import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';

/// Where uploaded images go. Profile photos, IDs and business permits all
/// pass through here.
abstract class ImageUploadService {
  /// Uploads [file] into [folder] and returns a URL [AppImage] can display.
  Future<String> upload(XFile file, {required String folder});
}

/// Unsigned uploads to Cloudinary using an upload preset.
class CloudinaryUploadService implements ImageUploadService {
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

/// Keeps images in memory for the demo backend (no Cloudinary account needed).
/// Returns `memory://<id>` URLs that [MemoryImageStore] resolves.
class MemoryUploadService implements ImageUploadService {
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
}

class ImageUploadException implements Exception {
  ImageUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}
