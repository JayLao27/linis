import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/address.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/provider_profile.dart';
import '../../../state/booking_draft.dart';
import '../../../state/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/marketplace.dart';
import '../shared/booking_detail_screen.dart';
import '../shared/provider_profile_screen.dart';

/// Service → schedule → address → cleaner → review. The estimate in the
/// bottom bar follows every change.
class BookingFlowScreen extends StatelessWidget {
  const BookingFlowScreen({super.key, this.service, this.provider});
  final ServiceType? service;
  final ProviderProfile? provider;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (ctx) => BookingDraft(ctx.read<Backend>(),
            service: service, provider: provider),
        child: _BookingFlow(initialProvider: provider),
      );
}

class _BookingFlow extends StatefulWidget {
  const _BookingFlow({this.initialProvider});
  final ProviderProfile? initialProvider;

  @override
  State<_BookingFlow> createState() => _BookingFlowState();
}

class _BookingFlowState extends State<_BookingFlow> {
  final _page = PageController();
  final _forms = List.generate(5, (_) => GlobalKey<FormState>());
  int _step = 0;

  static const _titles = [
    'What needs cleaning?',
    'When should we come?',
    'Where is your home?',
    'Choose your cleaner',
    'Review & confirm',
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _page.animateToPage(step,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _next() async {
    if (!(_forms[_step].currentState?.validate() ?? true)) return;
    if (_step < _titles.length - 1) {
      _go(_step + 1);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    final draft = context.read<BookingDraft>();
    final backend = context.read<Backend>();
    final user = context.read<SessionController>().user!;
    final nav = Navigator.of(context);
    final problem = draft.problem;
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    String? id;
    final ok = await runGuarded(context, () async {
      id = await backend.bookings.create(draft.toBooking(user));
    });
    if (ok && id != null) {
      nav.pushReplacement(MaterialPageRoute(
          builder: (_) => BookingDetailScreen(bookingId: id!)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(draft.recurrence.isRecurring
              ? 'Plan request sent. Your cleaner commits to all '
                  '${draft.totalVisits} visits when they accept.'
              : draft.chosenProvider != null
              ? 'Request sent to ${draft.chosenProvider!.displayName}.'
              : 'Request sent to cleaners in ${draft.address!.barangay.name}.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_step]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / _titles.length,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        body: PageView(
          controller: _page,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ServiceStep(formKey: _forms[0]),
            _ScheduleStep(formKey: _forms[1]),
            _AddressStep(formKey: _forms[2]),
            _ProviderStep(
                formKey: _forms[3], initialProvider: widget.initialProvider),
            _ReviewStep(formKey: _forms[4], onEdit: _go),
          ],
        ),
        bottomNavigationBar: _EstimateBar(
          step: _step,
          last: _step == _titles.length - 1,
          onNext: _next,
        ),
      ),
    );
  }
}

class _EstimateBar extends StatelessWidget {
  const _EstimateBar({
    required this.step,
    required this.last,
    required this.onNext,
  });
  final int step;
  final bool last;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<BookingDraft>();
    final est = draft.estimate;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${draft.chosenProvider != null ? 'Price' : 'Estimated price'}'
                      '${draft.recurrence.isRecurring ? ' per visit' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      pesoRange(est.min, est.max),
                      key: ValueKey('${est.min}-${est.max}'),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            AsyncButton(
              expand: false,
              label: last ? 'Send request' : 'Next',
              icon: last ? Icons.send_rounded : null,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ steps

class _StepBody extends StatelessWidget {
  const _StepBody({required this.formKey, required this.children});
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: children,
        ),
      );
}

class _ServiceStep extends StatelessWidget {
  const _ServiceStep({required this.formKey});
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<BookingDraft>();
    final scheme = Theme.of(context).colorScheme;
    final chosen = draft.chosenProvider;
    return _StepBody(
      formKey: formKey,
      children: [
        if (chosen != null) ...[
          NoticeBanner(
            icon: Icons.person_pin_rounded,
            color: LinisColors.brand,
            text: 'Booking ${chosen.displayName}. Services they don\'t offer '
                'will send your request to other cleaners instead.',
          ),
          const SizedBox(height: 16),
        ],
        const SectionTitle('Service type'),
        for (final s in ServiceType.values) ...[
          _SelectTile(
            selected: draft.serviceType == s,
            icon: serviceIcon(s),
            title: s.label,
            subtitle: s.companyOnly
                ? '${s.description} · companies only'
                : s.description,
            onTap: () => draft.setService(s),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const SectionTitle('Home size'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in HomeSize.values)
              ChoiceChip(
                label: Text(h.label),
                selected: draft.homeSize == h,
                onSelected: (_) => draft.setHomeSize(h),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Bigger homes and deeper cleans take longer, so they cost more. '
            'You\'ll see the exact price for each cleaner before sending.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
      ],
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({required this.formKey});
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<BookingDraft>();
    return _StepBody(
      formKey: formKey,
      children: [
        FormField<DateTime>(
          initialValue: draft.date,
          validator: (_) => draft.date == null ? 'Pick a date' : null,
          builder: (field) => PickerField(
            label: 'Date',
            icon: Icons.calendar_month_rounded,
            value: draft.date == null ? null : formatDate(draft.date!),
            errorText: field.errorText,
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: draft.date ?? now.add(const Duration(days: 1)),
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 60)),
                helpText: 'Cleaning date',
              );
              if (picked != null) {
                draft.setDate(picked);
                field.didChange(picked);
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        FormField<String>(
          initialValue: draft.timeSlot,
          validator: (_) => draft.timeSlot == null ? 'Pick a start time' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Start time'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3.2,
                children: [
                  for (final slot in kTimeSlots)
                    _SlotButton(
                      label: slot,
                      selected: draft.timeSlot == slot,
                      onTap: () {
                        draft.setTimeSlot(slot);
                        field.didChange(slot);
                      },
                    ),
                ],
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(field.errorText!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _FrequencyPicker(),
      ],
    );
  }
}

/// One-time or a recurring plan with the same cleaner.
class _FrequencyPicker extends StatelessWidget {
  const _FrequencyPicker();

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<BookingDraft>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('How often?'),
        for (final r in Recurrence.values) ...[
          _SelectTile(
            selected: draft.recurrence == r,
            icon: r.isRecurring ? Icons.repeat_rounded : Icons.event_rounded,
            title: r.isRecurring
                ? '${r.label} · save ${(r.discount * 100).round()}%'
                : r.label,
            subtitle: switch (r) {
              Recurrence.none => 'Just this date.',
              Recurrence.weekly => 'Same cleaner, same day and time each week.',
              Recurrence.biweekly => 'Same cleaner, every other week.',
            },
            onTap: () => draft.setRecurrence(r),
          ),
          const SizedBox(height: 8),
        ],
        if (draft.recurrence.isRecurring) ...[
          const SizedBox(height: 8),
          Text('Number of visits',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final n in Business.planVisitOptions)
                ChoiceChip(
                  label: Text('$n visits'),
                  selected: draft.totalVisits == n,
                  onSelected: (_) => draft.setTotalVisits(n),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You pay per visit. The next visit is booked automatically after '
            'each one, and you can skip a visit or end the plan anytime.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onPrimary : scheme.onSurface)),
        ),
      ),
    );
  }
}

class _AddressStep extends StatelessWidget {
  const _AddressStep({required this.formKey});
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    final draft = context.read<BookingDraft>();
    return _StepBody(
      formKey: formKey,
      children: [
        FormField<Address>(
          initialValue: draft.address,
          validator: (_) => context.read<BookingDraft>().address == null
              ? 'Complete every field, including house no. and street'
              : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AddressForm(
                initial: draft.address,
                onChanged: (a) {
                  draft.setAddress(a);
                  field.didChange(a);
                },
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(field.errorText!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: draft.notes,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes for the cleaner (optional)',
            hintText: 'Gate code, pets, supplies you have…',
          ),
          onChanged: (v) => draft.notes = v,
        ),
      ],
    );
  }
}

class _ProviderStep extends StatelessWidget {
  const _ProviderStep({required this.formKey, this.initialProvider});
  final GlobalKey<FormState> formKey;
  final ProviderProfile? initialProvider;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<BookingDraft>();
    final scheme = Theme.of(context).colorScheme;
    final list = draft.visibleCandidates;
    final lostInitial = initialProvider != null &&
        draft.chosenProvider == null &&
        draft.address != null &&
        !draft.loadingCandidates;

    return _StepBody(
      formKey: formKey,
      children: [
        SegmentedButton<TierFilter>(
          showSelectedIcon: false,
          segments: [
            for (final t in TierFilter.values)
              ButtonSegment(
                value: t,
                label: Text(switch (t) {
                  TierFilter.any => 'Both',
                  TierFilter.company => 'Companies',
                  TierFilter.individual => 'Individuals',
                }),
                enabled: !(t == TierFilter.individual &&
                    draft.serviceType.companyOnly),
              ),
          ],
          selected: {draft.tierFilter},
          onSelectionChanged: (s) => draft.setTierFilter(s.first),
        ),
        const SizedBox(height: 8),
        Text(
          'Companies bring crews and equipment for big or heavy jobs. '
          'Individuals cost less for routine cleaning.',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (lostInitial) ...[
          NoticeBanner(
            icon: Icons.info_outline_rounded,
            color: LinisColors.warning,
            text: '${initialProvider!.displayName} doesn\'t cover '
                '${draft.address!.barangay.name} for this service. '
                'Pick another cleaner below.',
          ),
          const SizedBox(height: 12),
        ],
        _SelectTile(
          selected: draft.chosenProvider == null,
          icon: Icons.campaign_rounded,
          title: 'Send to all matching cleaners',
          subtitle: list.isEmpty
              ? 'No one here yet. We\'ll notify cleaners as they join.'
              : 'Sent to ${list.length} cleaner${list.length == 1 ? '' : 's'} '
                  'in ${draft.address?.barangay.name ?? 'your area'}. '
                  'First to accept gets the job.',
          onTap: () => draft.choose(null),
        ),
        const SizedBox(height: 16),
        SectionTitle(draft.loadingCandidates
            ? 'Finding cleaners…'
            : 'Or pick one (${list.length})'),
        if (draft.loadingCandidates)
          const Center(child: CircularProgressIndicator())
        else if (list.isEmpty)
          Text(
            'No ${draft.tierFilter == TierFilter.any ? '' : '${draft.tierFilter.label.toLowerCase().replaceAll(' only', '')} '}'
            'cleaners offer ${draft.serviceType.label.toLowerCase()} in '
            '${draft.address?.barangay.name ?? 'this area'} yet.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        for (final p in list) ...[
          ProviderCard(
            provider: p,
            quote: draft.quoteFor(p),
            selected: draft.chosenProvider?.uid == p.uid,
            onTap: () => draft.choose(p),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProviderProfileScreen(
                      providerId: p.uid, showBookButton: false))),
              child: const Text('View profile & reviews'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.formKey, required this.onEdit});
  final GlobalKey<FormState> formKey;
  final void Function(int step) onEdit;

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<BookingDraft>();
    final scheme = Theme.of(context).colorScheme;
    final est = draft.estimate;
    final p = draft.chosenProvider;

    Widget row(String label, String value, int step) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          subtitle: Text(value,
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          trailing: TextButton(
              onPressed: () => onEdit(step), child: const Text('Edit')),
        );

    return _StepBody(
      formKey: formKey,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              children: [
                row('Service',
                    '${draft.serviceType.label} · ${draft.homeSize.label}', 0),
                row(
                    'When',
                    draft.date == null
                        ? '—'
                        : '${formatDate(draft.date!)}, ${draft.timeSlot ?? ''}',
                    1),
                if (draft.recurrence.isRecurring)
                  row(
                      'Repeats',
                      '${draft.recurrence.label} · ${draft.totalVisits} visits',
                      1),
                row('Where', draft.address?.fullLabel ?? '—', 2),
                row(
                    'Cleaner',
                    p?.displayName ??
                        'First available (${draft.tierFilter.label.toLowerCase()})',
                    3),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('Payment'),
        for (final m in PaymentMethod.values) ...[
          _SelectTile(
            selected: draft.paymentMethod == m,
            icon: m == PaymentMethod.gcash
                ? Icons.account_balance_wallet_rounded
                : Icons.payments_rounded,
            title: m.label,
            subtitle: m == PaymentMethod.gcash
                ? 'Pay after a cleaner accepts. Linis holds it until you '
                    'confirm the job is done.'
                : 'Pay the cleaner directly when the job is finished.',
            onTap: () => draft.setPaymentMethod(m),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Card(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.request_quote_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    [
                      p != null
                          ? '${draft.recurrence.isRecurring ? 'Per visit' : 'Total'}: '
                              '${peso(est.min)}. No extra fees for you.'
                          : 'Expected ${pesoRange(est.min, est.max)}'
                              '${draft.recurrence.isRecurring ? ' per visit' : ''} '
                              'depending on who accepts. You\'ll see the final '
                              'price before paying.',
                      if (draft.recurrence.isRecurring)
                        'Includes your ${(draft.recurrence.discount * 100).round()}% '
                            'plan discount.',
                    ].join(' '),
                    style: const TextStyle(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1),
      ),
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.25)
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
