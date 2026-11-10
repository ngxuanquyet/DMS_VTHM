import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';

void main() {
  test('Số phiên bản hiển thị lấy từ bản build, không phải chuỗi gõ cứng', () async {
    PackageInfo.setMockInitialValues(
      appName: 'VTHM DMS',
      packageName: 'vn.vthmgroup.dms',
      version: '1.0.2',
      buildNumber: '3',
      buildSignature: '',
    );
    await AppConstants.loadVersion();

    expect(AppConstants.appVersionSimple, 'Phiên bản 1.0.2');
    expect(AppConstants.appVersionBuild, 'Phiên bản 1.0.2 (Build 3)');
    expect(AppConstants.appVersion, 'Phiên bản 1.0.2 (Field Ops)');
  });
}
