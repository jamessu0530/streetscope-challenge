import 'package:google_sign_in/google_sign_in.dart';

import '../config/env.dart';

/// 共用 GoogleSignIn 設定（Web Client ID 供後端驗證 idToken）。
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  GoogleSignIn? _client;

  GoogleSignIn get client {
    _client ??= GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      clientId: kGoogleIosClientId.isNotEmpty ? kGoogleIosClientId : null,
      serverClientId:
          kGoogleWebClientId.isNotEmpty ? kGoogleWebClientId : null,
    );
    return _client!;
  }
}
