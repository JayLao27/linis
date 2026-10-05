import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/saved_place.dart';

/// Saves, loads, edits and deletes a customer's places in Firestore.
class PlaceRepository {
  PlaceRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('places');

  /// CREATE: adds a new place and returns its id.
  Future<String> create(SavedPlace place) async {
    _validate(place);
    final ref = await _col.add(place.toNewDocMap());
    return ref.id;
  }

  /// READ: the places owned by [ownerId], newest first. The list updates
  /// by itself whenever the data changes.
  Stream<List<SavedPlace>> watchFor(String ownerId) => _col
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((s) => s.docs.map((d) => SavedPlace.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  /// UPDATE: saves the edited details of a place.
  Future<void> update(SavedPlace place) {
    _validate(place);
    return _col.doc(place.id).update(place.toEditableMap());
  }

  /// DELETE: removes a place.
  Future<void> delete(String id) => _col.doc(id).delete();

  /// Stops a save if the name or the photo is missing.
  void _validate(SavedPlace place) {
    if (place.label.trim().isEmpty) {
      throw ArgumentError('Give this place a name.');
    }
    if (place.imageUrl.isEmpty) {
      throw ArgumentError('Add a photo of this place.');
    }
  }
}
