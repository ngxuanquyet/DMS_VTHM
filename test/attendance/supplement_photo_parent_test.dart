// ignore_for_file: invalid_use_of_protected_member
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:vthm_dms/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:vthm_dms/features/attendance/presentation/viewmodels/attendance_view_model.dart';

/// Rà soát offline vòng 2 (#24698), nhóm 2: "Bổ sung ảnh" cho lượt chấm CŨ phải gắn lượt cha là chính lượt đó — lượt
/// ngoại tuyến (id âm) được hàng đợi dò id máy chủ qua lượt cha, lấy lượt mới nhất là ảnh lên nhầm lượt.

/// Kho chấm công giả: chỉ ghi lại `parentUuid` của ảnh xếp hàng; mọi lệnh khác lỗi (màn bỏ qua khi nạp đầu).
class _Repo implements AttendanceRepository {
  final parents = <String?>[];

  @override
  Future<AttendancePunchPhotoEntity> enqueuePunchPhoto({
    required int punchId,
    required File file,
    required String photoType,
    DateTime? takenAt,
    double? lat,
    double? lng,
    String? parentUuid,
  }) async {
    parents.add(parentUuid);
    return AttendancePunchPhotoEntity(id: -1, url: file.path, photoType: photoType, photoTypeLabel: photoType);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AttendancePunchEntity _punch(int id, String uuid) => AttendancePunchEntity(
      id: id,
      punchAt: '2026-11-02T08:00:00+07:00',
      clientUuid: uuid,
      lat: 21,
      lng: 105.8,
      requirements: const AttendanceRequirementsEntity(),
    );

void main() {
  late _Repo repo;
  late AttendanceViewModel vm;

  setUp(() async {
    repo = _Repo();
    vm = AttendanceViewModel(
      getConfigUseCase: GetAttendanceConfigUseCase(repo),
      punchUseCase: PunchAttendanceUseCase(repo),
      uploadPhotoUseCase: UploadPunchPhotoUseCase(repo),
      getHistoryUseCase: GetAttendanceHistoryUseCase(repo),
      getAttendanceDetailUseCase: GetAttendanceDetailUseCase(repo),
      attendanceRepository: repo,
    );
    await Future<void>.delayed(Duration.zero);
    final old = _punch(-1000, 'old-uuid');
    final latest = _punch(-2000, 'latest-uuid');
    vm.state = vm.state.copyWith(latestPunch: latest, history: [latest, old]);
  });

  test('ảnh bổ sung cho lượt cũ ngoại tuyến gắn lượt cha = lượt cũ, không phải lượt mới nhất', () async {
    await vm.uploadPunchPhoto(punchId: -1000, file: File('/tmp/x.jpg'), photoType: 'front');
    expect(repo.parents, ['old-uuid'], reason: 'lỗi cũ: luôn lấy latestPunch.clientUuid');
  });

  test('lượt mới nhất vẫn gắn đúng', () async {
    await vm.uploadPunchPhoto(punchId: -2000, file: File('/tmp/x.jpg'), photoType: 'front');
    expect(repo.parents, ['latest-uuid']);
  });

  test('nơi gọi truyền client_uuid của lượt ⇒ dùng nó; chuỗi rỗng coi như không có', () async {
    await vm.uploadPunchPhoto(punchId: -1000, file: File('/tmp/x.jpg'), photoType: 'front', punchClientUuid: 'given');
    await vm.uploadPunchPhoto(punchId: -1000, file: File('/tmp/x.jpg'), photoType: 'back', punchClientUuid: '');
    expect(repo.parents, ['given', 'old-uuid']);
  });

  test('lượt ngoại tuyến không còn trong màn ⇒ báo lỗi, KHÔNG xếp ảnh mồ côi', () async {
    final photo = await vm.uploadPunchPhoto(punchId: -3000, file: File('/tmp/x.jpg'), photoType: 'front');
    expect(photo, isNull);
    expect(repo.parents, isEmpty);
    expect(vm.state.errorMessage, 'Không tìm thấy lượt chấm công cần bổ sung ảnh. Vui lòng tải lại màn hình.');
  });
}
