import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/add_schet/add_schet_widget.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/utils/company_lock.dart';
import '/custom_code/widgets/permissions_helper.dart';
import '/user_layout/user_page_layouts.dart';
import '/utils/account_transaction_balance_service.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/app_money_format.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/transaction_sync.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'scheta_model.dart';
export 'scheta_model.dart';

class SchetaWidget extends StatefulWidget {
  const SchetaWidget({super.key, this.embedded = false});

  final bool embedded;

  static String routeName = 'scheta';
  static String routePath = '/scheta';

  @override
  State<SchetaWidget> createState() => _SchetaWidgetState();
}

class _SchetaWidgetState extends State<SchetaWidget> {
  late SchetaModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<bool> _isOwnerFuture;
  bool _isOwner = false;
  bool _warnedCompanyLimit = false;
  Future<List<TranzactionRecord>>? _transactionsFuture;
  String _transactionsFutureKey = '';
  List<TranzactionRecord>? _transactionsCache;
  String _transactionsCacheKey = '';
  String _companyCurrencyCode = 'KZT';
  String _companyCurrencyKey = '';

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

  Map<String, dynamic> _snapshotDataMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Stream<List<ShetaRecord>> _shetaStreamForScope() {
    return queryShetaRecord(
      queryBuilder: (shetaRecord) => _applyCompanyFilter(shetaRecord),
    );
  }

  Future<List<TranzactionRecord>> _transactionsFutureForScope() {
    return _transactionsFutureForCompanyIds(_companyIdsForQuery());
  }

  Future<List<TranzactionRecord>> _transactionsFutureForCompanyIds(
    Iterable<String> companyIds,
  ) {
    final ids = companyIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != '__none__')
        .toSet()
        .toList()
      ..sort();
    final effectiveKey = ids.join('|');
    if (_transactionsFuture == null || _transactionsFutureKey != effectiveKey) {
      _transactionsFutureKey = effectiveKey;
      _transactionsFuture = (() async {
        final transactions = <TranzactionRecord>[];
        if (ids.isEmpty) {
          return transactions;
        }
        for (var index = 0; index < ids.length; index += 10) {
          final end = (index + 10 < ids.length) ? index + 10 : ids.length;
          final chunk = ids.sublist(index, end);
          Query query = TranzactionRecord.collection;
          query = chunk.length == 1
              ? query.where('idCompany', isEqualTo: chunk.first)
              : query.where('idCompany', whereIn: chunk);
          final snapshot = await query.get(
            const GetOptions(source: Source.serverAndCache),
          );
          final loaded = snapshot.docs
              .map(
                (doc) => safeGet(
                  () => TranzactionRecord.fromSnapshot(doc),
                  (error) => debugPrint(
                    'Error serializing doc ${doc.reference.path}:\n$error',
                  ),
                ),
              )
              .whereType<TranzactionRecord>();
          transactions.addAll(loaded);
        }
        _transactionsCache = transactions;
        _transactionsCacheKey = effectiveKey;
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _transactionsFutureKey == effectiveKey) {
              safeSetState(() {});
            }
          });
        }
        return transactions;
      })();
    }
    return _transactionsFuture!;
  }

  void _invalidateTransactionsFuture() {
    _transactionsFuture = null;
    _transactionsFutureKey = '';
    _transactionsCache = null;
    _transactionsCacheKey = '';
  }

  String _formatMoney(num? value, String? symbol) {
    final safeSymbol = (symbol ?? '').trim();
    if (safeSymbol.isNotEmpty) {
      final normalizedSymbol = normalizeCurrencyCode(safeSymbol, fallback: '');
      return formatMoneyWithCurrency(
        value,
        symbol: normalizedSymbol == 'TJS'
            ? moneySymbolForCurrency('TJS')
            : safeSymbol,
      );
    }
    return formatMoneyWithCurrency(value, currencyCode: _companyCurrencyCode);
  }

  String _accountMoneySymbol(ShetaRecord account) {
    return moneySymbolForCurrency(account.accountCurrency);
  }

  Widget _buildLoader() {
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

  Widget _buildAccountsError(String title, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              '${error ?? 'Неизвестная ошибка'}',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                  ),
            ),
            const SizedBox(height: 12.0),
            FFButtonWidget(
              onPressed: () => safeSetState(() {}),
              text: 'Повторить',
              options: FFButtonOptions(
                height: 40.0,
                padding:
                    const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                color: FlutterFlowTheme.of(context).primary,
                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      color: FlutterFlowTheme.of(context).info,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsEmptyState(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: FlutterFlowTheme.of(context).secondaryText,
              size: 42.0,
            ),
            const SizedBox(height: 12.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Добавьте первый счет, чтобы раздел загрузился полностью.',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTotalCard(
    BuildContext context,
    PageLayoutBlockData headerBlock,
    double totalNoOwner,
  ) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final showTotalCard = !_isAllCompaniesScope();
    if (!showTotalCard) {
      return const SizedBox.shrink();
    }
    final headerAccent =
        headerBlock.accentColor ?? FlutterFlowTheme.of(context).primary;
    final headerAccentText = _blockForeground(headerAccent);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: isMobile ? 180.0 : 220.0,
        maxWidth: isMobile ? 260.0 : 300.0,
        minHeight: 72.0,
      ),
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: FlutterFlowTheme.of(context).secondaryBackground,
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: headerAccent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  Icons.attach_money,
                  color: headerAccentText,
                  size: 22.0,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final totalCardBackground =
                        FlutterFlowTheme.of(context).secondaryBackground;
                    final totalCardSecondaryText = _readableTextColor(
                      totalCardBackground,
                      preferred: headerBlock.textColor ??
                          FlutterFlowTheme.of(context).secondaryText,
                      secondary: true,
                    );
                    final totalCardPrimaryText = _readableTextColor(
                      totalCardBackground,
                      preferred: headerBlock.textColor ??
                          FlutterFlowTheme.of(context).primaryText,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Всего в компании',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              FlutterFlowTheme.of(context).labelSmall.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: totalCardSecondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          _formatMoney(totalNoOwner, null),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: isMobile
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                    ),
                                    color: amountTextColor(
                                      context,
                                      totalNoOwner,
                                      positiveColor: totalCardPrimaryText,
                                    ),
                                    fontSize: isMobile ? 18.0 : 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: isMobile
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsTotalSummary(
    BuildContext context,
    double totalNoOwner,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Align(
          alignment: AlignmentDirectional(-1.0, 0.0),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              'Всего',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w900,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional(-1.0, 0.0),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              _formatMoney(totalNoOwner, null),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    color: amountTextColor(
                      context,
                      totalNoOwner,
                      positiveColor: FlutterFlowTheme.of(context).primaryText,
                    ),
                    fontSize: 20.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w900,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  _AccountCardMovementSummary _accountCardTransactionSummary(
    ShetaRecord account,
    Iterable<TranzactionRecord> transactions,
  ) {
    final summary = computeAccountTransactionMovementSummary(
      accountId: account.reference.id,
      storedBalance: account.summa,
      openingBalance: account.openingBalance,
      hasOpeningBalance: account.hasOpeningBalance(),
      transactionPayloads: transactions.map(_transactionPayload),
    );
    return _AccountCardMovementSummary(
      income: summary.income,
      expense: summary.expense,
      incomeCount: summary.incomeCount,
      expenseCount: summary.expenseCount,
      openingBalance: summary.openingBalance,
      closingBalance: summary.closingBalance,
    );
  }

  Map<String, dynamic> _transactionPayload(TranzactionRecord transaction) {
    return {
      ...transaction.snapshotData,
      'type': transaction.type,
      'summa': transaction.summa,
      'schetId': transaction.schetId ?? transaction.snapshotData['schetId'],
      'schet_id': transaction.snapshotData['schet_id'],
      'status': transaction.status,
    };
  }

  double _transactionSignedAmountForAccount(
    TranzactionRecord transaction,
    ShetaRecord account,
  ) {
    return transactionSignedAmountForAccount(
      transaction: _transactionPayload(transaction),
      accountId: account.reference.id,
    );
  }

  String _transactionTitle(TranzactionRecord transaction) {
    final text = transaction.text.trim();
    if (text.isNotEmpty) return text;
    final counterparty = transaction.counterparty.trim();
    if (counterparty.isNotEmpty) return counterparty;
    final category = transaction.kat.trim();
    return category.isEmpty ? 'Операция' : category;
  }

  String _transactionDescription(TranzactionRecord transaction) {
    final parts = <String>[
      transaction.kat.trim(),
      transaction.counterparty.trim(),
      transaction.comment.trim(),
      transaction.paymentPeriod.trim(),
    ].where((part) => part.isNotEmpty).toSet().toList();
    return parts.join(' · ');
  }

  DateTime? _transactionDate(TranzactionRecord transaction) {
    if (transaction.date != null) return transaction.date;
    final raw = transaction.snapshotData['created_at'] ??
        transaction.snapshotData['createdAt'] ??
        transaction.snapshotData['created_time'];
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  double _accountDisplayBalance(
    ShetaRecord account,
    Iterable<TranzactionRecord>? transactions,
  ) {
    if (transactions == null) {
      return account.summa;
    }
    return _accountCardTransactionSummary(account, transactions).closingBalance;
  }

  double _accountsDisplayTotal(
    List<ShetaRecord> items,
    Iterable<TranzactionRecord>? transactions,
  ) {
    final key = _companyIdsFromAccounts(items).join('|');
    final effectiveTransactions = transactions ??
        (_transactionsCacheKey == key ? _transactionsCache : null);
    if (effectiveTransactions == null) {
      _transactionsFutureForCompanyIds(_companyIdsFromAccounts(items));
    }
    return items.fold<double>(0, (totalSoFar, account) {
      final companyBalance = _num(
        account.snapshotData['summa_company'] ??
            account.snapshotData['summaCompany'],
      );
      if (companyBalance != 0) return totalSoFar + companyBalance;
      return totalSoFar +
          _accountDisplayBalance(account, effectiveTransactions);
    });
  }

  double _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  List<String> _companyIdsFromAccounts(Iterable<ShetaRecord> items) {
    return items
        .map((item) => item.idCompany.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<ShetaRecord> _applyScopeToRecords(List<ShetaRecord> items) {
    if (_isAllCompaniesScope()) return items;
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty) return items;
    return items.where((e) => e.idCompany == companyId).toList();
  }

  Future<bool> _isCompanyLocked() async {
    final companyId = _effectiveCompanyId();
    if (companyId.isEmpty) return false;
    final locked = await CompanyLock.isLocked(companyId);
    if (locked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Редактирование отключено после завершения первого входа.'),
        ),
      );
    }
    return locked;
  }

  Future<String?> _renameSchetTitle(
    BuildContext context,
    ShetaRecord record,
    String currentTitle,
  ) async {
    if (!(_isOwner || PermissionsHelper.has('scheta.manage'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостаточно прав для изменения счета')),
      );
      return null;
    }

    final locked = await _isCompanyLocked();
    if (locked) return null;
    if (!context.mounted) return null;

    final controller = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Переименовать счет'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название счета',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();

    final newTitle = (result ?? '').trim();
    if (newTitle.isEmpty || newTitle == currentTitle.trim()) {
      return null;
    }

    try {
      await record.reference.update({
        'title': newTitle,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final trxQuery = await TranzactionRecord.collection
          .where('schetId', isEqualTo: record.reference)
          .get();

      const chunkSize = 400;
      final docs = trxQuery.docs;
      for (var i = 0; i < docs.length; i += chunkSize) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = docs.skip(i).take(chunkSize);
        for (final doc in chunk) {
          batch.update(doc.reference, {'schetTitle': newTitle});
        }
        await batch.commit();
      }

      final debitEntries = await FirebaseFirestore.instance
          .collection('accounting_entries')
          .where('debit_account_id', isEqualTo: record.reference.id)
          .get();
      final creditEntries = await FirebaseFirestore.instance
          .collection('accounting_entries')
          .where('credit_account_id', isEqualTo: record.reference.id)
          .get();
      for (final docs in [debitEntries.docs, creditEntries.docs]) {
        for (var i = 0; i < docs.length; i += chunkSize) {
          final batch = FirebaseFirestore.instance.batch();
          final chunk = docs.skip(i).take(chunkSize);
          for (final doc in chunk) {
            final data = doc.data();
            if ((data['debit_account_id'] ?? '').toString() ==
                record.reference.id) {
              batch.update(doc.reference, {'debit_account_title': newTitle});
            }
            if ((data['credit_account_id'] ?? '').toString() ==
                record.reference.id) {
              batch.update(doc.reference, {'credit_account_title': newTitle});
            }
          }
          await batch.commit();
        }
      }

      if (!mounted || !context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Название счета обновлено')),
      );
      return newTitle;
    } catch (e) {
      if (!mounted || !context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось переименовать счет: $e')),
      );
      return null;
    }
  }

  Future<void> _showSchetTransactions(
      BuildContext context, ShetaRecord record) async {
    final isActive = (record.snapshotData['isActive'] ?? true) == true;
    String accountTitle = record.title;
    DateTimeRange? selectedRange;
    int? selectedYear;
    String filterType = 'all';
    const incomeType = 'income';
    const expenseType = 'decome';
    await showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickRange() async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 1),
                initialDateRange: selectedRange,
              );
              if (picked != null) {
                setModalState(() => selectedRange = picked);
              }
            }

            return Container(
              height: MediaQuery.sizeOf(context).height * 0.75,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16.0)),
              ),
              child: Opacity(
                opacity: isActive ? 1.0 : 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          16.0, 12.0, 16.0, 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Text(
                              'Транзакции: $accountTitle',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                          if (_isOwner ||
                              PermissionsHelper.has('scheta.manage'))
                            IconButton(
                              tooltip: 'Переименовать счет',
                              onPressed: () async {
                                final newTitle = await _renameSchetTitle(
                                  context,
                                  record,
                                  accountTitle,
                                );
                                if (newTitle != null && context.mounted) {
                                  setModalState(() => accountTitle = newTitle);
                                }
                              },
                              icon: Icon(
                                Icons.edit,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 160.0),
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedYear,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsetsDirectional.fromSTEB(
                                        10.0, 6.0, 10.0, 6.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              hint: const Text('Год'),
                              items: List.generate(
                                6,
                                (i) => DateTime.now().year - i,
                              )
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Text('$y'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setModalState(() => selectedYear = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          16.0, 0.0, 16.0, 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedRange == null
                                  ? 'Период: все время'
                                  : 'Период: ${dateTimeFormat('d/M/y', selectedRange!.start, locale: FFLocalizations.of(context).languageCode)} — ${dateTimeFormat('d/M/y', selectedRange!.end, locale: FFLocalizations.of(context).languageCode)}',
                              style: FlutterFlowTheme.of(context).bodySmall,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: pickRange,
                            icon: const Icon(Icons.calendar_month, size: 18.0),
                            label: const Text('Выбрать'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          16.0, 0.0, 16.0, 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ChoiceChip(
                            label: const Text('Все'),
                            selected: filterType == 'all',
                            selectedColor: const Color(0xFFE5E7EB),
                            onSelected: (_) =>
                                setModalState(() => filterType = 'all'),
                          ),
                          ChoiceChip(
                            label: const Text('Доходы'),
                            selected: filterType == incomeType,
                            selectedColor: const Color(0xFFDCFCE7),
                            onSelected: (_) =>
                                setModalState(() => filterType = incomeType),
                          ),
                          ChoiceChip(
                            label: const Text('Расходы'),
                            selected: filterType == expenseType,
                            selectedColor: const Color(0xFFFEE2E2),
                            onSelected: (_) =>
                                setModalState(() => filterType = expenseType),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<TranzactionRecord>>(
                        future: _transactionsFutureForCompanyIds(
                          [record.idCompany],
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Ошибка загрузки операций',
                                style: FlutterFlowTheme.of(context).bodyMedium,
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
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
                          final items = snapshot.data!
                              .where((transaction) =>
                                  _transactionSignedAmountForAccount(
                                      transaction, record) !=
                                  0)
                              .toList()
                            ..sort((a, b) {
                              final bDate = _transactionDate(b) ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              final aDate = _transactionDate(a) ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              return bDate.compareTo(aDate);
                            });
                          final typeFiltered = filterType == 'all'
                              ? items
                              : items.where((transaction) {
                                  final amount =
                                      _transactionSignedAmountForAccount(
                                          transaction, record);
                                  if (filterType == incomeType) {
                                    return amount > 0;
                                  }
                                  return amount < 0;
                                });
                          final yearFiltered = selectedYear == null
                              ? typeFiltered
                              : typeFiltered.where((transaction) {
                                  final date = _transactionDate(transaction);
                                  return date != null &&
                                      date.year == selectedYear;
                                });
                          final filtered = selectedRange == null
                              ? yearFiltered.toList()
                              : yearFiltered.where((transaction) {
                                  final date = _transactionDate(transaction);
                                  if (date == null) return false;
                                  final start = DateTime(
                                    selectedRange!.start.year,
                                    selectedRange!.start.month,
                                    selectedRange!.start.day,
                                  );
                                  final end = DateTime(
                                    selectedRange!.end.year,
                                    selectedRange!.end.month,
                                    selectedRange!.end.day,
                                    23,
                                    59,
                                    59,
                                  );
                                  return date.isAfter(start.subtract(
                                          const Duration(seconds: 1))) &&
                                      date.isBefore(
                                          end.add(const Duration(seconds: 1)));
                                }).toList();

                          final totalSum = filtered.fold<double>(
                              0,
                              (total, transaction) =>
                                  total +
                                  _transactionSignedAmountForAccount(
                                      transaction, record));

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                'Нет транзакций за выбранный период',
                                style: FlutterFlowTheme.of(context).bodyMedium,
                              ),
                            );
                          }

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    16.0, 0.0, 16.0, 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Количество: ${filtered.length}',
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall,
                                      ),
                                    ),
                                    Text(
                                      'Сумма: ${totalSum >= 0 ? '+' : '-'}${_formatMoney(totalSum.abs(), _accountMoneySymbol(record))}',
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final transaction = filtered[index];
                                    final signedAmount =
                                        _transactionSignedAmountForAccount(
                                            transaction, record);
                                    final isPositive = signedAmount >= 0;
                                    final title =
                                        _transactionTitle(transaction);
                                    final description =
                                        _transactionDescription(transaction);
                                    final entryDate =
                                        _transactionDate(transaction);
                                    return Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              12.0, 6.0, 12.0, 6.0),
                                      child: Card(
                                        clipBehavior:
                                            Clip.antiAliasWithSaveLayer,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        elevation: 6.0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Icon(
                                                isPositive
                                                    ? Icons.trending_up
                                                    : Icons.trending_down,
                                                color: isPositive
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .success
                                                    : Color(0xFFB80A14),
                                                size: 20.0,
                                              ),
                                              const SizedBox(width: 10.0),
                                              Expanded(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      title,
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium,
                                                    ),
                                                    if (description
                                                            .isNotEmpty &&
                                                        description != title)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsetsDirectional
                                                                .fromSTEB(0.0,
                                                                4.0, 0.0, 0.0),
                                                        child: Text(
                                                          description,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodySmall,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${isPositive ? '+' : '-'}${_formatMoney(
                                                      signedAmount.abs(),
                                                      _accountMoneySymbol(
                                                        record,
                                                      ),
                                                    )}',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: isPositive
                                                              ? FlutterFlowTheme
                                                                      .of(
                                                                          context)
                                                                  .success
                                                              : Color(
                                                                  0xFFB80A14),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  if (entryDate != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(0.0,
                                                              4.0, 0.0, 0.0),
                                                      child: Text(
                                                        dateTimeFormat(
                                                          'd/M/y',
                                                          entryDate,
                                                          locale:
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .languageCode,
                                                        ),
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showWithdrawalDialog(
      BuildContext context, ShetaRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    final amountController = TextEditingController();
    final commentController = TextEditingController();
    String? selectedCategory;
    LedgerScope ledgerScope = LedgerScope.management;
    final defaultCategories = ['Дивиденды', 'Личные расходы', 'Взнос в банк'];
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (alertContext) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Изъятие'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('statRashod')
                            .where(
                              'idCompany',
                              isEqualTo: record.idCompany.isNotEmpty
                                  ? record.idCompany
                                  : _effectiveCompanyId(),
                            )
                            .snapshots(),
                        builder: (context, snapshot) {
                          final items = [
                            ...defaultCategories,
                            if (snapshot.hasData)
                              ...snapshot.data!.docs.map((d) {
                                final data = _snapshotDataMap(d.data());
                                final type =
                                    (data['type'] ?? '').toString().trim();
                                if (type.isNotEmpty && type != 'expense') {
                                  return '';
                                }
                                return (data['title'] ??
                                        data['name'] ??
                                        data['category_name'] ??
                                        '')
                                    .toString();
                              }).where((v) => v.trim().isNotEmpty),
                          ].toSet().toList();

                          if (selectedCategory == null && items.isNotEmpty) {
                            selectedCategory = items.first;
                          }

                          return DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            items: items
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => selectedCategory = val);
                            },
                            decoration:
                                const InputDecoration(labelText: 'Категория'),
                          );
                        },
                      ),
                      DropdownButtonFormField<LedgerScope>(
                        initialValue: ledgerScope,
                        decoration:
                            const InputDecoration(labelText: 'Тип учета'),
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
                        onChanged: (val) {
                          setState(
                            () => ledgerScope = val ?? LedgerScope.management,
                          );
                        },
                      ),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Сумма'),
                      ),
                      TextFormField(
                        controller: commentController,
                        decoration:
                            const InputDecoration(labelText: 'Комментарий'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(alertContext, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(alertContext, true),
                      child: const Text('Сохранить'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }
    if (amount > (record.summa)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Недостаточно средств на счете')),
      );
      return;
    }
    await record.reference.update({
      ...mapToFirestore(
        {
          'summa': FieldValue.increment(-amount),
        },
      ),
    });
    final userScheta = await querySchetaRecordOnce(
      parent: currentUserReference,
      singleRecord: true,
    ).then((s) => s.firstOrNull);
    if (userScheta != null) {
      await userScheta.reference.update({
        ...mapToFirestore(
          {
            'myMoney': FieldValue.increment(-amount),
          },
        ),
      });
    }
    final txRef = TranzactionRecord.collection.doc();
    final legacyTypeUchet = ledgerScope.legacyTypeUchet;
    final txData = {
      ...createTranzactionRecordData(
        type: 'decome',
        typeUchet: legacyTypeUchet,
        ledgerScope: ledgerScope.storageValue,
        kat: selectedCategory ?? 'Изъятие',
        text: commentController.text,
        summa: amount,
        idCompany: _effectiveCompanyId(),
      ),
      ...mapToFirestore(
        transactionMoneyFieldsForAccountData(
          amountOriginal: amount,
          accountData: record.snapshotData,
        ),
      ),
      ...mapToFirestore(
        {
          'date': FieldValue.serverTimestamp(),
          'schetId': record.reference,
          'schetTitle': record.title,
        },
      ),
    };
    await txRef.set(txData);
    await createEntriesForTransaction(
      firestore: FirebaseFirestore.instance,
      transactionRef: txRef,
      transactionData: txData,
    );
    await TransactionSync.recomputeAllForCompany(_effectiveCompanyId());
    _invalidateTransactionsFuture();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SchetaModel());
    _isOwnerFuture = _checkIsOwner();
    _isOwnerFuture.then((value) {
      if (mounted) {
        setState(() => _isOwner = value);
      }
    });
    _loadCompanyCurrency();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<bool> _checkIsOwner() async {
    final user = currentUser;
    if (user == null) return false;
    final companyId = _effectiveCompanyId().trim();
    if (companyId.isEmpty) return false;
    final snap = await FirebaseFirestore.instance
        .collection('company_profile')
        .where('idCompany', isEqualTo: companyId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data();
      final ownerId = (data['user_id'] ??
              data['ownerId'] ??
              data['owner_id'] ??
              data['uid'] ??
              data['directorId'] ??
              data['director_id'])
          ?.toString();
      if (ownerId != null && ownerId.isNotEmpty && ownerId == user.uid) {
        return true;
      }
    }
    final docSnap = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(companyId)
        .get();
    if (docSnap.exists) {
      final data = docSnap.data() ?? {};
      final ownerId = (data['user_id'] ??
              data['ownerId'] ??
              data['owner_id'] ??
              data['uid'] ??
              data['directorId'] ??
              data['director_id'])
          ?.toString();
      if (ownerId != null && ownerId.isNotEmpty && ownerId == user.uid) {
        return true;
      }
    }
    return (currentUserDocument?.role ?? '') == 'owner';
  }

  Future<void> _loadCompanyCurrency() async {
    final companyId = _effectiveCompanyId().trim();
    if (companyId.isEmpty || companyId == _companyCurrencyKey) return;
    _companyCurrencyKey = companyId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('company_profile')
          .doc(companyId)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};
      final profile = countryProfileFromData(data);
      final currency = companyCurrencyFromProfileData(
        data,
        fallback: profile.baseCurrency,
      );
      if (!mounted) return;
      setState(() => _companyCurrencyCode = currency);
    } catch (e) {
      debugPrint('Error loading account company currency: $e');
    }
  }

  Widget _buildRoleLine(BuildContext context, {Color? textColor}) {
    return AuthUserStreamWidget(
      builder: (context) {
        final role = valueOrDefault(currentUserDocument?.role, 'не задана');
        final ownerLabel = _isOwner ? 'Да' : 'Нет';
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16.0, 4.0, 16.0, 0.0),
          child: Text(
            'Роль: $role • Владелец: $ownerLabel',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
                  color:
                      textColor ?? FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                ),
          ),
        );
      },
    );
  }

  Color _blockForeground(Color background) {
    return background.computeLuminance() > 0.55
        ? const Color(0xFF0F172A)
        : Colors.white;
  }

  double _contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final bright = max(l1, l2);
    final dark = min(l1, l2);
    return (bright + 0.05) / (dark + 0.05);
  }

  Color _readableTextColor(
    Color background, {
    Color? preferred,
    bool secondary = false,
  }) {
    final fallbackBase = _blockForeground(background);
    final fallback = secondary
        ? Color.lerp(fallbackBase, background,
                fallbackBase == Colors.white ? 0.22 : 0.38) ??
            fallbackBase
        : fallbackBase;
    if (preferred == null) return fallback;
    if (_contrastRatio(preferred, background) >= (secondary ? 3.2 : 4.5)) {
      return preferred;
    }
    return fallback;
  }

  Color _sectionSurface(Color lightColor) {
    final theme = FlutterFlowTheme.of(context);
    if (Theme.of(context).brightness == Brightness.dark) {
      return Color.lerp(
            theme.secondaryBackground,
            lightColor,
            0.14,
          ) ??
          theme.secondaryBackground;
    }
    return lightColor;
  }

  Widget _decorateLayoutBlock(
    BuildContext context,
    PageLayoutBlockData block,
    Widget child, {
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
    EdgeInsetsGeometry margin = const EdgeInsets.only(top: 10.0),
  }) {
    final background = block.backgroundColor;
    final border = block.borderColor;
    if (background == null && border == null) {
      return Padding(
        padding: margin,
        child: child,
      );
    }
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: border ?? FlutterFlowTheme.of(context).alternate,
        ),
      ),
      child: child,
    );
  }

  Widget _buildSchetSectionHeader(
    BuildContext context,
    String title,
    double total, {
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10.0, 12.0, 10.0, 0.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    color: textColor,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w900,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ),
          Text(
            _formatMoney(total, null),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  color:
                      total < 0 ? amountTextColor(context, total) : textColor,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w800,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchetaHeader(
    BuildContext context,
    Widget totalCard,
    Widget addButton, {
    required bool showTotalCard,
    Color? textColor,
    Color? accentColor,
  }) {
    final buttonFill = accentColor ?? FlutterFlowTheme.of(context).primary;
    final buttonIcon = _blockForeground(buttonFill);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            if ((Theme.of(context).brightness == Brightness.light) == true)
              Padding(
                padding: EdgeInsets.all(10.0),
                child: FlutterFlowIconButton(
                  borderRadius: 8.0,
                  buttonSize: 40.0,
                  fillColor: buttonFill,
                  icon: Icon(
                    Icons.dark_mode,
                    color: buttonIcon,
                    size: 24.0,
                  ),
                  onPressed: () async {
                    setDarkModeSetting(context, ThemeMode.dark);
                  },
                ),
              ),
            if ((Theme.of(context).brightness == Brightness.dark) == true)
              Padding(
                padding: EdgeInsets.all(10.0),
                child: FlutterFlowIconButton(
                  borderRadius: 8.0,
                  buttonSize: 40.0,
                  fillColor: buttonFill,
                  icon: Icon(
                    Icons.light_mode,
                    color: buttonIcon,
                    size: 24.0,
                  ),
                  onPressed: () async {
                    setDarkModeSetting(context, ThemeMode.light);
                  },
                ),
              ),
          ],
        ),
        FlutterFlowIconButton(
          borderRadius: 8.0,
          buttonSize: 40.0,
          fillColor: buttonFill,
          icon: Icon(
            Icons.notifications_sharp,
            color: buttonIcon,
            size: 24.0,
          ),
          onPressed: () {},
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
          child: FlutterFlowIconButton(
            borderRadius: 8.0,
            buttonSize: 40.0,
            fillColor: buttonFill,
            icon: Icon(
              Icons.person_sharp,
              color: buttonIcon,
              size: 24.0,
            ),
            onPressed: () {},
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12.0,
                runSpacing: 8.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Счета',
                    style: FlutterFlowTheme.of(context).headlineSmall.override(
                          font: GoogleFonts.interTight(
                            fontWeight: FontWeight.w700,
                            fontStyle: FlutterFlowTheme.of(context)
                                .headlineSmall
                                .fontStyle,
                          ),
                          color: textColor,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .fontStyle,
                        ),
                  ),
                  if (currentUserUid.isNotEmpty) CompanySwitcherInline(),
                  if (showTotalCard) totalCard,
                  addButton,
                ],
              ),
              SizedBox(height: 8.0),
              Align(
                alignment: Alignment.centerRight,
                child: actions,
              ),
            ],
          );
        }

        return Row(
          children: [
            Text(
              'Счета',
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    font: GoogleFonts.interTight(
                      fontWeight: FontWeight.w700,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                    ),
                    color: textColor,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w700,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineSmall.fontStyle,
                  ),
            ),
            SizedBox(width: 12.0),
            if (currentUserUid.isNotEmpty) CompanySwitcherInline(),
            SizedBox(width: 12.0),
            if (showTotalCard) ...[
              Flexible(child: totalCard),
              SizedBox(width: 12.0),
            ],
            addButton,
            Spacer(),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildMobileSchetSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<ShetaRecord> items,
    required bool isOwner,
    Iterable<TranzactionRecord>? transactions,
    Color? textColor,
    Color? borderColor,
    Color? accentColor,
  }) {
    final total = _accountsDisplayTotal(items, transactions);
    final resolvedTextColor = _readableTextColor(
      color,
      preferred: textColor,
    );
    final resolvedSecondaryTextColor = _readableTextColor(
      color,
      preferred: textColor ?? FlutterFlowTheme.of(context).secondaryText,
      secondary: true,
    );
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: borderColor ?? FlutterFlowTheme.of(context).alternate,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('scheta_mobile_section_$title'),
          maintainState: true,
          leading: Container(
            width: 36.0,
            height: 36.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(
              icon,
              color: accentColor ?? FlutterFlowTheme.of(context).primary,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                        ),
                        color: resolvedTextColor,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                _formatMoney(total, null),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                      ),
                      color: amountTextColor(
                        context,
                        total,
                        positiveColor: resolvedTextColor,
                      ),
                      fontSize: 18.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          subtitle: Text(
            '${items.length} счет(ов)',
            style: FlutterFlowTheme.of(context).labelSmall.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                  color: resolvedSecondaryTextColor,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          children: [
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Нет счетов',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(),
                        color: resolvedSecondaryTextColor,
                        letterSpacing: 0.0,
                      ),
                ),
              )
            else
              ListView.builder(
                padding: EdgeInsets.only(bottom: 8.0),
                primary: false,
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final record = items[index];
                  final canManage =
                      isOwner || PermissionsHelper.has('scheta.manage');
                  return _buildSchetCard(
                    context,
                    record,
                    canManage: canManage,
                    transactions: transactions,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchetCard(
    BuildContext context,
    ShetaRecord record, {
    required bool canManage,
    Iterable<TranzactionRecord>? transactions,
  }) {
    final isActive = (record.snapshotData['isActive'] ?? true) == true;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final cardColor = isActive
        ? FlutterFlowTheme.of(context).secondaryBackground
        : FlutterFlowTheme.of(context).alternate;
    final cardPrimaryText = _readableTextColor(
      cardColor,
      preferred: FlutterFlowTheme.of(context).primaryText,
    );
    final cardSecondaryText = _readableTextColor(
      cardColor,
      preferred: FlutterFlowTheme.of(context).secondaryText,
      secondary: true,
    );
    final typeUchetRaw = (record.snapshotData['typeUchet'] ?? '').toString();
    final typeUchet = typeUchetRaw.isEmpty
        ? normalizeLegacyTypeUchet(
            record.snapshotData['ledger_scope']?.toString())
        : typeUchetRaw;
    final scope = ledgerScopeFromLegacyValue(typeUchet);
    final uchetLabel = scope == LedgerScope.accounting
        ? 'Бухгалтерский (Б)'
        : scope == LedgerScope.both
            ? 'Общий учет (О)'
            : 'Управленческий (С)';
    final ownerKind = (record.snapshotData['ownerKind'] ?? '').toString();
    final ownerCurrency = (record.snapshotData['currency'] ?? '').toString();
    return Padding(
      padding: EdgeInsets.all(6.0),
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: cardColor,
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: InkWell(
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: isActive
              ? () async {
                  await _showSchetTransactions(context, record);
                }
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Stack(
                        children: [
                          if (record.tip == 'nal')
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 8.0,
                                buttonSize: 36.0,
                                fillColor: FlutterFlowTheme.of(context).primary,
                                icon: Icon(
                                  Icons.payments_outlined,
                                  color: FlutterFlowTheme.of(context).info,
                                  size: 22.0,
                                ),
                                onPressed: () {
                                  debugPrint('nal pressed');
                                },
                              ),
                            ),
                          if (record.tip == 'bank')
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 8.0,
                                buttonSize: 36.0,
                                fillColor: FlutterFlowTheme.of(context).success,
                                icon: FaIcon(
                                  FontAwesomeIcons.landmark,
                                  color: FlutterFlowTheme.of(context).info,
                                  size: 22.0,
                                ),
                                onPressed: () {
                                  debugPrint('bank pressed');
                                },
                              ),
                            ),
                          if (record.tip == 'my')
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 8.0,
                                buttonSize: 36.0,
                                fillColor: FlutterFlowTheme.of(context).accent2,
                                icon: Icon(
                                  Icons.monetization_on_sharp,
                                  color: FlutterFlowTheme.of(context).info,
                                  size: 22.0,
                                ),
                                onPressed: () {
                                  debugPrint('my pressed');
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(8.0, 8.0, 0.0, 0.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            record.title,
                            minFontSize: 14.0,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: cardPrimaryText,
                                  fontSize: 18.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                          if (!isActive)
                            Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Неактивен',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: cardSecondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          Align(
                            alignment: AlignmentDirectional(-1.0, 0.0),
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Material(
                                color: Colors.transparent,
                                elevation: 6.0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Container(
                                  height: 24.0,
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8.0),
                                  decoration: BoxDecoration(
                                    color: _sectionSurface(
                                      record.tip == 'bank'
                                          ? const Color(0xFFEFF6FF)
                                          : record.tip == 'nal'
                                              ? const Color(0xFFF0FDF4)
                                              : const Color(0xFFFFF7ED),
                                    ),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  child: Text(
                                    () {
                                      if (record.tip == 'nal') {
                                        return 'Наличные';
                                      } else if (record.tip == 'bank') {
                                        return 'Банк';
                                      } else {
                                        return 'Средства владельца';
                                      }
                                    }(),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: _readableTextColor(
                                            _sectionSurface(
                                              record.tip == 'bank'
                                                  ? const Color(0xFFEFF6FF)
                                                  : record.tip == 'nal'
                                                      ? const Color(0xFFF0FDF4)
                                                      : const Color(0xFFFFF7ED),
                                            ),
                                            preferred: cardPrimaryText,
                                          ),
                                          fontSize: 10.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Учет: $uchetLabel',
                              style: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: cardSecondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (record.tip == 'my' &&
                              (ownerKind.isNotEmpty ||
                                  ownerCurrency.isNotEmpty))
                            Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                [
                                  if (ownerKind.isNotEmpty)
                                    ownerKind == 'card'
                                        ? 'Карточный'
                                        : ownerKind == 'cash'
                                            ? 'Наличный'
                                            : ownerKind,
                                  if (ownerCurrency.isNotEmpty) ownerCurrency,
                                ].join(' • '),
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: cardSecondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (record.tip == 'my')
                    Padding(
                      padding: EdgeInsets.all(4.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await _showWithdrawalDialog(context, record);
                          safeSetState(() {});
                        },
                        child: Icon(
                          Icons.remove_circle_outline,
                          color: FlutterFlowTheme.of(context).accent2,
                          size: 22.0,
                        ),
                      ),
                    ),
                ],
              ),
              FutureBuilder<List<TranzactionRecord>>(
                future: transactions == null
                    ? _transactionsFutureForCompanyIds([record.idCompany])
                    : Future.value(transactions.toList()),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(6.0, 4.0, 6.0, 6.0),
                      child: Text(
                        'Движения по счету не загрузились',
                        style: FlutterFlowTheme.of(context).labelSmall.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                              color: FlutterFlowTheme.of(context).error,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    );
                  }
                  final loadedTransactions =
                      snapshot.data ?? const <TranzactionRecord>[];
                  final movements = _accountCardTransactionSummary(
                    record,
                    loadedTransactions,
                  );
                  final displayTotal = _accountDisplayBalance(
                    record,
                    snapshot.hasData ? loadedTransactions : null,
                  );
                  final incomeCount = movements.incomeCount;
                  final expenseCount = movements.expenseCount;
                  final incomeSum = movements.income;
                  final expenseSum = movements.expense;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Text(
                                'Всего',
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
                                      color: cardPrimaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional(1.0, 0.0),
                              child: Padding(
                                padding: EdgeInsets.all(6.0),
                                child: Text(
                                  _formatMoney(
                                    displayTotal,
                                    null,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: isMobile
                                              ? FontWeight.w800
                                              : FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        fontSize: isMobile ? 18.0 : null,
                                        color: amountTextColor(
                                          context,
                                          displayTotal,
                                          positiveColor: cardPrimaryText,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: isMobile
                                            ? FontWeight.w800
                                            : FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (movements.openingBalance != 0)
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 0.0, 6.0, 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: Text(
                                  record.openingBalanceDate == null
                                      ? 'Начальный остаток'
                                      : 'Начальный остаток на ${dateTimeFormat(
                                          'd/M/y',
                                          record.openingBalanceDate!,
                                          locale: FFLocalizations.of(context)
                                              .languageCode,
                                        )}',
                                  style: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: cardSecondaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Text(
                                _formatMoney(
                                  movements.openingBalance,
                                  _accountMoneySymbol(record),
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: cardSecondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 6.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Text(
                                'Приходы: $incomeCount / ${_formatMoney(incomeSum, _accountMoneySymbol(record))}',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: amountTextColor(
                                        context,
                                        incomeSum,
                                        positiveColor: cardSecondaryText,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional(1.0, 0.0),
                                child: Text(
                                  'Расходы: $expenseCount / ${_formatMoney(expenseSum, _accountMoneySymbol(record))}',
                                  style: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: amountTextColor(
                                          context,
                                          -expenseSum,
                                          positiveColor: cardSecondaryText,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                      'Создан: ${dateTimeFormat(
                        "relative",
                        record.dateCreate,
                        locale: FFLocalizations.of(context).languageCode,
                      )}',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: cardSecondaryText,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ShetaRecord> _sortSchetaActiveFirst(List<ShetaRecord> items) {
    final sorted = List<ShetaRecord>.from(items);
    sorted.sort((a, b) {
      final aActive = (a.snapshotData['isActive'] ?? true) == true;
      final bActive = (b.snapshotData['isActive'] ?? true) == true;
      if (aActive == bActive) return 0;
      return aActive ? -1 : 1;
    });
    return sorted;
  }

  bool _isAllCompaniesScope() {
    final scopeRaw = currentUserDocument?.snapshotData['companyScope'] ??
        currentUserDocument?.snapshotData['company_scope'];
    final scope = (scopeRaw ?? 'single').toString();
    final raw = (currentUserDocument?.idCompany ?? '').trim();
    return scope == 'all' || raw == '__all__';
  }

  Map<String, double> _sumByTip(
    List<ShetaRecord> items, [
    Iterable<TranzactionRecord>? transactions,
  ]) {
    final key = _companyIdsFromAccounts(items).join('|');
    final effectiveTransactions = transactions ??
        (_transactionsCacheKey == key ? _transactionsCache : null);
    if (effectiveTransactions == null) {
      _transactionsFutureForCompanyIds(_companyIdsFromAccounts(items));
    }
    double bank = 0;
    double nal = 0;
    double my = 0;
    for (final item in items) {
      final amount = _accountDisplayBalance(item, effectiveTransactions);
      if (item.tip == 'bank') {
        bank += amount;
      } else if (item.tip == 'nal') {
        nal += amount;
      } else if (item.tip == 'my') {
        my += amount;
      }
    }
    return {'bank': bank, 'nal': nal, 'my': my};
  }

  Widget _buildCompanyTypeBlock(
    BuildContext context,
    String title,
    List<ShetaRecord> items, {
    required Color background,
    Iterable<TranzactionRecord>? transactions,
    Color? textColor,
    Color? borderColor,
  }) {
    final total = _accountsDisplayTotal(items, transactions);
    final resolvedTextColor = _readableTextColor(
      background,
      preferred: textColor,
    );
    final resolvedSecondaryTextColor = _readableTextColor(
      background,
      preferred: textColor ?? FlutterFlowTheme.of(context).secondaryText,
      secondary: true,
    );
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
      padding: EdgeInsetsDirectional.fromSTEB(8.0, 6.0, 8.0, 10.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: borderColor ?? FlutterFlowTheme.of(context).alternate,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSchetSectionHeader(
            context,
            title,
            total,
            textColor: resolvedTextColor,
          ),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(10.0, 8.0, 10.0, 0.0),
              child: Text(
                'Нет счетов',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(),
                      color: resolvedSecondaryTextColor,
                      letterSpacing: 0.0,
                    ),
              ),
            )
          else
            ListView.builder(
              padding: EdgeInsets.zero,
              primary: false,
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final record = items[index];
                final canManage =
                    _isOwner || PermissionsHelper.has('scheta.manage');
                return _buildSchetCard(
                  context,
                  record,
                  canManage: canManage,
                  transactions: transactions,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCompanyBreakdown(
    BuildContext context,
    List<ShetaRecord> allRecords, {
    PageLayoutBlockData? layoutBlock,
  }) {
    if (!_isAllCompaniesScope()) {
      return SizedBox.shrink();
    }
    final allowedIds = _companyIdsForQuery().toSet();
    if (allowedIds.isEmpty) {
      return SizedBox.shrink();
    }
    final limitedIds = allowedIds.length > 10
        ? allowedIds.take(10).toList()
        : allowedIds.toList();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: limitedIds)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }
        final docs = snapshot.data!.docs
            .where((d) => allowedIds.contains(d.id))
            .toList();
        if (docs.isEmpty) {
          return SizedBox.shrink();
        }
        docs.sort((a, b) {
          final an = _snapshotDataMap(a.data())['name']?.toString() ?? '';
          final bn = _snapshotDataMap(b.data())['name']?.toString() ?? '';
          return an.compareTo(bn);
        });
        return FutureBuilder<List<TranzactionRecord>>(
          future: _transactionsFutureForScope(),
          builder: (context, transactionsSnapshot) {
            final transactions =
                transactionsSnapshot.hasData ? transactionsSnapshot.data : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(10.0, 16.0, 10.0, 0.0),
                  child: Text(
                    'Счета по компаниям',
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                ...docs.map((doc) {
                  final data = _snapshotDataMap(doc.data());
                  final name = (data['name'] ?? 'Компания').toString();
                  final companyRecords =
                      allRecords.where((r) => r.idCompany == doc.id).toList();
                  final bank = _sortSchetaActiveFirst(
                      companyRecords.where((e) => e.tip == 'bank').toList());
                  final cash = _sortSchetaActiveFirst(
                      companyRecords.where((e) => e.tip == 'nal').toList());
                  final owner = _sortSchetaActiveFirst(
                      companyRecords.where((e) => e.tip == 'my').toList());

                  final showBank =
                      _isOwner || PermissionsHelper.has('scheta.blocks.bank');
                  final showCash =
                      _isOwner || PermissionsHelper.has('scheta.blocks.cash');
                  final showOwner =
                      _isOwner || PermissionsHelper.has('scheta.blocks.owner');

                  final blocks = <Widget>[
                    if (showBank)
                      _buildCompanyTypeBlock(
                        context,
                        'Банковские счета',
                        bank,
                        background: _sectionSurface(const Color(0xFFEFF6FF)),
                        transactions: transactions,
                        textColor: layoutBlock?.textColor,
                        borderColor: layoutBlock?.borderColor,
                      ),
                    if (showCash)
                      _buildCompanyTypeBlock(
                        context,
                        'Наличные',
                        cash,
                        background: _sectionSurface(const Color(0xFFF0FDF4)),
                        transactions: transactions,
                        textColor: layoutBlock?.textColor,
                        borderColor: layoutBlock?.borderColor,
                      ),
                    if (showOwner)
                      _buildCompanyTypeBlock(
                        context,
                        'Средства владельца',
                        owner,
                        background: _sectionSurface(const Color(0xFFFFF7ED)),
                        transactions: transactions,
                        textColor: layoutBlock?.textColor,
                        borderColor: layoutBlock?.borderColor,
                      ),
                  ];
                  return Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(10.0, 12.0, 10.0, 0.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: layoutBlock?.backgroundColor ??
                            FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: layoutBlock?.borderColor ??
                              FlutterFlowTheme.of(context).alternate,
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: PageStorageKey<String>(
                              'scheta_company_${doc.id}'),
                          maintainState: true,
                          title: Text(
                            name,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  color: _readableTextColor(
                                    layoutBlock?.backgroundColor ??
                                        FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                    preferred: layoutBlock?.textColor ??
                                        FlutterFlowTheme.of(context)
                                            .primaryText,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12.0, 0.0, 12.0, 12.0),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 700;
                                  if (isNarrow || blocks.length <= 1) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: blocks
                                          .map((b) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8.0),
                                                child: b,
                                              ))
                                          .toList(),
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (int i = 0;
                                          i < blocks.length;
                                          i++) ...[
                                        if (i > 0) const SizedBox(width: 12.0),
                                        Expanded(child: blocks[i]),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    _loadCompanyCurrency();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        drawer: widget.embedded
            ? null
            : Drawer(
                elevation: 16.0,
                child: wrapWithModel(
                  model: _model.drawersUsersModel2,
                  updateCallback: () => safeSetState(() {}),
                  child: DrawersUsersWidget(),
                ),
              ),
        body: AuthUserStreamWidget(
          builder: (context) => Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.embedded &&
                  responsiveVisibility(
                    context: context,
                    phone: false,
                    tablet: false,
                  ))
                Container(
                  width: FFAppState().userSidebarCollapsed ? 88.0 : 270.0,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
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
                  child: SafeArea(
                    child: Container(
                      width: MediaQuery.sizeOf(context).width * 1.0,
                      constraints: BoxConstraints(
                        maxWidth: 1170.0,
                      ),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      child: SingleChildScrollView(
                        primary: false,
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 12.0, 0.0),
                          child: StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _effectiveCompanyId().isEmpty
                                ? null
                                : FirebaseFirestore.instance
                                    .collection('companies')
                                    .doc(_effectiveCompanyId())
                                    .snapshots(),
                            builder: (context, companySnapshot) {
                              final companyData =
                                  companySnapshot.data?.data() ??
                                      const <String, dynamic>{};
                              final layout =
                                  SchetaPageLayoutData.fromCompanyData(
                                      companyData);
                              final headerBlock = layout.block('header');
                              final roleBlock = layout.block('role_info');
                              final accountsBlock = layout.block('accounts');
                              return Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      if (!widget.embedded &&
                                          responsiveVisibility(
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
                                                    FlutterFlowTheme.of(context)
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
                                              child: AuthUserStreamWidget(
                                                builder: (context) =>
                                                    StreamBuilder<
                                                        List<SchetaRecord>>(
                                                  stream: querySchetaRecord(
                                                    parent:
                                                        currentUserReference,
                                                    singleRecord: true,
                                                  ),
                                                  builder: (context, snapshot) {
                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        AuthUserStreamWidget(
                                                          builder: (context) =>
                                                              StreamBuilder<
                                                                  List<
                                                                      ShetaRecord>>(
                                                            stream:
                                                                _shetaStreamForScope(),
                                                            builder: (context,
                                                                snapshot) {
                                                              final items =
                                                                  snapshot.data ??
                                                                      [];
                                                              final sums =
                                                                  _sumByTip(
                                                                      items);
                                                              final totalNoOwner =
                                                                  (sums['bank'] ??
                                                                          0) +
                                                                      (sums['nal'] ??
                                                                          0);
                                                              final showTotalCard =
                                                                  !_isAllCompaniesScope();
                                                              final headerAccent = headerBlock
                                                                      .accentColor ??
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .primary;
                                                              final headerAccentText =
                                                                  _blockForeground(
                                                                headerAccent,
                                                              );
                                                              final totalCard =
                                                                  _buildHeaderTotalCard(
                                                                context,
                                                                headerBlock,
                                                                totalNoOwner,
                                                              );
                                                              final addButton =
                                                                  FFButtonWidget(
                                                                onPressed:
                                                                    () async {
                                                                  if (await _isCompanyLocked()) {
                                                                    return;
                                                                  }
                                                                  if (!context
                                                                      .mounted) {
                                                                    return;
                                                                  }
                                                                  await showModalBottomSheet(
                                                                    isScrollControlled:
                                                                        true,
                                                                    backgroundColor:
                                                                        Colors
                                                                            .transparent,
                                                                    useSafeArea:
                                                                        true,
                                                                    context:
                                                                        context,
                                                                    builder:
                                                                        (context) {
                                                                      return GestureDetector(
                                                                        onTap:
                                                                            () {
                                                                          FocusScope.of(context)
                                                                              .unfocus();
                                                                          FocusManager
                                                                              .instance
                                                                              .primaryFocus
                                                                              ?.unfocus();
                                                                        },
                                                                        child:
                                                                            Padding(
                                                                          padding:
                                                                              MediaQuery.viewInsetsOf(context),
                                                                          child:
                                                                              Container(
                                                                            height:
                                                                                MediaQuery.sizeOf(context).height * 0.8,
                                                                            child:
                                                                                AddSchetWidget(),
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  ).then((value) =>
                                                                      safeSetState(
                                                                          () {}));
                                                                },
                                                                text: FFLocalizations.of(
                                                                        context)
                                                                    .getText(
                                                                  '58hpkz9s' /* Добавить счет  */,
                                                                ),
                                                                options:
                                                                    FFButtonOptions(
                                                                  height: 40.0,
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          16.0,
                                                                          0.0,
                                                                          16.0,
                                                                          0.0),
                                                                  iconPadding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  color:
                                                                      headerAccent,
                                                                  textStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .interTight(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .titleSmall
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .titleSmall
                                                                              .fontStyle,
                                                                        ),
                                                                        color:
                                                                            headerAccentText,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontStyle,
                                                                      ),
                                                                  elevation:
                                                                      0.0,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8.0),
                                                                ),
                                                              );

                                                              if (!headerBlock
                                                                  .visible) {
                                                                return const SizedBox
                                                                    .shrink();
                                                              }
                                                              return _decorateLayoutBlock(
                                                                context,
                                                                headerBlock,
                                                                _buildSchetaHeader(
                                                                  context,
                                                                  totalCard,
                                                                  addButton,
                                                                  showTotalCard:
                                                                      showTotalCard,
                                                                  textColor:
                                                                      headerBlock
                                                                          .textColor,
                                                                  accentColor:
                                                                      headerBlock
                                                                          .accentColor,
                                                                ),
                                                                margin:
                                                                    EdgeInsets
                                                                        .zero,
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        if (roleBlock.visible)
                                                          _decorateLayoutBlock(
                                                            context,
                                                            roleBlock,
                                                            _buildRoleLine(
                                                              context,
                                                              textColor:
                                                                  roleBlock
                                                                      .textColor,
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 4.0,
                                                              vertical: 4.0,
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SingleChildScrollView(
                                    primary: false,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            if (accountsBlock.visible &&
                                                responsiveVisibility(
                                                  context: context,
                                                  tabletLandscape: false,
                                                  desktop: false,
                                                ))
                                              Container(
                                                width: double.infinity,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height *
                                                        1.0,
                                                decoration: BoxDecoration(
                                                  color: accountsBlock
                                                          .backgroundColor ??
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .secondaryBackground,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          18.0),
                                                  border: Border.all(
                                                    color: accountsBlock
                                                            .borderColor ??
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .alternate,
                                                  ),
                                                ),
                                                alignment: AlignmentDirectional(
                                                    0.0, -1.0),
                                                child: SingleChildScrollView(
                                                  primary: false,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        10.0,
                                                                        0.0,
                                                                        10.0,
                                                                        0.0),
                                                            child:
                                                                FFButtonWidget(
                                                              onPressed:
                                                                  () async {
                                                                if (await _isCompanyLocked()) {
                                                                  return;
                                                                }
                                                                if (!context
                                                                    .mounted) {
                                                                  return;
                                                                }
                                                                await showModalBottomSheet(
                                                                  isScrollControlled:
                                                                      true,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .transparent,
                                                                  enableDrag:
                                                                      false,
                                                                  context:
                                                                      context,
                                                                  builder:
                                                                      (context) {
                                                                    return GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        FocusScope.of(context)
                                                                            .unfocus();
                                                                        FocusManager
                                                                            .instance
                                                                            .primaryFocus
                                                                            ?.unfocus();
                                                                      },
                                                                      child:
                                                                          Padding(
                                                                        padding:
                                                                            MediaQuery.viewInsetsOf(context),
                                                                        child:
                                                                            Container(
                                                                          height:
                                                                              MediaQuery.sizeOf(context).height * 0.6,
                                                                          child:
                                                                              AddSchetWidget(),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                ).then((value) =>
                                                                    safeSetState(
                                                                        () {}));
                                                              },
                                                              text: FFLocalizations
                                                                      .of(context)
                                                                  .getText(
                                                                '04twn8uh' /* Добавить счет  */,
                                                              ),
                                                              options:
                                                                  FFButtonOptions(
                                                                width: MediaQuery.sizeOf(
                                                                            context)
                                                                        .width *
                                                                    0.8,
                                                                height: 40.0,
                                                                padding: EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        16.0,
                                                                        0.0,
                                                                        16.0,
                                                                        0.0),
                                                                iconPadding:
                                                                    EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            0.0,
                                                                            0.0,
                                                                            0.0),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primary,
                                                                textStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .interTight(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontStyle,
                                                                      ),
                                                                      color: Colors
                                                                          .white,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleSmall
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleSmall
                                                                          .fontStyle,
                                                                    ),
                                                                elevation: 0.0,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8.0),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        10.0,
                                                                        0.0,
                                                                        0.0),
                                                            child: StreamBuilder<
                                                                List<
                                                                    ShetaRecord>>(
                                                              stream:
                                                                  _shetaStreamForScope(),
                                                              builder: (context,
                                                                  snapshot) {
                                                                if (snapshot
                                                                    .hasError) {
                                                                  return _buildAccountsError(
                                                                    'Не удалось загрузить счета',
                                                                    snapshot
                                                                        .error,
                                                                  );
                                                                }
                                                                if (!snapshot
                                                                    .hasData) {
                                                                  return _buildLoader();
                                                                }
                                                                final items =
                                                                    snapshot.data ??
                                                                        [];
                                                                if (items
                                                                    .isEmpty) {
                                                                  return _buildAccountsEmptyState(
                                                                    'Счета еще не добавлены',
                                                                  );
                                                                }
                                                                final sums =
                                                                    _sumByTip(
                                                                        items);
                                                                final totalNoOwner =
                                                                    (sums['bank'] ??
                                                                            0) +
                                                                        (sums['nal'] ??
                                                                            0);

                                                                return Container(
                                                                  width: MediaQuery.sizeOf(
                                                                              context)
                                                                          .width *
                                                                      1.0,
                                                                  height: MediaQuery.sizeOf(
                                                                              context)
                                                                          .height *
                                                                      1.0,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryBackground,
                                                                  ),
                                                                  child:
                                                                      SingleChildScrollView(
                                                                    primary:
                                                                        false,
                                                                    child:
                                                                        Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      children: [
                                                                        Padding(
                                                                          padding:
                                                                              EdgeInsets.all(10.0),
                                                                          child:
                                                                              Card(
                                                                            clipBehavior:
                                                                                Clip.antiAliasWithSaveLayer,
                                                                            color:
                                                                                FlutterFlowTheme.of(context).secondaryBackground,
                                                                            elevation:
                                                                                10.0,
                                                                            shape:
                                                                                RoundedRectangleBorder(
                                                                              borderRadius: BorderRadius.circular(8.0),
                                                                            ),
                                                                            child:
                                                                                Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              children: [
                                                                                Expanded(
                                                                                  child: _buildAccountsTotalSummary(
                                                                                    context,
                                                                                    totalNoOwner,
                                                                                  ),
                                                                                ),
                                                                                Padding(
                                                                                  padding: EdgeInsets.all(5.0),
                                                                                  child: Column(
                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                                    children: [
                                                                                      Padding(
                                                                                        padding: EdgeInsets.all(5.0),
                                                                                        child: Icon(
                                                                                          Icons.attach_money,
                                                                                          color: FlutterFlowTheme.of(context).primary,
                                                                                          size: 42.0,
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        AuthUserStreamWidget(
                                                                          builder: (context) =>
                                                                              StreamBuilder<List<ShetaRecord>>(
                                                                            stream:
                                                                                _shetaStreamForScope(),
                                                                            builder:
                                                                                (context, snapshot) {
                                                                              if (snapshot.hasError) {
                                                                                return _buildAccountsError(
                                                                                  'Не удалось загрузить счета',
                                                                                  snapshot.error,
                                                                                );
                                                                              }
                                                                              if (!snapshot.hasData) {
                                                                                return _buildLoader();
                                                                              }
                                                                              List<ShetaRecord> mySchetaShetaRecordList = snapshot.data!;
                                                                              final scopedRecords = _applyScopeToRecords(mySchetaShetaRecordList);
                                                                              if (scopedRecords.isEmpty) {
                                                                                return _buildAccountsEmptyState(
                                                                                  'Счета еще не добавлены',
                                                                                );
                                                                              }

                                                                              final bankScheta = _sortSchetaActiveFirst(
                                                                                scopedRecords.where((e) => e.tip == 'bank').toList(),
                                                                              );
                                                                              final nalScheta = _sortSchetaActiveFirst(
                                                                                scopedRecords.where((e) => e.tip == 'nal').toList(),
                                                                              );
                                                                              final myScheta = _sortSchetaActiveFirst(
                                                                                scopedRecords.where((e) => e.tip == 'my').toList(),
                                                                              );

                                                                              final showBank = _isOwner || PermissionsHelper.has('scheta.blocks.bank');
                                                                              final showCash = _isOwner || PermissionsHelper.has('scheta.blocks.cash');
                                                                              final showOwner = _isOwner || PermissionsHelper.has('scheta.blocks.owner');
                                                                              final showAllCompanies = _isAllCompaniesScope();
                                                                              if (showAllCompanies) {
                                                                                return Column(
                                                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                                                  children: [
                                                                                    _buildCompanyBreakdown(
                                                                                      context,
                                                                                      scopedRecords,
                                                                                      layoutBlock: accountsBlock,
                                                                                    ),
                                                                                  ],
                                                                                );
                                                                              }
                                                                              return Column(
                                                                                mainAxisSize: MainAxisSize.max,
                                                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                                                children: [
                                                                                  if (showBank)
                                                                                    _buildMobileSchetSection(
                                                                                      title: 'Банковские счета',
                                                                                      icon: Icons.account_balance_outlined,
                                                                                      color: _sectionSurface(const Color(0xFFEFF6FF)),
                                                                                      items: bankScheta,
                                                                                      isOwner: _isOwner,
                                                                                      textColor: accountsBlock.textColor,
                                                                                      borderColor: accountsBlock.borderColor,
                                                                                      accentColor: accountsBlock.accentColor,
                                                                                    ),
                                                                                  if (showCash)
                                                                                    _buildMobileSchetSection(
                                                                                      title: 'Наличные',
                                                                                      icon: Icons.payments_outlined,
                                                                                      color: _sectionSurface(const Color(0xFFF0FDF4)),
                                                                                      items: nalScheta,
                                                                                      isOwner: _isOwner,
                                                                                      textColor: accountsBlock.textColor,
                                                                                      borderColor: accountsBlock.borderColor,
                                                                                      accentColor: accountsBlock.accentColor,
                                                                                    ),
                                                                                  if (showOwner)
                                                                                    _buildMobileSchetSection(
                                                                                      title: 'Средства владельца',
                                                                                      icon: Icons.card_travel,
                                                                                      color: _sectionSurface(const Color(0xFFFFF7ED)),
                                                                                      items: myScheta,
                                                                                      isOwner: _isOwner,
                                                                                      textColor: accountsBlock.textColor,
                                                                                      borderColor: accountsBlock.borderColor,
                                                                                      accentColor: accountsBlock.accentColor,
                                                                                    ),
                                                                                ],
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ].addToEnd(SizedBox(
                                                        height: 100.0)),
                                                  ),
                                                ),
                                              ),
                                            if (accountsBlock.visible &&
                                                responsiveVisibility(
                                                  context: context,
                                                  phone: false,
                                                  tablet: false,
                                                ))
                                              Container(
                                                width:
                                                    MediaQuery.sizeOf(context)
                                                            .width *
                                                        0.81,
                                                height:
                                                    MediaQuery.sizeOf(context)
                                                            .height *
                                                        1.0,
                                                decoration: BoxDecoration(
                                                  color: accountsBlock
                                                          .backgroundColor ??
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .secondaryBackground,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          18.0),
                                                  border: Border.all(
                                                    color: accountsBlock
                                                            .borderColor ??
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .alternate,
                                                  ),
                                                ),
                                                alignment: AlignmentDirectional(
                                                    0.0, -1.0),
                                                child: SingleChildScrollView(
                                                  primary: false,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      SizedBox.shrink(),
                                                      Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        10.0,
                                                                        0.0,
                                                                        0.0),
                                                            child: StreamBuilder<
                                                                List<
                                                                    ShetaRecord>>(
                                                              stream:
                                                                  _shetaStreamForScope(),
                                                              builder: (context,
                                                                  snapshot) {
                                                                if (snapshot
                                                                    .hasError) {
                                                                  return _buildAccountsError(
                                                                    'Не удалось загрузить счета',
                                                                    snapshot
                                                                        .error,
                                                                  );
                                                                }
                                                                if (!snapshot
                                                                    .hasData) {
                                                                  return _buildLoader();
                                                                }
                                                                final scopedRecords =
                                                                    _applyScopeToRecords(
                                                                  snapshot.data ??
                                                                      const <ShetaRecord>[],
                                                                );
                                                                if (scopedRecords
                                                                    .isEmpty) {
                                                                  return _buildAccountsEmptyState(
                                                                    'Счета еще не добавлены',
                                                                  );
                                                                }
                                                                return Container(
                                                                  width: MediaQuery.sizeOf(
                                                                              context)
                                                                          .width *
                                                                      0.82,
                                                                  height: MediaQuery.sizeOf(
                                                                              context)
                                                                          .height *
                                                                      1.0,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: accountsBlock
                                                                            .backgroundColor ??
                                                                        FlutterFlowTheme.of(context)
                                                                            .secondaryBackground,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            18.0),
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: accountsBlock
                                                                              .borderColor ??
                                                                          FlutterFlowTheme.of(context)
                                                                              .alternate,
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      SingleChildScrollView(
                                                                    primary:
                                                                        false,
                                                                    child:
                                                                        Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      children: [
                                                                        Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          children: [
                                                                            Expanded(
                                                                              child: Builder(
                                                                                builder: (context) {
                                                                                  final bankScheta = _sortSchetaActiveFirst(
                                                                                    scopedRecords.where((e) => e.tip == 'bank').toList(),
                                                                                  );
                                                                                  final nalScheta = _sortSchetaActiveFirst(
                                                                                    scopedRecords.where((e) => e.tip == 'nal').toList(),
                                                                                  );
                                                                                  final myScheta = _sortSchetaActiveFirst(
                                                                                    scopedRecords.where((e) => e.tip == 'my').toList(),
                                                                                  );

                                                                                  final showBank = _isOwner || PermissionsHelper.has('scheta.blocks.bank');
                                                                                  final showCash = _isOwner || PermissionsHelper.has('scheta.blocks.cash');
                                                                                  final showOwner = _isOwner || PermissionsHelper.has('scheta.blocks.owner');
                                                                                  final showAllCompanies = _isAllCompaniesScope();

                                                                                  if (showAllCompanies) {
                                                                                    return Column(
                                                                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                                                                      children: [
                                                                                        _buildCompanyBreakdown(
                                                                                          context,
                                                                                          scopedRecords,
                                                                                        ),
                                                                                      ],
                                                                                    );
                                                                                  }

                                                                                  Widget buildColumn(
                                                                                    String title,
                                                                                    List<ShetaRecord> items, {
                                                                                    Color? background,
                                                                                  }) {
                                                                                    final total = _accountsDisplayTotal(items, null);
                                                                                    final bgColor = background ?? FlutterFlowTheme.of(context).secondaryBackground;
                                                                                    final resolvedTextColor = _readableTextColor(
                                                                                      bgColor,
                                                                                      preferred: accountsBlock.textColor,
                                                                                    );
                                                                                    final resolvedSecondaryTextColor = _readableTextColor(
                                                                                      bgColor,
                                                                                      preferred: accountsBlock.textColor ?? FlutterFlowTheme.of(context).secondaryText,
                                                                                      secondary: true,
                                                                                    );
                                                                                    return Expanded(
                                                                                      child: ClipRRect(
                                                                                        borderRadius: BorderRadius.circular(12.0),
                                                                                        child: Container(
                                                                                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 6.0, 8.0, 10.0),
                                                                                          decoration: BoxDecoration(
                                                                                            color: bgColor,
                                                                                            borderRadius: BorderRadius.circular(12.0),
                                                                                            border: Border.all(
                                                                                              color: accountsBlock.borderColor ?? FlutterFlowTheme.of(context).alternate,
                                                                                            ),
                                                                                          ),
                                                                                          child: Column(
                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                                            children: [
                                                                                              _buildSchetSectionHeader(
                                                                                                context,
                                                                                                title,
                                                                                                total,
                                                                                                textColor: resolvedTextColor,
                                                                                              ),
                                                                                              SizedBox(height: 6.0),
                                                                                              if (items.isEmpty)
                                                                                                Padding(
                                                                                                  padding: EdgeInsetsDirectional.fromSTEB(10.0, 8.0, 10.0, 0.0),
                                                                                                  child: Text(
                                                                                                    'Нет счетов',
                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                          font: GoogleFonts.inter(),
                                                                                                          color: resolvedSecondaryTextColor,
                                                                                                          letterSpacing: 0.0,
                                                                                                        ),
                                                                                                  ),
                                                                                                )
                                                                                              else
                                                                                                ListView.builder(
                                                                                                  padding: EdgeInsets.zero,
                                                                                                  primary: false,
                                                                                                  shrinkWrap: true,
                                                                                                  itemCount: items.length,
                                                                                                  itemBuilder: (context, index) {
                                                                                                    final record = items[index];
                                                                                                    final canManage = _isOwner || PermissionsHelper.has('scheta.manage');
                                                                                                    return _buildSchetCard(
                                                                                                      context,
                                                                                                      record,
                                                                                                      canManage: canManage,
                                                                                                    );
                                                                                                  },
                                                                                                ),
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    );
                                                                                  }

                                                                                  final columns = <Widget>[];
                                                                                  if (showBank) {
                                                                                    columns.add(buildColumn('Банковские счета', bankScheta, background: _sectionSurface(const Color(0xFFEFF6FF))));
                                                                                  }
                                                                                  if (showCash) {
                                                                                    if (columns.isNotEmpty) {
                                                                                      columns.add(SizedBox(width: 12.0));
                                                                                    }
                                                                                    columns.add(buildColumn('Наличные', nalScheta, background: _sectionSurface(const Color(0xFFF0FDF4))));
                                                                                  }
                                                                                  if (showOwner) {
                                                                                    if (columns.isNotEmpty) {
                                                                                      columns.add(SizedBox(width: 12.0));
                                                                                    }
                                                                                    columns.add(buildColumn(
                                                                                      'Средства владельца',
                                                                                      myScheta,
                                                                                      background: _sectionSurface(const Color(0xFFFFF7ED)),
                                                                                    ));
                                                                                  }
                                                                                  if (columns.isEmpty) {
                                                                                    return Center(
                                                                                      child: Text(
                                                                                        'Нет доступных разделов счетов',
                                                                                        style: FlutterFlowTheme.of(context).bodyMedium,
                                                                                      ),
                                                                                    );
                                                                                  }
                                                                                  return Row(
                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: columns,
                                                                                  );
                                                                                },
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ].addToEnd(SizedBox(width: 100.0)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCardMovementSummary {
  const _AccountCardMovementSummary({
    required this.income,
    required this.expense,
    required this.incomeCount,
    required this.expenseCount,
    required this.openingBalance,
    required this.closingBalance,
  });

  final double income;
  final double expense;
  final int incomeCount;
  final int expenseCount;
  final double openingBalance;
  final double closingBalance;
}
