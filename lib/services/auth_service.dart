// =============================================================================
// AuthService — Email / Google / Facebook / GitHub 登入接 FastAPI + MongoDB。
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';
import '../models/auth_user.dart';
import 'github_sign_in_service.dart';
import 'google_sign_in_service.dart';
import 'realtime_service.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.message,
    this.resetToken,
    this.expiresInMinutes,
  });

  final String message;
  final String? resetToken;
  final int? expiresInMinutes;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _kAccessTokenKey = 'auth_access_token_v1';
  static const String _kCurrentUserKey = 'auth_current_user_v1';
  static const String sessionSupersededMessage =
      '帳號已在其他裝置登入，請重新登入';

  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);
  final ValueNotifier<String?> sessionRevokedNotice =
      ValueNotifier<String?>(null);

  bool _initialized = false;
  String? _accessToken;

  String? get accessToken => _accessToken;

  bool get hasApi => kApiBaseUrl.isNotEmpty;

  /// App 啟動時：若有 token 則向後端 /auth/me 還原登入狀態。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessTokenKey);

    if (_accessToken != null && _accessToken!.isNotEmpty && hasApi) {
      try {
        final AuthUser user = await _fetchMe(_accessToken!);
        currentUser.value = user;
        await _persistUserOnly(user);
        unawaited(RealtimeService.instance.connect());
        return;
      } catch (_) {
        await _clearSession(prefs);
      }
    }

    final String? raw = prefs.getString(_kCurrentUserKey);
    if (raw != null && raw.isNotEmpty) {
      currentUser.value = AuthUser.decode(raw);
    }
  }

  bool get isLoggedIn => currentUser.value != null;

  static bool isSessionSupersededMessage(String message) {
    return message.contains('其他裝置') ||
        message.contains('SESSION_SUPERSEDED');
  }

  /// 401 且 session 被新登入取代時，清本機登入並通知 UI。
  Future<bool> handleUnauthorizedResponse(http.Response response) async {
    if (response.statusCode != 401) return false;
    final String message = _errorMessage(response);
    if (!isSessionSupersededMessage(message)) return false;
    sessionRevokedNotice.value = sessionSupersededMessage;
    await signOut();
    return true;
  }

  /// 確認 token 仍有效；被踢下線時會清 session。
  Future<void> ensureSessionStillValid() async {
    if (!isLoggedIn || _accessToken == null || _accessToken!.isEmpty) {
      return;
    }
    if (!hasApi) return;
    await _fetchMe(_accessToken!);
  }

  /// 註冊成功後會直接寫入 JWT 並登入（與 Google / GitHub 相同）。
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final String trimmedEmail = email.trim();
    final String trimmedName = displayName.trim();

    try {
      return await _authPost(
        '/auth/register',
        <String, dynamic>{
          'email': trimmedEmail,
          'password': password,
          'displayName': trimmedName,
        },
      );
    } on AuthException catch (e) {
      // 舊版或異常回應若未帶 token，改以同組帳密登入（帳號已建立時）
      if (e.message.contains('伺服器回應格式錯誤')) {
        return loginWithEmail(email: trimmedEmail, password: password);
      }
      rethrow;
    }
  }

  Future<AuthUser> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return _authPost(
      '/auth/login',
      <String, dynamic>{
        'email': email.trim(),
        'password': password,
      },
    );
  }

  Future<AuthUser> signInWithGoogle() async {
    if (!hasApi) {
      throw AuthException('請在 .env 設定 API_BASE_URL');
    }
    if (!hasGoogleOAuth) {
      throw AuthException(
        '請在 .env 設定 GOOGLE_IOS_CLIENT_ID\n詳見 docs/GOOGLE_SIGNIN.md',
      );
    }

    final GoogleSignInAccount? account =
        await GoogleSignInService.instance.client.signIn();
    if (account == null) {
      throw AuthException('已取消 Google 登入');
    }

    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AuthException(
        '無法取得 Google idToken，請確認 Secrets.xcconfig 與 .env 的 GOOGLE_IOS_CLIENT_ID',
      );
    }

    return _authPost(
      '/auth/google',
      <String, dynamic>{'idToken': idToken},
    );
  }

  Future<AuthUser> signInWithGitHub() async {
    if (!hasApi) {
      throw AuthException('請在 .env 設定 API_BASE_URL');
    }
    if (!hasGithubOAuth) {
      throw AuthException(
        '請在 .env 設定 GITHUB_CLIENT_ID\n詳見 docs/GITHUB_SIGNIN.md',
      );
    }

    try {
      final String code = await GitHubSignInService.instance.authorize();
      return _authPost(
        '/auth/github',
        <String, dynamic>{'code': code},
      );
    } on GitHubSignInCanceled {
      throw AuthException('已取消 GitHub 登入');
    } catch (e) {
      throw AuthException('GitHub 登入失敗：$e');
    }
  }

  Future<AuthUser> signInWithFacebook() async {
    if (!hasApi) {
      throw AuthException('請在 .env 設定 API_BASE_URL');
    }
    if (!hasFacebookAppId) {
      throw AuthException(
        '請在 ios/Flutter/Secrets.xcconfig 設定 FACEBOOK_APP_ID\n'
        '詳見 docs/FACEBOOK_SIGNIN.md',
      );
    }

    final LoginResult result = await FacebookAuth.instance.login(
      permissions: const <String>['public_profile'],
      loginTracking: LoginTracking.enabled,
    );

    if (result.status == LoginStatus.cancelled) {
      throw AuthException('已取消 Facebook 登入');
    }
    if (result.status != LoginStatus.success) {
      throw AuthException(
        result.message ?? 'Facebook 登入失敗',
      );
    }

    final AccessToken? accessToken = result.accessToken;
    if (accessToken == null || accessToken.tokenString.isEmpty) {
      throw AuthException('無法取得 Facebook token');
    }

    // iOS 未允許追蹤時 SDK 會走 Limited Login（JWT），不能用 Graph API access token。
    if (accessToken is LimitedToken) {
      final LimitedToken limited = accessToken;
      return _authPost(
        '/auth/facebook',
        <String, dynamic>{
          'loginType': 'limited',
          'authenticationToken': limited.tokenString,
          'userId': limited.userId,
          'userName': limited.userName,
          if (limited.userEmail != null && limited.userEmail!.isNotEmpty)
            'userEmail': limited.userEmail,
          'nonce': limited.nonce,
        },
      );
    }

    return _authPost(
      '/auth/facebook',
      <String, dynamic>{
        'loginType': 'classic',
        'accessToken': accessToken.tokenString,
      },
    );
  }

  Future<void> signOut() async {
    await RealtimeService.instance.disconnect();
    final AuthProvider? provider = currentUser.value?.provider;
    if (provider == AuthProvider.google && hasGoogleOAuth) {
      try {
        await GoogleSignInService.instance.client.signOut();
      } catch (_) {
        // ignore
      }
    }
    if (provider == AuthProvider.facebook && hasFacebookAppId) {
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {
        // ignore
      }
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    currentUser.value = null;
  }

  /// 忘記密碼 — 申請重設碼（教育版 API 會回傳 resetToken 供 App 顯示）。
  Future<ForgotPasswordResult> requestPasswordReset({
    required String email,
  }) async {
    if (!hasApi) {
      throw AuthException('請在 .env 設定 API_BASE_URL');
    }
    final http.Response response = await http
        .post(
          _uri('/auth/forgot-password'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, String>{'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = _decodeJson(response.body);
      return ForgotPasswordResult(
        message: (data['message'] as String?) ?? '已申請重設碼',
        resetToken: data['resetToken'] as String?,
        expiresInMinutes: data['expiresInMinutes'] as int?,
      );
    }
    throw AuthException(_errorMessage(response));
  }

  /// 用重設碼設定新密碼（不需 JWT）。
  Future<void> resetPasswordWithToken({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    if (!hasApi) {
      throw AuthException('請在 .env 設定 API_BASE_URL');
    }
    final http.Response response = await http
        .post(
          _uri('/auth/reset-password'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, String>{
            'email': email.trim(),
            'resetToken': resetToken.trim().toUpperCase(),
            'newPassword': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw AuthException(_errorMessage(response));
  }

  /// Email 帳號更改密碼（需已登入且持有 JWT）。
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final AuthUser? user = currentUser.value;
    if (user == null) {
      throw AuthException('請先登入');
    }
    if (user.provider != AuthProvider.email) {
      throw AuthException('只有 Email 帳號可以更改密碼');
    }
    final String? token = _accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('請用 Email 登入後再更改密碼');
    }
    if (!hasApi) {
      throw AuthException('請在 .env 設定 API_BASE_URL');
    }

    final http.Response response = await http
        .post(
          _uri('/auth/change-password'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, String>{
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    if (await handleUnauthorizedResponse(response)) {
      throw AuthException(sessionSupersededMessage);
    }
    throw AuthException(_errorMessage(response));
  }

  /// 更新全站唯一遊戲暱稱。
  Future<AuthUser> updateDisplayName(String displayName) async {
    final AuthUser? user = currentUser.value;
    if (user == null) {
      throw AuthException('請先登入');
    }
    final String? token = _accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('請先登入');
    }
    if (!hasApi) {
      throw AuthException('請在 .env 設定 API_BASE_URL');
    }

    final http.Response response = await http
        .patch(
          _uri('/auth/me/profile'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, String>{
            'displayName': displayName.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = _decodeJson(response.body);
      final AuthUser updated = AuthUser.fromApiJson(data);
      currentUser.value = updated;
      await _persistUserOnly(updated);
      unawaited(RealtimeService.instance.connect());
      return updated;
    }
    if (await handleUnauthorizedResponse(response)) {
      throw AuthException(sessionSupersededMessage);
    }
    throw AuthException(_errorMessage(response));
  }

  // ---------------------------------------------------------------------------
  // HTTP
  // ---------------------------------------------------------------------------
  Future<AuthUser> _authPost(String path, Map<String, dynamic> body) async {
    if (!hasApi) {
      throw AuthException('請在 .env 設定 API_BASE_URL（例如 http://127.0.0.1:3000）');
    }

    final http.Response response = await http
        .post(
          _uri(path),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = _decodeJson(response.body);
      return _applyAuthResponse(data);
    }
    throw AuthException(_errorMessage(response));
  }

  Future<AuthUser> _fetchMe(String token) async {
    final http.Response response = await http.get(
      _uri('/auth/me'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = _decodeJson(response.body);
      return AuthUser.fromApiJson(data);
    }
    if (await handleUnauthorizedResponse(response)) {
      throw AuthException(sessionSupersededMessage);
    }
    throw AuthException(_errorMessage(response));
  }

  Future<AuthUser> _applyAuthResponse(Map<String, dynamic> data) async {
    final String? token = (data['accessToken'] as String?)?.trim().isNotEmpty ==
            true
        ? data['accessToken'] as String
        : (data['access_token'] as String?)?.trim();
    final dynamic userJson = data['user'];
    if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
      throw AuthException('伺服器回應格式錯誤');
    }

    final AuthUser user = AuthUser.fromApiJson(userJson);
    _accessToken = token;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, token);
    await _persistUserOnly(user);
    currentUser.value = user;
    unawaited(RealtimeService.instance.connect());
    return user;
  }

  Uri _uri(String path) {
    final String base = kApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final String p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  Map<String, dynamic> _decodeJson(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw AuthException('伺服器回應格式錯誤');
    }
    return decoded;
  }

  String _errorMessage(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final dynamic first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
        }
      }
    } catch (_) {
      // ignore parse errors
    }
    return '請求失敗（${response.statusCode}）';
  }

  Future<void> _persistUserOnly(AuthUser user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUserKey, user.encode());
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    _accessToken = null;
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kCurrentUserKey);
  }
}
