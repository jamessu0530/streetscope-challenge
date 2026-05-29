import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../config/env.dart';

/// 開啟 GitHub OAuth 授權頁，回傳 authorization code。
class GitHubSignInService {
  GitHubSignInService._();
  static final GitHubSignInService instance = GitHubSignInService._();

  static final Random _random = Random.secure();

  String _newState() {
    final int n = _random.nextInt(0x7fffffff);
    return '${DateTime.now().millisecondsSinceEpoch}-$n';
  }

  Future<String> authorize() async {
    if (!hasGithubOAuth) {
      throw StateError('請在 .env 設定 GITHUB_CLIENT_ID');
    }

    final String state = _newState();
    final Uri authUrl = Uri.https(
      'github.com',
      '/login/oauth/authorize',
      <String, String>{
        'client_id': kGithubClientId,
        'redirect_uri': kGithubOAuthRedirectUri,
        'scope': 'read:user user:email',
        'state': state,
      },
    );

    final String callbackScheme =
        Uri.parse(kGithubOAuthRedirectUri).scheme;

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: callbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        throw GitHubSignInCanceled();
      }
      rethrow;
    }

    final Uri callback = Uri.parse(result);
    final String? error = callback.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      final String desc =
          callback.queryParameters['error_description'] ?? error;
      throw StateError(desc);
    }

    if (callback.queryParameters['state'] != state) {
      throw StateError('GitHub 登入 state 不符，請重試');
    }

    final String? code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('未取得 GitHub 授權碼');
    }
    return code;
  }
}

class GitHubSignInCanceled implements Exception {
  @override
  String toString() => '已取消 GitHub 登入';
}
