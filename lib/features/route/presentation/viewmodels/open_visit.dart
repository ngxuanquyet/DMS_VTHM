import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../visit/data/repositories/visit_repository_impl.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import 'route_view_model.dart';

/// Lượt viếng thăm còn MỞ của người đang dùng máy (§3 Luật 3): ưu tiên state trong RAM (màn check-in, tuyến), rồi bản
/// lưu trong máy. Bản lưu có thể đã đóng/huỷ (chưa đối soát) hoặc là lượt điểm bán mới ⇒ chỉ nhận khi `isOpen`.
/// Lượt ngày cũ đã có mã server không tính ([VisitEntity.isPastDayServerVisit], #24894).
/// [read] = `ref.read` của `Ref` hoặc `WidgetRef`.
Future<VisitEntity?> findOpenVisit(T Function<T>(ProviderListenable<T> provider) read) async {
  final checkInState = read(checkInViewModelProvider);
  final cs = checkInState.visitEntity;
  if (checkInState.visitId != 0 && cs != null && cs.isOpen && !cs.isPastDayServerVisit) return cs;
  final routeActive = read(routeViewModelProvider).activeVisit;
  if (routeActive != null && routeActive.isOpen && !routeActive.isPastDayServerVisit) return routeActive;
  try {
    final saved = await read(visitRepositoryProvider).getActiveVisit();
    if (saved != null && saved.isOpen && !saved.isPastDayServerVisit) return saved;
  } catch (_) {}
  return null;
}
