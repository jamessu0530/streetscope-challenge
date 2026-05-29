import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../widgets/matchday_ui.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    AudioService.instance.playClick();
    setState(() => _busy = true);
    try {
      await AuthService.instance.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密碼已更新')),
      );
      Navigator.of(context).pop();
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
          '更改密碼',
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
                  '密碼以 bcrypt 雜湊存在 MongoDB，Email 本身不會被 hash。',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _PasswordField(
                  controller: _currentCtrl,
                  label: '目前密碼',
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _newCtrl,
                  label: '新密碼（至少 6 碼）',
                  enabled: !_busy,
                  validator: (String? v) {
                    if ((v ?? '').length < 6) return '新密碼至少 6 碼';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _confirmCtrl,
                  label: '確認新密碼',
                  enabled: !_busy,
                  validator: (String? v) {
                    if (v != _newCtrl.text) return '兩次輸入的新密碼不一致';
                    return null;
                  },
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
                            '儲存新密碼',
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

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: const TextStyle(
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
            obscureText: true,
            validator: validator ??
                (String? v) {
                  if ((v ?? '').isEmpty) return '請填寫此欄位';
                  return null;
                },
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MatchdayPalette.ink,
            ),
            decoration: const InputDecoration(
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
