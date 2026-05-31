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
  final bool displayNameCustomized;
  final bool needsNicknameSetup;
  final String? suggestedDisplayName;

  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.provider,
    required this.loggedInAt,
    this.displayNameCustomized = true,
    this.needsNicknameSetup = false,
    this.suggestedDisplayName,
  });

  String get nicknameSuggestion =>
      (suggestedDisplayName != null && suggestedDisplayName!.trim().isNotEmpty)
          ? suggestedDisplayName!.trim()
          : displayName;

  AuthUser copyWith({
    String? displayName,
    bool? displayNameCustomized,
    bool? needsNicknameSetup,
    String? suggestedDisplayName,
  }) {
    return AuthUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email,
      provider: provider,
      loggedInAt: loggedInAt,
      displayNameCustomized:
          displayNameCustomized ?? this.displayNameCustomized,
      needsNicknameSetup: needsNicknameSetup ?? this.needsNicknameSetup,
      suggestedDisplayName:
          suggestedDisplayName ?? this.suggestedDisplayName,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayName': displayName,
        'email': email,
        'provider': provider.name,
        'loggedInAt': loggedInAt.toIso8601String(),
        'displayNameCustomized': displayNameCustomized,
        'needsNicknameSetup': needsNicknameSetup,
        'suggestedDisplayName': suggestedDisplayName,
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
      displayNameCustomized:
          json['displayNameCustomized'] as bool? ?? true,
      needsNicknameSetup: json['needsNicknameSetup'] as bool? ?? false,
      suggestedDisplayName: json['suggestedDisplayName'] as String?,
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
    final bool? displayNameCustomized = json['displayNameCustomized'] as bool? ??
        json['display_name_customized'] as bool?;
    final bool? needsNicknameSetup = json['needsNicknameSetup'] as bool? ??
        json['needs_nickname_setup'] as bool?;
    final String? suggestedDisplayName =
        json['suggestedDisplayName'] as String? ??
            json['suggested_display_name'] as String?;
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
      displayNameCustomized: displayNameCustomized ?? true,
      needsNicknameSetup: needsNicknameSetup ?? false,
      suggestedDisplayName: suggestedDisplayName,
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
