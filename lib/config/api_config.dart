class ApiConfig {
  // ⚠️ PENTING: Gunakan HTTPS untuk menghindari Mixed Content Error di browser
  // Base URL API Backend Laravel
  // static const String _productionUrl = 'http://127.0.0.1:8000/api/v1';
  static const String _productionUrl =
      'https://smart-environment-web.citiasiainc.id/api/v1';

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
  static const String forgotPassword = '/mobile/auth/password/forgot';

  // Mobile endpoints
  static const String mobileDashboard = '/mobile/dashboard';
  static const String mobileAreas = '/mobile/areas';
  static const String mobileSettings = '/mobile/settings';
  static const String mobileServiceAccounts = '/mobile/service-accounts';

  // Collector endpoints
  static const String collectorDashboard = '/mobile/collector/dashboard';
  static const String collectorPickupsToday = '/mobile/collector/pickups/today';
  static const String collectorPickupsHistory = '/mobile/collector/pickups/history';
  static const String collectorPickupDetail = '/mobile/collector/pickups'; // /{id}
  static const String collectorSchedules = '/mobile/collector/schedules';
  static const String collectorWasteItems = '/mobile/collector/waste-items';
  static const String collectorProfile = '/mobile/collector/profile';
  static const String collectorChangePassword ='/mobile/collector/profile/change-password';

  // Resident/User endpoints
  static const String residentPickupsUpcoming = '/mobile/resident/pickups/upcoming';
  static const String residentPickupsHistory = '/mobile/resident/pickups/history';
  static const String residentPickupDetail = '/mobile/resident/pickups'; // /{id}
  static const String residentProfile = '/mobile/resident/profile';
  static const String residentChangePassword = '/mobile/resident/profile/change-password';

  // Article endpoints
  static const String articles = '/mobile/resident/articles';
  static const String articleDetail = '/mobile/resident/articles'; // /{id}
  static const String articlesFeatured = '/mobile/resident/articles/featured';
}
