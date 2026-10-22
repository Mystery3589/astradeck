import 'package:flutter/material.dart';

enum AstraThemePreset {
  midnight,
  amoled,
  dracula,
  nord,
  solarized,
  catppuccin,
  cleanLight,
  cyberpunk,
}

extension AstraThemePresetExtension on AstraThemePreset {
  String get displayName {
    switch (this) {
      case AstraThemePreset.midnight:
        return 'Midnight Slate';
      case AstraThemePreset.amoled:
        return 'AMOLED Black';
      case AstraThemePreset.dracula:
        return 'Dracula Noir';
      case AstraThemePreset.nord:
        return 'Nordic Frost';
      case AstraThemePreset.solarized:
        return 'Solarized Dark';
      case AstraThemePreset.catppuccin:
        return 'Catppuccin Mocha';
      case AstraThemePreset.cleanLight:
        return 'Clean Studio Light';
      case AstraThemePreset.cyberpunk:
        return 'Cyberpunk Neon';
    }
  }

  String get description {
    switch (this) {
      case AstraThemePreset.midnight:
        return 'Deep slate & indigo contrast for night sessions';
      case AstraThemePreset.amoled:
        return 'Pure black OLED power saver with vibrant cyan';
      case AstraThemePreset.dracula:
        return 'Beloved developer dark theme with vivid pinks';
      case AstraThemePreset.nord:
        return 'Arctic, icy calmness for clean workspaces';
      case AstraThemePreset.solarized:
        return 'Gentle low-contrast warm palette with amber';
      case AstraThemePreset.catppuccin:
        return 'Soothing pastel mocha tones with mauve';
      case AstraThemePreset.cleanLight:
        return 'Crisp daylight mode with high clarity';
      case AstraThemePreset.cyberpunk:
        return 'High-voltage electric magenta & cyan';
    }
  }

  AstraThemeBundle get bundle {
    switch (this) {
      case AstraThemePreset.midnight:
        return const AstraThemeBundle(
          preset: AstraThemePreset.midnight,
          isDark: true,
          scaffoldBg: Color(0xFF0F172A),
          cardBg: Color(0xFF1E293B),
          surfaceElevated: Color(0xFF334155),
          navBarBg: Color(0xFF090D16),
          borderColor: Color(0xFF334155),
          defaultAccent: Color(0xFF6366F1),
          textPrimary: Colors.white,
          textSecondary: Color(0xFF94A3B8),
        );
      case AstraThemePreset.amoled:
        return const AstraThemeBundle(
          preset: AstraThemePreset.amoled,
          isDark: true,
          scaffoldBg: Color(0xFF000000),
          cardBg: Color(0xFF111111),
          surfaceElevated: Color(0xFF1E1E1E),
          navBarBg: Color(0xFF000000),
          borderColor: Color(0xFF27272A),
          defaultAccent: Color(0xFF00E5FF),
          textPrimary: Colors.white,
          textSecondary: Color(0xFFA1A1AA),
        );
      case AstraThemePreset.dracula:
        return const AstraThemeBundle(
          preset: AstraThemePreset.dracula,
          isDark: true,
          scaffoldBg: Color(0xFF282A36),
          cardBg: Color(0xFF343746),
          surfaceElevated: Color(0xFF44475A),
          navBarBg: Color(0xFF1E1F29),
          borderColor: Color(0xFF6272A4),
          defaultAccent: Color(0xFFFF79C6),
          textPrimary: Color(0xFFF8F8F2),
          textSecondary: Color(0xFFBD93F9),
        );
      case AstraThemePreset.nord:
        return const AstraThemeBundle(
          preset: AstraThemePreset.nord,
          isDark: true,
          scaffoldBg: Color(0xFF2E3440),
          cardBg: Color(0xFF3B4252),
          surfaceElevated: Color(0xFF434C5E),
          navBarBg: Color(0xFF242933),
          borderColor: Color(0xFF4C566A),
          defaultAccent: Color(0xFF88C0D0),
          textPrimary: Color(0xFFECEFF4),
          textSecondary: Color(0xFFD8DEE9),
        );
      case AstraThemePreset.solarized:
        return const AstraThemeBundle(
          preset: AstraThemePreset.solarized,
          isDark: true,
          scaffoldBg: Color(0xFF002B36),
          cardBg: Color(0xFF073642),
          surfaceElevated: Color(0xFF0A4756),
          navBarBg: Color(0xFF00212B),
          borderColor: Color(0xFF586E75),
          defaultAccent: Color(0xFFB58900),
          textPrimary: Color(0xFFFDF6E3),
          textSecondary: Color(0xFF93A1A1),
        );
      case AstraThemePreset.catppuccin:
        return const AstraThemeBundle(
          preset: AstraThemePreset.catppuccin,
          isDark: true,
          scaffoldBg: Color(0xFF1E1E2E),
          cardBg: Color(0xFF252538),
          surfaceElevated: Color(0xFF313244),
          navBarBg: Color(0xFF181825),
          borderColor: Color(0xFF45475A),
          defaultAccent: Color(0xFFCBA6F7),
          textPrimary: Color(0xFFCDD6F4),
          textSecondary: Color(0xFFA6ADC8),
        );
      case AstraThemePreset.cleanLight:
        return const AstraThemeBundle(
          preset: AstraThemePreset.cleanLight,
          isDark: false,
          scaffoldBg: Color(0xFFF8FAFC),
          cardBg: Color(0xFFFFFFFF),
          surfaceElevated: Color(0xFFF1F5F9),
          navBarBg: Color(0xFFFFFFFF),
          borderColor: Color(0xFFE2E8F0),
          defaultAccent: Color(0xFF2563EB),
          textPrimary: Color(0xFF0F172A),
          textSecondary: Color(0xFF64748B),
        );
      case AstraThemePreset.cyberpunk:
        return const AstraThemeBundle(
          preset: AstraThemePreset.cyberpunk,
          isDark: true,
          scaffoldBg: Color(0xFF0D0221),
          cardBg: Color(0xFF190933),
          surfaceElevated: Color(0xFF260F4C),
          navBarBg: Color(0xFF080114),
          borderColor: Color(0xFF541388),
          defaultAccent: Color(0xFFFF007F),
          textPrimary: Colors.white,
          textSecondary: Color(0xFF00F0FF),
        );
    }
  }

  static AstraThemePreset fromString(String? val) {
    if (val == null) return AstraThemePreset.midnight;
    return AstraThemePreset.values.firstWhere(
      (e) => e.name == val,
      orElse: () => AstraThemePreset.midnight,
    );
  }
}

class AstraThemeBundle extends ThemeExtension<AstraThemeBundle> {
  final AstraThemePreset preset;
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color surfaceElevated;
  final Color navBarBg;
  final Color borderColor;
  final Color defaultAccent;
  final Color textPrimary;
  final Color textSecondary;

  const AstraThemeBundle({
    required this.preset,
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.surfaceElevated,
    required this.navBarBg,
    required this.borderColor,
    required this.defaultAccent,
    required this.textPrimary,
    required this.textSecondary,
  });

  static AstraThemeBundle of(BuildContext context) {
    return Theme.of(context).extension<AstraThemeBundle>() ??
        AstraThemePreset.midnight.bundle;
  }

  @override
  AstraThemeBundle copyWith({
    AstraThemePreset? preset,
    bool? isDark,
    Color? scaffoldBg,
    Color? cardBg,
    Color? surfaceElevated,
    Color? navBarBg,
    Color? borderColor,
    Color? defaultAccent,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AstraThemeBundle(
      preset: preset ?? this.preset,
      isDark: isDark ?? this.isDark,
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      cardBg: cardBg ?? this.cardBg,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      navBarBg: navBarBg ?? this.navBarBg,
      borderColor: borderColor ?? this.borderColor,
      defaultAccent: defaultAccent ?? this.defaultAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AstraThemeBundle lerp(ThemeExtension<AstraThemeBundle>? other, double t) {
    if (other is! AstraThemeBundle) return this;
    return AstraThemeBundle(
      preset: t < 0.5 ? preset : other.preset,
      isDark: t < 0.5 ? isDark : other.isDark,
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t) ?? scaffoldBg,
      cardBg: Color.lerp(cardBg, other.cardBg, t) ?? cardBg,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      navBarBg: Color.lerp(navBarBg, other.navBarBg, t) ?? navBarBg,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
      defaultAccent: Color.lerp(defaultAccent, other.defaultAccent, t) ?? defaultAccent,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
    );
  }
}

class AstraDeckTheme {
  static ThemeData getTheme({
    AstraThemePreset preset = AstraThemePreset.midnight,
    Color? accentOverride,
    ThemeMode mode = ThemeMode.dark,
  }) {
    AstraThemeBundle bundle = preset.bundle;
    // If user explicitly forced light mode while on a dark preset or vice versa
    if (mode == ThemeMode.light && bundle.isDark) {
      bundle = AstraThemePreset.cleanLight.bundle;
    }

    final accent = accentOverride ?? bundle.defaultAccent;

    return ThemeData(
      useMaterial3: true,
      brightness: bundle.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bundle.scaffoldBg,
      colorScheme: bundle.isDark
          ? ColorScheme.dark(
              primary: accent,
              secondary: accent.withValues(alpha: 0.8),
              surface: bundle.cardBg,
              onSurface: bundle.textPrimary,
              outline: bundle.borderColor,
            )
          : ColorScheme.light(
              primary: accent,
              secondary: accent.withValues(alpha: 0.8),
              surface: bundle.cardBg,
              onSurface: bundle.textPrimary,
              outline: bundle.borderColor,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: bundle.scaffoldBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: bundle.textPrimary),
        titleTextStyle: TextStyle(
          color: bundle.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bundle.navBarBg,
        indicatorColor: accent.withValues(alpha: bundle.isDark ? 0.25 : 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return TextStyle(color: bundle.textSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent);
          }
          return IconThemeData(color: bundle.textSecondary);
        }),
      ),
      cardTheme: CardThemeData(
        color: bundle.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: bundle.borderColor, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bundle.surfaceElevated,
        labelStyle: TextStyle(color: bundle.textPrimary, fontSize: 13),
        side: BorderSide(color: bundle.borderColor, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bundle.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: bundle.borderColor, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bundle.cardBg,
        modalBackgroundColor: bundle.cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      extensions: [bundle],
    );
  }

  // Backward compatibility
  static ThemeData getDarkTheme(Color accentColor) =>
      getTheme(preset: AstraThemePreset.midnight, accentOverride: accentColor, mode: ThemeMode.dark);

  static ThemeData getLightTheme(Color accentColor) =>
      getTheme(preset: AstraThemePreset.cleanLight, accentOverride: accentColor, mode: ThemeMode.light);
}
