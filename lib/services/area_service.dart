import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/area_option.dart';
import 'api_client.dart';

class AreaService {
  AreaService() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  Future<List<AreaOption>> fetchAreas({
    String? level,
    String? parentId,
    String? search,
    int limit = 100,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': limit,
    };

    if (level != null) {
      queryParameters['level'] = level;
    }

    if (parentId != null) {
      queryParameters['parent_id'] = parentId;
    }

    if (search != null && search.isNotEmpty) {
      queryParameters['q'] = search;
    }

    final response = await _dio.get(
      ApiConfig.mobileAreas,
      queryParameters: queryParameters,
    );

    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['errors']?['message'] ?? 'Gagal memuat data area');
    }

    final data = body['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>? ?? const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(AreaOption.fromJson)
        .toList();
  }

  Future<List<AreaOption>> fetchKecamatan({String? search}) {
    return fetchAreas(level: 'Kecamatan', search: search);
  }

  Future<List<AreaOption>> fetchKelurahan({
    required String parentId,
    String? search,
  }) {
    return fetchAreas(level: 'Kelurahan', parentId: parentId, search: search);
  }
}
