import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/backend.dart';
import '../../../data/models/enums.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});
  final UserRole role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  ProviderTier _tier = ProviderTier.individual;
  bool _agree = false;

  bool get _isProvider => widget.role == UserRole.provider;
  bool get _isCompany => _isProvider && _tier == ProviderTier.company;

  @override
  void dispose() {
    for (final c in [_name, _business, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please agree to the terms to continue.')));
      return;
    }
    final backend = context.read<Backend>();
    final nav = Navigator.of(context);
    final ok = await runGuarded(
      context,
      () => backend.register(
        email: _email.text,
        password: _password.text,
        fullName: _name.text,
        phone: _phone.text,
        role: widget.role,
        tier: _isProvider ? _tier : null,
        businessName: _isCompany ? _business.text : null,
      ),
    );
    if (ok) nav.popUntil((r) => r.isFirst);
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(_isProvider ? 'Start earning with Linis' : 'Create your account',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                _isProvider
                    ? 'Get job requests from households in your barangays.'
                    : 'Book verified cleaners near you in a few taps.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              if (_isProvider) ...[
                Text('I am registering as',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final t in ProviderTier.values) ...[
                      Expanded(
                        child: _TierOption(
                          tier: t,
                          selected: _tier == t,
                          onTap: () => setState(() => _tier = t),
                        ),
                      ),
                      if (t != ProviderTier.values.last) const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (_isCompany) ...[
                TextFormField(
                  controller: _business,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Registered business name',
                      prefixIcon: Icon(Icons.business_outlined)),
                  validator: _required,
                ),
                gap,
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                    labelText: _isCompany ? 'Contact person' : 'Full name',
                    prefixIcon: const Icon(Icons.person_outline)),
                validator: _required,
              ),
              gap,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '09XX XXX XXXX',
                    prefixIcon: Icon(Icons.phone_outlined)),
                validator: (v) {
                  final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  return RegExp(r'^(09|639)\d{9}$').hasMatch(d)
                      ? null
                      : 'Enter a PH mobile number (09XX XXX XXXX)';
                },
              ),
              gap,
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch((v ?? '').trim())
                    ? null
                    : 'Enter a valid email',
              ),
              gap,
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 6 characters',
                    prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) =>
                    (v ?? '').length < 6 ? 'Use at least 6 characters' : null,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _agree,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _agree = v ?? false),
                title: Text(
                  _isProvider
                      ? 'I agree to the Terms, to have my documents verified, '
                          'and to Linis keeping a commission on completed jobs.'
                      : 'I agree to the Terms and Privacy Policy.',
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 12),
              AsyncButton(
                label: _isProvider ? 'Continue to verification' : 'Create account',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierOption extends StatelessWidget {
  const _TierOption({
    required this.tier,
    required this.selected,
    required this.onTap,
  });
  final ProviderTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCompany = tier == ProviderTier.company;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.5)
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isCompany ? Icons.business_rounded : Icons.person_rounded,
                color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(isCompany ? 'Cleaning company' : 'Individual cleaner',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
                isCompany
                    ? 'Registered business with crew & equipment'
                    : 'Independent cleaner with a valid ID',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
