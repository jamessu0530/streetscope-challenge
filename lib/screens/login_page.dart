// =============================================================================
// LoginPage — Email / Google / Facebook / GitHub 接 FastAPI。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/auth_user.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../utils/nickname_utils.dart';
import '../widgets/matchday_ui.dart';
import 'forgot_password_page.dart';
import 'nickname_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  AuthProvider? _busy;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// false = 登入；true = 註冊
  bool _isRegister = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSignIn(
    AuthProvider provider,
    Future<AuthUser> Function() action, {
    String Function(AuthUser user)? successMessage,
  }) async {
    if (_busy != null) return;
    AudioService.instance.playClick();
    setState(() => _busy = provider);
    try {
      final AuthUser user = await action();
      if (!mounted) return;
      if (user.needsNicknameSetup) {
        final bool ready = await ensureNicknameSetup(context);
        if (!mounted) return;
        if (!ready) {
          await AuthService.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('請完成遊戲暱稱設定後再登入')),
          );
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successMessage?.call(AuthService.instance.currentUser.value ?? user) ??
                '歡迎，${(AuthService.instance.currentUser.value ?? user).displayName}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登入失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _signInWithGoogle() {
    _runSignIn(
      AuthProvider.google,
      () => AuthService.instance.signInWithGoogle(),
    );
  }

  void _signInWithFacebook() {
    _runSignIn(
      AuthProvider.facebook,
      () => AuthService.instance.signInWithFacebook(),
    );
  }

  void _signInWithGitHub() {
    _runSignIn(
      AuthProvider.github,
      () => AuthService.instance.signInWithGitHub(),
    );
  }

  void _submitEmail() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String email = _emailCtrl.text.trim();
    final String password = _passwordCtrl.text;
    if (_isRegister) {
      final String name = _nameCtrl.text.trim();
      _runSignIn(
        AuthProvider.email,
        () => AuthService.instance.registerWithEmail(
          email: email,
          password: password,
          displayName: name,
        ),
        successMessage: (AuthUser user) =>
            '註冊成功，已為 ${user.displayName} 自動登入',
      );
    } else {
      _runSignIn(
        AuthProvider.email,
        () => AuthService.instance.loginWithEmail(
          email: email,
          password: password,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MatchdayPalette.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const MatchdayTopTicker(
                label: 'LIVE · MEMBER LOUNGE',
                trailing: 'SIGN IN',
              ),
              _Header(onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 8),
              _SocialButtons(
                busy: _busy,
                onGoogle: _signInWithGoogle,
                onFacebook: _signInWithFacebook,
                onGitHub: _signInWithGitHub,
              ),
              const SizedBox(height: 22),
              const _OrDivider(),
              const SizedBox(height: 22),
              _EmailFormCard(
                formKey: _formKey,
                emailCtrl: _emailCtrl,
                nameCtrl: _nameCtrl,
                passwordCtrl: _passwordCtrl,
                isRegister: _isRegister,
                busy: _busy == AuthProvider.email,
                anyBusy: _busy != null,
                onSubmit: _submitEmail,
                onToggleMode: () {
                  AudioService.instance.playClick();
                  setState(() => _isRegister = !_isRegister);
                },
              ),
              if (!_isRegister)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: _busy != null
                        ? null
                        : () {
                            AudioService.instance.playClick();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext _) =>
                                    const ForgotPasswordPage(),
                              ),
                            );
                          },
                    child: const Text(
                      '忘記密碼？',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MatchdayPalette.ink,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const _GuestNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            tooltip: '返回',
            onPressed: () {
              AudioService.instance.playClick();
              onBack();
            },
            icon: const Icon(Icons.arrow_back, color: MatchdayPalette.ink),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'SIGN IN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'JOIN THE MATCH.',
                style: TextStyle(
                  fontSize: 56,
                  height: 0.95,
                  letterSpacing: -2,
                  fontWeight: FontWeight.w900,
                  color: MatchdayPalette.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Email / Google / Facebook / GitHub 登入會寫入 MongoDB 雲端帳號。',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButtons extends StatelessWidget {
  final AuthProvider? busy;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onGitHub;

  const _SocialButtons({
    required this.busy,
    required this.onGoogle,
    required this.onFacebook,
    required this.onGitHub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: <Widget>[
          _SocialPillButton(
            label: '使用 Google 登入',
            iconChild: SvgPicture.asset(
              'assets/images/google_logo.svg',
              width: 22,
              height: 22,
            ),
            iconBg: Colors.white,
            background: Colors.white,
            foreground: MatchdayPalette.ink,
            border: MatchdayPalette.ink,
            loading: busy == AuthProvider.google,
            disabled: busy != null && busy != AuthProvider.google,
            onTap: onGoogle,
          ),
          const SizedBox(height: 12),
          _SocialPillButton(
            label: '使用 Facebook 登入',
            icon: Icons.facebook,
            iconBg: const Color(0xFF1877F2),
            iconColor: Colors.white,
            background: const Color(0xFF1877F2),
            foreground: Colors.white,
            border: const Color(0xFF1877F2),
            loading: busy == AuthProvider.facebook,
            disabled: busy != null && busy != AuthProvider.facebook,
            onTap: onFacebook,
          ),
          const SizedBox(height: 12),
          _SocialPillButton(
            label: '使用 GitHub 登入',
            iconChild: SvgPicture.asset(
              'assets/images/github_logo.svg',
              width: 22,
              height: 22,
            ),
            iconBg: const Color(0xFF24292F),
            background: const Color(0xFF24292F),
            foreground: Colors.white,
            border: const Color(0xFF24292F),
            loading: busy == AuthProvider.github,
            disabled: busy != null && busy != AuthProvider.github,
            onTap: onGitHub,
          ),
        ],
      ),
    );
  }
}

class _SocialPillButton extends StatelessWidget {
  final String label;
  final Widget? iconChild;
  final IconData? icon;
  final Color iconBg;
  final Color? iconColor;
  final Color background;
  final Color foreground;
  final Color border;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  const _SocialPillButton({
    required this.label,
    this.iconChild,
    this.icon,
    required this.iconBg,
    this.iconColor,
    required this.background,
    required this.foreground,
    required this.border,
    required this.loading,
    required this.disabled,
    required this.onTap,
  }) : assert(iconChild != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1.5),
        ),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: iconChild ??
                      Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(foreground),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward,
                    color: foreground,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 1,
              color: MatchdayPalette.ink.withValues(alpha: 0.2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: MatchdayPalette.ink.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController passwordCtrl;
  final bool isRegister;
  final bool busy;
  final bool anyBusy;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;

  const _EmailFormCard({
    required this.formKey,
    required this.emailCtrl,
    required this.nameCtrl,
    required this.passwordCtrl,
    required this.isRegister,
    required this.busy,
    required this.anyBusy,
    required this.onSubmit,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipPath(
        clipper: const MatchdayAngleCornerClipper(
          cut: 28,
          corner: MatchdayCorner.topRight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: MatchdayPalette.cream,
            border: Border.all(color: MatchdayPalette.ink, width: 2),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  isRegister ? 'REGISTER' : 'EMAIL',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: MatchdayPalette.ink,
                  ),
                ),
                const SizedBox(height: 10),
                if (isRegister) ...<Widget>[
                  _PlainInput(
                    controller: nameCtrl,
                    hint: '遊戲暱稱（全站唯一，2～32 字）',
                    textInputAction: TextInputAction.next,
                    enabled: !anyBusy,
                    validator: NicknameUtils.validate,
                  ),
                  const SizedBox(height: 10),
                ],
                _PlainInput(
                  controller: emailCtrl,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !anyBusy,
                  validator: (String? v) {
                    final String t = (v ?? '').trim();
                    if (t.isEmpty) return '請輸入 Email';
                    final RegExp re =
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                    if (!re.hasMatch(t)) return 'Email 格式不正確';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _PlainInput(
                  controller: passwordCtrl,
                  hint: '密碼（至少 6 碼）',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  enabled: !anyBusy,
                  validator: (String? v) {
                    final String t = v ?? '';
                    if (t.isEmpty) return '請輸入密碼';
                    if (isRegister && t.length < 6) return '密碼至少 6 碼';
                    return null;
                  },
                  onSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: anyBusy ? null : onToggleMode,
                  child: Text(
                    isRegister ? '已有帳號？改為登入' : '還沒有帳號？註冊',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MatchdayPalette.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: anyBusy ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: MatchdayPalette.ink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            isRegister
                                ? Icons.person_add_outlined
                                : Icons.login,
                            size: 18,
                          ),
                    label: Text(
                      busy
                          ? '處理中…'
                          : (isRegister ? '註冊 Email 帳號' : 'Email 登入'),
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

class _PlainInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _PlainInput({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    required this.enabled,
    this.obscureText = false,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MatchdayPalette.ink, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: MatchdayPalette.ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Colors.black38,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _GuestNote extends StatelessWidget {
  const _GuestNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(28, 4, 28, 0),
      child: Text(
        '開發時請保持後端 uvicorn 運行，且 .env 的 API_BASE_URL 要能被手機/simulator 連到。\n'
        '真機請改成 Mac 區網 IP，例如 http://192.168.x.x:3000',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: Colors.black45,
          height: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
