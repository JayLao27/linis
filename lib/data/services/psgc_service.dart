import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../core/constants.dart';
import '../models/address.dart';

/// Region → province → city → barangay lookups from the PSGC API
/// (https://psgc.gitlab.io/api). Results are cached for the session.
///
/// Davao City's barangays also ship as an asset, so the launch area works
/// offline and the barangay picker opens instantly.
class PsgcService {
  PsgcService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<PsgcPlace>> _cache = {};

  static const davaoRegion =
      PsgcPlace(code: Business.davaoRegionCode, name: 'Davao Region');
  static const davaoDelSur =
      PsgcPlace(code: Business.davaoProvinceCode, name: 'Davao del Sur');
  static const davaoCity =
      PsgcPlace(code: Business.davaoCityCode, name: 'City of Davao');

  Future<List<PsgcPlace>> regions() => _get('/regions/');

  Future<List<PsgcPlace>> provinces(String regionCode) =>
      _get('/regions/$regionCode/provinces/');

  /// Cities and municipalities of a province, or of a region for places with
  /// no province (NCR).
  Future<List<PsgcPlace>> cities({String? provinceCode, String? regionCode}) {
    assert(provinceCode != null || regionCode != null);
    return provinceCode != null
        ? _get('/provinces/$provinceCode/cities-municipalities/')
        : _get('/regions/$regionCode/cities-municipalities/');
  }

  Future<List<PsgcPlace>> barangays(String cityCode) async {
    if (cityCode == Business.davaoCityCode) return davaoCityBarangays();
    return _get('/cities-municipalities/$cityCode/barangays/');
  }

  Future<List<PsgcPlace>> davaoCityBarangays() async {
    const key = 'asset:davao';
    final cached = _cache[key];
    if (cached != null) return cached;
    final raw =
        await rootBundle.loadString('assets/data/davao_city_barangays.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => PsgcPlace.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _cache[key] = list;
  }

  Future<List<PsgcPlace>> _get(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;
    final res = await _client
        .get(Uri.parse('${AppConfig.psgcBaseUrl}$path'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw PsgcException('Address lookup failed (${res.statusCode}).');
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => PsgcPlace.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return _cache[path] = list;
  }
}

class PsgcException implements Exception {
  PsgcException(this.message);
  final String message;
  @override
  String toString() => message;
}
