import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/app_notification.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';
import 'booking_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final uid = context.read<SessionController>().uid;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => backend.notifications.markAllRead(uid),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: backend.notifications.watch(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message: 'Booking updates and ratings will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = items[i];
              return Card(
                color: n.read
                    ? null
                    : scheme.primaryContainer.withValues(alpha: 0.35),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      n.bookingId != null
                          ? Icons.event_note_rounded
                          : Icons.campaign_rounded,
                      color: scheme.primary,
                    ),
                  ),
                  title: Text(n.title,
                      style: TextStyle(
                          fontWeight:
                              n.read ? FontWeight.w500 : FontWeight.w700)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(n.body),
                  ),
                  trailing: n.createdAt == null
                      ? null
                      : Text(timeAgo(n.createdAt!),
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                  onTap: () {
                    if (!n.read) backend.notifications.markRead(n.id);
                    if (n.bookingId != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              BookingDetailScreen(bookingId: n.bookingId!)));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bottom-nav icon with a live unread count.
class NotificationBadgeIcon extends StatelessWidget {
  const NotificationBadgeIcon({super.key, this.selected = false});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final uid = context.read<SessionController>().uid;
    return StreamBuilder<int>(
      stream: backend.notifications.watchUnreadCount(uid),
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return Badge(
          isLabelVisible: n > 0,
          label: Text(n > 9 ? '9+' : '$n'),
          child: Icon(selected
              ? Icons.notifications_rounded
              : Icons.notifications_none_rounded),
        );
      },
    );
  }
}
