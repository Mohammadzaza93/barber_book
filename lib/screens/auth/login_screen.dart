import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
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
  bool _isRegister = false;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    final ok = _isRegister
        ? await auth.register(_email.text, _password.text)
        : await auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      showSnack(context, t(context).invalidCredentials);
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
                        const Icon(Icons.content_cut_rounded,
                            size: 32, color: Color(0xFF0F172A)),
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
                          onSelectionChanged: (s) =>
                              lang.setLocale(s.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Icon(Icons.content_cut_rounded,
                        size: 64, color: Color(0xFF2563EB)),
                    const SizedBox(height: 12),
                    Text(
                      _isRegister
                          ? t(context).registerTitle
                          : t(context).welcome,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t(context).welcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
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
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? t(context).required
                          : (v.length < 6
                              ? t(context).passwordTooShort
                              : null),
                    ),
                    if (_isRegister) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: t(context).confirmPassword,
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) => v != _password.text
                            ? t(context).passwordsDontMatch
                            : null,
                      ),
                    ],
                    if (!_isRegister) ...[
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
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegister
                              ? t(context).createAccount
                              : t(context).signIn),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister
                            ? t(context).alreadyHaveAccount
                            : t(context).needAccount,
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
