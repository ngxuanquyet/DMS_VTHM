import '../../domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String name;
  final String employeeId;
  final String role;
  final String region;
  final String avatarUrl;
  final String email;
  final String phone;

  const UserModel({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.role,
    required this.region,
    required this.avatarUrl,
    required this.email,
    required this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      role: json['role'] as String? ?? '',
      region: json['region'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'employeeId': employeeId,
      'role': role,
      'region': region,
      'avatarUrl': avatarUrl,
      'email': email,
      'phone': phone,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? employeeId,
    String? role,
    String? region,
    String? avatarUrl,
    String? email,
    String? phone,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      role: role ?? this.role,
      region: region ?? this.region,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        name: name,
        employeeId: employeeId,
        role: role,
        region: region,
        avatarUrl: avatarUrl,
        email: email,
        phone: phone,
      );

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
        id: entity.id,
        name: entity.name,
        employeeId: entity.employeeId,
        role: entity.role,
        region: entity.region,
        avatarUrl: entity.avatarUrl,
        email: entity.email,
        phone: entity.phone,
      );
}
