import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  /// false = sign in, true = create account
  bool _registerMode = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _mapAuthError(String? code) {
    switch (code) {
      case 'email-already-in-use':
        return 'هذا البريد مسجّل مسبقاً — سجّل الدخول أو استعد كلمة المرور';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
      case 'invalid-email':
        return 'صيغة البريد غير صحيحة';
      case 'network-request-failed':
        return 'تحقق من الاتصال بالإنترنت';
      default:
        return code == null || code.isEmpty
            ? 'تعذّر إنشاء الحساب'
            : 'تعذّر إنشاء الحساب ($code)';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    final bool ok;
    if (_registerMode) {
      ok = await auth.signUp(_email.text, _password.text);
    } else {
      ok = await auth.signIn(_email.text, _password.text);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      if (_registerMode) {
        showSnack(context, _mapAuthError(auth.error));
      } else {
        showSnack(context, t(context).invalidCredentials);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SvgPicture.asset(
                          'assets/brand/logo.svg',
                          width: 32,
                          height: 32,
                          colorFilter:
                              const ColorFilter.mode(kInk, BlendMode.srcIn),
                        ),
                        SegmentedButton<Locale>(
                          segments: const [
                            ButtonSegment(
                              value: Locale('ar'),
                              label: Text('عربي'),
                            ),
                            ButtonSegment(
                              value: Locale('en'),
                              label: Text('EN'),
                            ),
                          ],
                          selected: {lang.locale},
                          onSelectionChanged: (s) => lang.setLocale(s.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SvgPicture.asset(
                      'assets/brand/logo.svg',
                      width: 96,
                      height: 96,
                      colorFilter:
                          const ColorFilter.mode(kInk, BlendMode.srcIn),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _registerMode ? 'إنشاء حساب' : t(context).welcome,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _registerMode
                          ? 'أنشئ حساباً ثم اطلب من المالك ربطه بالمحل من شاشة الموظفين'
                          : t(context).welcomeSubtitle,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: t(context).email,
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty || !v.contains('@'))
                              ? t(context).required
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: t(context).password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? t(context).required
                          : (v.length < 6 ? t(context).passwordTooShort : null),
                    ),
                    if (_registerMode) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return t(context).required;
                          }
                          if (v != _password.text) {
                            return 'كلمتا المرور غير متطابقتين';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (!_registerMode) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () async {
                            await context
                                .read<AuthProvider>()
                                .sendPasswordReset(_email.text);
                            if (!context.mounted) return;
                            showSnack(context, t(context).settingsSaved);
                          },
                          child: Text(t(context).forgotPassword),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registerMode
                              ? 'إنشاء الحساب'
                              : t(context).signIn),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _registerMode = !_registerMode;
                              }),
                      child: Text(
                        _registerMode
                            ? 'لديك حساب؟ تسجيل الدخول'
                            : 'إنشاء حساب جديد',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
