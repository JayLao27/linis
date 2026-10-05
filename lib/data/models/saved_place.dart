import 'package:cloud_firestore/cloud_firestore.dart';

import 'address.dart';
import 'enums.dart';
import 'firestore_utils.dart';

/// A home that a customer wants cleaned, like their house or a condo.
/// Saved in Firestore under `places/{id}`. Every place has a photo.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.ownerId,
    required this.label,
    required this.homeSize,
    required this.address,
    required this.imageUrl,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;

  /// The name the customer gives the place, like "Home".
  final String label;
  final HomeSize homeSize;
  final Address address;
  final String imageUrl;

  /// Extra details for the cleaner, like a gate code or pets.
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SavedPlace.fromMap(String id, Map<String, dynamic> map) => SavedPlace(
        id: id,
        ownerId: map['ownerId'] as String? ?? '',
        label: map['label'] as String? ?? '',
        homeSize: enumByName(HomeSize.values, map['homeSize'], HomeSize.small),
        address: Address.fromMap(
            Map<String, dynamic>.from(map['address'] as Map? ?? const {})),
        imageUrl: map['imageUrl'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        createdAt: readDate(map['createdAt']),
        updatedAt: readDate(map['updatedAt']),
      );

  /// The fields that can be edited later.
  Map<String, dynamic> toEditableMap() => {
        'label': label.trim(),
        'homeSize': homeSize.name,
        'address': address.toMap(),
        'imageUrl': imageUrl,
        'notes': notes.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Everything saved when the place is first created.
  Map<String, dynamic> toNewDocMap() => {
        ...toEditableMap(),
        'ownerId': ownerId,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
