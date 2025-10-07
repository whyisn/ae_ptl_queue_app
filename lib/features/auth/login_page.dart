import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils.dart';
import '../../core/supabase_client.dart';
import '../../state/auth_provider.dart';
import 'widgets/auth_logo.dart';
import 'widgets/email_field.dart';
import 'widgets/password_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    // Prefill email jika pernah disimpan
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthController>();
      final remembered = await auth.getRememberedEmail();
      if (remembered != null && mounted) {
        setState(() {
          _emailC.text = remembered;
          _remember = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = await auth.login(
      _emailC.text.trim(),
      _passC.text,
      remember: _remember,
    );
    if (!ok && mounted) {
      showSnack(context, auth.error ?? 'Login gagal', error: true);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailC.text.trim();
    if (email.isEmpty) {
      showSnack(context, 'Masukkan email terlebih dahulu', error: true);
      return;
    }
    try {
      await supa.auth.resetPasswordForEmail(
        email,
        redirectTo: kAuthRedirectUri,
      );
      if (!mounted) return;
      showSnack(context, 'Email reset password telah dikirim ke $email');
    } on AuthException catch (e) {
      showSnack(context, e.message, error: true);
    } catch (e) {
      showSnack(context, 'Gagal mengirim email reset: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AuthLogo(),
                const SizedBox(height: 16),
                Text(
                  'Selamat datang 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          EmailField(controller: _emailC),
                          const SizedBox(height: 12),
                          PasswordField(controller: _passC),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _remember,
                                onChanged:
                                    (v) =>
                                        setState(() => _remember = v ?? false),
                              ),
                              const Text('Simpan akun'),
                              const Spacer(),
                              TextButton(
                                onPressed:
                                    auth.loading ? null : _forgotPassword,
                                child: const Text('Lupa password?'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: auth.loading ? null : _doLogin,
                              child:
                                  auth.loading
                                      ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('Masuk'),
                            ),
                          ),
                          if (auth.error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              auth.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gunakan email & password yang terdaftar.\nHubungi admin bila mengalami kendala.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
