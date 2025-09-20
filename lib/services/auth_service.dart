import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  Future<(bool success, String? message)> login({
    required String email,
    required String password,
    String deviceName = 'mobile',
  }) async {
    try {
      final res = await _dio.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
          'device_name': deviceName,
        },
      );

      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final token = data['data']?['token'] as String?;
        if (token != null) {
          await TokenStorage.saveToken(token);
        }
        return (true, null);
      } else {
        final msg = data['errors']?['message']?.toString() ?? 'Login gagal';
        return (false, msg);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg);
    } catch (e) {
      return (false, 'Error: $e');
    }
  }

  Future<Map<String, dynamic>?> me() async {
    try {
      final res = await _dio.get(ApiConfig.me);
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        return body['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConfig.logout);
    } catch (_) {}
    await TokenStorage.clearToken();
  }
}
