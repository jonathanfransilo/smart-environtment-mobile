import 'package:flutter/foundation.dart';

/// Konfigurasi untuk Device Wrapper
/// Device wrapper hanya aktif di web untuk demo/preview
class DeviceWrapperConfig {
  /// Toggle untuk mengaktifkan/menonaktifkan device wrapper
  /// Set ke true untuk menampilkan device frame saat development/demo di web
  /// Set ke false untuk production atau saat dijalankan di device fisik
  static const bool enableDeviceWrapper = true;

  /// Device wrapper hanya akan aktif jika:
  /// 1. enableDeviceWrapper = true
  /// 2. Platform adalah web (kIsWeb = true)
  static bool get shouldShowDeviceWrapper {
    // Hanya aktif jika toggle enabled DAN berjalan di web
    return enableDeviceWrapper && kIsWeb;
  }
}
