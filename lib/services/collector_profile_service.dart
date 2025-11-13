import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class CollectorProfileService {
  final Dio _dio = ApiClient.instance.dio;

  /// Get collector profile
  Future<(bool success, String? message, Map<String, dynamic>? data)>
  getProfile() async {
    try {
      final res = await _dio.get(ApiConfig.collectorProfile);
      final body = res.data as Map<String, dynamic>;

      if (body['success'] == true) {
        return (true, null, body['data'] as Map<String, dynamic>?);
      } else {
        final msg =
            body['errors']?['message']?.toString() ?? 'Gagal memuat profil';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  /// Update collector profile
  Future<(bool success, String? message, Map<String, dynamic>? data)>
  updateProfile({required String name, required String phone}) async {
    try {
      final res = await _dio.put(
        ApiConfig.collectorProfile,
        data: {'name': name, 'phone': phone},
      );

      final body = res.data as Map<String, dynamic>;

      if (body['success'] == true) {
        return (true, null, body['data'] as Map<String, dynamic>?);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal memperbarui profil';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  /// Change password for collector
  Future<(bool success, String? message)> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final res = await _dio.post(
        ApiConfig.collectorChangePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        },
      );

      final body = res.data as Map<String, dynamic>;

      if (body['success'] == true) {
        return (true, null);
      } else {
        final msg =
            body['errors']?['message']?.toString() ?? 'Gagal mengubah password';
        return (false, msg);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        final errorMsg = body['errors']?['message']?.toString() ?? '';

        // Handle specific error messages
        if (errorMsg.toLowerCase().contains('current password') ||
            errorMsg.toLowerCase().contains('password lama') ||
            e.response?.statusCode == 422) {
          msg = errorMsg.isNotEmpty ? errorMsg : 'Password lama tidak sesuai';
        } else {
          msg = errorMsg.isNotEmpty ? errorMsg : msg;
        }
      }
      return (false, msg);
    } catch (e) {
      return (false, 'Terjadi kesalahan: $e');
    }
  }
}
