import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';

const String kUserDesignTemplateField = 'userDesignTemplate';
const String kUserDesignConfigField = 'userDesignConfig';
const String kUserDesignCustom = 'custom';
const String kUserDesignReference = 'reference';
const String kUserDesignTemplatesField = 'templates';
const String kUserDesignLightMode = 'light';
const String kUserDesignDarkMode = 'dark';

const List<String> kUserDesignFontFamilies = <String>[
  'Inter',
  'Inter Tight',
  'Manrope',
  'Plus Jakarta Sans',
  'Nunito Sans',
  'Rubik',
  'Montserrat',
  'Poppins',
  'Lora',
  'Playfair Display',
];

String resolveCurrentCompanyId() {
  final active = (currentUserDocument?.activeCompanyId ?? '').trim();
  if (active.isNotEmpty) return active;

  final direct = (currentUserDocument?.idCompany ?? '').trim();
  if (direct.isNotEmpty) return direct;

  final ids = currentUserDocument?.companyIds ?? const <String>[];
  if (ids.isNotEmpty) return ids.first.toString().trim();

  return '';
}

String normalizeUserDesignTemplate(dynamic raw) {
  final value = (raw ?? '').toString().trim().toLowerCase();
  return value == kUserDesignCustom ? kUserDesignCustom : kUserDesignReference;
}

String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

Color colorFromHex(dynamic raw, Color fallback) {
  final value = (raw ?? '').toString().trim().replaceFirst('#', '');
  if (value.length != 6 && value.length != 8) return fallback;
  final normalized = value.length == 6 ? 'FF$value' : value;
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

Map<String, String> _defaultVariantConfig({
  required String templateId,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;
  if (templateId == kUserDesignReference) {
    if (isDark) {
      return {
        'pageStart': colorToHex(const Color(0xFF080B11)),
        'pageEnd': colorToHex(const Color(0xFF101721)),
        'surface': colorToHex(const Color(0xFF121821)),
        'surfaceBorder': colorToHex(const Color(0xFF273242)),
        'softSurface': colorToHex(const Color(0xFF171F2B)),
        'softSurfaceBorder': colorToHex(const Color(0xFF324053)),
        'activeSurface': colorToHex(const Color(0xFF1E2A3B)),
        'activeSurfaceBorder': colorToHex(const Color(0xFFC8A06A)),
        'button': colorToHex(const Color(0xFFC8A06A)),
        'buttonText': colorToHex(const Color(0xFF0D121A)),
        'text': colorToHex(const Color(0xFFFFFFFF)),
        'mutedText': colorToHex(const Color(0xFFB7C0CC)),
        'accent': colorToHex(const Color(0xFFC8A06A)),
        'success': colorToHex(const Color(0xFF4FD1A1)),
        'warning': colorToHex(const Color(0xFFE7B35A)),
        'danger': colorToHex(const Color(0xFFF08A9F)),
        'drawerStart': colorToHex(const Color(0xFF090D13)),
        'drawerEnd': colorToHex(const Color(0xFF121A25)),
        'drawerText': colorToHex(const Color(0xFFFFFFFF)),
        'drawerMutedText': colorToHex(const Color(0xFFB7C0CC)),
        'drawerSectionText': colorToHex(const Color(0xFFD9C3A1)),
        'drawerSectionActiveText': colorToHex(const Color(0xFFF0C78A)),
        'drawerSectionIcon': colorToHex(const Color(0xFFD9C3A1)),
        'drawerSectionActiveIcon': colorToHex(const Color(0xFFF0C78A)),
        'drawerSectionArrowBg': colorToHex(const Color(0xFF413A33)),
        'drawerSectionArrowIcon': colorToHex(const Color(0xFFE4BC80)),
        'headingFontFamily': 'Playfair Display',
        'bodyFontFamily': 'Manrope',
      };
    }
    return {
      'pageStart': colorToHex(const Color(0xFFFFFCF7)),
      'pageEnd': colorToHex(const Color(0xFFF6EFE4)),
      'surface': colorToHex(const Color(0xFFFFFFFF)),
      'surfaceBorder': colorToHex(const Color(0xFFE7D8C4)),
      'softSurface': colorToHex(const Color(0xFFFFFBF5)),
      'softSurfaceBorder': colorToHex(const Color(0xFFDCCCB7)),
      'activeSurface': colorToHex(const Color(0xFFF6E7D0)),
      'activeSurfaceBorder': colorToHex(const Color(0xFFC8A06A)),
      'button': colorToHex(const Color(0xFFC8A06A)),
      'buttonText': colorToHex(const Color(0xFFFFFFFF)),
      'text': colorToHex(const Color(0xFF1F1A16)),
      'mutedText': colorToHex(const Color(0xFF74685C)),
      'accent': colorToHex(const Color(0xFFE0B763)),
      'success': colorToHex(const Color(0xFF15803D)),
      'warning': colorToHex(const Color(0xFFD97706)),
      'danger': colorToHex(const Color(0xFFBE123C)),
      'drawerStart': colorToHex(const Color(0xFFFFFCF7)),
      'drawerEnd': colorToHex(const Color(0xFFF6ECDD)),
      'drawerText': colorToHex(const Color(0xFF2A211A)),
      'drawerMutedText': colorToHex(const Color(0xFF8A7562)),
      'drawerSectionText': colorToHex(const Color(0xFF6E5535)),
      'drawerSectionActiveText': colorToHex(const Color(0xFFA0702E)),
      'drawerSectionIcon': colorToHex(const Color(0xFF7C6445)),
      'drawerSectionActiveIcon': colorToHex(const Color(0xFFA0702E)),
      'drawerSectionArrowBg': colorToHex(const Color(0xFFF0E0C8)),
      'drawerSectionArrowIcon': colorToHex(const Color(0xFF9A712F)),
      'headingFontFamily': 'Playfair Display',
      'bodyFontFamily': 'Manrope',
    };
  }

  if (isDark) {
    return {
      'pageStart': colorToHex(const Color(0xFF101826)),
      'pageEnd': colorToHex(const Color(0xFF182235)),
      'surface': colorToHex(const Color(0xFF1B2638)),
      'surfaceBorder': colorToHex(const Color(0xFF30435E)),
      'softSurface': colorToHex(const Color(0xFF223149)),
      'softSurfaceBorder': colorToHex(const Color(0xFF39516F)),
      'activeSurface': colorToHex(const Color(0xFF233A67)),
      'activeSurfaceBorder': colorToHex(const Color(0xFF5E8DE0)),
      'button': colorToHex(const Color(0xFF3B82F6)),
      'buttonText': colorToHex(const Color(0xFFF8FAFC)),
      'text': colorToHex(const Color(0xFFF8FAFC)),
      'mutedText': colorToHex(const Color(0xFFB7C3D4)),
      'accent': colorToHex(const Color(0xFF38BDF8)),
      'success': colorToHex(const Color(0xFF22C55E)),
      'warning': colorToHex(const Color(0xFFF59E0B)),
      'danger': colorToHex(const Color(0xFFEF4444)),
      'drawerStart': colorToHex(const Color(0xFF101826)),
      'drawerEnd': colorToHex(const Color(0xFF162132)),
      'drawerText': colorToHex(const Color(0xFFF8FAFC)),
      'drawerMutedText': colorToHex(const Color(0xFFA7B7CC)),
      'drawerSectionText': colorToHex(const Color(0xFFD5E3FF)),
      'drawerSectionActiveText': colorToHex(const Color(0xFF8AB4FF)),
      'drawerSectionIcon': colorToHex(const Color(0xFFC7D8FB)),
      'drawerSectionActiveIcon': colorToHex(const Color(0xFF8AB4FF)),
      'drawerSectionArrowBg': colorToHex(const Color(0xFF24344B)),
      'drawerSectionArrowIcon': colorToHex(const Color(0xFF8AB4FF)),
      'headingFontFamily': 'Inter Tight',
      'bodyFontFamily': 'Inter',
    };
  }

  return {
    'pageStart': colorToHex(const Color(0xFFF6F8FC)),
    'pageEnd': colorToHex(const Color(0xFFE7EEF8)),
    'surface': colorToHex(const Color(0xFFFFFFFF)),
    'surfaceBorder': colorToHex(const Color(0xFFD5E0EE)),
    'softSurface': colorToHex(const Color(0xFFF8FAFD)),
    'softSurfaceBorder': colorToHex(const Color(0xFFE2E8F0)),
    'activeSurface': colorToHex(const Color(0xFFEAF2FF)),
    'activeSurfaceBorder': colorToHex(const Color(0xFF8AB4FF)),
    'button': colorToHex(const Color(0xFF1F4ED8)),
    'buttonText': colorToHex(const Color(0xFFFFFFFF)),
    'text': colorToHex(const Color(0xFF0E1726)),
    'mutedText': colorToHex(const Color(0xFF526277)),
    'accent': colorToHex(const Color(0xFF0F9BD7)),
    'success': colorToHex(const Color(0xFF16A34A)),
    'warning': colorToHex(const Color(0xFFD97706)),
    'danger': colorToHex(const Color(0xFFDC2626)),
    'drawerStart': colorToHex(const Color(0xFFFFFFFF)),
    'drawerEnd': colorToHex(const Color(0xFFF0F5FB)),
    'drawerText': colorToHex(const Color(0xFF102033)),
    'drawerMutedText': colorToHex(const Color(0xFF5B6B80)),
    'drawerSectionText': colorToHex(const Color(0xFF315D9F)),
    'drawerSectionActiveText': colorToHex(const Color(0xFF1F4ED8)),
    'drawerSectionIcon': colorToHex(const Color(0xFF315D9F)),
    'drawerSectionActiveIcon': colorToHex(const Color(0xFF1F4ED8)),
    'drawerSectionArrowBg': colorToHex(const Color(0xFFE8F0FF)),
    'drawerSectionArrowIcon': colorToHex(const Color(0xFF1F4ED8)),
    'headingFontFamily': 'Inter Tight',
    'bodyFontFamily': 'Inter',
  };
}

Map<String, dynamic> defaultCustomUserDesignConfig() => {
      kUserDesignTemplatesField: {
        kUserDesignCustom: {
          kUserDesignLightMode: _defaultVariantConfig(
            templateId: kUserDesignCustom,
            brightness: Brightness.light,
          ),
          kUserDesignDarkMode: _defaultVariantConfig(
            templateId: kUserDesignCustom,
            brightness: Brightness.dark,
          ),
        },
        kUserDesignReference: {
          kUserDesignLightMode: _defaultVariantConfig(
            templateId: kUserDesignReference,
            brightness: Brightness.light,
          ),
          kUserDesignDarkMode: _defaultVariantConfig(
            templateId: kUserDesignReference,
            brightness: Brightness.dark,
          ),
        },
      },
    };

Map<String, dynamic> normalizeUserDesignConfig(dynamic raw) {
  final defaults = defaultCustomUserDesignConfig();
  final normalized = <String, dynamic>{
    ...defaults,
  };
  final templates = <String, dynamic>{
    ...Map<String, dynamic>.from(defaults[kUserDesignTemplatesField] as Map),
  };

  if (raw is Map && raw[kUserDesignTemplatesField] is Map) {
    final incomingTemplates =
        Map<String, dynamic>.from(raw[kUserDesignTemplatesField] as Map);
    for (final templateId in [kUserDesignCustom, kUserDesignReference]) {
      final templateDefaults =
          Map<String, dynamic>.from(templates[templateId] as Map);
      final incomingTemplate = incomingTemplates[templateId];
      if (incomingTemplate is Map) {
        for (final modeKey in [kUserDesignLightMode, kUserDesignDarkMode]) {
          final variantDefaults =
              Map<String, dynamic>.from(templateDefaults[modeKey] as Map);
          final incomingVariant = incomingTemplate[modeKey];
          if (incomingVariant is Map) {
            templateDefaults[modeKey] = {
              ...variantDefaults,
              ...Map<String, dynamic>.from(incomingVariant),
            };
          }
        }
      }
      templates[templateId] = templateDefaults;
    }
  } else if (raw is Map) {
    // Backward compatibility for the old flat config.
    templates[kUserDesignCustom] = {
      ...Map<String, dynamic>.from(templates[kUserDesignCustom] as Map),
      kUserDesignLightMode: {
        ...Map<String, dynamic>.from(
          (templates[kUserDesignCustom] as Map)[kUserDesignLightMode] as Map,
        ),
        ...Map<String, dynamic>.from(raw),
      },
    };
  }

  normalized[kUserDesignTemplatesField] = templates;
  return normalized;
}

Map<String, dynamic> userDesignVariantConfig(
  dynamic rawConfig, {
  required String templateId,
  required Brightness brightness,
}) {
  final normalized = normalizeUserDesignConfig(rawConfig);
  final modeKey = brightness == Brightness.dark
      ? kUserDesignDarkMode
      : kUserDesignLightMode;
  final templates =
      Map<String, dynamic>.from(normalized[kUserDesignTemplatesField] as Map);
  final template =
      Map<String, dynamic>.from(templates[templateId] as Map? ?? const {});
  final variant =
      Map<String, dynamic>.from(template[modeKey] as Map? ?? const {});
  return {
    ..._defaultVariantConfig(templateId: templateId, brightness: brightness),
    ...variant,
  };
}

String normalizeUserDesignFontFamily(dynamic raw, String fallback) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty) return fallback;
  return kUserDesignFontFamilies.contains(value) ? value : fallback;
}

TextStyle userDesignFont(
  String family, {
  Color? color,
  FontWeight? fontWeight,
  double? fontSize,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.getFont(
    family,
    color: color,
    fontWeight: fontWeight,
    fontSize: fontSize,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    height: height,
  );
}

class UserDesignData {
  const UserDesignData({
    required this.companyId,
    required this.templateId,
    required this.brightness,
    required this.pageBackground,
    required this.sidebarBackground,
    required this.surfaceColor,
    required this.surfaceBorder,
    required this.softSurfaceColor,
    required this.softSurfaceBorder,
    required this.activeSurfaceColor,
    required this.activeSurfaceBorder,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.accentColor,
    required this.successColor,
    required this.warningColor,
    required this.dangerColor,
    required this.drawerTextColor,
    required this.drawerMutedTextColor,
    required this.drawerSectionTextColor,
    required this.drawerSectionActiveTextColor,
    required this.drawerSectionIconColor,
    required this.drawerSectionActiveIconColor,
    required this.drawerSectionArrowBackgroundColor,
    required this.drawerSectionArrowIconColor,
    required this.headingFontFamily,
    required this.bodyFontFamily,
    required this.isConfigurable,
  });

  final String companyId;
  final String templateId;
  final Brightness brightness;
  final Gradient pageBackground;
  final Gradient sidebarBackground;
  final Color surfaceColor;
  final Color surfaceBorder;
  final Color softSurfaceColor;
  final Color softSurfaceBorder;
  final Color activeSurfaceColor;
  final Color activeSurfaceBorder;
  final Color buttonColor;
  final Color buttonTextColor;
  final Color textColor;
  final Color mutedTextColor;
  final Color accentColor;
  final Color successColor;
  final Color warningColor;
  final Color dangerColor;
  final Color drawerTextColor;
  final Color drawerMutedTextColor;
  final Color drawerSectionTextColor;
  final Color drawerSectionActiveTextColor;
  final Color drawerSectionIconColor;
  final Color drawerSectionActiveIconColor;
  final Color drawerSectionArrowBackgroundColor;
  final Color drawerSectionArrowIconColor;
  final String headingFontFamily;
  final String bodyFontFamily;
  final bool isConfigurable;

  bool get isDarkTheme => brightness == Brightness.dark;

  bool get isReference => templateId == kUserDesignReference;

  static UserDesignData fallback() => fromCompanyData(
        companyId: '',
        templateId: kUserDesignReference,
        config: defaultCustomUserDesignConfig(),
        brightness: Brightness.light,
      );

  static UserDesignData fromCompanyData({
    required String companyId,
    required dynamic templateId,
    required dynamic config,
    required Brightness brightness,
  }) {
    final template = normalizeUserDesignTemplate(templateId);
    final configMap = userDesignVariantConfig(
      config,
      templateId: template,
      brightness: brightness,
    );

    final pageStart = colorFromHex(
      configMap['pageStart'],
      const Color(0xFFF8FBFF),
    );
    final pageEnd = colorFromHex(
      configMap['pageEnd'],
      const Color(0xFFE9F0FA),
    );
    final drawerStart = colorFromHex(
      configMap['drawerStart'],
      const Color(0xFFFFFFFF),
    );
    final drawerEnd = colorFromHex(
      configMap['drawerEnd'],
      const Color(0xFFF3F7FC),
    );
    final surface = colorFromHex(
      configMap['surface'],
      const Color(0xFFFFFFFF),
    );
    final surfaceBorder = colorFromHex(
      configMap['surfaceBorder'],
      const Color(0xFFD6E2F0),
    );
    final button = colorFromHex(
      configMap['button'],
      const Color(0xFF1D4ED8),
    );
    final softSurface = colorFromHex(
      configMap['softSurface'],
      surface.withValues(alpha: 0.96),
    );
    final softSurfaceBorder = colorFromHex(
      configMap['softSurfaceBorder'],
      surfaceBorder.withValues(alpha: 0.92),
    );
    final activeSurface = colorFromHex(
      configMap['activeSurface'],
      button.withValues(alpha: 0.12),
    );
    final activeSurfaceBorder = colorFromHex(
      configMap['activeSurfaceBorder'],
      button.withValues(alpha: 0.42),
    );
    final buttonText = colorFromHex(
      configMap['buttonText'],
      const Color(0xFFFFFFFF),
    );
    final text = colorFromHex(
      configMap['text'],
      const Color(0xFF0F172A),
    );
    final mutedText = colorFromHex(
      configMap['mutedText'],
      const Color(0xFF475569),
    );
    final accent = colorFromHex(
      configMap['accent'],
      const Color(0xFF0EA5E9),
    );
    final success = colorFromHex(
      configMap['success'],
      const Color(0xFF16A34A),
    );
    final warning = colorFromHex(
      configMap['warning'],
      const Color(0xFFD97706),
    );
    final danger = colorFromHex(
      configMap['danger'],
      const Color(0xFFDC2626),
    );
    final drawerText = colorFromHex(
      configMap['drawerText'],
      text,
    );
    final drawerMutedText = colorFromHex(
      configMap['drawerMutedText'],
      mutedText,
    );
    final drawerSectionText = colorFromHex(
      configMap['drawerSectionText'],
      drawerText,
    );
    final drawerSectionActiveText = colorFromHex(
      configMap['drawerSectionActiveText'],
      button,
    );
    final drawerSectionIcon = colorFromHex(
      configMap['drawerSectionIcon'],
      drawerSectionText,
    );
    final drawerSectionActiveIcon = colorFromHex(
      configMap['drawerSectionActiveIcon'],
      drawerSectionActiveText,
    );
    final drawerSectionArrowBg = colorFromHex(
      configMap['drawerSectionArrowBg'],
      activeSurface,
    );
    final drawerSectionArrowIcon = colorFromHex(
      configMap['drawerSectionArrowIcon'],
      button,
    );
    final headingFontFamily = normalizeUserDesignFontFamily(
      configMap['headingFontFamily'],
      'Inter Tight',
    );
    final bodyFontFamily = normalizeUserDesignFontFamily(
      configMap['bodyFontFamily'],
      'Inter',
    );

    return UserDesignData(
      companyId: companyId,
      templateId: template,
      brightness: brightness,
      pageBackground: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [pageStart, pageEnd],
      ),
      sidebarBackground: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [drawerStart, drawerEnd],
      ),
      surfaceColor: surface,
      surfaceBorder: surfaceBorder,
      softSurfaceColor: softSurface,
      softSurfaceBorder: softSurfaceBorder,
      activeSurfaceColor: activeSurface,
      activeSurfaceBorder: activeSurfaceBorder,
      buttonColor: button,
      buttonTextColor: buttonText,
      textColor: text,
      mutedTextColor: mutedText,
      accentColor: accent,
      successColor: success,
      warningColor: warning,
      dangerColor: danger,
      drawerTextColor: drawerText,
      drawerMutedTextColor: drawerMutedText,
      drawerSectionTextColor: drawerSectionText,
      drawerSectionActiveTextColor: drawerSectionActiveText,
      drawerSectionIconColor: drawerSectionIcon,
      drawerSectionActiveIconColor: drawerSectionActiveIcon,
      drawerSectionArrowBackgroundColor: drawerSectionArrowBg,
      drawerSectionArrowIconColor: drawerSectionArrowIcon,
      headingFontFamily: headingFontFamily,
      bodyFontFamily: bodyFontFamily,
      isConfigurable: true,
    );
  }

  UserDesignData copyWith({
    String? companyId,
    Brightness? brightness,
  }) {
    return UserDesignData(
      companyId: companyId ?? this.companyId,
      templateId: templateId,
      brightness: brightness ?? this.brightness,
      pageBackground: pageBackground,
      sidebarBackground: sidebarBackground,
      surfaceColor: surfaceColor,
      surfaceBorder: surfaceBorder,
      softSurfaceColor: softSurfaceColor,
      softSurfaceBorder: softSurfaceBorder,
      activeSurfaceColor: activeSurfaceColor,
      activeSurfaceBorder: activeSurfaceBorder,
      buttonColor: buttonColor,
      buttonTextColor: buttonTextColor,
      textColor: textColor,
      mutedTextColor: mutedTextColor,
      accentColor: accentColor,
      successColor: successColor,
      warningColor: warningColor,
      dangerColor: dangerColor,
      drawerTextColor: drawerTextColor,
      drawerMutedTextColor: drawerMutedTextColor,
      drawerSectionTextColor: drawerSectionTextColor,
      drawerSectionActiveTextColor: drawerSectionActiveTextColor,
      drawerSectionIconColor: drawerSectionIconColor,
      drawerSectionActiveIconColor: drawerSectionActiveIconColor,
      drawerSectionArrowBackgroundColor: drawerSectionArrowBackgroundColor,
      drawerSectionArrowIconColor: drawerSectionArrowIconColor,
      headingFontFamily: headingFontFamily,
      bodyFontFamily: bodyFontFamily,
      isConfigurable: isConfigurable,
    );
  }
}

class UserDesignScope extends InheritedWidget {
  const UserDesignScope({
    super.key,
    required this.data,
    required super.child,
  });

  final UserDesignData data;

  static UserDesignData of(BuildContext context) {
    return maybeOf(context) ?? UserDesignData.fallback();
  }

  static UserDesignData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UserDesignScope>()?.data;
  }

  @override
  bool updateShouldNotify(UserDesignScope oldWidget) => data != oldWidget.data;
}

class UserDesignScopeLoader extends StatelessWidget {
  const UserDesignScopeLoader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (UserDesignScope.maybeOf(context) != null) return child;

    final companyId = resolveCurrentCompanyId();
    if (companyId.isEmpty) {
      return UserDesignScope(
        data: UserDesignData.fallback(),
        child: child,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        return UserDesignScope(
          data: UserDesignData.fromCompanyData(
            companyId: companyId,
            templateId: data[kUserDesignTemplateField],
            config: data[kUserDesignConfigField],
            brightness: Theme.of(context).brightness,
          ),
          child: child,
        );
      },
    );
  }
}

class UserScaffoldBackground extends StatelessWidget {
  const UserScaffoldBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final design = UserDesignScope.maybeOf(context);
    if (design == null) {
      return UserDesignScopeLoader(
        child: UserScaffoldBackground(child: child),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: design.pageBackground),
      child: child,
    );
  }
}

class UserSidebarSurface extends StatelessWidget {
  const UserSidebarSurface({
    super.key,
    this.width,
    this.height,
    required this.child,
  });

  final double? width;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final design = UserDesignScope.maybeOf(context);
    if (design == null) {
      return UserDesignScopeLoader(
        child: UserSidebarSurface(
          width: width,
          height: height,
          child: child,
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: design.sidebarBackground,
        border: Border.all(color: design.surfaceBorder),
      ),
      child: child,
    );
  }
}

class UserDesignTheme extends StatelessWidget {
  const UserDesignTheme({super.key, required this.child});

  final Widget child;

  static ThemeData buildTheme(ThemeData base, UserDesignData design) {
    final brightness = design.isDarkTheme ? Brightness.dark : Brightness.light;
    final colorScheme = base.colorScheme.copyWith(
      brightness: brightness,
      primary: design.buttonColor,
      secondary: design.accentColor,
      surface: design.surfaceColor,
      onPrimary: design.buttonTextColor,
      onSecondary: design.buttonTextColor,
      onSurface: design.textColor,
      error: base.colorScheme.error,
      onError: base.colorScheme.onError,
    );
    final textTheme = GoogleFonts.getTextTheme(
      design.bodyFontFamily,
      base.textTheme,
    ).copyWith(
      displayLarge: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w700,
        fontSize: 56,
      ),
      displayMedium: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w700,
        fontSize: 42,
      ),
      displaySmall: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w700,
        fontSize: 34,
      ),
      headlineLarge: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w700,
        fontSize: 30,
      ),
      headlineMedium: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w700,
        fontSize: 26,
      ),
      headlineSmall: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
      titleLarge: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      titleMedium: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleSmall: userDesignFont(
        design.headingFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyLarge: userDesignFont(
        design.bodyFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w400,
        fontSize: 16,
      ),
      bodyMedium: userDesignFont(
        design.bodyFontFamily,
        color: design.textColor,
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      bodySmall: userDesignFont(
        design.bodyFontFamily,
        color: design.mutedTextColor,
        fontWeight: FontWeight.w400,
        fontSize: 12,
      ),
      labelLarge: userDesignFont(
        design.bodyFontFamily,
        color: design.mutedTextColor,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      labelMedium: userDesignFont(
        design.bodyFontFamily,
        color: design.mutedTextColor,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      labelSmall: userDesignFont(
        design.bodyFontFamily,
        color: design.mutedTextColor,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    );

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: design.surfaceColor,
      cardColor: design.surfaceColor,
      dividerColor: design.surfaceBorder,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: design.textColor,
        elevation: 0,
        titleTextStyle: textTheme.headlineSmall,
      ),
      iconTheme: base.iconTheme.copyWith(color: design.textColor),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: design.isDarkTheme
            ? const Color(0xFF0F172A)
            : const Color(0xFF10213A),
        contentTextStyle: userDesignFont(
          design.bodyFontFamily,
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: design.surfaceColor,
        hintStyle: textTheme.bodyMedium?.copyWith(color: design.mutedTextColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: design.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: design.buttonColor, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: design.surfaceBorder),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: design.surfaceColor,
        shadowColor: design.isDarkTheme
            ? Colors.black.withValues(alpha: 0.28)
            : design.buttonColor.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: design.surfaceBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: design.buttonColor,
          foregroundColor: design.buttonTextColor,
          textStyle: userDesignFont(
            design.bodyFontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: design.textColor,
          side: BorderSide(color: design.surfaceBorder),
          textStyle: userDesignFont(
            design.bodyFontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: design.buttonColor,
          textStyle: userDesignFont(
            design.bodyFontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final design = UserDesignScope.maybeOf(context);
    if (design == null) {
      return UserDesignScopeLoader(
        child: UserDesignTheme(child: child),
      );
    }
    final base = Theme.of(context);
    return Theme(
      data: buildTheme(base, design),
      child: DefaultTextStyle.merge(
        style: userDesignFont(
          design.bodyFontFamily,
          color: design.textColor,
          fontSize: 14,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: design.textColor),
          child: child,
        ),
      ),
    );
  }
}
