import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/backend.dart';
import '../../data/models/address.dart';
import '../../data/services/psgc_service.dart';
import 'common.dart';

/// Searchable single-choice list in a bottom sheet.
Future<PsgcPlace?> showPlacePicker(
  BuildContext context, {
  required String title,
  required List<PsgcPlace> places,
}) =>
    showModalBottomSheet<PsgcPlace>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlaceSearchSheet(title: title, places: places),
    );

/// Searchable multi-choice list in a bottom sheet. Returns null if dismissed.
Future<Set<PsgcPlace>?> showMultiPlacePicker(
  BuildContext context, {
  required String title,
  required List<PsgcPlace> places,
  required Set<PsgcPlace> initial,
  int? max,
}) =>
    showModalBottomSheet<Set<PsgcPlace>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlaceSearchSheet(
          title: title, places: places, multi: true, initial: initial, max: max),
    );

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({
    required this.title,
    required this.places,
    this.multi = false,
    this.initial = const {},
    this.max,
  });
  final String title;
  final List<PsgcPlace> places;
  final bool multi;
  final Set<PsgcPlace> initial;
  final int? max;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  String _query = '';
  late final Set<PsgcPlace> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final filtered =
        widget.places.where((p) => p.name.toLowerCase().contains(q)).toList();
    final atMax = widget.max != null && _selected.length >= widget.max!;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (widget.multi)
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text('Done (${_selected.length})'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: !widget.multi,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (widget.multi && widget.max != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text('Up to ${widget.max} areas',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                if (!widget.multi) {
                  return ListTile(
                    title: Text(p.name),
                    onTap: () => Navigator.pop(context, p),
                  );
                }
                final checked = _selected.contains(p);
                return CheckboxListTile(
                  value: checked,
                  title: Text(p.name),
                  onChanged: !checked && atMax
                      ? null
                      : (v) => setState(() =>
                          v! ? _selected.add(p) : _selected.remove(p)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only field that looks like a text input and opens a picker.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.errorText,
    this.loading = false,
  });
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? errorText;
  final bool loading;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon == null ? null : Icon(icon),
            errorText: errorText,
            enabled: onTap != null,
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : const Icon(Icons.expand_more_rounded),
          ),
          child: value == null ? null : Text(value!),
        ),
      );
}

/// Region → province → city → barangay from the PSGC API, then street.
/// Starts at Davao City. Calls [onChanged] with a complete address, or null
/// while something is missing.
class AddressForm extends StatefulWidget {
  const AddressForm({super.key, this.initial, required this.onChanged});
  final Address? initial;
  final ValueChanged<Address?> onChanged;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late PsgcService _psgc;
  late PsgcPlace _region;
  PsgcPlace? _province;
  PsgcPlace? _city;
  PsgcPlace? _barangay;
  late final TextEditingController _street;
  bool _hasProvinces = true;
  String? _loading;
  String? _error;

  @override
  void initState() {
    super.initState();
    _psgc = context.read<Backend>().psgc;
    final a = widget.initial;
    _region = a?.region ?? PsgcService.davaoRegion;
    _province = a != null ? a.province : PsgcService.davaoDelSur;
    _hasProvinces = _province != null;
    _city = a?.city ?? PsgcService.davaoCity;
    _barangay = a?.barangay;
    _street = TextEditingController(text: a?.street ?? '')
      ..addListener(_emit);
  }

  @override
  void dispose() {
    _street.dispose();
    super.dispose();
  }

  void _emit() {
    final ok = _city != null &&
        _barangay != null &&
        _street.text.trim().isNotEmpty &&
        (!_hasProvinces || _province != null);
    widget.onChanged(ok
        ? Address(
            region: _region,
            province: _province,
            city: _city!,
            barangay: _barangay!,
            street: _street.text.trim(),
          )
        : null);
  }

  Future<void> _pick(
    String level,
    Future<List<PsgcPlace>> Function() load,
    void Function(PsgcPlace) apply,
  ) async {
    setState(() {
      _loading = level;
      _error = null;
    });
    try {
      final places = await load();
      if (!mounted) return;
      setState(() => _loading = null);
      final picked =
          await showPlacePicker(context, title: 'Select $level', places: places);
      if (picked != null) {
        setState(() => apply(picked));
        _emit();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = null;
          _error = 'Could not load ${level}s. Check your connection.';
        });
      }
    }
  }

  Future<void> _pickRegion() => _pick('region', _psgc.regions, (r) {
        _region = r;
        _province = null;
        _city = null;
        _barangay = null;
        _checkProvinces(r);
      });

  /// NCR has no provinces; its cities hang directly off the region.
  Future<void> _checkProvinces(PsgcPlace region) async {
    try {
      final provinces = await _psgc.provinces(region.code);
      if (mounted && region == _region) {
        setState(() => _hasProvinces = provinces.isNotEmpty);
      }
    } catch (_) {
      // Keep the province picker; it shows its own error on tap.
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerField(
          label: 'Region',
          value: _region.name,
          icon: Icons.map_outlined,
          loading: _loading == 'region',
          onTap: _pickRegion,
        ),
        if (_hasProvinces) ...[
          gap,
          PickerField(
            label: 'Province',
            value: _province?.name,
            icon: Icons.terrain_outlined,
            loading: _loading == 'province',
            onTap: () => _pick('province', () => _psgc.provinces(_region.code),
                (p) {
              _province = p;
              _city = null;
              _barangay = null;
            }),
          ),
        ],
        gap,
        PickerField(
          label: 'City / municipality',
          value: _city?.name,
          icon: Icons.location_city_outlined,
          loading: _loading == 'city',
          onTap: _hasProvinces && _province == null
              ? null
              : () => _pick(
                      'city',
                      () => _psgc.cities(
                          provinceCode: _province?.code,
                          regionCode: _region.code), (c) {
                    _city = c;
                    _barangay = null;
                  }),
        ),
        gap,
        PickerField(
          label: 'Barangay',
          value: _barangay?.name,
          icon: Icons.holiday_village_outlined,
          loading: _loading == 'barangay',
          onTap: _city == null
              ? null
              : () => _pick('barangay', () => _psgc.barangays(_city!.code),
                  (b) => _barangay = b),
        ),
        gap,
        TextField(
          controller: _street,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'House no., street, building',
            hintText: 'e.g. Unit 4B, Palm Residences, Km. 7',
            prefixIcon: Icon(Icons.home_outlined),
          ),
        ),
        if (_error != null) ...[
          gap,
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

/// Picks a photo from the gallery/camera and uploads it (Cloudinary, or the
/// in-memory store in demo mode). Shows the current image.
class ImageUploadField extends StatefulWidget {
  const ImageUploadField({
    super.key,
    required this.label,
    required this.url,
    required this.folder,
    required this.onUploaded,
    this.hint,
  });
  final String label;
  final String? url;
  final String folder;
  final ValueChanged<String> onUploaded;
  final String? hint;

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  bool _uploading = false;

  Future<void> _pick() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    final uploads = context.read<Backend>().uploads;
    await runGuarded(context, () async {
      final url = await uploads.upload(file, folder: widget.folder);
      widget.onUploaded(url);
    });
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _uploading ? null : _pick,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 56,
                  child: widget.url == null
                      ? Container(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.add_a_photo_outlined,
                              color: scheme.onSurfaceVariant))
                      : AppImage(url: widget.url, placeholderLabel: 'On file'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      _uploading
                          ? 'Uploading…'
                          : widget.url == null
                              ? (widget.hint ?? 'Tap to upload a photo')
                              : 'Uploaded · tap to replace',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (_uploading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(
                  widget.url == null
                      ? Icons.upload_rounded
                      : Icons.check_circle_rounded,
                  color: widget.url == null ? scheme.onSurfaceVariant : scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
