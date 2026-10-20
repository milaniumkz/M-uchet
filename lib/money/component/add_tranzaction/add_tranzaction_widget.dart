import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/utils/effective_company_support.dart';
import '/utils/audit_log_service.dart';
import '/utils/app_money_format.dart';
import '/custom_code/widgets/permissions_helper.dart';
import '/utils/transaction_sync.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/country_profile.dart';
import '/utils/country_tax_profile.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/money_flow_type.dart';
import '/utils/money_wallet_support.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_tranzaction_model.dart';
export 'add_tranzaction_model.dart';

class AddTranzactionWidget extends StatefulWidget {
  const AddTranzactionWidget({
    super.key,
    this.initialTypeUchet,
  });

  final String? initialTypeUchet;

  @override
  State<AddTranzactionWidget> createState() => _AddTranzactionWidgetState();
}

class _AddTranzactionWidgetState extends State<AddTranzactionWidget> {
  static const String _taxRefundCategory = 'Возврат налога';

  late AddTranzactionModel _model;
  DocumentReference? _schetId;
  String _schetTitle = '';
  String _fundingRequestId = '';
  String _fundingRequestTitle = '';
  String _branchId = '';
  String _branchTitle = '';
  String _paymentAccountType = 'bank';
  DateTime? _selectedDate;
  MoneyFlowType _selectedMoneyFlowType = MoneyFlowType.operating;
  late final TextEditingController _exchangeRateController;
  late final TextEditingController _departmentController;
  late final FocusNode _exchangeRateFocusNode;

  LedgerScope get _selectedLedgerScope =>
      ledgerScopeFromLegacyValue(_model.dropDownValue2);

  bool get _isIncomeOperation =>
      (_model.dropDownValue1 ?? 'income') == 'income';

  String get _categoryLabelForSelectedOperation =>
      _isIncomeOperation ? 'Доход' : 'Расход';

  String get _budgetCategoryTypeForSelectedOperation =>
      _isIncomeOperation ? 'income' : 'expense';

  String get _taxFlagLabel => _isIncomeOperation ? 'Облагаемый доход' : 'Зачет';

  String get _taxAmountLabel => 'Сумма НДС к зачету';

  String get _paymentAccountLabel =>
      _paymentAccountType == 'nal' ? 'Наличные' : 'Безнал';

  bool get _isTaxRefundSelected =>
      _isIncomeOperation &&
      (_model.dropDownValue3 ?? '').trim().toLowerCase() ==
          _taxRefundCategory.toLowerCase();

  bool _accountMatchesPaymentType(ShetaRecord account) {
    if (_paymentAccountType == 'nal') return account.tip == 'nal';
    return account.tip == 'bank';
  }

  void _syncCategoryWithOperation([String? operationType]) {
    _model.dropDownValue3 = null;
    _model.dropDownValueController3 = FormFieldController<String>(null);
    _model.checkboxListTileValue = false;
    _model.textController3?.clear();
    if ((operationType ?? _model.dropDownValue1 ?? 'income') == 'income') {
      _fundingRequestId = '';
      _fundingRequestTitle = '';
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadPayableFundingRequests() async {
    final companyId = _effectiveCompanyId();
    if (companyId.trim().isEmpty) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('funding_requests')
        .where('idCompany', isEqualTo: companyId)
        .where('status_code', whereIn: ['to_pay', 'partially_paid']).get(
            const GetOptions(source: Source.serverAndCache));
    return snap.docs.where((doc) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final paid = (data['paid_amount'] as num?)?.toDouble() ?? 0;
      return amount <= 0 || paid < amount;
    }).toList();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadCompanyBranches() async {
    final companyId = _effectiveCompanyId();
    if (companyId.trim().isEmpty) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('company_branches')
        .where('idCompany', isEqualTo: companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    final docs = snap.docs;
    docs.sort((a, b) => (a.data()['name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b.data()['name'] ?? '').toString().toLowerCase()));
    return docs;
  }

  String _fundingRequestLabel(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final paid = (data['paid_amount'] as num?)?.toDouble() ?? 0;
    final rest = amount - paid;
    final project = (data['project'] ?? '').toString().trim();
    final date = (data['date_text'] ?? '').toString().trim();
    return [
      if (date.isNotEmpty) date,
      if (project.isNotEmpty) project,
      'остаток ${formatMoneyWithCurrency(rest, currencyCode: 'TJS')}',
    ].join(' · ');
  }

  Future<void> _applyFundingRequestPayment({
    required String requestId,
    required String transactionId,
    required DocumentReference transactionRef,
    required double paymentAmount,
    required String accountTitle,
    required DocumentReference? accountRef,
    required String budgetCategory,
  }) async {
    if (requestId.trim().isEmpty || paymentAmount == 0) return;

    final requestRef = FirebaseFirestore.instance
        .collection('funding_requests')
        .doc(requestId.trim());
    final paidAt = Timestamp.now();
    final amountToAdd = paymentAmount.abs();

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) return;

      final data = Map<String, dynamic>.from(requestSnap.data() as Map);
      final paymentLinks =
          ((data['payment_links'] ?? data['paymentLinks']) as List<dynamic>? ??
                  const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

      final alreadyLinked = paymentLinks.any((item) =>
          (item['transaction_id'] ?? item['transactionId']).toString() ==
          transactionId);
      if (alreadyLinked) return;

      final totalAmount = (data['amount'] as num?)?.toDouble() ?? 0;
      final currentPaid = (data['paid_amount'] as num?)?.toDouble() ??
          (data['paidAmount'] as num?)?.toDouble() ??
          0;
      final newPaid = currentPaid + amountToAdd;
      final remaining = totalAmount > 0 ? (totalAmount - newPaid) : 0;
      final isPaid = totalAmount > 0 && newPaid >= totalAmount - 0.01;

      final link = {
        'transaction_id': transactionId,
        'transactionId': transactionId,
        'transaction_ref': transactionRef,
        'amount': amountToAdd,
        'paid_at': paidAt,
        'account_title': accountTitle,
        'account_path': accountRef?.path,
        'budget_category': budgetCategory,
      };
      final nextLinks = [...paymentLinks, link];

      transaction.update(requestRef, {
        'paid_amount': newPaid,
        'paidAmount': newPaid,
        'remaining_amount': remaining > 0 ? remaining : 0,
        'remainingAmount': remaining > 0 ? remaining : 0,
        'payment_links': nextLinks,
        'paymentLinks': nextLinks,
        'last_payment_id': transactionId,
        'lastPaymentId': transactionId,
        'last_payment_ref': transactionRef,
        'last_payment_at': paidAt,
        'status': isPaid ? 'Оплачено' : 'Частично оплачено',
        'status_code': isPaid ? 'paid' : 'partially_paid',
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  String _budgetCategoryTitle(StatRashodRecord record) {
    return record.title.trim();
  }

  bool _matchesSelectedBudgetCategoryType(StatRashodRecord record) {
    final rawType = record.type.trim().toLowerCase();
    if (_isIncomeOperation) {
      return rawType == 'income' || rawType == 'доход' || rawType == 'doxod';
    }
    return rawType == 'expense' ||
        rawType == 'decome' ||
        rawType == 'расход' ||
        rawType == 'rashod';
  }

  void _setSelectedLedgerScope(LedgerScope scope) {
    final legacyTypeUchet = scope.legacyTypeUchet;
    _model.dropDownValue2 = legacyTypeUchet;
    _model.dropDownValueController2 ??=
        FormFieldController<String>(legacyTypeUchet);
    _model.dropDownValueController2!.value = legacyTypeUchet;
  }

  double _parseAmount(String? raw) {
    final normalized = (raw ?? '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  void _refreshCurrencyPreview() {
    if (!mounted) return;
    setState(() {});
  }

  String _effectiveCompanyId() {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: currentUserUid,
    );
  }

  Future<Map<String, dynamic>> _loadCompanyProfile(String companyId) async {
    if (companyId.trim().isEmpty) return const <String, dynamic>{};
    final snap = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    var data = snap.data();
    if (data == null) {
      final query = await FirebaseFirestore.instance
          .collection('company_profile')
          .where('idCompany', isEqualTo: companyId)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (query.docs.isNotEmpty) {
        data = query.docs.first.data();
      }
    }
    return data ?? const <String, dynamic>{};
  }

  Future<String> _accountCurrency(AccountSelection account) async {
    final ref = account.reference;
    if (ref == null) return 'KZT';
    final snap = await ref.get(const GetOptions(source: Source.serverAndCache));
    final data = snap.data();
    if (data is! Map) return 'KZT';
    return originalCurrencyFromData(Map<String, dynamic>.from(data));
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          (value ?? '').toString().replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0.0;
  }

  Future<double?> _defaultExchangeRate({
    required String companyId,
    required String currencyCode,
  }) async {
    if (companyId.trim().isEmpty || currencyCode.trim().isEmpty) return null;
    final companyRate = await FirebaseFirestore.instance
        .collection('valuta')
        .where('idCompany', isEqualTo: companyId)
        .where('kod', isEqualTo: currencyCode)
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));
    final docs = companyRate.docs.isNotEmpty
        ? companyRate.docs
        : (await FirebaseFirestore.instance
                .collection('valuta')
                .where('kod', isEqualTo: currencyCode)
                .limit(1)
                .get(const GetOptions(source: Source.serverAndCache)))
            .docs;
    if (docs.isEmpty) return null;
    final data = docs.first.data();
    final rate = _numValue(data['exchange_rate_to_company'] ??
        data['exchangeRateToCompany'] ??
        data['rate']);
    return rate > 0 ? rate : null;
  }

  Future<_TransactionCurrencyPreview> _loadCurrencyPreview() async {
    final companyId = _effectiveCompanyId();
    final companyProfile = await _loadCompanyProfile(companyId);
    final countryProfile = countryProfileFromData(companyProfile);
    final companyCurrency = normalizeCurrencyCode(
      (companyProfile['base_currency'] ??
              companyProfile['company_currency'] ??
              companyProfile['valuta'])
          ?.toString(),
      fallback: countryProfile.baseCurrency,
    );
    var accountCurrency = companyCurrency;
    if (_schetId != null) {
      accountCurrency = normalizeCurrencyCode(
        await _accountCurrency(AccountSelection(
          reference: _schetId,
          title: _schetTitle,
        )),
        fallback: companyCurrency,
      );
    }
    final defaultRate = accountCurrency == companyCurrency
        ? 1.0
        : await _defaultExchangeRate(
            companyId: companyId,
            currencyCode: accountCurrency,
          );
    return _TransactionCurrencyPreview(
      accountCurrency: accountCurrency,
      companyCurrency: companyCurrency,
      defaultExchangeRate: defaultRate,
    );
  }

  Widget _exchangeRateSection() {
    return FutureBuilder<_TransactionCurrencyPreview>(
      future: _loadCurrencyPreview(),
      builder: (context, snapshot) {
        final preview = snapshot.data;
        if (preview == null) {
          return const SizedBox.shrink();
        }
        if (preview.isCrossCurrency &&
            preview.defaultExchangeRate != null &&
            preview.defaultExchangeRate! > 0 &&
            (_exchangeRateController.text.trim().isEmpty ||
                _exchangeRateController.text.trim() == '1')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _exchangeRateController.text =
                preview.defaultExchangeRate!.toString();
          });
        }
        final amountOriginal = _parseAmount(_model.textController2.text);
        final rate = _parseAmount(_exchangeRateController.text);
        final effectiveRate = preview.isCrossCurrency && rate > 0 ? rate : 1.0;
        final amountCompany = amountOriginal * effectiveRate;
        final originalFormatted = formatMoneyWithCurrency(
          amountOriginal,
          currencyCode: preview.accountCurrency,
        );
        final companyFormatted = formatMoneyWithCurrency(
          amountCompany,
          currencyCode: preview.companyCurrency,
        );
        final helperText = preview.isCrossCurrency
            ? 'В отчеты попадет $companyFormatted. Сумма на счете: $originalFormatted.'
            : 'Валюта счета совпадает с валютой компании: ${preview.companyCurrency}. Курс 1.';

        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview.isCrossCurrency) ...[
              Text(
                'Курс ${preview.accountCurrency} к ${preview.companyCurrency}',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              TextFormField(
                controller: _exchangeRateController,
                focusNode: _exchangeRateFocusNode,
                decoration: InputDecoration(
                  hintText: '1',
                  helperText: 'Курс фиксируется на дату платежа.',
                  filled: true,
                  fillColor: FlutterFlowTheme.of(context).primaryBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(
                    16.0,
                    16.0,
                    16.0,
                    16.0,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).primaryBackground,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: Text(
                helperText,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ].divide(SizedBox(height: 8.0)),
        );
      },
    );
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddTranzactionModel());

    _model.textController1 ??= TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();

    _model.textController2 ??= TextEditingController();
    _model.textFieldFocusNode2 ??= FocusNode();

    _model.textController3 ??= TextEditingController();
    _model.textFieldFocusNode3 ??= FocusNode();

    _model.textController4 ??= TextEditingController();
    _model.textFieldFocusNode4 ??= FocusNode();

    _model.textController5 ??= TextEditingController();
    _model.textFieldFocusNode5 ??= FocusNode();

    _model.textController6 ??= TextEditingController();
    _model.textFieldFocusNode6 ??= FocusNode();
    _exchangeRateController = TextEditingController(text: '1');
    _departmentController = TextEditingController();
    _exchangeRateFocusNode = FocusNode();
    _model.textController2?.addListener(_refreshCurrencyPreview);
    _exchangeRateController.addListener(_refreshCurrencyPreview);

    final initialType = widget.initialTypeUchet;
    if (initialType != null && initialType.isNotEmpty) {
      _setSelectedLedgerScope(
        ledgerScopeFromLegacyValue(normalizeLegacyTypeUchet(initialType)),
      );
    }
    _syncCategoryWithOperation();
  }

  @override
  void dispose() {
    _model.textController2?.removeListener(_refreshCurrencyPreview);
    _exchangeRateController.removeListener(_refreshCurrencyPreview);
    _exchangeRateController.dispose();
    _departmentController.dispose();
    _exchangeRateFocusNode.dispose();
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24.0),
            bottomRight: Radius.circular(24.0),
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FFLocalizations.of(context).getText(
                    '77lnzp31' /* Добавить транзакцию           ... */,
                  ),
                  style: FlutterFlowTheme.of(context).headlineMedium.override(
                        font: GoogleFonts.interTight(
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).primaryText,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  FFLocalizations.of(context).getText(
                                    'eb00dn5t' /* Тип операции */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                FlutterFlowDropDown<String>(
                                  controller:
                                      _model.dropDownValueController1 ??=
                                          FormFieldController<String>(
                                    _model.dropDownValue1 ??= 'income',
                                  ),
                                  options:
                                      List<String>.from(['income', 'decome']),
                                  optionLabels: [
                                    FFLocalizations.of(context).getText(
                                      'w63qyytc' /* Доход */,
                                    ),
                                    FFLocalizations.of(context).getText(
                                      'lfbc8wi1' /* Расход */,
                                    )
                                  ],
                                  onChanged: (val) => safeSetState(() {
                                    _model.dropDownValue1 = val;
                                    _syncCategoryWithOperation(val);
                                  }),
                                  width: MediaQuery.sizeOf(context).width * 1.0,
                                  height: 40.0,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  hintText: FFLocalizations.of(context).getText(
                                    'wdu26cak' /* Выберите тип счета */,
                                  ),
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  elevation: 2.0,
                                  borderColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  hidesUnderline: true,
                                  isOverButton: false,
                                  isSearchable: false,
                                  isMultiSelect: false,
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  FFLocalizations.of(context).getText(
                                    '77dxo9vd' /* Тип учета */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                FlutterFlowDropDown<String>(
                                  controller:
                                      _model.dropDownValueController2 ??=
                                          FormFieldController<String>(
                                    _model.dropDownValue2 ??=
                                        LedgerScope.management.legacyTypeUchet,
                                  ),
                                  options: List<String>.from(['Up1', 'Bu']),
                                  optionLabels: [
                                    'Управленческий (С)',
                                    FFLocalizations.of(context).getText(
                                      's1hlso2f' /* Бухгалтерский */,
                                    ),
                                  ],
                                  onChanged: (val) => safeSetState(() {
                                    _setSelectedLedgerScope(
                                      ledgerScopeFromLegacyValue(val),
                                    );
                                  }),
                                  width: MediaQuery.sizeOf(context).width * 1.0,
                                  height: 40.0,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  hintText: FFLocalizations.of(context).getText(
                                    'y63itftx' /* Выберите тип счета */,
                                  ),
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  elevation: 2.0,
                                  borderColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  hidesUnderline: true,
                                  isOverButton: false,
                                  isSearchable: false,
                                  isMultiSelect: false,
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Тип оплаты',
                                  style:
                                      FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                DropdownButtonFormField<String>(
                                  value: _paymentAccountType,
                                  decoration: InputDecoration(
                                    hintText: 'Выберите тип оплаты',
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    contentPadding:
                                        EdgeInsetsDirectional.fromSTEB(
                                            12.0, 8.0, 12.0, 8.0),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'bank',
                                      child: Text('Безнал'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'nal',
                                      child: Text('Наличные'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _paymentAccountType = value ?? 'bank';
                                      _schetId = null;
                                      _schetTitle = '';
                                    });
                                  },
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Денежный поток',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                DropdownButtonFormField<MoneyFlowType>(
                                  initialValue: _selectedMoneyFlowType,
                                  onChanged: (val) => safeSetState(() {
                                    _selectedMoneyFlowType =
                                        val ?? MoneyFlowType.operating;
                                  }),
                                  items: MoneyFlowType.values
                                      .map(
                                        (flowType) =>
                                            DropdownMenuItem<MoneyFlowType>(
                                          value: flowType,
                                          child: Text(flowType.label),
                                        ),
                                      )
                                      .toList(),
                                  decoration: InputDecoration(
                                    hintText: 'Выберите поток',
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    contentPadding:
                                        EdgeInsetsDirectional.fromSTEB(
                                            12.0, 8.0, 12.0, 8.0),
                                  ),
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
                                  dropdownColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Счет',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                AuthUserStreamWidget(
                                  builder: (context) =>
                                      StreamBuilder<List<ShetaRecord>>(
                                    stream: queryShetaRecord(
                                      queryBuilder: (shetaRecord) =>
                                          shetaRecord.where(
                                        'idCompany',
                                        isEqualTo: _effectiveCompanyId(),
                                      ),
                                    ),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: SizedBox(
                                            width: 50.0,
                                            height: 50.0,
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final accounts = (snapshot.data ?? [])
                                          .where(_accountMatchesPaymentType)
                                          .toList();
                                      if (accounts.isEmpty) {
                                        return Text(
                                          'Счета "$_paymentAccountLabel" не найдены',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall,
                                        );
                                      }
                                      final hasValue = accounts.any((account) =>
                                          account.reference == _schetId);

                                      return DropdownButtonFormField<
                                          DocumentReference>(
                                        value: hasValue ? _schetId : null,
                                        items: accounts.map((account) {
                                          return DropdownMenuItem(
                                            value: account.reference,
                                            child: Text(account.title),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _schetId = value;
                                            _schetTitle = accounts
                                                .firstWhere(
                                                    (account) =>
                                                        account.reference ==
                                                        value,
                                                    orElse: () =>
                                                        accounts.first)
                                                .title;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Выберите счет',
                                          filled: true,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .secondaryBackground,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            borderSide: BorderSide(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .alternate,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Дата',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                FFButtonWidget(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _selectedDate ?? DateTime.now(),
                                      firstDate: DateTime(2015),
                                      lastDate: DateTime(
                                          DateTime.now().year + 1, 12, 31),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _selectedDate = picked;
                                      });
                                    }
                                  },
                                  text: _selectedDate == null
                                      ? 'Выбрать дату'
                                      : dateTimeFormat(
                                          'd/M/y',
                                          _selectedDate!,
                                          locale: FFLocalizations.of(context)
                                              .languageCode,
                                        ),
                                  options: FFButtonOptions(
                                    height: 40.0,
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16.0, 0.0, 16.0, 0.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                    elevation: 0.0,
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isIncomeOperation
                                      ? 'Статья дохода'
                                      : 'Статья расхода',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                AuthUserStreamWidget(
                                  builder: (context) =>
                                      StreamBuilder<List<StatRashodRecord>>(
                                    stream: queryStatRashodRecord(
                                      queryBuilder: (statRashodRecord) =>
                                          statRashodRecord.where(
                                        'idCompany',
                                        isEqualTo: _effectiveCompanyId(),
                                      ),
                                    ),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: SizedBox(
                                            width: 50.0,
                                            height: 50.0,
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      final categories = snapshot.data!
                                          .where(
                                              _matchesSelectedBudgetCategoryType)
                                          .map(_budgetCategoryTitle)
                                          .where((title) => title.isNotEmpty)
                                          .toSet()
                                          .toList();
                                      if (_isIncomeOperation &&
                                          !categories.any((title) =>
                                              title.toLowerCase().trim() ==
                                              _taxRefundCategory
                                                  .toLowerCase())) {
                                        categories.add(_taxRefundCategory);
                                      }
                                      categories.sort();
                                      final options = categories.isEmpty
                                          ? <String>[
                                              _categoryLabelForSelectedOperation,
                                            ]
                                          : categories;
                                      if (_model.dropDownValue3 != null &&
                                          !options.contains(
                                              _model.dropDownValue3)) {
                                        _model.dropDownValue3 = null;
                                        _model.dropDownValueController3 =
                                            FormFieldController<String>(null);
                                      }
                                      return FlutterFlowDropDown<String>(
                                        controller:
                                            _model.dropDownValueController3 ??=
                                                FormFieldController<String>(
                                          _model.dropDownValue3,
                                        ),
                                        options: List<String>.from(options),
                                        optionLabels: options,
                                        onChanged: (val) => safeSetState(() {
                                          _model.dropDownValue3 = val;
                                          if (_isTaxRefundSelected) {
                                            _model.checkboxListTileValue =
                                                false;
                                            _model.textController3?.clear();
                                          }
                                        }),
                                        width:
                                            MediaQuery.sizeOf(context).width *
                                                1.0,
                                        height: 40.0,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        hintText: _isIncomeOperation
                                            ? 'Выберите статью дохода'
                                            : 'Выберите статью расхода',
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          size: 24.0,
                                        ),
                                        fillColor: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        elevation: 2.0,
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderWidth: 1.0,
                                        borderRadius: 8.0,
                                        margin: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        hidesUnderline: true,
                                        disabled: categories.isEmpty,
                                        isOverButton: false,
                                        isSearchable: true,
                                        isMultiSelect: false,
                                      );
                                    },
                                  ),
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Период',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _model.textController6,
                            focusNode: _model.textFieldFocusNode6,
                            autofocus: false,
                            obscureText: false,
                            decoration: InputDecoration(
                              hintText: 'Например: май 2026 или 01.05-31.05',
                              hintStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).primary,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              contentPadding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 14.0, 16.0, 14.0),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                ),
                            validator: _model.textController6Validator
                                .asValidator(context),
                          ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            'ul0hf1lx' /* Название */,
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _model.textController1,
                            focusNode: _model.textFieldFocusNode1,
                            autofocus: false,
                            obscureText: false,
                            decoration: InputDecoration(
                              hintText: FFLocalizations.of(context).getText(
                                'jw0ui9eq' /* Например: Продажа товаров */,
                              ),
                              hintStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              contentPadding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 16.0, 16.0, 16.0),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                            validator: _model.textController1Validator
                                .asValidator(context),
                          ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Комментарий',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _model.textController5,
                            focusNode: _model.textFieldFocusNode5,
                            autofocus: false,
                            obscureText: false,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText:
                                  'Например: оплата за май 2026, договор, примечание',
                              hintStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).primary,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              contentPadding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 14.0, 16.0, 14.0),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                ),
                            validator: _model.textController5Validator
                                .asValidator(context),
                          ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    _exchangeRateSection(),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Статус',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                FlutterFlowDropDown<String>(
                                  controller:
                                      _model.dropDownValueController4 ??=
                                          FormFieldController<String>(
                                    _model.dropDownValue4 ??= 'Проведена',
                                  ),
                                  options: ['Проведена', 'Не проведена'],
                                  onChanged: (val) => safeSetState(
                                      () => _model.dropDownValue4 = val),
                                  width: MediaQuery.sizeOf(context).width * 1.0,
                                  height: 40.0,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  hintText: 'Выберите статус',
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  elevation: 2.0,
                                  borderColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  hidesUnderline: true,
                                  isOverButton: false,
                                  isSearchable: false,
                                  isMultiSelect: false,
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Контрагент',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                Container(
                                  width: double.infinity,
                                  child: StreamBuilder<List<TranzactionRecord>>(
                                    stream: queryTranzactionRecord(
                                      queryBuilder: (tranzactionRecord) =>
                                          tranzactionRecord.where(
                                        'idCompany',
                                        isEqualTo: _effectiveCompanyId(),
                                      ),
                                    ),
                                    builder: (context, snapshot) {
                                      final counterparties = (snapshot.data ??
                                              const <TranzactionRecord>[])
                                          .map((record) =>
                                              record.counterparty.trim())
                                          .where((name) => name.isNotEmpty)
                                          .toSet()
                                          .toList()
                                        ..sort((a, b) => a
                                            .toLowerCase()
                                            .compareTo(b.toLowerCase()));

                                      return RawAutocomplete<String>(
                                        textEditingController:
                                            _model.textController4,
                                        focusNode: _model.textFieldFocusNode4,
                                        optionsBuilder: (textEditingValue) {
                                          final query = textEditingValue.text
                                              .trim()
                                              .toLowerCase();
                                          final matches = query.isEmpty
                                              ? counterparties
                                              : counterparties
                                                  .where((name) => name
                                                      .toLowerCase()
                                                      .contains(query))
                                                  .toList();
                                          return matches.take(12);
                                        },
                                        onSelected: (value) {
                                          _model.textController4?.text = value;
                                        },
                                        fieldViewBuilder: (
                                          context,
                                          textEditingController,
                                          focusNode,
                                          onFieldSubmitted,
                                        ) {
                                          return TextFormField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            autofocus: false,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              hintText: 'Например: ТОО Ромашка',
                                              suffixIcon: counterparties.isEmpty
                                                  ? null
                                                  : Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                    ),
                                              hintStyle: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.inter(),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    letterSpacing: 0.0,
                                                  ),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              contentPadding:
                                                  EdgeInsetsDirectional
                                                      .fromSTEB(16.0, 16.0,
                                                          16.0, 16.0),
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.inter(),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                ),
                                            validator: _model
                                                .textController4Validator
                                                .asValidator(context),
                                          );
                                        },
                                        optionsViewBuilder:
                                            (context, onSelected, options) {
                                          return Align(
                                            alignment: Alignment.topLeft,
                                            child: Material(
                                              elevation: 4.0,
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                  maxHeight: 220.0,
                                                  maxWidth: 420.0,
                                                ),
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: options.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final option = options
                                                        .elementAt(index);
                                                    return InkWell(
                                                      onTap: () =>
                                                          onSelected(option),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 14.0,
                                                          vertical: 12.0,
                                                        ),
                                                        child: Text(
                                                          option,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                FlutterFlowDropDown<String>(
                                  controller:
                                      _model.dropDownValueController6 ??=
                                          FormFieldController<String>(
                                    _model.dropDownValue6 ??= 'Компания',
                                  ),
                                  options: const [
                                    'Компания',
                                    'Государство',
                                    'ФЛ',
                                  ],
                                  onChanged: (val) => safeSetState(
                                      () => _model.dropDownValue6 = val),
                                  width: double.infinity,
                                  height: 48.0,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                      ),
                                  hintText: 'Тип контрагента',
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  elevation: 2.0,
                                  borderColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  hidesUnderline: true,
                                  isOverButton: false,
                                  isSearchable: false,
                                  isMultiSelect: false,
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_isIncomeOperation &&
                        PermissionsHelper.has('funding_requests.pay'))
                      Padding(
                        padding: EdgeInsets.all(5.0),
                        child: FutureBuilder<
                            List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                          future: _loadCompanyBranches(),
                          builder: (context, snapshot) {
                            final branches = snapshot.data ?? const [];
                            final hasValue =
                                branches.any((doc) => doc.id == _branchId);
                            return Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Филиал / подразделение',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                                DropdownButtonFormField<String>(
                                  value: hasValue ? _branchId : '',
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('Без филиала'),
                                    ),
                                    ...branches.map((doc) {
                                      final title =
                                          (doc.data()['name'] ?? 'Филиал')
                                              .toString();
                                      return DropdownMenuItem<String>(
                                        value: doc.id,
                                        child: Text(
                                          title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    final selectedId = value ?? '';
                                    final selected = branches
                                        .where((doc) => doc.id == selectedId);
                                    setState(() {
                                      _branchId = selectedId;
                                      _branchTitle = selected.isEmpty
                                          ? ''
                                          : (selected.first.data()['name'] ??
                                                  '')
                                              .toString();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Филиал',
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _departmentController,
                                  decoration: InputDecoration(
                                    hintText: 'Подразделение',
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                  ),
                                ),
                              ].divide(SizedBox(height: 8.0)),
                            );
                          },
                        ),
                      ),
                    if (!_isIncomeOperation &&
                        PermissionsHelper.has('funding_requests.pay'))
                      Padding(
                        padding: EdgeInsets.all(5.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Закрыть обязательство',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                            AuthUserStreamWidget(
                              builder: (context) =>
                                  StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('obyaz')
                                    .where(
                                      'idCompany',
                                      isEqualTo: _effectiveCompanyId(),
                                    )
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return SizedBox(
                                      height: 40.0,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final docs = snapshot.data!.docs;
                                  final options = <String>[''];
                                  final labels = <String>['Не закрывать'];
                                  for (final doc in docs) {
                                    final data = Map<String, dynamic>.from(
                                        doc.data() as Map);
                                    final title = (data['title'] ??
                                            data['name'] ??
                                            data['type'] ??
                                            'Обязательств')
                                        .toString();
                                    options.add(doc.id);
                                    labels.add(title);
                                  }
                                  return FlutterFlowDropDown<String>(
                                    controller:
                                        _model.dropDownValueController5 ??=
                                            FormFieldController<String>(
                                      _model.dropDownValue5 ??= '',
                                    ),
                                    options: options,
                                    optionLabels: labels,
                                    onChanged: (val) => safeSetState(
                                        () => _model.dropDownValue5 = val),
                                    width:
                                        MediaQuery.sizeOf(context).width * 1.0,
                                    height: 40.0,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                    hintText: 'Не закрывать',
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 24.0,
                                    ),
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    elevation: 2.0,
                                    borderColor:
                                        FlutterFlowTheme.of(context).alternate,
                                    borderWidth: 1.0,
                                    borderRadius: 8.0,
                                    margin: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 0.0, 12.0, 0.0),
                                    hidesUnderline: true,
                                    isOverButton: false,
                                    isSearchable: false,
                                    isMultiSelect: false,
                                  );
                                },
                              ),
                            ),
                          ].divide(SizedBox(height: 8.0)),
                        ),
                      ),
                    if (!_isIncomeOperation)
                      Padding(
                        padding: EdgeInsets.all(5.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Заявка к оплате',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            FutureBuilder<
                                List<
                                    QueryDocumentSnapshot<
                                        Map<String, dynamic>>>>(
                              future: _loadPayableFundingRequests(),
                              builder: (context, snapshot) {
                                final docs = snapshot.data ?? const [];
                                final hasValue = docs
                                    .any((doc) => doc.id == _fundingRequestId);
                                return DropdownButtonFormField<String>(
                                  value: hasValue ? _fundingRequestId : '',
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('Без заявки'),
                                    ),
                                    ...docs.map((doc) {
                                      final label = _fundingRequestLabel(doc);
                                      return DropdownMenuItem<String>(
                                        value: doc.id,
                                        child: Text(
                                          label,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    final selectedId = value ?? '';
                                    final selectedDoc = docs
                                        .where((doc) => doc.id == selectedId)
                                        .firstOrNull;
                                    setState(() {
                                      _fundingRequestId = selectedId;
                                      _fundingRequestTitle = selectedDoc == null
                                          ? ''
                                          : _fundingRequestLabel(selectedDoc);
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Выберите заявку',
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ].divide(SizedBox(height: 8.0)),
                        ),
                      ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            'wcf4lur0' /* Сумма */,
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _model.textController2,
                            focusNode: _model.textFieldFocusNode2,
                            autofocus: false,
                            obscureText: false,
                            decoration: InputDecoration(
                              hintText: FFLocalizations.of(context).getText(
                                'v5x0x8gn' /* 0 */,
                              ),
                              hintStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              contentPadding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 16.0, 16.0, 16.0),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                            keyboardType: TextInputType.number,
                            validator: _model.textController2Validator
                                .asValidator(context),
                          ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: Theme(
                              data: ThemeData(
                                checkboxTheme: CheckboxThemeData(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                unselectedWidgetColor:
                                    FlutterFlowTheme.of(context).alternate,
                              ),
                              child: CheckboxListTile(
                                value: _model.checkboxListTileValue ??= false,
                                onChanged: _isTaxRefundSelected
                                    ? null
                                    : (newValue) async {
                                        safeSetState(() => _model
                                            .checkboxListTileValue = newValue!);
                                      },
                                title: Text(
                                  _isTaxRefundSelected
                                      ? 'Не облагается налогом'
                                      : _taxFlagLabel,
                                  style: FlutterFlowTheme.of(context)
                                      .titleLarge
                                      .override(
                                        font: GoogleFonts.interTight(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleLarge
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleLarge
                                                  .fontStyle,
                                        ),
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                      ),
                                ),
                                tileColor: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                activeColor:
                                    FlutterFlowTheme.of(context).primary,
                                checkColor: FlutterFlowTheme.of(context).info,
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsetsDirectional.fromSTEB(
                                    12.0, 0.0, 12.0, 0.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_model.checkboxListTileValue == true &&
                        !_isIncomeOperation)
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _taxAmountLabel,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                          Container(
                            width: double.infinity,
                            child: TextFormField(
                              controller: _model.textController3,
                              focusNode: _model.textFieldFocusNode3,
                              autofocus: false,
                              obscureText: false,
                              decoration: InputDecoration(
                                hintText: FFLocalizations.of(context).getText(
                                  'rlwv10p8' /* 0 */,
                                ),
                                hintStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0x00000000),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0x00000000),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0x00000000),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                filled: true,
                                fillColor: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                contentPadding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 16.0, 16.0, 16.0),
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              keyboardType: TextInputType.number,
                              validator: _model.textController3Validator
                                  .asValidator(context),
                            ),
                          ),
                        ].divide(SizedBox(height: 8.0)),
                      ),
                  ].divide(SizedBox(height: 16.0)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          Navigator.pop(context);
                        },
                        text: FFLocalizations.of(context).getText(
                          '0jzyzltf' /* Отменить */,
                        ),
                        options: FFButtonOptions(
                          height: 48.0,
                          padding: EdgeInsets.all(8.0),
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          textStyle: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontStyle,
                              ),
                          elevation: 0.0,
                          borderSide: BorderSide(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          final companyId = _effectiveCompanyId();
                          final account = _schetId == null
                              ? await TransactionSync.selectAccount(
                                  companyId,
                                  tip: _paymentAccountType,
                                )
                              : AccountSelection(
                                  reference: _schetId, title: _schetTitle);
                          final obligationId = _isIncomeOperation
                              ? ''
                              : (_model.dropDownValue5?.trim() ?? '');
                          String obligationTitle = '';
                          if (obligationId.isNotEmpty) {
                            final obligationSnap = await FirebaseFirestore
                                .instance
                                .collection('obyaz')
                                .doc(obligationId)
                                .get();
                            if (obligationSnap.exists) {
                              final data = Map<String, dynamic>.from(
                                  obligationSnap.data() as Map);
                              obligationTitle = (data['title'] ??
                                      data['name'] ??
                                      data['type'] ??
                                      'Обязательств')
                                  .toString();
                            }
                          }

                          final txRef = TranzactionRecord.collection.doc();
                          final wallet = await ensureWalletForAccountReference(
                            firestore: FirebaseFirestore.instance,
                            accountRef: account.reference,
                            fallbackTitle: account.title,
                          );
                          final companyProfile =
                              await _loadCompanyProfile(companyId);
                          final countryProfile =
                              countryProfileFromData(companyProfile);
                          final companyCurrency = normalizeCurrencyCode(
                            (companyProfile['base_currency'] ??
                                    companyProfile['company_currency'] ??
                                    companyProfile['valuta'])
                                ?.toString(),
                            fallback: countryProfile.baseCurrency,
                          );
                          final accountCurrency = normalizeCurrencyCode(
                              await _accountCurrency(account),
                              fallback: companyCurrency);
                          final amountOriginal =
                              _parseAmount(_model.textController2.text);
                          final exchangeRate = _parseAmount(
                            _exchangeRateController.text,
                          );
                          final moneyAmount = buildCompanyMoneyAmount(
                            amountOriginal: amountOriginal,
                            currencyOriginal: accountCurrency,
                            companyCurrency: companyCurrency,
                            exchangeRateToCompany: exchangeRate,
                            exchangeRateDate: _selectedDate,
                          );
                          final taxProfile = taxProfileForCountry(
                            countryCode: countryProfile.countryCode,
                            date: _selectedDate,
                          );
                          final taxAmountOriginal =
                              _parseAmount(_model.textController3.text);
                          final taxAmountCompany = taxAmountOriginal *
                              moneyAmount.exchangeRateToCompany;
                          final ledgerScope = _selectedLedgerScope;
                          final taxFlag = _model.checkboxListTileValue == true;
                          final isIncomeOperation = _isIncomeOperation;
                          final selectedCategory =
                              (_model.dropDownValue3 ?? '').trim().isEmpty
                                  ? _categoryLabelForSelectedOperation
                                  : _model.dropDownValue3!.trim();
                          final counterpartyType =
                              (_model.dropDownValue6 ?? 'Компания').trim();
                          final fundingRequestId =
                              isIncomeOperation ? '' : _fundingRequestId.trim();
                          final excludeFromCompanyIncome = isIncomeOperation &&
                              selectedCategory.toLowerCase() ==
                                  _taxRefundCategory.toLowerCase();
                          final txData = {
                            ...createTranzactionRecordData(
                              type: _model.dropDownValue1,
                              typeUchet: ledgerScope.legacyTypeUchet,
                              ledgerScope: ledgerScope.storageValue,
                              moneyFlowType:
                                  _selectedMoneyFlowType.storageValue,
                              kat: selectedCategory,
                              text: _model.textController1.text,
                              comment: _model.textController5.text,
                              paymentPeriod: _model.textController6.text,
                              summa: moneyAmount.amountCompany,
                              amountOriginal: moneyAmount.amountOriginal,
                              currencyOriginal: moneyAmount.currencyOriginal,
                              exchangeRateToCompany:
                                  moneyAmount.exchangeRateToCompany,
                              amountCompany: moneyAmount.amountCompany,
                              companyCurrency: moneyAmount.companyCurrency,
                              exchangeRateDate: moneyAmount.exchangeRateDate,
                              exchangeRateSource:
                                  moneyAmount.exchangeRateSource,
                              nds: taxFlag && !excludeFromCompanyIncome,
                              summaNds: taxFlag && !isIncomeOperation
                                  ? taxAmountCompany
                                  : 0,
                              taxRate: taxProfile.vatRate,
                              taxProfileCountry: taxProfile.countryCode,
                              taxProfileVersion: taxProfile.version,
                              taxable:
                                  isIncomeOperation && !excludeFromCompanyIncome
                                      ? taxFlag
                                      : false,
                              deductible: isIncomeOperation ? false : taxFlag,
                              excludeFromCompanyIncome:
                                  excludeFromCompanyIncome,
                              idCompany: companyId,
                              schetId: account.reference,
                              schetTitle: account.title,
                              walletId: wallet?.reference.id,
                              walletName: wallet?.name,
                              walletType: wallet?.type,
                              date: _selectedDate,
                              status: _model.dropDownValue4 ?? 'Проведена',
                              counterparty: _model.textController4.text,
                              obligationId:
                                  obligationId.isEmpty ? null : obligationId,
                              obligationTitle: obligationTitle.isEmpty
                                  ? null
                                  : obligationTitle,
                            ),
                            ...mapToFirestore(
                              {
                                'date': _selectedDate ??
                                    FieldValue.serverTimestamp(),
                                'category_name': selectedCategory,
                                'country_code': countryProfile.countryCode,
                                'tax_profile_country': taxProfile.countryCode,
                                'taxProfileCountry': taxProfile.countryCode,
                                'tax_profile_version': taxProfile.version,
                                'taxProfileVersion': taxProfile.version,
                                'tax_rate': taxProfile.vatRate,
                                'taxRate': taxProfile.vatRate,
                                ...moneyAmount.toMap(),
                                'budget_category': selectedCategory,
                                'budget_category_type':
                                    _budgetCategoryTypeForSelectedOperation,
                                'exclude_from_company_income':
                                    excludeFromCompanyIncome,
                                'excludeFromCompanyIncome':
                                    excludeFromCompanyIncome,
                                'user_id': currentUserUid,
                                'user_name': currentUserDisplayName,
                                'created_by': currentUserUid,
                                'created_by_name': currentUserDisplayName,
                                'counterparty_type': counterpartyType,
                                'counterpartyType': counterpartyType,
                                'branch_id': _branchId,
                                'branchId': _branchId,
                                'branch': _branchTitle,
                                'branch_name': _branchTitle,
                                'branchName': _branchTitle,
                                'department': _departmentController.text.trim(),
                                if (fundingRequestId.isNotEmpty) ...{
                                  'funding_request_id': fundingRequestId,
                                  'fundingRequestId': fundingRequestId,
                                  'funding_request_title': _fundingRequestTitle,
                                  'fundingRequestTitle': _fundingRequestTitle,
                                  'funding_request_payment_amount':
                                      moneyAmount.amountCompany.abs(),
                                  'fundingRequestPaymentAmount':
                                      moneyAmount.amountCompany.abs(),
                                },
                              },
                            ),
                          };
                          await txRef.set(txData);
                          await createEntriesForTransaction(
                            firestore: FirebaseFirestore.instance,
                            transactionRef: txRef,
                            transactionData: txData,
                          );
                          await AuditLogService.logAction(
                            companyId: companyId,
                            action: 'create',
                            entity: 'transaction',
                            entityId: txRef.id,
                            entityTitle:
                                (_model.textController1.text.trim().isNotEmpty
                                        ? _model.textController1.text
                                        : selectedCategory)
                                    .trim(),
                            after: txData,
                            details: {
                              'message': 'Создан платеж',
                              'amount': moneyAmount.amountCompany,
                              'amount_original': moneyAmount.amountOriginal,
                              'currency_original': moneyAmount.currencyOriginal,
                              'company_currency': moneyAmount.companyCurrency,
                              'exchange_rate_to_company':
                                  moneyAmount.exchangeRateToCompany,
                              'operation_type': _model.dropDownValue1,
                              'account_title': wallet?.name,
                              'category': selectedCategory,
                              'counterparty': _model.textController4.text,
                              'counterparty_type': counterpartyType,
                              'status': _model.dropDownValue4 ?? 'Проведена',
                              'entries_generated': true,
                            },
                          );
                          await TransactionSync.recomputeAllForCompany(
                            companyId,
                          );

                          if (obligationId.isNotEmpty) {
                            final amount = moneyAmount.amountCompany;
                            final obligationRef = FirebaseFirestore.instance
                                .collection('obyaz')
                                .doc(obligationId);
                            final obligationSnap = await obligationRef.get();
                            if (obligationSnap.exists) {
                              final data = Map<String, dynamic>.from(
                                  obligationSnap.data() as Map);
                              final totalPaid =
                                  (data['total_paid'] ?? 0).toDouble();
                              final totalAmount =
                                  (data['amount'] ?? 0).toDouble();
                              final newTotalPaid = totalPaid + amount;
                              final newStatus = newTotalPaid >= totalAmount
                                  ? 'Завершено'
                                  : 'Активно';
                              await obligationRef.update({
                                'total_paid': newTotalPaid,
                                'status': newStatus,
                                'updated_at': FieldValue.serverTimestamp(),
                              });
                              if (companyId.isNotEmpty) {
                                FirestoreQueryCache.instance
                                    .invalidateCompanyCollection(
                                        'obyaz', companyId);
                              } else {
                                FirestoreQueryCache.instance
                                    .invalidateCollection('obyaz');
                              }
                            }
                          }

                          await _applyFundingRequestPayment(
                            requestId: fundingRequestId,
                            transactionId: txRef.id,
                            transactionRef: txRef,
                            paymentAmount: moneyAmount.amountCompany,
                            accountTitle: account.title,
                            accountRef: account.reference,
                            budgetCategory: selectedCategory,
                          );

                          await TransactionSync.recomputeAllForCompany(
                              companyId);
                          Navigator.pop(context);

                          safeSetState(() {});
                        },
                        text: FFLocalizations.of(context).getText(
                          'c66vbz61' /* Добавить */,
                        ),
                        options: FFButtonOptions(
                          height: 48.0,
                          padding: EdgeInsets.all(8.0),
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          color: Color(0xFFB8956A),
                          textStyle:
                              FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                          elevation: 0.0,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ].divide(SizedBox(width: 16.0)),
                ),
              ].divide(SizedBox(height: 24.0)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionCurrencyPreview {
  const _TransactionCurrencyPreview({
    required this.accountCurrency,
    required this.companyCurrency,
    this.defaultExchangeRate,
  });

  final String accountCurrency;
  final String companyCurrency;
  final double? defaultExchangeRate;

  bool get isCrossCurrency => accountCurrency != companyCurrency;
}
