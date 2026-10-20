import 'package:flutter/material.dart';

import '/user_design/user_design.dart';

const String kUserPageLayoutsField = 'userPageLayouts';
const String kSchetaPageLayoutKey = 'scheta';

const List<String> kSchetaLayoutBlockIds = <String>[
  'header',
  'role_info',
  'accounts',
];

Map<String, dynamic> defaultSchetaPageLayout() => {
      'blocks': [
        defaultSchetaLayoutBlock('header'),
        defaultSchetaLayoutBlock('role_info'),
        defaultSchetaLayoutBlock('accounts'),
      ],
    };

Map<String, dynamic> defaultSchetaLayoutBlock(String id) => {
      'id': id,
      'visible': true,
      'background': '',
      'border': '',
      'text': '',
      'accent': '',
    };

String schetaBlockTitle(String id) {
  switch (id) {
    case 'header':
      return 'Шапка страницы';
    case 'role_info':
      return 'Информация о роли';
    case 'accounts':
      return 'Блок счетов';
    default:
      return id;
  }
}

class PageLayoutBlockData {
  const PageLayoutBlockData({
    required this.id,
    required this.visible,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.accentColor,
  });

  final String id;
  final bool visible;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? accentColor;

  Map<String, dynamic> toMap() => {
        'id': id,
        'visible': visible,
        'background':
            backgroundColor == null ? '' : colorToHex(backgroundColor!),
        'border': borderColor == null ? '' : colorToHex(borderColor!),
        'text': textColor == null ? '' : colorToHex(textColor!),
        'accent': accentColor == null ? '' : colorToHex(accentColor!),
      };

  PageLayoutBlockData copyWith({
    bool? visible,
    Color? backgroundColor,
    bool clearBackground = false,
    Color? borderColor,
    bool clearBorder = false,
    Color? textColor,
    bool clearText = false,
    Color? accentColor,
    bool clearAccent = false,
  }) {
    return PageLayoutBlockData(
      id: id,
      visible: visible ?? this.visible,
      backgroundColor:
          clearBackground ? null : (backgroundColor ?? this.backgroundColor),
      borderColor: clearBorder ? null : (borderColor ?? this.borderColor),
      textColor: clearText ? null : (textColor ?? this.textColor),
      accentColor: clearAccent ? null : (accentColor ?? this.accentColor),
    );
  }
}

class SchetaPageLayoutData {
  const SchetaPageLayoutData({
    required this.blocks,
  });

  final List<PageLayoutBlockData> blocks;

  factory SchetaPageLayoutData.fromCompanyData(
      Map<String, dynamic> companyData) {
    final layoutsRaw = companyData[kUserPageLayoutsField];
    final layouts = layoutsRaw is Map<String, dynamic>
        ? layoutsRaw
        : layoutsRaw is Map
            ? Map<String, dynamic>.from(layoutsRaw)
            : const <String, dynamic>{};
    final pageRaw = layouts[kSchetaPageLayoutKey];
    final page = pageRaw is Map<String, dynamic>
        ? pageRaw
        : pageRaw is Map
            ? Map<String, dynamic>.from(pageRaw)
            : defaultSchetaPageLayout();
    final blocksRaw = page['blocks'];
    final parsed = <PageLayoutBlockData>[];
    if (blocksRaw is List) {
      for (final item in blocksRaw) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final id = (data['id'] ?? '').toString().trim();
        if (!kSchetaLayoutBlockIds.contains(id)) continue;
        parsed.add(
          PageLayoutBlockData(
            id: id,
            visible: data['visible'] != false,
            backgroundColor: _nullableColor(data['background']),
            borderColor: _nullableColor(data['border']),
            textColor: _nullableColor(data['text']),
            accentColor: _nullableColor(data['accent']),
          ),
        );
      }
    }

    for (final id in kSchetaLayoutBlockIds) {
      if (parsed.any((block) => block.id == id)) continue;
      parsed.add(
        PageLayoutBlockData(
          id: id,
          visible: true,
          backgroundColor: null,
          borderColor: null,
          textColor: null,
          accentColor: null,
        ),
      );
    }

    parsed.sort((a, b) => kSchetaLayoutBlockIds
        .indexOf(a.id)
        .compareTo(kSchetaLayoutBlockIds.indexOf(b.id)));

    return SchetaPageLayoutData(blocks: parsed);
  }

  Map<String, dynamic> toMap() => {
        'blocks': blocks.map((block) => block.toMap()).toList(),
      };

  PageLayoutBlockData block(String id) => blocks.firstWhere(
        (block) => block.id == id,
        orElse: () => PageLayoutBlockData(
          id: id,
          visible: true,
          backgroundColor: null,
          borderColor: null,
          textColor: null,
          accentColor: null,
        ),
      );

  List<PageLayoutBlockData> visibleBlocks() =>
      blocks.where((block) => block.visible).toList();
}

Color? _nullableColor(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty) return null;
  return colorFromHex(value, const Color(0x00000000));
}
