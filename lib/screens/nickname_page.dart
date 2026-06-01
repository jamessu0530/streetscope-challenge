import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../utils/nickname_utils.dart';
import '../utils/post_login_navigation.dart';
import '../widgets/matchday_ui.dart';

/// 若尚未完成暱稱設定，導向設定頁。回傳 true 代表可繼續（已設定或設定完成）。
Future<bool> ensureNicknameSetup(BuildContext context) async {
  final AuthUser? user = AuthService.instance.currentUser.value;
  if (user == null || !user.needsNicknameSetup) {
    return true;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => NicknameSetupPage(
        initialName: user.nicknameSuggestion,
      ),
    ),
  );
  if (!context.mounted) return false;
  return !(AuthService.instance.currentUser.value?.needsNicknameSetup ?? true);
}

/// 首次 OAuth 登入後設定全站唯一遊戲暱稱。
class NicknameSetupPage extends StatefulWidget {
  const NicknameSetupPage({super.key, this.initialName = ''});

  final String initialName;

  @override
  State<NicknameSetupPage> createState() => _NicknameSetupPageState();
}

class _NicknameSetupPageState extends State<NicknameSetupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.initialName);
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    AudioService.instance.playClick();
    setState(() => _busy = true);
    try {
      await AuthService.instance.updateDisplayName(_nameCtrl.text.trim());
      if (!mounted) return;
      returnToAppHome(context, snackMessage: '暱稱已設定');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('設定失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: MatchdayPalette.bg,
        appBar: AppBar(
          backgroundColor: MatchdayPalette.bg,
          elevation: 0,
          foregroundColor: MatchdayPalette.ink,
          automaticallyImplyLeading: false,
          title: const Text(
            '設定遊戲暱稱',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    '你的遊戲暱稱是？\n全站唯一，會顯示在大廳、排行榜與對戰中。',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _NicknameField(
                    controller: _nameCtrl,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: MatchdayPalette.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '確認暱稱',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditNicknamePage extends StatefulWidget {
  const EditNicknamePage({super.key});

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl = TextEditingController(
    text: AuthService.instance.currentUser.value?.displayName ?? '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    AudioService.instance.playClick();
    setState(() => _busy = true);
    try {
      await AuthService.instance.updateDisplayName(_nameCtrl.text.trim());
      if (!mounted) return;
      returnToAppHome(context, snackMessage: '暱稱已更新');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MatchdayPalette.bg,
      appBar: AppBar(
        backgroundColor: MatchdayPalette.bg,
        elevation: 0,
        foregroundColor: MatchdayPalette.ink,
        title: const Text(
          '編輯暱稱',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  '遊戲暱稱全站唯一，2～32 字且不可含空白。',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _NicknameField(
                  controller: _nameCtrl,
                  enabled: !_busy,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: MatchdayPalette.ink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '儲存暱稱',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NicknameField extends StatelessWidget {
  const _NicknameField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'GAME ID',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: MatchdayPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: MatchdayPalette.cream,
            border: Border.all(color: MatchdayPalette.ink, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            validator: NicknameUtils.validate,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MatchdayPalette.ink,
            ),
            decoration: const InputDecoration(
              hintText: '例如 GeoMaster99',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
