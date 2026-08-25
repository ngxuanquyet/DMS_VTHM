import '../../domain/entities/user_relation_entity.dart';

class UserRelationModel {
  final int employeeId;
  final String employeeCode;
  final String employeeName;
  final String positionRowId;
  final String branchCode;
  final int level;
  final String viaSubPosId;
  final bool isPrimary;
  final String phone;
  final String email;
  final String companyName;
  final String companyBranchName;
  final String jobName;
  final String deptName;

  const UserRelationModel({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.positionRowId,
    required this.branchCode,
    required this.level,
    required this.viaSubPosId,
    required this.isPrimary,
    required this.phone,
    required this.email,
    required this.companyName,
    required this.companyBranchName,
    required this.jobName,
    required this.deptName,
  });

  factory UserRelationModel.fromJson(Map<String, dynamic> json) {
    final companyNameStr = (json['company_name'] as String?)?.trim();
    final companyBranchNameStr = (json['company_branch_name'] as String?)?.trim();
    final jobNameStr = (json['job_name'] as String?)?.trim();
    final deptNameStr = (json['dept_name'] as String?)?.trim();
    final employeeNameStr = (json['employee_name'] as String?)?.trim();
    final employeeCodeStr = (json['employee_code'] as String?)?.trim();

    final resolvedCompanyName = (companyNameStr != null && companyNameStr.isNotEmpty)
        ? companyNameStr
        : 'Không xác định';

    final resolvedCompanyBranchName = (companyBranchNameStr != null && companyBranchNameStr.isNotEmpty)
        ? companyBranchNameStr
        : resolvedCompanyName;

    return UserRelationModel(
      employeeId: json['employee_id'] is int
          ? json['employee_id'] as int
          : int.tryParse(json['employee_id']?.toString() ?? '0') ?? 0,
      employeeCode: (employeeCodeStr != null && employeeCodeStr.isNotEmpty)
          ? employeeCodeStr
          : 'Không xác định',
      employeeName: (employeeNameStr != null && employeeNameStr.isNotEmpty)
          ? employeeNameStr
          : 'Không xác định',
      positionRowId: json['position_row_id'] as String? ?? '',
      branchCode: json['branch_code'] as String? ?? '',
      level: json['level'] is int
          ? json['level'] as int
          : int.tryParse(json['level']?.toString() ?? '0') ?? 0,
      viaSubPosId: json['via_sub_pos_id'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      companyName: resolvedCompanyName,
      companyBranchName: resolvedCompanyBranchName,
      jobName: (jobNameStr != null && jobNameStr.isNotEmpty) ? jobNameStr : 'Không xác định',
      deptName: (deptNameStr != null && deptNameStr.isNotEmpty) ? deptNameStr : 'Không xác định',
    );
  }

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'employee_code': employeeCode,
        'employee_name': employeeName,
        'position_row_id': positionRowId,
        'branch_code': branchCode,
        'level': level,
        'via_sub_pos_id': viaSubPosId,
        'is_primary': isPrimary,
        'phone': phone,
        'email': email,
        'company_name': companyName,
        'company_branch_name': companyBranchName,
        'job_name': jobName,
        'dept_name': deptName,
      };

  UserRelationEntity toEntity() => UserRelationEntity(
        employeeId: employeeId,
        employeeCode: employeeCode,
        employeeName: employeeName,
        positionRowId: positionRowId,
        branchCode: branchCode,
        level: level,
        viaSubPosId: viaSubPosId,
        isPrimary: isPrimary,
        phone: phone,
        email: email,
        companyName: companyName,
        companyBranchName: companyBranchName,
        jobName: jobName,
        deptName: deptName,
      );
}
