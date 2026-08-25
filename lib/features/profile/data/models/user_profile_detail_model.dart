import '../../domain/entities/user_profile_detail_entity.dart';

class UserProfileDetailModel {
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

  const UserProfileDetailModel({
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

  factory UserProfileDetailModel.fromJson(Map<String, dynamic> json) {
    final companyStr = (json['company'] as String?)?.trim();
    final deptStr = (json['dept_name'] as String?)?.trim();
    final jobStr = (json['job_name'] as String? ?? json['role'] as String?)?.trim();
    final userTypeLabelStr = (json['user_type_label'] as String?)?.trim();
    final fullNameStr = (json['full_name'] as String? ?? json['name'] as String?)?.trim();
    final employeeCodeStr = (json['employee_code'] as String? ?? json['employeeId'] as String?)?.trim();

    return UserProfileDetailModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username'] as String? ?? '',
      fullName: (fullNameStr != null && fullNameStr.isNotEmpty) ? fullNameStr : 'Không xác định',
      company: (companyStr != null && companyStr.isNotEmpty) ? companyStr : 'Không xác định',
      deptName: (deptStr != null && deptStr.isNotEmpty) ? deptStr : 'Không xác định',
      jobName: (jobStr != null && jobStr.isNotEmpty) ? jobStr : 'Không xác định',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      personalEmail: json['personal_email'] as String? ?? '',
      userType: json['user_type'] is int ? json['user_type'] as int : int.tryParse(json['user_type']?.toString() ?? '0') ?? 0,
      userTypeLabel: (userTypeLabelStr != null && userTypeLabelStr.isNotEmpty) ? userTypeLabelStr : 'Không xác định',
      status: json['status'] is int ? json['status'] as int : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      statusLabel: (json['status_label'] as String?)?.trim().isNotEmpty == true
          ? json['status_label'] as String
          : 'Đang hoạt động',
      statusColor: json['status_color'] as String? ?? 'success',
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      employeeCode: (employeeCodeStr != null && employeeCodeStr.isNotEmpty) ? employeeCodeStr : 'Không xác định',
      avatarUrl: json['avatar_url'] as String? ?? '',
      lastLoginAt: json['last_login_at'] as String? ?? '',
      resigned: json['resigned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'company': company,
        'dept_name': deptName,
        'job_name': jobName,
        'phone': phone,
        'email': email,
        'personal_email': personalEmail,
        'user_type': userType,
        'user_type_label': userTypeLabel,
        'status': status,
        'status_label': statusLabel,
        'status_color': statusColor,
        'is_super_admin': isSuperAdmin,
        'employee_code': employeeCode,
        'avatar_url': avatarUrl,
        'last_login_at': lastLoginAt,
        'resigned': resigned,
      };

  UserProfileDetailEntity toEntity() => UserProfileDetailEntity(
        id: id,
        username: username,
        fullName: fullName,
        company: company,
        deptName: deptName,
        jobName: jobName,
        phone: phone,
        email: email,
        personalEmail: personalEmail,
        userType: userType,
        userTypeLabel: userTypeLabel,
        status: status,
        statusLabel: statusLabel,
        statusColor: statusColor,
        isSuperAdmin: isSuperAdmin,
        employeeCode: employeeCode,
        avatarUrl: avatarUrl,
        lastLoginAt: lastLoginAt,
        resigned: resigned,
      );
}
