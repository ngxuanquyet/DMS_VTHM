import '../../domain/entities/user_profile_entity.dart';

class UserProfileModel {
  final String id;
  final String name;
  final String employeeId;
  final String role;
  final String region;
  final String avatarUrl;
  final String email;
  final String phone;
  final bool isDarkMode;
  final String language;

  const UserProfileModel({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.role,
    required this.region,
    required this.avatarUrl,
    required this.email,
    required this.phone,
    this.isDarkMode = false,
    this.language = 'Tiếng Việt',
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      role: json['role'] as String? ?? '',
      region: json['region'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      language: json['language'] as String? ?? 'Tiếng Việt',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'employeeId': employeeId,
        'role': role,
        'region': region,
        'avatarUrl': avatarUrl,
        'email': email,
        'phone': phone,
        'isDarkMode': isDarkMode,
        'language': language,
      };

  UserProfileEntity toEntity() => UserProfileEntity(
        id: id,
        name: name,
        employeeId: employeeId,
        role: role,
        region: region,
        avatarUrl: avatarUrl,
        email: email,
        phone: phone,
        isDarkMode: isDarkMode,
        language: language,
      );
}
