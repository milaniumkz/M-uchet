// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/custom_code/widgets/editing_helper.dart';
import '/custom_code/widgets/personal_finance_support.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/app_money_format.dart';
import '/utils/business_event_support.dart';
import '/utils/country_profile.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/money_flow_type.dart';
import '/utils/transaction_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String _legacyPersonalInvestmentSource = 'personal_investment';
const String _companyExpenseSource = 'personal_company_expense';

bool _looksLikeOwnerInvestmentLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return normalized.contains('вложен') ||
      normalized.contains('ввод остат') ||
      normalized.contains('фин.пом') ||
      normalized.contains('фин пом') ||
      normalized.contains('финансовая помощь') ||
      normalized.contains('учредител');
}

bool _looksLikeOwnerInvestmentExpense(Map<String, dynamic> item) {
  final source = (item['source'] ?? '').toString();
  if (source == _legacyPersonalInvestmentSource) {
    return true;
  }
  final candidates = <String>[
    (item['category'] ?? '').toString(),
    (item['category_title'] ?? '').toString(),
    (item['subcategory1_title'] ?? '').toString(),
    (item['subcategory2_title'] ?? '').toString(),
    (item['source_label'] ?? '').toString(),
    (item['description'] ?? '').toString(),
  ];
  return candidates.any(_looksLikeOwnerInvestmentLabel);
}

Future<void> _deleteBusinessEventsByTransaction(
  FirebaseFirestore firestore,
  String transactionId,
) async {
  if (transactionId.trim().isEmpty) return;
  final snap = await firestore
      .collection('business_events')
      .where('transaction_id', isEqualTo: transactionId.trim())
      .get();
  if (snap.docs.isEmpty) return;
  final batch = firestore.batch();
  for (final doc in snap.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}

class MoneyCompanyExpensesWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const MoneyCompanyExpensesWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<MoneyCompanyExpensesWidget> createState() =>
      _MoneyCompanyExpensesWidgetState();
}

class _MoneyCompanyExpensesWidgetState extends State<MoneyCompanyExpensesWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _categories = [];
  String _currencyCode = 'KZT';

  Map<String, dynamic> _docMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool allowRepair = true}) async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _expenses = [];
          _wallets = [];
          _categories = [];
        });
        return;
      }
      final companyId = PersonalFinanceSupport.effectiveCompanyId(user);

      final expensesSnap = await _firestore
          .collection('company_expenses')
          .where('idCompany', isEqualTo: companyId)
          .limit(300)
          .get(const GetOptions(source: Source.serverAndCache));
      final walletsSnap = await _firestore
          .collection(PersonalFinanceSupport.walletsCollection)
          .where('user_id', isEqualTo: user.uid)
          .where('idCompany', isEqualTo: companyId)
          .get(const GetOptions(source: Source.serverAndCache));
      final categoriesSnap = await _firestore
          .collection(PersonalFinanceSupport.categoriesCollection)
          .where('user_id', isEqualTo: user.uid)
          .where('idCompany', isEqualTo: companyId)
          .get(const GetOptions(source: Source.serverAndCache));

      final fallbackWalletsSnap = walletsSnap.docs.isEmpty
          ? await _firestore
              .collection(PersonalFinanceSupport.walletsCollection)
              .where('user_id', isEqualTo: user.uid)
              .get(const GetOptions(source: Source.serverAndCache))
          : walletsSnap;
      final fallbackCategoriesSnap = categoriesSnap.docs.isEmpty
          ? await _firestore
              .collection(PersonalFinanceSupport.categoriesCollection)
              .where('user_id', isEqualTo: user.uid)
              .get(const GetOptions(source: Source.serverAndCache))
          : categoriesSnap;
      final profileSnap =
          await _firestore.collection('company_profile').doc(companyId).get();

      final expenses = expensesSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
          .where((item) =>
              ((item['source'] ?? _legacyPersonalInvestmentSource).toString() ==
                  _legacyPersonalInvestmentSource) ||
              ((item['source'] ?? '').toString() == _companyExpenseSource))
          .toList();
      expenses.sort((a, b) {
        final bDate = PersonalFinanceSupport.parseDate(b['date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final aDate = PersonalFinanceSupport.parseDate(a['date']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (allowRepair &&
          await _repairLegacyOwnerInvestmentRecords(companyId, expenses)) {
        await _loadData(allowRepair: false);
        return;
      }

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _expenses = expenses;
        _wallets = fallbackWalletsSnap.docs
            .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
            .toList();
        _categories = fallbackCategoriesSnap.docs
            .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading company expenses: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<bool> _repairLegacyOwnerInvestmentRecords(
    String companyId,
    List<Map<String, dynamic>> expenses,
  ) async {
    var changed = false;
    for (final item in expenses) {
      if (!_looksLikeOwnerInvestmentExpense(item)) continue;

      final expenseId = (item['id'] ?? '').toString();
      final transactionId = (item['tranzaction_id'] ?? '').toString();
      final personalEntryId = (item['personal_entry_id'] ?? '').toString();
      final categoryTitle =
          (item['category_title'] ?? item['category'] ?? 'Вложение в компанию')
              .toString()
              .trim();
      final description = (item['description'] ?? '').toString().trim().isEmpty
          ? 'Ввод остатков владельца'
          : (item['description'] ?? '').toString().trim();

      if (expenseId.isNotEmpty) {
        final companyExpensePatch = <String, dynamic>{};
        final source = (item['source'] ?? '').toString();
        final flow = (item['money_flow_type'] ?? item['moneyFlowType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (source != _legacyPersonalInvestmentSource) {
          companyExpensePatch['source'] = _legacyPersonalInvestmentSource;
        }
        if (flow != MoneyFlowType.financing.storageValue) {
          companyExpensePatch['money_flow_type'] =
              MoneyFlowType.financing.storageValue;
          companyExpensePatch['moneyFlowType'] =
              MoneyFlowType.financing.storageValue;
        }
        if (companyExpensePatch.isNotEmpty) {
          await _firestore
              .collection('company_expenses')
              .doc(expenseId)
              .update(companyExpensePatch);
          changed = true;
        }
      }

      if (personalEntryId.isNotEmpty) {
        final personalRef = _firestore
            .collection(PersonalFinanceSupport.entriesCollection)
            .doc(personalEntryId);
        final personalSnap = await personalRef.get();
        if (personalSnap.exists) {
          final data = _docMap(personalSnap.data());
          final personalPatch = <String, dynamic>{};
          final source = (data['source'] ?? '').toString();
          final sourceLabel = (data['source_label'] ?? '').toString();
          final flow = (data['money_flow_type'] ?? data['moneyFlowType'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (source != _legacyPersonalInvestmentSource) {
            personalPatch['source'] = _legacyPersonalInvestmentSource;
          }
          if (sourceLabel != 'Ввод остатков') {
            personalPatch['source_label'] = 'Ввод остатков';
          }
          if (flow != MoneyFlowType.financing.storageValue) {
            personalPatch['money_flow_type'] =
                MoneyFlowType.financing.storageValue;
            personalPatch['moneyFlowType'] =
                MoneyFlowType.financing.storageValue;
          }
          if ((data['description'] ?? '').toString().trim().isEmpty ||
              (data['description'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase()
                  .contains('расход на компанию')) {
            personalPatch['description'] = 'Ввод остатков';
          }
          if (personalPatch.isNotEmpty) {
            await personalRef.update(personalPatch);
            changed = true;
          }
        }
      }

      if (transactionId.isNotEmpty) {
        final txRef = _firestore.collection('tranzaction').doc(transactionId);
        final txSnap = await txRef.get();
        if (txSnap.exists) {
          final txData = _docMap(txSnap.data());
          final txPatch = <String, dynamic>{};
          final type = (txData['type'] ?? '').toString().trim().toLowerCase();
          final flow =
              (txData['money_flow_type'] ?? txData['moneyFlowType'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
          if (type != 'income') {
            txPatch['type'] = 'income';
          }
          if (flow != MoneyFlowType.financing.storageValue) {
            txPatch['money_flow_type'] = MoneyFlowType.financing.storageValue;
            txPatch['moneyFlowType'] = MoneyFlowType.financing.storageValue;
          }
          if ((txData['kat'] ?? '').toString().trim() != categoryTitle) {
            txPatch['kat'] = categoryTitle;
          }
          if ((txData['counterparty'] ?? '').toString().trim() !=
              'Личные средства владельца') {
            txPatch['counterparty'] = 'Личные средства владельца';
          }
          if ((txData['text'] ?? '').toString().trim().isEmpty ||
              (txData['text'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase()
                  .contains('расход на компанию')) {
            txPatch['text'] = description;
          }
          if (txPatch.isNotEmpty) {
            await txRef.update(txPatch);
            txData.addAll(txPatch);
            changed = true;
          }
          if (txPatch.isNotEmpty) {
            await createEntriesForTransaction(
              firestore: _firestore,
              transactionRef: txRef,
              transactionData: txData,
              overwriteExisting: true,
            );
          }
        }

        final eventSnap = await _firestore
            .collection('business_events')
            .where('transaction_id', isEqualTo: transactionId)
            .limit(1)
            .get();
        if (eventSnap.docs.isNotEmpty) {
          await _deleteBusinessEventsByTransaction(_firestore, transactionId);
          changed = true;
        }
      }
    }

    if (!changed) return false;

    await TransactionSync.recomputeAllForCompany(companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('company_expenses', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('accounting_entries', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('tranzaction', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('sheta', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('ushet', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('business_events', companyId);
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      PersonalFinanceSupport.entriesCollection,
      companyId,
    );
    return true;
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  double get _total => _expenses.fold<double>(
      0, (total, item) => total + PersonalFinanceSupport.toNum(item['amount']));

  void _openFinancingJournal() {
    context.pushNamedAuth(
      'tranzactionJournal',
      mounted,
      queryParameters: const {'flow': 'financing'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        scheduleReloadOnCompanyChange(_loadData);
        if (!PermissionsHelper.has('money.company_expenses')) {
          return PermissionsHelper.noAccess();
        }
        return ResponsiveFrame(
          backgroundColor: const Color(0xFFF7F8FA),
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
                            .warning
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.trending_down,
                          color: Color(0xFFF97316)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Расходы на компанию с личных',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Оплата расходов компании из личного кошелька с выбором категории',
                            style: TextStyle(
                                fontSize: 13,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showExpenseDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Оплатить'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _statCard(
                      title: 'Вложено',
                      value: _formatMoney(_total),
                      amount: _total,
                      icon: Icons.trending_down,
                      iconBg: FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.14),
                      iconColor: FlutterFlowTheme.of(context).warning,
                      onTap: _openFinancingJournal,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      title: 'Операций',
                      value: _expenses.length.toString(),
                      icon: Icons.receipt_long,
                      iconBg: FlutterFlowTheme.of(context).accent1,
                      iconColor: FlutterFlowTheme.of(context).primary,
                      onTap: _openFinancingJournal,
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
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Личные расходы на компанию',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            TextButton.icon(
                              onPressed: _openFinancingJournal,
                              icon: const Icon(Icons.menu_book_outlined,
                                  size: 16),
                              label: const Text('Журнал financing'),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                _HeaderCell('Дата', flex: 2),
                                _HeaderCell('Кошелек', flex: 3),
                                _HeaderCell('Категория', flex: 4),
                                _HeaderCell('Описание', flex: 4),
                                _HeaderCell('Сумма', flex: 2),
                                _HeaderCell('', flex: 2),
                              ],
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _expenses.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Вложений пока нет',
                                        style: TextStyle(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText),
                                      ),
                                    )
                                  : ListView(
                                      children: _expenses.map(_row).toList()),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    num? amount,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final content = Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        color: FlutterFlowTheme.of(context).secondaryText)),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: amountTextColor(
                      context,
                      amount,
                      positiveColor: FlutterFlowTheme.of(context).primaryText,
                    ),
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
    return Expanded(
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }

  Widget _row(Map<String, dynamic> item) {
    final date = PersonalFinanceSupport.parseDate(item['date']);
    final wallet = (item['wallet_name'] ?? '').toString();
    final desc = (item['description'] ?? '').toString();
    final amount = PersonalFinanceSupport.toNum(item['amount']);
    final category = [
      (item['category_title'] ?? '').toString().trim(),
      (item['subcategory1_title'] ?? '').toString().trim(),
      (item['subcategory2_title'] ?? '').toString().trim(),
    ].where((element) => element.isNotEmpty).join(' / ');
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
          _Cell(date == null ? '-' : PersonalFinanceSupport.formatDate(date),
              flex: 2),
          _Cell(wallet.isEmpty ? '-' : wallet, flex: 3, bold: true),
          _Cell(category.isEmpty ? '-' : category, flex: 4),
          _Cell(desc.isEmpty ? '-' : desc, flex: 4),
          _Cell(_formatMoney(amount), flex: 2, amount: amount),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (EditingHelper.canEditExisting())
                  IconButton(
                    onPressed: () => _showExpenseDialog(existing: item),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                if (EditingHelper.canEditExisting())
                  IconButton(
                    onPressed: () => _deleteExpense(item),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseDialog({Map<String, dynamic>? existing}) {
    if (existing != null && !EditingHelper.guardEdit(context)) return;
    if (_wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте личный кошелек.'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _InvestmentDialog(
        existing: existing,
        wallets: _wallets,
        categories: _categories,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _deleteExpense(Map<String, dynamic> item) async {
    if (!EditingHelper.guardEdit(context)) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final companyId = PersonalFinanceSupport.effectiveCompanyId(user);
    final walletId = (item['wallet_id'] ?? '').toString();
    final amount = PersonalFinanceSupport.toNum(item['amount']);
    final personalEntryId = (item['personal_entry_id'] ?? '').toString();
    final tranzactionId = (item['tranzaction_id'] ?? '').toString();
    final personalEntryManaged = item['personal_entry_managed'] != false;

    await _firestore.collection('company_expenses').doc(item['id']).delete();
    if (personalEntryManaged && personalEntryId.isNotEmpty) {
      await _firestore
          .collection(PersonalFinanceSupport.entriesCollection)
          .doc(personalEntryId)
          .delete();
    }
    if (tranzactionId.isNotEmpty) {
      await deleteEntriesByTransaction(
        firestore: _firestore,
        transactionId: tranzactionId,
      );
      await _deleteBusinessEventsByTransaction(_firestore, tranzactionId);
      await _firestore.collection('tranzaction').doc(tranzactionId).delete();
    }
    if (personalEntryManaged) {
      await PersonalFinanceSupport.applyWalletDelta(
          _firestore, walletId, amount);
    }
    await TransactionSync.recomputeAllForCompany(companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('company_expenses', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('accounting_entries', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('tranzaction', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('sheta', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('ushet', companyId);
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      PersonalFinanceSupport.entriesCollection,
      companyId,
    );
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      PersonalFinanceSupport.walletsCollection,
      companyId,
    );
    await _loadData();
  }
}

class _InvestmentDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> wallets;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onSaved;

  const _InvestmentDialog({
    this.existing,
    required this.wallets,
    required this.categories,
    required this.onSaved,
  });

  @override
  State<_InvestmentDialog> createState() => _InvestmentDialogState();
}

class _InvestmentDialogState extends State<_InvestmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _amount = TextEditingController(text: '0');
  final _category = TextEditingController(text: 'Вложение в компанию');
  final _desc = TextEditingController();
  LedgerScope _ledgerScope = LedgerScope.accounting;
  String? _walletId;
  String? _categoryId;
  String? _sub1Id;
  String? _sub2Id;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _date.text = (ex['date'] ?? '').toString();
      _amount.text = PersonalFinanceSupport.toNum(ex['amount']).toString();
      _category.text = (ex['category'] ?? 'Вложение в компанию').toString();
      _desc.text = (ex['description'] ?? '').toString();
      _ledgerScope = ledgerScopeFromLegacyValue(
        normalizeLegacyTypeUchet(
          (ex['typeUchet'] ?? ex['ledger_scope'] ?? 'Bu').toString(),
        ),
      );
      _walletId = (ex['wallet_id'] ?? '').toString();
      _categoryId = (ex['category_id'] ?? '').toString();
      _sub1Id = (ex['subcategory1_id'] ?? '').toString();
      _sub2Id = (ex['subcategory2_id'] ?? '').toString();
    } else {
      _date.text = PersonalFinanceSupport.formatDate(DateTime.now());
      if (widget.wallets.isNotEmpty) {
        _walletId = (widget.wallets.first['id'] ?? '').toString();
      }
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    _category.dispose();
    _desc.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _children(String? parentId) => widget.categories
      .where((item) => (item['parent_id'] ?? '').toString() == (parentId ?? ''))
      .toList();

  Map<String, dynamic>? _findCategory(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in widget.categories) {
      if ((item['id'] ?? '').toString() == id) return item;
    }
    return null;
  }

  DateTime? _parseDate(String value) => PersonalFinanceSupport.parseDate(value);

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findReusablePersonalEntry({
    required String userId,
    required String companyId,
    required String walletId,
    required DateTime dateValue,
    required double amount,
  }) async {
    final normalizedDate = PersonalFinanceSupport.formatDate(dateValue);
    final snap = await FirebaseFirestore.instance
        .collection(PersonalFinanceSupport.entriesCollection)
        .where('user_id', isEqualTo: userId)
        .where('idCompany', isEqualTo: companyId)
        .where('wallet_id', isEqualTo: walletId)
        .where('entry_type', isEqualTo: 'expense')
        .limit(50)
        .get(const GetOptions(source: Source.serverAndCache));

    for (final doc in snap.docs) {
      final data = doc.data();
      final docDate = PersonalFinanceSupport.formatDate(
        PersonalFinanceSupport.parseDate(
              data['operation_date'] ?? data['date'],
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
      final docAmount = PersonalFinanceSupport.toNum(data['amount']);
      if (docDate == normalizedDate && (docAmount - amount).abs() < 0.0001) {
        return doc;
      }
    }
    return null;
  }

  double _parseAmount(String value) {
    return double.tryParse(
          value.trim().replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  bool _isOwnerInvestment({
    required String categoryTitle,
    Map<String, dynamic>? categoryDoc,
    Map<String, dynamic>? sub1Doc,
    Map<String, dynamic>? sub2Doc,
  }) {
    final existingSource = (widget.existing?['source'] ?? '').toString();
    if (existingSource == _legacyPersonalInvestmentSource) {
      return true;
    }
    final candidates = <String>[
      _category.text,
      categoryTitle,
      (categoryDoc?['title'] ?? '').toString(),
      (sub1Doc?['title'] ?? '').toString(),
      (sub2Doc?['title'] ?? '').toString(),
      (widget.existing?['category'] ?? '').toString(),
      (widget.existing?['category_title'] ?? '').toString(),
      _desc.text,
    ];
    return candidates.any(_looksLikeOwnerInvestmentLabel);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_walletId == null || _walletId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите кошелек.')),
      );
      return;
    }
    if (widget.existing != null && !EditingHelper.guardEdit(context)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final companyId = PersonalFinanceSupport.effectiveCompanyId(user);
      final wallet = widget.wallets.firstWhere(
        (item) => (item['id'] ?? '').toString() == _walletId,
        orElse: () => const <String, dynamic>{},
      );
      final categoryDoc = _findCategory(_categoryId);
      final sub1Doc = _findCategory(_sub1Id);
      final sub2Doc = _findCategory(_sub2Id);
      final amount = _parseAmount(_amount.text);
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сумма должна быть больше 0.')),
        );
        return;
      }
      final dateValue = _parseDate(_date.text.trim()) ?? DateTime.now();
      final account = await TransactionSync.selectAccount(companyId, tip: 'my');
      if (account.reference == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось подобрать счет для проведения операции.'),
          ),
        );
        return;
      }
      final legacyTypeUchet = _ledgerScope.legacyTypeUchet;
      final categoryTitle =
          (categoryDoc?['title'] ?? _category.text.trim()).toString();
      final isOwnerInvestment = _isOwnerInvestment(
        categoryTitle: categoryTitle,
        categoryDoc: categoryDoc,
        sub1Doc: sub1Doc,
        sub2Doc: sub2Doc,
      );
      final flowType =
          isOwnerInvestment ? MoneyFlowType.financing : MoneyFlowType.operating;
      final transactionType = isOwnerInvestment ? 'income' : 'decome';
      final businessDescription = _desc.text.trim().isEmpty
          ? isOwnerInvestment
              ? 'Ввод остатков владельца'
              : 'Расход на компанию с личных средств'
          : _desc.text.trim();
      final personalDescription = _desc.text.trim().isEmpty
          ? isOwnerInvestment
              ? 'Ввод остатков'
              : 'Расход на компанию'
          : _desc.text.trim();
      final operationSource = isOwnerInvestment
          ? _legacyPersonalInvestmentSource
          : _companyExpenseSource;
      final txData = {
        ...createTranzactionRecordData(
          type: transactionType,
          typeUchet: legacyTypeUchet,
          ledgerScope: _ledgerScope.storageValue,
          moneyFlowType: flowType.storageValue,
          kat: categoryTitle,
          text: businessDescription,
          summa: amount,
          nds: false,
          summaNds: 0,
          idCompany: companyId,
          schetTitle: account.title,
          date: dateValue,
          status: 'Проведена',
          counterparty: 'Личные средства владельца',
        ),
        ...mapToFirestore(
          transactionMoneyFieldsForAccountData(
            amountOriginal: amount,
            accountData: account.snapshotData,
            exchangeRateDate: dateValue,
          ),
        ),
        'schet_id': account.reference!.id,
      };

      final companyExpenseData = {
        'date': PersonalFinanceSupport.formatDate(dateValue),
        'category': categoryTitle,
        'category_id': _categoryId ?? '',
        'category_title': categoryTitle,
        'subcategory1_id': _sub1Id ?? '',
        'subcategory1_title': (sub1Doc?['title'] ?? '').toString(),
        'subcategory2_id': _sub2Id ?? '',
        'subcategory2_title': (sub2Doc?['title'] ?? '').toString(),
        'wallet_id': _walletId,
        'wallet_name': (wallet['name'] ?? '').toString(),
        'amount': amount,
        'description': _desc.text.trim(),
        'typeUchet': legacyTypeUchet,
        ...moneyFlowTypeFields(flowType),
        ...ledgerScopeFields(
          ledgerScope: _ledgerScope,
          legacyTypeUchet: legacyTypeUchet,
        ),
        'source': operationSource,
        'user_id': user.uid,
        'idCompany': companyId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      final personalEntryData = {
        'date': PersonalFinanceSupport.formatDate(dateValue),
        'operation_date': Timestamp.fromDate(dateValue),
        'entry_type': 'expense',
        'wallet_id': _walletId,
        'wallet_name': (wallet['name'] ?? '').toString(),
        'category_id': _categoryId ?? '',
        'category_title': (categoryDoc?['title'] ?? '').toString(),
        'subcategory1_id': _sub1Id ?? '',
        'subcategory1_title': (sub1Doc?['title'] ?? '').toString(),
        'subcategory2_id': _sub2Id ?? '',
        'subcategory2_title': (sub2Doc?['title'] ?? '').toString(),
        'amount': amount,
        'description': personalDescription,
        'scope': 'personal',
        'source': operationSource,
        'source_label':
            isOwnerInvestment ? 'Ввод остатков' : 'Расход на компанию',
        'money_flow_type': flowType.storageValue,
        'moneyFlowType': flowType.storageValue,
        'user_id': user.uid,
        'idCompany': companyId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      final oldWalletId = (widget.existing?['wallet_id'] ?? '').toString();
      final oldAmount =
          PersonalFinanceSupport.toNum(widget.existing?['amount']);
      final existingTxId =
          (widget.existing?['tranzaction_id'] ?? '').toString();
      final existingPersonalEntryId =
          (widget.existing?['personal_entry_id'] ?? '').toString();
      final oldManagedPersonalEntry =
          widget.existing?['personal_entry_managed'] != false;

      String transactionId = existingTxId;
      if (transactionId.isEmpty) {
        final txRef =
            FirebaseFirestore.instance.collection('tranzaction').doc();
        await txRef.set(txData);
        await createEntriesForTransaction(
          firestore: FirebaseFirestore.instance,
          transactionRef: txRef,
          transactionData: txData,
        );
        transactionId = txRef.id;
      } else {
        final txRef = FirebaseFirestore.instance
            .collection('tranzaction')
            .doc(transactionId);
        await txRef.update(txData);
        await createEntriesForTransaction(
          firestore: FirebaseFirestore.instance,
          transactionRef: txRef,
          transactionData: txData,
          overwriteExisting: true,
        );
      }

      String personalEntryId = existingPersonalEntryId;
      bool personalEntryManaged = oldManagedPersonalEntry;
      bool applyWalletDelta = oldManagedPersonalEntry;

      if (widget.existing == null) {
        final reusableEntry = await _findReusablePersonalEntry(
          userId: user.uid,
          companyId: companyId,
          walletId: _walletId!,
          dateValue: dateValue,
          amount: amount,
        );
        if (reusableEntry != null) {
          personalEntryId = reusableEntry.id;
          personalEntryManaged = false;
          applyWalletDelta = false;
        } else {
          personalEntryData['created_at'] = FieldValue.serverTimestamp();
          final entryRef = await FirebaseFirestore.instance
              .collection(PersonalFinanceSupport.entriesCollection)
              .add(personalEntryData);
          personalEntryId = entryRef.id;
          personalEntryManaged = true;
          applyWalletDelta = true;
        }
      } else if (personalEntryId.isNotEmpty && oldManagedPersonalEntry) {
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.entriesCollection)
            .doc(personalEntryId)
            .update(personalEntryData);
        personalEntryManaged = true;
        applyWalletDelta = true;
      } else {
        personalEntryManaged = false;
        applyWalletDelta = false;
      }

      await _deleteBusinessEventsByTransaction(
        FirebaseFirestore.instance,
        transactionId,
      );

      final payload = {
        ...companyExpenseData,
        'tranzaction_id': transactionId,
        'personal_entry_id': personalEntryId,
        'personal_entry_managed': personalEntryManaged,
      };

      if (widget.existing == null) {
        payload['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('company_expenses')
            .add(payload);
        if (applyWalletDelta) {
          await PersonalFinanceSupport.applyWalletDelta(
            FirebaseFirestore.instance,
            _walletId!,
            -amount,
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('company_expenses')
            .doc(widget.existing!['id'])
            .update(payload);
        if (oldManagedPersonalEntry) {
          await PersonalFinanceSupport.applyWalletDelta(
            FirebaseFirestore.instance,
            oldWalletId,
            oldAmount,
          );
        }
        if (applyWalletDelta) {
          await PersonalFinanceSupport.applyWalletDelta(
            FirebaseFirestore.instance,
            _walletId!,
            -amount,
          );
        }
      }

      if (!isOwnerInvestment) {
        await FirebaseFirestore.instance.collection('business_events').add(
              buildBusinessEventPayload(
                companyId: companyId,
                type: BusinessEventType.expenseRecorded,
                ledgerScope: _ledgerScope,
                aggregateId:
                    (widget.existing?['id'] ?? transactionId).toString(),
                transactionId: transactionId,
                categoryName:
                    (categoryDoc?['title'] ?? _category.text).toString(),
                cost: amount,
                paymentMethod: 'wallet',
                notes: _desc.text.trim(),
              ),
            );
      }

      await TransactionSync.recomputeAllForCompany(companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('company_expenses', companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('accounting_entries', companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('tranzaction', companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('sheta', companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('ushet', companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('business_events', companyId);
      FirestoreQueryCache.instance.invalidateCompanyCollection(
        PersonalFinanceSupport.entriesCollection,
        companyId,
      );
      FirestoreQueryCache.instance.invalidateCompanyCollection(
        PersonalFinanceSupport.walletsCollection,
        companyId,
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Операция не проведена: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final root = _children('');
    final sub1 = _children(_categoryId);
    final sub2 = _children(_sub1Id);
    final media = MediaQuery.sizeOf(context);
    final dialogWidth = media.width > 520 ? 460.0 : media.width - 32.0;
    final maxContentHeight = media.height * 0.58;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actionsAlignment: MainAxisAlignment.end,
      title: Text(isEdit ? 'Редактировать расход' : 'Оплатить расход компании'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: maxContentHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _walletId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Кошелек'),
                    items: widget.wallets
                        .map((item) => DropdownMenuItem<String>(
                              value: (item['id'] ?? '').toString(),
                              child: Text(
                                (item['name'] ?? 'Кошелек').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _walletId = value),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _date,
                    decoration: const InputDecoration(labelText: 'Дата'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Основная категория'),
                    items: root
                        .map((item) => DropdownMenuItem<String>(
                              value: (item['id'] ?? '').toString(),
                              child: Text(
                                (item['title'] ?? 'Категория').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _categoryId = value;
                        _sub1Id = null;
                        _sub2Id = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _sub1Id,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Подкатегория'),
                    items: sub1
                        .map((item) => DropdownMenuItem<String>(
                              value: (item['id'] ?? '').toString(),
                              child: Text(
                                (item['title'] ?? 'Подкатегория').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _sub1Id = value;
                        _sub2Id = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _sub2Id,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Подкатегория 2'),
                    items: sub2
                        .map((item) => DropdownMenuItem<String>(
                              value: (item['id'] ?? '').toString(),
                              child: Text(
                                (item['title'] ?? 'Подкатегория 2').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _sub2Id = value),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _category,
                    decoration:
                        const InputDecoration(labelText: 'Статья компании'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Введите статью' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Сумма'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Введите сумму'
                        : ((double.tryParse(v.replaceAll(',', '.')) ?? 0) <= 0
                            ? 'Сумма должна быть больше 0'
                            : null),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<LedgerScope>(
                    initialValue: _ledgerScope,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Тип учета'),
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
                      setState(() => _ledgerScope = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _desc,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: Text(isEdit ? 'Сохранить' : 'Оплатить'),
        ),
      ],
    );
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
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: FlutterFlowTheme.of(context).secondaryText)),
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
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
    );
  }
}
