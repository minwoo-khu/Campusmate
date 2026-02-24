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
    scaffoldBg: Color(0xFFF3FAFF),
    cardBg: Colors.white,
    cardBorder: Color(0xFFDDF2FF),
    navBarBg: Color(0xFFFFFDFC),
    navBarShadow: Color(0x140C2842),
    navActive: Color(0xFF5FA8E8),
    navInactive: Color(0xFF7E95B2),
    textPrimary: Color(0xFF16314A),
    textSecondary: Color(0xFF26435E),
    textTertiary: Color(0xFF4A6986),
    textHint: Color(0xFF7B9BB7),
    inputBg: Color(0xFFFFF7F3),
    sectionHeader: Color(0xFF16314A),
    tileBg: Colors.white,
    tileCompletedBg: Color(0xFFFFFBF9),
    tileBorder: Color(0xFFDDF2FF),
    tileHighlightBorder: Color(0xFF88C8FF),
    checkActive: Color(0xFF5FA8E8),
    checkInactive: Color(0xFFB8D9F3),
    todoEventBg: Colors.white,
    todoEventBorder: Color(0xFFDDF2FF),
    icsEventBg: Color(0xFFFFFBF7),
    icsEventBorder: Color(0xFFFCEDE4),
    priorityHigh: Color(0xFFDF3D3D),
    priorityMedium: Color(0xFFE8A81E),
    priorityLow: Color(0xFF5FA8E8),
    chipBg: Color(0xFFFFFDFC),
    chipBorder: Color(0xFFF8E9DF),
    iconButtonBg: Color(0xFFEEF8FF),
    deleteBg: Color(0xFFD83A3A),
    gridBorder: Color(0xFFE4F1FB),
    pdfBadgeBg: Color(0xFFEAF6FF),
    pdfBadgeText: Color(0xFF5FA8E8),
    memoBadgeBg: Color(0xFFFFF8F4),
    memoBadgeText: Color(0xFF5D4A42),
    tipBannerBg: Color(0xFFFFFAF6),
    tipBannerBorder: Color(0xFFFBEDE3),
    tipBannerTitle: Color(0xFF5FA8E8),
    tipBannerBody: Color(0xFF2D4A63),
  );

  // Dark palette
  static const dark = CampusMateColors(
    scaffoldBg: Color(0xFF090B10),
    cardBg: Color(0xFF11141B),
    cardBorder: Color(0xFF1F2633),
    navBarBg: Color(0xFF11141B),
    navBarShadow: Color(0x60000000),
    navActive: Color(0xFF74B8F5),
    navInactive: Color(0xFF647085),
    textPrimary: Color(0xFFEFF3FF),
    textSecondary: Color(0xFFD8E1F5),
    textTertiary: Color(0xFFA5B4CF),
    textHint: Color(0xFF7584A1),
    inputBg: Color(0xFF171A21),
    sectionHeader: Color(0xFFDCE6FF),
    tileBg: Color(0xFF11141B),
    tileCompletedBg: Color(0xFF0D1118),
    tileBorder: Color(0xFF1F2633),
    tileHighlightBorder: Color(0xFF74B8F5),
    checkActive: Color(0xFF74B8F5),
    checkInactive: Color(0xFF4A566D),
    todoEventBg: Color(0xFF11141B),
    todoEventBorder: Color(0xFF1F2633),
    icsEventBg: Color(0xFF171D28),
    icsEventBorder: Color(0xFF2A3447),
    priorityHigh: Color(0xFFF56B6B),
    priorityMedium: Color(0xFFFBC65D),
    priorityLow: Color(0xFF74B8F5),
    chipBg: Color(0xFF171D28),
    chipBorder: Color(0xFF2A3447),
    iconButtonBg: Color(0xFF171D28),
    deleteBg: Color(0xFFE04A4A),
    gridBorder: Color(0xFF273043),
    pdfBadgeBg: Color(0xFF1E2430),
    pdfBadgeText: Color(0xFFA9D6FF),
    memoBadgeBg: Color(0xFF202734),
    memoBadgeText: Color(0xFFE7ECF8),
    tipBannerBg: Color(0xFF1A2233),
    tipBannerBorder: Color(0xFF2A3447),
    tipBannerTitle: Color(0xFFA9D6FF),
    tipBannerBody: Color(0xFFE6EEFF),
  );

  @override
  CampusMateColors copyWith({
    Color? scaffoldBg,
    Color? cardBg,
    Color? cardBorder,
    Color? navBarBg,
    Color? navBarShadow,
    Color? navActive,
    Color? navInactive,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textHint,
    Color? inputBg,
    Color? sectionHeader,
    Color? tileBg,
    Color? tileCompletedBg,
    Color? tileBorder,
    Color? tileHighlightBorder,
    Color? checkActive,
    Color? checkInactive,
    Color? todoEventBg,
    Color? todoEventBorder,
    Color? icsEventBg,
    Color? icsEventBorder,
    Color? priorityHigh,
    Color? priorityMedium,
    Color? priorityLow,
    Color? chipBg,
    Color? chipBorder,
    Color? iconButtonBg,
    Color? deleteBg,
    Color? gridBorder,
    Color? pdfBadgeBg,
    Color? pdfBadgeText,
    Color? memoBadgeBg,
    Color? memoBadgeText,
    Color? tipBannerBg,
    Color? tipBannerBorder,
    Color? tipBannerTitle,
    Color? tipBannerBody,
  }) {
    return CampusMateColors(
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      navBarBg: navBarBg ?? this.navBarBg,
      navBarShadow: navBarShadow ?? this.navBarShadow,
      navActive: navActive ?? this.navActive,
      navInactive: navInactive ?? this.navInactive,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textHint: textHint ?? this.textHint,
      inputBg: inputBg ?? this.inputBg,
      sectionHeader: sectionHeader ?? this.sectionHeader,
      tileBg: tileBg ?? this.tileBg,
      tileCompletedBg: tileCompletedBg ?? this.tileCompletedBg,
      tileBorder: tileBorder ?? this.tileBorder,
      tileHighlightBorder: tileHighlightBorder ?? this.tileHighlightBorder,
      checkActive: checkActive ?? this.checkActive,
      checkInactive: checkInactive ?? this.checkInactive,
      todoEventBg: todoEventBg ?? this.todoEventBg,
      todoEventBorder: todoEventBorder ?? this.todoEventBorder,
      icsEventBg: icsEventBg ?? this.icsEventBg,
      icsEventBorder: icsEventBorder ?? this.icsEventBorder,
      priorityHigh: priorityHigh ?? this.priorityHigh,
      priorityMedium: priorityMedium ?? this.priorityMedium,
      priorityLow: priorityLow ?? this.priorityLow,
      chipBg: chipBg ?? this.chipBg,
      chipBorder: chipBorder ?? this.chipBorder,
      iconButtonBg: iconButtonBg ?? this.iconButtonBg,
      deleteBg: deleteBg ?? this.deleteBg,
      gridBorder: gridBorder ?? this.gridBorder,
      pdfBadgeBg: pdfBadgeBg ?? this.pdfBadgeBg,
      pdfBadgeText: pdfBadgeText ?? this.pdfBadgeText,
      memoBadgeBg: memoBadgeBg ?? this.memoBadgeBg,
      memoBadgeText: memoBadgeText ?? this.memoBadgeText,
      tipBannerBg: tipBannerBg ?? this.tipBannerBg,
      tipBannerBorder: tipBannerBorder ?? this.tipBannerBorder,
      tipBannerTitle: tipBannerTitle ?? this.tipBannerTitle,
      tipBannerBody: tipBannerBody ?? this.tipBannerBody,
    );
  }

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

@immutable
class CampusMateCustomPalette {
  final Color primary;
  final Color soft;
  final Color banner;
  final Color danger;

  const CampusMateCustomPalette({
    required this.primary,
    required this.soft,
    required this.banner,
    required this.danger,
  });

  static const defaults = CampusMateCustomPalette(
    primary: Color(0xFF5FA8E8),
    soft: Color(0xFFEEF3FA),
    banner: Color(0xFFEDF3FF),
    danger: Color(0xFFD83A3A),
  );

  CampusMateCustomPalette copyWith({
    Color? primary,
    Color? soft,
    Color? banner,
    Color? danger,
  }) {
    return CampusMateCustomPalette(
      primary: primary ?? this.primary,
      soft: soft ?? this.soft,
      banner: banner ?? this.banner,
      danger: danger ?? this.danger,
    );
  }

  Map<String, int> toStorageMap() {
    return {
      'primary': primary.toARGB32(),
      'soft': soft.toARGB32(),
      'banner': banner.toARGB32(),
      'danger': danger.toARGB32(),
    };
  }

  static CampusMateCustomPalette fromStorageMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) return defaults;
    return CampusMateCustomPalette(
      primary: _parseColor(raw['primary'], defaults.primary),
      soft: _parseColor(raw['soft'], defaults.soft),
      banner: _parseColor(raw['banner'], defaults.banner),
      danger: _parseColor(raw['danger'], defaults.danger),
    );
  }

  static Color _parseColor(dynamic raw, Color fallback) {
    final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (value == null) return fallback;
    return Color(value & 0xFFFFFFFF);
  }
}

// ── ThemeData builders ──────────────────────────────────────────────────────
class CampusMateTheme {
  CampusMateTheme._();

  static const String defaultPaletteKey = 'slate_blue_gray';
  static const String customPaletteKey = 'custom';
  static const List<String> paletteKeys = [
    'slate_blue_gray',
    'sky_peach',
    'powder_mint',
    'periwinkle_lavender',
    customPaletteKey,
  ];

  static bool isValidPaletteKey(String key) => paletteKeys.contains(key);

  static ThemeData light({
    String paletteKey = defaultPaletteKey,
    CampusMateCustomPalette customPalette = CampusMateCustomPalette.defaults,
  }) {
    final colors = _resolveLightColors(paletteKey, customPalette);
    final seed = _resolveSeedColor(paletteKey, customPalette);
    return _buildTheme(
      colors: colors,
      seed: seed,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark({
    String paletteKey = defaultPaletteKey,
    CampusMateCustomPalette customPalette = CampusMateCustomPalette.defaults,
  }) {
    final colors = _resolveDarkColors(paletteKey, customPalette);
    final seed = _resolveSeedColor(paletteKey, customPalette);
    return _buildTheme(colors: colors, seed: seed, brightness: Brightness.dark);
  }

  static ThemeData _buildTheme({
    required CampusMateColors colors,
    required Color seed,
    required Brightness brightness,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: colors.scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.cardBg,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: colors.chipBorder),
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.navActive;
          }
          return colors.chipBg;
        }),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(color: colors.chipBorder),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.navActive,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.navActive.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textSecondary,
          side: BorderSide(color: colors.chipBorder),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.navActive,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      extensions: [colors],
    );
  }

  static Color _resolveSeedColor(
    String paletteKey,
    CampusMateCustomPalette customPalette,
  ) {
    if (paletteKey == customPaletteKey) {
      return customPalette.primary;
    }
    switch (paletteKey) {
      case 'powder_mint':
        return const Color(0xFF8ED8CF);
      case 'periwinkle_lavender':
        return const Color(0xFFAAB7FF);
      case 'slate_blue_gray':
        return const Color(0xFF9EC0F8);
      case 'sky_peach':
      default:
        return const Color(0xFF88C8FF);
    }
  }

  static CampusMateColors _resolveLightColors(
    String paletteKey,
    CampusMateCustomPalette customPalette,
  ) {
    final base = CampusMateColors.light;
    if (paletteKey == customPaletteKey) {
      return _buildCustomLightColors(base, customPalette);
    }
    switch (paletteKey) {
      case 'powder_mint':
        return base.copyWith(
          scaffoldBg: const Color(0xFFF2FAF8),
          cardBorder: const Color(0xFFD7EFE7),
          navBarBg: const Color(0xFFFAFFFD),
          navBarShadow: const Color(0x14203C39),
          navActive: const Color(0xFF6DBEB2),
          navInactive: const Color(0xFF77989A),
          textPrimary: const Color(0xFF163935),
          textSecondary: const Color(0xFF24514C),
          textTertiary: const Color(0xFF42716B),
          textHint: const Color(0xFF6F9790),
          inputBg: const Color(0xFFEDF8F5),
          sectionHeader: const Color(0xFF163935),
          tileCompletedBg: const Color(0xFFF6FCFA),
          tileBorder: const Color(0xFFD7EFE7),
          tileHighlightBorder: const Color(0xFF94DACE),
          checkActive: const Color(0xFF6DBEB2),
          checkInactive: const Color(0xFFB3DDD5),
          todoEventBorder: const Color(0xFFD7EFE7),
          icsEventBg: const Color(0xFFF3F8FF),
          icsEventBorder: const Color(0xFFDFE9FA),
          priorityLow: const Color(0xFF6DBEB2),
          chipBg: const Color(0xFFFCFFFE),
          chipBorder: const Color(0xFFD6ECE6),
          iconButtonBg: const Color(0xFFE9F7F3),
          gridBorder: const Color(0xFFDDEFEA),
          pdfBadgeBg: const Color(0xFFE7F6F2),
          pdfBadgeText: const Color(0xFF4BAEA1),
          memoBadgeBg: const Color(0xFFEFFAF7),
          memoBadgeText: const Color(0xFF345853),
          tipBannerBg: const Color(0xFFEAF8F4),
          tipBannerBorder: const Color(0xFFD2ECE5),
          tipBannerTitle: const Color(0xFF4BAEA1),
          tipBannerBody: const Color(0xFF2A4D48),
        );
      case 'periwinkle_lavender':
        return base.copyWith(
          scaffoldBg: const Color(0xFFF6F5FF),
          cardBorder: const Color(0xFFE6E0FF),
          navBarBg: const Color(0xFFFDFCFF),
          navBarShadow: const Color(0x141B173A),
          navActive: const Color(0xFF8FA4FF),
          navInactive: const Color(0xFF827FA5),
          textPrimary: const Color(0xFF221B45),
          textSecondary: const Color(0xFF352E61),
          textTertiary: const Color(0xFF57507F),
          textHint: const Color(0xFF8B86AE),
          inputBg: const Color(0xFFF2EEFF),
          sectionHeader: const Color(0xFF221B45),
          tileCompletedBg: const Color(0xFFF9F7FF),
          tileBorder: const Color(0xFFE6E0FF),
          tileHighlightBorder: const Color(0xFFB0BCFF),
          checkActive: const Color(0xFF8FA4FF),
          checkInactive: const Color(0xFFC6C6E8),
          todoEventBorder: const Color(0xFFE6E0FF),
          icsEventBg: const Color(0xFFF6F2FF),
          icsEventBorder: const Color(0xFFEDE6FF),
          priorityLow: const Color(0xFF8FA4FF),
          chipBg: const Color(0xFFFDFBFF),
          chipBorder: const Color(0xFFE8E2FF),
          iconButtonBg: const Color(0xFFF1ECFF),
          gridBorder: const Color(0xFFE8E2F8),
          pdfBadgeBg: const Color(0xFFEEEBFF),
          pdfBadgeText: const Color(0xFF7C8EF0),
          memoBadgeBg: const Color(0xFFF4F1FF),
          memoBadgeText: const Color(0xFF4A4371),
          tipBannerBg: const Color(0xFFF2EEFF),
          tipBannerBorder: const Color(0xFFE5DDFF),
          tipBannerTitle: const Color(0xFF7C8EF0),
          tipBannerBody: const Color(0xFF3E3667),
        );
      case 'slate_blue_gray':
        return base.copyWith(
          scaffoldBg: const Color(0xFFF3F6FB),
          cardBorder: const Color(0xFFDCE4F2),
          navBarBg: const Color(0xFFFCFDFF),
          navBarShadow: const Color(0x1410243A),
          navActive: const Color(0xFF7EAEF8),
          navInactive: const Color(0xFF66758F),
          textPrimary: const Color(0xFF0F172A),
          textSecondary: const Color(0xFF1A2438),
          textTertiary: const Color(0xFF3F4D66),
          textHint: const Color(0xFF66758F),
          inputBg: const Color(0xFFEEF3FA),
          sectionHeader: const Color(0xFF0F172A),
          tileCompletedBg: const Color(0xFFF6F8FC),
          tileBorder: const Color(0xFFDCE4F2),
          tileHighlightBorder: const Color(0xFFA2C5FB),
          checkActive: const Color(0xFF7EAEF8),
          checkInactive: const Color(0xFFA8B7CD),
          todoEventBorder: const Color(0xFFDCE4F2),
          icsEventBg: const Color(0xFFEEF3FA),
          icsEventBorder: const Color(0xFFD7E1F0),
          priorityLow: const Color(0xFF7EAEF8),
          chipBg: const Color(0xFFFCFDFF),
          chipBorder: const Color(0xFFD6E0F0),
          iconButtonBg: const Color(0xFFEAF0F9),
          gridBorder: const Color(0xFFD7E0EF),
          pdfBadgeBg: const Color(0xFFECF2FD),
          pdfBadgeText: const Color(0xFF7EAEF8),
          memoBadgeBg: const Color(0xFFF1F5FC),
          memoBadgeText: const Color(0xFF132033),
          tipBannerBg: const Color(0xFFEDF3FF),
          tipBannerBorder: const Color(0xFFD4E0F6),
          tipBannerTitle: const Color(0xFF4D84DA),
          tipBannerBody: const Color(0xFF132033),
        );
      case 'sky_peach':
      default:
        return base;
    }
  }

  static CampusMateColors _resolveDarkColors(
    String paletteKey,
    CampusMateCustomPalette customPalette,
  ) {
    final base = CampusMateColors.dark;
    if (paletteKey == customPaletteKey) {
      return _buildCustomDarkColors(base, customPalette);
    }
    switch (paletteKey) {
      case 'powder_mint':
        return base.copyWith(
          navActive: const Color(0xFF6FCAC0),
          tileHighlightBorder: const Color(0xFF6FCAC0),
          checkActive: const Color(0xFF6FCAC0),
          priorityLow: const Color(0xFF6FCAC0),
          pdfBadgeText: const Color(0xFF9CE4DB),
          tipBannerTitle: const Color(0xFF9CE4DB),
          inputBg: const Color(0xFF15211F),
          chipBg: const Color(0xFF1A2524),
          iconButtonBg: const Color(0xFF1A2524),
        );
      case 'periwinkle_lavender':
        return base.copyWith(
          navActive: const Color(0xFFA2AEFF),
          tileHighlightBorder: const Color(0xFFA2AEFF),
          checkActive: const Color(0xFFA2AEFF),
          priorityLow: const Color(0xFFA2AEFF),
          pdfBadgeText: const Color(0xFFC2CAFF),
          tipBannerTitle: const Color(0xFFC2CAFF),
          inputBg: const Color(0xFF181828),
          chipBg: const Color(0xFF1E1E2F),
          iconButtonBg: const Color(0xFF1E1E2F),
        );
      case 'slate_blue_gray':
        return base.copyWith(
          navActive: const Color(0xFF7EAEF8),
          tileHighlightBorder: const Color(0xFF7EAEF8),
          checkActive: const Color(0xFF7EAEF8),
          priorityLow: const Color(0xFF7EAEF8),
          pdfBadgeText: const Color(0xFFB5D0FC),
          tipBannerTitle: const Color(0xFFB5D0FC),
          inputBg: const Color(0xFF171B24),
          chipBg: const Color(0xFF1A2030),
          iconButtonBg: const Color(0xFF1A2030),
        );
      case 'sky_peach':
      default:
        return base;
    }
  }

  static CampusMateColors _buildCustomLightColors(
    CampusMateColors base,
    CampusMateCustomPalette customPalette,
  ) {
    final primary = customPalette.primary;
    final soft = customPalette.soft;
    final banner = customPalette.banner;
    final danger = customPalette.danger;

    return base.copyWith(
      navActive: primary,
      navInactive: _mix(base.navInactive, primary, 0.2),
      inputBg: soft,
      chipBg: _mix(soft, Colors.white, 0.4),
      chipBorder: _mix(soft, Colors.black, 0.08),
      iconButtonBg: _mix(soft, Colors.white, 0.3),
      tileHighlightBorder: _mix(primary, Colors.white, 0.45),
      checkActive: primary,
      priorityLow: primary,
      pdfBadgeText: _mix(primary, Colors.black, 0.12),
      memoBadgeBg: _mix(soft, Colors.white, 0.35),
      memoBadgeText: _mix(base.memoBadgeText, primary, 0.16),
      tipBannerBg: banner,
      tipBannerBorder: _mix(banner, Colors.black, 0.08),
      tipBannerTitle: _mix(primary, Colors.black, 0.12),
      tipBannerBody: _mix(base.tipBannerBody, primary, 0.2),
      deleteBg: danger,
      priorityHigh: danger,
    );
  }

  static CampusMateColors _buildCustomDarkColors(
    CampusMateColors base,
    CampusMateCustomPalette customPalette,
  ) {
    final primary = _mix(customPalette.primary, Colors.white, 0.2);
    final soft = _mix(customPalette.soft, Colors.black, 0.78);
    final banner = _mix(customPalette.banner, Colors.black, 0.72);
    final danger = _mix(customPalette.danger, Colors.white, 0.12);

    return base.copyWith(
      navActive: primary,
      navInactive: _mix(base.navInactive, primary, 0.22),
      inputBg: soft,
      chipBg: _mix(soft, Colors.black, 0.18),
      chipBorder: _mix(soft, Colors.white, 0.12),
      iconButtonBg: _mix(soft, Colors.black, 0.18),
      tileHighlightBorder: primary,
      checkActive: primary,
      priorityLow: primary,
      pdfBadgeText: _mix(primary, Colors.white, 0.3),
      tipBannerBg: banner,
      tipBannerBorder: _mix(banner, Colors.white, 0.16),
      tipBannerTitle: _mix(primary, Colors.white, 0.3),
      tipBannerBody: _mix(base.tipBannerBody, primary, 0.18),
      deleteBg: danger,
      priorityHigh: danger,
    );
  }

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
}
