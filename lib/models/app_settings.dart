import 'area_option.dart';

class AppSettingsData {
  const AppSettingsData({this.province, this.city});

  final AreaOption? province;
  final AreaOption? city;

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    return AppSettingsData(
      province: json['province'] is Map<String, dynamic>
          ? AreaOption.fromJson(
              {
                'level': 'Province',
                ...json['province'] as Map<String, dynamic>,
              },
            )
          : null,
      city: json['city'] is Map<String, dynamic>
          ? AreaOption.fromJson(
              {
                'level': (json['city'] as Map<String, dynamic>)['level'] ?? 'City',
                ...json['city'] as Map<String, dynamic>,
              },
            )
          : null,
    );
  }
}
