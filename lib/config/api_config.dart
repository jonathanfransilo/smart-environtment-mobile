import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  // Resolve base URL with priority: dart-define > platform default
  static String get baseUrl {
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return 'http://$host:8000/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';

  // Mobile endpoints
  static const String mobileDashboard = '/mobile/dashboard';
  static const String mobileAreas = '/mobile/areas';
  static const String mobileSettings = '/mobile/settings';
  static const String mobileServiceAccounts = '/mobile/service-accounts';
}
