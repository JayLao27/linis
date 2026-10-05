import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';

/// Where uploaded images go. Profile photos, IDs and business permits all
/// pass through here.
abstract class ImageUploadService {
  /// Uploads [file] into [folder] and returns a URL [AppImage] can display.
  Future<String> upload(XFile file, {required String folder});

  /// Loads the picture behind a URL that is not a normal web link.
  /// Returns null if the picture cannot be found.
  Future<Uint8List?> fetch(String url) async => MemoryImageStore.get(url);
}

/// Unsigned uploads to Cloudinary using an upload preset.
class CloudinaryUploadService extends ImageUploadService {
  CloudinaryUploadService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> upload(XFile file, {required String folder}) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = 'linis/$folder'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        await file.readAsBytes(),
        filename: file.name,
      ));
    final res = await http.Response.fromStream(await _client.send(req));
    if (res.statusCode != 200) {
      throw ImageUploadException('Upload failed (${res.statusCode}).');
    }
    return (jsonDecode(res.body) as Map)['secure_url'] as String;
  }
}

/// Saves pictures inside Firestore (`images/{id}`), so they show on every
/// device without a separate photo service. Used when Cloudinary is not set
/// up. A Firestore document can hold about 1 MB, so big photos are refused.
class FirestoreUploadService extends ImageUploadService {
  FirestoreUploadService(this._db, this._currentUid);

  final FirebaseFirestore _db;

  /// Gives the id of the signed-in user, who becomes the picture's owner.
  final String? Function() _currentUid;

  /// Saved URLs look like `firestore-image://<document id>`.
  static const scheme = 'firestore-image://';
  static const maxBytes = 900 * 1024;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('images');

  @override
  Future<String> upload(XFile file, {required String folder}) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw ImageUploadException(
          'That photo is too large. Please pick a smaller one.');
    }
    final ref = await _col.add({
      'ownerId': _currentUid(),
      'folder': folder,
      'bytes': Blob(bytes),
      'createdAt': FieldValue.serverTimestamp(),
    });
    final url = '$scheme${ref.id}';
    // Keep a copy in memory so the picture shows right away.
    MemoryImageStore.put(url, bytes);
    return url;
  }

  @override
  Future<Uint8List?> fetch(String url) async {
    final cached = MemoryImageStore.get(url);
    if (cached != null || !url.startsWith(scheme)) return cached;
    final snap = await _col.doc(url.substring(scheme.length)).get();
    final blob = snap.data()?['bytes'];
    if (blob is! Blob) return null;
    MemoryImageStore.put(url, blob.bytes);
    return blob.bytes;
  }
}

/// Keeps images in memory for the demo backend (no Cloudinary account needed).
/// Returns `memory://<id>` URLs that [MemoryImageStore] resolves.
class MemoryUploadService extends ImageUploadService {
  int _next = 0;

  @override
  Future<String> upload(XFile file, {required String folder}) async {
    final url = 'memory://$folder/${_next++}';
    MemoryImageStore.put(url, await file.readAsBytes());
    return url;
  }
}

class MemoryImageStore {
  MemoryImageStore._();
  static final Map<String, Uint8List> _images = {};

  static void put(String url, Uint8List bytes) => _images[url] = bytes;
  static Uint8List? get(String url) => _images[url];
  static void clear() => _images.clear();
}

class ImageUploadException implements Exception {
  ImageUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}
