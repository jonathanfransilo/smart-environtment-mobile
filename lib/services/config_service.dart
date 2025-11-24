import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/app_settings.dart';
import 'api_client.dart';

class ConfigService {
  ConfigService() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  Future<AppSettingsData?> fetchAppSettings() async {
    print('🌐 [ConfigService] Fetching settings from: ${ApiConfig.mobileSettings}');
    final response = await _dio.get(ApiConfig.mobileSettings);
    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    
    print('📦 [ConfigService] Raw response: $body');

    if (body['success'] != true) {
      throw Exception(body['errors']?['message'] ?? 'Gagal memuat pengaturan');
    }

    final data = body['data'];
    print('📊 [ConfigService] Data from response: $data');
    
    if (data is Map<String, dynamic>) {
      final settings = AppSettingsData.fromJson(data);
      print('✅ [ConfigService] Parsed settings:');
      print('   - Province: ${settings.province?.name} (ID: ${settings.province?.id})');
      print('   - City: ${settings.city?.name} (ID: ${settings.city?.id})');
      return settings;
    }

    return null;
  }
}
