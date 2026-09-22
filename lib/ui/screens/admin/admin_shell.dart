import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/ledger_entry.dart';
import '../../../data/models/provider_profile.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/marketplace.dart';
import '../../widgets/sheets.dart';
import '../shared/account_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            _VerificationQueue(),
            _CommissionScreen(),
            AccountScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.fact_check_outlined),
                activeIcon: Icon(Icons.fact_check_rounded),
                label: 'Verify'),
            BottomNavigationBarItem(
                icon: Icon(Icons.payments_outlined),
                activeIcon: Icon(Icons.payments_rounded),
                label: 'Commission'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Account'),
          ],
        ),
      );
}

class _VerificationQueue extends StatelessWidget {
  const _VerificationQueue();

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verification queue')),
      body: StreamBuilder<List<ProviderProfile>>(
        stream: backend.providers.watchByStatus(VerificationStatus.pending),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'All caught up',
              message: 'New provider applications will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = list[i];
              return ProviderCard(
                provider: p,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _VerificationDetail(provider: p))),
              );
            },
          );
        },
      ),
    );
  }
}

class _VerificationDetail extends StatelessWidget {
  const _VerificationDetail({required this.provider});
  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final p = provider;
    final docUrl = p.isCompany ? p.permitUrl : p.govIdUrl;

    return Scaffold(
      appBar: AppBar(title: Text(p.displayName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(children: [
            TierBadge(p.tier),
            const Spacer(),
            if (p.createdAt != null)
              Text('Applied ${timeAgo(p.createdAt!)}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 12),
          const SectionTitle('Document'),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: GestureDetector(
                onTap: docUrl == null
                    ? null
                    : () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: InteractiveViewer(
                                child: AppImage(url: docUrl, fit: BoxFit.contain)),
                          ),
                        ),
                child: AppImage(url: docUrl),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (p.isCompany) ...[
                    InfoRow(
                        icon: Icons.business_outlined,
                        label: 'Business',
                        value: p.businessName ?? '—'),
                    InfoRow(
                        icon: Icons.numbers_rounded,
                        label: 'Reg. no.',
                        value: p.businessRegNo ?? '—'),
                    InfoRow(
                        icon: Icons.groups_outlined,
                        label: 'Crew size',
                        value: '${p.crewSize}'),
                    InfoRow(
                        icon: Icons.handyman_outlined,
                        label: 'Equipment',
                        value: p.equipment.isEmpty ? '—' : p.equipment.join(', ')),
                  ] else ...[
                    InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'ID type',
                        value: p.govIdType ?? '—'),
                    InfoRow(
                        icon: Icons.work_history_outlined,
                        label: 'Experience',
                        value: '${p.yearsExperience} years'),
                  ],
                  InfoRow(
                      icon: Icons.phone_outlined, label: 'Phone', value: p.phone),
                  InfoRow(
                      icon: Icons.sell_outlined,
                      label: 'Base rate',
                      value: peso(p.baseRate)),
                  InfoRow(
                      icon: Icons.cleaning_services_outlined,
                      label: 'Services',
                      value: p.servicesOffered.map((s) => s.label).join(', ')),
                  InfoRow(
                      icon: Icons.map_outlined,
                      label: 'Areas',
                      value: p.serviceAreaNames.join(', ')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          NoticeBanner(
            icon: Icons.info_outline_rounded,
            color: LinisColors.brand,
            text: p.isCompany
                ? 'Check that the permit is current and the business name and '
                    'registration number match.'
                : 'Check that the ID is valid, readable, and the name matches '
                    'the account.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: AsyncButton(
                  label: 'Reject',
                  outlined: true,
                  color: LinisColors.danger,
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final reason = await textInputDialog(context,
                        title: 'Reason for rejection',
                        label: 'What should they fix?',
                        confirmLabel: 'Reject');
                    if (reason == null || !context.mounted) return;
                    final ok = await runGuarded(
                        context, () => backend.providers.reject(p.uid, reason),
                        success: '${p.displayName} was asked to resubmit.');
                    if (ok) nav.pop();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AsyncButton(
                  label: 'Approve',
                  icon: Icons.verified_rounded,
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final ok = await runGuarded(
                        context, () => backend.providers.approve(p.uid),
                        success: '${p.displayName} is now live.');
                    if (ok) nav.pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommissionScreen extends StatelessWidget {
  const _CommissionScreen();

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Commission')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          StreamBuilder<List<LedgerEntry>>(
            stream: backend.ledger.watchAll(),
            builder: (context, snap) {
              final entries = snap.data ?? const [];
              final earned = entries
                  .where((e) => e.type != LedgerType.settlement)
                  .fold<double>(0, (s, e) => s + e.commission);
              final collected = entries
                      .where((e) => e.type == LedgerType.settlement)
                      .fold<double>(0, (s, e) => s + e.amount) +
                  entries
                      .where((e) => e.type == LedgerType.gcashRelease)
                      .fold<double>(0, (s, e) => s + e.commission);
              return Row(
                children: [
                  Expanded(
                      child: _Stat(label: 'Commission earned', value: peso(earned))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Stat(label: 'Collected', value: peso(collected))),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const SectionTitle('Unsettled (cash jobs)'),
          StreamBuilder<List<ProviderProfile>>(
            stream: backend.providers.watchWithUnsettledCommission(),
            builder: (context, snap) {
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Every provider is settled up.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                );
              }
              return Column(
                children: [
                  for (final p in list) ...[
                    Card(
                      child: ListTile(
                        leading: Avatar(name: p.displayName, url: p.photoUrl),
                        title: Text(p.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(p.bookingsPaused
                            ? 'Over the ${peso(Business.unsettledCommissionCap)} cap: bookings paused'
                            : p.tier.label),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(peso(p.unsettledCommission),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: p.bookingsPaused
                                        ? LinisColors.danger
                                        : null)),
                            InkWell(
                              onTap: () async {
                                if (!await confirmDialog(context,
                                    title: 'Mark as settled?',
                                    message: 'Confirm you received '
                                        '${peso(p.unsettledCommission)} from '
                                        '${p.displayName} outside the app.',
                                    confirmLabel: 'Mark settled')) {
                                  return;
                                }
                                if (!context.mounted) return;
                                await runGuarded(
                                    context,
                                    () => backend.ledger.settle(p.uid,
                                        reference: 'ADMIN-MANUAL'),
                                    success: 'Recorded.');
                              },
                              child: Text('Mark settled',
                                  style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12.5)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}
