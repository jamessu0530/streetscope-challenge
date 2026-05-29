// =============================================================================
// AuthUser — 登入後本機保存的玩家資訊
//
// 目前是 local-only（沒有後端 / 資料庫），只用 SharedPreferences 存。
// 之後接 Firebase / 自家後端時，再把 provider 對應到真正的 OAuth flow 即可。
// =============================================================================

import 'dart:convert';

/// 登入方式：對應到 LoginPage 上的三個選項。
enum AuthProvider {
  email,
  google,
  facebook,
  github,
}

extension AuthProviderX on AuthProvider {
  String get label {
    switch (this) {
      case AuthProvider.email:
        return 'Email';
      case AuthProvider.google:
        return 'Google';
      case AuthProvider.facebook:
        return 'Facebook';
      case AuthProvider.github:
        return 'GitHub';
    }
  }
}

class AuthUser {
  /// 本機產生的 unique id（之後接後端再換成 server uid）。
  final String id;
  final String displayName;
  final String? email;
  final AuthProvider provider;
  final DateTime loggedInAt;

  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.provider,
    required this.loggedInAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayName': displayName,
        'email': email,
        'provider': provider.name,
        'loggedInAt': loggedInAt.toIso8601String(),
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final String providerName =
        json['provider'] as String? ?? AuthProvider.email.name;
    return AuthUser(
      id: (json['id'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? 'Player',
      email: json['email'] as String?,
      provider: AuthProvider.values.firstWhere(
        (AuthProvider p) => p.name == providerName,
        orElse: () => AuthProvider.email,
      ),
      loggedInAt: DateTime.tryParse(json['loggedInAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// FastAPI `/auth/register`、`/auth/login`、`/auth/me` 回傳的 user 物件。
  factory AuthUser.fromApiJson(Map<String, dynamic> json) {
    final String providerName =
        json['provider'] as String? ?? AuthProvider.email.name;
    final String? createdAt =
        json['createdAt'] as String? ?? json['created_at'] as String?;
    final String? displayName =
        json['displayName'] as String? ?? json['display_name'] as String?;
    return AuthUser(
      id: (json['id'] as String?) ?? '',
      displayName: (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : 'Player',
      email: json['email'] as String?,
      provider: AuthProvider.values.firstWhere(
        (AuthProvider p) => p.name == providerName,
        orElse: () => AuthProvider.email,
      ),
      loggedInAt:
          DateTime.tryParse(createdAt ?? '') ?? DateTime.now(),
    );
  }

  String encode() => jsonEncode(toJson());

  static AuthUser? decode(String raw) {
    try {
      final dynamic data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      return AuthUser.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
