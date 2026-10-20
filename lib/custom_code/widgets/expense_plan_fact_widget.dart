// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/business_event_support.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/app_money_format.dart';
import '/utils/expense_plan_analytics_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/report_export_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpensePlanFactWidget extends StatefulWidget {
  const ExpensePlanFactWidget({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  State<ExpensePlanFactWidget> createState() => _ExpensePlanFactWidgetState();
}

class _ExpensePlanFactWidgetState extends State<ExpensePlanFactWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  String _viewMode = 'table';
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _accountingEntries = [];
  List<Map<String, dynamic>> _businessEvents = [];
  List<String> _categories = [];
  LedgerScope _scope = LedgerScope.both;
  String _currencyCode = 'KZT';
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _load();
  }

  String get _periodKey =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

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
    for (final field in const ['idCompany', 'companyId', 'company_id']) {
      for (final chunk in splitCompanyIdsForWhereIn(companyIds)) {
        Query<Map<String, dynamic>> query =
            _firestore.collection(collectionName);
        if (chunk.length == 1) {
          query = query.where(field, isEqualTo: chunk.first);
        } else {
          query = query.where(field, whereIn: chunk);
        }
        if (limitPerQuery != null) {
          query = query.limit(limitPerQuery);
        }
        final snap = await query.getCached();
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
    }
    return docsById.values.toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final results = await Future.wait([
        _loadCompanyScopedDocs('expense_plans', limitPerQuery: 1000),
        _loadCompanyScopedDocs('tranzaction', limitPerQuery: 3000),
        _loadCompanyScopedDocs('accounting_entries', limitPerQuery: 5000),
        _loadCompanyScopedDocs('business_events', limitPerQuery: 4000),
        _loadCompanyScopedDocs('statRashod', limitPerQuery: 500),
      ]);
      final companyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );
      final profileSnap =
          await _firestore.collection('company_profile').doc(companyId).get();
      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _plans = List<Map<String, dynamic>>.from(results[0]);
        _expenses = List<Map<String, dynamic>>.from(results[1])
            .where((row) =>
                expensePlanString(row['type']).toLowerCase() == 'decome')
            .toList();
        _accountingEntries = List<Map<String, dynamic>>.from(results[2]);
        _businessEvents = List<Map<String, dynamic>>.from(results[3]);
        _categories = List<Map<String, dynamic>>.from(results[4])
            .map((doc) => expensePlanString(doc['title']))
            .where((title) => title.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ExpensePlanFactRow> get _rows => _businessEvents.any(
        (event) =>
            businessEventTypeFromValue(
                (event['event_type'] ?? '').toString()) ==
            BusinessEventType.expenseRecorded,
      )
          ? buildExpensePlanFactRowsFromEvents(
              planDocs: _plans,
              eventDocs: _businessEvents,
              periodKey: _periodKey,
              ledgerScope: _scope == LedgerScope.both ? null : _scope,
            )
          : buildExpensePlanFactRows(
              planDocs: _plans,
              expenseDocs: buildBudgetExpenseActualDocs(
                transactions: _expenses,
                accountingEntries: _accountingEntries,
              ),
              periodKey: _periodKey,
              ledgerScope: _scope == LedgerScope.both ? null : _scope,
            );

  List<ExpenseRiskIndicator> get _risks => buildExpenseRiskIndicators(_rows);

  double get _planned =>
      _rows.fold<double>(0, (t, row) => t + row.plannedAmount);
  double get _actual => _rows.fold<double>(0, (t, row) => t + row.actualAmount);
  double get _variance =>
      _rows.fold<double>(0, (t, row) => t + row.varianceAmount);

  String _money(double value) => formatMoneyWithCurrency(
        value,
        currencyCode: _currencyCode,
      );

  String _compactMoney(double value) {
    final rounded = value.round();
    final negative = rounded < 0;
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(' ');
      }
    }
    return '${negative ? '-' : ''}${buffer.toString()}';
  }

  Future<void> _showAddPlanDialog() async {
    final amountController = TextEditingController();
    final departmentController = TextEditingController();
    var category = _categories.isEmpty ? '' : _categories.first;
    var branchId = '';
    var branchName = '';
    var notes = '';
    final user = _auth.currentUser;
    final companyId = resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user?.uid ?? '',
    );
    final branchSnap = companyId.isEmpty
        ? null
        : await _firestore
            .collection('company_branches')
            .where('idCompany', isEqualTo: companyId)
            .getCached();
    final branches = branchSnap?.docs ??
        const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый План расходов'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: category.isEmpty ? null : category,
              decoration: const InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => category = value ?? '',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: branchId,
              decoration: const InputDecoration(
                labelText: 'Филиал',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Без филиала')),
                ...branches.map((doc) {
                  final rawData = doc.data();
                  final data = rawData is Map<String, dynamic>
                      ? rawData
                      : rawData is Map
                          ? Map<String, dynamic>.from(rawData)
                          : const <String, dynamic>{};
                  final name = (data['name'] ?? '').toString();
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(name.isEmpty ? 'Филиал' : name),
                  );
                }),
              ],
              onChanged: (value) {
                branchId = value ?? '';
                final selected = branches.where((doc) => doc.id == branchId);
                final rawSelectedData =
                    selected.isEmpty ? null : selected.first.data();
                final selectedData = rawSelectedData is Map<String, dynamic>
                    ? rawSelectedData
                    : rawSelectedData is Map
                        ? Map<String, dynamic>.from(rawSelectedData)
                        : const <String, dynamic>{};
                branchName = selected.isEmpty
                    ? ''
                    : (selectedData['name'] ?? '').toString();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: departmentController,
              decoration: const InputDecoration(
                labelText: 'Подразделение',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Плановая сумма',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => notes = value,
              decoration: const InputDecoration(
                labelText: 'Примечания',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (user == null || category.trim().isEmpty) return;
              await _firestore.collection('expense_plans').add(
                {
                  ...buildExpensePlanPayload(
                    companyId: companyId,
                    categoryName: category,
                    periodKey: _periodKey,
                    plannedAmount: double.tryParse(
                            amountController.text.replaceAll(',', '.')) ??
                        0,
                    ledgerScope: _scope == LedgerScope.both
                        ? LedgerScope.accounting
                        : _scope,
                    notes: notes,
                    isCreate: true,
                  ),
                  'branch_id': branchId,
                  'branch': branchName,
                  'branch_name': branchName,
                  'department': departmentController.text.trim(),
                },
              );
              if (context.mounted) Navigator.pop(context);
              await _load();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    amountController.dispose();
    departmentController.dispose();
  }

  Future<void> _exportExcel() {
    final rows = buildExpenseReportExportRows(
      title: 'Plan / Fact расходов',
      bodyRows: <List<String>>[
        <String>[
          'Категория',
          'План',
          'Факт',
          'Отклонение',
          'Отклонение %',
          'Контур'
        ],
        ..._rows.map(
          (row) => <String>[
            row.categoryName,
            row.plannedAmount.toStringAsFixed(2),
            row.actualAmount.toStringAsFixed(2),
            row.varianceAmount.toStringAsFixed(2),
            row.variancePercent.toStringAsFixed(2),
            row.ledgerScope.storageValue,
          ],
        ),
      ],
    );
    return exportReportExcel(
      filename: 'expense-plan-fact.xls',
      title: 'Plan / Fact расходов',
      rows: rows,
    );
  }

  Future<void> _exportPdf() {
    final rows = buildExpenseReportExportRows(
      title: 'Plan / Fact расходов',
      bodyRows: <List<String>>[
        <String>[
          'Категория',
          'План',
          'Факт',
          'Отклонение',
          'Отклонение %',
          'Контур'
        ],
        ..._rows.map(
          (row) => <String>[
            row.categoryName,
            row.plannedAmount.toStringAsFixed(2),
            row.actualAmount.toStringAsFixed(2),
            row.varianceAmount.toStringAsFixed(2),
            row.variancePercent.toStringAsFixed(2),
            row.ledgerScope.storageValue,
          ],
        ),
      ],
    );
    return exportReportPdf(
      filename: 'expense-plan-fact.pdf',
      title: 'Plan / Fact расходов',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Plan / Fact расходов',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddPlanDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('План'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportExcel,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Excel'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _statCard('План', _money(_planned))),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Факт', _money(_actual))),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Отклонение', _money(_variance))),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Риски', _risks.length.toString())),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Год',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (index) {
                      final year = DateTime.now().year - 2 + index;
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedYear = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Месяц',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem<int>(
                        value: month,
                        child: Text(month.toString().padLeft(2, '0')),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedMonth = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<LedgerScope>(
                    initialValue: _scope,
                    decoration: const InputDecoration(
                      labelText: 'Контур',
                      border: OutlineInputBorder(),
                    ),
                    items: LedgerScope.values
                        .map((scope) => DropdownMenuItem(
                              value: scope,
                              child: Text(scope.storageValue),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _scope = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _viewMode == 'chart'
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          _buildPlanFactChart(),
                          if (_risks.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Риск-индикаторы',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._risks.map(
                              (risk) => ListTile(
                                dense: true,
                                tileColor: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                title: Text(risk.categoryName),
                                subtitle: Text(risk.message),
                                trailing: Text(risk.severity.toUpperCase()),
                              ),
                            ),
                          ],
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          ..._rows.map(
                            (row) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.categoryName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _chip(
                                          'План ${_money(row.plannedAmount)}'),
                                      _chip('Факт ${_money(row.actualAmount)}'),
                                      _chip(
                                        'Откл. ${_money(row.varianceAmount)}',
                                      ),
                                      _chip(
                                        '${row.variancePercent.toStringAsFixed(1)}%',
                                      ),
                                      _chip(row.ledgerScope.storageValue),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_risks.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Риск-индикаторы',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._risks.map(
                              (risk) => ListTile(
                                dense: true,
                                tileColor: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                title: Text(risk.categoryName),
                                subtitle: Text(risk.message),
                                trailing: Text(risk.severity.toUpperCase()),
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanFactChart() {
    final rows = _rows;
    if (rows.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Text(
          'Данные не найдены',
          style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText),
        ),
      );
    }

    final topRows = [...rows]
      ..sort((a, b) => (b.plannedAmount.abs() + b.actualAmount.abs()).compareTo(
            a.plannedAmount.abs() + a.actualAmount.abs(),
          ));
    final visibleRows = topRows.take(10).toList(growable: false);
    final maxValue = visibleRows.fold<double>(
      1,
      (max, row) => [
        max,
        row.plannedAmount.abs(),
        row.actualAmount.abs(),
      ].reduce((a, b) => a > b ? a : b),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan / Fact по категориям',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ExpenseLegendChip(label: 'План', color: Color(0xFF2563EB)),
              _ExpenseLegendChip(label: 'Факт', color: Color(0xFF16A34A)),
            ],
          ),
          const SizedBox(height: 16),
          ...visibleRows.map((row) {
            final planWidth =
                maxValue <= 0 ? 0.0 : row.plannedAmount.abs() / maxValue;
            final factWidth =
                maxValue <= 0 ? 0.0 : row.actualAmount.abs() / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.categoryName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _ExpenseBarRow(
                        label: 'План',
                        color: const Color(0xFF2563EB),
                        width: width * planWidth,
                        value: _compactMoney(row.plannedAmount),
                      ),
                      const SizedBox(height: 6),
                      _ExpenseBarRow(
                        label: 'Факт',
                        color: const Color(0xFF16A34A),
                        width: width * factWidth,
                        value: _compactMoney(row.actualAmount),
                      ),
                    ],
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }

  Widget _statCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: FlutterFlowTheme.of(context).secondaryText)),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ExpenseLegendChip extends StatelessWidget {
  const _ExpenseLegendChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ExpenseBarRow extends StatelessWidget {
  const _ExpenseBarRow({
    required this.label,
    required this.color,
    required this.width,
    required this.value,
  });

  final String label;
  final Color color;
  final double width;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Container(
                width: width.clamp(12.0, double.infinity),
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
