import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/backend.dart';
import '../../../data/demo_seed.dart';
import '../../widgets/common.dart';
import '../../widgets/sheets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final backend = context.read<Backend>();
    final nav = Navigator.of(context);
    final ok = await runGuarded(
        context, () => backend.auth.signIn(_email.text, _password.text));
    if (ok) nav.popUntil((r) => r.isFirst);
  }

  Future<void> _forgot() async {
    final backend = context.read<Backend>();
    final email = _email.text.trim().isNotEmpty
        ? _email.text.trim()
        : await textInputDialog(context,
            title: 'Reset password', label: 'Email', confirmLabel: 'Send link');
    if (email == null || !mounted) return;
    await runGuarded(context, () => backend.auth.sendPasswordReset(email),
        success: 'Password reset link sent to $email.');
  }

  void _fill(String email) {
    _email.text = email;
    _password.text = DemoSeed.password;
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = context.read<Backend>().isDemo;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text('Welcome back',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Log in to book or manage your jobs.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 28),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) =>
                    (v ?? '').contains('@') ? null : 'Enter your email',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Enter your password' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _forgot, child: const Text('Forgot password?')),
              ),
              const SizedBox(height: 8),
              AsyncButton(label: 'Log in', onPressed: _submit),
              if (isDemo) ...[
                const SizedBox(height: 32),
                const SectionTitle('Try a demo account'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, email) in const [
                      ('Customer', DemoSeed.customerEmail),
                      ('Individual cleaner', DemoSeed.individualEmail),
                      ('Cleaning company', DemoSeed.companyEmail),
                      ('Pending cleaner', DemoSeed.pendingEmail),
                      ('Admin', DemoSeed.adminEmail),
                    ])
                      ActionChip(
                        label: Text(label),
                        onPressed: () => _fill(email),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Password for every demo account: ${DemoSeed.password}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
