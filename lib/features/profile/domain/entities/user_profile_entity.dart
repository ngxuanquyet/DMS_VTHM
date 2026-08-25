class UserProfileEntity {
  final String id;
  final String name;
  final String employeeId;
  final String role;
  final String department;
  final String avatarUrl;
  final String email;
  final String phone;
  final bool isDarkMode;
  final String language;

  const UserProfileEntity({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.role,
    required this.department,
    required this.avatarUrl,
    required this.email,
    required this.phone,
    required this.isDarkMode,
    required this.language,
  });

  // Backward compatibility getter
  String get region => department;
}
