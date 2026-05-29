import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../widgets/matchday_ui.dart';

/// 忘記密碼：兩步驟 — ① 申請重設碼 ② 輸入重設碼 + 新密碼
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  int _step = 0;
  bool _busy = false;
  String? _issuedResetToken;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入 Email')),
      );
      return;
    }
    AudioService.instance.playClick();
    setState(() => _busy = true);
    try {
      final ForgotPasswordResult result =
          await AuthService.instance.requestPasswordReset(
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _issuedResetToken = result.resetToken;
        _step = 1;
        if (result.resetToken != null) {
          _codeCtrl.text = result.resetToken!;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          duration: const Duration(seconds: 4),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    AudioService.instance.playClick();
    setState(() => _busy = true);
    try {
      await AuthService.instance.resetPasswordWithToken(
        email: _emailCtrl.text.trim(),
        resetToken: _codeCtrl.text.trim(),
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密碼已重設，請用新密碼登入')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copyCode() {
    final String? code = _issuedResetToken;
    if (code == null || code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製重設碼')),
    );
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
          '忘記密碼',
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
                Text(
                  _step == 0
                      ? '步驟 1：輸入註冊用的 Email，取得重設碼（教育版會顯示在畫面上）。'
                      : '步驟 2：輸入重設碼與新密碼。',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _Field(
                  label: 'Email',
                  controller: _emailCtrl,
                  enabled: !_busy && _step == 0,
                  keyboardType: TextInputType.emailAddress,
                  validator: _step == 0 ? _emailValidator : null,
                ),
                if (_step == 1) ...<Widget>[
                  const SizedBox(height: 12),
                  if (_issuedResetToken != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MatchdayPalette.cream,
                        border: Border.all(color: MatchdayPalette.ink, width: 1.5),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  '你的重設碼',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _issuedResetToken!,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                    color: MatchdayPalette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '複製',
                            onPressed: _copyCode,
                            icon: const Icon(Icons.copy, color: MatchdayPalette.ink),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _Field(
                    label: '重設碼',
                    controller: _codeCtrl,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    validator: (String? v) {
                      if ((v ?? '').trim().length < 4) return '請輸入重設碼';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: '新密碼（至少 6 碼）',
                    controller: _newCtrl,
                    enabled: !_busy,
                    obscureText: true,
                    validator: (String? v) {
                      if ((v ?? '').length < 6) return '新密碼至少 6 碼';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: '確認新密碼',
                    controller: _confirmCtrl,
                    enabled: !_busy,
                    obscureText: true,
                    validator: (String? v) {
                      if (v != _newCtrl.text) return '兩次密碼不一致';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : (_step == 0 ? _requestCode : _resetPassword),
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
                        : Text(
                            _step == 0 ? '取得重設碼' : '重設密碼',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                if (_step == 1)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _step = 0;
                              _codeCtrl.clear();
                              _newCtrl.clear();
                              _confirmCtrl.clear();
                            }),
                    child: const Text(
                      '重新申請重設碼',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MatchdayPalette.ink,
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

  String? _emailValidator(String? v) {
    final String t = (v ?? '').trim();
    if (t.isEmpty) return '請輸入 Email';
    final RegExp re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(t)) return 'Email 格式不正確';
    return null;
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
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
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            validator: validator,
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
