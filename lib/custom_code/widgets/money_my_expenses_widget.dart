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
import '/custom_code/widgets/company_reload_mixin.dart';
import '/custom_code/widgets/editing_helper.dart';
import '/custom_code/widgets/personal_finance_support.dart';
import '/utils/country_profile.dart';
import '/utils/personal_money_entry_filter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoneyMyExpensesWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const MoneyMyExpensesWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<MoneyMyExpensesWidget> createState() => _MoneyMyExpensesWidgetState();
}

class _MoneyMyExpensesWidgetState extends State<MoneyMyExpensesWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _expenses = [];
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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _wallets = [];
          _categories = [];
          _expenses = [];
        });
        return;
      }
      final companyId = PersonalFinanceSupport.effectiveCompanyId(user);
      final walletsSnap = await _firestore
          .collection(PersonalFinanceSupport.walletsCollection)
          .where('user_id', isEqualTo: user.uid)
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final categoriesSnap = await _firestore
          .collection(PersonalFinanceSupport.categoriesCollection)
          .where('user_id', isEqualTo: user.uid)
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final entriesSnap = await _firestore
          .collection(PersonalFinanceSupport.entriesCollection)
          .where('user_id', isEqualTo: user.uid)
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final profileSnap =
          await _firestore.collection('company_profile').doc(companyId).get();

      final wallets = walletsSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
          .toList();
      final categories = categoriesSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
          .toList();
      final expenses = entriesSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
          .where(isPersonalMoneyEntry)
          .where((item) => (item['entry_type'] ?? 'expense') != 'income')
          .toList();
      expenses.sort((a, b) {
        final bDate = PersonalFinanceSupport.parseDate(
              b['operation_date'] ?? b['date'],
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final aDate = PersonalFinanceSupport.parseDate(
              a['operation_date'] ?? a['date'],
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _wallets = wallets;
        _categories = categories;
        _expenses = expenses;
      });
    } catch (e) {
      print('Error loading personal expenses: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  double get _total => _expenses.fold<double>(
      0, (sum, item) => sum + PersonalFinanceSupport.toNum(item['amount']));

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        scheduleReloadOnCompanyChange(_loadData);
        if (!PermissionsHelper.has('money.my_expenses')) {
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
                            'Личные расходы',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Расходы из личных кошельков с категориями и подкатегориями',
                            style: TextStyle(
                                fontSize: 13,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          _wallets.isEmpty ? null : () => _showExpenseDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Добавить расход'),
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
                      title: 'Расходы',
                      value: _formatMoney(_total),
                      icon: Icons.trending_down,
                      iconBg: FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.14),
                      iconColor: FlutterFlowTheme.of(context).warning,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      title: 'Операций',
                      value: _expenses.length.toString(),
                      icon: Icons.receipt_long,
                      iconBg: FlutterFlowTheme.of(context).accent1,
                      iconColor: FlutterFlowTheme.of(context).primary,
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
                              'Последние расходы',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: const [
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
                                        'Расходов не найдено',
                                        style: TextStyle(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText),
                                      ),
                                    )
                                  : ListView(
                                      children: _expenses.map(_row).toList(),
                                    ),
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
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
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
      ),
    );
  }

  Widget _row(Map<String, dynamic> item) {
    final date = PersonalFinanceSupport.parseDate(
        item['operation_date'] ?? item['date']);
    final wallet = (item['wallet_name'] ?? '').toString();
    final category = PersonalFinanceSupport.buildCategoryPath(item);
    final desc = (item['description'] ?? '').toString();
    final amount = PersonalFinanceSupport.toNum(item['amount']);
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
    showDialog(
      context: context,
      builder: (context) => _ExpenseDialog(
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
    await _firestore
        .collection(PersonalFinanceSupport.entriesCollection)
        .doc(item['id'])
        .delete();
    await PersonalFinanceSupport.applyWalletDelta(_firestore, walletId, amount);
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

class _ExpenseDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> wallets;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onSaved;

  const _ExpenseDialog({
    this.existing,
    required this.wallets,
    required this.categories,
    required this.onSaved,
  });

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _amount = TextEditingController(text: '0');
  final _desc = TextEditingController();
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
      _desc.text = (ex['description'] ?? '').toString();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_walletId == null || _walletId!.isEmpty) return;
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
      final category = _findCategory(_categoryId);
      final sub1 = _findCategory(_sub1Id);
      final sub2 = _findCategory(_sub2Id);
      final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
      final dateValue =
          PersonalFinanceSupport.parseDate(_date.text.trim()) ?? DateTime.now();
      final data = {
        'date': PersonalFinanceSupport.formatDate(dateValue),
        'operation_date': Timestamp.fromDate(dateValue),
        'entry_type': 'expense',
        'wallet_id': _walletId,
        'wallet_name': (wallet['name'] ?? '').toString(),
        'category_id': _categoryId ?? '',
        'category_title': (category?['title'] ?? '').toString(),
        'subcategory1_id': _sub1Id ?? '',
        'subcategory1_title': (sub1?['title'] ?? '').toString(),
        'subcategory2_id': _sub2Id ?? '',
        'subcategory2_title': (sub2?['title'] ?? '').toString(),
        'amount': amount,
        'description': _desc.text.trim(),
        'scope': 'personal',
        'source': 'manual',
        'section': personalMoneySection,
        'entry_scope': personalMoneySection,
        'user_id': user.uid,
        'idCompany': companyId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      final oldWalletId = (widget.existing?['wallet_id'] ?? '').toString();
      final oldAmount =
          PersonalFinanceSupport.toNum(widget.existing?['amount']);

      if (widget.existing == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.entriesCollection)
            .add(data);
        await PersonalFinanceSupport.applyWalletDelta(
          FirebaseFirestore.instance,
          _walletId!,
          -amount,
        );
      } else {
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.entriesCollection)
            .doc(widget.existing!['id'])
            .update(data);
        await PersonalFinanceSupport.applyWalletDelta(
          FirebaseFirestore.instance,
          oldWalletId,
          oldAmount,
        );
        await PersonalFinanceSupport.applyWalletDelta(
          FirebaseFirestore.instance,
          _walletId!,
          -amount,
        );
      }

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
    return AlertDialog(
      title: Text(isEdit ? 'Редактировать расход' : 'Добавить расход'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _walletId,
                decoration: const InputDecoration(labelText: 'Кошелек'),
                items: widget.wallets
                    .map((item) => DropdownMenuItem<String>(
                          value: (item['id'] ?? '').toString(),
                          child: Text((item['name'] ?? 'Кошелек').toString()),
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
                value: _categoryId,
                decoration:
                    const InputDecoration(labelText: 'Основная категория'),
                items: root
                    .map((item) => DropdownMenuItem<String>(
                          value: (item['id'] ?? '').toString(),
                          child:
                              Text((item['title'] ?? 'Категория').toString()),
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
                value: _sub1Id,
                decoration: const InputDecoration(labelText: 'Подкатегория'),
                items: sub1
                    .map((item) => DropdownMenuItem<String>(
                          value: (item['id'] ?? '').toString(),
                          child: Text(
                              (item['title'] ?? 'Подкатегория').toString()),
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
                value: _sub2Id,
                decoration: const InputDecoration(labelText: 'Подкатегория 2'),
                items: sub2
                    .map((item) => DropdownMenuItem<String>(
                          value: (item['id'] ?? '').toString(),
                          child: Text(
                              (item['title'] ?? 'Подкатегория 2').toString()),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _sub2Id = value),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Сумма'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Введите сумму' : null,
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
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: Text(isEdit ? 'Сохранить' : 'Добавить'),
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
            positiveColor: const Color(0xFF1F2A37),
          ),
        ),
      ),
    );
  }
}
