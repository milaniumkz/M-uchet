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
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/country_profile.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/sales_ledger_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/effective_company_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/sales_profit_breakdown_support.dart';
import '/utils/warehouse_scope_support.dart';

class SalesCashierReportsWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesCashierReportsWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesCashierReportsWidget> createState() =>
      _SalesCashierReportsWidgetState();
}

class _SalesCashierReportsWidgetState extends State<SalesCashierReportsWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<SaleEntryView> _sales = [];
  Map<String, double> _cogsBySaleId = {};
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _cashiers = [];
  String _filter = 'today';
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
        setState(() => _sales = []);
        return;
      }
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final results = await Future.wait([
        _firestore
            .collection('sales')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('tranzaction')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('employees')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('cashiers')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('cogs_register')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('sale_item_cogs')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
      ]);
      final salesSnap = results[0];
      final txSnap = results[1];
      final employeesSnap = results[2];
      final cashiersSnap = results[3];
      final salesItemsSnap = results[4];
      final legacyCogsSnap = results[5];
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        final userData = currentUserDocument?.snapshotData;
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
        final scopedSales = filterRowsByUserShopScope(
          userData: userData,
          rows: buildSalesLedger(sales: sales, transactions: transactions),
        );
        final scopedSaleIds = resolveSaleIdsFromRows(scopedSales);
        _sales = scopedSales.map(SaleEntryView.fromMap).toList();
        _employees = filterRowsByUserShopScope(
          userData: userData,
          rows: employeesSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _cashiers = filterRowsByUserShopScope(
          userData: userData,
          rows: cashiersSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        final cogsItems = resolveSalesCogsItems(
          cogsEntries: filterRowsByShopScopeOrSaleIds(
            userData: userData,
            saleIds: scopedSaleIds,
            rows: salesItemsSnap.docs.map((d) {
              final raw = d.data();
              final data = raw is Map<String, dynamic>
                  ? raw
                  : Map<String, dynamic>.from(raw as Map);
              return {'id': d.id, ...data};
            }).toList(),
          ),
          legacyCogsItems: filterRowsByShopScopeOrSaleIds(
            userData: userData,
            saleIds: scopedSaleIds,
            rows: legacyCogsSnap.docs.map((d) {
              final raw = d.data();
              final data = raw is Map<String, dynamic>
                  ? raw
                  : Map<String, dynamic>.from(raw as Map);
              return {'id': d.id, ...data};
            }).toList(),
          ),
        );
        _cogsBySaleId = buildSaleCogsBySaleId(
          cogsEntries: cogsItems,
        );
      });
    } catch (e) {
      debugPrint('Error loading cashier reports: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  bool _matchFilter(DateTime? dt) {
    if (dt == null) return false;
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

  bool _isOfficialSale(SaleEntryView sale) {
    return sale.ledgerScope == LedgerScope.accounting;
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  List<SaleEntryView> get _filteredSales {
    return _sales.where((s) => _matchFilter(s.createdAt)).toList();
  }

  double get _totalSales => _filteredSales.fold(0, (s, i) => s + i.amount);
  double get _totalCogs =>
      _filteredSales.fold(0, (s, i) => s + (_cogsBySaleId[i.id] ?? 0));
  double get _grossProfit => _totalSales - _totalCogs;
  int get _totalTransactions => _filteredSales.length;
  double get _totalDiscount => _filteredSales.fold(0, (s, i) => s + i.discount);
  double get _avgCheck =>
      _totalTransactions == 0 ? 0 : _totalSales / _totalTransactions;

  Map<String, _CashierRow> get _salesByCashier {
    final map = <String, _CashierRow>{};
    final planByCashier = _planByCashierKey;
    for (final sale in _filteredSales) {
      final id = sale.cashierId;
      final name = sale.cashierName;
      final key = id.isNotEmpty ? id : name;
      if (key.isEmpty) continue;
      map.putIfAbsent(
        key,
        () => _CashierRow(
          name: name.isEmpty ? key : name,
          plan: planByCashier[key] ?? planByCashier[name] ?? 0,
        )..key = key,
      );
      map[key]!.sales += sale.amount;
      map[key]!.cogs += _cogsBySaleId[sale.id] ?? 0;
      map[key]!.transactions += 1;
      final shopName = sale.shopName.trim();
      map[key]!.shops.add(shopName.isEmpty ? 'Без магазина' : shopName);
    }
    return map;
  }

  Map<String, double> get _planByCashierKey {
    final map = <String, double>{};
    for (final e in _employees) {
      final userId = (e['user_id'] ?? '').toString().trim();
      final name = (e['name'] ?? '').toString().trim();
      final plan = double.tryParse(
            '${e['plan_sales'] ?? e['plan_amount'] ?? e['sales_plan'] ?? 0}'
                .replaceAll(',', '.'),
          ) ??
          0;
      if (userId.isNotEmpty) map[userId] = plan;
      if (name.isNotEmpty && !map.containsKey(name)) map[name] = plan;
    }
    return map;
  }

  List<_CashierRow> get _cashierRowsSorted {
    final list = _salesByCashier.values.toList();
    list.sort((a, b) => b.sales.compareTo(a.sales));
    return list;
  }

  double? _cashierRating(String key, String name) {
    for (final doc in _cashiers) {
      final docId = (doc['id'] ?? '').toString().trim();
      final userId = (doc['user_id'] ?? '').toString().trim();
      final docName = (doc['name'] ?? '').toString().trim();
      final matches = (key.isNotEmpty &&
              (docId == key || userId == key || docName == key)) ||
          (name.isNotEmpty && docName == name);
      if (!matches) continue;
      final value = doc['rating'] ?? doc['rate'] ?? doc['cashier_rating'];
      if (value is num) return value.toDouble();
      final parsed =
          double.tryParse((value ?? '').toString().replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return null;
  }

  Map<String, _CashierShopRow> get _salesByCashierShop {
    final map = <String, _CashierShopRow>{};
    final planByCashier = _planByCashierKey;
    for (final sale in _filteredSales) {
      final cashierId = sale.cashierId.trim();
      final cashierName = sale.cashierName.trim();
      final cashierKey = cashierId.isNotEmpty ? cashierId : cashierName;
      if (cashierKey.isEmpty) continue;
      final shopName = sale.shopName.trim();
      final shopLabel = shopName.isEmpty ? 'Без магазина' : shopName;
      final key = '$cashierKey|$shopLabel';
      map.putIfAbsent(
        key,
        () => _CashierShopRow(
          cashierName: cashierName.isEmpty ? cashierKey : cashierName,
          shopName: shopLabel,
          plan: planByCashier[cashierKey] ?? planByCashier[cashierName] ?? 0,
        ),
      );
      map[key]!.sales += sale.amount;
      map[key]!.cogs += _cogsBySaleId[sale.id] ?? 0;
      map[key]!.transactions += 1;
    }
    return map;
  }

  List<_CashierShopRow> get _cashierShopRowsSorted {
    final list = _salesByCashierShop.values.toList();
    list.sort((a, b) => b.sales.compareTo(a.sales));
    return list;
  }

  Map<String, _CashRegisterRow> get _salesByCashRegister {
    final map = <String, _CashRegisterRow>{};
    for (final sale in _filteredSales) {
      final id = sale.cashRegisterId.trim();
      final name = sale.cashRegisterName.trim();
      final key = id.isNotEmpty ? id : (name.isNotEmpty ? name : 'no_register');
      map.putIfAbsent(
        key,
        () => _CashRegisterRow(
          name: name.isNotEmpty
              ? name
              : (id.isNotEmpty ? 'Касса $id' : 'Без кассы'),
        ),
      );
      map[key]!.sales += sale.amount;
      map[key]!.cogs += _cogsBySaleId[sale.id] ?? 0;
      map[key]!.transactions += 1;
    }
    return map;
  }

  List<_CashRegisterRow> get _cashRegisterRowsSorted {
    final list = _salesByCashRegister.values.toList();
    list.sort((a, b) => b.sales.compareTo(a.sales));
    return list;
  }

  List<_CashierShopRow> get _cashierWithoutShopRows => _cashierShopRowsSorted
      .where((r) => r.shopName == 'Без магазина')
      .toList();

  double get _cashSales => _filteredSales
      .where((s) => s.paymentMethod == 'cash')
      .fold(0, (total, i) => total + i.amount);
  double get _cardSales => _filteredSales
      .where((s) => s.paymentMethod == 'card')
      .fold(0, (total, i) => total + i.amount);

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.reports')) {
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
                  child: const Icon(Icons.bar_chart_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Отчеты по кассирам',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Анализ продаж и производительности',
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
                  title: 'Продажи',
                  value: _formatMoney(_totalSales),
                  icon: Icons.attach_money,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                _statCard(
                  title: 'Чеки',
                  value: _totalTransactions.toString(),
                  icon: Icons.receipt_long,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                _statCard(
                  title: 'Скидки',
                  value: _formatMoney(_totalDiscount),
                  icon: Icons.percent,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                _statCard(
                  title: 'Средний чек',
                  value: _formatMoney(_avgCheck),
                  icon: Icons.trending_up,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.12),
                  iconColor: const Color(0xFF9E7B4F),
                ),
                _statCard(
                  title: 'COGS',
                  value: _formatMoney(_totalCogs),
                  icon: Icons.inventory_2_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                _statCard(
                  title: 'Валовая',
                  value: _formatMoney(_grossProfit),
                  icon: Icons.stacked_line_chart,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                _statCard(
                  title: 'Наличные',
                  value: _formatMoney(_cashSales),
                  icon: Icons.payments_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                _statCard(
                  title: 'Карта',
                  value: _formatMoney(_cardSales),
                  icon: Icons.credit_card,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                _statCard(
                  title: 'Без магазина',
                  value: _cashierWithoutShopRows.length.toString(),
                  icon: Icons.storefront_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .error
                      .withValues(alpha: 0.12),
                  iconColor: const Color(0xFFB42318),
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
                          'Рейтинг сотрудников (кассиры)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _cashierRowsSorted.isEmpty
                              ? Center(
                                  child: Text(
                                    'Данные не найдены',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _cashierRowsSorted.length,
                                  itemBuilder: (context, index) =>
                                      _tableRow(_cashierRowsSorted[index]),
                                ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'По сотрудникам и магазинам (включая без магазина)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _shopTableHeader(),
                        const Divider(height: 1),
                        SizedBox(
                          height: 220,
                          child: _cashierShopRowsSorted.isEmpty
                              ? Center(
                                  child: Text(
                                    'Нет данных по магазинам',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _cashierShopRowsSorted.length,
                                  itemBuilder: (context, index) =>
                                      _shopTableRow(
                                          _cashierShopRowsSorted[index]),
                                ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'По кассам',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _registerTableHeader(),
                        const Divider(height: 1),
                        SizedBox(
                          height: 180,
                          child: _cashRegisterRowsSorted.isEmpty
                              ? Center(
                                  child: Text(
                                    'Нет данных по кассам',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _cashRegisterRowsSorted.length,
                                  itemBuilder: (context, index) =>
                                      _registerTableRow(
                                    _cashRegisterRowsSorted[index],
                                  ),
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

  Widget _statCard({
    required String title,
    required String value,
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

  Widget _tableHeader() {
    return const Row(
      children: [
        _HeaderCell('Кассир', flex: 3),
        _HeaderCell('Магазины', flex: 2),
        _HeaderCell('План', flex: 2),
        _HeaderCell('Факт', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Чеки', flex: 1),
        _HeaderCell('Средний чек', flex: 2),
        _HeaderCell('% план', flex: 1),
      ],
    );
  }

  Widget _tableRow(_CashierRow row) {
    final avg = row.transactions == 0 ? 0.0 : row.sales / row.transactions;
    final perf = row.plan == 0 ? 0.0 : (row.sales / row.plan) * 100;
    final grossProfit = row.sales - row.cogs;
    final rating = _cashierRating(row.key, row.name);
    return InkWell(
      onTap: () => _showCashierDetails(row),
      child: Container(
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
            _Cell(
              rating == null || rating <= 0
                  ? row.name
                  : '${row.name} ★${rating.toStringAsFixed(1)}',
              flex: 3,
              bold: true,
            ),
            _Cell(
              row.shops.isEmpty ? 'Без магазина' : row.shops.take(2).join(', '),
              flex: 2,
            ),
            _Cell(_formatMoney(row.plan), flex: 2, amount: row.plan),
            _Cell(_formatMoney(row.sales), flex: 2, amount: row.sales),
            _Cell(_formatMoney(row.cogs), flex: 2, amount: row.cogs),
            _Cell(_formatMoney(grossProfit), flex: 2, amount: grossProfit),
            _Cell(row.transactions.toString(), flex: 1),
            _Cell(_formatMoney(avg), flex: 2, amount: avg),
            _Cell('${perf.toStringAsFixed(0)}%', flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _shopTableHeader() {
    return const Row(
      children: [
        _HeaderCell('Сотрудник', flex: 3),
        _HeaderCell('Магазин', flex: 2),
        _HeaderCell('План', flex: 2),
        _HeaderCell('Факт', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Чеки', flex: 1),
        _HeaderCell('Средний чек', flex: 2),
      ],
    );
  }

  Widget _shopTableRow(_CashierShopRow row) {
    final avg = row.transactions == 0 ? 0.0 : row.sales / row.transactions;
    final grossProfit = row.sales - row.cogs;
    final rating = _cashierRating(row.cashierName, row.cashierName);
    return InkWell(
      onTap: () => _showCashierShopDetails(row),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: FlutterFlowTheme.of(context)
                      .alternate
                      .withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            _Cell(
              rating == null || rating <= 0
                  ? row.cashierName
                  : '${row.cashierName} ★${rating.toStringAsFixed(1)}',
              flex: 3,
              bold: true,
            ),
            _Cell(row.shopName, flex: 2),
            _Cell(_formatMoney(row.plan), flex: 2, amount: row.plan),
            _Cell(_formatMoney(row.sales), flex: 2, amount: row.sales),
            _Cell(_formatMoney(row.cogs), flex: 2, amount: row.cogs),
            _Cell(_formatMoney(grossProfit), flex: 2, amount: grossProfit),
            _Cell(row.transactions.toString(), flex: 1),
            _Cell(_formatMoney(avg), flex: 2, amount: avg),
          ],
        ),
      ),
    );
  }

  Widget _registerTableHeader() {
    return const Row(
      children: [
        _HeaderCell('Касса', flex: 3),
        _HeaderCell('Факт', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Чеки', flex: 1),
        _HeaderCell('Средний чек', flex: 2),
      ],
    );
  }

  Widget _registerTableRow(_CashRegisterRow row) {
    final avg = row.transactions == 0 ? 0.0 : row.sales / row.transactions;
    final grossProfit = row.sales - row.cogs;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: FlutterFlowTheme.of(context)
                    .alternate
                    .withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          _Cell(row.name, flex: 3, bold: true),
          _Cell(_formatMoney(row.sales), flex: 2, amount: row.sales),
          _Cell(_formatMoney(row.cogs), flex: 2, amount: row.cogs),
          _Cell(_formatMoney(grossProfit), flex: 2, amount: grossProfit),
          _Cell(row.transactions.toString(), flex: 1),
          _Cell(_formatMoney(avg), flex: 2, amount: avg),
        ],
      ),
    );
  }

  Future<void> _showCashierDetails(_CashierRow row) async {
    final sales = _filteredSales.where((s) {
      final name = s.cashierName.trim();
      final id = s.cashierId.trim();
      return name == row.name || id == row.key;
    }).toList();
    sales.sort((a, b) {
      final ad = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bd = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bd.compareTo(ad);
    });
    final officialSales = sales.where(_isOfficialSale).toList();
    final unofficialSales = sales.where((s) => !_isOfficialSale(s)).toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Сотрудник: ${row.name}'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('План: ${_formatMoney(row.plan)}'),
              Text('Факт: ${_formatMoney(row.sales)}'),
              Text('Чеки: ${row.transactions}'),
              const SizedBox(height: 8),
              Text(
                  'Магазины: ${row.shops.isEmpty ? 'Без магазина' : row.shops.join(', ')}'),
              const SizedBox(height: 10),
              const Text('Журнал чеков',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: ListView(
                  children: [
                    _salesJournalSection(
                      title: 'Официальные',
                      sales: officialSales,
                      emptyText: 'Официальных чеков нет',
                    ),
                    const SizedBox(height: 12),
                    _salesJournalSection(
                      title: 'Неофициальные',
                      sales: unofficialSales,
                      emptyText: 'Неофициальных чеков нет',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _showCashierShopDetails(_CashierShopRow row) async {
    final sales = _filteredSales.where((s) {
      final cashier = s.cashierName.trim();
      final shop = s.shopName.trim();
      final shopNorm = shop.isEmpty ? 'Без магазина' : shop;
      return cashier == row.cashierName && shopNorm == row.shopName;
    }).toList();
    sales.sort((a, b) {
      final ad = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bd = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bd.compareTo(ad);
    });
    final officialSales = sales.where(_isOfficialSale).toList();
    final unofficialSales = sales.where((s) => !_isOfficialSale(s)).toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${row.cashierName} • ${row.shopName}'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('План: ${_formatMoney(row.plan)}'),
              Text('Факт: ${_formatMoney(row.sales)}'),
              Text('Чеки: ${row.transactions}'),
              const SizedBox(height: 10),
              const Text('Журнал чеков',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: ListView(
                  children: [
                    _salesJournalSection(
                      title: 'Официальные',
                      sales: officialSales,
                      emptyText: 'Официальных чеков нет',
                    ),
                    const SizedBox(height: 12),
                    _salesJournalSection(
                      title: 'Неофициальные',
                      sales: unofficialSales,
                      emptyText: 'Неофициальных чеков нет',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Widget _salesJournalSection({
    required String title,
    required List<SaleEntryView> sales,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${sales.length})',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
        const SizedBox(height: 6),
        if (sales.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              emptyText,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          )
        else
          ...sales.take(10).map(_salesJournalTile),
      ],
    );
  }

  Widget _salesJournalTile(SaleEntryView sale) {
    final dt = sale.createdAt;
    final shop = sale.shopName.isEmpty ? 'Без магазина' : sale.shopName.trim();
    final shopLabel = shop.isEmpty ? 'Без магазина' : shop;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(_formatMoney(sale.amount)),
      subtitle: Text(
        '${dt == null ? '-' : dateTimeFormat('d/M H:mm', dt)} • $shopLabel',
      ),
    );
  }
}

class _CashierRow {
  final String name;
  String key = '';
  double sales = 0;
  double cogs = 0;
  int transactions = 0;
  double plan = 0;
  final Set<String> shops = <String>{};

  _CashierRow({required this.name, this.plan = 0});
}

class _CashierShopRow {
  final String cashierName;
  final String shopName;
  double sales = 0;
  double cogs = 0;
  int transactions = 0;
  double plan = 0;

  _CashierShopRow({
    required this.cashierName,
    required this.shopName,
    this.plan = 0,
  });
}

class _CashRegisterRow {
  final String name;
  double sales = 0;
  double cogs = 0;
  int transactions = 0;

  _CashRegisterRow({
    required this.name,
  });
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
            positiveColor: const Color(0xFF1F2A37),
          ),
        ),
      ),
    );
  }
}
