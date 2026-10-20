// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/utils/app_money_format.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/business_event_support.dart';
import '/utils/accounting_tax_service.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/expense_plan_analytics_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/pnl_report_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class AnalyticsFinReportWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const AnalyticsFinReportWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<AnalyticsFinReportWidget> createState() =>
      _AnalyticsFinReportWidgetState();
}

class _AnalyticsFinReportWidgetState extends State<AnalyticsFinReportWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<AccountingEntryRecord> _entries = [];
  List<Map<String, dynamic>> _cogsItems = [];
  List<Map<String, dynamic>> _expensePlans = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _businessEvents = [];
  LedgerScope _ledgerFilter = LedgerScope.management;
  double _ndsRate = 16;
  double _kpnRate = 20;
  String _currencyCode = 'KZT';
  String _vatLabel = 'НДС';
  String _profitTaxLabel = 'КПН';
  String _viewMode = 'table';
  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDarkTheme ? const Color(0xFF111722) : const Color(0xFFF7F8FA);
  Color get _panelSurface => _isDarkTheme
      ? Color.alphaBlend(
          Colors.white.withValues(alpha: 0.03),
          FlutterFlowTheme.of(context).secondaryBackground,
        )
      : FlutterFlowTheme.of(context).secondaryBackground;
  Color get _panelBorder => _isDarkTheme
      ? FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.42)
      : FlutterFlowTheme.of(context).alternate;
  Color get _mutedText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.72)
      : FlutterFlowTheme.of(context).secondaryText;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<String> _queryCompanyIds() {
    final user = _auth.currentUser;
    return resolveQueryCompanyIds(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user?.uid ?? '',
    );
  }

  Future<List<Map<String, dynamic>>> _loadCompanyScopedDocs(
    String collectionName, {
    int? limitPerQuery,
  }) async {
    final companyIds = _queryCompanyIds();
    if (companyIds.isEmpty) return const <Map<String, dynamic>>[];
    final docsById = <String, Map<String, dynamic>>{};
    final futures = splitCompanyIdsForWhereIn(companyIds).map((chunk) {
      Query<Map<String, dynamic>> query = _firestore.collection(collectionName);
      if (chunk.length == 1) {
        query = query.where('idCompany', isEqualTo: chunk.first);
      } else {
        query = query.where('idCompany', whereIn: chunk);
      }
      if (limitPerQuery != null) {
        query = query.limit(limitPerQuery);
      }
      return query.getCached();
    }).toList();
    final snapshots = await Future.wait(futures);
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        final data = doc.data();
        docsById[doc.id] = <String, dynamic>{
          'id': doc.id,
          ...(data is Map<String, dynamic>
              ? data
              : data is Map
                  ? Map<String, dynamic>.from(data)
                  : const <String, dynamic>{}),
        };
      }
    }
    return docsById.values.toList();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _entries = const [];
        });
        return;
      }
      final results = await Future.wait([
        _loadCompanyScopedDocs('accounting_entries'),
        _loadCompanyScopedDocs('cogs_register'),
        _loadCompanyScopedDocs('sale_item_cogs'),
        _loadCompanyScopedDocs('expense_plans', limitPerQuery: 1000),
        _loadCompanyScopedDocs('tranzaction', limitPerQuery: 3000),
        _loadCompanyScopedDocs('business_events', limitPerQuery: 4000),
        _loadCompanyScopedDocs('company_profile'),
      ]);

      setState(() {
        _entries = List<Map<String, dynamic>>.from(results[0])
            .map(
              (data) => AccountingEntryRecord.getDocumentFromData(
                data,
                FirebaseFirestore.instance
                    .collection('accounting_entries')
                    .doc((data['id'] ?? '').toString()),
              ),
            )
            .toList();
        _cogsItems = resolvePnlCogsItems(
          cogsEntries: List<Map<String, dynamic>>.from(results[1]),
          legacyCogsItems: List<Map<String, dynamic>>.from(results[2]),
        );
        _expensePlans = List<Map<String, dynamic>>.from(results[3]);
        _transactions = List<Map<String, dynamic>>.from(results[4]);
        _businessEvents = List<Map<String, dynamic>>.from(results[5]);
        final profiles = List<Map<String, dynamic>>.from(results[6]);
        final profile = _resolveScopedProfile(profiles);
        final countryProfile = countryProfileFromData(profile);
        final rates = _resolveTaxRates(profile);
        _ndsRate = rates.$1;
        _kpnRate = rates.$2;
        _currencyCode = companyCurrencyFromProfileData(profile);
        _vatLabel = countryProfile.vatLabel;
        _profitTaxLabel = countryProfile.profitTaxLabel;
      });
    } catch (e) {
      debugPrint('Error loading finance report: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _resolveScopedProfile(
    List<Map<String, dynamic>> profiles,
  ) {
    final companyIds = _queryCompanyIds().toSet();
    final scoped = profiles
        .where((profile) => companyIds.contains(
              (profile['idCompany'] ?? profile['id'] ?? '').toString(),
            ))
        .toList(growable: false);
    return scoped.isNotEmpty
        ? scoped.first
        : profiles.isNotEmpty
            ? profiles.first
            : const <String, dynamic>{};
  }

  (double, double) _resolveTaxRates(Map<String, dynamic> profile) {
    return (
      _rateFrom(profile['nds_rate'], 16),
      _rateFrom(profile['kpn_rate'], 20),
    );
  }

  double _rateFrom(dynamic value, double fallback) {
    if (value == null) return fallback;
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return fallback;
    return parsed <= 1 ? parsed : parsed;
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Map<String, _MonthlyPlanFact> get _budgetPlanFactByMonth {
    final monthKeys = <String>{};
    for (final doc in _expensePlans) {
      final key = expensePlanString(doc['period_key']);
      if (key.isNotEmpty) monthKeys.add(key);
    }
    for (final doc in _transactions) {
      final date = expensePlanDate(doc['date']) ??
          expensePlanDate(doc['created_at']) ??
          expensePlanDate(doc['updated_at']);
      if (date != null) {
        monthKeys.add(periodKeyForDate(date));
      }
    }
    for (final doc in _businessEvents) {
      final date = expensePlanDate(doc['occurred_at']) ??
          expensePlanDate(doc['created_at']) ??
          expensePlanDate(doc['updated_at']);
      if (date != null) {
        monthKeys.add(periodKeyForDate(date));
      }
    }

    final useEvents = _businessEvents.any(
      (event) =>
          businessEventTypeFromValue((event['event_type'] ?? '').toString()) ==
          BusinessEventType.expenseRecorded,
    );
    final rowsByMonth = <String, _MonthlyPlanFact>{};
    final eventExpenseDocs = _businessEvents
        .where((doc) =>
            businessEventTypeFromValue((doc['event_type'] ?? '').toString()) ==
            BusinessEventType.expenseRecorded)
        .map((doc) => <String, dynamic>{
              ...doc,
              'category_name': expensePlanString(doc['category_name']).isEmpty
                  ? expensePlanString(doc['notes'])
                  : expensePlanString(doc['category_name']),
              'amount': expensePlanNum(doc['cost']),
              'date': doc['occurred_at'] ?? doc['created_at'],
            })
        .toList(growable: false);

    for (final key in monthKeys) {
      final rows = buildExpensePlanFactRows(
        planDocs: _expensePlans,
        expenseDocs: useEvents ? eventExpenseDocs : _transactions,
        periodKey: key,
        ledgerScope: _ledgerFilter == LedgerScope.both ? null : _ledgerFilter,
      );
      rowsByMonth[key] = _MonthlyPlanFact(
        planned: rows.fold<double>(0, (sum, row) => sum + row.plannedAmount),
        actual: rows.fold<double>(0, (sum, row) => sum + row.actualAmount),
      );
    }
    return rowsByMonth;
  }

  List<_FinMonthRow> get _monthlyRows {
    final map = <String, _FinMonthRow>{};
    for (final entry in _filteredEntries) {
      final dt = entry.entryDate ?? entry.createdAt ?? entry.updatedAt;
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(
        key,
        () => _FinMonthRow(monthKey: key, monthLabel: _monthLabel(dt)),
      );
    }
    for (final item in _cogsItems) {
      if (!_ledgerFilter.matches(
        ledgerScopeFromLegacyValue(
          (item['ledger_scope'] ?? item['ledgerScope']).toString(),
        ),
      )) {
        continue;
      }
      final dt = item['created_at'] ?? item['date'] ?? item['updated_at'];
      if (dt is! DateTime) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(
        key,
        () => _FinMonthRow(monthKey: key, monthLabel: _monthLabel(dt)),
      );
    }
    for (final row in map.values) {
      final monthDate = DateTime.parse('${row.monthKey}-01');
      final pnl = computePnlReport(
        entries: _filteredEntries,
        cogsItems: _cogsItems,
        ledgerScope: _ledgerFilter,
        inPeriod: (date) =>
            date != null &&
            date.year == monthDate.year &&
            date.month == monthDate.month,
      );
      final tax = computeTaxSnapshotForScope(
        sources: _filteredEntries,
        ledgerScope: _ledgerFilter,
        income: pnl.revenue,
        expense: pnl.opex,
        ndsRate: _ndsRate,
        kpnRate: _kpnRate,
        inPeriod: (date) =>
            date != null &&
            date.year == monthDate.year &&
            date.month == monthDate.month,
      );
      final planFact = _budgetPlanFactByMonth[row.monthKey];
      row.revenue = pnl.revenue;
      row.cogs = pnl.cogs;
      row.grossProfit = pnl.grossProfit;
      row.opex = pnl.opex;
      row.netProfit = pnl.revenue - pnl.opex - tax.ndsPayable - tax.kpnPayable;
      row.plan = planFact?.planned ?? 0;
      row.fact = planFact?.actual ?? 0;
    }
    final rows = map.values.toList();
    rows.sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return rows;
  }

  List<AccountingEntryRecord> get _filteredEntries {
    if (_ledgerFilter == LedgerScope.both) return _entries;
    return _entries
        .where((entry) => _ledgerFilter.matches(
              ledgerScopeFromLegacyValue(entry.ledgerScope),
            ))
        .toList();
  }

  PnlReport get _pnl => computePnlReport(
        entries: _filteredEntries,
        cogsItems: _cogsItems,
        ledgerScope: _ledgerFilter,
      );
  AccountingTaxSnapshot get _taxSnapshot => computeTaxSnapshotForScope(
        sources: _filteredEntries,
        ledgerScope: _ledgerFilter,
        income: _pnl.revenue,
        expense: _pnl.opex,
        ndsRate: _ndsRate,
        kpnRate: _kpnRate,
      );
  double get _netProfitValue =>
      _pnl.revenue -
      _pnl.opex -
      _taxSnapshot.ndsPayable -
      _taxSnapshot.kpnPayable;

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('analytics.fin')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: _pageBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.balance_outlined,
                      color: Color(0xFF16A34A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Финансовый отчёт',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Доходы, расходы и прибыль компании',
                        style: TextStyle(
                          fontSize: 13,
                          color: _mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Управленческий (С)'),
                  selected: _ledgerFilter == LedgerScope.management,
                  selectedColor: const Color(0xFFE0E7FF),
                  onSelected: (_) =>
                      setState(() => _ledgerFilter = LedgerScope.management),
                ),
                ChoiceChip(
                  label: const Text('Бухгалтерский'),
                  selected: _ledgerFilter == LedgerScope.accounting,
                  selectedColor: const Color(0xFFFFEDD5),
                  onSelected: (_) =>
                      setState(() => _ledgerFilter = LedgerScope.accounting),
                ),
                ChoiceChip(
                  label: const Text('Общий'),
                  selected: _ledgerFilter == LedgerScope.both,
                  selectedColor: const Color(0xFFE5E7EB),
                  onSelected: (_) =>
                      setState(() => _ledgerFilter = LedgerScope.both),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: _statCard(
                    title: 'Revenue',
                    value: _formatMoney(_pnl.revenue),
                    icon: Icons.trending_up,
                    iconBg: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.14),
                    iconColor: FlutterFlowTheme.of(context).success,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _statCard(
                    title: 'COGS',
                    value: _formatMoney(_pnl.cogs),
                    icon: Icons.inventory_2_outlined,
                    iconBg: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.14),
                    iconColor: FlutterFlowTheme.of(context).warning,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _statCard(
                    title: 'Gross Profit',
                    value: _formatMoney(_pnl.grossProfit),
                    icon: Icons.show_chart,
                    iconBg: FlutterFlowTheme.of(context).accent1,
                    iconColor: FlutterFlowTheme.of(context).primary,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _statCard(
                    title: 'OPEX',
                    value: _formatMoney(_pnl.opex),
                    icon: Icons.trending_down,
                    iconBg: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.14),
                    iconColor: FlutterFlowTheme.of(context).warning,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _statCard(
                    title: 'Net Profit',
                    value: _formatMoney(_netProfitValue),
                    icon: Icons.account_balance_wallet_outlined,
                    iconBg: FlutterFlowTheme.of(context).accent1,
                    iconColor: FlutterFlowTheme.of(context).primary,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _statCard(
                    title: '$_vatLabel к оплате',
                    value: _formatMoney(_taxSnapshot.ndsPayable),
                    icon: Icons.receipt_long,
                    iconBg: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.14),
                    iconColor: FlutterFlowTheme.of(context).warning,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _statCard(
                    title: _profitTaxLabel,
                    value: _formatMoney(_taxSnapshot.kpnPayable),
                    icon: Icons.account_balance,
                    iconBg: FlutterFlowTheme.of(context)
                        .primary
                        .withValues(alpha: 0.14),
                    iconColor: FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _panelSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_netProfitValue < 0)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFB91C1C)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Неоправданный риск',
                                    style: TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Text(
                          'Финансы по месяцам',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
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
                          selected: {_viewMode},
                          onSelectionChanged: (value) {
                            if (value.isEmpty) return;
                            setState(() => _viewMode = value.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _monthlyRows.isEmpty
                              ? Center(
                                  child: Text(
                                    'Данные не найдены',
                                    style: TextStyle(color: _mutedText),
                                  ),
                                )
                              : _viewMode == 'chart'
                                  ? ListView(
                                      children: [
                                        _buildCombinedChart(),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _tableHeader(),
                                        const Divider(height: 1),
                                        Expanded(
                                          child: ListView(
                                            children: _monthlyRows
                                                .map(_tableRow)
                                                .toList(),
                                          ),
                                        ),
                                      ],
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

  Widget _tableHeader() {
    return const Row(
      children: [
        _HeaderCell('Месяц', flex: 3),
        _HeaderCell('Доходы', flex: 2),
        _HeaderCell('Расходы', flex: 2),
        _HeaderCell('Чистая прибыль', flex: 2),
        _HeaderCell('План', flex: 2),
        _HeaderCell('Факт', flex: 2),
      ],
    );
  }

  Widget _buildCombinedChart() {
    final rows = _monthlyRows.length > 12
        ? _monthlyRows.sublist(_monthlyRows.length - 12)
        : _monthlyRows;
    if (rows.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Недостаточно данных для графика',
          style: TextStyle(color: _mutedText),
        ),
      );
    }

    final series = <_ChartSeries>[
      _ChartSeries('Доходы', const Color(0xFF16A34A),
          rows.map((e) => e.revenue).toList()),
      _ChartSeries(
          'Расходы', const Color(0xFFDC2626), rows.map((e) => e.opex).toList()),
      _ChartSeries(
        'Чистая прибыль',
        const Color(0xFF2563EB),
        rows.map((e) => e.netProfit).toList(),
      ),
      _ChartSeries(
          'План', const Color(0xFFB45309), rows.map((e) => e.plan).toList()),
      _ChartSeries(
          'Факт', const Color(0xFF7C3AED), rows.map((e) => e.fact).toList()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: CustomPaint(
            painter: _FinanceSeriesChartPainter(
              series: series,
              gridColor: _panelBorder.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in series) _legendChip(item.name, item.color),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: rows
              .map((row) => Text(
                    row.monthLabel,
                    style: TextStyle(fontSize: 11, color: _mutedText),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _legendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tableRow(_FinMonthRow row) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: FlutterFlowTheme.of(context)
                    .alternate
                    .withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          _Cell(row.monthLabel, flex: 3, bold: true),
          _Cell(_formatMoney(row.revenue), flex: 2, amount: row.revenue),
          _Cell(_formatMoney(row.opex), flex: 2, amount: -row.opex),
          _Cell(_formatMoney(row.netProfit), flex: 2, amount: row.netProfit),
          _Cell(_formatMoney(row.plan), flex: 2, amount: row.plan),
          _Cell(_formatMoney(row.fact), flex: 2, amount: row.fact),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: _mutedText)),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );
  }
}

class _FinMonthRow {
  final String monthKey;
  final String monthLabel;
  double revenue = 0;
  double cogs = 0;
  double grossProfit = 0;
  double opex = 0;
  double netProfit = 0;
  double plan = 0;
  double fact = 0;

  _FinMonthRow({
    required this.monthKey,
    required this.monthLabel,
  });
}

class _MonthlyPlanFact {
  const _MonthlyPlanFact({
    required this.planned,
    required this.actual,
  });

  final double planned;
  final double actual;
}

class _ChartSeries {
  const _ChartSeries(this.name, this.color, this.values);

  final String name;
  final Color color;
  final List<double> values;
}

class _FinanceSeriesChartPainter extends CustomPainter {
  const _FinanceSeriesChartPainter({
    required this.series,
    required this.gridColor,
  });

  final List<_ChartSeries> series;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.values.isEmpty) return;
    const leftPadding = 8.0;
    const topPadding = 8.0;
    const bottomPadding = 12.0;
    final chartWidth = size.width - leftPadding * 2;
    final chartHeight = size.height - topPadding - bottomPadding;
    final pointsCount = series.first.values.length;
    final allValues = series.expand((item) => item.values).toList();
    final maxValue = allValues.fold<double>(0, (max, value) {
      final absolute = value.abs();
      return absolute > max ? absolute : max;
    });
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final yFor = (double value) =>
        topPadding +
        chartHeight -
        ((value + safeMax) / (safeMax * 2)) * chartHeight;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = topPadding + chartHeight * (index / 3);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );
    }

    for (final item in series) {
      final path = Path();
      for (var index = 0; index < item.values.length; index++) {
        final dx = pointsCount == 1
            ? leftPadding + chartWidth / 2
            : leftPadding + chartWidth * (index / (pointsCount - 1));
        final dy = yFor(item.values[index]);
        if (index == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FinanceSeriesChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.gridColor != gridColor;
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: FlutterFlowTheme.of(context).secondaryText,
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final num? amount;

  const _Cell(this.text, {required this.flex, this.bold = false, this.amount});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment:
            amount == null ? Alignment.centerLeft : Alignment.centerRight,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: amount == null ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            color: amountTextColor(
              context,
              amount,
              positiveColor: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
        ),
      ),
    );
  }
}
