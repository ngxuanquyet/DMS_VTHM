import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Danh sách HIỆN DẦN từng [pageSize] dòng (mặc định 12 — vừa hơn một màn hình): đầu tiên [pageSize] dòng, cuộn gần
/// cuối thì hiện thêm [pageSize].
///
/// Dữ liệu vẫn nằm đủ trong bộ nhớ (tải ngầm về máy để dùng khi mất mạng, lọc/sắp/đếm trên TOÀN bộ) — widget chỉ giới
/// hạn số dòng đưa vào danh sách. Đổi [resetKey] (bộ lọc, từ khoá, kiểu sắp) thì quay về [pageSize] dòng đầu.
class IncrementalListView extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder separatorBuilder;
  final int pageSize;
  final Object? resetKey;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  /// Tên đơn vị ở dòng cuối ("Đang hiện 12/1.090 điểm bán").
  final String unitLabel;

  /// Còn cách đáy bao nhiêu px thì hiện thêm trang sau — đủ xa để người dùng không chạm đáy rồi mới thấy dòng mới.
  final double loadMoreExtent;

  const IncrementalListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.separatorBuilder,
    this.pageSize = 12,
    this.resetKey,
    this.controller,
    this.padding,
    this.physics,
    this.unitLabel = 'điểm bán',
    this.loadMoreExtent = 800,
  });

  @override
  State<IncrementalListView> createState() => _IncrementalListViewState();
}

class _IncrementalListViewState extends State<IncrementalListView> {
  late int _visible = widget.pageSize;

  /// Một lần cuộn phát NHIỀU thông báo trước khi danh sách kịp dựng lại — không chặn thì một cú cuộn thêm 300 dòng.
  bool _growScheduled = false;

  @override
  void didUpdateWidget(IncrementalListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey || oldWidget.pageSize != widget.pageSize) {
      _visible = widget.pageSize;
      // Đổi bộ lọc khi đang cuộn sâu: vị trí cũ vượt quá số dòng mới ⇒ bị kẹp ở đáy, đứng trước dòng "cuộn để xem
      // thêm" mà không có thông báo cuộn nào để hiện tiếp. Danh sách đã khác ⇒ về đầu.
      final c = widget.controller;
      if (c != null && c.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && c.hasClients) c.jumpTo(0);
        });
      }
    }
  }

  /// Nghe cả cuộn lẫn đổi kích thước nội dung (`ScrollMetricsNotification`, có ngay sau lần dựng đầu): 12 dòng không
  /// đầy màn (máy tính bảng, xoay ngang) thì không có cú cuộn nào — chỉ nghe cuộn là kẹt ở dòng "cuộn để xem thêm".
  bool _onScroll(Notification notification) {
    final ScrollMetrics metrics;
    final int depth;
    if (notification is ScrollNotification) {
      metrics = notification.metrics;
      depth = notification.depth;
    } else if (notification is ScrollMetricsNotification) {
      metrics = notification.metrics;
      depth = notification.depth;
    } else {
      return false;
    }
    // depth 0: chỉ cuộn của CHÍNH danh sách này, không phải ô cuộn lồng trong một thẻ.
    if (depth == 0 &&
        metrics.axis == Axis.vertical &&
        metrics.extentAfter < widget.loadMoreExtent &&
        _visible < widget.itemCount &&
        !_growScheduled) {
      _growScheduled = true;
      setState(() => _visible += widget.pageSize);
      WidgetsBinding.instance.addPostFrameCallback((_) => _growScheduled = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.itemCount < _visible ? widget.itemCount : _visible;
    final hasMore = shown < widget.itemCount;

    return NotificationListener<Notification>(
      onNotification: _onScroll,
      child: ListView.separated(
        controller: widget.controller,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: shown + (hasMore ? 1 : 0),
        separatorBuilder: widget.separatorBuilder,
        itemBuilder: (context, index) {
          if (index == shown) return _buildFooter(context, shown);
          return widget.itemBuilder(context, index);
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context, int shown) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Đang hiện $shown/${widget.itemCount} ${widget.unitLabel} — cuộn để xem thêm',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
