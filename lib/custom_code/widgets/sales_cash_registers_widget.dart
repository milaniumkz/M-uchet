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
import 'package:firebase_auth/firebase_auth.dart';
import '/utils/transaction_sync.dart';
import '/utils/sale_flow_support.dart';
import '/utils/country_profile.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/effective_company_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/sales_ledger_support.dart';
import '/utils/sales_profit_breakdown_support.dart';
import '/utils/warehouse_scope_support.dart';

class SalesCashRegistersWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesCashRegistersWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesCashRegistersWidget> createState() =>
      _SalesCashRegistersWidgetState();
}

class _SalesCashRegistersWidgetState extends State<SalesCashRegistersWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  String _filter = 'today';
  List<CashRegisterShiftEntryView> _registers = [];
  Map<String, Map<String, dynamic>> _profitByRegisterKey = {};
  Map<String, double> _cashierRatingsByKey = {};
  String _currencyCode = 'KZT';

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
          _registers = [];
        });
        return;
      }
      final companyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );
      final snap = await _firestore
          .collection('cash_registers')
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final cashiersSnap = await _firestore
          .collection('cashiers')
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final salesSnap = await _firestore
          .collection('sales')
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final txSnap = await _firestore
          .collection('tranzaction')
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final salesItemsSnap = await _firestore
          .collection('cogs_register')
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final legacyCogsSnap = await _firestore
          .collection('sale_item_cogs')
          .where('idCompany', isEqualTo: companyId)
          .getCached();
      final profileSnap =
          await _firestore.collection('company_profile').doc(companyId).get();
      final userData = currentUserDocument?.snapshotData;
      final rows = filterRowsByUserShopScope(
        userData: userData,
        rows: snap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList(),
      );
      rows.sort((a, b) {
        final ad = _extractDate(a['opened_at']) ?? DateTime(1970);
        final bd = _extractDate(b['opened_at']) ?? DateTime(1970);
        return bd.compareTo(ad);
      });
      final sales = salesSnap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return {'id': d.id, ...data};
      }).toList();
      final transactions = txSnap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return {'id': d.id, ...data};
      }).toList();
      final cogsItems = resolveSalesCogsItems(
        cogsEntries: salesItemsSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList(),
        legacyCogsItems: legacyCogsSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList(),
      );
      final profitRows = buildCashRegisterProfitRows(
        salesLedger: filterRowsByUserShopScope(
          userData: userData,
          rows: buildSalesLedger(sales: sales, transactions: transactions),
        ),
        cogsEntries: cogsItems,
      );
      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _registers = rows.map(CashRegisterShiftEntryView.fromMap).toList();
        _profitByRegisterKey = {};
        _cashierRatingsByKey = {};
        final cashierRows = filterRowsByUserShopScope(
          userData: userData,
          rows: cashiersSnap.docs.map((doc) {
            final raw = doc.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': doc.id, ...data};
          }).toList(),
        );
        for (final data in cashierRows) {
          final ratingRaw =
              data['rating'] ?? data['rate'] ?? data['cashier_rating'];
          final rating = ratingRaw is num
              ? ratingRaw.toDouble()
              : double.tryParse(
                  (ratingRaw ?? '').toString().replaceAll(',', '.'),
                );
          if (rating == null || rating <= 0) continue;
          _cashierRatingsByKey['id:${data['id']}'] = rating;
          final name = (data['name'] ?? '').toString().trim().toLowerCase();
          if (name.isNotEmpty) {
            _cashierRatingsByKey['name:$name'] = rating;
          }
        }
        for (final row in profitRows) {
          final idKey = salesProfitBreakdownKey(
            row,
            idField: 'cash_register_id',
            nameField: 'register_name',
          );
          if (idKey.isNotEmpty) {
            _profitByRegisterKey[idKey] = row;
          }
          final name = (row['register_name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            _profitByRegisterKey['name:${name.toLowerCase()}'] = row;
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading cash registers: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  DateTime? _extractDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _matchFilter(DateTime? dt) {
    if (dt == null) return _filter == 'all';
    final now = DateTime.now();
    if (_filter == 'today') {
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }
    if (_filter == 'week') {
      return dt.isAfter(now.subtract(const Duration(days: 7)));
    }
    if (_filter == 'month') {
      return dt.year == now.year && dt.month == now.month;
    }
    return true;
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  Future<void> _showIncassationDialog(CashRegisterShiftEntryView row) async {
    final amountController = TextEditingController();
    final cashierController =
        TextEditingController(text: row.cashierName.trim());
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    DocumentReference? selectedAccountRef;
    String selectedAccountTitle = '';
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text('Инкассация: ${_registerName(row)}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Сумма',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cashierController,
                        decoration: const InputDecoration(
                          labelText: 'Кассир',
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<List<ShetaRecord>>(
                        stream: queryShetaRecord(
                          queryBuilder: (shetaRecord) => shetaRecord.where(
                            'idCompany',
                            isEqualTo: resolveEffectiveCompanyId(
                              userData: currentUserDocument?.snapshotData,
                              fallbackUserId: _auth.currentUser!.uid,
                            ),
                          ),
                        ),
                        builder: (context, snapshot) {
                          final accounts = snapshot.data ?? [];
                          final hasSelected = accounts.any(
                            (account) =>
                                account.reference == selectedAccountRef,
                          );
                          return DropdownButtonFormField<DocumentReference>(
                            initialValue:
                                hasSelected ? selectedAccountRef : null,
                            items: accounts
                                .map(
                                  (account) =>
                                      DropdownMenuItem<DocumentReference>(
                                    value: account.reference,
                                    child: Text(account.title),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setLocalState(() {
                                selectedAccountRef = value;
                                selectedAccountTitle = accounts
                                    .firstWhere(
                                      (account) => account.reference == value,
                                      orElse: () => accounts.first,
                                    )
                                    .title;
                                errorText = null;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Расчетный счет',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Дата',
                              ),
                              child: Text(
                                dateTimeFormat('d/M/y', selectedDate),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setLocalState(() => selectedDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: const Text('Выбрать'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Описание / основание',
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(
                            amountController.text.replaceAll(',', '.')) ??
                        0;
                    final cashier = cashierController.text.trim();
                    final note = noteController.text.trim();
                    if (amount <= 0) {
                      setLocalState(() => errorText = 'Введите сумму больше 0');
                      return;
                    }
                    if (cashier.isEmpty) {
                      setLocalState(() => errorText = 'Укажите кассира');
                      return;
                    }
                    if (selectedAccountRef == null ||
                        selectedAccountTitle.isEmpty) {
                      setLocalState(
                        () => errorText = 'Выберите расчетный счет',
                      );
                      return;
                    }
                    if (note.isEmpty) {
                      setLocalState(
                        () => errorText = 'Заполните описание вручную',
                      );
                      return;
                    }

                    final plan = await buildCashRegisterIncassationWritePlan(
                      firestore: _firestore,
                      companyId: row.companyId,
                      shiftId: row.id,
                      cashRegisterName: _registerName(row),
                      cashierName: cashier,
                      note: note,
                      amount: amount,
                      accountReference: selectedAccountRef!,
                      accountTitle: selectedAccountTitle,
                      operationDate: selectedDate,
                      typeUchet: row.typeUchet,
                      ledgerScope: row.ledgerScope,
                      nextIncassationTotal: row.incassationTotal + amount,
                    );

                    final batch = _firestore.batch();
                    batch.set(plan.incassationRef, plan.incassationData);
                    batch.set(plan.transactionRef, plan.transactionData);
                    for (final write in plan.entryWrites) {
                      batch.set(write.reference, write.data);
                    }
                    batch.update(
                      _firestore.collection('cash_registers').doc(
                            row.id,
                          ),
                      plan.cashRegisterPatch,
                    );
                    await batch.commit();

                    await TransactionSync.recomputeAllForCompany(
                      row.companyId,
                    );
                    FirestoreQueryCache.instance.invalidateCompanyCollection(
                      'cash_registers',
                      row.companyId,
                    );
                    FirestoreQueryCache.instance.invalidateCompanyCollection(
                      'tranzaction',
                      row.companyId,
                    );
                    FirestoreQueryCache.instance.invalidateCompanyCollection(
                      'cash_register_incassations',
                      row.companyId,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    await _loadData();
                  },
                  child: const Text('Провести'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    cashierController.dispose();
    noteController.dispose();
  }

  String _registerName(CashRegisterShiftEntryView row) {
    final explicit = row.cashRegisterName.trim();
    if (explicit.isNotEmpty) return explicit;
    final cashier = row.cashierName.trim();
    if (cashier.isNotEmpty) {
      final cashierId = row.cashierId.trim();
      final rating = cashierId.isNotEmpty
          ? _cashierRatingsByKey['id:$cashierId']
          : _cashierRatingsByKey['name:${cashier.toLowerCase()}'];
      if (rating != null && rating > 0) {
        return '$cashier ★${rating.toStringAsFixed(1)}';
      }
      return cashier;
    }
    final id = row.id;
    return id.isEmpty
        ? 'Касса'
        : 'Касса ${id.substring(0, id.length > 6 ? 6 : id.length)}';
  }

  List<CashRegisterShiftEntryView> get _filteredRegisters {
    return _registers.where((row) {
      return _matchFilter(row.openedAtOrCreatedAt);
    }).toList();
  }

  double get _totalTurnover =>
      _filteredRegisters.fold(0, (s, i) => s + i.turnover);
  double get _totalCogs =>
      _filteredRegisters.fold(0, (s, i) => s + _registerCogs(i));
  double get _grossProfit => _totalTurnover - _totalCogs;

  int get _totalChecks =>
      _filteredRegisters.fold(0, (s, i) => s + i.transactions.round());

  double get _avgCheck => _totalChecks == 0 ? 0 : _totalTurnover / _totalChecks;

  int get _openCount => _filteredRegisters.where((i) => i.isOpen).length;

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.cash')) {
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
                    color: FlutterFlowTheme.of(context).accent1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.point_of_sale_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Кассы',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Смены касс и средний чек по кассе',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: _filter,
                  onChanged: (v) => setState(() => _filter = v ?? 'today'),
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text('Сегодня')),
                    DropdownMenuItem(value: 'week', child: Text('Неделя')),
                    DropdownMenuItem(value: 'month', child: Text('Месяц')),
                    DropdownMenuItem(value: 'all', child: Text('Все время')),
                  ],
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
                _statCard(
                  title: 'Кассы (смены)',
                  value: _filteredRegisters.length.toString(),
                  icon: Icons.point_of_sale_outlined,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                _statCard(
                  title: 'Открытые',
                  value: _openCount.toString(),
                  icon: Icons.lock_open_rounded,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                _statCard(
                  title: 'Кол-во чеков',
                  value: _totalChecks.toString(),
                  icon: Icons.receipt_long,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                _statCard(
                  title: 'COGS',
                  value: _formatMoney(_totalCogs),
                  amount: _totalCogs,
                  icon: Icons.inventory_2_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.12),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                _statCard(
                  title: 'Валовая',
                  value: _formatMoney(_grossProfit),
                  amount: _grossProfit,
                  icon: Icons.stacked_line_chart,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                _statCard(
                  title: 'Средний чек по кассе',
                  value: _formatMoney(_avgCheck),
                  amount: _avgCheck,
                  icon: Icons.trending_up,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.12),
                  iconColor: const Color(0xFF9E7B4F),
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
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Список касс',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _filteredRegisters.isEmpty
                              ? Center(
                                  child: Text(
                                    'Кассы не найдены',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _filteredRegisters.length,
                                  itemBuilder: (context, index) =>
                                      _tableRow(_filteredRegisters[index]),
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
        _HeaderCell('Касса', flex: 3),
        _HeaderCell('Статус', flex: 1),
        _HeaderCell('Кол-во чеков', flex: 1),
        _HeaderCell('Средний чек', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Наличные', flex: 2),
        _HeaderCell('Карта', flex: 2),
        _HeaderCell('На закрытие дня наличных', flex: 2),
        _HeaderCell('Инкассация', flex: 2),
      ],
    );
  }

  Widget _tableRow(CashRegisterShiftEntryView row) {
    final transactions = row.transactions.round();
    final cashSales = row.cashSales;
    final cardSales = row.cardSales;
    final avg = row.averageCheck;
    final cogs = _registerCogs(row);
    final grossProfit = row.turnover - cogs;
    final statusLabel = row.isOpen ? 'Открыта' : 'Закрыта';
    final endingCash = row.endingCash;
    final incassationTotal = row.incassationTotal;

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
          _Cell(_registerName(row), flex: 3, bold: true),
          _Cell(statusLabel, flex: 1),
          _Cell(transactions.toString(), flex: 1),
          _Cell(_formatMoney(avg), flex: 2, amount: avg),
          _Cell(_formatMoney(cogs), flex: 2, amount: cogs),
          _Cell(_formatMoney(grossProfit), flex: 2, amount: grossProfit),
          _Cell(_formatMoney(cashSales), flex: 2, amount: cashSales),
          _Cell(_formatMoney(cardSales), flex: 2, amount: cardSales),
          _Cell(_formatMoney(endingCash), flex: 2, amount: endingCash),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _formatMoney(incassationTotal),
                    style: TextStyle(
                      fontSize: 12,
                      color: amountTextColor(
                        context,
                        incassationTotal,
                        positiveColor: FlutterFlowTheme.of(context).primaryText,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showIncassationDialog(row),
                    child: const Text('Инкассация'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    num? amount,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return SizedBox(
      width: 240,
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
      ),
    );
  }

  double _registerCogs(CashRegisterShiftEntryView row) {
    final key = row.id.isNotEmpty
        ? 'id:${row.id}'
        : (row.cashRegisterName.trim().isEmpty
            ? ''
            : 'name:${row.cashRegisterName.trim().toLowerCase()}');
    if (key.isEmpty) return 0;
    final profitRow = _profitByRegisterKey[key];
    if (profitRow == null) return 0;
    final value = profitRow['cogs'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
