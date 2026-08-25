import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/user_profile_detail_entity.dart';
import '../../domain/entities/user_relation_entity.dart';
import '../states/personal_info_state.dart';
import '../viewmodels/personal_info_view_model.dart';

class PersonalInfoScreen extends ConsumerWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalInfoViewModelProvider);
    final viewModel = ref.read(personalInfoViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          onPressed: () => context.pop(),
        ),
        title: Text(
          strings.personalInfoTitle,
          style: AppTypography.headlineSmallMobile(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => viewModel.loadData(isRefresh: true),
        color: AppColors.primary,
        child: _buildBody(context, state, viewModel, strings, isDark),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PersonalInfoState state,
    PersonalInfoViewModel viewModel,
    AppStrings strings,
    bool isDark,
  ) {
    if (state.status == PersonalInfoStatus.loading && state.profileDetail == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.status == PersonalInfoStatus.error && state.profileDetail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? strings.loadProfileError,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => viewModel.loadData(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.roundedMd,
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(strings.retry),
              ),
            ],
          ),
        ),
      );
    }

    final profile = state.profileDetail;
    if (profile == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
        vertical: AppSpacing.stackLg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            // 1. Profile Header Section
            _buildProfileHeader(profile, strings, isDark),
            const SizedBox(height: AppSpacing.stackLg),

            // 2. Job Information Section
            _buildWorkInfoCard(profile, strings, isDark),
            const SizedBox(height: AppSpacing.gutter),

            // 3. Contact Information Section
            _buildContactInfoCard(profile, strings, isDark),
            const SizedBox(height: AppSpacing.gutter),

            // 4. Direct Manager / Relations Section
            _buildRelationsCard(state.relations, strings, isDark),
            const SizedBox(height: AppSpacing.stackLg * 2),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    UserProfileDetailEntity profile,
    AppStrings strings,
    bool isDark,
  ) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  profile.avatarUrl.isNotEmpty
                      ? profile.avatarUrl
                      : AppConstants.userAvatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    child: Center(
                      child: Text(
                        profile.fullName.isNotEmpty
                            ? profile.fullName.trim().split(' ').last.substring(0, 1)
                            : 'V',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    width: 2,
                  ),
                  boxShadow: AppShadows.level1,
                ),
                child: const Icon(
                  Icons.photo_camera,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          profile.fullName,
          textAlign: TextAlign.center,
          style: AppTypography.headlineSmall(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${strings.employeeCodePrefix}${profile.employeeCode}',
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.15),
            borderRadius: AppRadius.roundedFull,
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                profile.statusLabel.isNotEmpty ? profile.statusLabel : strings.statusActive,
                style: AppTypography.labelSmall(
                  color: AppColors.primary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkInfoCard(
    UserProfileDetailEntity profile,
    AppStrings strings,
    bool isDark,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                strings.workInfoSection,
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildInfoRow(
            label: strings.roleLabel,
            value: profile.jobName.trim().isNotEmpty ? profile.jobName : strings.unknown,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildInfoRow(
            label: strings.departmentLabel,
            value: profile.deptName.trim().isNotEmpty ? profile.deptName : strings.unknown,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildInfoRow(
            label: strings.companyLabel,
            value: profile.company.trim().isNotEmpty ? profile.company : strings.unknown,
            isDark: isDark,
          ),
          if (profile.userTypeLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildInfoRow(
              label: strings.employeeTypeLabel,
              value: profile.userTypeLabel.trim().isNotEmpty
                  ? profile.userTypeLabel
                  : strings.unknown,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactInfoCard(
    UserProfileDetailEntity profile,
    AppStrings strings,
    bool isDark,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contacts_outlined, color: AppColors.secondary, size: 22),
              const SizedBox(width: 10),
              Text(
                strings.contactInfoSection,
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildContactTile(
            icon: Icons.phone_outlined,
            iconBgColor: AppColors.secondaryContainer.withValues(alpha: 0.3),
            iconColor: AppColors.secondary,
            label: strings.phoneNumber,
            value: profile.phone.isNotEmpty ? profile.phone : strings.notUpdated,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildContactTile(
            icon: Icons.email_outlined,
            iconBgColor: AppColors.secondaryContainer.withValues(alpha: 0.3),
            iconColor: AppColors.secondary,
            label: strings.companyEmail,
            value: profile.email.isNotEmpty ? profile.email : strings.notUpdated,
            isDark: isDark,
          ),
          if (profile.personalEmail.isNotEmpty && profile.personalEmail != profile.email) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _buildContactTile(
              icon: Icons.alternate_email_rounded,
              iconBgColor: AppColors.primaryContainer.withValues(alpha: 0.2),
              iconColor: AppColors.primary,
              label: strings.personalEmail,
              value: profile.personalEmail,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelationsCard(
    List<UserRelationEntity> relations,
    AppStrings strings,
    bool isDark,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                strings.directManagerSection,
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (relations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                strings.noManagerInfo,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
            )
          else
            ...relations.map((relation) => _buildRelationItem(relation, strings, isDark)),
        ],
      ),
    );
  }

  Widget _buildRelationItem(
    UserRelationEntity relation,
    AppStrings strings,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: Text(
                  relation.employeeName.isNotEmpty
                      ? relation.employeeName.trim().split(' ').last.substring(0, 1)
                      : 'Q',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    relation.employeeName,
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${strings.employeeCodePrefix}${relation.employeeCode}',
                    style: AppTypography.labelSmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildInfoRow(
          label: strings.roleLabel,
          value: relation.jobName.trim().isNotEmpty ? relation.jobName : strings.unknown,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _buildInfoRow(
          label: strings.departmentLabel,
          value: relation.deptName.trim().isNotEmpty ? relation.deptName : strings.unknown,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _buildInfoRow(
          label: strings.companyLabel,
          value: relation.companyBranchName.trim().isNotEmpty
              ? relation.companyBranchName
              : (relation.companyName.trim().isNotEmpty ? relation.companyName : strings.unknown),
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        if (relation.phone.isNotEmpty) ...[
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildContactTile(
            icon: Icons.phone_outlined,
            iconBgColor: AppColors.secondaryContainer.withValues(alpha: 0.3),
            iconColor: AppColors.secondary,
            label: strings.phoneNumber,
            value: relation.phone,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (relation.email.isNotEmpty) ...[
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildContactTile(
            icon: Icons.email_outlined,
            iconBgColor: AppColors.secondaryContainer.withValues(alpha: 0.3),
            iconColor: AppColors.secondary,
            label: strings.companyEmail,
            value: relation.email,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.surfaceContainerLow,
        borderRadius: AppRadius.roundedMd,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall(
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
