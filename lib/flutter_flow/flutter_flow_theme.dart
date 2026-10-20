// ignore_for_file: overridden_fields, annotate_overrides

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '/user_design/user_design.dart';

const kThemeModeKey = '__theme_mode__';

SharedPreferences? _prefs;

abstract class FlutterFlowTheme {
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();

  static ThemeMode get themeMode {
    final darkMode = _prefs?.getBool(kThemeModeKey);
    return darkMode == null
        ? ThemeMode.system
        : darkMode
            ? ThemeMode.dark
            : ThemeMode.light;
  }

  static void saveThemeMode(ThemeMode mode) => mode == ThemeMode.system
      ? _prefs?.remove(kThemeModeKey)
      : _prefs?.setBool(kThemeModeKey, mode == ThemeMode.dark);

  static FlutterFlowTheme of(BuildContext context) {
    final design = UserDesignScope.maybeOf(context);
    if (design != null) {
      return design.isDarkTheme
          ? UserDarkModeTheme(design)
          : UserLightModeTheme(design);
    }
    return Theme.of(context).brightness == Brightness.dark
        ? DarkModeTheme()
        : LightModeTheme();
  }

  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  @Deprecated('Use displaySmallFamily instead')
  String get title1Family => displaySmallFamily;
  @Deprecated('Use displaySmall instead')
  TextStyle get title1 => typography.displaySmall;
  @Deprecated('Use headlineMediumFamily instead')
  String get title2Family => typography.headlineMediumFamily;
  @Deprecated('Use headlineMedium instead')
  TextStyle get title2 => typography.headlineMedium;
  @Deprecated('Use headlineSmallFamily instead')
  String get title3Family => typography.headlineSmallFamily;
  @Deprecated('Use headlineSmall instead')
  TextStyle get title3 => typography.headlineSmall;
  @Deprecated('Use titleMediumFamily instead')
  String get subtitle1Family => typography.titleMediumFamily;
  @Deprecated('Use titleMedium instead')
  TextStyle get subtitle1 => typography.titleMedium;
  @Deprecated('Use titleSmallFamily instead')
  String get subtitle2Family => typography.titleSmallFamily;
  @Deprecated('Use titleSmall instead')
  TextStyle get subtitle2 => typography.titleSmall;
  @Deprecated('Use bodyMediumFamily instead')
  String get bodyText1Family => typography.bodyMediumFamily;
  @Deprecated('Use bodyMedium instead')
  TextStyle get bodyText1 => typography.bodyMedium;
  @Deprecated('Use bodySmallFamily instead')
  String get bodyText2Family => typography.bodySmallFamily;
  @Deprecated('Use bodySmall instead')
  TextStyle get bodyText2 => typography.bodySmall;

  String get displayLargeFamily => typography.displayLargeFamily;
  bool get displayLargeIsCustom => typography.displayLargeIsCustom;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  bool get displayMediumIsCustom => typography.displayMediumIsCustom;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  bool get displaySmallIsCustom => typography.displaySmallIsCustom;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  bool get headlineLargeIsCustom => typography.headlineLargeIsCustom;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  bool get headlineMediumIsCustom => typography.headlineMediumIsCustom;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  bool get headlineSmallIsCustom => typography.headlineSmallIsCustom;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  bool get titleLargeIsCustom => typography.titleLargeIsCustom;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  bool get titleMediumIsCustom => typography.titleMediumIsCustom;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  bool get titleSmallIsCustom => typography.titleSmallIsCustom;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  bool get labelLargeIsCustom => typography.labelLargeIsCustom;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  bool get labelMediumIsCustom => typography.labelMediumIsCustom;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  bool get labelSmallIsCustom => typography.labelSmallIsCustom;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  bool get bodyLargeIsCustom => typography.bodyLargeIsCustom;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  bool get bodyMediumIsCustom => typography.bodyMediumIsCustom;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  bool get bodySmallIsCustom => typography.bodySmallIsCustom;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

class LightModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = const Color(0xFF114BC3);
  late Color secondary = const Color(0xFF39D2C0);
  late Color tertiary = const Color(0xFFEE8B60);
  late Color alternate = const Color(0xFFE0E3E7);
  late Color primaryText = const Color(0xFF14181B);
  late Color secondaryText = const Color(0xFF57636C);
  late Color primaryBackground = const Color(0xFFFFFFFF);
  late Color secondaryBackground = const Color(0xFFFFFFFF);
  late Color accent1 = const Color(0x4C4B39EF);
  late Color accent2 = const Color(0xFFA450FF);
  late Color accent3 = const Color(0x4DEE8B60);
  late Color accent4 = const Color(0xCCFFFFFF);
  late Color success = const Color(0xFF249689);
  late Color warning = const Color(0xFFF9CF58);
  late Color error = const Color(0xFFFF5963);
  late Color info = const Color(0xFFFFFFFF);
}

abstract class Typography {
  String get displayLargeFamily;
  bool get displayLargeIsCustom;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  bool get displayMediumIsCustom;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  bool get displaySmallIsCustom;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  bool get headlineLargeIsCustom;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  bool get headlineMediumIsCustom;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  bool get headlineSmallIsCustom;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  bool get titleLargeIsCustom;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  bool get titleMediumIsCustom;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  bool get titleSmallIsCustom;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  bool get labelLargeIsCustom;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  bool get labelMediumIsCustom;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  bool get labelSmallIsCustom;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  bool get bodyLargeIsCustom;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  bool get bodyMediumIsCustom;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  bool get bodySmallIsCustom;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  String get displayLargeFamily => 'Inter Tight';
  bool get displayLargeIsCustom => false;
  TextStyle get displayLarge => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 64.0,
      );
  String get displayMediumFamily => 'Inter Tight';
  bool get displayMediumIsCustom => false;
  TextStyle get displayMedium => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 44.0,
      );
  String get displaySmallFamily => 'Inter Tight';
  bool get displaySmallIsCustom => false;
  TextStyle get displaySmall => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 36.0,
      );
  String get headlineLargeFamily => 'Inter Tight';
  bool get headlineLargeIsCustom => false;
  TextStyle get headlineLarge => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 32.0,
      );
  String get headlineMediumFamily => 'Inter Tight';
  bool get headlineMediumIsCustom => false;
  TextStyle get headlineMedium => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 28.0,
      );
  String get headlineSmallFamily => 'Inter Tight';
  bool get headlineSmallIsCustom => false;
  TextStyle get headlineSmall => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 24.0,
      );
  String get titleLargeFamily => 'Inter Tight';
  bool get titleLargeIsCustom => false;
  TextStyle get titleLarge => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 20.0,
      );
  String get titleMediumFamily => 'Inter Tight';
  bool get titleMediumIsCustom => false;
  TextStyle get titleMedium => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 18.0,
      );
  String get titleSmallFamily => 'Inter Tight';
  bool get titleSmallIsCustom => false;
  TextStyle get titleSmall => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 16.0,
      );
  String get labelLargeFamily => 'Inter';
  bool get labelLargeIsCustom => false;
  TextStyle get labelLarge => GoogleFonts.inter(
        color: theme.secondaryText,
        fontWeight: FontWeight.normal,
        fontSize: 16.0,
      );
  String get labelMediumFamily => 'Inter';
  bool get labelMediumIsCustom => false;
  TextStyle get labelMedium => GoogleFonts.inter(
        color: theme.secondaryText,
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
      );
  String get labelSmallFamily => 'Inter';
  bool get labelSmallIsCustom => false;
  TextStyle get labelSmall => GoogleFonts.inter(
        color: theme.secondaryText,
        fontWeight: FontWeight.normal,
        fontSize: 12.0,
      );
  String get bodyLargeFamily => 'Inter';
  bool get bodyLargeIsCustom => false;
  TextStyle get bodyLarge => GoogleFonts.inter(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 16.0,
      );
  String get bodyMediumFamily => 'Inter';
  bool get bodyMediumIsCustom => false;
  TextStyle get bodyMedium => GoogleFonts.inter(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
      );
  String get bodySmallFamily => 'Inter';
  bool get bodySmallIsCustom => false;
  TextStyle get bodySmall => GoogleFonts.inter(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 12.0,
      );
}

class UserThemeTypography extends Typography {
  UserThemeTypography(this.theme, this.design);

  final FlutterFlowTheme theme;
  final UserDesignData design;

  @override
  String get displayLargeFamily => design.headingFontFamily;
  @override
  bool get displayLargeIsCustom => false;
  @override
  TextStyle get displayLarge => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w700,
        fontSize: 64.0,
      );
  @override
  String get displayMediumFamily => design.headingFontFamily;
  @override
  bool get displayMediumIsCustom => false;
  @override
  TextStyle get displayMedium => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w700,
        fontSize: 44.0,
      );
  @override
  String get displaySmallFamily => design.headingFontFamily;
  @override
  bool get displaySmallIsCustom => false;
  @override
  TextStyle get displaySmall => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w700,
        fontSize: 36.0,
      );
  @override
  String get headlineLargeFamily => design.headingFontFamily;
  @override
  bool get headlineLargeIsCustom => false;
  @override
  TextStyle get headlineLarge => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w700,
        fontSize: 32.0,
      );
  @override
  String get headlineMediumFamily => design.headingFontFamily;
  @override
  bool get headlineMediumIsCustom => false;
  @override
  TextStyle get headlineMedium => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w700,
        fontSize: 28.0,
      );
  @override
  String get headlineSmallFamily => design.headingFontFamily;
  @override
  bool get headlineSmallIsCustom => false;
  @override
  TextStyle get headlineSmall => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w700,
        fontSize: 24.0,
      );
  @override
  String get titleLargeFamily => design.headingFontFamily;
  @override
  bool get titleLargeIsCustom => false;
  @override
  TextStyle get titleLarge => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 20.0,
      );
  @override
  String get titleMediumFamily => design.headingFontFamily;
  @override
  bool get titleMediumIsCustom => false;
  @override
  TextStyle get titleMedium => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 18.0,
      );
  @override
  String get titleSmallFamily => design.headingFontFamily;
  @override
  bool get titleSmallIsCustom => false;
  @override
  TextStyle get titleSmall => userDesignFont(
        design.headingFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 16.0,
      );
  @override
  String get labelLargeFamily => design.bodyFontFamily;
  @override
  bool get labelLargeIsCustom => false;
  @override
  TextStyle get labelLarge => userDesignFont(
        design.bodyFontFamily,
        color: theme.secondaryText,
        fontWeight: FontWeight.w500,
        fontSize: 16.0,
      );
  @override
  String get labelMediumFamily => design.bodyFontFamily;
  @override
  bool get labelMediumIsCustom => false;
  @override
  TextStyle get labelMedium => userDesignFont(
        design.bodyFontFamily,
        color: theme.secondaryText,
        fontWeight: FontWeight.w500,
        fontSize: 14.0,
      );
  @override
  String get labelSmallFamily => design.bodyFontFamily;
  @override
  bool get labelSmallIsCustom => false;
  @override
  TextStyle get labelSmall => userDesignFont(
        design.bodyFontFamily,
        color: theme.secondaryText,
        fontWeight: FontWeight.w500,
        fontSize: 12.0,
      );
  @override
  String get bodyLargeFamily => design.bodyFontFamily;
  @override
  bool get bodyLargeIsCustom => false;
  @override
  TextStyle get bodyLarge => userDesignFont(
        design.bodyFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 16.0,
      );
  @override
  String get bodyMediumFamily => design.bodyFontFamily;
  @override
  bool get bodyMediumIsCustom => false;
  @override
  TextStyle get bodyMedium => userDesignFont(
        design.bodyFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
      );
  @override
  String get bodySmallFamily => design.bodyFontFamily;
  @override
  bool get bodySmallIsCustom => false;
  @override
  TextStyle get bodySmall => userDesignFont(
        design.bodyFontFamily,
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 12.0,
      );
}

class DarkModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = const Color(0xFF114BC3);
  late Color secondary = const Color(0xFF39D2C0);
  late Color tertiary = const Color(0xFFEE8B60);
  late Color alternate = const Color(0xFF1F2937);
  late Color primaryText = const Color(0xFFF9FAFB);
  late Color secondaryText = const Color(0xFF9CA3AF);
  late Color primaryBackground = const Color(0xFF0B0F17);
  late Color secondaryBackground = const Color(0xFF111827);
  late Color accent1 = const Color(0x3D4F46E5);
  late Color accent2 = const Color(0xFF8B5CF6);
  late Color accent3 = const Color(0x3D22C55E);
  late Color accent4 = const Color(0xFF0F172A);
  late Color success = const Color(0xFF22C55E);
  late Color warning = const Color(0xFFF59E0B);
  late Color error = const Color(0xFFEF4444);
  late Color info = const Color(0xFFE5E7EB);
}

class UserLightModeTheme extends LightModeTheme {
  UserLightModeTheme(this.design) {
    primary = design.buttonColor;
    secondary = design.accentColor;
    tertiary = design.accentColor.withValues(alpha: 0.82);
    alternate = design.softSurfaceBorder;
    primaryText = design.textColor;
    secondaryText = design.mutedTextColor;
    primaryBackground = design.softSurfaceColor;
    secondaryBackground = design.surfaceColor;
    accent1 = design.activeSurfaceColor;
    accent2 = design.accentColor.withValues(alpha: 0.35);
    accent3 = design.accentColor.withValues(alpha: 0.12);
    accent4 = design.softSurfaceColor;
    success = design.successColor;
    warning = design.warningColor;
    error = design.dangerColor;
    info = design.buttonTextColor;
  }

  final UserDesignData design;

  @override
  Typography get typography => UserThemeTypography(this, design);
}

class UserDarkModeTheme extends DarkModeTheme {
  UserDarkModeTheme(this.design) {
    primary = design.buttonColor;
    secondary = design.accentColor;
    tertiary = design.accentColor.withValues(alpha: 0.82);
    alternate = design.softSurfaceBorder;
    primaryText = design.textColor;
    secondaryText = design.mutedTextColor;
    primaryBackground = design.softSurfaceColor;
    secondaryBackground = design.surfaceColor;
    accent1 = design.activeSurfaceColor;
    accent2 = design.accentColor.withValues(alpha: 0.35);
    accent3 = design.accentColor.withValues(alpha: 0.12);
    accent4 = design.softSurfaceColor;
    success = design.successColor;
    warning = design.warningColor;
    error = design.dangerColor;
    info = design.buttonTextColor;
  }

  final UserDesignData design;

  @override
  Typography get typography => UserThemeTypography(this, design);
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    if (useGoogleFonts && fontFamily != null) {
      font = GoogleFonts.getFont(fontFamily,
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle);
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily,
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}
