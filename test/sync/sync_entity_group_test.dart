import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/sync/sync_entity_group.dart';

void main() {
  group('SyncEntityGroupHelper Tests', () {
    test('1 visit checkin + 3 photos are grouped into 1 visit business entity', () {
      const visitUuid = 'visit-uuid-123';

      final entries = [
        SyncQueueEntry(
          id: 1,
          entity: 'visit',
          op: 'create',
          clientUuid: visitUuid,
          parentUuid: null,
          payload: jsonEncode({'dealer_name': 'Tạp hóa Bình An'}),
          state: 'pending',
          attempts: 0,
          nextAttemptAt: null,
          lastError: null,
          createdAt: 1000,
          createdElapsed: 1000,
          bootId: 'boot-1',
          serverId: null,
        ),
        SyncQueueEntry(
          id: 2,
          entity: 'visit_photo',
          op: 'upload',
          clientUuid: 'photo-1',
          parentUuid: visitUuid,
          payload: jsonEncode({'photo_type': 'store_front'}),
          state: 'pending',
          attempts: 0,
          nextAttemptAt: null,
          lastError: null,
          createdAt: 1001,
          createdElapsed: 1001,
          bootId: 'boot-1',
          serverId: null,
        ),
        SyncQueueEntry(
          id: 3,
          entity: 'visit_photo',
          op: 'upload',
          clientUuid: 'photo-2',
          parentUuid: visitUuid,
          payload: jsonEncode({'photo_type': 'display'}),
          state: 'pending',
          attempts: 0,
          nextAttemptAt: null,
          lastError: null,
          createdAt: 1002,
          createdElapsed: 1002,
          bootId: 'boot-1',
          serverId: null,
        ),
        SyncQueueEntry(
          id: 4,
          entity: 'visit_photo',
          op: 'upload',
          clientUuid: 'photo-3',
          parentUuid: visitUuid,
          payload: jsonEncode({'photo_type': 'other'}),
          state: 'pending',
          attempts: 0,
          nextAttemptAt: null,
          lastError: null,
          createdAt: 1003,
          createdElapsed: 1003,
          bootId: 'boot-1',
          serverId: null,
        ),
      ];

      final grouped = SyncEntityGroupHelper.groupEntries(entries);
      expect(grouped.length, 1);
      expect(grouped.first.entityType, 'visit');
      expect(grouped.first.title, contains('Tạp hóa Bình An'));
      expect(grouped.first.subtitle, contains('Kèm 3 ảnh'));
      expect(grouped.first.totalEntries, 4);

      final summary = SyncEntityGroupHelper.buildSummaryText(entries);
      expect(summary, '1 lượt viếng thăm');
    });

    test('1 customer + 1 visit with photos are grouped into 2 business entities', () {
      const visitUuid = 'visit-uuid-456';
      const custUuid = 'cust-uuid-789';

      final entries = [
        SyncQueueEntry(
          id: 1,
          entity: 'customer',
          op: 'create',
          clientUuid: custUuid,
          parentUuid: null,
          payload: jsonEncode({'name': 'Đại lý Thành Công', 'route': 'Tuyến 1'}),
          state: 'pending',
          attempts: 0,
          nextAttemptAt: null,
          lastError: null,
          createdAt: 1000,
          createdElapsed: 1000,
          bootId: 'boot-1',
          serverId: null,
        ),
        SyncQueueEntry(
          id: 2,
          entity: 'visit',
          op: 'create',
          clientUuid: visitUuid,
          parentUuid: null,
          payload: jsonEncode({'dealer_name': 'Đại lý Thành Công'}),
          state: 'pending',
          attempts: 0,
          nextAttemptAt: null,
          lastError: null,
          createdAt: 1001,
          createdElapsed: 1001,
          bootId: 'boot-1',
          serverId: null,
        ),
        SyncQueueEntry(
          id: 3,
          entity: 'visit_photo',
          op: 'upload',
          clientUuid: 'photo-1',
          parentUuid: visitUuid,
          payload: jsonEncode({'photo_type': 'store_front'}),
          state: 'pending',
          attempts: 0,
          nextAttemptAt: null,
          lastError: null,
          createdAt: 1002,
          createdElapsed: 1002,
          bootId: 'boot-1',
          serverId: null,
        ),
      ];

      final grouped = SyncEntityGroupHelper.groupEntries(entries);
      expect(grouped.length, 2);

      final summary = SyncEntityGroupHelper.buildSummaryText(entries);
      expect(summary, '1 điểm bán, 1 lượt viếng thăm');
    });
  });
}
