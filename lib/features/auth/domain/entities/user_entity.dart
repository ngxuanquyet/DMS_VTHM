class UserEntity {
  final String id;
  final String username;
  final String email;
  final int userType;
  final bool isInternal;
  final String employeeCode;
  final bool isSuperAdmin;
  final String displayName;
  final String jobTitle;
  final String initial;
  final String avatarUrl;
  final bool mustChangePassword;
  final List<String> permissions;

  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    this.userType = 1,
    this.isInternal = true,
    required this.employeeCode,
    this.isSuperAdmin = false,
    required this.displayName,
    required this.jobTitle,
    this.initial = '',
    required this.avatarUrl,
    this.mustChangePassword = false,
    this.permissions = const [],
  });

  // Backward compatibility getters
  String get name => displayName.isNotEmpty ? displayName : username;
  String get employeeId => employeeCode.isNotEmpty ? employeeCode : id;
  String get role => jobTitle.isNotEmpty ? jobTitle : 'Nhân viên';
  String get region => 'Hệ thống VTHM';
  String get phone => '';
}
