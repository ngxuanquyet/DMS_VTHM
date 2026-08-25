class UserProfileDetailEntity {
  final int id;
  final String username;
  final String fullName;
  final String company;
  final String deptName;
  final String jobName;
  final String phone;
  final String email;
  final String personalEmail;
  final int userType;
  final String userTypeLabel;
  final int status;
  final String statusLabel;
  final String statusColor;
  final bool isSuperAdmin;
  final String employeeCode;
  final String avatarUrl;
  final String lastLoginAt;
  final bool resigned;

  const UserProfileDetailEntity({
    required this.id,
    required this.username,
    required this.fullName,
    required this.company,
    required this.deptName,
    required this.jobName,
    required this.phone,
    required this.email,
    required this.personalEmail,
    required this.userType,
    required this.userTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.isSuperAdmin,
    required this.employeeCode,
    required this.avatarUrl,
    required this.lastLoginAt,
    required this.resigned,
  });
}
