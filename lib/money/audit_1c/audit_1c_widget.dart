import '/component/header/header_widget.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/custom_code/widgets/permissions_helper.dart';
import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import '/utils/country_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:xml/xml.dart' as xml;

class Audit1CWidget extends StatefulWidget {
  const Audit1CWidget({super.key});

  static String routeName = 'audit1C';
  static String routePath = '/audit1C';

  @override
  State<Audit1CWidget> createState() => _Audit1CWidgetState();
}

class _Audit1CWidgetState extends State<Audit1CWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _uploadingExpressCheck = false;
  bool _syncSaving = false;
  bool _syncRunning = false;
  bool _autoSyncEnabled = false;
  int _syncIntervalMinutes = 1440;
  int _fixedErrorsCount = 0;
  Timer? _syncTimer;
  final Set<String> _expandedPanels = {
    'overview',
    'criticality',
  };
  final Set<String> _expandedSections = {};
  final Set<AuditCriticality> _expandedCriticalityBlocks = {};
  final TextEditingController _xmlUrlController = TextEditingController();
  final TextEditingController _xmlTokenController = TextEditingController();
  final GlobalKey _criticalityPanelKey = GlobalKey();
  String? _syncStatusText;
  CountryProfile _companyCountryProfile = kazakhstanCountryProfile;

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  Color get _pageBackground =>
      _isDarkTheme ? const Color(0xFF111722) : const Color(0xFFF4F6FB);

  Color get _pageBackgroundSoft =>
      _isDarkTheme ? const Color(0xFF151C28) : const Color(0xFFF8FAFC);

  Color get _panelSurface => _isDarkTheme
      ? Color.alphaBlend(
          FlutterFlowTheme.of(context).primary.withValues(alpha: 0.04),
          FlutterFlowTheme.of(context).secondaryBackground,
        )
      : const Color(0xFFFFFFFF);

  Color get _panelSurfaceSoft => _isDarkTheme
      ? Color.alphaBlend(
          Colors.white.withValues(alpha: 0.03),
          FlutterFlowTheme.of(context).secondaryBackground,
        )
      : const Color(0xFFFCFDFE);

  Color get _panelBorder => _isDarkTheme
      ? FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.45)
      : const Color(0xFFE7ECF4);

  Color get _panelBorderSoft => _isDarkTheme
      ? FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.32)
      : const Color(0xFFE5E7EB);

  Color get _strongText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.96)
      : const Color(0xFF111827);

  Color get _mutedText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.72)
      : const Color(0xFF4B5563);

  Color get _softText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.58)
      : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadCompanyCountryProfile();
    _loadXmlSyncSettings();
    _loadLatestAuditStats();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _xmlUrlController.dispose();
    _xmlTokenController.dispose();
    super.dispose();
  }

  static const _kzSections = <_AuditSection>[
    _AuditSection(key: 'A', title: 'Учетная политика и регламент', rules: [
      _AuditRule(
          code: 'A1',
          name: 'Наличие учетной политики по бухгалтерскому учету',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'A2',
          name: 'Наличие учетной политики по налоговому учету',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'A3',
          name: 'Наличие учетной политики по персоналу',
          criticality: AuditCriticality.high),
      _AuditRule(
          code: 'A4',
          name: 'Заполненность регламентированного производственного календаря',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(key: 'B', title: 'Касса и наличные операции', rules: [
      _AuditRule(
          code: 'B1',
          name: 'Отсутствие непроведенных кассовых документов',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'B2',
          name: 'Отсутствие отрицательных остатков по кассе',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'B3',
          name: 'Соблюдение лимита расчетов наличными с ЮЛ и ИП',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'B4',
          name: 'Соблюдение нумерации ПКО и РКО',
          criticality: AuditCriticality.high),
      _AuditRule(
          code: 'B5',
          name: 'Соответствие курсов в банковских и кассовых документах',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(
        key: 'C',
        title: 'ДДС и статьи движения денежных средств',
        rules: [
          _AuditRule(
              code: 'C1',
              name: 'Заполнение реквизитов справочника «Статьи ДДС»',
              criticality: AuditCriticality.high),
          _AuditRule(
              code: 'C2',
              name: 'Заполненность статьи ДДС в документах',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'C3',
              name: 'Соответствие «Поступление/Выбытие» фактической операции',
              criticality: AuditCriticality.critical),
        ]),
    _AuditSection(key: 'D', title: 'Заработная плата и персонал', rules: [
      _AuditRule(
          code: 'D1',
          name: 'Отражение зарплаты в регламентированном учете',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'D2',
          name: 'Наличие документа «Удержание ИПН, ОПВ, ВОСМС»',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'D3',
          name: 'Корректность расчета налогов по зарплате',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'D4',
          name: 'Регистрация облагаемых доходов ИП',
          criticality: AuditCriticality.critical),
    ]),
    _AuditSection(key: 'E', title: 'НДС и ЭСФ', rules: [
      _AuditRule(
          code: 'E1',
          name: 'Корректность выписки выданных счетов-фактур',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'E2',
          name: 'Корректность выписки полученных счетов-фактур',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'E3',
          name: 'Наличие регистрационных данных по НДС у поставщиков',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'E4',
          name: 'Отсутствие отрицательных остатков по источникам происхождения',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'E5',
          name: 'Корректность заполнения ЭСФ и источников происхождения',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'E6',
          name: 'Корректность отложенного принятия НДС к зачету',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'E7',
          name: 'Корректность регистрации ЭСФ при отложенном НДС',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'E8',
          name: 'Своевременность выписки ЭСФ по отгрузке',
          criticality: AuditCriticality.critical),
    ]),
    _AuditSection(key: 'F', title: 'Документы и договоры', rules: [
      _AuditRule(
          code: 'F1',
          name:
              'Наличие проведенных документов по ЭАВР со статусом «Расторгнут»',
          criticality: AuditCriticality.high),
      _AuditRule(
          code: 'F2',
          name: 'Несовпадение даты выписки и подписания актов',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(key: 'G', title: 'Баланс и проводки', rules: [
      _AuditRule(
          code: 'G1',
          name: 'Отрицательные остатки на балансовых счетах',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'G2',
          name: 'Остатки на доходных/расходных счетах после реформации',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'G3',
          name: 'Корректность использования счетов в проводках',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'G4',
          name: 'Зависшие остатки и сальдо на балансовых счетах',
          criticality: AuditCriticality.critical),
    ]),
    _AuditSection(key: 'H', title: 'Основные средства', rules: [
      _AuditRule(
          code: 'H1',
          name: 'Статус «Принято к учету» при наличии остатка ОС',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'H2',
          name: 'Статус «Снято с учета» при отсутствии остатка ОС',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'H3',
          name: 'Соответствие Подразделения/МОЛ счетам и регистрам',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(key: 'I', title: 'Контроль изменений и чистоты базы', rules: [
      _AuditRule(
          code: 'I1',
          name: 'Статистика создания документов и справочников',
          criticality: AuditCriticality.control),
      _AuditRule(
          code: 'I2',
          name: 'Изменения документов прошлых периодов',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'I3',
          name: 'Дубли номенклатуры',
          criticality: AuditCriticality.control),
      _AuditRule(
          code: 'I4',
          name: 'Помеченные на удаление объекты',
          criticality: AuditCriticality.control),
    ]),
    _AuditSection(
        key: 'J',
        title: 'Экономический смысл и контроль бухгалтера',
        rules: [
          _AuditRule(
              code: 'J1',
              name: 'Проводка корректна формально, но неверна по смыслу',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J2',
              name: 'Использование счетов затрат без аналитики',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J3',
              name: 'Ручные операции без документа-основания',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J4',
              name: 'Использование счета 000 для выравнивания',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J5',
              name: 'Исправление ошибок через сторно в другом периоде',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J6',
              name: 'Документы, введенные после сдачи отчетности',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J7',
              name: 'Несоответствие прибыли ОПИУ и изменения капитала',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J8',
              name: 'ДДС классифицирован не по типу потока',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J9',
              name: 'Подотчетные суммы без движения > N дней',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J10',
              name: 'Авансы без закрывающих документов',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J11',
              name: 'Расчеты с учредителями без договоров',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J12',
              name: 'Налоги рассчитаны без налоговой базы',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J13',
              name: 'Частые исправления одним пользователем',
              criticality: AuditCriticality.high),
          _AuditRule(
              code: 'J14',
              name: 'Массовые изменения прошлых периодов',
              criticality: AuditCriticality.critical),
          _AuditRule(
              code: 'J15',
              name: 'Отсутствие закрытия месяца при наличии оборотов',
              criticality: AuditCriticality.critical),
        ]),
  ];

  static const _tjSections = <_AuditSection>[
    _AuditSection(key: 'A', title: 'Учетная политика и регламент', rules: [
      _AuditRule(
          code: 'TJ-A1',
          name: 'Наличие учетной политики по бухгалтерскому учету',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-A2',
          name: 'Наличие учетной политики по налоговому учету РТ',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-A3',
          name: 'Заполненность производственного календаря РТ',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(key: 'B', title: 'Касса, банк и валютные операции', rules: [
      _AuditRule(
          code: 'TJ-B1',
          name: 'Отсутствие непроведенных кассовых и банковских документов',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-B2',
          name: 'Отсутствие отрицательных остатков по кассе и счетам',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-B3',
          name: 'Соответствие курсов валют дате операции',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(key: 'C', title: 'НДС Таджикистан', rules: [
      _AuditRule(
          code: 'TJ-C1',
          name: 'Корректность ставки НДС по дате операции',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-C2',
          name: 'Корректность НДС к зачету по расходам',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-C3',
          name: 'Сверка начисленного и зачтенного НДС',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(key: 'D', title: 'Налог на доходы юрлиц', rules: [
      _AuditRule(
          code: 'TJ-D1',
          name: 'Корректность налоговой базы по доходам и вычетам',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-D2',
          name: 'Корректность применения ставки налога на доходы юрлиц',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-D3',
          name: 'Сверка налогового учета с бухгалтерской прибылью',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(key: 'E', title: 'Зарплата и налоги сотрудников', rules: [
      _AuditRule(
          code: 'TJ-E1',
          name: 'Корректность расчета подоходного налога сотрудников',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-E2',
          name: 'Корректность расчета социального налога',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-E3',
          name: 'Отражение зарплаты в регламентированном учете',
          criticality: AuditCriticality.high),
    ]),
    _AuditSection(key: 'F', title: 'Баланс и закрытие периода', rules: [
      _AuditRule(
          code: 'TJ-F1',
          name: 'Отсутствие некорректных проводок и незакрытых периодов',
          criticality: AuditCriticality.critical),
      _AuditRule(
          code: 'TJ-F2',
          name: 'Сверка оборотов и остатков по счетам',
          criticality: AuditCriticality.high),
      _AuditRule(
          code: 'TJ-F3',
          name: 'Контроль изменений прошлых периодов',
          criticality: AuditCriticality.high),
    ]),
  ];

  List<_AuditSection> get _sections =>
      _companyCountryProfile.countryCode == 'TJ' ? _tjSections : _kzSections;

  List<_AuditRule> get _allRules => [for (final s in _sections) ...s.rules];

  int _count(AuditCriticality criticality) =>
      _allRules.where((r) => r.criticality == criticality).length;

  int get _criticalErrors => _count(AuditCriticality.critical);
  int get _substantialErrors => _count(AuditCriticality.high);
  int get _controlErrors => _count(AuditCriticality.control);
  int get _totalErrors => _criticalErrors + _substantialErrors;
  bool get _isAccountingReliable =>
      _criticalErrors == 0 && _substantialErrors == 0;

  String get _reliabilityStatusLabel {
    if (_criticalErrors > 0) {
      return 'Недостоверный: критические ошибки присутствуют';
    }
    if (_substantialErrors > 0) {
      return 'Относительно достоверный: ошибки только существенные';
    }
    return 'Достоверный: критических и существенных ошибок нет';
  }

  Color get _reliabilityStatusColor {
    if (_criticalErrors > 0) return const Color(0xFFB42318);
    if (_substantialErrors > 0) return const Color(0xFFB45309);
    return const Color(0xFF15803D);
  }

  double _ratio(AuditCriticality criticality) =>
      _allRules.isEmpty ? 0 : _count(criticality) / _allRules.length;

  List<_AuditRule> _rulesBy(AuditCriticality criticality) =>
      _allRules.where((r) => r.criticality == criticality).toList()
        ..sort((a, b) => a.code.compareTo(b.code));

  String _effectiveCompanyId() {
    final raw = (currentUserDocument?.idCompany ?? '').trim();
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    final companyIds = (currentUserDocument?.companyIds ?? const <String>[])
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (raw == '__all__') {
      if (active.isNotEmpty) return active;
      if (companyIds.isNotEmpty) return companyIds.first;
      return '';
    }
    if (raw.isNotEmpty) return raw;
    if (active.isNotEmpty) return active;
    if (companyIds.isNotEmpty) return companyIds.first;
    return '';
  }

  Future<void> _loadCompanyCountryProfile() async {
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('company_profile')
          .doc(companyId)
          .get(const GetOptions(source: Source.serverAndCache));
      final profile = countryProfileFromData(doc.data());
      if (!mounted) return;
      setState(() => _companyCountryProfile = profile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _companyCountryProfile = kazakhstanCountryProfile);
    }
  }

  Future<void> _loadLatestAuditStats() async {
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('audit_1c_runs')
          .where('idCompany', isEqualTo: companyId)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty || !mounted) return;
      final data = snap.docs.first.data();
      final indicators = (data['indicators'] is Map)
          ? Map<String, dynamic>.from(data['indicators'] as Map)
          : const <String, dynamic>{};
      final fixed = (indicators['fixed_errors'] as num?)?.toInt() ??
          (indicators['resolved_errors'] as num?)?.toInt() ??
          (indicators['corrected_errors'] as num?)?.toInt() ??
          0;
      setState(() {
        _fixedErrorsCount = fixed;
      });
    } catch (_) {}
  }

  Future<void> _scrollToCriticality({AuditCriticality? criticality}) async {
    setState(() {
      _expandedPanels.add('criticality');
      if (criticality != null) {
        _expandedCriticalityBlocks.add(criticality);
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final context = _criticalityPanelKey.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Map<String, dynamic> _buildAuditIndicators({
    required String fileName,
    required int fileSizeBytes,
  }) {
    final totalRules = _allRules.length;
    final critical = _count(AuditCriticality.critical);
    final high = _count(AuditCriticality.high);
    final control = _count(AuditCriticality.control);
    final weightedRiskScore = (critical * 3) + (high * 2) + control;
    final ext = fileName.split('.').last.toLowerCase();
    return {
      'source_type': 'express_check',
      'country_code': _companyCountryProfile.countryCode,
      'parse_status': 'uploaded_metadata',
      'file_ext': ext,
      'file_size_bytes': fileSizeBytes,
      'matrix_rules_total': totalRules,
      'critical_count': critical,
      'high_count': high,
      'control_count': control,
      'sections_total': _sections.length,
      'weighted_risk_score': weightedRiskScore,
      'critical_ratio': totalRules == 0 ? 0 : critical / totalRules,
      'high_ratio': totalRules == 0 ? 0 : high / totalRules,
      'control_ratio': totalRules == 0 ? 0 : control / totalRules,
      'section_breakdown': {
        for (final s in _sections)
          s.key: {
            'title': s.title,
            'total': s.rules.length,
            'critical': s.count(AuditCriticality.critical),
            'high': s.count(AuditCriticality.high),
            'control': s.count(AuditCriticality.control),
          }
      },
      'generated_from': 'audit_docx_matrix+uploaded_file_metadata',
    };
  }

  Future<void> _uploadExpressCheckFile() async {
    final userId = currentUserUid;
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не определена компания или пользователь'),
        ),
      );
      return;
    }

    final selected = await selectFile(
      storageFolderPath: 'users/$userId/audit_1c/express_check',
      allowedExtensions: ['xls', 'xlsx'],
    );
    if (selected == null) return;

    final fileName = (selected.originalFilename ?? '').trim().isNotEmpty
        ? selected.originalFilename!.trim()
        : selected.storagePath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    if (!(ext == 'xls' || ext == 'xlsx')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужен файл формата .xls или .xlsx')),
      );
      return;
    }

    if (selected.bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл пустой или не прочитан')),
      );
      return;
    }

    setState(() => _uploadingExpressCheck = true);
    try {
      showUploadMessage(context, 'Загрузка файла...', showLoading: true);
      final downloadUrl =
          await uploadData(selected.storagePath, selected.bytes);
      if (downloadUrl == null) {
        throw Exception('upload_failed');
      }

      final indicators = _buildAuditIndicators(
        fileName: fileName,
        fileSizeBytes: selected.bytes.length,
      );

      final doc = FirebaseFirestore.instance.collection('audit_1c_runs').doc();
      await doc.set({
        'idCompany': companyId,
        'country_code': _companyCountryProfile.countryCode,
        'user_id': userId,
        'source': 'express_check_upload',
        'status': 'ready',
        'file_name': fileName,
        'file_storage_path': selected.storagePath,
        'file_url': downloadUrl,
        'file_size_bytes': selected.bytes.length,
        'file_ext': ext,
        'indicators': indicators,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Экспресс-проверка загружена, показатели сохранены'),
          ),
        );
      _loadLatestAuditStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Ошибка загрузки/сохранения: $e')),
        );
    } finally {
      if (mounted) {
        setState(() => _uploadingExpressCheck = false);
      }
    }
  }

  Future<void> _loadXmlSyncSettings() async {
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty || currentUserUid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('audit_1c_sync_settings')
          .doc('${companyId}_xml')
          .get();
      if (!doc.exists) return;
      final data = doc.data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _xmlUrlController.text = (data['xml_url'] ?? '').toString();
        _xmlTokenController.text = (data['xml_token'] ?? '').toString();
        _autoSyncEnabled = data['auto_enabled'] == true;
        final interval = (data['interval_minutes'] as num?)?.toInt() ?? 15;
        if (interval <= 1440) {
          _syncIntervalMinutes = 1440;
        } else if (interval <= 10080) {
          _syncIntervalMinutes = 10080;
        } else {
          _syncIntervalMinutes = 43200;
        }
        _syncStatusText = (data['last_status_text'] ?? '').toString().trim();
      });
      _restartSyncTimer();
    } catch (e) {
      debugPrint('load xml sync settings error: $e');
    }
  }

  Future<void> _saveXmlSyncSettings() async {
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty || currentUserUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не определена компания/пользователь')),
      );
      return;
    }
    final url = _xmlUrlController.text.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите URL XML отчета 1С 8.3')),
      );
      return;
    }
    setState(() => _syncSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('audit_1c_sync_settings')
          .doc('${companyId}_xml')
          .set({
        'idCompany': companyId,
        'user_id': currentUserUid,
        'type': 'xml_1c_83',
        'xml_url': url,
        'xml_token': _xmlTokenController.text.trim(),
        'auto_enabled': _autoSyncEnabled,
        'interval_minutes': _syncIntervalMinutes,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _restartSyncTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки XML синхронизации сохранены')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения настроек: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncSaving = false);
    }
  }

  void _restartSyncTimer() {
    _syncTimer?.cancel();
    if (!_autoSyncEnabled) return;
    final interval = Duration(minutes: _syncIntervalMinutes);
    _syncTimer = Timer.periodic(interval, (_) {
      _syncXmlNow(background: true);
    });
  }

  Map<String, dynamic> _buildIndicatorsFromXml(String xmlText) {
    final document = xml.XmlDocument.parse(xmlText);
    final allElements = document.findAllElements('*').toList();
    final tagCounts = <String, int>{};
    final criticalityCounts = <String, int>{
      'critical': 0,
      'high': 0,
      'control': 0,
    };
    final samples = <Map<String, dynamic>>[];

    for (final element in allElements) {
      final name = element.name.local;
      tagCounts[name] = (tagCounts[name] ?? 0) + 1;
      final text = element.innerText.trim();
      if (text.isNotEmpty) {
        final normalized = text.toLowerCase();
        if (normalized.contains('критич')) {
          criticalityCounts['critical'] = criticalityCounts['critical']! + 1;
        } else if (normalized.contains('существен')) {
          criticalityCounts['high'] = criticalityCounts['high']! + 1;
        } else if (normalized.contains('контроль')) {
          criticalityCounts['control'] = criticalityCounts['control']! + 1;
        }
      }
    }

    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedTags.take(10)) {
      samples.add({'tag': e.key, 'count': e.value});
    }

    final root = document.rootElement.name.local;
    final directChildren = document.rootElement.childElements.toList();
    final repeatedChildren = <String, int>{};
    for (final child in directChildren) {
      repeatedChildren[child.name.local] =
          (repeatedChildren[child.name.local] ?? 0) + 1;
    }

    return {
      'source_type': 'xml_1c_83',
      'country_code': _companyCountryProfile.countryCode,
      'parse_status': 'parsed',
      'root_tag': root,
      'xml_nodes_total': allElements.length,
      'xml_direct_children_total': directChildren.length,
      'top_tags': samples,
      'tag_counts_top': {for (final e in sortedTags.take(20)) e.key: e.value},
      'xml_detected_critical': criticalityCounts['critical'],
      'xml_detected_high': criticalityCounts['high'],
      'xml_detected_control': criticalityCounts['control'],
      'matrix_rules_total': _allRules.length,
      'matrix_critical_count': _count(AuditCriticality.critical),
      'matrix_high_count': _count(AuditCriticality.high),
      'matrix_control_count': _count(AuditCriticality.control),
      'section_breakdown': {
        for (final s in _sections)
          s.key: {
            'title': s.title,
            'total': s.rules.length,
            'critical': s.count(AuditCriticality.critical),
            'high': s.count(AuditCriticality.high),
            'control': s.count(AuditCriticality.control),
          }
      },
      'repeated_root_children': repeatedChildren,
    };
  }

  Future<void> _syncXmlNow({bool background = false}) async {
    final companyId = _effectiveCompanyId();
    final userId = currentUserUid;
    final url = _xmlUrlController.text.trim();
    if (companyId.isEmpty || userId.isEmpty || url.isEmpty) return;
    if (_syncRunning) return;

    setState(() {
      _syncRunning = true;
      _syncStatusText =
          background ? 'Автосинхронизация...' : 'Синхронизация...';
    });

    try {
      final headers = <String, String>{'Accept': 'application/xml,text/xml'};
      final token = _xmlTokenController.text.trim();
      if (token.isNotEmpty) {
        headers['Authorization'] =
            token.startsWith('Bearer ') ? token : 'Bearer $token';
      }

      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final bodyBytes = response.bodyBytes;
      final xmlText = utf8.decode(bodyBytes, allowMalformed: true);
      final indicators = _buildIndicatorsFromXml(xmlText);

      final storagePath =
          'users/$userId/audit_1c/xml_sync/${DateTime.now().microsecondsSinceEpoch}.xml';
      String? fileUrl;
      try {
        fileUrl = await uploadData(storagePath, Uint8List.fromList(bodyBytes));
      } catch (_) {
        fileUrl = null;
      }

      await FirebaseFirestore.instance.collection('audit_1c_runs').add({
        'idCompany': companyId,
        'country_code': _companyCountryProfile.countryCode,
        'user_id': userId,
        'source': 'xml_1c_83_sync',
        'status': 'ready',
        'sync_mode': background ? 'auto' : 'manual',
        'xml_url': url,
        'file_name': '1c_report.xml',
        'file_ext': 'xml',
        'file_size_bytes': bodyBytes.length,
        'file_storage_path': fileUrl != null ? storagePath : null,
        'file_url': fileUrl,
        'indicators': indicators,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('audit_1c_sync_settings')
          .doc('${companyId}_xml')
          .set({
        'idCompany': companyId,
        'user_id': userId,
        'type': 'xml_1c_83',
        'xml_url': url,
        'xml_token': _xmlTokenController.text.trim(),
        'auto_enabled': _autoSyncEnabled,
        'interval_minutes': _syncIntervalMinutes,
        'last_sync_at': FieldValue.serverTimestamp(),
        'last_sync_ok': true,
        'last_status_text': 'Синхронизация успешна',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _syncStatusText = 'Синхронизация успешна');
      if (!background) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('XML синхронизация выполнена')),
        );
      }
      _loadLatestAuditStats();
    } catch (e) {
      final companyId2 = _effectiveCompanyId();
      if (companyId2.isNotEmpty && currentUserUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('audit_1c_sync_settings')
            .doc('${companyId2}_xml')
            .set({
          'last_sync_at': FieldValue.serverTimestamp(),
          'last_sync_ok': false,
          'last_status_text': 'Ошибка: $e',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      setState(() => _syncStatusText = 'Ошибка синхронизации: $e');
      if (!background) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка XML синхронизации: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final userData = currentUserDocument?.snapshotData ?? const {};
    final roleRaw = (userData['role'] ?? '').toString().toLowerCase().trim();
    final isCompanyAdmin = (userData['is_admin'] == true) ||
        (userData['admin'] == true) ||
        roleRaw == 'admin' ||
        roleRaw == 'owner' ||
        roleRaw == 'business_owner' ||
        roleRaw == 'владелец';
    final canOpenAudit = isCompanyAdmin || PermissionsHelper.has('audit.view');
    if (!canOpenAudit) {
      return Scaffold(
        body: SafeArea(
          child: PermissionsHelper.noAccess(),
        ),
      );
    }

    final critical = _count(AuditCriticality.critical);
    final high = _count(AuditCriticality.high);
    final control = _count(AuditCriticality.control);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: _pageBackground,
      drawer: Drawer(
        elevation: 16.0,
        child: const DrawersUsersWidget(),
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (responsiveVisibility(
              context: context,
              phone: false,
              tablet: false,
            ))
              Container(
                width: FFAppState().userSidebarCollapsed ? 88.0 : 270.0,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  border: Border.all(
                    color: _panelBorderSoft,
                    width: 1.0,
                  ),
                ),
                child: const DrawersUsersWidget(),
              ),
            Expanded(
              child: Align(
                alignment: const AlignmentDirectional(0.0, -1.0),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 1480.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _pageBackground,
                        _pageBackgroundSoft,
                        _pageBackgroundSoft,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (responsiveVisibility(
                            context: context,
                            tabletLandscape: false,
                            desktop: false,
                          ))
                            Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: InkWell(
                                onTap: () =>
                                    scaffoldKey.currentState?.openDrawer(),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.menu,
                                    color: FlutterFlowTheme.of(context).info,
                                  ),
                                ),
                              ),
                            ),
                          const Expanded(
                              child: HeaderWidget(
                                  title: 'Аудит бухгалтерского учета')),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _titleBlock(),
                              const SizedBox(height: 8),
                              _compactPanel(
                                id: 'overview',
                                title: 'Ошибки бух учета',
                                icon: Icons.insights_rounded,
                                accent: const Color(0xFFEA580C),
                                summary:
                                    'Статус достоверности, существенность и общее количество ошибок',
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isNarrow =
                                        constraints.maxWidth < 1050;
                                    if (isNarrow) {
                                      return Column(
                                        children: [
                                          _summaryBlock(
                                              critical, high, control),
                                          const SizedBox(height: 8),
                                          _sectionsBlock(),
                                        ],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: _summaryBlock(
                                              critical, high, control),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 7,
                                          child: _sectionsBlock(),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              KeyedSubtree(
                                key: _criticalityPanelKey,
                                child: _compactPanel(
                                  id: 'criticality',
                                  title: 'Ошибки бух учета: действия',
                                  icon: Icons.rule_rounded,
                                  accent: const Color(0xFFB42318),
                                  summary:
                                      'Рекомендации строками и раскрытие деталей по каждому правилу',
                                  child: _criticalityColumns(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleBlock() {
    final critical = _criticalErrors;
    final high = _substantialErrors;
    final control = _controlErrors;
    final total = critical + high + control;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_panelSurface, _panelSurfaceSoft],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D0F172A)
                .withValues(alpha: _isDarkTheme ? 0.22 : 0.05),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F0FF), Color(0xFFD9E7FF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Аудит бухгалтерского учета',
                  style: FlutterFlowTheme.of(context).titleLarge.override(
                        font: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _reliabilityStatusLabel,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(),
                        color: _mutedText,
                        letterSpacing: 0.0,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _pill(
                _reliabilityStatusLabel,
                _reliabilityStatusColor.withValues(alpha: 0.12),
                _reliabilityStatusColor,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  _pill(
                    'Критические ошибки: $critical',
                    const Color(0xFFFEE2E2),
                    const Color(0xFFB42318),
                  ),
                  _pill(
                    'Существенные ошибки: $high',
                    const Color(0xFFFFEDD5),
                    const Color(0xFFB45309),
                  ),
                  _pill(
                    'Всего ошибок: $total',
                    const Color(0xFFE8F0FF),
                    const Color(0xFF1D4ED8),
                  ),
                  _pill(
                    'Исправлено: $_fixedErrorsCount',
                    const Color(0xFFFEF3C7),
                    const Color(0xFFA16207),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _xmlSyncBlock() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelSurfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Модуль синхронизации XML (1С 8.3)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '1С 8.3 может отдавать отчет в XML по HTTP. Модуль выполняет ручную и авто-синхронизацию (по таймеру, пока открыт экран), парсит XML и сохраняет показатели в базу.',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _xmlUrlController,
            decoration: const InputDecoration(
              labelText: 'URL XML отчета 1С 8.3',
              hintText: 'https://.../report.xml',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _xmlTokenController,
            decoration: const InputDecoration(
              labelText: 'Токен / Authorization (необязательно)',
              hintText: 'Bearer ... или просто токен',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _syncIntervalMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Интервал автосинхронизации',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [1440, 10080, 43200]
                      .map(
                        (m) => DropdownMenuItem<int>(
                          value: m,
                          child: Text(
                            m == 1440
                                ? 'День'
                                : (m == 10080 ? 'Неделя' : 'Месяц'),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _syncIntervalMinutes = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Автосинхронизация',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Работает пока открыт раздел',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _autoSyncEnabled,
                  onChanged: (v) => setState(() => _autoSyncEnabled = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _syncSaving ? null : _saveXmlSyncSettings,
                icon: _syncSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label:
                    Text(_syncSaving ? 'Сохранение...' : 'Сохранить настройки'),
              ),
              OutlinedButton.icon(
                onPressed: _syncRunning ? null : () => _syncXmlNow(),
                icon: _syncRunning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_syncRunning
                    ? 'Синхронизация...'
                    : 'Синхронизировать сейчас'),
              ),
              _pill(
                _autoSyncEnabled
                    ? 'Авто: включено (${_syncIntervalMinutes == 1440 ? 'день' : (_syncIntervalMinutes == 10080 ? 'неделя' : 'месяц')})'
                    : 'Авто: выключено',
                _autoSyncEnabled
                    ? const Color(0xFFECFDF3)
                    : const Color(0xFFF3F4F6),
                _autoSyncEnabled
                    ? const Color(0xFF15803D)
                    : const Color(0xFF475467),
              ),
            ],
          ),
          if ((_syncStatusText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _syncStatusText!,
              style: TextStyle(
                fontSize: 12,
                color: (_syncStatusText ?? '').toLowerCase().contains('ошиб')
                    ? const Color(0xFFB42318)
                    : const Color(0xFF15803D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Важно: для веба 1С endpoint должен отдавать XML по HTTP/HTTPS и разрешать CORS.',
            style: TextStyle(fontSize: 11, color: _softText),
          ),
        ],
      ),
    );
  }

  Widget _uploadExpressCheckBlock() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelSurfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Загрузка файла Экспресс-проверка',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Пользователь загружает файл .xls/.xlsx. Формируются показатели (по матрице аудита + метаданным файла) и сохраняются в базу Firestore.',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed:
                    _uploadingExpressCheck ? null : _uploadExpressCheckFile,
                icon: _uploadingExpressCheck
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _uploadingExpressCheck
                      ? 'Загрузка...'
                      : 'Загрузить Экспресс-проверка',
                ),
              ),
              const SizedBox(width: 8),
              _pill(
                'База: audit_1c_runs',
                const Color(0xFFEFF6FF),
                const Color(0xFF1D4ED8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uploadsHistoryBlock() {
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _panelSurfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _panelBorder),
        ),
        child:
            const Text('История загрузок недоступна: не определена компания.'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelSurfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Последние загрузки Экспресс-проверка',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('audit_1c_runs')
                .where('idCompany', isEqualTo: companyId)
                .orderBy('created_at', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Ошибка чтения истории: ${snapshot.error}',
                  style: const TextStyle(color: Color(0xFFB42318)),
                );
              }
              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Text(
                  'Загрузок пока нет.',
                  style: TextStyle(color: _mutedText),
                );
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data();
                  final indicators = (data['indicators'] is Map)
                      ? Map<String, dynamic>.from(data['indicators'] as Map)
                      : const <String, dynamic>{};
                  final ts = data['created_at'];
                  final dt = ts is Timestamp ? ts.toDate() : null;
                  final fileName =
                      (data['file_name'] ?? 'Без имени').toString();
                  final status = (data['status'] ?? '—').toString();
                  final c = indicators['critical_count'] ?? 0;
                  final h = indicators['high_count'] ?? 0;
                  final k = indicators['control_count'] ?? 0;
                  final risk = indicators['weighted_risk_score'] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _panelSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _panelBorderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined,
                                size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                fileName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _pill(
                              status,
                              const Color(0xFFECFDF3),
                              const Color(0xFF15803D),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _pill('🔴 $c', const Color(0xFFFEE2E2),
                                const Color(0xFFB42318)),
                            _pill('🟠 $h', const Color(0xFFFFEDD5),
                                const Color(0xFFB45309)),
                            _pill('🟡 $k', const Color(0xFFFEF3C7),
                                const Color(0xFFA16207)),
                            _pill('Риск: $risk', const Color(0xFFE8F0FF),
                                const Color(0xFF1D4ED8)),
                          ],
                        ),
                        if (dt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Сохранено: ${DateFormat('dd.MM.yyyy HH:mm').format(dt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _mutedText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryBlock(int critical, int high, int control) {
    final total = critical + high + control;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0x080F172A)
                .withValues(alpha: _isDarkTheme ? 0.18 : 0.03),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ошибки бух учета',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Статус достоверности, общее количество и существенность ошибок',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _reliabilityStatusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _reliabilityStatusColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              _reliabilityStatusLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _reliabilityStatusColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _scrollToCriticality(
                    criticality: AuditCriticality.critical,
                  ),
                  child: _kpiCard(
                    'Критические ошибки',
                    '$critical',
                    const Color(0xFFFEE2E2),
                    const Color(0xFFB42318),
                    icon: Icons.priority_high_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _scrollToCriticality(
                    criticality: AuditCriticality.high,
                  ),
                  child: _kpiCard(
                    'Существенные ошибки',
                    '$high',
                    const Color(0xFFFFEDD5),
                    const Color(0xFFB45309),
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _scrollToCriticality(),
                  child: _kpiCard(
                    'Всего ошибок',
                    '$total',
                    const Color(0xFFE8F0FF),
                    const Color(0xFF1D4ED8),
                    icon: Icons.analytics_outlined,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                'Статус достоверности: ${_isAccountingReliable ? 'достоверный' : 'требует исправления'}',
                const Color(0xFFF3F4F6),
                const Color(0xFF374151),
              ),
              _pill(
                'Статус бух учета: существенность ${high > 0 ? 'есть' : 'нет'}',
                const Color(0xFFEFF6FF),
                const Color(0xFF1D4ED8),
              ),
              _pill(
                'Исправленные ошибки: $_fixedErrorsCount',
                const Color(0xFFECFDF3),
                const Color(0xFF15803D),
              ),
              _pill(
                'Контрольные: $control',
                const Color(0xFFFEE2E2),
                const Color(0xFFB42318),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionsBlock() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0x080F172A)
                .withValues(alpha: _isDarkTheme ? 0.18 : 0.03),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Графики по разделам аудита',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Сумма ошибок по разделам аудита: критические, существенные и контрольные',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
          const SizedBox(height: 10),
          ..._sections.map((section) {
            final c = section.count(AuditCriticality.critical);
            final h = section.count(AuditCriticality.high);
            final k = section.count(AuditCriticality.control);
            final sum = section.rules.length;
            final sectionId = '${section.key}_${section.title}';
            final expanded = _expandedSections.contains(sectionId);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _panelBorderSoft),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x06000000)
                        .withValues(alpha: _isDarkTheme ? 0.16 : 0.02),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        if (expanded) {
                          _expandedSections.remove(sectionId);
                        } else {
                          _expandedSections.add(sectionId);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${section.key}. ${section.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _miniStat('Σ', '$sum', const Color(0xFF374151)),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(Icons.expand_more, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _stackedBar(
                    segments: [
                      _BarSeg(
                        value: sum == 0 ? 0 : c / sum,
                        color: const Color(0xFFDC2626),
                      ),
                      _BarSeg(
                        value: sum == 0 ? 0 : h / sum,
                        color: const Color(0xFFD97706),
                      ),
                      _BarSeg(
                        value: sum == 0 ? 0 : k / sum,
                        color: const Color(0xFFCA8A04),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _miniStat('Крит.', '$c', const Color(0xFFDC2626)),
                      _miniStat('Сущ.', '$h', const Color(0xFFD97706)),
                      _miniStat('Контр.', '$k', const Color(0xFFCA8A04)),
                      _miniStat('Сумма', '$sum', const Color(0xFF2563EB)),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Структура ошибок по разделу',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _softText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _miniStat('Всего', '$sum', const Color(0xFF2563EB)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _barScale(),
                      ],
                    ),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 180),
                    sizeCurve: Curves.easeOutCubic,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _criticalityColumns() {
    final critical = _rulesBy(AuditCriticality.critical);
    final high = _rulesBy(AuditCriticality.high);
    final control = _rulesBy(AuditCriticality.control);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1120;
        if (isNarrow) {
          return Column(
            children: [
              _criticalityColumn(
                '🔴 Критическая',
                AuditCriticality.critical,
                critical,
                const Color(0xFFFEE2E2),
                const Color(0xFFB42318),
              ),
              const SizedBox(height: 10),
              _criticalityColumn(
                '🟠 Существенная',
                AuditCriticality.high,
                high,
                const Color(0xFFFFEDD5),
                const Color(0xFFB45309),
              ),
              const SizedBox(height: 10),
              _criticalityColumn(
                '🟡 Контрольная',
                AuditCriticality.control,
                control,
                const Color(0xFFFEF3C7),
                const Color(0xFFA16207),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _criticalityColumn(
                '🔴 Критическая',
                AuditCriticality.critical,
                critical,
                const Color(0xFFFEE2E2),
                const Color(0xFFB42318),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _criticalityColumn(
                '🟠 Существенная',
                AuditCriticality.high,
                high,
                const Color(0xFFFFEDD5),
                const Color(0xFFB45309),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _criticalityColumn(
                '🟡 Контрольная',
                AuditCriticality.control,
                control,
                const Color(0xFFFEF3C7),
                const Color(0xFFA16207),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _criticalityColumn(
    String title,
    AuditCriticality criticality,
    List<_AuditRule> rules,
    Color bg,
    Color fg,
  ) {
    final blockRecommendations = _blockRecommendations(criticality);
    final expanded = _expandedCriticalityBlocks.contains(criticality);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0x090F172A)
                .withValues(alpha: _isDarkTheme ? 0.2 : 0.04),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedCriticalityBlocks.remove(criticality);
                } else {
                  _expandedCriticalityBlocks.add(criticality);
                }
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
                _pill('${rules.length}', bg, fg),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more, size: 18, color: fg),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  bg.withValues(alpha: 0.42),
                  bg.withValues(alpha: 0.20),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bg.withValues(alpha: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Рекомендации и действия',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Column(
                  children: blockRecommendations
                      .take(expanded ? blockRecommendations.length : 2)
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  r,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          if (!expanded)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Разверните блок для просмотра действий по каждому правилу',
                style: TextStyle(
                  fontSize: 11,
                  color: _mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: rules.map(
                  (rule) {
                    final recommendation = _actionRecommendation(rule);
                    final owner = _recommendedOwner(rule);
                    final due = _recommendedDue(criticality);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            bg.withValues(alpha: 0.48),
                            _panelSurface,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: bg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                rule.code,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: fg,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _pill(
                                due,
                                Colors.white.withValues(alpha: 0.75),
                                fg,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rule.name,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _actionLine('Решение', recommendation, fg),
                          const SizedBox(height: 3),
                          _actionLine('Ответственный', owner, fg),
                          const SizedBox(height: 3),
                          _actionLine(
                            'Срок',
                            due.replaceFirst('Срок: ', ''),
                            fg,
                          ),
                        ],
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _compactPanel({
    required String id,
    required String title,
    required IconData icon,
    required Color accent,
    required String summary,
    required Widget child,
  }) {
    final expanded = _expandedPanels.contains(id);
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A0F172A)
                .withValues(alpha: _isDarkTheme ? 0.2 : 0.04),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedPanels.remove(id);
                } else {
                  _expandedPanels.add(id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.16),
                          accent.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          summary,
                          maxLines: expanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _mutedText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more, color: accent),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: child,
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  List<String> _blockRecommendations(AuditCriticality criticality) {
    switch (criticality) {
      case AuditCriticality.critical:
        return const [
          'Исправлять в первую очередь до новых операций и закрытия периода.',
          'Назначить ответственного и дедлайн в день обнаружения.',
          'После исправления выполнить повторную синхронизацию XML и контрольный прогон.',
        ];
      case AuditCriticality.high:
        return const [
          'Закрыть в ближайший операционный цикл (1-3 дня).',
          'Проверить влияние на налоги, ДДС и отчетность до сдачи периода.',
          'Согласовать корректировки с главным бухгалтером.',
        ];
      case AuditCriticality.control:
        return const [
          'Поставить в план профилактики и чистки базы.',
          'Исправлять пакетно по регламенту (еженедельно/ежемесячно).',
          'Фиксировать результат повторной проверкой после изменений.',
        ];
    }
  }

  String _recommendedDue(AuditCriticality criticality) {
    switch (criticality) {
      case AuditCriticality.critical:
        return 'Срок: день';
      case AuditCriticality.high:
        return 'Срок: неделя';
      case AuditCriticality.control:
        return 'Срок: месяц';
    }
  }

  String _recommendedOwner(_AuditRule rule) {
    final code = rule.code;
    if (code.startsWith('B') || code.startsWith('C'))
      return 'Кассир / Бухгалтер';
    if (code.startsWith('D')) return 'ЗП бухгалтер';
    if (code.startsWith('E')) return 'НДС бухгалтер';
    if (code.startsWith('H')) return 'Бухгалтер ОС';
    if (code.startsWith('J')) return 'Главбух / Финконтроль';
    return 'Бухгалтер';
  }

  String _actionRecommendation(_AuditRule rule) {
    final text = rule.name.toLowerCase();
    if (text.contains('отрицатель')) {
      return 'Найти источник минусового остатка, перепровести документы и сверить регистры.';
    }
    if (text.contains('ндс') || text.contains('эсф')) {
      return 'Сверить документы, регистрационные данные и порядок регистрации ЭСФ/НДС.';
    }
    if (text.contains('касс') || text.contains('пко') || text.contains('рко')) {
      return 'Проверить кассовые документы, нумерацию и лимиты, затем перепровести.';
    }
    if (text.contains('зарплат') ||
        text.contains('ипн') ||
        text.contains('опв')) {
      return 'Проверить начисления, удержания и регистры ЗП; пересчитать проблемный период.';
    }
    if (text.contains('ддс') || text.contains('статьи ддс')) {
      return 'Заполнить/исправить статью ДДС и тип потока, затем перепровести документы.';
    }
    if (text.contains('дубли')) {
      return 'Проверить дубли, объединить/пометить лишние элементы и обновить ссылки в документах.';
    }
    if (text.contains('удаление')) {
      return 'Провести ревизию помеченных объектов и удалить только подтвержденные элементы.';
    }
    if (text.contains('учетной политики')) {
      return 'Заполнить и утвердить учетную политику в базе и проверить применение настроек.';
    }
    if (text.contains('прошлых периодов')) {
      return 'Проверить изменения по пользователям, согласовать и зафиксировать корректировку.';
    }
    if (text.contains('закрытия месяца')) {
      return 'Выполнить закрытие месяца, устранить ошибки закрытия и повторить контроль.';
    }
    if (text.contains('договор')) {
      return 'Проверить наличие и реквизиты договора, привязать документ-основание.';
    }
    return 'Проверить первичный документ/регистр, устранить причину и выполнить повторный контроль.';
  }

  Widget _actionLine(String label, String value, Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionThreeColumns({
    required String recommendation,
    required String owner,
    required String due,
    required Color accent,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 280;
        if (isNarrow) {
          return Column(
            children: [
              _miniActionCell(
                title: 'Действие',
                value: recommendation,
                bg: Colors.white.withValues(alpha: 0.72),
                border: accent.withValues(alpha: 0.16),
                fg: accent,
              ),
              const SizedBox(height: 4),
              _miniActionCell(
                title: 'Ответственный',
                value: owner,
                bg: Colors.white.withValues(alpha: 0.72),
                border: accent.withValues(alpha: 0.16),
                fg: accent,
              ),
              const SizedBox(height: 4),
              _miniActionCell(
                title: 'Срок',
                value: due.replaceFirst('Срок: ', ''),
                bg: Colors.white.withValues(alpha: 0.72),
                border: accent.withValues(alpha: 0.16),
                fg: accent,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _miniActionCell(
                title: 'Действие',
                value: recommendation,
                bg: Colors.white.withValues(alpha: 0.72),
                border: accent.withValues(alpha: 0.16),
                fg: accent,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 3,
              child: _miniActionCell(
                title: 'Ответственный',
                value: owner,
                bg: Colors.white.withValues(alpha: 0.72),
                border: accent.withValues(alpha: 0.16),
                fg: accent,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _miniActionCell(
                title: 'Срок',
                value: due.replaceFirst('Срок: ', ''),
                bg: Colors.white.withValues(alpha: 0.72),
                border: accent.withValues(alpha: 0.16),
                fg: accent,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _miniActionCell({
    required String title,
    required String value,
    required Color bg,
    required Color border,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9.5,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    Color bg,
    Color fg, {
    required IconData icon,
    String? percentLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    if ((percentLabel ?? '').isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          percentLabel!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stackedBar({required List<_BarSeg> segments}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 16,
        decoration: BoxDecoration(
          color: _isDarkTheme
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFF3F4F6),
          border: Border.all(color: _panelBorderSoft),
        ),
        child: Row(
          children: [
            for (final seg in segments)
              if (seg.value > 0)
                Expanded(
                  flex: math.max(1, (seg.value * 1000).round()),
                  child: Container(color: seg.color),
                ),
          ],
        ),
      ),
    );
  }

  Widget _criticalityLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _LegendChip(
          label: 'Критическая',
          color: Color(0xFFDC2626),
          bg: Color(0xFFFEE2E2),
        ),
        _LegendChip(
          label: 'Существенная',
          color: Color(0xFFD97706),
          bg: Color(0xFFFFEDD5),
        ),
        _LegendChip(
          label: 'Контрольная',
          color: Color(0xFFCA8A04),
          bg: Color(0xFFFEF3C7),
        ),
      ],
    );
  }

  Widget _barScale() {
    return Row(
      children: [
        for (final label in const ['0%', '25%', '50%', '75%', '100%'])
          Expanded(
            child: Text(
              label,
              textAlign: label == '0%'
                  ? TextAlign.left
                  : label == '100%'
                      ? TextAlign.right
                      : TextAlign.center,
              style: TextStyle(fontSize: 10, color: _softText),
            ),
          ),
      ],
    );
  }

  Widget _ratioRow(String label, double ratio, Color color) {
    final percent = (ratio * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio.clamp(0, 1),
            backgroundColor: _isDarkTheme
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF3F4F6),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _miniInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: _softText)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

enum AuditCriticality { critical, high, control }

class _AuditRule {
  final String code;
  final String name;
  final AuditCriticality criticality;

  const _AuditRule({
    required this.code,
    required this.name,
    required this.criticality,
  });
}

class _AuditSection {
  final String key;
  final String title;
  final List<_AuditRule> rules;

  const _AuditSection({
    required this.key,
    required this.title,
    required this.rules,
  });

  int count(AuditCriticality criticality) =>
      rules.where((r) => r.criticality == criticality).length;
}

class _BarSeg {
  final double value;
  final Color color;

  const _BarSeg({required this.value, required this.color});
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _LegendChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
