import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// Mô hình một ảnh hiển thị trong full-screen viewer
class FullScreenImageItem {
  final String? url;
  final String? filePath;
  final String? title;
  final String? subtitle;

  const FullScreenImageItem({
    this.url,
    this.filePath,
    this.title,
    this.subtitle,
  });

  /// Chuẩn hóa URL ảnh (§11.5)
  String? get resolvedUrl {
    if (url == null || url!.isEmpty) return null;
    final trimmed = url!.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${AppConstants.baseUrl}$trimmed';
    }
    return '${AppConstants.baseUrl}/$trimmed';
  }

  bool get isLocalFile =>
      filePath != null && filePath!.isNotEmpty && File(filePath!).existsSync();
}

/// Màn hình / Dialog xem ảnh tràn màn hình chất lượng cao
/// Hỗ trợ:
/// - Vuốt chuyển ảnh (PageView nếu có nhiều ảnh)
/// - Thu phóng & xoay/kéo (InteractiveViewer)
/// - Đếm số lượng ảnh (1 / N) và hiển thị tiêu đề/loại ảnh
/// - Nút đóng góc trên & vuốt xuống để thoát
class AppFullScreenImageViewer extends StatefulWidget {
  final List<FullScreenImageItem> items;
  final int initialIndex;

  const AppFullScreenImageViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  /// Hàm tiện ích mở full màn hình cho danh sách URL hoặc File
  static Future<void> open(
    BuildContext context, {
    required List<FullScreenImageItem> items,
    int initialIndex = 0,
  }) {
    if (items.isEmpty) return Future.value();
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black,
        pageBuilder: (ctx, anim1, anim2) => AppFullScreenImageViewer(
          items: items,
          initialIndex: initialIndex.clamp(0, items.length - 1),
        ),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  /// Mở nhanh cho danh sách URLs (String)
  static Future<void> openUrls(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
    List<String>? titles,
  }) {
    final items = urls.asMap().entries.map((e) {
      final idx = e.key;
      final u = e.value;
      final t = (titles != null && idx < titles.length) ? titles[idx] : null;
      return FullScreenImageItem(url: u, title: t);
    }).toList();

    return open(context, items: items, initialIndex: initialIndex);
  }

  /// Mở nhanh cho một ảnh duy nhất (URL hoặc local path)
  static Future<void> openSingle(
    BuildContext context, {
    String? url,
    String? filePath,
    String? title,
    String? subtitle,
  }) {
    return open(
      context,
      items: [
        FullScreenImageItem(
          url: url,
          filePath: filePath,
          title: title,
          subtitle: subtitle,
        ),
      ],
      initialIndex: 0,
    );
  }

  @override
  State<AppFullScreenImageViewer> createState() =>
      _AppFullScreenImageViewerState();
}

class _AppFullScreenImageViewerState extends State<AppFullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    final currentItem = widget.items[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PageView vuốt xem ảnh
            GestureDetector(
              onTap: _toggleOverlay,
              child: PageView.builder(
                controller: _pageController,
                itemCount: count,
                onPageChanged: (idx) {
                  setState(() {
                    _currentIndex = idx;
                  });
                },
                itemBuilder: (ctx, idx) {
                  final item = widget.items[idx];
                  return _buildZoomableImage(item);
                },
              ),
            ),

            // Top Bar: Nút đóng & Chỉ số ảnh
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _showOverlay ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  right: 12,
                  bottom: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 22),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (currentItem.title != null &&
                              currentItem.title!.isNotEmpty)
                            Text(
                              currentItem.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (currentItem.subtitle != null &&
                              currentItem.subtitle!.isNotEmpty)
                            Text(
                              currentItem.subtitle!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (count > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / $count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 26),
                      tooltip: 'Thoát',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Bar: Tiêu đề chi tiết nếu có
            if (currentItem.title != null && currentItem.title!.isNotEmpty)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: _showOverlay ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    left: 20,
                    right: 20,
                    top: 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    currentItem.title!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomableImage(FullScreenImageItem item) {
    Widget imageWidget;

    if (item.isLocalFile) {
      imageWidget = Image.file(
        File(item.filePath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildErrorWidget(),
      );
    } else {
      final url = item.resolvedUrl;
      if (url == null || url.isEmpty) {
        imageWidget = _buildErrorWidget();
      } else {
        imageWidget = Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            final expected = progress.expectedTotalBytes;
            final loaded = progress.cumulativeBytesLoaded;
            final percent = expected != null && expected > 0
                ? (loaded / expected).clamp(0.0, 1.0)
                : null;

            return Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 3,
                  color: Colors.white70,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildErrorWidget(),
        );
      }
    }

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      panEnabled: true,
      scaleEnabled: true,
      child: Center(child: imageWidget),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.broken_image_rounded, size: 64, color: Colors.white38),
        SizedBox(height: 12),
        Text(
          'Không thể tải hình ảnh này',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      ],
    );
  }
}
