import '../../domain/entities/user_entity.dart';

class UserModel {
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

  const UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json, {List<String>? permissions}) {
    final rawPerms = permissions ??
        (json['permissions'] as List?)?.map((e) => e.toString()).toList() ??
        [];

    final rawId = json['id'];
    final idStr = rawId?.toString() ?? '';

    final rawUserType = json['user_type'];
    final userTypeInt = rawUserType is int
        ? rawUserType
        : int.tryParse(rawUserType?.toString() ?? '1') ?? 1;

    final displayName = json['display_name'] as String? ??
        json['name'] as String? ??
        '';

    final employeeCode = json['employee_code'] as String? ??
        json['employeeId'] as String? ??
        '';

    final jobTitle = json['job_title'] as String? ??
        json['role'] as String? ??
        '';

    final avatarUrl = json['avatar_url'] as String? ??
        json['avatarUrl'] as String? ??
        '';

    return UserModel(
      id: idStr,
      username: json['username'] as String? ?? json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      userType: userTypeInt,
      isInternal: json['is_internal'] as bool? ?? true,
      employeeCode: employeeCode,
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      displayName: displayName,
      jobTitle: jobTitle,
      initial: json['initial'] as String? ?? '',
      avatarUrl: avatarUrl,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      permissions: rawPerms,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'user_type': userType,
      'is_internal': isInternal,
      'employee_code': employeeCode,
      'is_super_admin': isSuperAdmin,
      'display_name': displayName,
      'job_title': jobTitle,
      'initial': initial,
      'avatar_url': avatarUrl,
      'must_change_password': mustChangePassword,
      'permissions': permissions,
      // Legacy compatibility keys
      'name': displayName,
      'employeeId': employeeCode,
      'role': jobTitle,
      'avatarUrl': avatarUrl,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    int? userType,
    bool? isInternal,
    String? employeeCode,
    bool? isSuperAdmin,
    String? displayName,
    String? jobTitle,
    String? initial,
    String? avatarUrl,
    bool? mustChangePassword,
    List<String>? permissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      isInternal: isInternal ?? this.isInternal,
      employeeCode: employeeCode ?? this.employeeCode,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      displayName: displayName ?? this.displayName,
      jobTitle: jobTitle ?? this.jobTitle,
      initial: initial ?? this.initial,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      permissions: permissions ?? this.permissions,
    );
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        username: username,
        email: email,
        userType: userType,
        isInternal: isInternal,
        employeeCode: employeeCode,
        isSuperAdmin: isSuperAdmin,
        displayName: displayName,
        jobTitle: jobTitle,
        initial: initial,
        avatarUrl: avatarUrl,
        mustChangePassword: mustChangePassword,
        permissions: permissions,
      );

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
        id: entity.id,
        username: entity.username,
        email: entity.email,
        userType: entity.userType,
        isInternal: entity.isInternal,
        employeeCode: entity.employeeCode,
        isSuperAdmin: entity.isSuperAdmin,
        displayName: entity.displayName,
        jobTitle: entity.jobTitle,
        initial: entity.initial,
        avatarUrl: entity.avatarUrl,
        mustChangePassword: entity.mustChangePassword,
        permissions: entity.permissions,
      );
}
