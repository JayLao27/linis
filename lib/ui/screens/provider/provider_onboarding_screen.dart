import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/provider_profile.dart';
import '../../../state/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/marketplace.dart';

const _govIdTypes = [
  'PhilSys National ID',
  'UMID',
  "Driver's License",
  'Passport',
  'Postal ID',
  "Voter's ID",
  'PRC ID',
];

/// Profile setup for new providers, and later edits. What it asks for depends
/// on the tier: companies submit registration and a business permit,
/// individuals a government ID.
class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key, this.editing = false});

  /// Editing an approved profile: saves without resubmitting for review.
  final bool editing;

  @override
  State<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  final _form = GlobalKey<FormState>();
  late ProviderProfile _p;
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _rate;
  late final TextEditingController _regNo;
  late final TextEditingController _crew;
  late final TextEditingController _years;
  final _equipmentInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _p = context.read<SessionController>().provider!;
    _name = TextEditingController(text: _p.displayName);
    _bio = TextEditingController(text: _p.bio);
    _rate = TextEditingController(
        text: _p.baseRate > 0 ? _p.baseRate.toStringAsFixed(0) : '');
    _regNo = TextEditingController(text: _p.businessRegNo ?? '');
    _crew = TextEditingController(text: _p.crewSize > 0 ? '${_p.crewSize}' : '');
    _years = TextEditingController(
        text: _p.yearsExperience > 0 ? '${_p.yearsExperience}' : '');
  }

  @override
  void dispose() {
    for (final c in [_name, _bio, _rate, _regNo, _crew, _years, _equipmentInput]) {
      c.dispose();
    }
    super.dispose();
  }

  ProviderProfile _collect() => _p.copyWith(
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        baseRate: double.tryParse(_rate.text) ?? 0,
        businessName: _p.isCompany ? _name.text.trim() : null,
        businessRegNo: _regNo.text.trim(),
        crewSize: int.tryParse(_crew.text) ?? 0,
        yearsExperience: int.tryParse(_years.text) ?? 0,
      );

  Future<void> _save({required bool submit}) async {
    if (submit && !_form.currentState!.validate()) return;
    final backend = context.read<Backend>();
    final nav = Navigator.of(context);
    final ok = await runGuarded(
      context,
      () => backend.providers.saveProfile(_collect(), submit: submit),
      success: submit
          ? 'Submitted! We\'ll check your documents and notify you.'
          : 'Saved.',
    );
    if (ok && widget.editing) nav.pop();
  }

  Future<void> _pickAreas() async {
    final psgc = context.read<Backend>().psgc;
    final all = await psgc.davaoCityBarangays();
    if (!mounted) return;
    final current = all.where((b) => _p.serviceAreas.contains(b.code)).toSet();
    final picked = await showMultiPlacePicker(context,
        title: 'Service areas',
        places: all,
        initial: current,
        max: Business.maxServiceAreas);
    if (picked == null) return;
    final sorted = picked.toList()..sort((a, b) => a.name.compareTo(b.name));
    setState(() => _p = _p.copyWith(
          serviceAreas: sorted.map((b) => b.code).toList(),
          serviceAreaNames: sorted.map((b) => b.name).toList(),
        ));
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final live = session.provider!;
    final scheme = Theme.of(context).colorScheme;
    final pricing = context.read<Backend>().pricing;
    final rate = double.tryParse(_rate.text) ?? 0;
    const gap = SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Edit profile' : 'Set up your profile'),
        actions: [
          if (!widget.editing)
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: session.signOut,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (live.verificationStatus == VerificationStatus.rejected) ...[
              NoticeBanner(
                icon: Icons.error_outline_rounded,
                color: LinisColors.danger,
                text: 'Your last submission needs changes: '
                    '${live.rejectionReason ?? ''}',
              ),
              const SizedBox(height: 16),
            ] else if (!widget.editing) ...[
              NoticeBanner(
                icon: Icons.verified_user_outlined,
                color: LinisColors.brand,
                text: _p.isCompany
                    ? 'Linis checks every company\'s registration and permit '
                        'by hand before it appears to customers.'
                    : 'Linis checks every cleaner\'s government ID by hand '
                        'before they appear to customers.',
              ),
              const SizedBox(height: 16),
            ],
            Row(children: [
              TierBadge(_p.tier),
              const Spacer(),
              Text('Commission: ${(_p.tier.commissionRate * 100).round()}% per job',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
            ]),
            const SizedBox(height: 12),
            ImageUploadField(
              label: _p.isCompany ? 'Company logo' : 'Profile photo',
              url: _p.photoUrl,
              folder: 'profile',
              hint: 'A clear photo builds trust',
              onUploaded: (url) => setState(() => _p = _p.copyWith(photoUrl: url)),
            ),
            gap,
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: _p.isCompany ? 'Registered business name' : 'Display name'),
              validator: _required,
            ),
            gap,
            TextFormField(
              controller: _bio,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'About you',
                hintText: 'Experience, what you bring, what you\'re great at',
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Verification documents'),
            if (_p.isCompany) ...[
              TextFormField(
                controller: _regNo,
                decoration: const InputDecoration(
                    labelText: 'DTI / SEC registration no.',
                    prefixIcon: Icon(Icons.numbers_rounded)),
                validator: _required,
              ),
              gap,
              ImageUploadField(
                label: 'Business / Mayor\'s permit',
                url: _p.permitUrl,
                folder: 'permits',
                onUploaded: (url) =>
                    setState(() => _p = _p.copyWith(permitUrl: url)),
              ),
              gap,
              TextFormField(
                controller: _crew,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Crew size',
                    prefixIcon: Icon(Icons.groups_outlined)),
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter crew size',
              ),
              gap,
              _EquipmentEditor(
                equipment: _p.equipment,
                controller: _equipmentInput,
                onChanged: (list) =>
                    setState(() => _p = _p.copyWith(equipment: list)),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _p.govIdType,
                decoration: const InputDecoration(
                    labelText: 'Government ID type',
                    prefixIcon: Icon(Icons.badge_outlined)),
                items: [
                  for (final t in _govIdTypes)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _p = _p.copyWith(govIdType: v)),
                validator: (v) => v == null ? 'Pick your ID type' : null,
              ),
              gap,
              ImageUploadField(
                label: 'Photo of your ID',
                url: _p.govIdUrl,
                folder: 'ids',
                hint: 'Front side, all four corners visible',
                onUploaded: (url) =>
                    setState(() => _p = _p.copyWith(govIdUrl: url)),
              ),
              gap,
              TextFormField(
                controller: _years,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Years of cleaning experience',
                    prefixIcon: Icon(Icons.work_history_outlined)),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Enter a number' : null,
              ),
            ],
            const SizedBox(height: 20),
            const SectionTitle('Services you offer'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in ServiceType.values)
                  if (_p.isCompany || !s.companyOnly)
                    FilterChip(
                      avatar: Icon(serviceIcon(s), size: 18),
                      label: Text(s.label),
                      selected: _p.offers(s),
                      onSelected: (on) => setState(() {
                        final list = [..._p.servicesOffered];
                        on ? list.add(s) : list.remove(s);
                        _p = _p.copyWith(servicesOffered: list);
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionTitle('Your rate'),
            TextFormField(
              controller: _rate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Base rate (₱)',
                helperText: 'Price for a regular clean of a studio. Other jobs '
                    'scale from this.',
                prefixText: '₱ ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) >= 100
                  ? null
                  : 'Enter at least ₱100',
            ),
            if (rate > 0) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customers will see',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      for (final s in _p.servicesOffered)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(child: Text(s.label)),
                              Text(pesoRange(
                                pricing.quote(
                                    baseRate: rate,
                                    service: s,
                                    size: HomeSize.studio),
                                pricing.quote(
                                    baseRate: rate,
                                    service: s,
                                    size: HomeSize.large),
                              )),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SectionTitle('Service areas',
                trailing: Text(
                    '${_p.serviceAreas.length}/${Business.maxServiceAreas}',
                    style: TextStyle(color: scheme.onSurfaceVariant))),
            Text('Barangays in Davao City where you take jobs. Requests from '
                'these barangays will reach you.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _p.serviceAreas.length; i++)
                  InputChip(
                    label: Text(_p.serviceAreaNames.length > i
                        ? _p.serviceAreaNames[i]
                        : _p.serviceAreas[i]),
                    onDeleted: () => setState(() {
                      final codes = [..._p.serviceAreas]..removeAt(i);
                      final names = [..._p.serviceAreaNames]..removeAt(i);
                      _p = _p.copyWith(
                          serviceAreas: codes, serviceAreaNames: names);
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add barangays'),
                  onPressed: _pickAreas,
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (widget.editing)
              AsyncButton(
                  label: 'Save changes', onPressed: () => _save(submit: false))
            else ...[
              AsyncButton(
                label: 'Submit for verification',
                icon: Icons.send_rounded,
                onPressed: () => _save(submit: true),
              ),
              const SizedBox(height: 10),
              AsyncButton(
                  label: 'Save draft',
                  outlined: true,
                  onPressed: () => _save(submit: false)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EquipmentEditor extends StatelessWidget {
  const _EquipmentEditor({
    required this.equipment,
    required this.controller,
    required this.onChanged,
  });
  final List<String> equipment;
  final TextEditingController controller;
  final ValueChanged<List<String>> onChanged;

  void _add() {
    final v = controller.text.trim();
    if (v.isEmpty || equipment.contains(v)) return;
    onChanged([...equipment, v]);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Equipment',
              hintText: 'e.g. Industrial vacuum',
              prefixIcon: const Icon(Icons.handyman_outlined),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.add_rounded), onPressed: _add),
            ),
            onSubmitted: (_) => _add(),
          ),
          if (equipment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in equipment)
                  InputChip(
                    label: Text(e),
                    onDeleted: () =>
                        onChanged(equipment.where((x) => x != e).toList()),
                  ),
              ],
            ),
          ],
        ],
      );
}
