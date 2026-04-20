// =============================================================================
// StreetViewPanel — Maps JavaScript Street View 嵌在 WebView
//
// 為什麼用 WebView 而不是 Static API：
//   - HTTP Metadata 端點不會回傳 [links]，做不到「沿路箭頭」。
//   - Maps JavaScript StreetViewPanorama 才有真正的 GeoGuessr / Google 地圖那種
//     地上自動出現方向箭頭、可以走、可以拖、可以縮放、會自動轉彎。
//
// 流程：
//   1. WebView 載入內嵌的 HTML（含 Maps JS API），初始化 StreetViewPanorama。
//   2. JS 監聽 position_changed / pano_changed，把座標 + panoId 透過
//      JavaScriptChannel 回傳給 Flutter，更新本回合「正確答案」。
//   3. 外部更新 widget.place（換題）→ 呼叫 JS 的 setPosition()。
// =============================================================================

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/env.dart';
import '../models/game_mode.dart';
import '../models/place.dart';

class StreetViewPanel extends StatefulWidget {
  final Place place;
  final ValueChanged<Place>? onPlaceChanged;

  /// 初始 panorama 載入後若沒有可走的 links（俯視 / 空拍 / 孤島街景），會呼叫此 callback。
  /// 父層收到後可重新抽一個地點。
  final VoidCallback? onNeedsRepick;
  final double? height;
  final GameMode mode;

  /// 街景右上角的「打開地圖」icon，按下時呼叫此 callback。
  /// 為 null 時不顯示該 icon。
  final VoidCallback? onOpenMap;

  /// 是否已有猜測（決定右上 icon 是否顯示一個小徽章）。
  final bool hasGuess;

  /// Move 模式下可以走幾步。0 = 不限。
  final int maxMoveSteps;

  const StreetViewPanel({
    super.key,
    required this.place,
    this.onPlaceChanged,
    this.onNeedsRepick,
    this.height,
    this.mode = GameMode.move,
    this.onOpenMap,
    this.hasGuess = false,
    this.maxMoveSteps = 0,
  });

  @override
  State<StreetViewPanel> createState() => _StreetViewPanelState();
}

class _StreetViewPanelState extends State<StreetViewPanel> {
  late WebViewController _controller;
  late Place _currentPlace;
  bool _ready = false;
  bool _hasError = false;
  String? _statusMessage;

  /// 我們呼叫 [widget.onPlaceChanged] 後，父層會用新位置 setState 重建本 widget，
  /// 這時 [didUpdateWidget] 會看到 widget.place 跟 oldWidget.place 不同，
  /// 但這是「我們自己往前走出去的」，**不能**重新 loadHtmlString，否則 panorama
  /// 會被重置回新位置（看起來就是「走一步就被彈回去」）。
  /// 用這個 flag 跳過下一次 didUpdateWidget 的 reload 判斷。
  bool _ignoreNextExternalChange = false;

  /// 目前鏡頭朝向（度，0 = 正北，順時針）。供畫面右上角的指南針顯示。
  double _headingDeg = 0;

  /// 已走的步數（每次 position_changed 且座標顯著不同時 +1）。
  int _moveCount = 0;

  /// 達到 maxMoveSteps 後，JS 側會關掉 links / clickToGo，避免繼續往前走。
  bool _moveLocked = false;

  String get _hintText {
    switch (widget.mode) {
      case GameMode.move:
        if (widget.maxMoveSteps > 0) {
          final int left =
              (widget.maxMoveSteps - _moveCount).clamp(0, widget.maxMoveSteps);
          return '拖曳環視 ・ 步數剩 $left / ${widget.maxMoveSteps}';
        }
        return '拖曳環視 ・ 點地上箭頭沿路走';
      case GameMode.noMove:
        return 'No Move ・ 只能旋轉鏡頭';
      case GameMode.picture:
        return 'Picture ・ 完全靜態';
    }
  }

  Future<void> _zoomIn() async {
    try {
      await _controller.runJavaScript('zoomBy(1)');
    } catch (_) {
      // 忽略：panorama 還沒就緒等
    }
  }

  Future<void> _zoomOut() async {
    try {
      await _controller.runJavaScript('zoomBy(-1)');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _currentPlace = widget.place;
    _initWebView();
  }

  void _initWebView() {
    final WebViewController c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
          onWebResourceError: (WebResourceError err) {
            debugPrint('StreetView WebView error: ${err.description}');
          },
        ),
      )
      ..loadHtmlString(_buildHtml(_currentPlace),
          baseUrl: 'https://localhost/');
    _controller = c;
  }

  @override
  void didUpdateWidget(covariant StreetViewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool placeChanged =
        oldWidget.place.latitude != widget.place.latitude ||
            oldWidget.place.longitude != widget.place.longitude;
    if (!placeChanged) return;

    // 玩家自己在 panorama 裡走，父層會用新座標 setState 回來；不要 reload。
    if (_ignoreNextExternalChange) {
      _ignoreNextExternalChange = false;
      _currentPlace = widget.place;
      return;
    }

    // 真．外部換題（換回合等）才整個 reload。
    _currentPlace = widget.place;
    _hasError = false;
    _statusMessage = null;
    _headingDeg = 0;
    _controller.loadHtmlString(
      _buildHtml(_currentPlace),
      baseUrl: 'https://localhost/',
    );
    setState(() => _ready = false);
  }

  void _onJsMessage(JavaScriptMessage msg) {
    try {
      final dynamic decoded = jsonDecode(msg.message);
      if (decoded is! Map) return;
      final String type = decoded['type'] as String? ?? '';
      switch (type) {
        case 'pos':
          final num? lat = decoded['lat'] as num?;
          final num? lng = decoded['lng'] as num?;
          final String pano = (decoded['pano'] as String?) ?? '';
          if (lat == null || lng == null) return;
          final Place updated = Place(
            latitude: lat.toDouble(),
            longitude: lng.toDouble(),
            panoId: pano.isEmpty ? null : pano,
          );
          // 移動微距時不擾動 state；位置真的變了再回呼。
          final bool same =
              (updated.latitude - _currentPlace.latitude).abs() < 1e-7 &&
                  (updated.longitude - _currentPlace.longitude).abs() < 1e-7;
          if (same) return;
          _currentPlace = updated;
          // 標記：接下來父層會用新位置重建本 widget，不要把 WebView reload 掉。
          _ignoreNextExternalChange = true;
          widget.onPlaceChanged?.call(_currentPlace);
          // 計算步數並在到達上限時鎖住移動
          if (widget.mode == GameMode.move && widget.maxMoveSteps > 0) {
            _moveCount += 1;
            if (mounted) setState(() {});
            if (!_moveLocked && _moveCount >= widget.maxMoveSteps) {
              _moveLocked = true;
              _controller.runJavaScript('setCanMove(false)').catchError((_) {});
            }
          }
          break;
        case 'status':
          final String status = (decoded['status'] as String?) ?? '';
          if (status != 'OK') {
            if (!mounted) return;
            setState(() {
              _hasError = true;
              _statusMessage = status;
            });
          }
          break;
        case 'no_links':
          // 抽到俯視 / 空拍 / 孤島：請父層重抽。
          widget.onNeedsRepick?.call();
          break;
        case 'pov':
          final num? heading = decoded['heading'] as num?;
          if (heading == null) return;
          final double h = ((heading.toDouble() % 360) + 360) % 360;
          // 至少差 1° 才 setState，避免 60fps 流量
          if ((h - _headingDeg).abs() < 1) return;
          if (!mounted) return;
          setState(() => _headingDeg = h);
          break;
      }
    } catch (_) {
      // 忽略損毀訊息。
    }
  }

  String _buildHtml(Place place) {
    final String key = kGoogleApiKey;
    final String lat = place.latitude.toStringAsFixed(7);
    final String lng = place.longitude.toStringAsFixed(7);
    final String pano = place.panoId ?? '';

    // 模式對應 panorama 選項：
    //   move    → 走 + 轉 + 縮放
    //   noMove  → 不走，但轉 + 縮放
    //   picture → 完全靜止（連鏡頭都不能動）
    final String linksControlJs;
    final String clickToGoJs;
    final String scrollWheelJs;
    final String gestureHandlingJs;
    switch (widget.mode) {
      case GameMode.move:
        linksControlJs = 'true';
        clickToGoJs = 'true';
        scrollWheelJs = 'true';
        gestureHandlingJs = 'greedy';
        break;
      case GameMode.noMove:
        linksControlJs = 'false';
        clickToGoJs = 'false';
        scrollWheelJs = 'true';
        gestureHandlingJs = 'greedy';
        break;
      case GameMode.picture:
        linksControlJs = 'false';
        clickToGoJs = 'false';
        scrollWheelJs = 'false';
        gestureHandlingJs = 'none';
        break;
    }
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport"
          content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <style>
      html, body { margin: 0; padding: 0; height: 100%; background: #000; }
      #sv { width: 100%; height: 100%; }
      .err {
        color:#fff; font-family: -apple-system, system-ui, sans-serif;
        padding:16px; text-align:center;
      }
    </style>
  </head>
  <body>
    <div id="sv"></div>
    <script>
      var panorama = null;
      function post(obj) {
        if (window.FlutterChannel) {
          FlutterChannel.postMessage(JSON.stringify(obj));
        }
      }
      function initPano() {
        try {
          var opts = {
            // 不指定 pov：用 panorama 拍攝當下的相機朝向（在下方 pano_changed 設定）
            zoom: 0,
            addressControl: false,
            linksControl: $linksControlJs,
            panControl: false,
            zoomControl: false,
            enableCloseButton: false,
            fullscreenControl: false,
            showRoadLabels: false,
            motionTracking: false,
            motionTrackingControl: false,
            clickToGo: $clickToGoJs,
            scrollwheel: $scrollWheelJs,
            disableDefaultUI: false,
            gestureHandling: '$gestureHandlingJs',
          };
          var pano = "$pano";
          if (pano && pano.length > 0) {
            opts.pano = pano;
          } else {
            opts.position = { lat: $lat, lng: $lng };
          }
          panorama = new google.maps.StreetViewPanorama(
            document.getElementById('sv'), opts
          );
          panorama.addListener('position_changed', function() {
            var p = panorama.getPosition();
            if (!p) return;
            post({
              type: 'pos',
              lat: p.lat(),
              lng: p.lng(),
              pano: panorama.getPano() || ''
            });
          });
          // 鏡頭朝向變動 → 通知 Flutter 端的指南針
          panorama.addListener('pov_changed', function() {
            var pov = panorama.getPov();
            if (!pov) return;
            post({ type: 'pov', heading: pov.heading || 0 });
          });
          panorama.addListener('status_changed', function() {
            post({ type: 'status', status: panorama.getStatus() });
          });
          // 第一張全景就位後：(1) 套用拍攝者原本的朝向；(2) 檢查是否有可走 links
          var initialDone = false;
          panorama.addListener('pano_changed', function() {
            if (initialDone) return;
            initialDone = true;
            // 用拍攝當下的相機朝向，而不是強制朝北
            var photographerPov = panorama.getPhotographerPov();
            if (photographerPov) {
              panorama.setPov({
                heading: photographerPov.heading,
                pitch: 0
              });
            }
            // 給 panorama 一點時間把 links 算出來
            setTimeout(function() {
              var links = panorama.getLinks() || [];
              if (links.length === 0) {
                post({ type: 'no_links' });
              }
            }, 350);
          });
        } catch (e) {
          document.body.innerHTML =
            '<div class="err">街景初始化失敗：' + e.message + '</div>';
          post({ type: 'status', status: 'INIT_ERROR' });
        }
      }
      function setPosition(lat, lng) {
        if (panorama) panorama.setPosition({ lat: lat, lng: lng });
      }
      function setPano(panoId) {
        if (panorama) panorama.setPano(panoId);
      }
      function zoomBy(delta) {
        if (!panorama) return;
        var z = (panorama.getZoom() || 0) + delta;
        // Street View 實務上的縮放範圍大約 0 ~ 5
        if (z < 0) z = 0;
        if (z > 5) z = 5;
        panorama.setZoom(z);
      }
      // Flutter 端的「可移動步數」達到上限時呼叫，關掉方向箭頭與點地移動。
      function setCanMove(can) {
        if (!panorama) return;
        panorama.setOptions({
          linksControl: !!can,
          clickToGo: !!can
        });
      }
    </script>
    <script async defer
      src="https://maps.googleapis.com/maps/api/js?key=$key&callback=initPano&v=weekly">
    </script>
  </body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final bool missingKey = !hasGoogleApiKey;

    if (missingKey) {
      return _placeholder(
        '請設定 Google API Key（.env 或 --dart-define）\n'
        '並啟用 Maps JavaScript API + Street View Static API',
      );
    }

    final Widget webView = WebViewWidget(
      controller: _controller,
      gestureRecognizers: kStreetViewGestureRecognizers,
    );

    final Widget content = Stack(
      fit: StackFit.expand,
      children: [
        // Picture 模式：用 AbsorbPointer 吞掉所有觸控（連旋轉鏡頭都不行）
        widget.mode == GameMode.picture
            ? AbsorbPointer(child: webView)
            : webView,

        if (!_ready && !_hasError)
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          ),

        if (_hasError)
          Container(
            color: Colors.grey.shade900,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white54),
                const SizedBox(height: 8),
                Text(
                  '街景載入失敗${_statusMessage == null ? '' : '（$_statusMessage）'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        Positioned(
          left: 8,
          bottom: 8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _hintText,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ),
          ),
        ),

        // 縮放按鈕：樣式與小地圖一致。Picture 模式完全靜態，不顯示。
        if (widget.mode != GameMode.picture)
          Positioned(
            right: 10,
            bottom: 16,
            child: _StreetViewZoomButtons(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),

        // 指南針：一律顯示。配合太陽位置可推測南北半球。
        Positioned(
          left: 8,
          top: 8,
          child: IgnorePointer(
            child: _CompassBadge(headingDeg: _headingDeg),
          ),
        ),

        // 右上角「打開地圖」icon
        if (widget.onOpenMap != null)
          Positioned(
            right: 8,
            top: 8,
            child: _OpenMapFab(
              onPressed: widget.onOpenMap!,
              hasGuess: widget.hasGuess,
            ),
          ),
      ],
    );

    final Widget rounded = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: content,
    );

    if (widget.height != null) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: rounded,
      );
    }
    return rounded;
  }

  Widget _placeholder(String msg) {
    return Container(
      height: widget.height ?? 220,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(msg, textAlign: TextAlign.center),
    );
  }
}

/// 指南針：紅色三角永遠指北；外圈會跟著鏡頭朝向反向旋轉。
class _CompassBadge extends StatelessWidget {
  final double headingDeg;
  const _CompassBadge({required this.headingDeg});

  @override
  Widget build(BuildContext context) {
    // 鏡頭朝向 N 表示玩家面向北。要讓「N 字」隨之轉到上方相對於視角的位置：
    // 把整顆指南針逆向旋轉 -heading 度，N 就會出現在「真實的北方」那一側。
    final double radians = -headingDeg * math.pi / 180;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Transform.rotate(
              angle: radians,
              child: CustomPaint(painter: _CompassPainter()),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${headingDeg.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = math.min(size.width, size.height) / 2;

    final Paint ring = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, r - 1, ring);

    // N（北）— 紅色三角
    final Paint north = Paint()..color = Colors.redAccent;
    final Path northPath = Path()
      ..moveTo(center.dx, center.dy - r * 0.85)
      ..lineTo(center.dx + r * 0.22, center.dy)
      ..lineTo(center.dx - r * 0.22, center.dy)
      ..close();
    canvas.drawPath(northPath, north);

    // S（南）— 灰色三角
    final Paint south = Paint()..color = Colors.white70;
    final Path southPath = Path()
      ..moveTo(center.dx, center.dy + r * 0.85)
      ..lineTo(center.dx + r * 0.22, center.dy)
      ..lineTo(center.dx - r * 0.22, center.dy)
      ..close();
    canvas.drawPath(southPath, south);

    // 「N」字
    final TextPainter tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - r * 0.95 - 1),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 街景右上角「打開地圖」icon 按鈕。
/// 有猜測時右上角會出現一個藍色小圓點當作提醒。
class _OpenMapFab extends StatelessWidget {
  final VoidCallback onPressed;
  final bool hasGuess;

  const _OpenMapFab({required this.onPressed, required this.hasGuess});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: Image.asset(
                  'flutterproject4icon.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              if (hasGuess)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 街景右下角縮放按鈕（與 GuessMap 小地圖相同視覺）。
class _StreetViewZoomButtons extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _StreetViewZoomButtons({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomIconButton(
            icon: Icons.add,
            tooltip: '放大',
            onPressed: onZoomIn,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          Container(width: 36, height: 1, color: Colors.grey.shade300),
          _ZoomIconButton(
            icon: Icons.remove,
            tooltip: '縮小',
            onPressed: onZoomOut,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ],
      ),
    );
  }
}

class _ZoomIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;

  const _ZoomIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: const Color(0xFF3F51B5)),
        ),
      ),
    );
  }
}

/// 確保 WebView 內的拖曳手勢一定吃得到（不會被外層 Scroll 搶走）。
final Set<Factory<OneSequenceGestureRecognizer>> kStreetViewGestureRecognizers =
    <Factory<OneSequenceGestureRecognizer>>{
  Factory<OneSequenceGestureRecognizer>(
    () => EagerGestureRecognizer(),
  ),
};
