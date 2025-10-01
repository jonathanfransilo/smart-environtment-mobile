import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/service_account.dart';
import 'api_client.dart';

class ServiceAccountService {
  ServiceAccountService() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  Future<List<ServiceAccount>> fetchAccounts({int limit = 100}) async {
    final response = await _dio.get(
      ApiConfig.mobileServiceAccounts,
      queryParameters: {
        'page': {
          'size': limit,
        },
      },
    );

    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['errors']?['message'] ?? 'Gagal memuat akun layanan');
    }

    final data = body['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>? ?? const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(ServiceAccount.fromJson)
        .toList();
  }

  Future<ServiceAccount> createAccount({
    required String name,
    required String address,
    required String areaId,
    required double latitude,
    required double longitude,
    String? contactPhone,
    String? note,
  }) async {
    final response = await _dio.post(
      ApiConfig.mobileServiceAccounts,
      data: {
        'name': name,
        'address': address,
        'area_id': areaId,
        'latitude': latitude,
        'longitude': longitude,
        if (contactPhone != null && contactPhone.isNotEmpty)
          'contact_phone': contactPhone,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );

    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['errors']?['message'] ?? 'Gagal menyimpan akun');
    }

    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return ServiceAccount.fromJson(data);
    }

    throw Exception('Data akun tidak valid');
  }

  Future<void> deleteAccount(String id) async {
    await _dio.delete('${ApiConfig.mobileServiceAccounts}/$id');
  }
}
