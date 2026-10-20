import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/effective_company_support.dart';
import '/utils/app_money_format.dart';
import '/utils/balance_sheet_service.dart';
import '/utils/debt_aging_service.dart';
import '/utils/debt_payment_history_support.dart';
import '/utils/debt_register_support.dart';
import '/utils/debt_register_report_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/pnl_report_service.dart';
import '/utils/report_export_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '/custom_code/widgets/permissions_helper.dart';
import 'balance_model.dart';
import '/money/tranzaction/tranzaction_journal_widget.dart';
export 'balance_model.dart';

class BalanceWidget extends StatefulWidget {
  const BalanceWidget({super.key});

  static String routeName = 'balance';
  static String routePath = '/balance';

  @override
  State<BalanceWidget> createState() => _BalanceWidgetState();
}

class _BalanceRow {
  final String label;
  final double? value;
  final bool isTotal;
  final List<_BalanceRow> children;
  final String filterCategory;
  final String? manualKey;
  final bool allowManualInput;

  const _BalanceRow(
    this.label, {
    this.value,
    this.isTotal = false,
    this.children = const [],
    String? filterCategory,
    this.manualKey,
    this.allowManualInput = false,
  }) : filterCategory = filterCategory ?? label;
}

class _BalanceSection {
  final String title;
  final List<_BalanceRow> rows;

  const _BalanceSection({
    required this.title,
    required this.rows,
  });
}

class _BalanceGroup {
  final String title;
  final double? total;
  final List<_BalanceSection> sections;
  final List<_BalanceRow> footerRows;

  const _BalanceGroup({
    required this.title,
    this.total,
    this.sections = const [],
    this.footerRows = const [],
  });
}

class _BalanceSummaryMetric {
  const _BalanceSummaryMetric({
    required this.label,
    required this.value,
    this.highlight = false,
    this.warning = false,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final double value;
  final bool highlight;
  final bool warning;
  final bool selected;
  final VoidCallback? onTap;
}

enum _DebtRegisterIssueFilter {
  overdue,
  limitExceeded,
  ar90Plus,
}

class _BalanceWidgetState extends State<BalanceWidget> {
  late BalanceModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  String _period = 'year';
  int? _selectedYear;
  int? _selectedMonth;
  List<int> _availableYears = [];
  bool _warnedCompanyLimit = false;
  DebtType? _debtTypeFilter;
  _DebtRegisterIssueFilter? _debtIssueFilter;
  final Map<String, double> _manualOverrides = <String, double>{};
  String _balanceCurrencyCode = 'KZT';
  String _balanceCurrencyCompanyId = '';

  static const Map<int, String> _monthNames = {
    1: 'Январь',
    2: 'Февраль',
    3: 'Март',
    4: 'Апрель',
    5: 'Май',
    6: 'Июнь',
    7: 'Июль',
    8: 'Август',
    9: 'Сентябрь',
    10: 'Октябрь',
    11: 'Ноябрь',
    12: 'Декабрь',
  };

  Color get _positiveColor => Color(0xFF047857);

  Color get _negativeColor => Color(0xFFB91C1C);

  Color get _neutralColor =>
      FlutterFlowTheme.of(context).bodySmall.color ??
      FlutterFlowTheme.of(context).primaryText;

  void _setDebtFilters({
    DebtType? type,
    _DebtRegisterIssueFilter? issue,
  }) {
    setState(() {
      _debtTypeFilter = type;
      _debtIssueFilter = issue;
    });
  }

  List<DebtRegisterRow> _applyDebtIssueFilter(
    List<DebtRegisterRow> rows, {
    required DateTime asOf,
    _DebtRegisterIssueFilter? issue,
  }) {
    switch (issue ?? _debtIssueFilter) {
      case _DebtRegisterIssueFilter.overdue:
        return rows
            .where((row) => row.dueDate != null && !row.dueDate!.isAfter(asOf))
            .toList();
      case _DebtRegisterIssueFilter.limitExceeded:
        return rows.where((row) => row.isCreditLimitExceeded).toList();
      case _DebtRegisterIssueFilter.ar90Plus:
        return rows
            .where((row) => row.type == DebtType.ar && row.agingDays >= 90)
            .toList();
      case null:
        return rows;
    }
  }

  List<DebtRecordView> _filterDebtViewsForIssue(
    List<DebtRecordView> debts, {
    required DateTime asOf,
    DebtType? type,
    _DebtRegisterIssueFilter? issue,
  }) {
    final filteredRows = _applyDebtIssueFilter(
      buildDebtRegisterRows(
        debts: debts,
        asOf: asOf,
        ledgerScope: LedgerScope.accounting,
        type: type,
      ),
      asOf: asOf,
      issue: issue,
    );
    final debtIds = filteredRows.map((row) => row.id).toSet();
    return debts.where((debt) => debtIds.contains(debt.id)).toList();
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(
      value,
      currencyCode: _balanceCurrencyCode,
    );
  }

  void _ensureBalanceCurrencyLoaded() {
    final companyId = _manualBalanceCompanyId();
    if (companyId.isEmpty || companyId == _balanceCurrencyCompanyId) return;
    _balanceCurrencyCompanyId = companyId;
    unawaited(_loadBalanceCurrency(companyId));
  }

  Future<void> _loadBalanceCurrency(String companyId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('company_profile')
          .doc(companyId)
          .get(const GetOptions(source: Source.serverAndCache));
      final data = snap.data() ?? const <String, dynamic>{};
      final currency = companyCurrencyFromProfileData(data, fallback: 'KZT');
      if (!mounted || currency == _balanceCurrencyCode) return;
      setState(() => _balanceCurrencyCode = currency);
    } catch (_) {}
  }

  String _formatValue(double? value) {
    if (value == null) {
      return '';
    }
    return _formatMoney(value);
  }

  TextStyle _labelTextStyle(bool isTotal) {
    return FlutterFlowTheme.of(context).bodyLarge.override(
          font: GoogleFonts.inter(
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
          ),
          fontSize: 16.0,
          letterSpacing: 0.0,
          fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
          fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
        );
  }

  TextStyle _valueTextStyle(bool isBold, Color color) {
    return FlutterFlowTheme.of(context).titleLarge.override(
          font: GoogleFonts.inter(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            fontStyle: FlutterFlowTheme.of(context).titleLarge.fontStyle,
          ),
          fontSize: 20.0,
          letterSpacing: 0.0,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
          fontStyle: FlutterFlowTheme.of(context).titleLarge.fontStyle,
          color: color,
        );
  }

  Widget _balanceValueWidget(double value, {required bool isBold}) {
    final icon = value > 0
        ? Icons.trending_up
        : value < 0
            ? Icons.trending_down
            : Icons.horizontal_rule;
    final color = value < 0
        ? _negativeColor
        : value > 0
            ? _positiveColor
            : _neutralColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16.0,
          color: color,
        ),
        SizedBox(width: 4.0),
        Text(
          _formatMoney(value),
          style: _valueTextStyle(isBold, color),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
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

  Widget _buildLoadErrorCard({
    required String title,
    required Object? error,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720.0),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w700,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleMedium.fontStyle,
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              '$error',
              style: FlutterFlowTheme.of(context).bodySmall,
            ),
            const SizedBox(height: 12.0),
            OutlinedButton(
              onPressed: () => setState(() {}),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _companyIdsForQuery() {
    return resolveQueryCompanyIds(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: currentUserUid,
    );
  }

  String _manualBalanceCompanyId() {
    final effective = resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: currentUserUid,
    ).trim();
    if (effective.isNotEmpty && effective != '__all__') {
      return effective;
    }
    final ids = _companyIdsForQuery();
    return ids.isNotEmpty ? ids.first : '';
  }

  String _manualBalancePeriodKey() {
    final year = _selectedYear ?? DateTime.now().year;
    if (_period == 'month' && _selectedMonth != null) {
      return '$year-${_selectedMonth!.toString().padLeft(2, '0')}';
    }
    return '$year';
  }

  double? _manualValueFor(
    Map<String, double> values,
    _BalanceRow row,
  ) {
    final key = row.manualKey?.trim() ?? '';
    if (key.isEmpty) return null;
    return values[key];
  }

  double _rowResolvedValue(
    _BalanceRow row, {
    Map<String, double> manualValues = const <String, double>{},
  }) {
    final manualValue = _manualValueFor(manualValues, row);
    final ownValue = row.value ?? manualValue;
    if (ownValue != null) {
      return ownValue;
    }
    if (row.children.isEmpty) {
      return 0.0;
    }
    return _rowsResolvedTotal(
      row.children,
      manualValues: manualValues,
      skipTotalRows: true,
    );
  }

  double _rowsResolvedTotal(
    List<_BalanceRow> rows, {
    Map<String, double> manualValues = const <String, double>{},
    bool skipTotalRows = false,
  }) {
    return rows.fold<double>(0.0, (total, row) {
      if (skipTotalRows && row.isTotal) {
        return total;
      }
      return total +
          _rowResolvedValue(
            row,
            manualValues: manualValues,
          );
    });
  }

  double _groupResolvedTotal(
    _BalanceGroup group, {
    Map<String, double> manualValues = const <String, double>{},
  }) {
    final sectionTotal = group.sections.fold<double>(
      0.0,
      (total, section) =>
          total +
          _rowsResolvedTotal(
            section.rows,
            manualValues: manualValues,
            skipTotalRows: true,
          ),
    );
    final footerStandaloneTotal = _rowsResolvedTotal(
      group.footerRows,
      manualValues: manualValues,
      skipTotalRows: true,
    );
    return sectionTotal + footerStandaloneTotal;
  }

  Future<void> _showManualValueDialog(_BalanceRow row) async {
    final manualKey = row.manualKey?.trim() ?? '';
    if (!row.allowManualInput || manualKey.isEmpty) return;
    final controller = TextEditingController();
    final nextValue = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row.label),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          decoration: const InputDecoration(
            labelText: 'Ручное значение',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Отмена'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, double.nan),
            child: const Text('Очистить'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
              );
              Navigator.pop(context, parsed);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (nextValue == null) return;
    final companyId = _manualBalanceCompanyId();
    if (companyId.isEmpty) return;
    final userId = currentUserUid;
    if (userId.isEmpty) return;
    final payload = <String, dynamic>{
      'idCompany': companyId,
      'user_id': userId,
      'period_key': _manualBalancePeriodKey(),
      'row_key': manualKey,
      'row_label': row.label,
      'is_manual': true,
      'updated_at': FieldValue.serverTimestamp(),
    };
    final docId = '${companyId}_${_manualBalancePeriodKey()}_$manualKey';
    final docRef = FirebaseFirestore.instance
        .collection('balance_manual_values')
        .doc(docId);
    try {
      if (nextValue.isNaN) {
        await docRef.delete().catchError((_) {});
        if (mounted) {
          setState(() {
            _manualOverrides.remove(manualKey);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ручное значение очищено')),
          );
        }
        return;
      }
      await docRef.set({
        ...payload,
        'value': nextValue,
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _manualOverrides[manualKey] = nextValue;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Значение сохранено')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить значение: $e')),
      );
    }
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

  void _openJournal({
    String? type,
    String? category,
    LedgerScope? ledgerScope,
  }) {
    final params = <String, String?>{
      if (type != null && type.isNotEmpty) 'type': type,
      if (category != null && category.isNotEmpty) 'category': category,
      if (ledgerScope != null) 'typeUchet': ledgerScope.legacyTypeUchet,
    }.withoutNulls;
    context.pushNamedAuth(
      TranzactionJournalWidget.routeName,
      mounted,
      queryParameters: params,
    );
  }

  void _openJournalForRow(_BalanceRow row) {
    final category =
        row.filterCategory.trim().isEmpty ? null : row.filterCategory.trim();
    _openJournal(
      category: category,
      ledgerScope: LedgerScope.accounting,
    );
  }

  void _openJournalForGroup(_BalanceGroup group) {
    final category = group.title.trim().isEmpty ? null : group.title.trim();
    _openJournal(
      category: category,
      ledgerScope: LedgerScope.accounting,
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BalanceModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    return AuthUserStreamWidget(
      builder: (context) {
        _ensureBalanceCurrencyLoaded();
        if (!PermissionsHelper.has('uchet.view')) {
          return PermissionsHelper.noAccess();
        }
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
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
              child: Row(
                mainAxisSize: MainAxisSize.max,
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
                                Padding(
                                  padding: EdgeInsets.all(5.0),
                                  child: FlutterFlowIconButton(
                                    borderRadius: 8.0,
                                    buttonSize: 40.0,
                                    fillColor:
                                        FlutterFlowTheme.of(context).primary,
                                    icon: Icon(
                                      Icons.menu,
                                      color: FlutterFlowTheme.of(context).info,
                                      size: 24.0,
                                    ),
                                    onPressed: () async {
                                      scaffoldKey.currentState!.openDrawer();
                                    },
                                  ),
                                ),
                              Expanded(
                                child: HeaderWidget(
                                  title: 'Баланс',
                                  trailing: const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 12.0, 16.0, 24.0),
                              child: AuthUserStreamWidget(
                                builder: (context) =>
                                    StreamBuilder<List<MoneyWalletRecord>>(
                                  stream: queryMoneyWalletRecord(
                                    queryBuilder: (wallets) =>
                                        _applyCompanyFilter(wallets),
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return _buildLoadErrorCard(
                                        title:
                                            'Не удалось загрузить кошельки для баланса',
                                        error: snapshot.error,
                                      );
                                    }
                                    if (!snapshot.hasData) {
                                      return _buildLoadingState();
                                    }

                                    final wallets = snapshot.data ??
                                        const <MoneyWalletRecord>[];
                                    return StreamBuilder<List<ShetaRecord>>(
                                      stream: queryShetaRecord(
                                        queryBuilder: (accounts) =>
                                            _applyCompanyFilter(accounts),
                                      ),
                                      builder: (context, accountSnapshot) {
                                        if (accountSnapshot.hasError) {
                                          return _buildLoadErrorCard(
                                            title:
                                                'Не удалось загрузить счета для баланса',
                                            error: accountSnapshot.error,
                                          );
                                        }
                                        if (!accountSnapshot.hasData) {
                                          return _buildLoadingState();
                                        }

                                        final accounts = accountSnapshot.data ??
                                            const <ShetaRecord>[];
                                        return StreamBuilder<
                                            List<AccountingEntryRecord>>(
                                          stream: queryAccountingEntryRecord(
                                            queryBuilder: (entries) =>
                                                _applyCompanyFilter(entries),
                                          ),
                                          builder: (context, entrySnapshot) {
                                            if (entrySnapshot.hasError) {
                                              return _buildLoadErrorCard(
                                                title:
                                                    'Не удалось загрузить проводки для баланса',
                                                error: entrySnapshot.error,
                                              );
                                            }
                                            if (!entrySnapshot.hasData) {
                                              return _buildLoadingState();
                                            }

                                            final entries = entrySnapshot
                                                    .data ??
                                                const <AccountingEntryRecord>[];
                                            return StreamBuilder<QuerySnapshot>(
                                              stream: _applyCompanyFilter(
                                                FirebaseFirestore.instance
                                                    .collection(
                                                        'inventory_batches'),
                                              ).snapshots(),
                                              builder:
                                                  (context, batchSnapshot) {
                                                if (batchSnapshot.hasError) {
                                                  return _buildLoadErrorCard(
                                                    title:
                                                        'Не удалось загрузить партии склада для баланса',
                                                    error: batchSnapshot.error,
                                                  );
                                                }
                                                if (!batchSnapshot.hasData) {
                                                  return _buildLoadingState();
                                                }

                                                return StreamBuilder<
                                                    QuerySnapshot>(
                                                  stream: _applyCompanyFilter(
                                                    FirebaseFirestore.instance
                                                        .collection(
                                                            'debt_register'),
                                                  ).snapshots(),
                                                  builder:
                                                      (context, debtSnapshot) {
                                                    if (debtSnapshot.hasError) {
                                                      return _buildLoadErrorCard(
                                                        title:
                                                            'Не удалось загрузить реестр долгов для баланса',
                                                        error:
                                                            debtSnapshot.error,
                                                      );
                                                    }
                                                    if (!debtSnapshot.hasData) {
                                                      return _buildLoadingState();
                                                    }

                                                    return StreamBuilder<
                                                        QuerySnapshot>(
                                                      stream:
                                                          _applyCompanyFilter(
                                                        FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'obyaz'),
                                                      ).snapshots(),
                                                      builder: (context,
                                                          obligationSnapshot) {
                                                        if (obligationSnapshot
                                                            .hasError) {
                                                          return _buildLoadErrorCard(
                                                            title:
                                                                'Не удалось загрузить обязательства для баланса',
                                                            error:
                                                                obligationSnapshot
                                                                    .error,
                                                          );
                                                        }
                                                        if (!obligationSnapshot
                                                            .hasData) {
                                                          return _buildLoadingState();
                                                        }

                                                        return StreamBuilder<
                                                            QuerySnapshot>(
                                                          stream:
                                                              _applyCompanyFilter(
                                                            FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                    'cogs_register'),
                                                          ).snapshots(),
                                                          builder: (context,
                                                              cogsRegisterSnapshot) {
                                                            if (cogsRegisterSnapshot
                                                                .hasError) {
                                                              return _buildLoadErrorCard(
                                                                title:
                                                                    'Не удалось загрузить COGS register для баланса',
                                                                error:
                                                                    cogsRegisterSnapshot
                                                                        .error,
                                                              );
                                                            }
                                                            if (!cogsRegisterSnapshot
                                                                .hasData) {
                                                              return _buildLoadingState();
                                                            }

                                                            return StreamBuilder<
                                                                QuerySnapshot>(
                                                              stream:
                                                                  _applyCompanyFilter(
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                        'sale_item_cogs'),
                                                              ).snapshots(),
                                                              builder: (context,
                                                                  cogsSnapshot) {
                                                                if (cogsSnapshot
                                                                    .hasError) {
                                                                  return _buildLoadErrorCard(
                                                                    title:
                                                                        'Не удалось загрузить sale item COGS для баланса',
                                                                    error: cogsSnapshot
                                                                        .error,
                                                                  );
                                                                }
                                                                if (!cogsSnapshot
                                                                    .hasData) {
                                                                  return _buildLoadingState();
                                                                }

                                                                final datedEntries = entries
                                                                    .where((entry) =>
                                                                        entry
                                                                            .entryDate !=
                                                                        null)
                                                                    .toList();
                                                                final availableYears = datedEntries
                                                                    .map((entry) => entry
                                                                        .entryDate!
                                                                        .year)
                                                                    .toSet()
                                                                    .toList()
                                                                  ..sort((a,
                                                                          b) =>
                                                                      b.compareTo(
                                                                          a));

                                                                if (_availableYears
                                                                            .length !=
                                                                        availableYears
                                                                            .length ||
                                                                    !_availableYears
                                                                        .toSet()
                                                                        .containsAll(
                                                                            availableYears)) {
                                                                  WidgetsBinding
                                                                      .instance
                                                                      .addPostFrameCallback(
                                                                          (_) {
                                                                    if (!mounted)
                                                                      return;
                                                                    setState(
                                                                        () {
                                                                      _availableYears =
                                                                          List<int>.from(
                                                                              availableYears);
                                                                    });
                                                                  });
                                                                }

                                                                if (_selectedYear ==
                                                                        null &&
                                                                    availableYears
                                                                        .isNotEmpty) {
                                                                  _selectedYear =
                                                                      availableYears
                                                                          .first;
                                                                }

                                                                final effectiveYear = _selectedYear ??
                                                                    (availableYears
                                                                            .isNotEmpty
                                                                        ? availableYears
                                                                            .first
                                                                        : null);
                                                                final availableMonths = effectiveYear ==
                                                                        null
                                                                    ? <int>[]
                                                                    : datedEntries
                                                                        .where((entry) =>
                                                                            entry.entryDate!.year ==
                                                                            effectiveYear)
                                                                        .map((entry) => entry
                                                                            .entryDate!
                                                                            .month)
                                                                        .toSet()
                                                                        .toList()
                                                                  ..sort();
                                                                final desiredMonth = _period ==
                                                                        'year'
                                                                    ? null
                                                                    : (_selectedMonth ??
                                                                        (availableMonths.isNotEmpty
                                                                            ? availableMonths.first
                                                                            : null));

                                                                if (desiredMonth !=
                                                                    _selectedMonth) {
                                                                  WidgetsBinding
                                                                      .instance
                                                                      .addPostFrameCallback(
                                                                          (_) {
                                                                    if (!mounted)
                                                                      return;
                                                                    setState(
                                                                        () {
                                                                      _selectedMonth =
                                                                          desiredMonth;
                                                                    });
                                                                  });
                                                                }

                                                                DateTime?
                                                                    periodEnd;
                                                                if (effectiveYear !=
                                                                    null) {
                                                                  if (_period ==
                                                                      'year') {
                                                                    periodEnd =
                                                                        DateTime(
                                                                      effectiveYear +
                                                                          1,
                                                                      1,
                                                                      1,
                                                                    );
                                                                  } else if (_selectedMonth !=
                                                                      null) {
                                                                    periodEnd = _selectedMonth ==
                                                                            12
                                                                        ? DateTime(
                                                                            effectiveYear +
                                                                                1,
                                                                            1,
                                                                            1)
                                                                        : DateTime(
                                                                            effectiveYear,
                                                                            _selectedMonth! +
                                                                                1,
                                                                            1,
                                                                          );
                                                                  }
                                                                }

                                                                final filteredEntryPayloads =
                                                                    entries
                                                                        .where((entry) =>
                                                                            periodEnd == null ||
                                                                            entry.entryDate ==
                                                                                null ||
                                                                            entry.entryDate!.isBefore(
                                                                                periodEnd))
                                                                        .map((entry) =>
                                                                            Map<String,
                                                                                dynamic>.from(
                                                                              entry.snapshotData,
                                                                            ))
                                                                        .toList();
                                                                final inventoryPayloads = (batchSnapshot
                                                                            .data
                                                                            ?.docs ??
                                                                        const [])
                                                                    .map(
                                                                        (doc) =>
                                                                            {
                                                                              'id': doc.id,
                                                                              ...(Map<String, dynamic>.from(doc.data() as Map)),
                                                                            })
                                                                    .toList();
                                                                final debtViews = (debtSnapshot
                                                                            .data
                                                                            ?.docs ??
                                                                        const [])
                                                                    .map((doc) =>
                                                                        DebtRecordView
                                                                            .fromMap({
                                                                          'id':
                                                                              doc.id,
                                                                          ...Map<
                                                                              String,
                                                                              dynamic>.from(doc
                                                                                  .data()
                                                                              as Map),
                                                                        }))
                                                                    .toList();
                                                                final obligationPayloads = (obligationSnapshot
                                                                            .data
                                                                            ?.docs ??
                                                                        const [])
                                                                    .map(
                                                                        (doc) =>
                                                                            {
                                                                              'id': doc.id,
                                                                              ...(Map<String, dynamic>.from(doc.data() as Map)),
                                                                            })
                                                                    .toList();
                                                                final cogsPayloads =
                                                                    resolvePnlCogsItems(
                                                                  cogsEntries: (cogsRegisterSnapshot
                                                                              .data
                                                                              ?.docs ??
                                                                          const [])
                                                                      .map(
                                                                          (doc) =>
                                                                              {
                                                                                'id': doc.id,
                                                                                ...Map<String, dynamic>.from(doc.data() as Map),
                                                                              })
                                                                      .where(
                                                                          (item) {
                                                                    if (periodEnd ==
                                                                        null) {
                                                                      return true;
                                                                    }
                                                                    final raw = item[
                                                                            'created_at'] ??
                                                                        item[
                                                                            'date'] ??
                                                                        item[
                                                                            'updated_at'];
                                                                    if (raw
                                                                        is DateTime) {
                                                                      return raw
                                                                          .isBefore(
                                                                              periodEnd);
                                                                    }
                                                                    return true;
                                                                  }).toList(),
                                                                  legacyCogsItems: (cogsSnapshot
                                                                              .data
                                                                              ?.docs ??
                                                                          const [])
                                                                      .map(
                                                                          (doc) =>
                                                                              {
                                                                                'id': doc.id,
                                                                                ...Map<String, dynamic>.from(doc.data() as Map),
                                                                              })
                                                                      .where(
                                                                          (item) {
                                                                    if (periodEnd ==
                                                                        null) {
                                                                      return true;
                                                                    }
                                                                    final raw = item[
                                                                            'created_at'] ??
                                                                        item[
                                                                            'date'] ??
                                                                        item[
                                                                            'updated_at'];
                                                                    if (raw
                                                                        is DateTime) {
                                                                      return raw
                                                                          .isBefore(
                                                                              periodEnd);
                                                                    }
                                                                    return true;
                                                                  }).toList(),
                                                                );

                                                                final balanceSheet =
                                                                    computeBalanceSheet(
                                                                  wallets: wallets
                                                                      .map((wallet) => {
                                                                            'id':
                                                                                wallet.reference.id,
                                                                            ...wallet.snapshotData,
                                                                          })
                                                                      .toList(),
                                                                  accounts: accounts
                                                                      .map((account) => {
                                                                            'id':
                                                                                account.reference.id,
                                                                            ...account.snapshotData,
                                                                          })
                                                                      .toList(),
                                                                  inventoryBatches:
                                                                      inventoryPayloads,
                                                                  debts:
                                                                      debtViews,
                                                                  obligations:
                                                                      obligationPayloads,
                                                                  accountingEntries:
                                                                      filteredEntryPayloads,
                                                                  cogsItems:
                                                                      cogsPayloads,
                                                                  ledgerScope:
                                                                      LedgerScope
                                                                          .accounting,
                                                                );
                                                                final aging =
                                                                    DebtAgingService
                                                                        .compute(
                                                                  debts: debtViews
                                                                      .where(
                                                                        (debt) =>
                                                                            debt.type ==
                                                                                DebtType.ar &&
                                                                            debt.ledgerScope.matches(
                                                                              LedgerScope.accounting,
                                                                            ),
                                                                      )
                                                                      .toList(),
                                                                  asOf: periodEnd?.subtract(const Duration(
                                                                          milliseconds:
                                                                              1)) ??
                                                                      DateTime
                                                                          .now(),
                                                                );
                                                                final debtSummary =
                                                                    computeDebtRegisterSummary(
                                                                  debts:
                                                                      debtViews,
                                                                  asOf: periodEnd?.subtract(const Duration(
                                                                          milliseconds:
                                                                              1)) ??
                                                                      DateTime
                                                                          .now(),
                                                                  ledgerScope:
                                                                      LedgerScope
                                                                          .accounting,
                                                                );
                                                                final debtAsOf =
                                                                    periodEnd
                                                                            ?.subtract(
                                                                          const Duration(
                                                                            milliseconds:
                                                                                1,
                                                                          ),
                                                                        ) ??
                                                                        DateTime
                                                                            .now();
                                                                final debtRows =
                                                                    _applyDebtIssueFilter(
                                                                  buildDebtRegisterRows(
                                                                    debts:
                                                                        debtViews,
                                                                    asOf:
                                                                        debtAsOf,
                                                                    ledgerScope:
                                                                        LedgerScope
                                                                            .accounting,
                                                                    type:
                                                                        _debtTypeFilter,
                                                                  ),
                                                                  asOf:
                                                                      debtAsOf,
                                                                );

                                                                return SingleChildScrollView(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .stretch,
                                                                    children: [
                                                                      Padding(
                                                                        padding:
                                                                            EdgeInsets.only(bottom: 12.0),
                                                                        child:
                                                                            Wrap(
                                                                          spacing:
                                                                              12.0,
                                                                          runSpacing:
                                                                              8.0,
                                                                          crossAxisAlignment:
                                                                              WrapCrossAlignment.center,
                                                                          children: [
                                                                            Container(
                                                                              constraints: BoxConstraints(maxWidth: 150.0),
                                                                              child: DropdownButtonFormField<String>(
                                                                                initialValue: _period,
                                                                                decoration: InputDecoration(
                                                                                  isDense: true,
                                                                                  contentPadding: EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
                                                                                  border: OutlineInputBorder(
                                                                                    borderRadius: BorderRadius.circular(8.0),
                                                                                  ),
                                                                                ),
                                                                                items: const [
                                                                                  DropdownMenuItem(
                                                                                    value: 'year',
                                                                                    child: Text('Год'),
                                                                                  ),
                                                                                  DropdownMenuItem(
                                                                                    value: 'month',
                                                                                    child: Text('Месяц'),
                                                                                  ),
                                                                                ],
                                                                                onChanged: (value) {
                                                                                  if (value == null) return;
                                                                                  setState(() {
                                                                                    _period = value;
                                                                                    if (value == 'year') {
                                                                                      _selectedMonth = null;
                                                                                    }
                                                                                  });
                                                                                },
                                                                              ),
                                                                            ),
                                                                            if (availableYears.isNotEmpty)
                                                                              Container(
                                                                                constraints: BoxConstraints(maxWidth: 140.0),
                                                                                child: DropdownButtonFormField<int>(
                                                                                  initialValue: effectiveYear,
                                                                                  decoration: InputDecoration(
                                                                                    isDense: true,
                                                                                    contentPadding: EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
                                                                                    border: OutlineInputBorder(
                                                                                      borderRadius: BorderRadius.circular(8.0),
                                                                                    ),
                                                                                  ),
                                                                                  items: availableYears
                                                                                      .map(
                                                                                        (y) => DropdownMenuItem(
                                                                                          value: y,
                                                                                          child: Text('$y'),
                                                                                        ),
                                                                                      )
                                                                                      .toList(),
                                                                                  onChanged: (value) {
                                                                                    if (value == null) return;
                                                                                    setState(() {
                                                                                      _selectedYear = value;
                                                                                      _selectedMonth = null;
                                                                                    });
                                                                                  },
                                                                                ),
                                                                              ),
                                                                            if (_period !=
                                                                                'year')
                                                                              Container(
                                                                                constraints: BoxConstraints(maxWidth: 170.0),
                                                                                child: DropdownButtonFormField<int>(
                                                                                  initialValue: desiredMonth,
                                                                                  decoration: InputDecoration(
                                                                                    isDense: true,
                                                                                    contentPadding: EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
                                                                                    border: OutlineInputBorder(
                                                                                      borderRadius: BorderRadius.circular(8.0),
                                                                                    ),
                                                                                  ),
                                                                                  items: availableMonths
                                                                                      .map(
                                                                                        (m) => DropdownMenuItem(
                                                                                          value: m,
                                                                                          child: Text(_monthNames[m] ?? '$m'),
                                                                                        ),
                                                                                      )
                                                                                      .toList(),
                                                                                  onChanged: (value) {
                                                                                    if (value == null) return;
                                                                                    setState(() {
                                                                                      _selectedMonth = value;
                                                                                    });
                                                                                  },
                                                                                ),
                                                                              ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      Padding(
                                                                        padding:
                                                                            EdgeInsets.only(bottom: 12.0),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Expanded(
                                                                              child: Text(
                                                                                'Баланс',
                                                                                style: FlutterFlowTheme.of(context).headlineSmall.override(
                                                                                      font: GoogleFonts.interTight(
                                                                                        fontWeight: FontWeight.w700,
                                                                                        fontStyle: FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                                                                                      ),
                                                                                      letterSpacing: 0.0,
                                                                                      fontWeight: FontWeight.w700,
                                                                                      fontStyle: FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                                                                                    ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              12.0),
                                                                      Wrap(
                                                                        spacing:
                                                                            12.0,
                                                                        runSpacing:
                                                                            12.0,
                                                                        children:
                                                                            _balanceSummaryMetrics(
                                                                          balanceSheet:
                                                                              balanceSheet,
                                                                          aging:
                                                                              aging,
                                                                        ).map(_balanceSummaryCard).toList(),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              12.0),
                                                                      StreamBuilder<
                                                                          QuerySnapshot>(
                                                                        stream: FirebaseFirestore
                                                                            .instance
                                                                            .collection('balance_manual_values')
                                                                            .where(
                                                                              'idCompany',
                                                                              isEqualTo: _manualBalanceCompanyId(),
                                                                            )
                                                                            .where(
                                                                              'period_key',
                                                                              isEqualTo: _manualBalancePeriodKey(),
                                                                            )
                                                                            .snapshots(),
                                                                        builder:
                                                                            (context,
                                                                                manualSnapshot) {
                                                                          final manualValues =
                                                                              <String, double>{
                                                                            ..._manualOverrides,
                                                                          };
                                                                          if (manualSnapshot
                                                                              .hasData) {
                                                                            for (final doc
                                                                                in manualSnapshot.data?.docs ?? const []) {
                                                                              final data = Map<String, dynamic>.from(doc.data() as Map);
                                                                              final key = (data['row_key'] ?? '').toString().trim();
                                                                              if (key.isEmpty)
                                                                                continue;
                                                                              manualValues[key] = (data['value'] as num?)?.toDouble() ?? 0;
                                                                            }
                                                                            if (_manualOverrides.isNotEmpty) {
                                                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                                                if (!mounted) return;
                                                                                setState(() {
                                                                                  _manualOverrides.removeWhere(
                                                                                    (key, value) => manualValues[key] == value,
                                                                                  );
                                                                                });
                                                                              });
                                                                            }
                                                                          }
                                                                          final groups =
                                                                              _balanceGroups(
                                                                            balanceSheet:
                                                                                balanceSheet,
                                                                            aging:
                                                                                aging,
                                                                          );
                                                                          _BalanceGroup?
                                                                              assetsGroup;
                                                                          for (final group
                                                                              in groups) {
                                                                            if (group.title ==
                                                                                'Активы') {
                                                                              assetsGroup = group;
                                                                              break;
                                                                            }
                                                                          }
                                                                          assetsGroup ??= groups.isNotEmpty
                                                                              ? groups.first
                                                                              : null;

                                                                          _BalanceGroup?
                                                                              liabilitiesGroup;
                                                                          for (final group
                                                                              in groups) {
                                                                            if (group.title ==
                                                                                'Пассивы') {
                                                                              liabilitiesGroup = group;
                                                                              break;
                                                                            }
                                                                          }
                                                                          liabilitiesGroup ??= groups.length > 1
                                                                              ? groups[1]
                                                                              : null;

                                                                          if (assetsGroup == null &&
                                                                              liabilitiesGroup == null) {
                                                                            return const SizedBox.shrink();
                                                                          }

                                                                          return LayoutBuilder(
                                                                            builder:
                                                                                (context, constraints) {
                                                                              final isTwoColumns = constraints.maxWidth >= 980.0;
                                                                              if (isTwoColumns) {
                                                                                return Row(
                                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                                  children: [
                                                                                    if (assetsGroup != null)
                                                                                      Expanded(
                                                                                        child: Padding(
                                                                                          padding: const EdgeInsets.only(right: 8.0),
                                                                                          child: _buildBalancePanel(
                                                                                            assetsGroup,
                                                                                            manualValues: manualValues,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    if (liabilitiesGroup != null)
                                                                                      Expanded(
                                                                                        child: Padding(
                                                                                          padding: const EdgeInsets.only(left: 8.0),
                                                                                          child: _buildBalancePanel(
                                                                                            liabilitiesGroup,
                                                                                            manualValues: manualValues,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                  ],
                                                                                );
                                                                              }

                                                                              return Column(
                                                                                children: [
                                                                                  if (assetsGroup != null)
                                                                                    Padding(
                                                                                      padding: const EdgeInsets.only(bottom: 12.0),
                                                                                      child: _buildBalancePanel(
                                                                                        assetsGroup,
                                                                                        manualValues: manualValues,
                                                                                      ),
                                                                                    ),
                                                                                  if (liabilitiesGroup != null)
                                                                                    Padding(
                                                                                      padding: const EdgeInsets.only(bottom: 12.0),
                                                                                      child: _buildBalancePanel(
                                                                                        liabilitiesGroup,
                                                                                        manualValues: manualValues,
                                                                                      ),
                                                                                    ),
                                                                                ],
                                                                              );
                                                                            },
                                                                          );
                                                                        },
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              12.0),
                                                                      _buildDebtRegisterSection(
                                                                        summary:
                                                                            debtSummary,
                                                                        rows:
                                                                            debtRows,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              },
                                                            );
                                                          },
                                                        );
                                                      },
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
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
            ),
          ),
        );
      },
    );
  }

  List<_BalanceGroup> _balanceGroups({
    required BalanceSheet balanceSheet,
    required DebtAgingSummary aging,
  }) {
    return [
      _BalanceGroup(
        title: 'Активы',
        total: balanceSheet.assetsTotal,
        sections: [
          _BalanceSection(
            title: 'I. Краткосрочные активы',
            rows: [
              _BalanceRow('Денежные средства и их эквиваленты',
                  value: balanceSheet.cashTotal, filterCategory: 'Касса'),
              _BalanceRow('Запасы', value: balanceSheet.inventoryTotal),
              _BalanceRow('Товары'),
              _BalanceRow(
                'Биологические активы',
                manualKey: 'assets_biological_short',
                allowManualInput: true,
              ),
              _BalanceRow('Краткосрочная Дебиторская задолженность Покупателей',
                  value: balanceSheet.receivablesTotal, filterCategory: 'AR'),
              _BalanceRow(
                'Авансы выданные Поставщикам (предоплата)',
                manualKey: 'assets_supplier_advances',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Задолженность сотрудников',
                manualKey: 'assets_staff_debt',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Текущие налоговые активы',
                manualKey: 'assets_current_tax',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Расходы будущих периодов',
                manualKey: 'assets_prepaid_expenses',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Прочие краткосрочные активы',
                manualKey: 'assets_other_short',
                allowManualInput: true,
              ),
              _BalanceRow('Итого краткосрочных активов',
                  value: balanceSheet.assetsTotal, isTotal: true),
            ],
          ),
          _BalanceSection(
            title: 'II. Долгосрочные активы',
            rows: [
              _BalanceRow(
                  'Инвестиции, учитываемые по первоначальной стоимости, в том числе',
                  manualKey: 'assets_investments_long',
                  allowManualInput: true),
              _BalanceRow(
                'Долгосрочная Дебиторская задолженность',
                manualKey: 'assets_receivables_long',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Инвестиционное имущество',
                manualKey: 'assets_investment_property',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Основные средства',
                manualKey: 'assets_fixed_assets',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Биологические активы',
                manualKey: 'assets_biological_long',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Нематериальные активы',
                manualKey: 'assets_intangible',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Отложенные налоговые активы',
                manualKey: 'assets_deferred_tax',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Прочие долгосрочные активы',
                manualKey: 'assets_other_long',
                allowManualInput: true,
              ),
              _BalanceRow('Итого долгосрочных активов', isTotal: true),
            ],
          ),
        ],
        footerRows: [
          _BalanceRow('БАЛАНС', value: balanceSheet.assetsTotal, isTotal: true),
        ],
      ),
      _BalanceGroup(
        title: 'Пассивы',
        total: balanceSheet.liabilitiesTotal + balanceSheet.equityTotal,
        sections: [
          _BalanceSection(
            title: 'III. Краткосрочные обязательства',
            rows: [
              _BalanceRow(
                  'Краткосрочная Кредиторская задолженность Поставщикам',
                  value: balanceSheet.payablesTotal,
                  filterCategory: 'AP'),
              _BalanceRow(
                'Краткосрочные обязательства с Покупателями',
                manualKey: 'liabilities_buyers_short',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Краткосрочная задолженность по аренде',
                manualKey: 'liabilities_rent_short',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Вознаграждения работникам (ЗРП, ГПХ)',
                manualKey: 'liabilities_staff_short',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Краткосрочные финансовые обязательства',
                manualKey: 'liabilities_fin_short',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Текущие налоговые обязательства',
                manualKey: 'liabilities_tax_short',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Государственные субсидии',
                manualKey: 'liabilities_subsidies',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Дивиденды к оплате',
                manualKey: 'liabilities_dividends',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Прочие краткосрочные обязательства',
                manualKey: 'liabilities_other_short',
                allowManualInput: true,
              ),
              _BalanceRow('Итого краткосрочных обязательств',
                  value: balanceSheet.payablesTotal, isTotal: true),
            ],
          ),
          _BalanceSection(
            title: 'IV. Долгосрочные обязательства',
            rows: [
              _BalanceRow(
                'Долгосрочные финансовые обязательства (Инвестиции), в том числе',
                value: balanceSheet.loansTotal,
                children: [
                  _BalanceRow('UDI Kazakhstan ТОО'),
                  _BalanceRow('Давлатов Саидмурод Раджабович'),
                  _BalanceRow('Тогузов Ерлан Ергалиевич'),
                ],
              ),
              _BalanceRow(
                'Долгосрочная Кредиторская задолженность',
                manualKey: 'liabilities_payables_long',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Отложенные налоговые обязательства',
                manualKey: 'liabilities_deferred_tax',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Прочие долгосрочные обязательства',
                manualKey: 'liabilities_other_long',
                allowManualInput: true,
              ),
              _BalanceRow('Итого долгосрочных обязательств',
                  value: balanceSheet.loansTotal, isTotal: true),
            ],
          ),
          _BalanceSection(
            title: 'V. Капитал',
            rows: [
              _BalanceRow('Уставный (акционерный) капитал',
                  value: balanceSheet.ownerCapitalTotal),
              _BalanceRow('Начальный капитал / корректировка открытия',
                  value: balanceSheet.openingAdjustmentTotal),
              _BalanceRow(
                'Эмиссионный доход',
                manualKey: 'equity_emission_income',
                allowManualInput: true,
              ),
              _BalanceRow(
                'Выкупленные собственные долевые инструменты',
                manualKey: 'equity_treasury',
                allowManualInput: true,
              ),
              _BalanceRow('Нераспределенная прибыль (непокрытый убыток)',
                  value: balanceSheet.retainedEarningsTotal),
              _BalanceRow(
                'Прочий капитал',
                manualKey: 'equity_other',
                allowManualInput: true,
              ),
              _BalanceRow('Итого капитал, относимый на собственников',
                  value: balanceSheet.equityTotal, isTotal: true),
            ],
          ),
          _BalanceSection(
            title: 'Проверки',
            rows: [
              _BalanceRow('БАЛАНС',
                  value:
                      balanceSheet.liabilitiesTotal + balanceSheet.equityTotal,
                  isTotal: true),
              _BalanceRow('Проверка баланса', value: balanceSheet.imbalance),
              _BalanceRow('AR aging 0-30', value: aging.bucket0To30),
              _BalanceRow('AR aging 90+', value: aging.bucket90Plus),
            ],
          ),
        ],
      ),
    ];
  }

  List<_BalanceSummaryMetric> _balanceSummaryMetrics({
    required BalanceSheet balanceSheet,
    required DebtAgingSummary aging,
  }) {
    return [
      _BalanceSummaryMetric(
        label: 'Активы',
        value: balanceSheet.assetsTotal,
        highlight: true,
      ),
      _BalanceSummaryMetric(
        label: 'Обязательства',
        value: balanceSheet.liabilitiesTotal,
      ),
      _BalanceSummaryMetric(
        label: 'Капитал',
        value: balanceSheet.equityTotal,
      ),
      _BalanceSummaryMetric(
        label: 'AR',
        value: balanceSheet.receivablesTotal,
        selected: _debtTypeFilter == DebtType.ar && _debtIssueFilter == null,
        onTap: () => _setDebtFilters(type: DebtType.ar),
      ),
      _BalanceSummaryMetric(
        label: 'AP',
        value: balanceSheet.payablesTotal,
        selected: _debtTypeFilter == DebtType.ap && _debtIssueFilter == null,
        onTap: () => _setDebtFilters(type: DebtType.ap),
      ),
      _BalanceSummaryMetric(
        label: 'Расхождение',
        value: balanceSheet.imbalance,
        warning: !balanceSheet.isBalanced,
      ),
      _BalanceSummaryMetric(
        label: 'AR 0-30',
        value: aging.bucket0To30,
        selected: _debtTypeFilter == DebtType.ar && _debtIssueFilter == null,
        onTap: () => _setDebtFilters(type: DebtType.ar),
      ),
      _BalanceSummaryMetric(
        label: 'AR 90+',
        value: aging.bucket90Plus,
        warning: aging.bucket90Plus > 0.01,
        selected: _debtTypeFilter == DebtType.ar &&
            _debtIssueFilter == _DebtRegisterIssueFilter.ar90Plus,
        onTap: () => _setDebtFilters(
          type: DebtType.ar,
          issue: _DebtRegisterIssueFilter.ar90Plus,
        ),
      ),
    ];
  }

  Widget _balanceSummaryCard(_BalanceSummaryMetric metric) {
    final color = metric.warning
        ? _negativeColor
        : metric.highlight
            ? FlutterFlowTheme.of(context).primary
            : _neutralColor;
    return InkWell(
        onTap: metric.onTap,
        borderRadius: BorderRadius.circular(14.0),
        child: Container(
          constraints: const BoxConstraints(minWidth: 150.0, maxWidth: 220.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(
              color: metric.selected
                  ? FlutterFlowTheme.of(context).primary
                  : metric.warning
                      ? _negativeColor.withValues(alpha: 0.24)
                      : FlutterFlowTheme.of(context).alternate,
              width: metric.selected ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: FlutterFlowTheme.of(context).bodySmall,
              ),
              const SizedBox(height: 8.0),
              Text(
                _formatMoney(metric.value),
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      color: color,
                    ),
              ),
              if (metric.onTap != null) ...[
                const SizedBox(height: 6.0),
                Text(
                  'Нажмите для фильтра',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                ),
              ],
            ],
          ),
        ));
  }

  Widget _buildDebtRegisterSection({
    required DebtRegisterSummary summary,
    required List<DebtRegisterRow> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Реестр долгов',
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: rows.isEmpty
                    ? null
                    : () =>
                        _exportDebtRegisterPdf(summary: summary, rows: rows),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF'),
              ),
              const SizedBox(width: 8.0),
              OutlinedButton.icon(
                onPressed: rows.isEmpty
                    ? null
                    : () =>
                        _exportDebtRegisterExcel(summary: summary, rows: rows),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Excel'),
              ),
              const SizedBox(width: 8.0),
              OutlinedButton.icon(
                onPressed: rows.isEmpty ? null : _showDebtTimelineDialog,
                icon: const Icon(Icons.timeline_outlined, size: 16),
                label: const Text('Погашения'),
              ),
              const SizedBox(width: 12.0),
              Wrap(
                spacing: 8.0,
                children: [
                  ChoiceChip(
                    label: const Text('Все'),
                    selected:
                        _debtTypeFilter == null && _debtIssueFilter == null,
                    onSelected: (_) => _setDebtFilters(),
                  ),
                  ChoiceChip(
                    label: const Text('AR'),
                    selected: _debtTypeFilter == DebtType.ar &&
                        _debtIssueFilter == null,
                    onSelected: (_) => _setDebtFilters(type: DebtType.ar),
                  ),
                  ChoiceChip(
                    label: const Text('AP'),
                    selected: _debtTypeFilter == DebtType.ap &&
                        _debtIssueFilter == null,
                    onSelected: (_) => _setDebtFilters(type: DebtType.ap),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: [
              _balanceSummaryCard(
                _BalanceSummaryMetric(
                  label: 'AR',
                  value: summary.arTotal,
                  selected: _debtTypeFilter == DebtType.ar &&
                      _debtIssueFilter == null,
                  onTap: () => _setDebtFilters(type: DebtType.ar),
                ),
              ),
              _balanceSummaryCard(
                _BalanceSummaryMetric(
                  label: 'AP',
                  value: summary.apTotal,
                  selected: _debtTypeFilter == DebtType.ap &&
                      _debtIssueFilter == null,
                  onTap: () => _setDebtFilters(type: DebtType.ap),
                ),
              ),
              _balanceSummaryCard(
                _BalanceSummaryMetric(
                  label: 'Открытые',
                  value: summary.openCount.toDouble(),
                ),
              ),
              _balanceSummaryCard(
                _BalanceSummaryMetric(
                  label: 'Просрочено',
                  value: summary.overdueCount.toDouble(),
                  warning: summary.overdueCount > 0,
                  selected:
                      _debtIssueFilter == _DebtRegisterIssueFilter.overdue,
                  onTap: () =>
                      _setDebtFilters(issue: _DebtRegisterIssueFilter.overdue),
                ),
              ),
              _balanceSummaryCard(
                _BalanceSummaryMetric(
                  label: 'Лимит превышен',
                  value: summary.limitExceededCount.toDouble(),
                  warning: summary.limitExceededCount > 0,
                  selected: _debtIssueFilter ==
                      _DebtRegisterIssueFilter.limitExceeded,
                  onTap: () => _setDebtFilters(
                    issue: _DebtRegisterIssueFilter.limitExceeded,
                  ),
                ),
              ),
              _balanceSummaryCard(
                _BalanceSummaryMetric(
                  label: 'AR 90+',
                  value: summary.arAging.bucket90Plus,
                  warning: summary.arAging.bucket90Plus > 0.01,
                  selected: _debtTypeFilter == DebtType.ar &&
                      _debtIssueFilter == _DebtRegisterIssueFilter.ar90Plus,
                  onTap: () => _setDebtFilters(
                    type: DebtType.ar,
                    issue: _DebtRegisterIssueFilter.ar90Plus,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          if (rows.isEmpty)
            Text(
              'Открытые долги не найдены',
              style: FlutterFlowTheme.of(context).bodyMedium,
            )
          else
            Column(
              children: [
                const Row(
                  children: [
                    Expanded(flex: 2, child: Text('Контрагент')),
                    Expanded(flex: 1, child: Text('Тип')),
                    Expanded(flex: 1, child: Text('Сумма')),
                    Expanded(flex: 1, child: Text('Остаток')),
                    Expanded(flex: 1, child: Text('Aging')),
                    Expanded(flex: 1, child: Text('Статус')),
                  ],
                ),
                const Divider(height: 16.0),
                ...rows.take(12).map(_buildDebtRow),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _exportDebtRegisterExcel({
    required DebtRegisterSummary summary,
    required List<DebtRegisterRow> rows,
  }) {
    return exportReportExcel(
      filename: 'debt-register.xls',
      title: 'Реестр долгов',
      rows: buildDebtRegisterExportRows(
        title: 'Реестр долгов',
        summary: summary,
        rows: rows,
      ),
    );
  }

  Future<void> _exportDebtRegisterPdf({
    required DebtRegisterSummary summary,
    required List<DebtRegisterRow> rows,
  }) {
    return exportReportPdf(
      filename: 'debt-register.pdf',
      title: 'Реестр долгов',
      rows: buildDebtRegisterExportRows(
        title: 'Реестр долгов',
        summary: summary,
        rows: rows,
      ),
    );
  }

  Widget _buildDebtRow(DebtRegisterRow row) {
    final dueColor = row.isCreditLimitExceeded
        ? _negativeColor
        : row.agingDays >= 90
            ? const Color(0xFFB45309)
            : _neutralColor;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child:
                Text(row.counterpartyName.isEmpty ? '—' : row.counterpartyName),
          ),
          Expanded(
            flex: 1,
            child: Text(row.type.label),
          ),
          Expanded(
            flex: 1,
            child: Text(_formatMoney(row.totalAmount)),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _formatMoney(row.remainingAmount),
              style: TextStyle(color: dueColor, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text('${row.agingDays} дн'),
          ),
          Expanded(
            flex: 1,
            child: Text(
              row.isCreditLimitExceeded ? 'Лимит' : row.status.storageValue,
              style: TextStyle(color: dueColor),
            ),
          ),
          IconButton(
            onPressed: () => _showDebtPaymentHistory(row),
            icon: const Icon(Icons.history, size: 18),
            tooltip: 'История погашений',
          ),
        ],
      ),
    );
  }

  Future<void> _showDebtPaymentHistory(DebtRegisterRow row) async {
    final companyIds = _companyIdsForQuery();
    if (companyIds.isEmpty) return;
    final linksSnap = await _applyCompanyFilter(
      FirebaseFirestore.instance.collection('debt_payment_links'),
    ).get();
    final transactionsSnap = await _applyCompanyFilter(
      FirebaseFirestore.instance.collection('tranzaction'),
    ).get();
    final rows = buildDebtPaymentHistoryRows(
      debtId: row.id,
      paymentLinks: linksSnap.docs
          .map((doc) => {
                'id': doc.id,
                ...(Map<String, dynamic>.from(doc.data() as Map)),
              })
          .toList(),
      transactions: transactionsSnap.docs
          .map((doc) => {
                'id': doc.id,
                ...(Map<String, dynamic>.from(doc.data() as Map)),
              })
          .toList(),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'История погашений: ${row.counterpartyName.isEmpty ? row.id : row.counterpartyName}',
        ),
        content: SizedBox(
          width: 760,
          child: rows.isEmpty
              ? const Text('Погашения по долгу не найдены')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final history = rows[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        history.description.isEmpty
                            ? history.paymentTransactionId
                            : history.description,
                      ),
                      subtitle: Text(
                        '${history.accountTitle.isEmpty ? '—' : history.accountTitle} · ${history.status.isEmpty ? '—' : history.status} · ${history.createdAt == null ? '—' : dateTimeFormat('dd.MM.yyyy', history.createdAt)}',
                      ),
                      trailing: Text(_formatMoney(history.amount)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDebtTimelineDialog() async {
    final linksSnap = await _applyCompanyFilter(
      FirebaseFirestore.instance.collection('debt_payment_links'),
    ).get();
    final transactionsSnap = await _applyCompanyFilter(
      FirebaseFirestore.instance.collection('tranzaction'),
    ).get();
    final debtSnap = await _applyCompanyFilter(
      FirebaseFirestore.instance.collection('debt_register'),
    ).get();
    if (!mounted) return;
    DebtType? selectedType = _debtTypeFilter;
    _DebtRegisterIssueFilter? selectedIssue = _debtIssueFilter;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final asOf = DateTime.now();
            final debtViews = debtSnap.docs
                .map((doc) => DebtRecordView.fromMap({
                      'id': doc.id,
                      ...(Map<String, dynamic>.from(doc.data() as Map)),
                    }))
                .toList();
            final filteredDebts = _filterDebtViewsForIssue(
              debtViews,
              asOf: asOf,
              type: selectedType,
              issue: selectedIssue,
            );
            final rows = buildDebtPaymentTimelineRows(
              debts: filteredDebts,
              paymentLinks: linksSnap.docs
                  .map((doc) => {
                        'id': doc.id,
                        ...(Map<String, dynamic>.from(doc.data() as Map)),
                      })
                  .toList(),
              transactions: transactionsSnap.docs
                  .map((doc) => {
                        'id': doc.id,
                        ...(Map<String, dynamic>.from(doc.data() as Map)),
                      })
                  .toList(),
              type: selectedType,
              ledgerScope: LedgerScope.accounting,
            );
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Журнал погашений')),
                  OutlinedButton.icon(
                    onPressed: rows.isEmpty
                        ? null
                        : () => exportReportPdf(
                              filename: 'debt-timeline.pdf',
                              title: 'Журнал погашений',
                              rows: buildDebtPaymentTimelineExportRows(
                                title: 'Журнал погашений',
                                rows: rows,
                              ),
                            ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('PDF'),
                  ),
                  const SizedBox(width: 8.0),
                  OutlinedButton.icon(
                    onPressed: rows.isEmpty
                        ? null
                        : () => exportReportExcel(
                              filename: 'debt-timeline.xls',
                              title: 'Журнал погашений',
                              rows: buildDebtPaymentTimelineExportRows(
                                title: 'Журнал погашений',
                                rows: rows,
                              ),
                            ),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Excel'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 880,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ChoiceChip(
                          label: const Text('Все'),
                          selected:
                              selectedType == null && selectedIssue == null,
                          onSelected: (_) => setDialogState(() {
                            selectedType = null;
                            selectedIssue = null;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('AR'),
                          selected: selectedType == DebtType.ar,
                          onSelected: (_) => setDialogState(() {
                            selectedType = DebtType.ar;
                            selectedIssue = null;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('AP'),
                          selected: selectedType == DebtType.ap,
                          onSelected: (_) => setDialogState(() {
                            selectedType = DebtType.ap;
                            selectedIssue = null;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Просрочено'),
                          selected:
                              selectedIssue == _DebtRegisterIssueFilter.overdue,
                          onSelected: (_) => setDialogState(
                            () => selectedIssue = selectedIssue ==
                                    _DebtRegisterIssueFilter.overdue
                                ? null
                                : _DebtRegisterIssueFilter.overdue,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Лимит'),
                          selected: selectedIssue ==
                              _DebtRegisterIssueFilter.limitExceeded,
                          onSelected: (_) => setDialogState(
                            () => selectedIssue = selectedIssue ==
                                    _DebtRegisterIssueFilter.limitExceeded
                                ? null
                                : _DebtRegisterIssueFilter.limitExceeded,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('AR 90+'),
                          selected: selectedIssue ==
                              _DebtRegisterIssueFilter.ar90Plus,
                          onSelected: (_) => setDialogState(() {
                            selectedType = DebtType.ar;
                            selectedIssue = selectedIssue ==
                                    _DebtRegisterIssueFilter.ar90Plus
                                ? null
                                : _DebtRegisterIssueFilter.ar90Plus;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    if (rows.isEmpty)
                      const Text('Погашения не найдены')
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                '${row.counterpartyName.isEmpty ? row.debtId : row.counterpartyName} · ${row.debtType.label}',
                              ),
                              subtitle: Text(
                                '${row.accountTitle.isEmpty ? '—' : row.accountTitle} · ${row.description.isEmpty ? row.paymentTransactionId : row.description} · ${row.createdAt == null ? '—' : dateTimeFormat('dd.MM.yyyy', row.createdAt)}',
                              ),
                              trailing: Text(_formatMoney(row.amount)),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _balanceGroupCard(
    _BalanceGroup group, {
    bool compact = false,
    bool showTitle = true,
    Map<String, double> manualValues = const <String, double>{},
  }) {
    final resolvedGroupTotal = _groupResolvedTotal(
      group,
      manualValues: manualValues,
    );
    final padding = compact ? EdgeInsets.all(12.0) : EdgeInsets.all(16.0);
    final headerSpacing = compact ? 8.0 : 12.0;
    final footerSpacing = compact ? 6.0 : 12.0;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.title,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                  ),
                ),
                if (group.total != null || resolvedGroupTotal != 0)
                  Text(
                    _formatValue(resolvedGroupTotal),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                  ),
              ],
            ),
            SizedBox(height: headerSpacing),
          ],
          ...group.sections
              .map((section) => _balanceSectionTile(section, manualValues)),
          if (group.footerRows.isNotEmpty) ...[
            SizedBox(height: footerSpacing),
            _balanceRows(
              group.footerRows,
              manualValues: manualValues,
              totalOverride: resolvedGroupTotal,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalancePanel(
    _BalanceGroup group, {
    Map<String, double> manualValues = const <String, double>{},
  }) {
    final total = _groupResolvedTotal(
      group,
      manualValues: manualValues,
    );
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        collapsedIconColor: Colors.grey,
        title: Row(
          children: [
            Expanded(
              child: Text(
                group.title,
                style: FlutterFlowTheme.of(context).bodyLarge.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      fontSize: 16.0,
                    ),
              ),
            ),
            _balanceValueWidget(total, isBold: true),
          ],
        ),
        children: [
          const SizedBox(height: 8.0),
          _balanceGroupCard(
            group,
            compact: true,
            showTitle: false,
            manualValues: manualValues,
          ),
          const SizedBox(height: 8.0),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openJournalForGroup(group),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Журнал'),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }

  Widget _balanceSectionTile(
    _BalanceSection section,
    Map<String, double> manualValues,
  ) {
    final sectionTotal = _rowsResolvedTotal(
      section.rows,
      manualValues: manualValues,
      skipTotalRows: true,
    );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          section.title,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                font: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
              ),
        ),
        children: [
          _balanceRows(
            section.rows,
            manualValues: manualValues,
            totalOverride: sectionTotal,
          ),
        ],
      ),
    );
  }

  Widget _balanceRows(
    List<_BalanceRow> rows, {
    int depth = 0,
    Map<String, double> manualValues = const <String, double>{},
    double? totalOverride,
  }) {
    return Column(
      children: rows
          .map((row) => _balanceRow(
                row,
                depth: depth,
                manualValues: manualValues,
                valueOverride: row.isTotal ? totalOverride : null,
              ))
          .toList(),
    );
  }

  Widget _balanceRow(
    _BalanceRow row, {
    int depth = 0,
    Map<String, double> manualValues = const <String, double>{},
    double? valueOverride,
  }) {
    final left = 8.0 + (depth * 16.0);
    final labelStyle = _labelTextStyle(row.isTotal);
    final manualValue = _manualValueFor(manualValues, row);
    final displayValue = valueOverride ?? row.value ?? manualValue;
    return Column(
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(left, 6.0, 8.0, 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  row.allowManualInput &&
                          row.value == null &&
                          manualValue != null
                      ? '${row.label} (ручн.)'
                      : row.label,
                  style: labelStyle,
                ),
              ),
              displayValue != null
                  ? InkWell(
                      borderRadius: BorderRadius.circular(8.0),
                      onTap: row.value != null
                          ? () => _openJournalForRow(row)
                          : row.allowManualInput
                              ? () => _showManualValueDialog(row)
                              : null,
                      child: _balanceValueWidget(
                        displayValue,
                        isBold: row.isTotal,
                      ),
                    )
                  : row.allowManualInput
                      ? TextButton.icon(
                          onPressed: () => _showManualValueDialog(row),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Ввести'),
                        )
                      : Text(
                          '—',
                          style: labelStyle,
                        ),
            ],
          ),
        ),
        if (row.children.isNotEmpty)
          _balanceRows(
            row.children,
            depth: depth + 1,
            manualValues: manualValues,
          ),
      ],
    );
  }
}
