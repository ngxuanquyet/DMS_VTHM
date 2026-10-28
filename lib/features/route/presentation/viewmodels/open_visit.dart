import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../visit/data/repositories/visit_repository_impl.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import 'route_view_model.dart';

/// Lượt viếng thăm còn MỞ của người đang dùng máy (§3 Luật 3): ưu tiên state trong RAM (màn check-in, tuyến), rồi bản
/// lưu trong máy. Bản lưu có thể đã đóng/huỷ (chưa đối soát) hoặc là lượt điểm bán mới ⇒ chỉ nhận khi `isOpen`.
/// [read] = `ref.read` của `Ref` hoặc `WidgetRef`.
Future<VisitEntity?> findOpenVisit(T Function<T>(ProviderListenable<T> provider) read) async {
  final checkInState = read(checkInViewModelProvider);
  if (checkInState.visitId != 0 && checkInState.visitEntity?.isOpen == true) return checkInState.visitEntity;
  final routeActive = read(routeViewModelProvider).activeVisit;
  if (routeActive?.isOpen == true) return routeActive;
  try {
    final saved = await read(visitRepositoryProvider).getActiveVisit();
    if (saved != null && saved.isOpen) return saved;
  } catch (_) {}
  return null;
}
