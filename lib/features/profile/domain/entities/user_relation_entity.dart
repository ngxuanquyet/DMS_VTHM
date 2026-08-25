class UserRelationEntity {
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

  const UserRelationEntity({
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
}
