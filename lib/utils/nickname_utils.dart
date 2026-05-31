/// 遊戲暱稱驗證（需與後端 display_name.py 規則一致）。
class NicknameUtils {
  NicknameUtils._();

  static const int minLength = 2;
  static const int maxLength = 32;

  static String? validate(String? raw) {
    final String name = (raw ?? '').trim();
    if (name.length < minLength || name.length > maxLength) {
      return '暱稱需 $minLength～$maxLength 字';
    }
    if (RegExp(r'\s').hasMatch(name)) {
      return '暱稱不可含空白';
    }
    final String lowered = name.toLowerCase();
    const List<String> banned = <String>[
      'fuck',
      'shit',
      'bitch',
      'asshole',
      '操你',
      '幹你',
      '傻逼',
      '白痴',
      '婊子',
    ];
    for (final String token in banned) {
      if (lowered.contains(token)) {
        return '暱稱含有不當用字，請換一個';
      }
    }
    return null;
  }
}
