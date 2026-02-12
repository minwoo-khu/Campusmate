import 'package:flutter/material.dart';

// ── Semantic color extension ────────────────────────────────────────────────
@immutable
class CampusMateColors extends ThemeExtension<CampusMateColors> {
  // Scaffold / surface
  final Color scaffoldBg;
  final Color cardBg;
  final Color cardBorder;

  // Nav bar
  final Color navBarBg;
  final Color navBarShadow;
  final Color navActive;
  final Color navInactive;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textHint;

  // Quick capture / input
  final Color inputBg;

  // Section headers
  final Color sectionHeader;

  // Todo tile
  final Color tileBg;
  final Color tileCompletedBg;
  final Color tileBorder;
  final Color tileHighlightBorder;
  final Color checkActive;
  final Color checkInactive;

  // Calendar event cards
  final Color todoEventBg;
  final Color todoEventBorder;
  final Color icsEventBg;
  final Color icsEventBorder;

  // Priority colors
  final Color priorityHigh;
  final Color priorityMedium;
  final Color priorityLow;

  // Chips / badges
  final Color chipBg;
  final Color chipBorder;
  final Color iconButtonBg;

  // Action colors (delete, etc)
  final Color deleteBg;

  // Timetable
  final Color gridBorder;

  // Course badges
  final Color pdfBadgeBg;
  final Color pdfBadgeText;
  final Color memoBadgeBg;
  final Color memoBadgeText;
  final Color tipBannerBg;
  final Color tipBannerBorder;
  final Color tipBannerTitle;
  final Color tipBannerBody;

  const CampusMateColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.cardBorder,
    required this.navBarBg,
    required this.navBarShadow,
    required this.navActive,
    required this.navInactive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textHint,
    required this.inputBg,
    required this.sectionHeader,
    required this.tileBg,
    required this.tileCompletedBg,
    required this.tileBorder,
    required this.tileHighlightBorder,
    required this.checkActive,
    required this.checkInactive,
    required this.todoEventBg,
    required this.todoEventBorder,
    required this.icsEventBg,
    required this.icsEventBorder,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.priorityLow,
    required this.chipBg,
    required this.chipBorder,
    required this.iconButtonBg,
    required this.deleteBg,
    required this.gridBorder,
    required this.pdfBadgeBg,
    required this.pdfBadgeText,
    required this.memoBadgeBg,
    required this.memoBadgeText,
    required this.tipBannerBg,
    required this.tipBannerBorder,
    required this.tipBannerTitle,
    required this.tipBannerBody,
  });

  // Light palette
  static const light = CampusMateColors(
    scaffoldBg: Color(0xFFF3F4F6),
    cardBg: Colors.white,
    cardBorder: Color(0xFFE2E8F0),
    navBarBg: Colors.white,
    navBarShadow: Color(0x140F172A),
    navActive: Color(0xFF2563EB),
    navInactive: Color(0xFF98A2B3),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textTertiary: Color(0xFF64748B),
    textHint: Color(0xFF94A3B8),
    inputBg: Color(0xFFEAECEF),
    sectionHeader: Color(0xFF334155),
    tileBg: Colors.white,
    tileCompletedBg: Color(0xFFF1F5F9),
    tileBorder: Color(0xFFE2E8F0),
    tileHighlightBorder: Color(0xFFBFDBFE),
    checkActive: Color(0xFF60A5FA),
    checkInactive: Color(0xFFCBD5E1),
    todoEventBg: Colors.white,
    todoEventBorder: Color(0xFFE2E8F0),
    icsEventBg: Color(0xFFF5F3FF),
    icsEventBorder: Color(0xFFDDD6FE),
    priorityHigh: Color(0xFFEF4444),
    priorityMedium: Color(0xFFF59E0B),
    priorityLow: Color(0xFF3B82F6),
    chipBg: Colors.white,
    chipBorder: Color(0xFFE5E7EB),
    iconButtonBg: Color(0xFFE8EEF9),
    deleteBg: Color(0xFFEF4444),
    gridBorder: Color(0xFFE5E7EB),
    pdfBadgeBg: Color(0xFFF3E8FF),
    pdfBadgeText: Color(0xFF7E22CE),
    memoBadgeBg: Color(0xFFFFEDD5),
    memoBadgeText: Color(0xFFEA580C),
    tipBannerBg: Color(0xFFDEE8F8),
    tipBannerBorder: Color(0xFFBFDBFE),
    tipBannerTitle: Color(0xFF1D4ED8),
    tipBannerBody: Color(0xFF2563EB),
  );

  // Dark palette
  static const dark = CampusMateColors(
    scaffoldBg: Color(0xFF0F1117),
    cardBg: Color(0xFF1A1D27),
    cardBorder: Color(0xFF2D3348),
    navBarBg: Color(0xFF1A1D27),
    navBarShadow: Color(0x40000000),
    navActive: Color(0xFF60A5FA),
    navInactive: Color(0xFF6B7280),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFFCBD5E1),
    textTertiary: Color(0xFF94A3B8),
    textHint: Color(0xFF64748B),
    inputBg: Color(0xFF252836),
    sectionHeader: Color(0xFFCBD5E1),
    tileBg: Color(0xFF1A1D27),
    tileCompletedBg: Color(0xFF151722),
    tileBorder: Color(0xFF2D3348),
    tileHighlightBorder: Color(0xFF1E40AF),
    checkActive: Color(0xFF60A5FA),
    checkInactive: Color(0xFF475569),
    todoEventBg: Color(0xFF1A1D27),
    todoEventBorder: Color(0xFF2D3348),
    icsEventBg: Color(0xFF1E1B2E),
    icsEventBorder: Color(0xFF3B2F6B),
    priorityHigh: Color(0xFFF87171),
    priorityMedium: Color(0xFFFBBF24),
    priorityLow: Color(0xFF60A5FA),
    chipBg: Color(0xFF252836),
    chipBorder: Color(0xFF374151),
    iconButtonBg: Color(0xFF252836),
    deleteBg: Color(0xFFDC2626),
    gridBorder: Color(0xFF2D3348),
    pdfBadgeBg: Color(0xFF2E1065),
    pdfBadgeText: Color(0xFFC084FC),
    memoBadgeBg: Color(0xFF431407),
    memoBadgeText: Color(0xFFFB923C),
    tipBannerBg: Color(0xFF172554),
    tipBannerBorder: Color(0xFF1E40AF),
    tipBannerTitle: Color(0xFF93C5FD),
    tipBannerBody: Color(0xFF60A5FA),
  );

  @override
  CampusMateColors copyWith() => this;

  @override
  CampusMateColors lerp(CampusMateColors? other, double t) {
    if (other is! CampusMateColors) return this;
    return CampusMateColors(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      navBarBg: Color.lerp(navBarBg, other.navBarBg, t)!,
      navBarShadow: Color.lerp(navBarShadow, other.navBarShadow, t)!,
      navActive: Color.lerp(navActive, other.navActive, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      sectionHeader: Color.lerp(sectionHeader, other.sectionHeader, t)!,
      tileBg: Color.lerp(tileBg, other.tileBg, t)!,
      tileCompletedBg: Color.lerp(tileCompletedBg, other.tileCompletedBg, t)!,
      tileBorder: Color.lerp(tileBorder, other.tileBorder, t)!,
      tileHighlightBorder: Color.lerp(
        tileHighlightBorder,
        other.tileHighlightBorder,
        t,
      )!,
      checkActive: Color.lerp(checkActive, other.checkActive, t)!,
      checkInactive: Color.lerp(checkInactive, other.checkInactive, t)!,
      todoEventBg: Color.lerp(todoEventBg, other.todoEventBg, t)!,
      todoEventBorder: Color.lerp(todoEventBorder, other.todoEventBorder, t)!,
      icsEventBg: Color.lerp(icsEventBg, other.icsEventBg, t)!,
      icsEventBorder: Color.lerp(icsEventBorder, other.icsEventBorder, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      iconButtonBg: Color.lerp(iconButtonBg, other.iconButtonBg, t)!,
      deleteBg: Color.lerp(deleteBg, other.deleteBg, t)!,
      gridBorder: Color.lerp(gridBorder, other.gridBorder, t)!,
      pdfBadgeBg: Color.lerp(pdfBadgeBg, other.pdfBadgeBg, t)!,
      pdfBadgeText: Color.lerp(pdfBadgeText, other.pdfBadgeText, t)!,
      memoBadgeBg: Color.lerp(memoBadgeBg, other.memoBadgeBg, t)!,
      memoBadgeText: Color.lerp(memoBadgeText, other.memoBadgeText, t)!,
      tipBannerBg: Color.lerp(tipBannerBg, other.tipBannerBg, t)!,
      tipBannerBorder: Color.lerp(tipBannerBorder, other.tipBannerBorder, t)!,
      tipBannerTitle: Color.lerp(tipBannerTitle, other.tipBannerTitle, t)!,
      tipBannerBody: Color.lerp(tipBannerBody, other.tipBannerBody, t)!,
    );
  }
}

// ── Convenience accessor ────────────────────────────────────────────────────
extension CampusMateThemeX on BuildContext {
  CampusMateColors get cmColors =>
      Theme.of(this).extension<CampusMateColors>() ?? CampusMateColors.light;
}

// ── ThemeData builders ──────────────────────────────────────────────────────
class CampusMateTheme {
  CampusMateTheme._();

  static const _seed = Color(0xFF2563EB);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: CampusMateColors.light.scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: CampusMateColors.light.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: CampusMateColors.light.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: CampusMateColors.light.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: CampusMateColors.light.cardBg,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: CampusMateColors.light.chipBorder),
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return CampusMateColors.light.chipBg;
        }),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: CampusMateColors.light.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(color: CampusMateColors.light.chipBorder),
      extensions: const [CampusMateColors.light],
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: CampusMateColors.dark.scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: CampusMateColors.dark.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: CampusMateColors.dark.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: CampusMateColors.dark.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: CampusMateColors.dark.cardBg,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: CampusMateColors.dark.chipBorder),
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CampusMateColors.dark.navActive;
          }
          return CampusMateColors.dark.chipBg;
        }),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: CampusMateColors.dark.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(color: CampusMateColors.dark.chipBorder),
      extensions: const [CampusMateColors.dark],
    );
  }
}
