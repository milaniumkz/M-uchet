import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/custom_code/widgets/permissions_helper.dart';
import '/utils/accounting_accounts.dart';
import '/utils/accounting_tax_service.dart';
import '/utils/app_money_format.dart';
import '/utils/country_profile.dart';
import '/utils/country_tax_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_flow_type.dart';
import '/utils/owner_investment_support.dart';
import '/utils/pnl_report_service.dart';
import '/money/audit_1c/audit_1c_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'uchet_model.dart';
export 'uchet_model.dart';

class UchetWidget extends StatefulWidget {
  const UchetWidget({super.key});

  static String routeName = 'uchet';
  static String routePath = '/uchet';

  @override
  State<UchetWidget> createState() => _UchetWidgetState();
}

class _UchetWidgetState extends State<UchetWidget>
    with TickerProviderStateMixin {
  late UchetModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _warnedCompanyLimit = false;
  int? _selectedYear;
  int? _selectedMonth;
  DateTime? _selectedDay;
  DateTimeRange? _selectedRange;
  String _periodMode = 'year';
  String _financialViewMode = 'table';
  List<int> _availableYears = [];
  final Set<String> _expandedCards = {};
  Future<_UchetScreenData>? _screenDataFuture;
  String _screenDataKey = '';
  String _reportCurrencyCode = 'KZT';

  String _effectiveCompanyId() {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: currentUserUid,
    );
  }

  List<String> _companyIdsForQuery() {
    return resolveQueryCompanyIds(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: currentUserUid,
    );
  }

  Query _applyCompanyFilter(Query query) {
    final ids = _companyIdsForQuery();
    if (ids.isEmpty) {
      return query.where('idCompany', isEqualTo: '__none__');
    }
    if (ids.length == 1) {
      return query.where('idCompany', isEqualTo: ids.first);
    }
    if (ids.length > 10 && !_warnedCompanyLimit) {
      _warnedCompanyLimit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Слишком много компаний для режима "Все". Показаны первые 10.'),
          ),
        );
      });
    }
    final limited = ids.length > 10 ? ids.take(10).toList() : ids;
    return query.where('idCompany', whereIn: limited);
  }

  Query<Map<String, dynamic>> _applyCompanyFilterMap(
    Query<Map<String, dynamic>> query,
  ) {
    return _applyCompanyFilter(query) as Query<Map<String, dynamic>>;
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _safeDocGet(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get(const GetOptions(source: Source.serverAndCache));
    } catch (error) {
      if (_isPermissionDenied(error)) {
        return null;
      }
      rethrow;
    }
  }

  Future<QuerySnapshot?> _safeQueryGet(
    Query query, {
    String? key,
  }) async {
    try {
      return await query.get(
        const GetOptions(source: Source.serverAndCache),
      );
    } catch (error) {
      if (_isPermissionDenied(error)) {
        return null;
      }
      rethrow;
    }
  }

  Future<_UchetScreenData> _loadUchetScreenData({
    required bool isAllCompanies,
    required String companyId,
  }) async {
    final targetCompanyIds = isAllCompanies
        ? _companyIdsForQuery()
        : <String>[if (companyId.isNotEmpty) companyId];
    for (final scopedCompanyId in targetCompanyIds) {
      await ensureOwnerInvestmentsNormalizedForCompany(
        firestore: FirebaseFirestore.instance,
        companyId: scopedCompanyId,
      );
    }

    final profileFuture = companyId.isEmpty
        ? Future.value(null)
        : _safeDocGet(
            FirebaseFirestore.instance
                .collection('company_profile')
                .doc(companyId),
          );

    final entryQuery = isAllCompanies
        ? _applyCompanyFilter(AccountingEntryRecord.collection)
        : AccountingEntryRecord.collection
            .where('idCompany', isEqualTo: companyId);
    final cogsRegisterQuery = isAllCompanies
        ? _applyCompanyFilterMap(
            FirebaseFirestore.instance
                .collection('cogs_register')
                .withConverter<Map<String, dynamic>>(
                  fromFirestore: (snapshot, _) =>
                      snapshot.data() ?? const <String, dynamic>{},
                  toFirestore: (value, _) => value,
                ),
          )
        : FirebaseFirestore.instance
            .collection('cogs_register')
            .where('idCompany', isEqualTo: companyId);
    final legacyCogsQuery = isAllCompanies
        ? _applyCompanyFilterMap(
            FirebaseFirestore.instance
                .collection('sale_item_cogs')
                .withConverter<Map<String, dynamic>>(
                  fromFirestore: (snapshot, _) =>
                      snapshot.data() ?? const <String, dynamic>{},
                  toFirestore: (value, _) => value,
                ),
          )
        : FirebaseFirestore.instance
            .collection('sale_item_cogs')
            .where('idCompany', isEqualTo: companyId);

    final results = await Future.wait<dynamic>([
      profileFuture,
      _safeQueryGet(
        entryQuery,
        key:
            'uchet/accounting_entries/${isAllCompanies ? _companyIdsForQuery().join(",") : companyId}',
      ),
      _safeQueryGet(
        cogsRegisterQuery,
        key:
            'uchet/cogs_register/${isAllCompanies ? _companyIdsForQuery().join(",") : companyId}',
      ),
      _safeQueryGet(
        legacyCogsQuery,
        key:
            'uchet/sale_item_cogs/${isAllCompanies ? _companyIdsForQuery().join(",") : companyId}',
      ),
    ]);

    final profileSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>?;
    final entriesSnap = results[1] as QuerySnapshot?;
    final cogsRegisterSnap = results[2] as QuerySnapshot?;
    final legacyCogsSnap = results[3] as QuerySnapshot?;

    final profileData = profileSnap?.data() ?? const <String, dynamic>{};

    final countryProfile = countryProfileFromData(profileData);
    final companyCurrency = companyCurrencyFromProfileData(
      profileData,
      fallback: countryProfile.baseCurrency,
    );
    _reportCurrencyCode = companyCurrency;
    final taxProfile = taxProfileForCountry(
      countryCode: countryProfile.countryCode,
      date: _effectiveTaxDate(),
    );
    double ndsRate = taxProfile.vatRate;
    double kpnRate = taxProfile.profitTaxRate;
    final rawNds = profileData['nds_rate'];
    final rawKpn = profileData['kpn_rate'];
    ndsRate = normalizeTaxRate(rawNds, taxProfile.vatRate);
    kpnRate = normalizeTaxRate(rawKpn, taxProfile.profitTaxRate);

    final entries = <dynamic>[];
    for (final doc in entriesSnap?.docs ?? const []) {
      try {
        entries.add(AccountingEntryRecord.fromSnapshot(doc));
      } catch (_) {
        final raw = doc.data();
        if (raw is Map<String, dynamic>) {
          entries.add(Map<String, dynamic>.from(raw));
        } else if (raw is Map) {
          entries.add(Map<String, dynamic>.from(raw));
        }
      }
    }
    final fallbackCogsItems = resolvePnlCogsItems(
      cogsEntries: cogsRegisterSnap?.docs
              .map((doc) => Map<String, dynamic>.from(doc.data() as Map))
              .toList(growable: false) ??
          const <Map<String, dynamic>>[],
      legacyCogsItems: legacyCogsSnap?.docs
              .map((doc) => Map<String, dynamic>.from(doc.data() as Map))
              .toList(growable: false) ??
          const <Map<String, dynamic>>[],
    );

    return _UchetScreenData(
      entries: entries,
      cogsItems: fallbackCogsItems,
      ndsRate: ndsRate,
      kpnRate: kpnRate,
      currencyCode: companyCurrency,
      vatLabel: countryProfile.vatLabel,
      profitTaxLabel: countryProfile.profitTaxLabel,
    );
  }

  DateTime? _entryLikeDate(dynamic entry) {
    if (entry is AccountingEntryRecord) {
      return entry.entryDate ?? entry.createdAt ?? entry.updatedAt;
    }
    if (entry is Map<String, dynamic>) {
      final value =
          entry['entry_date'] ?? entry['created_at'] ?? entry['updated_at'];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UchetModel());

    _model.tabBarController1 = TabController(
      vsync: this,
      length: 3,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    _model.expandableExpandableController =
        ExpandableController(initialExpanded: false);
    _model.osnExpandableController1 =
        ExpandableController(initialExpanded: true);
    _model.nalogExpandableController1 =
        ExpandableController(initialExpanded: false);
    _model.osnExpandableController2 =
        ExpandableController(initialExpanded: false);
    _model.nalogExpandableController2 =
        ExpandableController(initialExpanded: false);
    _model.tabBarController2 = TabController(
      vsync: this,
      length: 3,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String _formatMoney(num? value, {String? currencyCode}) {
    final code = currencyCode ?? _reportCurrencyCode;
    return formatMoneyWithCurrency(
      value,
      currencyCode: code,
    );
  }

  DateTime _effectiveTaxDate() {
    switch (_periodMode) {
      case 'day':
        return _selectedDay ?? DateTime.now();
      case 'month':
        final year = _selectedYear ?? DateTime.now().year;
        final month = _selectedMonth ?? DateTime.now().month;
        return DateTime(year, month + 1, 0);
      case 'range':
        return _selectedRange?.end ?? DateTime.now();
      case 'year':
      default:
        final year = _selectedYear ?? DateTime.now().year;
        return DateTime(year, 12, 31);
    }
  }

  bool _inSelectedPeriod(DateTime? date) {
    if (date == null) return false;
    switch (_periodMode) {
      case 'day':
        final day = _selectedDay;
        if (day == null) return true;
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      case 'month':
        final year = _selectedYear;
        final month = _selectedMonth;
        if (year == null || month == null) return true;
        return date.year == year && date.month == month;
      case 'range':
        final range = _selectedRange;
        if (range == null) return true;
        final start =
            DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(
            range.end.year, range.end.month, range.end.day, 23, 59, 59);
        return date.isAfter(start.subtract(Duration(seconds: 1))) &&
            date.isBefore(end.add(Duration(seconds: 1)));
      case 'year':
      default:
        if (_selectedYear == null) return true;
        return date.year == _selectedYear;
    }
  }

  Widget _buildPeriodSelector() {
    final periodItems = const [
      DropdownMenuItem(value: 'year', child: Text('Год')),
      DropdownMenuItem(value: 'month', child: Text('Месяц')),
      DropdownMenuItem(value: 'day', child: Text('День')),
      DropdownMenuItem(value: 'range', child: Text('Период')),
    ];

    Widget buildYearDropdown() {
      return SizedBox(
        width: 120.0,
        child: DropdownButtonFormField<int>(
          initialValue: _selectedYear ??
              (_availableYears.isNotEmpty ? _availableYears.first : null),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          hint: Text('Год'),
          items: _availableYears
              .map(
                (y) => DropdownMenuItem(
                  value: y,
                  child: Text('$y'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedYear = value);
          },
        ),
      );
    }

    Widget buildMonthDropdown() {
      final months = List<int>.generate(12, (i) => i + 1);
      return SizedBox(
        width: 120.0,
        child: DropdownButtonFormField<int>(
          initialValue: _selectedMonth,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          hint: Text('Месяц'),
          items: months
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text('$m'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedMonth = value);
          },
        ),
      );
    }

    Widget buildDayButton() {
      final label = _selectedDay == null
          ? 'Выбрать день'
          : dateTimeFormat('yMd', _selectedDay,
              locale: FFLocalizations.of(context).languageCode);
      return SizedBox(
        width: 150.0,
        child: OutlinedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDay ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(DateTime.now().year + 1),
            );
            if (picked != null) {
              setState(() => _selectedDay = picked);
            }
          },
          child: Text(label),
        ),
      );
    }

    Widget buildRangeButton() {
      final label = _selectedRange == null
          ? 'Выбрать период'
          : '${dateTimeFormat('yMd', _selectedRange!.start, locale: FFLocalizations.of(context).languageCode)} - ${dateTimeFormat('yMd', _selectedRange!.end, locale: FFLocalizations.of(context).languageCode)}';
      return SizedBox(
        width: 200.0,
        child: OutlinedButton(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(DateTime.now().year + 1),
              initialDateRange: _selectedRange,
            );
            if (picked != null) {
              setState(() => _selectedRange = picked);
            }
          },
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 120.0,
          child: DropdownButtonFormField<String>(
            initialValue: _periodMode,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            items: periodItems,
            onChanged: (val) {
              if (val == null) return;
              setState(() => _periodMode = val);
            },
          ),
        ),
        if (_periodMode == 'year') buildYearDropdown(),
        if (_periodMode == 'month') ...[
          buildYearDropdown(),
          buildMonthDropdown(),
        ],
        if (_periodMode == 'day') buildDayButton(),
        if (_periodMode == 'range') buildRangeButton(),
      ],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
        ),
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required String title,
    required Color color,
    bool bold = false,
    bool underline = false,
    Widget? trailing,
  }) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.interTight(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    ),
                    color: color,
                    decoration: underline
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    letterSpacing: 0.0,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleMedium.fontStyle,
                  ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _auditReliabilityBadge() {
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('audit_1c_runs')
          .where('idCompany', isEqualTo: companyId)
          .orderBy('created_at', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final data = docs.first.data();
        final indicators = (data['indicators'] is Map)
            ? Map<String, dynamic>.from(data['indicators'] as Map)
            : const <String, dynamic>{};
        final critical = (indicators['critical_count'] as num?)?.toInt() ?? 0;
        final high = (indicators['high_count'] as num?)?.toInt() ?? 0;
        final unreliable = critical > 0 || high > 0;
        if (!unreliable) return const SizedBox.shrink();
        return Tooltip(
          message:
              'Бухучет недостоверный. Есть критические/существенные ошибки. Нажмите для перехода в аудит.',
          child: InkWell(
            onTap: () => context.pushNamed(Audit1CWidget.routeName),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.priority_high_rounded,
                size: 14,
                color: FlutterFlowTheme.of(context).secondaryBackground,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionWrapper({
    required Color background,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 16.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color borderColor,
    required Color fillColor,
    required Color accent,
    required VoidCallback? onTap,
    required Color valueColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minWidth: 200.0),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
              ),
              SizedBox(height: 6.0),
              Text(
                value,
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleMedium.fontStyle,
                      ),
                      color: valueColor,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w700,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    ),
              ),
              SizedBox(height: 6.0),
              Text(
                subtitle,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUchetBody(BuildContext context) {
    final canSummary = PermissionsHelper.has('uchet.blocks.summary');
    if (!canSummary) {
      return const SizedBox.shrink();
    }
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final scopeRaw = currentUserDocument?.snapshotData['companyScope'] ??
        currentUserDocument?.snapshotData['company_scope'];
    final isAllCompanies = (scopeRaw ?? 'single').toString() == 'all' ||
        _companyIdsForQuery().length > 1;
    final companyId = _effectiveCompanyId();
    final requestKey =
        '${isAllCompanies ? "all" : "single"}|${_companyIdsForQuery().join(",")}|$companyId';
    if (_screenDataFuture == null || _screenDataKey != requestKey) {
      _screenDataKey = requestKey;
      _screenDataFuture = _loadUchetScreenData(
        isAllCompanies: isAllCompanies,
        companyId: companyId,
      );
    }

    Widget buildCol({
      required Widget header,
      required Widget body,
      required Color background,
    }) {
      return Container(
        margin: isMobile ? EdgeInsets.only(bottom: 16.0) : EdgeInsets.zero,
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            body,
          ],
        ),
      );
    }

    return FutureBuilder<_UchetScreenData>(
      future: _screenDataFuture,
      builder: (context, screenSnap) {
        if (screenSnap.hasError) {
          return _sectionWrapper(
            background: const Color(0xFFFFF7ED),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Не удалось загрузить финансовый учет',
                  style: FlutterFlowTheme.of(context).titleMedium,
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${screenSnap.error}',
                  style: FlutterFlowTheme.of(context).bodySmall,
                ),
                const SizedBox(height: 12.0),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _screenDataFuture = null;
                      _screenDataKey = '';
                    });
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        if (!screenSnap.hasData) {
          return Center(
            child: SizedBox(
              width: 50.0,
              height: 50.0,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).primary,
                ),
              ),
            ),
          );
        }

        final screenData = screenSnap.data!;
        final entries = screenData.entries;
        final cogsItems = screenData.cogsItems;
        final ndsRate = screenData.ndsRate;
        final kpnRate = screenData.kpnRate;
        final pnlUp = computePnlReport(
          entries: entries,
          cogsItems: cogsItems,
          ledgerScope: LedgerScope.both,
          inPeriod: _inSelectedPeriod,
        );
        final pnlUp1 = computePnlReport(
          entries: entries,
          cogsItems: cogsItems,
          ledgerScope: LedgerScope.management,
          inPeriod: _inSelectedPeriod,
        );
        final pnlBu = computePnlReport(
          entries: entries,
          cogsItems: cogsItems,
          ledgerScope: LedgerScope.accounting,
          inPeriod: _inSelectedPeriod,
        );

        final taxUp = computeTaxSnapshotForScope(
          sources: entries,
          ledgerScope: LedgerScope.both,
          income: pnlUp.revenue,
          expense: pnlUp.opex,
          ndsRate: ndsRate,
          kpnRate: kpnRate,
          inPeriod: _inSelectedPeriod,
        );
        final taxUp1 = computeTaxSnapshotForScope(
          sources: entries,
          ledgerScope: LedgerScope.management,
          income: pnlUp1.revenue,
          expense: pnlUp1.opex,
          ndsRate: ndsRate,
          kpnRate: kpnRate,
          inPeriod: _inSelectedPeriod,
        );
        final taxBu = computeTaxSnapshotForScope(
          sources: entries,
          ledgerScope: LedgerScope.accounting,
          income: pnlBu.revenue,
          expense: pnlBu.opex,
          ndsRate: ndsRate,
          kpnRate: kpnRate,
          inPeriod: _inSelectedPeriod,
        );

        final availableYears = <int>{
          ...entries
              .map(_entryLikeDate)
              .whereType<DateTime>()
              .map((date) => date.year),
          ...cogsItems
              .map((item) =>
                  item['created_at'] ?? item['date'] ?? item['updated_at'])
              .whereType<DateTime>()
              .map((date) => date.year),
        }.toList()
          ..sort((a, b) => b.compareTo(a));

        if (_selectedYear == null && availableYears.isNotEmpty) {
          _selectedYear = availableYears.first;
        }
        if (_selectedYear != null &&
            availableYears.isNotEmpty &&
            !availableYears.contains(_selectedYear)) {
          _selectedYear = availableYears.first;
        }
        if (_selectedMonth == null && _selectedYear != null) {
          _selectedMonth = DateTime.now().month;
        }

        final cols = <Widget>[
          buildCol(
            header: _sectionHeader(
              title: 'Общий учет',
              color: const Color(0xFF111827),
              bold: true,
              underline: true,
              trailing: _auditReliabilityBadge(),
            ),
            body: _sectionWrapper(
              background: const Color(0xFFEFF6FF),
              child: _buildLedgerTab(
                title: 'Общий учет',
                revenue: pnlUp.revenue,
                cogs: pnlUp.cogs,
                grossProfit: pnlUp.grossProfit,
                opex: pnlUp.opex,
                netProfit: pnlUp.netProfit,
                ndsAccrued: taxUp.ndsAccrued,
                ndsPayable: taxUp.ndsPayable,
                kpnAccrued: taxUp.kpnAccrued,
                kpnPayable: taxUp.kpnPayable,
                totalTaxes: taxUp.ndsPayable + taxUp.kpnPayable,
                revenueBreakdown: pnlUp.revenueBreakdown,
                opexBreakdown: pnlUp.opexBreakdown,
                entries: entries,
                ledgerScope: LedgerScope.both,
                expansionKeyPrefix: 'up',
                vatLabel: screenData.vatLabel,
                profitTaxLabel: screenData.profitTaxLabel,
              ),
            ),
            background: const Color(0xFFF8FAFC),
          ),
          buildCol(
            header: _sectionHeader(
              title: 'Упр. учет (С)',
              color: const Color(0xFF6B7280),
              trailing: _auditReliabilityBadge(),
            ),
            body: _sectionWrapper(
              background: const Color(0xFFF3F4F6),
              child: _buildLedgerTab(
                title: 'Упр. учет (С)',
                revenue: pnlUp1.revenue,
                cogs: pnlUp1.cogs,
                grossProfit: pnlUp1.grossProfit,
                opex: pnlUp1.opex,
                netProfit: pnlUp1.netProfit,
                ndsAccrued: taxUp1.ndsAccrued,
                ndsPayable: taxUp1.ndsPayable,
                kpnAccrued: taxUp1.kpnAccrued,
                kpnPayable: taxUp1.kpnPayable,
                totalTaxes: taxUp1.ndsPayable + taxUp1.kpnPayable,
                revenueBreakdown: pnlUp1.revenueBreakdown,
                opexBreakdown: pnlUp1.opexBreakdown,
                entries: entries,
                ledgerScope: LedgerScope.management,
                expansionKeyPrefix: 'up1',
                vatLabel: screenData.vatLabel,
                profitTaxLabel: screenData.profitTaxLabel,
              ),
            ),
            background: const Color(0xFFF3F4F6),
          ),
        ];

        cols.add(
          buildCol(
            header: _sectionHeader(
              title: 'Бухгалтерский учет',
              color: const Color(0xFF111827),
              bold: true,
              underline: true,
              trailing: _auditReliabilityBadge(),
            ),
            body: _sectionWrapper(
              background: const Color(0xFFFFFBEB),
              child: _buildLedgerTab(
                title: 'Бухгалтерский учет',
                revenue: pnlBu.revenue,
                cogs: pnlBu.cogs,
                grossProfit: pnlBu.grossProfit,
                opex: pnlBu.opex,
                netProfit: pnlBu.netProfit,
                ndsAccrued: taxBu.ndsAccrued,
                ndsPayable: taxBu.ndsPayable,
                kpnAccrued: taxBu.kpnAccrued,
                kpnPayable: taxBu.kpnPayable,
                totalTaxes: taxBu.ndsPayable + taxBu.kpnPayable,
                revenueBreakdown: pnlBu.revenueBreakdown,
                opexBreakdown: pnlBu.opexBreakdown,
                entries: entries,
                ledgerScope: LedgerScope.accounting,
                expansionKeyPrefix: 'bu',
                vatLabel: screenData.vatLabel,
                profitTaxLabel: screenData.profitTaxLabel,
              ),
            ),
            background: const Color(0xFFFFFBEB),
          ),
        );

        if (_availableYears.length != availableYears.length ||
            !_availableYears.every((y) => availableYears.contains(y))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _availableYears = List<int>.from(availableYears);
              });
            }
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final useRow = !isMobile && constraints.maxWidth >= 900;
            final columnSpacing = useRow ? 12.0 : 0.0;
            final content = useRow
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cols[0]),
                      SizedBox(width: columnSpacing),
                      Expanded(child: cols[1]),
                      SizedBox(width: columnSpacing),
                      Expanded(child: cols[2]),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cols,
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content],
            );
          },
        );
      },
    );
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (_expandedCards.contains(key)) {
        _expandedCards.remove(key);
      } else {
        _expandedCards.add(key);
      }
    });
  }

  bool _isExpanded(String key) => _expandedCards.contains(key);

  Widget _detailsList(Map<String, double> items) {
    final filtered = items.entries.where((e) => e.value != 0).toList();
    final rows = filtered.isEmpty ? items.entries.toList() : filtered;
    return Container(
      margin: EdgeInsets.only(top: 8.0),
      padding: EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows.map((e) {
          return Padding(
            padding: EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    e.key,
                    style: FlutterFlowTheme.of(context).bodySmall,
                  ),
                ),
                SizedBox(width: 12.0),
                Text(
                  _formatMoney(e.value),
                  style: FlutterFlowTheme.of(context).bodySmall,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Map<String, dynamic> _entryMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  String _entryDebitAccountId(dynamic entry) {
    if (entry is AccountingEntryRecord) return entry.debitAccountId;
    return (_entryMap(entry)['debit_account_id'] ?? '').toString();
  }

  String _entryDebitAccountTitle(dynamic entry) {
    if (entry is AccountingEntryRecord) return entry.debitAccountTitle;
    return (_entryMap(entry)['debit_account_title'] ?? '').toString();
  }

  String _entryDescription(dynamic entry) {
    if (entry is AccountingEntryRecord) return entry.description;
    return (_entryMap(entry)['description'] ?? '').toString();
  }

  String _entryMemo(dynamic entry) {
    if (entry is AccountingEntryRecord) return entry.memo;
    return (_entryMap(entry)['memo'] ?? '').toString();
  }

  double _entryAmountValue(dynamic entry) {
    if (entry is AccountingEntryRecord) return entry.amount;
    final raw = _entryMap(entry)['amount'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _expenseDriverLabel(dynamic entry) {
    final debitTitle = _entryDebitAccountTitle(entry).trim();
    final description = _entryDescription(entry).trim();
    final memo = _entryMemo(entry).trim();
    final normalized = debitTitle.toLowerCase();

    if (_isLegacyOperatingPayableExpense(entry)) {
      if (description.isNotEmpty) return description;
      if (memo.isNotEmpty) return memo;
      return 'Обязательства';
    }

    if (debitTitle.isNotEmpty &&
        normalized != 'decome' &&
        normalized != 'expense' &&
        normalized != 'income' &&
        normalized != 'rashod') {
      return debitTitle;
    }

    if (description.isNotEmpty) return description;
    if (memo.isNotEmpty) return memo;
    return 'Прочие расходы';
  }

  bool _isLegacyOperatingPayableExpense(dynamic entry) {
    final debitId = _entryDebitAccountId(entry);
    final debitTitle = _entryDebitAccountTitle(entry).trim().toLowerCase();
    final isPayableDebit = debitId.startsWith('virtual:liability:payable:') ||
        debitTitle == 'кредиторка' ||
        debitTitle == 'кредиторская задолженность';
    if (!isPayableDebit) return false;
    final combined = [
      _entryDescription(entry),
      _entryMemo(entry),
    ].join(' ').toLowerCase();
    const financingMarkers = [
      'займ',
      'кредит',
      'капитал',
      'вклад',
      'собствен',
      'loan',
      'credit',
      'capital',
    ];
    return !financingMarkers.any(combined.contains);
  }

  Map<String, double> _expenseDriversFromEntries({
    required Iterable<dynamic> entries,
    required LedgerScope ledgerScope,
  }) {
    final result = <String, double>{};
    for (final entry in entries) {
      if (!_inSelectedPeriod(_entryLikeDate(entry))) continue;
      final entryScope = entry is AccountingEntryRecord
          ? entry.ledgerScopeEnum
          : ledgerScopeFromLegacyValue(
              (_entryMap(entry)['ledger_scope'] ??
                      _entryMap(entry)['ledgerScope'] ??
                      '')
                  .toString(),
            );
      if (!ledgerScope.matches(entryScope)) continue;
      final flowType = entry is AccountingEntryRecord
          ? entry.moneyFlowTypeEnum
          : inferMoneyFlowType(
              explicitValue:
                  (entry['money_flow_type'] ?? entry['moneyFlowType'])
                      ?.toString(),
              transactionType: entry['type']?.toString(),
              category: entry['kat']?.toString(),
              description:
                  entry['description']?.toString() ?? entry['text']?.toString(),
              obligationId: entry['obligationId']?.toString(),
            );
      final isLegacyOperatingPayableExpense =
          _isLegacyOperatingPayableExpense(entry);
      if (flowType == MoneyFlowType.investing ||
          flowType == MoneyFlowType.transfer ||
          (flowType == MoneyFlowType.financing &&
              !isLegacyOperatingPayableExpense)) {
        continue;
      }
      if (accountNatureForId(_entryDebitAccountId(entry)) !=
              AccountNature.expense &&
          !isLegacyOperatingPayableExpense) {
        continue;
      }
      final amount = _entryAmountValue(entry);
      if (amount <= 0) continue;
      final label = _expenseDriverLabel(entry);
      result[label] = (result[label] ?? 0) + amount;
    }
    return result;
  }

  Widget _buildLedgerTab({
    required String title,
    required double revenue,
    required double cogs,
    required double grossProfit,
    required double opex,
    required double netProfit,
    required double ndsAccrued,
    required double ndsPayable,
    required double kpnAccrued,
    required double kpnPayable,
    required double totalTaxes,
    required Map<String, double> revenueBreakdown,
    required Map<String, double> opexBreakdown,
    required Iterable<dynamic> entries,
    required LedgerScope ledgerScope,
    required String expansionKeyPrefix,
    required String vatLabel,
    required String profitTaxLabel,
  }) {
    final canSummary = PermissionsHelper.has('uchet.blocks.summary');
    final canInsights = PermissionsHelper.has('uchet.blocks.insights');
    if (!canSummary) {
      return const SizedBox.shrink();
    }
    final totalExpense = cogs + opex;
    final netAfterTax = netProfit - ndsPayable - kpnPayable;
    final detailedExpenseDrivers = _expenseDriversFromEntries(
      entries: entries,
      ledgerScope: ledgerScope,
    );
    final negativeDrivers = <String, double>{
      if (cogs != 0) 'Себестоимость продаж': cogs,
      ...(detailedExpenseDrivers.isNotEmpty
          ? detailedExpenseDrivers
          : opexBreakdown),
      if (ndsPayable != 0) '$vatLabel к оплате': ndsPayable,
      if (kpnPayable != 0) '$profitTaxLabel к оплате': kpnPayable,
    };
    final sortedNegativeDrivers = Map<String, double>.fromEntries(
      negativeDrivers.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final cardSpacing = isNarrow ? 0.0 : 12.0;
        final cardsPerRow = isNarrow ? 1 : 4;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final computedCardWidth = isNarrow
            ? double.infinity
            : ((availableWidth - (cardSpacing * (cardsPerRow - 1))) /
                    cardsPerRow)
                .clamp(150.0, 175.0)
                .toDouble();
        final cardWidth = computedCardWidth;
        final chartItems = <_LedgerChartItem>[
          _LedgerChartItem(
            label: 'Доход',
            value: revenue,
            color: const Color(0xFF16A34A),
          ),
          _LedgerChartItem(
            label: 'Расход',
            value: totalExpense,
            color: const Color(0xFFB45309),
          ),
          _LedgerChartItem(
            label: 'Налог',
            value: totalTaxes,
            color: const Color(0xFF2563EB),
          ),
          _LedgerChartItem(
            label: 'Чистая прибыль',
            value: netAfterTax,
            color: netAfterTax >= 0
                ? const Color(0xFF0F766E)
                : const Color(0xFFDC2626),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'table',
                    label: Text('Таблица'),
                    icon: Icon(Icons.table_chart_outlined, size: 18),
                  ),
                  ButtonSegment<String>(
                    value: 'chart',
                    label: Text('График'),
                    icon: Icon(Icons.show_chart, size: 18),
                  ),
                ],
                selected: {_financialViewMode},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  setState(() => _financialViewMode = value.first);
                },
              ),
            ),
            const SizedBox(height: 16.0),
            if (_financialViewMode == 'chart')
              _buildLedgerChart(chartItems)
            else
              Wrap(
                spacing: cardSpacing,
                runSpacing: 16.0,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summaryCard(
                          title: 'Доход',
                          value: _formatMoney(revenue),
                          subtitle: 'Поступления периода',
                          borderColor: Color(0xFF7AE3A8),
                          fillColor: Color(0xFFE9F9F0),
                          accent: Color(0xFF16A34A),
                          valueColor: Color(0xFF16A34A),
                          onTap: () =>
                              _toggleExpanded('${expansionKeyPrefix}_income'),
                        ),
                        if (canInsights &&
                            _isExpanded('${expansionKeyPrefix}_income'))
                          _detailsList(revenueBreakdown),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summaryCard(
                          title: 'Расход',
                          value: _formatMoney(totalExpense),
                          subtitle: 'Себестоимость и операционные',
                          borderColor: Color(0xFFFAD7A0),
                          fillColor: Color(0xFFFFF7E6),
                          accent: Color(0xFFB45309),
                          valueColor: Color(0xFFB45309),
                          onTap: () =>
                              _toggleExpanded('${expansionKeyPrefix}_expense'),
                        ),
                        if (canInsights &&
                            _isExpanded('${expansionKeyPrefix}_expense'))
                          _detailsList({
                            'Себестоимость продаж': cogs,
                            ...opexBreakdown,
                          }),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summaryCard(
                          title: 'Налог',
                          value: _formatMoney(totalTaxes),
                          subtitle: '$vatLabel и $profitTaxLabel',
                          borderColor: Color(0xFFD6E5FF),
                          fillColor: Color(0xFFF0F5FF),
                          accent: Color(0xFF2563EB),
                          valueColor: Color(0xFF2563EB),
                          onTap: () =>
                              _toggleExpanded('${expansionKeyPrefix}_tax'),
                        ),
                        if (canInsights &&
                            _isExpanded('${expansionKeyPrefix}_tax'))
                          _detailsList({
                            '$vatLabel начислено': ndsAccrued,
                            '$vatLabel к оплате': ndsPayable,
                            '$profitTaxLabel начислено': kpnAccrued,
                            '$profitTaxLabel к оплате': kpnPayable,
                          }),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summaryCard(
                          title: 'Чистая прибыль',
                          value: _formatMoney(netAfterTax),
                          subtitle: 'После расходов и налогов',
                          borderColor: Color(0xFFE5E7EB),
                          fillColor: Color(0xFFF7F7F7),
                          accent: Color(0xFF111827),
                          valueColor: netAfterTax >= 0
                              ? Color(0xFF16A34A)
                              : Color(0xFFDC2626),
                          onTap: () =>
                              _toggleExpanded('${expansionKeyPrefix}_net'),
                        ),
                        if (canInsights &&
                            _isExpanded('${expansionKeyPrefix}_net'))
                          _detailsList({
                            'Доход': revenue,
                            'Расход': totalExpense,
                            'Налог': totalTaxes,
                            'Чистая прибыль': netAfterTax,
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            if (netAfterTax <= 0) ...[
              SizedBox(height: 12.0),
              InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: () => _toggleExpanded('${expansionKeyPrefix}_warning'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 10.0),
                      const Expanded(
                        child: Text(
                          'Обратите внимание',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      Icon(
                        _isExpanded('${expansionKeyPrefix}_warning')
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFFB45309),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isExpanded('${expansionKeyPrefix}_warning'))
                _detailsList(sortedNegativeDrivers),
            ],
            SizedBox(height: 20.0),
          ],
        );
      },
    );
  }

  Widget _buildLedgerChart(List<_LedgerChartItem> items) {
    final maxValue = items.fold<double>(
      1,
      (max, item) => item.value.abs() > max ? item.value.abs() : max,
    );
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.map((item) {
          final ratio = maxValue <= 0 ? 0.0 : item.value.abs() / maxValue;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Text(
                          _formatMoney(item.value),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: item.value >= 0
                                ? FlutterFlowTheme.of(context).primaryText
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Stack(
                      children: [
                        Container(
                          height: 18.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(999.0),
                          ),
                        ),
                        Container(
                          width: (width * ratio).clamp(18.0, width),
                          height: 18.0,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(999.0),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: PopScope(
        canPop: false,
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          drawer: Drawer(
            elevation: 16.0,
            child: wrapWithModel(
              model: _model.drawersUsersModel1,
              updateCallback: () => safeSetState(() {}),
              child: DrawersUsersWidget(),
            ),
          ),
          body: SafeArea(
            top: true,
            child: AuthUserStreamWidget(
              builder: (context) {
                final canView = PermissionsHelper.has('uchet.view');
                return canView
                    ? Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (responsiveVisibility(
                            context: context,
                            phone: false,
                            tablet: false,
                          ))
                            Container(
                              width: FFAppState().userSidebarCollapsed
                                  ? 88.0
                                  : 270.0,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(0.0),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                              ),
                              child: wrapWithModel(
                                model: _model.drawersUsersModel2,
                                updateCallback: () => safeSetState(() {}),
                                child: DrawersUsersWidget(),
                              ),
                            ),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional(0.0, -1.0),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          if (responsiveVisibility(
                                            context: context,
                                            tabletLandscape: false,
                                            desktop: false,
                                          ))
                                            Column(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.all(5.0),
                                                  child: FlutterFlowIconButton(
                                                    borderRadius: 8.0,
                                                    buttonSize: 40.0,
                                                    fillColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    icon: Icon(
                                                      Icons.menu,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .info,
                                                      size: 24.0,
                                                    ),
                                                    onPressed: () async {
                                                      scaffoldKey.currentState!
                                                          .openDrawer();
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                wrapWithModel(
                                                  model: _model.headerModel,
                                                  updateCallback: () =>
                                                      safeSetState(() {}),
                                                  child: HeaderWidget(
                                                    title:
                                                        'Финансовый учет компании',
                                                    trailing:
                                                        _buildPeriodSelector(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                            16.0, 12.0, 16.0, 24.0),
                                        child: AuthUserStreamWidget(
                                          builder: (context) =>
                                              _buildUchetBody(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(child: PermissionsHelper.noAccess());
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _UchetScreenData {
  const _UchetScreenData({
    required this.entries,
    required this.cogsItems,
    required this.ndsRate,
    required this.kpnRate,
    required this.currencyCode,
    required this.vatLabel,
    required this.profitTaxLabel,
  });

  final List<dynamic> entries;
  final Iterable<Map<String, dynamic>> cogsItems;
  final double ndsRate;
  final double kpnRate;
  final String currencyCode;
  final String vatLabel;
  final String profitTaxLabel;
}

class _LedgerChartItem {
  const _LedgerChartItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}
