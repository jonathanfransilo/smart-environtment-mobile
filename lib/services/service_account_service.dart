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
        'page': {'size': limit},
      },
    );

    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(
        body['errors']?['message'] ?? 'Gagal memuat akun layanan',
      );
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

  /// Update status akun (active/inactive)
  Future<void> updateAccountStatus(String id, String status) async {
    try {
      print(
        '🔄 [ServiceAccountService] Updating account $id to status: $status',
      );

      final response = await _dio.patch(
        '${ApiConfig.mobileServiceAccounts}/$id',
        data: {'status': status},
      );

      print(
        '✅ [ServiceAccountService] Response status: ${response.statusCode}',
      );
      print('📦 [ServiceAccountService] Response data: ${response.data}');

      final Map<String, dynamic> body = response.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw Exception(
          body['errors']?['message'] ?? 'Gagal mengubah status akun',
        );
      }

      print('✅ [ServiceAccountService] Status updated successfully');
    } on DioException catch (e) {
      print(
        '❌ [ServiceAccountService] DioException: ${e.response?.statusCode}',
      );
      print('📦 [ServiceAccountService] Error data: ${e.response?.data}');

      if (e.response?.statusCode == 404) {
        throw Exception('Akun tidak ditemukan');
      } else if (e.response?.statusCode == 400) {
        final body = e.response?.data as Map<String, dynamic>?;
        throw Exception(body?['errors']?['message'] ?? 'Data tidak valid');
      }
      throw Exception('Gagal mengubah status akun: ${e.message}');
    } catch (e) {
      print('❌ [ServiceAccountService] Unexpected error: $e');
      throw Exception('Gagal mengubah status akun: $e');
    }
  }
}
