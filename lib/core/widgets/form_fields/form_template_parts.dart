import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Bảng màu và thông số khung giao diện chung cho các màn nhập liệu biểu mẫu & điểm bán.
abstract final class FormTemplateTokens {
  static const Color accentGreen = Color(0xFF166534);
  static const Color badgeGreen = Color(0xFF15803D);
  static const Color onlineDotGreen = Color(0xFF16A34A);

  static Color pageBg(bool isDark) =>
      isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC);

  static Color cardSurface(bool isDark) =>
      isDark ? AppColors.darkSurfaceContainerLowest : Colors.white;

  static Color cardBorder(bool isDark) =>
      isDark ? AppColors.darkOutlineVariant : const Color(0xFFE2E8F0);

  static Color divider(bool isDark) =>
      isDark ? AppColors.darkOutlineVariant : const Color(0xFFF1F5F9);

  static Color headingText(bool isDark) =>
      isDark ? AppColors.darkOnSurface : const Color(0xFF0F172A);

  static Color bodyText(bool isDark) =>
      isDark ? AppColors.darkOnSurface : const Color(0xFF334155);

  static Color mutedText(bool isDark) =>
      isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF64748B);

  static Color subtleText(bool isDark) =>
      isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF94A3B8);

  static Color softMintBg(bool isDark) =>
      isDark ? AppColors.primary.withValues(alpha: 0.22) : const Color(0xFFDCFCE7);

  static Color softMintBorder(bool isDark) =>
      isDark ? AppColors.darkOutlineVariant : const Color(0xFFDCFCE7);

  static Color onlinePillBg(bool isDark) =>
      isDark ? const Color(0xFF10B981).withValues(alpha: 0.16) : const Color(0xFFF0FDF4);

  static Color onlinePillBorder(bool isDark) =>
      isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFBBF7D0);

  static Color onlinePillText(bool isDark) =>
      isDark ? const Color(0xFF6EE7B7) : badgeGreen;
}

/// Huy hiệu trạng thái mạng `Online` / `Offline` đặt trên AppBar của màn nhập liệu.
class FormOnlineStatusBadge extends StatelessWidget {
  final bool isOnline;

  const FormOnlineStatusBadge({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOnline
            ? FormTemplateTokens.onlinePillBg(isDark)
            : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isOnline
              ? FormTemplateTokens.onlinePillBorder(isDark)
              : AppColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? FormTemplateTokens.onlineDotGreen : AppColors.error,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isOnline
                  ? FormTemplateTokens.onlinePillText(isDark)
                  : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh tiêu đề nền trắng dùng chung cho các màn nhập liệu phiếu & điểm bán.
class FormTemplateAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final bool? isOnline;
  final List<Widget> extraActions;

  const FormTemplateAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.isOnline,
    this.extraActions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = subtitle?.trim();

    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 8,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: FormTemplateTokens.cardBorder(isDark),
        ),
      ),
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: FormTemplateTokens.bodyText(isDark),
            tooltip: 'Quay lại',
            onPressed: onBack,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium(
                    color: FormTemplateTokens.headingText(isDark),
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall(
                      color: FormTemplateTokens.mutedText(isDark),
                    ).copyWith(fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (isOnline != null)
          Padding(
            padding: EdgeInsets.only(right: extraActions.isEmpty ? 14 : 6),
            child: Center(child: FormOnlineStatusBadge(isOnline: isOnline!)),
          ),
        ...extraActions,
      ],
    );
  }
}

/// Thẻ giới thiệu đầu trang (Hero Card) với gradient trắng - xanh bạc hà dịu.
class FormHeroCard extends StatelessWidget {
  final IconData categoryIcon;
  final String categoryLabel;
  final String title;
  final String? description;
  final String? codeTag;
  final String? requiredTag;
  final IconData? footerIcon;
  final String? footerText;

  const FormHeroCard({
    super.key,
    required this.categoryIcon,
    required this.categoryLabel,
    required this.title,
    this.description,
    this.codeTag,
    this.requiredTag,
    this.footerIcon,
    this.footerText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desc = description?.trim();
    final tag = codeTag?.trim();
    final req = requiredTag?.trim();
    final footer = footerText?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF0FDF4)],
              ),
        color: isDark ? AppColors.darkSurfaceContainerLowest : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FormTemplateTokens.softMintBorder(isDark)),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: FormTemplateTokens.softMintBg(isDark),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcon,
                            size: 13,
                            color: isDark ? AppColors.primaryFixedDim : FormTemplateTokens.accentGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            categoryLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: isDark ? AppColors.primaryFixedDim : FormTemplateTokens.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (req != null && req.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          req,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (tag != null && tag.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: FormTemplateTokens.cardBorder(isDark)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: FormTemplateTokens.subtleText(isDark),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTypography.titleLarge(
              color: FormTemplateTokens.headingText(isDark),
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 18, height: 1.25),
          ),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              desc,
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF475569),
              ).copyWith(fontSize: 12.5, height: 1.45),
            ),
          ],
          if (footer != null && footer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: FormTemplateTokens.cardBorder(isDark)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    footerIcon ?? Icons.storefront_rounded,
                    size: 16,
                    color: isDark ? AppColors.primaryFixedDim : FormTemplateTokens.badgeGreen,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      footer,
                      style: AppTypography.bodyMedium(
                        color: FormTemplateTokens.bodyText(isDark),
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ mục (Section Card) dùng chung: bo góc 16px, badge chữ cái màu xanh đậm, tiêu đề + mô tả + đường kẻ ngăn.
///
/// Dùng [Material] làm bề mặt thẻ thay cho `DecoratedBox(color: ...)` để tránh lỗi assertion của Flutter khi bên
/// trong chứa `SwitchListTile` / `CheckboxListTile` / `RadioListTile`.
class FormSectionCard extends StatelessWidget {
  final String? title;
  final String? description;
  final String? badgeText;
  final String? trailingTag;
  final List<Widget> children;
  final bool hasVisibleBody;
  final Key? headerKey;
  final EdgeInsetsGeometry margin;

  const FormSectionCard({
    super.key,
    this.title,
    this.description,
    this.badgeText,
    this.trailingTag,
    required this.children,
    this.hasVisibleBody = true,
    this.headerKey,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  /// Rút chữ cái đầu kiểu `A.`, `B -`, `C:` từ tiêu đề; nếu không có thì sinh `A`, `B`, `C`... theo thứ tự [index].
  static String badgeFor(String? title, int index) {
    final trimmed = title?.trim() ?? '';
    final match = RegExp(r'^([A-Za-z])[\.\-:\s]').firstMatch(trimmed);
    if (match != null) return match.group(1)!.toUpperCase();
    if (index < 26) return String.fromCharCode(65 + index);
    return '${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanTitle = title?.trim() ?? '';
    final cleanDesc = description?.trim() ?? '';
    final showHeader = cleanTitle.isNotEmpty;
    final tag = trailingTag?.trim();

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: FormTemplateTokens.cardSurface(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: FormTemplateTokens.cardBorder(isDark)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, hasVisibleBody ? 4 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader) ...[
                KeyedSubtree(
                  key: headerKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primary : FormTemplateTokens.accentGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeText ?? 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cleanTitle,
                              style: AppTypography.titleMedium(
                                color: FormTemplateTokens.headingText(isDark),
                              ).copyWith(fontWeight: FontWeight.w700, fontSize: 15, height: 1.25),
                            ),
                            if (cleanDesc.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                cleanDesc,
                                style: AppTypography.bodySmall(
                                  color: FormTemplateTokens.mutedText(isDark),
                                ).copyWith(fontSize: 11.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (tag != null && tag.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: FormTemplateTokens.cardBorder(isDark)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: FormTemplateTokens.mutedText(isDark),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasVisibleBody) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, thickness: 1, color: FormTemplateTokens.divider(isDark)),
                  const SizedBox(height: 14),
                ],
              ],
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh hành động cố định dưới đáy màn hình nhập liệu (nền trắng, viền trên mảnh, bóng nhẹ).
class FormBottomDock extends StatelessWidget {
  final Widget child;

  const FormBottomDock({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: FormTemplateTokens.cardBorder(isDark)),
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  offset: Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
