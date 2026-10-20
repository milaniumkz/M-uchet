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
import '/utils/effective_company_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/sales_profit_breakdown_support.dart';
import '/utils/sales_ledger_support.dart';

class SalesProfitCashierWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesProfitCashierWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesProfitCashierWidget> createState() =>
      _SalesProfitCashierWidgetState();
}

class _SalesProfitCashierWidgetState extends State<SalesProfitCashierWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _salesItems = [];
  List<Map<String, dynamic>> _cogsItems = [];
  String _currencyCode = 'KZT';

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

      final salesSnap = await _firestore
          .collection('sales')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final txSnap = await _firestore
          .collection('tranzaction')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final salesItemsSnap = await _firestore
          .collection('sales_items')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final cogsEntrySnap = await _firestore
          .collection('cogs_register')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final legacyCogsSnap = await _firestore
          .collection('sale_item_cogs')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
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
        _salesItems = salesItemsSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _cogsItems = resolveSalesCogsItems(
          cogsEntries: cogsEntrySnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }),
          legacyCogsItems: legacyCogsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }),
        );
        _sales = buildSalesLedger(sales: sales, transactions: transactions);
      });
    } catch (e) {
      debugPrint('Error loading cashier profit: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  double _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  List<_CashierRow> get _rows {
    return buildCashierProfitRows(
      salesLedger: _sales,
      salesItems: _salesItems,
    ).map((row) {
      return _CashierRow(
        name: (row['cashier_name'] ?? '').toString(),
        orders: (row['orders'] as num?)?.toInt() ?? 0,
        revenue: _toNum(row['revenue']),
        cogs: _toNum(row['cogs']),
        grossProfit: _toNum(row['gross_profit']),
      );
    }).toList();
  }

  double get _totalRevenue => _sales.fold(0, (s, i) => s + _toNum(i['amount']));
  double get _totalCogs => _rows.fold(0, (total, row) => total + row.cogs);
  double get _totalGrossProfit =>
      _rows.fold(0, (total, row) => total + row.grossProfit);
  int get _totalOrders => _sales.length;

  Set<String> _saleIdsForCashier(String name) {
    final normalized = name.trim().toLowerCase();
    return _sales
        .where((sale) =>
            (sale['cashier_name'] ?? '').toString().trim().toLowerCase() ==
            normalized)
        .map((sale) => (sale['sale_id'] ?? sale['id'] ?? '').toString().trim())
        .where((saleId) => saleId.isNotEmpty)
        .toSet();
  }

  Future<void> _showCashierCogsDialog(_CashierRow row) async {
    final rows = buildSaleItemCogsReportRowsForSaleIds(
      cogsItems: _cogsItems,
      saleIds: _saleIdsForCashier(row.name),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('COGS: ${row.name}'),
        content: SizedBox(
          width: 880,
          child: rows.isEmpty
              ? const Text('Детализация COGS отсутствует')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = rows[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        item.productName.isEmpty
                            ? 'Без названия'
                            : item.productName,
                      ),
                      subtitle: Text(
                        '${item.warehouseName.isEmpty ? '—' : item.warehouseName} · ${item.costingMethod} · ${item.batchBreakdown.join(', ')}',
                      ),
                      trailing: Text(_formatMoney(item.totalCost)),
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

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.view')) {
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
                    color: FlutterFlowTheme.of(context).accent1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Прибыль кассиров',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Выручка, COGS и валовая прибыль по кассирам',
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
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(
                  title: 'Выручка',
                  value: _formatMoney(_totalRevenue),
                  amount: _totalRevenue,
                  icon: Icons.attach_money,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Чеки',
                  value: _totalOrders.toString(),
                  icon: Icons.receipt_long,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Средний чек',
                  value: _formatMoney(
                      _totalOrders == 0 ? 0 : _totalRevenue / _totalOrders),
                  amount: _totalOrders == 0 ? 0 : _totalRevenue / _totalOrders,
                  icon: Icons.trending_up,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'COGS',
                  value: _formatMoney(_totalCogs),
                  amount: _totalCogs,
                  icon: Icons.inventory_2_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Валовая прибыль',
                  value: _formatMoney(_totalGrossProfit),
                  amount: _totalGrossProfit,
                  icon: Icons.show_chart,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
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
                        const Text(
                          'Рейтинг кассиров',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _rows.isEmpty
                              ? Center(
                                  child: Text(
                                    'Данные не найдены',
                                    style: TextStyle(color: _mutedText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _rows.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_rows[index]);
                                  },
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
    num? amount,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return SizedBox(
      width: 220,
      child: Container(
        width: 220,
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
                  Text(title,
                      style: TextStyle(
                        fontSize: 12,
                        color: _mutedText,
                      )),
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

  Widget _tableHeader() {
    return const Row(
      children: [
        _HeaderCell('Кассир', flex: 3),
        _HeaderCell('Чеки', flex: 1),
        _HeaderCell('Выручка', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Средний чек', flex: 2),
        _HeaderCell('Детали', flex: 1),
      ],
    );
  }

  Widget _tableRow(_CashierRow row) {
    final avg = row.orders == 0 ? 0.0 : row.revenue / row.orders;
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
          _Cell(row.name, flex: 3, bold: true),
          _Cell(row.orders.toString(), flex: 1),
          _Cell(_formatMoney(row.revenue), flex: 2, amount: row.revenue),
          _Cell(_formatMoney(row.cogs), flex: 2, amount: row.cogs),
          _Cell(
            _formatMoney(row.grossProfit),
            flex: 2,
            amount: row.grossProfit,
          ),
          _Cell(_formatMoney(avg), flex: 2, amount: avg),
          Expanded(
            flex: 1,
            child: IconButton(
              onPressed: () => _showCashierCogsDialog(row),
              icon: const Icon(Icons.receipt_long, size: 18),
              tooltip: 'COGS детализация',
            ),
          ),
        ],
      ),
    );
  }
}

class _CashierRow {
  final String name;
  final int orders;
  final double revenue;
  final double cogs;
  final double grossProfit;

  _CashierRow({
    required this.name,
    required this.orders,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
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
            fontSize: 12,
            color: FlutterFlowTheme.of(context).secondaryText,
          )),
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
