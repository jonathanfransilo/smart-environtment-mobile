class ApiConfig {
  // ⚠️ PENTING: Gunakan HTTPS untuk menghindari Mixed Content Error di browser
  // Base URL API Backend Laravel
  static const String _productionUrl = 'https://smart-environment-web.citiasiainc.id/api/v1';
  
  // Resolve base URL with priority: dart-define > hardcoded production URL
  static String get baseUrl {
    // Cek environment variable yang di-set saat build
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defined.isNotEmpty) {
      // Pastikan menggunakan HTTPS jika bukan localhost
      if (defined.contains('localhost') || defined.contains('127.0.0.1')) {
        return defined;
      }
      // Force HTTPS untuk domain publik
      return defined.replaceFirst('http://', 'https://');
    }
    
    // Default: gunakan production URL (HTTPS)
    return _productionUrl;
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
