import 'package:flutter/material.dart';

import '../logo_widget.dart';

enum EnterpriseViewport { mobile, tablet, desktop, ultraWide }

class EnterpriseBreakpoints {
  const EnterpriseBreakpoints._();

  static const mobileMax = 767.0;
  static const tabletMax = 1199.0;
  static const ultraWideMin = 1600.0;

  static EnterpriseViewport fromWidth(double width) {
    if (width <= mobileMax) return EnterpriseViewport.mobile;
    if (width <= tabletMax) return EnterpriseViewport.tablet;
    if (width >= ultraWideMin) return EnterpriseViewport.ultraWide;
    return EnterpriseViewport.desktop;
  }
}

extension EnterpriseViewportX on EnterpriseViewport {
  bool get isMobile => this == EnterpriseViewport.mobile;
  bool get isTablet => this == EnterpriseViewport.tablet;
  bool get isDesktop =>
      this == EnterpriseViewport.desktop ||
      this == EnterpriseViewport.ultraWide;
}

class EnterpriseSpacing {
  const EnterpriseSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class EnterpriseRadii {
  const EnterpriseRadii._();

  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
}

class EnterpriseThemeEngine {
  const EnterpriseThemeEngine._();

  static ThemeData theme({
    Brightness brightness = Brightness.light,
    bool highContrast = false,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? AppBrand.info : AppBrand.primary,
      onPrimary: Colors.white,
      secondary: AppBrand.secondary,
      onSecondary: Colors.white,
      tertiary: AppBrand.accent,
      onTertiary: AppBrand.primary,
      error: AppBrand.error,
      onError: Colors.white,
      surface: dark ? AppBrand.darkSurface : AppBrand.surface,
      onSurface: dark ? Colors.white : AppBrand.ink,
      surfaceContainerHighest: dark
          ? const Color(0xFF1F2937)
          : const Color(0xFFE2E8F0),
      outline: highContrast
          ? (dark ? Colors.white : AppBrand.primary)
          : (dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
    );

    final background = dark ? AppBrand.darkBackground : AppBrand.surface;
    final panel = dark ? AppBrand.darkSurface : Colors.white;
    final border = highContrast
        ? scheme.outline
        : (dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final textTheme = _textTheme(dark);

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['SF Pro Display', 'Segoe UI', 'Roboto'],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: panel,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: EnterpriseSpacing.xs),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        prefixIconColor: AppBrand.muted,
        suffixIconColor: AppBrand.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
          borderSide: BorderSide(color: scheme.secondary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: EnterpriseSpacing.lg,
          vertical: 14,
        ),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EnterpriseRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EnterpriseRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EnterpriseRadii.md),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark
            ? const Color(0xFF1E293B)
            : const Color(0xFFEFF6FF),
        selectedColor: dark ? const Color(0xFF1D4ED8) : const Color(0xFFDBEAFE),
        disabledColor: dark ? const Color(0xFF111827) : const Color(0xFFE2E8F0),
        labelStyle: TextStyle(fontSize: 12, color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(fontSize: 12, color: scheme.onSurface),
        checkmarkColor: scheme.secondary,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 48,
        iconColor: scheme.secondary,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.secondary,
        unselectedLabelColor: dark ? const Color(0xFFCBD5E1) : AppBrand.muted,
        indicatorColor: scheme.secondary,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: panel,
        indicatorColor: scheme.secondary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: scheme.secondary),
        unselectedIconTheme: IconThemeData(
          color: dark ? const Color(0xFFCBD5E1) : AppBrand.muted,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.secondary,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: panel,
        modalBarrierColor: Colors.black.withValues(alpha: 0.36),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EnterpriseRadii.lg),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: scheme.onSurface,
        ),
        dataTextStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurface),
        headingRowColor: WidgetStatePropertyAll(
          dark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
        ),
        dividerThickness: 1,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(false),
        thumbColor: WidgetStatePropertyAll(
          scheme.secondary.withValues(alpha: dark ? 0.55 : 0.36),
        ),
        radius: const Radius.circular(EnterpriseRadii.md),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFE2E8F0) : AppBrand.primary,
          borderRadius: BorderRadius.circular(EnterpriseRadii.sm),
        ),
        textStyle: TextStyle(color: dark ? AppBrand.primary : Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EnterpriseRadii.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFFE2E8F0) : AppBrand.primary,
        contentTextStyle: TextStyle(
          color: dark ? AppBrand.primary : Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
      ),
      focusColor: scheme.secondary.withValues(
        alpha: highContrast ? 0.35 : 0.18,
      ),
    );
  }

  static TextTheme _textTheme(bool dark) {
    final color = dark ? Colors.white : AppBrand.ink;
    final muted = dark ? const Color(0xFFCBD5E1) : AppBrand.muted;
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.08,
        fontWeight: FontWeight.w900,
        color: color,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.16,
        fontWeight: FontWeight.w900,
        color: color,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: color,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: color,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: color),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: color),
      bodySmall: TextStyle(fontSize: 12, height: 1.35, color: muted),
      labelLarge: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: color,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
    );
  }
}

class EnterprisePanel extends StatelessWidget {
  const EnterprisePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(EnterpriseSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(EnterpriseRadii.md),
      ),
      child: child,
    );
  }
}

class EnterpriseStatusPill extends StatelessWidget {
  const EnterpriseStatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(EnterpriseRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
