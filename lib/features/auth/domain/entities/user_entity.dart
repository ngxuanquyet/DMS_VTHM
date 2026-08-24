class UserEntity {
  final String id;
  final String name;
  final String employeeId;
  final String role;
  final String region;
  final String avatarUrl;
  final String email;
  final String phone;

  const UserEntity({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.role,
    required this.region,
    required this.avatarUrl,
    required this.email,
    required this.phone,
  });
}
