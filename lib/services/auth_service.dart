import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_client.dart';
import 'token_storage.dart';
import 'user_storage.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  Future<(bool success, String? message, Map<String, dynamic>? user)> login({
    required String email,
    required String password,
    String deviceName = 'mobile',
  }) async {
    try {
      final res = await _dio.post(
        ApiConfig.login,
        data: {'email': email, 'password': password, 'device_name': deviceName},
      );

      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final token = data['data']?['token'] as String?;
        final user = data['data']?['user'] as Map<String, dynamic>?;

        if (token != null) {
          await TokenStorage.saveToken(token);
          await UserStorage.saveToken(token); // Simpan juga ke UserStorage
        }

        // Simpan data user termasuk role
        if (user != null) {
          // Safely extract id - handle both int and string
          int? userId;
          if (user['id'] != null) {
            if (user['id'] is int) {
              userId = user['id'] as int;
            } else if (user['id'] is String) {
              userId = int.tryParse(user['id'] as String);
            }
          }

          // Only save if we have valid user id
          if (userId != null) {
            await UserStorage.saveUser(
              id: userId,
              name: user['name']?.toString() ?? '',
              email: user['email']?.toString() ?? email,
              roles: (user['roles'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList(),
              fullData:
                  user, // ✅ TAMBAHAN: Simpan full user data untuk akses RW
            );
          }
        }

        return (true, null, user);
      } else {
        final msg = data['errors']?['message']?.toString() ?? 'Login gagal';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        final errorMsg = body['errors']?['message']?.toString() ?? '';
        // Ubah "Invalid credentials" menjadi "Email atau password salah"
        if (errorMsg.toLowerCase().contains('invalid credentials') ||
            errorMsg.toLowerCase().contains('invalid') ||
            e.response?.statusCode == 401) {
          msg = 'Email atau password salah';
        } else {
          msg = errorMsg.isNotEmpty ? errorMsg : msg;
        }
      } else if (e.response?.statusCode == 401) {
        msg = 'Email atau password salah';
      }
      return (false, msg, null);
    } catch (e) {
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  Future<(bool success, String? message)> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final res = await _dio.post(
        ApiConfig.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (true, null);
      } else {
        final msg =
            data['errors']?['message']?.toString() ?? 'Registrasi gagal';
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
    await UserStorage.clearUser();
  }

  /// Kirim email untuk reset password
  Future<(bool success, String? message)> forgotPassword({
    required String email,
  }) async {
    try {
      final res = await _dio.post(
        ApiConfig.forgotPassword,
        data: {'email': email},
      );

      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final msg = data['message']?.toString() ?? 
                   'Link reset password telah dikirim ke email Anda';
        return (true, msg);
      } else {
        final msg = data['errors']?['message']?.toString() ?? 
                   data['message']?.toString() ??
                   'Gagal mengirim link reset password';
        return (false, msg);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        // Coba ambil pesan error dari berbagai kemungkinan struktur
        msg = body['errors']?['message']?.toString() ?? 
              body['message']?.toString() ??
              body['errors']?['email']?.first?.toString() ?? // Validation error
              msg;
      } else if (e.response?.statusCode == 404) {
        msg = 'Email tidak terdaftar';
      } else if (e.response?.statusCode == 422) {
        msg = 'Email tidak valid';
      }
      return (false, msg);
    } catch (e) {
      return (false, 'Terjadi kesalahan: $e');
    }
  }
}
