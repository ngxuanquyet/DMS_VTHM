import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.roundedXl,
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 1,
          shadowColor: AppColors.primary.withValues(alpha: 0.28),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, 48),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.8),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        prefixIconColor: AppColors.onSurfaceVariant,
        suffixIconColor: AppColors.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.8)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.outline,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        disabledColor: AppColors.surfaceContainer,
        selectedColor: AppColors.primaryContainer.withValues(alpha: 0.2),
        secondarySelectedColor: AppColors.primary.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedFull),
        iconTheme: const IconThemeData(
          size: 16,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.outlineVariant.withValues(alpha: 0.3),
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryFixedDim,
        onPrimary: AppColors.onPrimaryFixedVariant,
        primaryContainer: AppColors.primary,
        onPrimaryContainer: AppColors.onPrimary,
        secondary: AppColors.secondaryFixedDim,
        onSecondary: AppColors.onSecondaryFixedVariant,
        secondaryContainer: AppColors.secondary,
        onSecondaryContainer: AppColors.onSecondary,
        tertiary: AppColors.tertiaryFixedDim,
        onTertiary: AppColors.onTertiaryFixedVariant,
        tertiaryContainer: AppColors.tertiary,
        onTertiaryContainer: AppColors.onTertiary,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.primaryFixedDim,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.roundedXl,
          side: BorderSide(
            color: AppColors.darkOutlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryFixedDim,
          foregroundColor: AppColors.onPrimaryFixedVariant,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryFixedDim,
          foregroundColor: AppColors.onPrimaryFixedVariant,
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFixedDim,
          minimumSize: const Size(64, 48),
          side: BorderSide(
            color: AppColors.darkOutlineVariant.withValues(alpha: 0.8),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryFixedDim,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceContainerLowest,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        prefixIconColor: AppColors.darkOnSurfaceVariant,
        suffixIconColor: AppColors.darkOnSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(
            color: AppColors.darkOutlineVariant.withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(
            color: AppColors.darkOutlineVariant.withValues(alpha: 0.7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.primaryFixedDim, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.8)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: BorderSide(
            color: AppColors.darkOutlineVariant.withValues(alpha: 0.3),
          ),
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.darkOutline,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.darkOnSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: AppColors.primaryFixedDim,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceContainer,
        disabledColor: AppColors.darkSurface,
        selectedColor: AppColors.primary.withValues(alpha: 0.3),
        secondarySelectedColor: AppColors.primaryFixedDim.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.darkOnSurface,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryFixedDim,
        ),
        side: BorderSide(
          color: AppColors.darkOutlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.roundedFull),
        iconTheme: const IconThemeData(
          size: 16,
          color: AppColors.darkOnSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.darkOutlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
