// =============================================================================
// GuessMap — 真實 Google Map（點一點猜位置）
//
// ✅ [Callback / Lift] onGuessChanged / onMapCreated
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GuessMap extends StatefulWidget {
  final ValueChanged<LatLng> onGuessChanged;
  final ValueChanged<GoogleMapController>? onMapCreated;
  final bool locked;
  final LatLng? guessedLocation;
  final LatLng? correctLocation;

  const GuessMap({
    super.key,
    required this.onGuessChanged,
    this.onMapCreated,
    this.locked = false,
    this.guessedLocation,
    this.correctLocation,
  });

  @override
  State<GuessMap> createState() => _GuessMapState();
}

class _GuessMapState extends State<GuessMap> {
  GoogleMapController? _controller;

  void _handleMapCreated(GoogleMapController controller) {
    _controller = controller;
    widget.onMapCreated?.call(controller);
  }

  Future<void> _zoomIn() async {
    try {
      await _controller?.animateCamera(CameraUpdate.zoomIn());
    } catch (_) {
      // PlatformView 邊界例外忽略即可
    }
  }

  Future<void> _zoomOut() async {
    try {
      await _controller?.animateCamera(CameraUpdate.zoomOut());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = <Marker>{};
    final Set<Polyline> polylines = <Polyline>{};

    if (widget.guessedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('guess'),
          position: widget.guessedLocation!,
          draggable: !widget.locked,
          onDragEnd: widget.locked ? null : widget.onGuessChanged,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: '你的猜測'),
        ),
      );
    }

    if (widget.correctLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('correct'),
          position: widget.correctLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '正確位置'),
        ),
      );
      if (widget.guessedLocation != null) {
        // 注意：iOS 上 PatternItem.gap(...) 的虛線 polyline 有 memory 暴衝 /
        // 凍結問題（flutter/flutter#150823），此處只用實線。
        polylines.add(
          Polyline(
            polylineId: const PolylineId('guess_to_correct'),
            color: Colors.redAccent,
            width: 3,
            points: <LatLng>[widget.guessedLocation!, widget.correctLocation!],
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20, 0),
              zoom: 2,
            ),
            onMapCreated: _handleMapCreated,
            onTap: widget.locked ? null : widget.onGuessChanged,
            markers: markers,
            polylines: polylines,
            myLocationButtonEnabled: false,
            // 關掉 Google 預設那組 +/- 按鈕，改用自訂的圓形按鈕
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            gestureRecognizers: _kMapGestureRecognizers,
          ),
          Positioned(
            right: 10,
            bottom: 16,
            child: _ZoomButtonColumn(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButtonColumn extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomButtonColumn({
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
          Container(
            width: 36,
            height: 1,
            color: Colors.grey.shade300,
          ),
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

final Set<Factory<OneSequenceGestureRecognizer>> _kMapGestureRecognizers =
    <Factory<OneSequenceGestureRecognizer>>{
  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
};
