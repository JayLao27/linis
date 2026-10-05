import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/backend.dart';
import '../../../data/models/saved_place.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/sheets.dart';
import 'place_form_screen.dart';

/// Shows the customer's saved places. From here they can add, edit and
/// delete a place.
class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});

  /// Opens the form. With a [place] it edits it, without one it adds a new one.
  void _openForm(BuildContext context, [SavedPlace? place]) =>
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlaceFormScreen(place: place)));

  /// Asks the user to confirm, then deletes the place.
  Future<void> _delete(BuildContext context, SavedPlace place) async {
    final backend = context.read<Backend>();
    final confirmed = await confirmDialog(
      context,
      title: 'Delete "${place.label}"?',
      message: 'This removes the place and its photo from your account.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await runGuarded(context, () => backend.places.delete(place.id),
        success: 'Place deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final uid = context.read<SessionController>().uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved places')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add place'),
      ),
      body: StreamBuilder<List<SavedPlace>>(
        stream: backend.places.watchFor(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load your places',
                message: 'Check your connection and try again.');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final places = snap.data!;
          if (places.isEmpty) {
            return const EmptyState(
                icon: Icons.home_work_outlined,
                title: 'No saved places yet',
                message: 'Add the homes you get cleaned, each with a photo '
                    'so your cleaner can spot it from the street.');
          }
          return ListView.separated(
            // Extra space at the bottom so the button does not cover a card.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PlaceCard(
              place: places[i],
              onEdit: () => _openForm(context, places[i]),
              onDelete: () => _delete(context, places[i]),
            ),
          );
        },
      ),
    );
  }
}

enum _PlaceAction { edit, delete }

/// A card for one place: its photo, its details, and an edit/delete menu.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedPlace place;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AppImage(url: place.imageUrl, placeholderLabel: 'Photo'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(place.address.fullLabel,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.straighten_rounded,
                                size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(place.homeSize.label,
                                style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (place.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(place.notes,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<_PlaceAction>(
                    tooltip: 'More',
                    onSelected: (action) => switch (action) {
                      _PlaceAction.edit => onEdit(),
                      _PlaceAction.delete => onDelete(),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: _PlaceAction.edit, child: Text('Edit')),
                      PopupMenuItem(
                          value: _PlaceAction.delete, child: Text('Delete')),
                    ],
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
