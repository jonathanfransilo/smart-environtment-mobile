import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/service_account.dart';
import 'api_client.dart';

class ServiceAccountService {
  ServiceAccountService() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  Future<List<ServiceAccount>> fetchAccounts({int limit = 100}) async {
    print('[SYNC] [ServiceAccountService] Fetching accounts...');

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

    print('[DATA] [ServiceAccountService] Fetched ${items.length} accounts');

    final accounts = items.whereType<Map<String, dynamic>>().map((json) {
      print(
        '   - Account JSON: ${json['name']} -> contact_phone: ${json['contact_phone']}',
      );
      print('   - RW data: ${json['rw']}');
      print('   - RW name: ${json['rw_name']}');
      return ServiceAccount.fromJson(json);
    }).toList();

    print('[OK] [ServiceAccountService] Parsed ${accounts.length} accounts');
    for (final account in accounts) {
      print(
        '   - ${account.name}: contactPhone = ${account.contactPhone}, RW = ${account.rwName}',
      );
    }

    return accounts;
  }

  Future<ServiceAccount> createAccount({
    required String name,
    required String address,
    required String areaId,
    required double latitude,
    required double longitude,
    String? contactPhone,
    String? rwName,
    String? note,
  }) async {
    final requestData = {
      'name': name,
      'address': address,
      'area_id': areaId,
      'latitude': latitude,
      'longitude': longitude,
      if (contactPhone != null && contactPhone.isNotEmpty)
        'contact_phone': contactPhone,
      if (rwName != null && rwName.isNotEmpty) 'rw_name': rwName,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    print(
      '[SEND] [ServiceAccountService] Creating account with data: $requestData',
    );

    final response = await _dio.post(
      ApiConfig.mobileServiceAccounts,
      data: requestData,
    );

    print('[RECV] [ServiceAccountService] Response status: ${response.statusCode}');
    print('[DATA] [ServiceAccountService] Response data: ${response.data}');

    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['errors']?['message'] ?? 'Gagal menyimpan akun');
    }

    final data = body['data'];
    if (data is Map<String, dynamic>) {
      print('[OK] [ServiceAccountService] Parsed account data: $data');
      print(
        '[INFO] [ServiceAccountService] Contact phone from response: ${data['contact_phone']}',
      );
      print('[LIST] [ServiceAccountService] RW data from response: ${data['rw']}');
      print(
        '[LIST] [ServiceAccountService] RW name from response: ${data['rw_name']}',
      );

      final account = ServiceAccount.fromJson(data);
      print(
        '[OK] [ServiceAccountService] Account created - Phone: ${account.contactPhone}, RW: ${account.rwName}',
      );

      return account;
    }

    throw Exception('Data akun tidak valid');
  }

  /// Ambil detail service account berdasarkan ID
  Future<ServiceAccount?> getAccountById(String id) async {
    try {
      print('[SYNC] [ServiceAccountService] Fetching account by ID: $id');

      final response = await _dio.get('${ApiConfig.mobileServiceAccounts}/$id');

      final Map<String, dynamic> body = response.data as Map<String, dynamic>;
      if (body['success'] != true) {
        print('[ERROR] [ServiceAccountService] Failed to fetch account');
        return null;
      }

      final data = body['data'] as Map<String, dynamic>?;
      if (data != null) {
        print('[OK] [ServiceAccountService] Account fetched: ${data['name']}');
        print('[LIST] [ServiceAccountService] RW data in response: ${data['rw']}');
        print(
          '[LIST] [ServiceAccountService] RW name in response: ${data['rw_name']}',
        );
        return ServiceAccount.fromJson(data);
      }

      return null;
    } catch (e) {
      print('[ERROR] [ServiceAccountService] Error fetching account: $e');
      return null;
    }
  }

  Future<void> deleteAccount(String id) async {
    await _dio.delete('${ApiConfig.mobileServiceAccounts}/$id');
  }

  /// Update status akun (active/inactive)
  Future<void> updateAccountStatus(String id, String status) async {
    try {
      print(
        '[SYNC] [ServiceAccountService] Updating account $id to status: $status',
      );

      final response = await _dio.patch(
        '${ApiConfig.mobileServiceAccounts}/$id',
        data: {'status': status},
      );

      print(
        '[OK] [ServiceAccountService] Response status: ${response.statusCode}',
      );
      print('[DATA] [ServiceAccountService] Response data: ${response.data}');

      final Map<String, dynamic> body = response.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw Exception(
          body['errors']?['message'] ?? 'Gagal mengubah status akun',
        );
      }

      print('[OK] [ServiceAccountService] Status updated successfully');
    } on DioException catch (e) {
      print(
        '[ERROR] [ServiceAccountService] DioException: ${e.response?.statusCode}',
      );
      print('[DATA] [ServiceAccountService] Error data: ${e.response?.data}');

      if (e.response?.statusCode == 404) {
        throw Exception('Akun tidak ditemukan');
      } else if (e.response?.statusCode == 400) {
        final body = e.response?.data as Map<String, dynamic>?;
        throw Exception(body?['errors']?['message'] ?? 'Data tidak valid');
      }
      throw Exception('Gagal mengubah status akun: ${e.message}');
    } catch (e) {
      print('[ERROR] [ServiceAccountService] Unexpected error: $e');
      throw Exception('Gagal mengubah status akun: $e');
    }
  }
}
