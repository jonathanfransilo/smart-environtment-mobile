import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/app_settings.dart';
import 'api_client.dart';

class ConfigService {
  ConfigService() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  Future<AppSettingsData?> fetchAppSettings() async {
    final response = await _dio.get(ApiConfig.mobileSettings);
    final Map<String, dynamic> body = response.data as Map<String, dynamic>;

    if (body['success'] != true) {
      throw Exception(body['errors']?['message'] ?? 'Gagal memuat pengaturan');
    }

    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return AppSettingsData.fromJson(data);
    }

    return null;
  }
}
