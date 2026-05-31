class OnlinePlayer {
  const OnlinePlayer({
    required this.id,
    required this.displayName,
  });

  final String id;
  final String displayName;

  factory OnlinePlayer.fromJson(Map<String, dynamic> json) {
    return OnlinePlayer(
      id: (json['id'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? 'Player',
    );
  }
}

class LobbyChatMessage {
  const LobbyChatMessage({
    required this.fromId,
    required this.fromDisplayName,
    required this.text,
    required this.at,
  });

  final String fromId;
  final String fromDisplayName;
  final String text;
  final DateTime at;

  factory LobbyChatMessage.fromJson(Map<String, dynamic> json) {
    final dynamic from = json['from'];
    final Map<String, dynamic> fromMap =
        from is Map<String, dynamic> ? from : <String, dynamic>{};
    final String atRaw = (json['at'] as String?) ?? '';
    return LobbyChatMessage(
      fromId: (fromMap['id'] as String?) ?? '',
      fromDisplayName: (fromMap['displayName'] as String?) ?? 'Player',
      text: (json['text'] as String?) ?? '',
      at: DateTime.tryParse(atRaw) ?? DateTime.now(),
    );
  }
}
