import 'package:flutter/material.dart';
import '../services/user_storage.dart';

class RouteHelper {
  /// Navigate ke home screen yang sesuai berdasarkan role user
  static Future<void> navigateToHome(BuildContext context) async {
    final isCollector = await UserStorage.isCollector();
    
    if (!context.mounted) return;
    
    if (isCollector) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home-kolektor', (route) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  /// Get home route berdasarkan role user
  static Future<String> getHomeRoute() async {
    final isCollector = await UserStorage.isCollector();
    return isCollector ? '/home-kolektor' : '/home';
  }
}
