import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/user_design/user_design.dart';
import '/utils/access_rules.dart';

class UserDesignAdminPanel extends StatefulWidget {
  const UserDesignAdminPanel({
    super.key,
    required this.companyId,
    this.compact = false,
  });

  final String companyId;
  final bool compact;

  @override
  State<UserDesignAdminPanel> createState() => _UserDesignAdminPanelState();
}

class _UserDesignAdminPanelState extends State<UserDesignAdminPanel> {
  bool _saving = false;
  String? _editorTemplate;
  Brightness _editorBrightness = Brightness.light;

  Color _configColor(
    Map<String, dynamic> config,
    String keyName,
    Color fallback,
  ) {
    return colorFromHex(config[keyName], fallback);
  }

  Future<void> _updateCompanyDesign(Map<String, dynamic> patch) async {
    final companyId = widget.companyId.trim();
    if (companyId.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .set(
        {
          ...patch,
          'userDesignUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _canEditCompanyDesign() {
    final userData =
        currentUserDocument?.snapshotData ?? const <String, dynamic>{};
    return AccessRules.isAdminUserData(userData);
  }

  Future<void> _updateVariantConfig(
    Map<String, dynamic> fullConfig, {
    required String templateId,
    required Brightness brightness,
    required Map<String, dynamic> patch,
  }) async {
    final normalized = normalizeUserDesignConfig(fullConfig);
    final templates =
        Map<String, dynamic>.from(normalized[kUserDesignTemplatesField] as Map);
    final template =
        Map<String, dynamic>.from(templates[templateId] as Map? ?? const {});
    final modeKey = brightness == Brightness.dark
        ? kUserDesignDarkMode
        : kUserDesignLightMode;
    final variant = Map<String, dynamic>.from(
      template[modeKey] as Map? ?? const <String, dynamic>{},
    );
    template[modeKey] = {
      ...variant,
      ...patch,
    };
    templates[templateId] = template;
    await _updateCompanyDesign({
      kUserDesignConfigField: {
        ...normalized,
        kUserDesignTemplatesField: templates,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyId = widget.companyId.trim();
    if (companyId.isEmpty) {
      return const Text('Компания не выбрана');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final canEdit = _canEditCompanyDesign();
        final config = normalizeUserDesignConfig(data[kUserDesignConfigField]);
        final template = normalizeUserDesignTemplate(
          data[kUserDesignTemplateField],
        );
        final editorTemplate = _editorTemplate ?? template;
        final activeVariantConfig = userDesignVariantConfig(
          config,
          templateId: editorTemplate,
          brightness: _editorBrightness,
        );
        final preview = UserDesignData.fromCompanyData(
          companyId: companyId,
          templateId: editorTemplate,
          config: config,
          brightness: _editorBrightness,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Дизайн пользователей',
                        style: FlutterFlowTheme.of(context).titleLarge.override(
                              font: GoogleFonts.interTight(
                                fontWeight: FontWeight.w700,
                              ),
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        canEdit
                            ? 'Настройка обоих шаблонов доступна отдельно для светлой и тёмной темы.'
                            : 'Нет прав на изменение дизайна.',
                        style: FlutterFlowTheme.of(context).bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _templateTile(
                  context,
                  title: 'Дизайн 1',
                  subtitle: 'Базовый шаблон',
                  selected: template == kUserDesignCustom,
                  preview: [
                    colorFromHex(
                      userDesignVariantConfig(
                        config,
                        templateId: kUserDesignCustom,
                        brightness: Brightness.light,
                      )['pageStart'],
                      const Color(0xFFF8FBFF),
                    ),
                    colorFromHex(
                      userDesignVariantConfig(
                        config,
                        templateId: kUserDesignCustom,
                        brightness: Brightness.dark,
                      )['button'],
                      const Color(0xFF3B82F6),
                    ),
                  ],
                  onTap: canEdit
                      ? () => _updateCompanyDesign({
                            kUserDesignTemplateField: kUserDesignCustom,
                          })
                      : null,
                ),
                _templateTile(
                  context,
                  title: 'Дизайн 2',
                  subtitle: 'Luxury шаблон',
                  selected: template == kUserDesignReference,
                  preview: [
                    colorFromHex(
                      userDesignVariantConfig(
                        config,
                        templateId: kUserDesignReference,
                        brightness: Brightness.light,
                      )['pageStart'],
                      const Color(0xFFFFFCF7),
                    ),
                    colorFromHex(
                      userDesignVariantConfig(
                        config,
                        templateId: kUserDesignReference,
                        brightness: Brightness.dark,
                      )['button'],
                      const Color(0xFFE0B763),
                    ),
                  ],
                  onTap: canEdit
                      ? () => _updateCompanyDesign({
                            kUserDesignTemplateField: kUserDesignReference,
                          })
                      : null,
                ),
              ],
            ),
            if (widget.compact)
              const SizedBox.shrink()
            else ...[
              const SizedBox(height: 20),
              _settingsCard(
                context,
                title: 'Редактор шаблонов',
                subtitle:
                    'Выберите шаблон и режим темы, которые хотите настроить. Выбранный ниже редактор не меняет активный шаблон компании, пока вы отдельно его не переключите выше.',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: kUserDesignCustom,
                          label: Text('Шаблон 1'),
                        ),
                        ButtonSegment<String>(
                          value: kUserDesignReference,
                          label: Text('Шаблон 2'),
                        ),
                      ],
                      selected: {editorTemplate},
                      onSelectionChanged: canEdit
                          ? (values) => setState(
                                () => _editorTemplate = values.first,
                              )
                          : null,
                    ),
                    SegmentedButton<Brightness>(
                      segments: const [
                        ButtonSegment<Brightness>(
                          value: Brightness.light,
                          label: Text('Светлая'),
                        ),
                        ButtonSegment<Brightness>(
                          value: Brightness.dark,
                          label: Text('Тёмная'),
                        ),
                      ],
                      selected: {_editorBrightness},
                      onSelectionChanged: canEdit
                          ? (values) => setState(
                                () => _editorBrightness = values.first,
                              )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _settingsCard(
                context,
                title: 'Цвета интерфейса',
                subtitle:
                    'Для каждого элемента можно открыть редактор цвета с HEX и RGB.',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Фон страницы',
                      keyName: 'pageStart',
                      fallback: colorFromHex(
                        activeVariantConfig['pageStart'],
                        const Color(0xFFF8FBFF),
                      ),
                      helper: 'Начало градиента страницы',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Фон страницы 2',
                      keyName: 'pageEnd',
                      fallback: colorFromHex(
                        activeVariantConfig['pageEnd'],
                        const Color(0xFFE9F0FA),
                      ),
                      helper: 'Конец градиента страницы',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Фон карточек',
                      keyName: 'surface',
                      fallback: colorFromHex(
                        activeVariantConfig['surface'],
                        const Color(0xFFFFFFFF),
                      ),
                      helper: 'Карточки, поля и выпадающие списки',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Границы',
                      keyName: 'surfaceBorder',
                      fallback: colorFromHex(
                        activeVariantConfig['surfaceBorder'],
                        const Color(0xFFD6E2F0),
                      ),
                      helper: 'Рамки и разделители',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Мягкий фон',
                      keyName: 'softSurface',
                      fallback: colorFromHex(
                        activeVariantConfig['softSurface'],
                        const Color(0xFFF8FAFD),
                      ),
                      helper: 'Вторичный фон блоков и экранов',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Мягкие границы',
                      keyName: 'softSurfaceBorder',
                      fallback: colorFromHex(
                        activeVariantConfig['softSurfaceBorder'],
                        const Color(0xFFE2E8F0),
                      ),
                      helper: 'Границы вторичных блоков',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Активный блок',
                      keyName: 'activeSurface',
                      fallback: colorFromHex(
                        activeVariantConfig['activeSurface'],
                        const Color(0xFFEAF2FF),
                      ),
                      helper: 'Фон активных пунктов и выделения',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Граница активного',
                      keyName: 'activeSurfaceBorder',
                      fallback: colorFromHex(
                        activeVariantConfig['activeSurfaceBorder'],
                        const Color(0xFF8AB4FF),
                      ),
                      helper: 'Рамка активных пунктов',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Кнопки',
                      keyName: 'button',
                      fallback: colorFromHex(
                        activeVariantConfig['button'],
                        const Color(0xFF1D4ED8),
                      ),
                      helper: 'Основные действия',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Текст кнопок',
                      keyName: 'buttonText',
                      fallback: colorFromHex(
                        activeVariantConfig['buttonText'],
                        const Color(0xFFFFFFFF),
                      ),
                      helper: 'Надписи внутри кнопок',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Основной текст',
                      keyName: 'text',
                      fallback: colorFromHex(
                        activeVariantConfig['text'],
                        const Color(0xFF0F172A),
                      ),
                      helper: 'Заголовки и обычный текст',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Вторичный текст',
                      keyName: 'mutedText',
                      fallback: colorFromHex(
                        activeVariantConfig['mutedText'],
                        const Color(0xFF475569),
                      ),
                      helper: 'Подписи и дополнительные детали',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Акцент',
                      keyName: 'accent',
                      fallback: colorFromHex(
                        activeVariantConfig['accent'],
                        const Color(0xFF0EA5E9),
                      ),
                      helper: 'Подсветка графиков и вторичных акцентов',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Успех',
                      keyName: 'success',
                      fallback: colorFromHex(
                        activeVariantConfig['success'],
                        const Color(0xFF16A34A),
                      ),
                      helper: 'Положительные показатели и успех',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Предупреждение',
                      keyName: 'warning',
                      fallback: colorFromHex(
                        activeVariantConfig['warning'],
                        const Color(0xFFD97706),
                      ),
                      helper: 'Предупреждения и внимание',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Ошибка',
                      keyName: 'danger',
                      fallback: colorFromHex(
                        activeVariantConfig['danger'],
                        const Color(0xFFDC2626),
                      ),
                      helper: 'Ошибки, удаления и опасные действия',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Меню фон 1',
                      keyName: 'drawerStart',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerStart'],
                        const Color(0xFFFFFFFF),
                      ),
                      helper: 'Начало фона бокового меню',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Меню фон 2',
                      keyName: 'drawerEnd',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerEnd'],
                        const Color(0xFFF3F7FC),
                      ),
                      helper: 'Конец фона бокового меню',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Текст меню',
                      keyName: 'drawerText',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerText'],
                        const Color(0xFF0F172A),
                      ),
                      helper: 'Основной цвет текста в меню',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Вторичный текст меню',
                      keyName: 'drawerMutedText',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerMutedText'],
                        const Color(0xFF475569),
                      ),
                      helper: 'Подсказки и вторичный текст меню',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _settingsCard(
                context,
                title: 'Боковое меню',
                subtitle:
                    'Отдельная настройка основных пунктов меню, их активного состояния и стрелки раскрытия.',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Текст основных пунктов',
                      keyName: 'drawerSectionText',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerSectionText'],
                        colorFromHex(
                          activeVariantConfig['drawerText'],
                          const Color(0xFF0F172A),
                        ),
                      ),
                      helper: 'Название основных разделов меню',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Текст активного пункта',
                      keyName: 'drawerSectionActiveText',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerSectionActiveText'],
                        colorFromHex(
                          activeVariantConfig['button'],
                          const Color(0xFF1D4ED8),
                        ),
                      ),
                      helper: 'Текст раскрытого или активного раздела',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Иконки основных пунктов',
                      keyName: 'drawerSectionIcon',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerSectionIcon'],
                        colorFromHex(
                          activeVariantConfig['drawerSectionText'],
                          const Color(0xFF0F172A),
                        ),
                      ),
                      helper: 'Иконки слева в основных разделах',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Иконки активного пункта',
                      keyName: 'drawerSectionActiveIcon',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerSectionActiveIcon'],
                        colorFromHex(
                          activeVariantConfig['drawerSectionActiveText'],
                          const Color(0xFF1D4ED8),
                        ),
                      ),
                      helper: 'Иконки в активном основном разделе',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Фон стрелки',
                      keyName: 'drawerSectionArrowBg',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerSectionArrowBg'],
                        colorFromHex(
                          activeVariantConfig['activeSurface'],
                          const Color(0xFFEAF2FF),
                        ),
                      ),
                      helper: 'Кнопка справа у основного раздела',
                    ),
                    _colorEditorTile(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Иконка стрелки',
                      keyName: 'drawerSectionArrowIcon',
                      fallback: colorFromHex(
                        activeVariantConfig['drawerSectionArrowIcon'],
                        colorFromHex(
                          activeVariantConfig['button'],
                          const Color(0xFF1D4ED8),
                        ),
                      ),
                      helper: 'Цвет стрелки раскрытия',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _settingsCard(
                context,
                title: 'Шрифты',
                subtitle:
                    'Шрифты применяются ко всей пользовательской части приложения. Админка остаётся на своей теме.',
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _fontSelector(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Шрифт заголовков',
                      keyName: 'headingFontFamily',
                      previewText: 'Заголовок раздела',
                      textColor: preview.textColor,
                    ),
                    _fontSelector(
                      context,
                      canEdit: canEdit,
                      config: config,
                      templateId: editorTemplate,
                      brightness: _editorBrightness,
                      label: 'Шрифт основного текста',
                      keyName: 'bodyFontFamily',
                      previewText: 'Основной текст, формы и таблицы',
                      textColor: preview.textColor,
                    ),
                  ],
                ),
              ),
              if (!widget.compact) ...[
                const SizedBox(height: 12),
                _preview(
                  UserDesignData.fromCompanyData(
                    companyId: companyId,
                    templateId: editorTemplate,
                    config: config,
                    brightness: _editorBrightness,
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _templateTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    required List<Color> preview,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8EEF8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: preview
                  .map((color) => Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.interTight(),
                    color: const Color(0xFF111827),
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(),
                    color: const Color(0xFF475569),
                    letterSpacing: 0,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  font: GoogleFonts.interTight(),
                  color: const Color(0xFF111827),
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(),
                  color: const Color(0xFF475569),
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _colorEditorTile(
    BuildContext context, {
    required bool canEdit,
    required Map<String, dynamic> config,
    required String templateId,
    required Brightness brightness,
    required String label,
    required String keyName,
    required Color fallback,
    required String helper,
  }) {
    final current = _configColor(
      userDesignVariantConfig(
        config,
        templateId: templateId,
        brightness: brightness,
      ),
      keyName,
      fallback,
    );
    const titleColor = Color(0xFF111827);
    const bodyColor = Color(0xFF475569);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: current,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.interTight(),
                        color: titleColor,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            colorToHex(current),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(),
                  color: bodyColor,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: bodyColor,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: titleColor,
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              onPressed: canEdit
                  ? () => _openColorEditor(
                        context,
                        config: config,
                        templateId: templateId,
                        brightness: brightness,
                        keyName: keyName,
                        label: label,
                        fallback: fallback,
                      )
                  : null,
              child: const Text('Изменить цвет'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openColorEditor(
    BuildContext context, {
    required Map<String, dynamic> config,
    required String templateId,
    required Brightness brightness,
    required String keyName,
    required String label,
    required Color fallback,
  }) async {
    var current = _configColor(config, keyName, fallback);
    final hexController = TextEditingController(text: colorToHex(current));

    int red() => current.red;
    int green() => current.green;
    int blue() => current.blue;

    Future<void> saveAndClose(BuildContext dialogContext) async {
      await _updateVariantConfig(
        config,
        templateId: templateId,
        brightness: brightness,
        patch: {
          keyName: colorToHex(current),
        },
      );
      if (dialogContext.mounted) Navigator.pop(dialogContext);
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void syncHex() {
              setModalState(() {
                hexController.text = colorToHex(current);
              });
            }

            return AlertDialog(
              title: Text('Цвет: $label'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: current,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: hexController,
                        decoration: const InputDecoration(
                          labelText: 'HEX',
                          hintText: '#FFFFFFFF',
                        ),
                        onChanged: (value) {
                          final parsed = colorFromHex(value, current);
                          if (parsed.toARGB32() != current.toARGB32()) {
                            setModalState(() => current = parsed);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('R: ${red()}'),
                      Slider(
                        value: red().toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (value) {
                          setModalState(() {
                            current = current.withRed(value.round());
                            hexController.text = colorToHex(current);
                          });
                        },
                      ),
                      Text('G: ${green()}'),
                      Slider(
                        value: green().toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (value) {
                          setModalState(() {
                            current = current.withGreen(value.round());
                            hexController.text = colorToHex(current);
                          });
                        },
                      ),
                      Text('B: ${blue()}'),
                      Slider(
                        value: blue().toDouble(),
                        min: 0,
                        max: 255,
                        onChanged: (value) {
                          setModalState(() {
                            current = current.withBlue(value.round());
                            hexController.text = colorToHex(current);
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          Color(0xFFFFFFFF),
                          Color(0xFF111827),
                          Color(0xFF1D4ED8),
                          Color(0xFFD97706),
                          Color(0xFF0F766E),
                          Color(0xFF7C3AED),
                          Color(0xFFBE123C),
                          Color(0xFF0EA5E9),
                        ].map((color) {
                          return _QuickColor(
                            color: color,
                            onTap: () {
                              setModalState(() {
                                current = color;
                                hexController.text = colorToHex(current);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    current = fallback;
                    syncHex();
                  },
                  child: const Text('Сброс'),
                ),
                ElevatedButton(
                  onPressed: () => saveAndClose(dialogContext),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    hexController.dispose();
  }

  Widget _fontSelector(
    BuildContext context, {
    required bool canEdit,
    required Map<String, dynamic> config,
    required String templateId,
    required Brightness brightness,
    required String label,
    required String keyName,
    required String previewText,
    required Color textColor,
  }) {
    final fallback = keyName == 'headingFontFamily' ? 'Inter Tight' : 'Inter';
    final current = normalizeUserDesignFontFamily(
      userDesignVariantConfig(
        config,
        templateId: templateId,
        brightness: brightness,
      )[keyName],
      fallback,
    );
    const titleColor = Color(0xFF111827);
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.interTight(),
                  color: titleColor,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: current,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: kUserDesignFontFamilies.map((family) {
              return DropdownMenuItem(
                value: family,
                child: Text(
                  family,
                  style: userDesignFont(
                    family,
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: canEdit
                ? (value) {
                    if (value == null) return;
                    _updateVariantConfig(
                      config,
                      templateId: templateId,
                      brightness: brightness,
                      patch: {
                        keyName: value,
                      },
                    );
                  }
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            previewText,
            style: userDesignFont(
              current,
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: keyName == 'headingFontFamily' ? 24 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(UserDesignData design) {
    return Container(
      decoration: BoxDecoration(
        gradient: design.pageBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: design.surfaceBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              gradient: design.sidebarBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: design.surfaceBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Меню',
                  style: userDesignFont(
                    design.headingFontFamily,
                    color: design.drawerTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 14),
                _previewMenuItem(design, 'Счета'),
                _previewMenuItem(design, 'Продажи'),
                _previewMenuItem(design, 'Настройки'),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: design.softSurfaceColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: design.softSurfaceBorder),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Экран пользователя',
                    style: userDesignFont(
                      design.headingFontFamily,
                      color: design.textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Такой стиль увидят все сотрудники компании.',
                    style: userDesignFont(
                      design.bodyFontFamily,
                      color: design.mutedTextColor,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: design.buttonColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Кнопка действия',
                        style: userDesignFont(
                          design.bodyFontFamily,
                          color: design.buttonTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewMenuItem(UserDesignData design, String label) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: design.activeSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: design.activeSurfaceBorder),
      ),
      child: Text(
        label,
        style: userDesignFont(
          design.bodyFontFamily,
          color: design.drawerTextColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _QuickColor extends StatelessWidget {
  const _QuickColor({
    required this.color,
    required this.onTap,
  });

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}
