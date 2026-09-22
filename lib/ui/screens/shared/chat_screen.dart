import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/chat_message.dart';
import '../../../state/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

const _providerQuickReplies = [
  "I'm on my way",
  'Running about 15 minutes late',
  "I've arrived",
  'All done! Please check and confirm the job.',
];

const _customerQuickReplies = [
  'The gate is open',
  'Please call when you arrive',
  'Thank you!',
];

/// Conversation between a booking's customer and its provider.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return StreamBuilder<Booking?>(
      stream: backend.bookings.watch(bookingId),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        return _ChatView(booking: b);
      },
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.booking});
  final Booking booking;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void didUpdateWidget(_ChatView old) {
    super.didUpdateWidget(old);
    // New message arrived while the chat is open.
    if (old.booking.lastMessageAt != widget.booking.lastMessageAt) _markRead();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _markRead() {
    final session = context.read<SessionController>();
    context.read<Backend>().chat.markRead(widget.booking, session.uid);
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _text.text;
    if (text.trim().isEmpty || _sending) return;
    final session = context.read<SessionController>();
    final backend = context.read<Backend>();
    final b = widget.booking;
    setState(() => _sending = true);
    final ok = await runGuarded(
      context,
      () => backend.chat.send(
        bookingId: b.id,
        senderId: session.uid,
        senderName: session.uid == b.customerId
            ? session.user!.fullName
            : (session.provider?.displayName ?? session.user!.fullName),
        text: text,
      ),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok && preset == null) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final uid = context.read<SessionController>().uid;
    final isCustomer = uid == b.customerId;
    final otherName =
        isCustomer ? (b.providerName ?? 'Your cleaner') : b.customerName;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar(name: otherName, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                      '${b.serviceType.label} · '
                      '${formatShortDate(b.scheduledDate)}, ${b.timeSlot}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: context.read<Backend>().chat.watch(b.id),
              builder: (context, snap) {
                final msgs = snap.data ?? const <ChatMessage>[];
                if (snap.hasData && msgs.isEmpty) {
                  return EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Say hi to $otherName',
                    message: isCustomer
                        ? 'Share gate codes, parking tips or anything the '
                            'cleaner should know.'
                        : 'Confirm the visit or ask about the home before '
                            'you go.',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final index = msgs.length - 1 - i;
                    final m = msgs[index];
                    final prev = index > 0 ? msgs[index - 1] : null;
                    final showDay = m.createdAt != null &&
                        (prev?.createdAt == null ||
                            !_sameDay(prev!.createdAt!, m.createdAt!));
                    return Column(
                      children: [
                        if (showDay) _DayLabel(date: m.createdAt!),
                        _Bubble(
                          message: m,
                          mine: m.senderId == uid,
                          groupedWithPrevious: !showDay &&
                              prev?.senderId == m.senderId,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (b.canChat)
            _Composer(
              controller: _text,
              sending: _sending,
              quickReplies:
                  isCustomer ? _customerQuickReplies : _providerQuickReplies,
              onSend: _send,
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NoticeBanner(
                  icon: Icons.lock_outline_rounded,
                  color: scheme.onSurfaceVariant,
                  text: 'This booking is ${b.status.label.toLowerCase()}. '
                      'The conversation is read-only.',
                ),
              ),
            ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final label = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : formatDate(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.groupedWithPrevious,
  });
  final ChatMessage message;
  final bool mine;
  final bool groupedWithPrevious;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? LinisColors.brand : scheme.surfaceContainerHigh;
    final fg = mine ? Colors.white : scheme.onSurface;
    const r = Radius.circular(18);
    const tight = Radius.circular(6);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: EdgeInsets.only(top: groupedWithPrevious ? 3 : 10),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: r,
              topRight: r,
              bottomLeft: mine ? r : tight,
              bottomRight: mine ? tight : r,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(message.text,
                  style: TextStyle(color: fg, fontSize: 15, height: 1.3)),
              const SizedBox(height: 3),
              Text(
                message.createdAt == null
                    ? 'Sending…'
                    : DateFormat('h:mm a').format(message.createdAt!),
                style: TextStyle(
                    color: fg.withValues(alpha: 0.7), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.quickReplies,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final List<String> quickReplies;
  final Future<void> Function([String? preset]) onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                itemCount: quickReplies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(quickReplies[i]),
                  onPressed: sending ? null : () => onSend(quickReplies[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: ChatMessage.maxLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        counterText: '',
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: sending ? null : () => onSend(),
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
