import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/backend.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/review.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/marketplace.dart';
import '../../widgets/sheets.dart';
import '../provider/provider_onboarding_screen.dart';
import 'provider_profile_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final backend = context.read<Backend>();
    final user = session.user!;
    final provider = session.provider;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Avatar(
                      name: provider?.displayName ?? user.fullName,
                      url: provider?.photoUrl ?? user.photoUrl,
                      size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider?.displayName ?? user.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17)),
                        Text(user.email,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        if (provider != null)
                          Row(children: [
                            TierBadge(provider.tier),
                            const SizedBox(width: 8),
                            RatingBadge(
                                avg: provider.ratingAvg,
                                count: provider.ratingCount,
                                compact: true),
                          ])
                        else if (user.role == UserRole.customer)
                          RatingBadge(
                              avg: user.ratingAvg, count: user.ratingCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (user.role != UserRole.provider)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit name & phone'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editProfile(context),
                  ),
                if (user.role != UserRole.provider)
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Profile photo'),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ImageUploadField(
                        label: 'Photo',
                        url: user.photoUrl,
                        folder: 'profile',
                        onUploaded: (url) => backend.users
                            .updateProfile(user.uid, photoUrl: url),
                      ),
                    ),
                  ),
                if (provider != null) ...[
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('View public profile'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProviderProfileScreen(
                            providerId: provider.uid, showBookButton: false))),
                  ),
                  ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('Edit rates, services & areas'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            const ProviderOnboardingScreen(editing: true))),
                  ),
                ],
                if (user.role == UserRole.customer)
                  ListTile(
                    leading: const Icon(Icons.reviews_outlined),
                    title: const Text('Reviews from cleaners'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _MyReviewsScreen(uid: user.uid))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text('Log out', style: TextStyle(color: scheme.error)),
              onTap: () async {
                if (await confirmDialog(context,
                    title: 'Log out?',
                    message: backend.isDemo
                        ? 'Demo data stays until the app restarts.'
                        : 'You can log back in anytime.',
                    confirmLabel: 'Log out')) {
                  await session.signOut();
                }
              },
            ),
          ),
          if (backend.isDemo) ...[
            const SizedBox(height: 16),
            Text('Demo mode · in-memory data',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final session = context.read<SessionController>();
    final backend = context.read<Backend>();
    final user = session.user!;
    final name = TextEditingController(text: user.fullName);
    final phone = TextEditingController(text: user.phone);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      await runGuarded(
          context,
          () => backend.users.updateProfile(user.uid,
              fullName: name.text, phone: phone.text),
          success: 'Profile updated.');
    }
  }
}

class _MyReviewsScreen extends StatelessWidget {
  const _MyReviewsScreen({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews from cleaners')),
      body: StreamBuilder<List<Review>>(
        stream: backend.reviews.watchFor(uid),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.reviews_outlined,
                title: 'No reviews yet',
                message: 'Cleaners rate you after each completed job.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => ReviewTile(review: list[i]),
          );
        },
      ),
    );
  }
}
