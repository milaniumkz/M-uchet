import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/custom_code/widgets/permissions_helper.dart';
import '/custom_code/widgets/editing_helper.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/money/component/add_tranzaction/add_tranzaction_widget.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/app_money_format.dart';
import '/utils/country_profile.dart';
import '/utils/transaction_sync.dart';
import '/utils/export_transactions.dart';
import '/utils/effective_company_support.dart';
import '/utils/income_exclusion_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/money_flow_type.dart';
import '/utils/owner_investment_support.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'tranzaction_model.dart';
export 'tranzaction_model.dart';

class TranzactionWidget extends StatefulWidget {
  const TranzactionWidget({
    super.key,
    this.mode = 'analytics',
    this.initialFilters,
  });

  static String routeName = 'tranzaction';
  static String routePath = '/tranzaction';
  final String mode;
  final Map<String, String>? initialFilters;

  @override
  State<TranzactionWidget> createState() => _TranzactionWidgetState();
}

class _TranzactionWidgetState extends State<TranzactionWidget> {
  late TranzactionModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _warnedCompanyLimit = false;
  final Map<LedgerScope, DateTimeRange?> _rangeByLedgerScope = {
    LedgerScope.both: null,
    LedgerScope.management: null,
    LedgerScope.accounting: null,
  };
  bool _initialFiltersApplied = false;
  final Map<LedgerScope, String> _typeFilterByLedgerScope = {
    LedgerScope.both: 'all',
    LedgerScope.management: 'all',
    LedgerScope.accounting: 'all',
  };
  final Map<LedgerScope, String> _statusFilterByLedgerScope = {
    LedgerScope.both: 'all',
    LedgerScope.management: 'all',
    LedgerScope.accounting: 'all',
  };
  final Map<LedgerScope, String> _flowFilterByLedgerScope = {
    LedgerScope.both: 'all',
    LedgerScope.management: 'all',
    LedgerScope.accounting: 'all',
  };
  final Map<LedgerScope, String> _categoryFilterByLedgerScope = {
    LedgerScope.both: 'all',
    LedgerScope.management: 'all',
    LedgerScope.accounting: 'all',
  };
  final Map<LedgerScope, String> _counterpartyFilterByLedgerScope = {
    LedgerScope.both: 'all',
    LedgerScope.management: 'all',
    LedgerScope.accounting: 'all',
  };
  final Map<LedgerScope, String> _obligationFilterByLedgerScope = {
    LedgerScope.both: 'all',
    LedgerScope.management: 'all',
    LedgerScope.accounting: 'all',
  };
  final Map<LedgerScope, bool> _journalListExpandedByLedgerScope = {
    LedgerScope.both: false,
    LedgerScope.management: false,
    LedgerScope.accounting: false,
  };
  String _ownerInvestmentRepairKey = '';
  List<List<String>> _exportRows = const [];
  String _journalCurrencyCode = 'KZT';
  String _journalCurrencyCompanyId = '';
  bool get _isJournalMode => widget.mode == 'journal';

  String _sectionKeyForScope(LedgerScope scope) {
    switch (scope) {
      case LedgerScope.management:
        return 'Up1';
      case LedgerScope.accounting:
        return 'Bu';
      case LedgerScope.both:
        return 'Up';
    }
  }

  String _displayLedgerLabel(String? rawValue) {
    return ledgerScopeFromLegacyValue(rawValue).shortLabel;
  }

  String _displayLedgerLabelForTransaction(TranzactionRecord item) {
    return _displayLedgerLabel(
      item.ledgerScope.isNotEmpty ? item.ledgerScope : item.typeUchet,
    );
  }

  String _displayMoneyFlowLabelForTransaction(TranzactionRecord item) {
    if (_isOwnerInvestmentTransaction(item)) {
      return ownerInvestmentDisplayLabel;
    }
    return item.moneyFlowTypeEnum.label;
  }

  IconData _iconForMoneyFlow(MoneyFlowType flowType) {
    switch (flowType) {
      case MoneyFlowType.operating:
        return Icons.sync_alt_rounded;
      case MoneyFlowType.investing:
        return Icons.precision_manufacturing_outlined;
      case MoneyFlowType.financing:
        return Icons.account_balance_outlined;
      case MoneyFlowType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _accentForMoneyFlow(MoneyFlowType flowType) {
    switch (flowType) {
      case MoneyFlowType.operating:
        return const Color(0xFF2563EB);
      case MoneyFlowType.investing:
        return const Color(0xFF7C3AED);
      case MoneyFlowType.financing:
        return const Color(0xFF0F766E);
      case MoneyFlowType.transfer:
        return const Color(0xFFB45309);
    }
  }

  List<LedgerScope> _targetScopes(String? typeUchet) {
    final filterScope = ledgerScopeFromLegacyValue(typeUchet);
    switch (filterScope) {
      case LedgerScope.both:
        return const [
          LedgerScope.both,
          LedgerScope.management,
          LedgerScope.accounting,
        ];
      case LedgerScope.management:
        return const [LedgerScope.management];
      case LedgerScope.accounting:
        return const [LedgerScope.accounting];
    }
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
          const SnackBar(
            content: Text(
                'Слишком много компаний для режима "Все". Показаны первые 10.'),
          ),
        );
      });
    }
    final limited = ids.length > 10 ? ids.take(10).toList() : ids;
    return query.where('idCompany', whereIn: limited);
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TranzactionModel());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialFilters();
      safeSetState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant TranzactionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilters != oldWidget.initialFilters) {
      _initialFiltersApplied = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyInitialFilters();
        safeSetState(() {});
      });
    }
  }

  void _applyInitialFilters() {
    if (_initialFiltersApplied) return;
    final filters = widget.initialFilters;
    if (filters == null || filters.isEmpty) {
      _initialFiltersApplied = true;
      return;
    }

    final scopes = _targetScopes(filters['typeUchet']);
    final flowValue = filters['flow'] ?? filters['moneyFlowType'];
    for (final scope in scopes) {
      _setIfNotEmpty(_typeFilterByLedgerScope, scope, filters['type']);
      _setIfNotEmpty(_statusFilterByLedgerScope, scope, filters['status']);
      _setIfNotEmpty(_flowFilterByLedgerScope, scope, flowValue);
      _setIfNotEmpty(_categoryFilterByLedgerScope, scope, filters['category']);
      _setIfNotEmpty(
          _counterpartyFilterByLedgerScope, scope, filters['counterparty']);
      _setIfNotEmpty(
          _obligationFilterByLedgerScope, scope, filters['obligation']);
    }

    _initialFiltersApplied = true;
  }

  void _setIfNotEmpty(
    Map<LedgerScope, String> map,
    LedgerScope ledgerScope,
    String? value,
  ) {
    final trimmed = value?.trim();
    if (trimmed?.isNotEmpty ?? false) {
      map[ledgerScope] = trimmed!;
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String _formatMoney(num? value) {
    return formatMoneyWithCurrency(
      value,
      currencyCode: _journalCurrencyCode,
    );
  }

  String _formatOriginalMoney(TranzactionRecord item) {
    return formatMoneyWithCurrency(
      item.amountOriginal,
      currencyCode: item.currencyOriginal,
    );
  }

  double _companyAmount(TranzactionRecord item) => item.amountCompany;

  double _contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final bright = max(l1, l2);
    final dark = min(l1, l2);
    return (bright + 0.05) / (dark + 0.05);
  }

  Color _safeTextOn(Color background,
      {Color? preferred, bool secondary = false}) {
    final fallback = background.computeLuminance() > 0.55
        ? (secondary ? const Color(0xFF64748B) : const Color(0xFF0F172A))
        : (secondary ? const Color(0xFFCBD5E1) : Colors.white);
    if (preferred == null) return fallback;
    final minRatio = secondary ? 3.0 : 4.5;
    if (_contrastRatio(preferred, background) >= minRatio) {
      return preferred;
    }
    return fallback;
  }

  Widget _buildExportButton() {
    return FFButtonWidget(
      onPressed: () async {
        if (_exportRows.isEmpty || _exportRows.length == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет данных для экспорта')),
          );
          return;
        }
        final now = DateTime.now();
        final filename = 'transactions_${now.year}-${now.month}-${now.day}.csv';
        await exportTransactionsCsv(
          filename: filename,
          rows: _exportRows,
        );
      },
      text: 'Экспорт',
      icon: const Icon(
        Icons.download,
        size: 16.0,
      ),
      options: FFButtonOptions(
        height: 40.0,
        padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
        iconPadding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
        color: const Color(0xFF0F766E),
        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
              font: GoogleFonts.interTight(
                fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
              ),
              color: FlutterFlowTheme.of(context).secondaryBackground,
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
            ),
        elevation: 0.0,
        borderRadius: BorderRadius.circular(8.0),
      ),
    );
  }

  String _effectiveCompanyId() {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: currentUserUid,
    );
  }

  void _ensureJournalCurrencyLoaded() {
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty || companyId == _journalCurrencyCompanyId) return;
    _journalCurrencyCompanyId = companyId;
    unawaited(_loadJournalCurrency(companyId));
  }

  Future<void> _loadJournalCurrency(String companyId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('company_profile')
          .doc(companyId)
          .get(const GetOptions(source: Source.serverAndCache));
      final data = snap.data() ?? const <String, dynamic>{};
      final profile = countryProfileFromData(data);
      final currency = companyCurrencyFromProfileData(
        data,
        fallback: profile.baseCurrency,
      );
      if (!mounted || currency == _journalCurrencyCode) return;
      setState(() => _journalCurrencyCode = currency);
    } catch (_) {}
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '—';
    }
    return dateTimeFormat(
      'd/M/y',
      date,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  Future<void> _pickDateRangeFor(LedgerScope ledgerScope) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _rangeByLedgerScope[ledgerScope],
    );
    if (picked != null) {
      setState(() {
        _rangeByLedgerScope[ledgerScope] = picked;
      });
    }
  }

  String _rangeLabel(DateTimeRange? range) {
    if (range == null) {
      return 'Все время';
    }
    final start = range.start;
    final end = range.end;
    return '${_formatDate(start)} — ${_formatDate(end)}';
  }

  bool _isIncomeType(String type) {
    final t = type.toLowerCase().trim();
    return t == 'income' || t == 'доход' || t == 'doxod';
  }

  bool _isExpenseType(String type) {
    final t = type.toLowerCase().trim();
    return t == 'decome' || t == 'expense' || t == 'расход' || t == 'rashod';
  }

  bool _isOwnerInvestmentTransaction(TranzactionRecord item) {
    return isOwnerInvestmentTransaction(item);
  }

  bool _isVisibleIncomeTransaction(TranzactionRecord item) {
    return _isIncomeType(item.type) && !_isOwnerInvestmentTransaction(item);
  }

  bool _isCompanyIncomeTransaction(TranzactionRecord item) {
    return _isVisibleIncomeTransaction(item) && !isExcludedCompanyIncome(item);
  }

  bool _isVisibleExpenseTransaction(TranzactionRecord item) {
    return _isExpenseType(item.type) && !_isOwnerInvestmentTransaction(item);
  }

  String _displayTransactionType(TranzactionRecord item) {
    if (_isOwnerInvestmentTransaction(item)) {
      return ownerInvestmentDisplayLabel;
    }
    return _isIncomeType(item.type) ? 'Доход' : 'Расход';
  }

  void _ensureOwnerInvestmentNormalization() {
    final ids = _companyIdsForQuery();
    final key = ids.join('|');
    if (ids.isEmpty || key == _ownerInvestmentRepairKey) return;
    _ownerInvestmentRepairKey = key;
    Future(() async {
      var changed = false;
      for (final companyId in ids) {
        changed = await ensureOwnerInvestmentsNormalizedForCompany(
              firestore: FirebaseFirestore.instance,
              companyId: companyId,
            ) ||
            changed;
      }
      if (changed && mounted) {
        safeSetState(() {});
      }
    });
  }

  bool _isTaxTransaction(TranzactionRecord item) {
    final category = item.kat.toLowerCase().trim();
    final text = item.text.toLowerCase().trim();
    return category.contains('налог') ||
        category.contains('ндс') ||
        category.contains('kpn') ||
        text.contains('налог') ||
        text.contains('ндс') ||
        text.contains('kpn');
  }

  String _totalSubtitleFor(LedgerScope ledgerScope) {
    return 'Общий итог (${ledgerScope.shortLabel})';
  }

  Widget _detailRow(String label, String value, {num? amount}) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    color: amountTextColor(
                      context,
                      amount,
                      positiveColor: FlutterFlowTheme.of(context).primaryText,
                    ),
                    fontSize: 12.0,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    num? amount,
    required String subtitle,
    required Color borderColor,
    required Color fillColor,
    required Color accent,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final titleColor = _safeTextOn(fillColor);
    final subtitleColor = _safeTextOn(
      fillColor,
      preferred: FlutterFlowTheme.of(context).secondaryText,
      secondary: true,
    );
    final valueColor = isNegativeAmount(amount)
        ? amountTextColor(context, amount)
        : _safeTextOn(fillColor, preferred: accent);
    final card = Container(
      width: double.infinity,
      constraints: BoxConstraints(minWidth: 140.0),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                          fontSize: 12.0,
                          color: titleColor,
                        ),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: valueColor,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w700,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        fontSize: 12.0,
                      ),
                ),
                SizedBox(width: 6.0),
                Icon(icon, color: valueColor, size: 16.0),
              ],
            ),
            SizedBox(height: 4.0),
            Text(
              subtitle,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    color: subtitleColor,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w500,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    fontSize: 10.0,
                  ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) {
      return card;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _buildTransactionList(
    List<TranzactionRecord> items,
    bool isMobile,
  ) {
    final canEdit = PermissionsHelper.has('tranzaction.edit');
    final canDeletePerm = PermissionsHelper.has('tranzaction.delete');
    final editingAllowed =
        EditingHelper.canEditExisting(section: EditSection.transactions);
    if (items.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
          ),
        ),
        child: Text(
          'Транзакций пока нет. Добавьте первую.',
          style: FlutterFlowTheme.of(context).bodyMedium,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _transactionTile(
          item: item,
          isMobile: isMobile,
          canEdit: canEdit && editingAllowed,
          canDeletePerm: canDeletePerm && editingAllowed,
        );
      },
    );
  }

  Widget _transactionTile({
    required TranzactionRecord item,
    required bool isMobile,
    required bool canEdit,
    required bool canDeletePerm,
  }) {
    final isOwnerInvestment = _isOwnerInvestmentTransaction(item);
    final isIncome = _isVisibleIncomeTransaction(item) || isOwnerInvestment;
    final statusLabel = item.status.isEmpty ? 'Проведена' : item.status;
    final canDelete = true;
    final directionLabel = isIncome ? 'Откуда пришло' : 'Куда ушло';
    final directionValue = item.schetTitle.isNotEmpty ? item.schetTitle : '—';
    final iconColor = isOwnerInvestment
        ? const Color(0xFF0F766E)
        : isIncome
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10.0 : 12.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('transaction_${item.reference.id}'),
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: isMobile ? 8.0 : 10.0,
          ),
          childrenPadding: EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 6.0,
          ),
          collapsedIconColor: iconColor,
          iconColor: iconColor,
          title: Row(
            children: [
              Container(
                width: isMobile ? 32.0 : 34.0,
                height: isMobile ? 32.0 : 34.0,
                decoration: BoxDecoration(
                  color: isOwnerInvestment
                      ? const Color(0xFFE6FFFB)
                      : isIncome
                          ? const Color(0xFFE9F9F0)
                          : const Color(0xFFFDF1F1),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(
                  isOwnerInvestment
                      ? Icons.account_balance_outlined
                      : isIncome
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                  color: iconColor,
                  size: 18.0,
                ),
              ),
              SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  item.text,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w700,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ),
              Text(
                _formatMoney(_companyAmount(item)),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: iconColor,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w700,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
            ],
          ),
          children: [
            Wrap(
              spacing: 8.0,
              runSpacing: 6.0,
              children: [
                _buildChip(_formatDate(item.date)),
                _buildChip(_displayMoneyFlowLabelForTransaction(item)),
                _buildChip(item.kat),
                _buildChip(item.counterparty),
                _buildChip(item.schetTitle),
                _buildChip(_displayLedgerLabelForTransaction(item)),
                _buildChip(item.obligationTitle),
                _buildChip(statusLabel),
              ],
            ),
            const SizedBox(height: 8.0),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).primaryBackground,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Color(0xFFEAECF0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Подробнее о транзакции контрагента',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4.0),
                  _detailRow(
                    'Компания',
                    item.counterparty.isEmpty ? '—' : item.counterparty,
                  ),
                  _detailRow(
                    'Тип контрагента',
                    _counterpartyType(item),
                  ),
                  _detailRow(directionLabel, directionValue),
                ],
              ),
            ),
            const SizedBox(height: 6.0),
            _detailRow('Категория', item.kat),
            _detailRow('Тип', _displayTransactionType(item)),
            _detailRow('Поток', _displayMoneyFlowLabelForTransaction(item)),
            _detailRow('Учет', _displayLedgerLabelForTransaction(item)),
            _detailRow('Статус', statusLabel),
            _detailRow('Сумма', _formatMoney(_companyAmount(item)),
                amount: _companyAmount(item)),
            if (item.currencyOriginal.isNotEmpty &&
                item.currencyOriginal != item.companyCurrency)
              _detailRow('Сумма в валюте счета', _formatOriginalMoney(item),
                  amount: item.amountOriginal),
            _detailRow('Дата', _formatDate(item.date)),
            if (item.paymentPeriod.isNotEmpty)
              _detailRow('Период', item.paymentPeriod),
            _detailRow('Счет', item.schetTitle),
            if (item.comment.isNotEmpty)
              _detailRow('Комментарий', item.comment),
            _detailRow(
              _isVisibleExpenseTransaction(item) ? 'Зачет' : 'Облагаемый доход',
              _isVisibleExpenseTransaction(item)
                  ? (item.deductible ? 'Да' : 'Нет')
                  : (item.taxable ? 'Да' : 'Нет'),
            ),
            if (item.nds && !_isVisibleExpenseTransaction(item))
              _detailRow(
                'Сумма НДС',
                _formatMoney(item.summaNds),
                amount: item.summaNds,
              ),
            if (item.obligationTitle.isNotEmpty)
              _detailRow('Обязательств', item.obligationTitle),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canEdit)
                  IconButton(
                    onPressed: () async {
                      if (!EditingHelper.guardEdit(context,
                          section: EditSection.transactions)) return;
                      await showDialog(
                        context: context,
                        builder: (context) {
                          return _EditTransactionDialog(
                            record: item,
                          );
                        },
                      );
                    },
                    icon: Icon(
                      Icons.edit,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                if (canDelete && canDeletePerm)
                  IconButton(
                    onPressed: () => _confirmDelete(item),
                    icon: Icon(
                      Icons.delete,
                      color: Color(0xFFDC2626),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _counterpartyType(TranzactionRecord item) {
    final saved = (item.snapshotData['counterparty_type'] ??
            item.snapshotData['counterpartyType'] ??
            '')
        .toString()
        .trim();
    if (saved.isNotEmpty) return saved;
    final counterparty = item.counterparty;
    if (counterparty.isEmpty) return 'ФЛ';
    final upper = counterparty.toUpperCase();
    if (upper.contains('ГОС') ||
        upper.contains('НАЛОГ') ||
        upper.contains('БЮДЖЕТ') ||
        upper.contains('КАЗНА') ||
        upper.contains('ПРАВИТЕЛЬСТВО') ||
        upper.contains('МИНИСТЕРСТВО') ||
        upper.contains('КОМИТЕТ')) {
      return 'Государство';
    }
    if (upper.contains('ИП') || upper.contains('ФЛ')) {
      return 'ФЛ';
    }
    if (upper.contains('ТОО') ||
        upper.contains('ООО') ||
        upper.contains('АО')) {
      return 'Компания';
    }
    return 'Компания';
  }

  Widget _buildUchetAnalyticsSection({
    required String title,
    required LedgerScope ledgerScope,
    required Color tint,
    required Color borderColor,
    required List<TranzactionRecord> items,
  }) {
    final sectionKey = _sectionKeyForScope(ledgerScope);
    final canFilter = PermissionsHelper.has('tranzaction.filter');
    final range = _rangeByLedgerScope[ledgerScope];
    final filteredItems = items.where((e) {
      if (!ledgerScopeMatchesFilter(
        rawValue: e.ledgerScope.isNotEmpty ? e.ledgerScope : e.typeUchet,
        rawFilter: sectionKey,
      )) {
        return false;
      }
      if (range != null) {
        final start =
            DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        final date = e.date;
        if (date == null || date.isBefore(start) || date.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList();
    final incomeTotal = filteredItems
        .where((e) => _isCompanyIncomeTransaction(e))
        .fold<double>(0, (total, e) => total + _companyAmount(e));
    final taxesTotal = filteredItems
        .where((e) => _isVisibleExpenseTransaction(e) && _isTaxTransaction(e))
        .fold<double>(0, (total, e) => total + _companyAmount(e));
    final expenseTotal = filteredItems
        .where((e) => _isVisibleExpenseTransaction(e) && !_isTaxTransaction(e))
        .fold<double>(0, (total, e) => total + _companyAmount(e));
    final netProfit = incomeTotal - expenseTotal - taxesTotal;
    final total = filteredItems.fold<double>(
        0, (totalAmount, e) => totalAmount + _companyAmount(e));
    final count = filteredItems.length;
    final sectionTitleColor = _safeTextOn(tint);
    final sectionMetaColor = _safeTextOn(
      tint,
      preferred: FlutterFlowTheme.of(context).secondaryText,
    );

    return Container(
      margin: EdgeInsets.only(bottom: 12.0),
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        font: GoogleFonts.interTight(
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .titleMedium
                              .fontStyle,
                        ),
                        color: sectionTitleColor,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleMedium.fontStyle,
                      ),
                ),
              ),
              if (canFilter)
                TextButton.icon(
                  onPressed: () => _pickDateRangeFor(ledgerScope),
                  icon: Icon(
                    Icons.calendar_month,
                    size: 14.0,
                    color: sectionMetaColor,
                  ),
                  label: Text(
                    _rangeLabel(range),
                    style: TextStyle(
                      color: sectionMetaColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.0),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final cardWidth =
                  isNarrow ? double.infinity : (constraints.maxWidth / 2) - 6;
              return Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Доходы',
                      value: _formatMoney(incomeTotal),
                      amount: incomeTotal,
                      subtitle: 'Поступления периода',
                      borderColor: const Color(0xFFBBF7D0),
                      fillColor: const Color(0xFFF0FDF4),
                      accent: const Color(0xFF16A34A),
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Расходы',
                      value: _formatMoney(expenseTotal),
                      amount: -expenseTotal,
                      subtitle: 'Операционные и прочие расходы',
                      borderColor: const Color(0xFFFED7AA),
                      fillColor: const Color(0xFFFFF7ED),
                      accent: const Color(0xFFB45309),
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Налоги',
                      value: _formatMoney(taxesTotal),
                      amount: -taxesTotal,
                      subtitle: 'Налоговые платежи',
                      borderColor: const Color(0xFFBFDBFE),
                      fillColor: const Color(0xFFEFF6FF),
                      accent: const Color(0xFF2563EB),
                      icon: Icons.account_balance_outlined,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Чистая прибыль',
                      value: _formatMoney(netProfit),
                      amount: netProfit,
                      subtitle: 'Доходы - Расходы - Налоги',
                      borderColor: const Color(0xFFE5E7EB),
                      fillColor: const Color(0xFFF8FAFC),
                      accent: netProfit >= 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Кол-во',
                      value: '$count',
                      subtitle: 'Транзакций',
                      borderColor: const Color(0xFF94A3B8),
                      fillColor: const Color(0xFFF8FAFC),
                      accent: const Color(0xFF334155),
                      icon: Icons.list_alt,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Сумма',
                      value: _formatMoney(total),
                      amount: total,
                      subtitle: _totalSubtitleFor(ledgerScope),
                      borderColor: const Color(0xFFE5E7EB),
                      fillColor: const Color(0xFFFFFFFF),
                      accent: const Color(0xFF111827),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUchetJournalSection({
    required String title,
    required LedgerScope ledgerScope,
    required Color tint,
    required Color borderColor,
    required bool isMobile,
    required List<TranzactionRecord> items,
    required List<String> categories,
    required List<String> counterparties,
    required List<String> obligations,
  }) {
    final sectionKey = _sectionKeyForScope(ledgerScope);
    final canAdd = PermissionsHelper.has('tranzaction.add');
    final canFilter = PermissionsHelper.has('tranzaction.filter');
    final range = _rangeByLedgerScope[ledgerScope];
    final typeFilter = _typeFilterByLedgerScope[ledgerScope] ?? 'all';
    final statusFilter = _statusFilterByLedgerScope[ledgerScope] ?? 'all';
    final flowFilter = _flowFilterByLedgerScope[ledgerScope] ?? 'all';
    final categoryFilter = _categoryFilterByLedgerScope[ledgerScope] ?? 'all';
    final counterpartyFilter =
        _counterpartyFilterByLedgerScope[ledgerScope] ?? 'all';
    final obligationFilter =
        _obligationFilterByLedgerScope[ledgerScope] ?? 'all';

    bool matchesStatus(TranzactionRecord e) {
      final status = e.status.isEmpty ? 'Проведена' : e.status;
      if (statusFilter == 'all') {
        return true;
      }
      return status == statusFilter;
    }

    final filteredItems = items.where((e) {
      if (!ledgerScopeMatchesFilter(
        rawValue: e.ledgerScope.isNotEmpty ? e.ledgerScope : e.typeUchet,
        rawFilter: sectionKey,
      )) {
        return false;
      }
      if (range != null) {
        final start =
            DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        final date = e.date;
        if (date == null || date.isBefore(start) || date.isAfter(end)) {
          return false;
        }
      }
      if (typeFilter != 'all') {
        if (typeFilter == 'income' && !_isVisibleIncomeTransaction(e)) {
          return false;
        }
        if (typeFilter == 'decome' && !_isVisibleExpenseTransaction(e)) {
          return false;
        }
      }
      if (!matchesStatus(e)) {
        return false;
      }
      if (flowFilter != 'all' &&
          e.moneyFlowTypeEnum.storageValue != flowFilter) {
        return false;
      }
      if (categoryFilter != 'all' && e.kat != categoryFilter) {
        return false;
      }
      if (counterpartyFilter != 'all' && e.counterparty != counterpartyFilter) {
        return false;
      }
      if (obligationFilter != 'all' && e.obligationTitle != obligationFilter) {
        return false;
      }
      return true;
    }).toList();

    final count = filteredItems.length;
    final sectionTitleColor = _safeTextOn(tint);
    final sectionMetaColor = _safeTextOn(
      tint,
      preferred: FlutterFlowTheme.of(context).secondaryText,
      secondary: true,
    );
    final actionColor =
        _safeTextOn(tint, preferred: FlutterFlowTheme.of(context).primary);
    final filterSurface = Color.alphaBlend(
      Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.06,
      ),
      tint,
    );
    final filterTextColor = _safeTextOn(filterSurface);
    final filterHintColor = _safeTextOn(
      filterSurface,
      preferred: FlutterFlowTheme.of(context).secondaryText,
      secondary: true,
    );
    final listExpanded =
        _journalListExpandedByLedgerScope[ledgerScope] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 16.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FlutterFlowTheme.of(context).headlineSmall.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FontWeight.w600,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineSmall
                            .fontStyle,
                      ),
                      color: sectionTitleColor,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                    ),
              ),
            ],
          ),
          SizedBox(height: 12.0),
          if (canFilter) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Период',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                              ),
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                              color: sectionMetaColor,
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      SizedBox(
                        height: 40.0,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDateRangeFor(ledgerScope),
                          icon: Icon(
                            Icons.calendar_month,
                            size: 16.0,
                            color: actionColor,
                          ),
                          label: Text(
                            _rangeLabel(range),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(),
                                  color: actionColor,
                                  letterSpacing: 0.0,
                                ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Color.alphaBlend(
                                actionColor.withValues(alpha: 0.28),
                                borderColor,
                              ),
                            ),
                            foregroundColor: actionColor,
                            backgroundColor: filterSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (ledgerScope != LedgerScope.both && canAdd)
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: FFButtonWidget(
                      onPressed: () async {
                        await showModalBottomSheet(
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          enableDrag: false,
                          context: context,
                          builder: (context) {
                            return GestureDetector(
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                              child: Padding(
                                padding: MediaQuery.viewInsetsOf(context),
                                child: Container(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.8,
                                  child: AddTranzactionWidget(
                                    initialTypeUchet: sectionKey,
                                  ),
                                ),
                              ),
                            );
                          },
                        ).then((value) => safeSetState(() {}));
                      },
                      text: 'Добавить',
                      icon: Icon(
                        Icons.add,
                        size: 16.0,
                      ),
                      options: FFButtonOptions(
                        height: 40.0,
                        padding: EdgeInsetsDirectional.fromSTEB(
                            16.0, 0.0, 16.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color: _safeTextOn(
                                    FlutterFlowTheme.of(context).primary,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                        elevation: 0.0,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12.0),
            LayoutBuilder(
              builder: (context, constraints) {
                final filterWidth = isMobile
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 8.0) / 2;
                return Wrap(
                  spacing: 8.0,
                  runSpacing: 12.0,
                  children: [
                    SizedBox(
                      width: filterWidth,
                      child: _filterDropdown(
                        label: 'Тип операции',
                        value: typeFilter,
                        options: const ['all', 'income', 'decome'],
                        labels: const {
                          'all': 'Все',
                          'income': 'Доходы',
                          'decome': 'Расходы',
                        },
                        labelColor: sectionMetaColor,
                        fillColor: filterSurface,
                        textColor: filterTextColor,
                        hintColor: filterHintColor,
                        borderColor: borderColor,
                        onChanged: (val) => setState(() =>
                            _typeFilterByLedgerScope[ledgerScope] =
                                val ?? 'all'),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: _filterDropdown(
                        label: 'Поток',
                        value: flowFilter,
                        options: const [
                          'all',
                          'operating',
                          'investing',
                          'financing',
                          'transfer',
                        ],
                        labels: const {
                          'all': 'Все',
                          'operating': 'Operating',
                          'investing': 'Investing',
                          'financing': 'Financing',
                          'transfer': 'Transfer',
                        },
                        labelColor: sectionMetaColor,
                        fillColor: filterSurface,
                        textColor: filterTextColor,
                        hintColor: filterHintColor,
                        borderColor: borderColor,
                        onChanged: (val) => setState(() =>
                            _flowFilterByLedgerScope[ledgerScope] =
                                val ?? 'all'),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: _filterDropdown(
                        label: 'Статус',
                        value: statusFilter,
                        options: const ['all', 'Проведена', 'Не проведена'],
                        labels: const {
                          'all': 'Все',
                          'Проведена': 'Проведенные',
                          'Не проведена': 'Не проведенные',
                        },
                        labelColor: sectionMetaColor,
                        fillColor: filterSurface,
                        textColor: filterTextColor,
                        hintColor: filterHintColor,
                        borderColor: borderColor,
                        onChanged: (val) => setState(() =>
                            _statusFilterByLedgerScope[ledgerScope] =
                                val ?? 'all'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12.0),
            LayoutBuilder(
              builder: (context, constraints) {
                final filterWidth = isMobile
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24.0) / 3;
                return Wrap(
                  spacing: 12.0,
                  runSpacing: 12.0,
                  children: [
                    SizedBox(
                      width: filterWidth,
                      child: _filterDropdown(
                        label: 'Категория',
                        value: categoryFilter,
                        options: ['all', ...categories],
                        labelColor: sectionMetaColor,
                        fillColor: filterSurface,
                        textColor: filterTextColor,
                        hintColor: filterHintColor,
                        borderColor: borderColor,
                        onChanged: (val) => setState(() =>
                            _categoryFilterByLedgerScope[ledgerScope] =
                                val ?? 'all'),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: _filterDropdown(
                        label: 'Контрагент',
                        value: counterpartyFilter,
                        options: ['all', ...counterparties],
                        labelColor: sectionMetaColor,
                        fillColor: filterSurface,
                        textColor: filterTextColor,
                        hintColor: filterHintColor,
                        borderColor: borderColor,
                        onChanged: (val) => setState(() =>
                            _counterpartyFilterByLedgerScope[ledgerScope] =
                                val ?? 'all'),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: _filterDropdown(
                        label: 'Обязательств',
                        value: obligationFilter,
                        options: ['all', ...obligations],
                        labelColor: sectionMetaColor,
                        fillColor: filterSurface,
                        textColor: filterTextColor,
                        hintColor: filterHintColor,
                        borderColor: borderColor,
                        onChanged: (val) => setState(() =>
                            _obligationFilterByLedgerScope[ledgerScope] =
                                val ?? 'all'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12.0),
          ],
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                color: filterSurface,
                borderRadius: BorderRadius.circular(18.0),
                border: Border.all(
                  color: Color.alphaBlend(
                    actionColor.withValues(alpha: 0.18),
                    borderColor,
                  ),
                ),
              ),
              child: ExpansionTile(
                key: PageStorageKey('journal_list_$sectionKey'),
                maintainState: true,
                initiallyExpanded: false,
                onExpansionChanged: (value) {
                  setState(() =>
                      _journalListExpandedByLedgerScope[ledgerScope] = value);
                },
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 4.0,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  14.0,
                  0.0,
                  14.0,
                  12.0,
                ),
                iconColor: actionColor,
                collapsedIconColor: actionColor,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Платежи',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: sectionTitleColor,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w700,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: FlutterFlowTheme.of(context).labelMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .fontStyle,
                            ),
                            color: listExpanded
                                ? sectionTitleColor
                                : sectionMetaColor,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w700,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontStyle,
                          ),
                    ),
                  ],
                ),
                children: [
                  _buildTransactionList(filteredItems, isMobile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(TranzactionRecord record) async {
    if (!EditingHelper.guardEdit(context, section: EditSection.transactions)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить транзакцию?'),
          content: const Text('Действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Удалить',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await deleteEntriesByTransaction(
        firestore: FirebaseFirestore.instance,
        transactionId: record.reference.id,
      );
      await record.reference.delete();
      final companyId = _effectiveCompanyId();
      await TransactionSync.recomputeAllForCompany(companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final isMobile = MediaQuery.sizeOf(context).width < 900;

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
            model: _model.drawersUsersModel2,
            updateCallback: () => safeSetState(() {}),
            child: DrawersUsersWidget(),
          ),
        ),
        body: SafeArea(
          top: true,
          child: AuthUserStreamWidget(
            builder: (context) {
              _ensureJournalCurrencyLoaded();
              final canView = PermissionsHelper.has('tranzaction.view');
              final canExport = PermissionsHelper.has('tranzaction.export');
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
                              model: _model.drawersUsersModel1,
                              updateCallback: () => safeSetState(() {}),
                              child: DrawersUsersWidget(),
                            ),
                          ),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional(0.0, -1.0),
                            child: Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                maxWidth: 1170.0,
                              ),
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
                                                    color: FlutterFlowTheme.of(
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
                                                  title: _isJournalMode
                                                      ? 'Журнал платежей'
                                                      : 'Платежи',
                                                  trailing: canExport
                                                      ? _buildExportButton()
                                                      : const SizedBox.shrink(),
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
                                        builder: (context) {
                                          _ensureOwnerInvestmentNormalization();
                                          return StreamBuilder<
                                              List<TranzactionRecord>>(
                                            stream: queryTranzactionRecord(
                                              queryBuilder:
                                                  (tranzactionRecord) {
                                                var query = _applyCompanyFilter(
                                                    tranzactionRecord);
                                                return query.orderBy('date',
                                                    descending: true);
                                              },
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasError) {
                                                return Center(
                                                  child: Container(
                                                    constraints:
                                                        const BoxConstraints(
                                                            maxWidth: 720),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            20),
                                                    decoration: BoxDecoration(
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .secondaryBackground,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      border: Border.all(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          _isJournalMode
                                                              ? 'Не удалось загрузить журнал платежей'
                                                              : 'Не удалось загрузить платежи',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          '${snapshot.error}',
                                                          style: TextStyle(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 16),
                                                        OutlinedButton(
                                                          onPressed: () =>
                                                              safeSetState(
                                                                  () {}),
                                                          child: const Text(
                                                              'Повторить'),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }
                                              if (!snapshot.hasData) {
                                                return Center(
                                                  child: SizedBox(
                                                    width: 50.0,
                                                    height: 50.0,
                                                    child:
                                                        CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }

                                              final items = snapshot.data!;

                                              final analyticsSections = [
                                                _buildUchetAnalyticsSection(
                                                  title: 'Общий учет (О)',
                                                  ledgerScope: LedgerScope.both,
                                                  tint: Color(0xFFEFFDF4),
                                                  borderColor:
                                                      Color(0xFF86EFAC),
                                                  items: items,
                                                ),
                                                _buildUchetAnalyticsSection(
                                                  title: 'Упр. учет (С)',
                                                  ledgerScope:
                                                      LedgerScope.management,
                                                  tint: Color(0xFFF3F4F6),
                                                  borderColor:
                                                      Color(0xFFD1D5DB),
                                                  items: items,
                                                ),
                                                _buildUchetAnalyticsSection(
                                                  title: 'Бухгалтерский учет',
                                                  ledgerScope:
                                                      LedgerScope.accounting,
                                                  tint: Color(0xFFFFF1F2),
                                                  borderColor:
                                                      Color(0xFFFBCFE8),
                                                  items: items,
                                                ),
                                              ];

                                              Widget buildSections(
                                                  List<Widget> sections) {
                                                if (isMobile) {
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: sections,
                                                  );
                                                }
                                                final isWide =
                                                    MediaQuery.sizeOf(context)
                                                            .width >=
                                                        1000;
                                                if (!isWide) {
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: sections,
                                                  );
                                                }
                                                return Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                        child: sections[0]),
                                                    SizedBox(width: 8.0),
                                                    Expanded(
                                                        child: sections[1]),
                                                    SizedBox(width: 8.0),
                                                    Expanded(
                                                        child: sections[2]),
                                                  ],
                                                );
                                              }

                                              if (_isJournalMode) {
                                                final categories = items
                                                    .map((e) => e.kat)
                                                    .where((e) => e.isNotEmpty)
                                                    .toSet()
                                                    .toList()
                                                  ..sort();
                                                final counterparties = items
                                                    .map((e) => e.counterparty)
                                                    .where((e) => e.isNotEmpty)
                                                    .toSet()
                                                    .toList()
                                                  ..sort();
                                                final obligations = items
                                                    .map((e) =>
                                                        e.obligationTitle)
                                                    .where((e) => e.isNotEmpty)
                                                    .toSet()
                                                    .toList()
                                                  ..sort();

                                                _exportRows = [
                                                  [
                                                    'Дата',
                                                    'Тип',
                                                    'Поток',
                                                    'Учет',
                                                    'Категория',
                                                    'Счет',
                                                    'Контрагент',
                                                    'Сумма',
                                                    'Статус',
                                                    'Обязательств',
                                                  ],
                                                  ...items.map(
                                                    (e) => [
                                                      _formatDate(e.date),
                                                      _displayTransactionType(
                                                          e),
                                                      _displayMoneyFlowLabelForTransaction(
                                                        e,
                                                      ),
                                                      _displayLedgerLabel(
                                                        e.ledgerScope.isNotEmpty
                                                            ? e.ledgerScope
                                                            : e.typeUchet,
                                                      ),
                                                      e.kat,
                                                      e.schetTitle,
                                                      e.counterparty,
                                                      e.summa.toString(),
                                                      e.status.isEmpty
                                                          ? 'Проведена'
                                                          : e.status,
                                                      e.obligationTitle,
                                                    ],
                                                  ),
                                                ];

                                                final journalSections = [
                                                  _buildUchetJournalSection(
                                                    title: 'Общий учет (О)',
                                                    ledgerScope:
                                                        LedgerScope.both,
                                                    tint: Color(0xFFEFFDF4),
                                                    borderColor:
                                                        Color(0xFF86EFAC),
                                                    isMobile: isMobile,
                                                    items: items,
                                                    categories: categories,
                                                    counterparties:
                                                        counterparties,
                                                    obligations: obligations,
                                                  ),
                                                  _buildUchetJournalSection(
                                                    title: 'Упр. учет (С)',
                                                    ledgerScope:
                                                        LedgerScope.management,
                                                    tint: Color(0xFFF3F4F6),
                                                    borderColor:
                                                        Color(0xFFD1D5DB),
                                                    isMobile: isMobile,
                                                    items: items,
                                                    categories: categories,
                                                    counterparties:
                                                        counterparties,
                                                    obligations: obligations,
                                                  ),
                                                  _buildUchetJournalSection(
                                                    title: 'Бухгалтерский учет',
                                                    ledgerScope:
                                                        LedgerScope.accounting,
                                                    tint: Color(0xFFFFF1F2),
                                                    borderColor:
                                                        Color(0xFFFBCFE8),
                                                    isMobile: isMobile,
                                                    items: items,
                                                    categories: categories,
                                                    counterparties:
                                                        counterparties,
                                                    obligations: obligations,
                                                  ),
                                                ];

                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    buildSections(
                                                        journalSections),
                                                  ],
                                                );
                                              }

                                              return buildSections(
                                                  analyticsSections);
                                            },
                                          );
                                        },
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
    );
  }

  Widget _buildChip(String text) {
    if (text.isEmpty) {
      return SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: FlutterFlowTheme.of(context).labelSmall,
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    Map<String, String>? labels,
    double? width,
    Color? labelColor,
    Color? fillColor,
    Color? textColor,
    Color? hintColor,
    Color? borderColor,
  }) {
    final effectiveLabelColor =
        labelColor ?? FlutterFlowTheme.of(context).secondaryText;
    final dropdown = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FlutterFlowTheme.of(context).bodySmall.override(
                font: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                ),
                color: effectiveLabelColor,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              ),
        ),
        const SizedBox(height: 6.0),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: borderColor ?? FlutterFlowTheme.of(context).alternate,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(
                color: borderColor ?? FlutterFlowTheme.of(context).primary,
              ),
            ),
            filled: fillColor != null,
            fillColor: fillColor,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          ),
          style: TextStyle(color: textColor),
          dropdownColor: fillColor,
          iconEnabledColor: hintColor ?? textColor,
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    labels?[option] ?? (option == 'all' ? 'Все' : option),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );

    if (width == null) {
      return dropdown;
    }
    return SizedBox(width: width, child: dropdown);
  }
}

class _EditTransactionDialog extends StatefulWidget {
  const _EditTransactionDialog({required this.record});

  final TranzactionRecord record;

  @override
  State<_EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  late TextEditingController _textController;
  late TextEditingController _categoryController;
  late TextEditingController _amountController;
  late TextEditingController _ndsAmountController;
  late TextEditingController _counterpartyController;
  late TextEditingController _commentController;
  late TextEditingController _periodController;
  late String _counterpartyType;
  late String _type;
  late LedgerScope _ledgerScope;
  late String _status;
  late bool _nds;
  DateTime? _date;
  DocumentReference? _schetId;
  String _schetTitle = '';

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.record.text);
    _categoryController = TextEditingController(text: widget.record.kat);
    _amountController =
        TextEditingController(text: widget.record.amountOriginal.toString());
    _ndsAmountController =
        TextEditingController(text: widget.record.summaNds.toString());
    _counterpartyController =
        TextEditingController(text: widget.record.counterparty);
    _commentController = TextEditingController(text: widget.record.comment);
    _periodController =
        TextEditingController(text: widget.record.paymentPeriod);
    _counterpartyType = (widget.record.snapshotData['counterparty_type'] ??
            widget.record.snapshotData['counterpartyType'] ??
            '')
        .toString()
        .trim();
    if (_counterpartyType.isEmpty) {
      _counterpartyType = _counterpartyTypeForName(widget.record.counterparty);
    }
    _type = widget.record.type.isEmpty ? 'income' : widget.record.type;
    final rawUchet =
        widget.record.typeUchet.isEmpty ? 'Up1' : widget.record.typeUchet;
    _ledgerScope =
        ledgerScopeFromLegacyValue(normalizeLegacyTypeUchet(rawUchet));
    _status = widget.record.status.isEmpty ? 'Проведена' : widget.record.status;
    _nds = _type == 'decome' ? widget.record.deductible : widget.record.taxable;
    _date = widget.record.date ?? DateTime.now();
    _schetId = widget.record.schetId;
    _schetTitle = widget.record.schetTitle;
  }

  @override
  void dispose() {
    _textController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _ndsAmountController.dispose();
    _counterpartyController.dispose();
    _commentController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  double _parseAmount(String value) {
    final normalized = value.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  String get _categoryForType => _type == 'decome' ? 'decome' : 'income';

  String get _categoryLabelForType => _type == 'decome' ? 'Расход' : 'Доход';

  bool get _isExpenseEdit => _type == 'decome' || _type == 'expense';

  String _counterpartyTypeForName(String counterparty) {
    if (counterparty.isEmpty) return 'ФЛ';
    final upper = counterparty.toUpperCase();
    if (upper.contains('ГОС') ||
        upper.contains('НАЛОГ') ||
        upper.contains('БЮДЖЕТ') ||
        upper.contains('КАЗНА') ||
        upper.contains('ПРАВИТЕЛЬСТВО') ||
        upper.contains('МИНИСТЕРСТВО') ||
        upper.contains('КОМИТЕТ')) {
      return 'Государство';
    }
    if (upper.contains('ИП') || upper.contains('ФЛ')) {
      return 'ФЛ';
    }
    return 'Компания';
  }

  String get _resolvedCategory {
    final currentCategory = _categoryController.text.trim();
    if (currentCategory.isNotEmpty &&
        currentCategory != 'income' &&
        currentCategory != 'decome') {
      return currentCategory;
    }
    return _categoryLabelForType;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _save() async {
    final amountOriginal = _parseAmount(_amountController.text);
    final moneyAmount = buildCompanyMoneyAmount(
      amountOriginal: amountOriginal,
      currencyOriginal: widget.record.currencyOriginal,
      companyCurrency: widget.record.companyCurrency,
      exchangeRateToCompany: widget.record.exchangeRateToCompany,
      exchangeRateDate: widget.record.exchangeRateDate ?? _date,
      exchangeRateSource: widget.record.exchangeRateSource.isEmpty
          ? 'manual_edit_existing_rate'
          : widget.record.exchangeRateSource,
    );
    final excludeFromCompanyIncome = _type == 'income' &&
        (widget.record.excludeFromCompanyIncome ||
            _resolvedCategory.toLowerCase() == 'возврат налога');
    final updateData = {
      'text': _textController.text.trim(),
      'comment': _commentController.text.trim(),
      'commentary': _commentController.text.trim(),
      'payment_period': _periodController.text.trim(),
      'paymentPeriod': _periodController.text.trim(),
      'kat': _resolvedCategory,
      'summa': moneyAmount.amountCompany,
      'amount': moneyAmount.amountCompany,
      'amount_original': moneyAmount.amountOriginal,
      'amountOriginal': moneyAmount.amountOriginal,
      'currency_original': moneyAmount.currencyOriginal,
      'currencyOriginal': moneyAmount.currencyOriginal,
      'exchange_rate_to_company': moneyAmount.exchangeRateToCompany,
      'exchangeRateToCompany': moneyAmount.exchangeRateToCompany,
      'amount_company': moneyAmount.amountCompany,
      'amountCompany': moneyAmount.amountCompany,
      'company_currency': moneyAmount.companyCurrency,
      'companyCurrency': moneyAmount.companyCurrency,
      'exchange_rate_date': moneyAmount.exchangeRateDate,
      'exchangeRateDate': moneyAmount.exchangeRateDate,
      'exchange_rate_source': moneyAmount.exchangeRateSource,
      'exchangeRateSource': moneyAmount.exchangeRateSource,
      'type': _type,
      'typeUchet': _ledgerScope.legacyTypeUchet,
      'ledger_scope': _ledgerScope.storageValue,
      'status': _status,
      'counterparty': _counterpartyController.text.trim(),
      'counterparty_type': _counterpartyType,
      'counterpartyType': _counterpartyType,
      'nds': _nds,
      'summaNds':
          _isExpenseEdit && _nds ? _parseAmount(_ndsAmountController.text) : 0,
      'taxable': !_isExpenseEdit && !excludeFromCompanyIncome && _nds,
      'taxable_income': !_isExpenseEdit && !excludeFromCompanyIncome && _nds,
      'deductible': _isExpenseEdit && _nds,
      'tax_deductible': _isExpenseEdit && _nds,
      'date': _date,
      'schetId': _schetId,
      'schetTitle': _schetTitle,
      'exclude_from_company_income': excludeFromCompanyIncome,
      'excludeFromCompanyIncome': excludeFromCompanyIncome,
    };
    await widget.record.reference.update(updateData);
    await createEntriesForTransaction(
      firestore: FirebaseFirestore.instance,
      transactionRef: widget.record.reference,
      transactionData: {
        ...widget.record.snapshotData,
        ...updateData,
      },
      overwriteExisting: true,
    );
    final companyId = _resolveCompanyId();
    await TransactionSync.recomputeAllForCompany(companyId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _resolveCompanyId() {
    final fromRecord = widget.record.idCompany.trim();
    if (fromRecord.isNotEmpty) return fromRecord;
    final fromUser = (currentUserDocument?.idCompany ?? '').trim();
    if (fromUser.isNotEmpty) return fromUser;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать транзакцию'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'Категория',
                helperText: 'Можно указать любую категорию',
              ),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _counterpartyController,
              decoration: const InputDecoration(labelText: 'Контрагент'),
            ),
            const SizedBox(height: 12.0),
            DropdownButtonFormField<String>(
              initialValue: _counterpartyType,
              items: const [
                DropdownMenuItem(value: 'Компания', child: Text('Компания')),
                DropdownMenuItem(
                    value: 'Государство', child: Text('Государство')),
                DropdownMenuItem(value: 'ФЛ', child: Text('ФЛ')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _counterpartyType = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Тип контрагента'),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _periodController,
              decoration: const InputDecoration(labelText: 'Период'),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _commentController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Сумма'),
            ),
            const SizedBox(height: 12.0),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'income', child: Text('Доход')),
                DropdownMenuItem(value: 'decome', child: Text('Расход')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _type = value;
                  _categoryController.text = _categoryForType;
                });
              },
              decoration: const InputDecoration(labelText: 'Тип'),
            ),
            const SizedBox(height: 12.0),
            DropdownButtonFormField<LedgerScope>(
              initialValue: _ledgerScope,
              items: const [
                DropdownMenuItem(
                  value: LedgerScope.management,
                  child: Text('Управленческий (С)'),
                ),
                DropdownMenuItem(
                  value: LedgerScope.accounting,
                  child: Text('Бухгалтерский'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _ledgerScope = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Учет'),
            ),
            const SizedBox(height: 12.0),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: 'Проведена', child: Text('Проведена')),
                DropdownMenuItem(
                    value: 'Не проведена', child: Text('Не проведена')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _status = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Статус'),
            ),
            const SizedBox(height: 12.0),
            StreamBuilder<List<ShetaRecord>>(
              stream: queryShetaRecord(
                queryBuilder: (shetaRecord) => shetaRecord.where(
                  'idCompany',
                  isEqualTo: _resolveCompanyId(),
                ),
              ),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? [];
                final hasValue =
                    accounts.any((account) => account.reference == _schetId);
                return DropdownButtonFormField<DocumentReference>(
                  initialValue: hasValue ? _schetId : null,
                  items: accounts.map((account) {
                    return DropdownMenuItem(
                      value: account.reference,
                      child: Text(account.title),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _schetId = value;
                      _schetTitle = _resolveSchetTitle(accounts, value);
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Счет'),
                );
              },
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _date == null
                        ? 'Дата не выбрана'
                        : dateTimeFormat(
                            'd/M/y',
                            _date!,
                            locale: FFLocalizations.of(context).languageCode,
                          ),
                  ),
                ),
                TextButton(
                  onPressed: _pickDate,
                  child: Text('Выбрать дату'),
                ),
              ],
            ),
            SwitchListTile(
              value: _nds,
              onChanged: (value) {
                setState(() {
                  _nds = value;
                });
              },
              title: Text(_isExpenseEdit ? 'Зачет' : 'Облагаемый доход'),
            ),
            if (_nds && _isExpenseEdit)
              TextField(
                controller: _ndsAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      _isExpenseEdit ? 'Сумма НДС к зачету' : 'Сумма НДС',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  String _resolveSchetTitle(
      List<ShetaRecord> accounts, DocumentReference? ref) {
    for (final account in accounts) {
      if (account.reference == ref) {
        return account.title;
      }
    }
    return '';
  }
}
