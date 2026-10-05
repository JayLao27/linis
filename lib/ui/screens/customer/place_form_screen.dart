import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/backend.dart';
import '../../../data/models/address.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/saved_place.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

/// The form for a saved place. It adds a new place, or edits [place] if
/// one is given.
class PlaceFormScreen extends StatefulWidget {
  const PlaceFormScreen({super.key, this.place});
  final SavedPlace? place;

  @override
  State<PlaceFormScreen> createState() => _PlaceFormScreenState();
}

class _PlaceFormScreenState extends State<PlaceFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.place?.label ?? '');
  late final _notes = TextEditingController(text: widget.place?.notes ?? '');
  late HomeSize _size = widget.place?.homeSize ?? HomeSize.small;
  late Address? _address = widget.place?.address;
  late String? _imageUrl = widget.place?.imageUrl;

  /// Becomes true after the user taps save, so the photo and address
  /// errors only show after they have tried to save.
  bool _showErrors = false;

  bool get _isEditing => widget.place != null;

  @override
  void dispose() {
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Checks the form, then creates or updates the place.
  Future<void> _save() async {
    final fieldsValid = _form.currentState!.validate();
    setState(() => _showErrors = true);
    if (!fieldsValid || _address == null || _imageUrl == null) return;

    final backend = context.read<Backend>();
    final nav = Navigator.of(context);
    final place = SavedPlace(
      id: widget.place?.id ?? '',
      ownerId: context.read<SessionController>().uid,
      label: _label.text,
      homeSize: _size,
      address: _address!,
      imageUrl: _imageUrl!,
      notes: _notes.text,
    );
    final saved = await runGuarded(context, () async {
      if (_isEditing) {
        await backend.places.update(place);
      } else {
        await backend.places.create(place);
      }
    }, success: _isEditing ? 'Place updated.' : 'Place saved.');
    if (saved) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit place' : 'Add a place')),
      body: SafeArea(
        child: Form(
          key: _form,
          // A scroll view (not a lazy list) keeps every field built, so the
          // whole form is always checked when saving.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ImageUploadField(
                  label: 'Photo of the place',
                  hint: 'Tap to add a photo of the front or gate',
                  url: _imageUrl,
                  folder: 'places',
                  onUploaded: (url) => setState(() => _imageUrl = url),
                ),
                if (_showErrors && _imageUrl == null)
                  const _FieldError('Add a photo of this place.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _label,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: "e.g. Home, Mom's house, Rental condo",
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Give this place a name' : null,
                ),
                const SectionTitle('Home size'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final size in HomeSize.values)
                      ChoiceChip(
                        label: Text(size.label),
                        selected: _size == size,
                        onSelected: (_) => setState(() => _size = size),
                      ),
                  ],
                ),
                const SectionTitle('Address'),
                AddressForm(
                  initial: _address,
                  onChanged: (a) => setState(() => _address = a),
                ),
                if (_showErrors && _address == null)
                  const _FieldError(
                      'Complete every field, including house no. and street.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes for the cleaner (optional)',
                    hintText: 'Gate code, pets, where to park…',
                  ),
                ),
                const SizedBox(height: 8),
                Text('Only you can see your saved places.',
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                const SizedBox(height: 20),
                AsyncButton(
                  label: _isEditing ? 'Save changes' : 'Save place',
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small red error message shown under the photo or the address.
class _FieldError extends StatelessWidget {
  const _FieldError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Text(message,
            style: TextStyle(
                color: Theme.of(context).colorScheme.error, fontSize: 12)),
      );
}
