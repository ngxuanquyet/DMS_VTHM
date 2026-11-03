import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/utils/rich_image_cache.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

/// Ô "Tài liệu hướng dẫn" (`note`) của biểu mẫu thị trường: [title] làm tiêu đề có biểu tượng; BẤM mới mở / thu phần
/// [description] — HTML server đã làm sạch (đoạn, đậm/nghiêng, danh sách, liên kết, ảnh `<img data-token>`).
/// Ô note cũ: description chữ thường ⇒ hiện nguyên văn (giữ xuống dòng); không có tiêu đề ⇒ hiện thẳng nội dung như
/// trước, không thu gọn. Không ghi gì vào câu trả lời.
class NoteFieldWidget extends StatefulWidget {
  final String title;
  final String? description;

  const NoteFieldWidget({super.key, required this.title, this.description});

  /// CHỈ thẻ của trình soạn văn bản — chữ thường của ô note cũ kiểu `<Tên SP>` không bị coi là HTML (mất chữ).
  static final RegExp _htmlTag = RegExp(
      // Sau tên thẻ phải là '>' / '/>' hoặc một thuộc tính `ten=` — chữ thường kiểu `<sữa …>`, `<b 2 thùng>` không khớp.
      r'<\s*/?\s*(p|br|strong|b|em|i|u|s|ul|ol|li|a|img|h[1-6]|span|div|blockquote|hr|table|thead|tbody|tr|td|th|code|pre|sub|sup)(\s*/?>|\s+[a-zA-Z-]+\s*=[^>]*>)',
      caseSensitive: false);

  /// Nội dung có thẻ HTML (khác chữ thường của ô note cũ).
  static bool looksLikeHtml(String s) => _htmlTag.hasMatch(s);

  /// Chữ thường đã qua bộ làm sạch của server (`&lt;`, `&amp;`…) ⇒ trả về ký tự gốc để hiện bằng Text.
  static String unescapeEntities(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#039;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');

  @override
  State<NoteFieldWidget> createState() => _NoteFieldWidgetState();
}

class _NoteFieldWidgetState extends State<NoteFieldWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.title.trim();
    final desc = widget.description?.trim() ?? '';
    final textColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final collapsible = title.isNotEmpty && desc.isNotEmpty;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(collapsible ? Icons.menu_book_outlined : Icons.info_outline, size: 20, color: AppColors.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: title.isNotEmpty
              ? Text(
                  title,
                  style: AppTypography.bodyMedium(color: textColor)
                      .copyWith(fontWeight: collapsible ? FontWeight.w600 : null),
                )
              : _content(desc, textColor),
        ),
        if (collapsible)
          Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 22, color: textColor),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (collapsible)
            InkWell(
              key: const ValueKey('note_toggle'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(padding: const EdgeInsets.all(12), child: header),
            )
          else
            Padding(padding: const EdgeInsets.all(12), child: header),
          if (collapsible && _expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _content(desc, textColor),
            ),
        ],
      ),
    );
  }

  Widget _content(String desc, Color textColor) {
    final style = AppTypography.bodyMedium(color: textColor);
    if (!NoteFieldWidget.looksLikeHtml(desc)) return Text(NoteFieldWidget.unescapeEntities(desc), style: style);
    return HtmlWidget(
      desc,
      textStyle: style,
      customWidgetBuilder: (element) {
        if (element.localName != 'img') return null;
        final token = element.attributes['data-token']?.trim() ?? '';
        if (token.isEmpty) return null; // <img src> thường: để gói tự vẽ
        return RichImageView(token: token);
      },
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null) return false;
        try {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          return false;
        }
      },
    );
  }
}

class RichImageView extends ConsumerStatefulWidget {
  final String? token;

  const RichImageView({super.key, required String this.token});

  const RichImageView.broken({super.key}) : token = null;

  @override
  ConsumerState<RichImageView> createState() => _RichImageViewState();
}

class _RichImageViewState extends ConsumerState<RichImageView> {
  Future<File?>? _future;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Widget được dùng lại cho ảnh khác (ô ẩn/hiện theo điều kiện làm các ô dồn chỗ) ⇒ tải lại theo token mới.
  @override
  void didUpdateWidget(RichImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _start();
  }

  void _start() {
    final token = widget.token;
    _future = token == null ? null : ref.read(richImageCacheProvider).load(token).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return _placeholder(broken: true);
    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _placeholder(broken: false);
        final file = snap.data;
        if (file == null) return _placeholder(broken: true);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              // Ảnh điện thoại vài MB: giải mã ở cỡ màn hình, không ở cỡ gốc.
              cacheWidth: 1080,
              errorBuilder: (_, __, ___) => _placeholder(broken: true),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder({required bool broken}) => Container(
        key: ValueKey(broken ? 'rich_image_broken' : 'rich_image_loading'),
        width: 64,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6)),
        child: Icon(broken ? Icons.broken_image_outlined : Icons.image_outlined, size: 20, color: Colors.grey.shade600),
      );
}
