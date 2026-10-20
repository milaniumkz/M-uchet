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
import '/utils/sales_ledger_support.dart';
import '/utils/effective_company_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/shop_finance_ledger_support.dart';
import '/utils/warehouse_scope_support.dart';

class SalesProfitShopWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesProfitShopWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesProfitShopWidget> createState() => _SalesProfitShopWidgetState();
}

class _SalesProfitShopWidgetState extends State<SalesProfitShopWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _cogsItems = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _shops = [];
  List<Map<String, dynamic>> _registers = [];
  List<Map<String, dynamic>> _incassations = [];
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
          _sales = [];
          _expenses = [];
          _shops = [];
        });
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
      final expSnap = await _firestore
          .collection('shop_expenses')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final salesItemsSnap = await _firestore
          .collection('cogs_register')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final legacyCogsSnap = await _firestore
          .collection('sale_item_cogs')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final shopsSnap = await _firestore
          .collection('shops')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final registersSnap = await _firestore
          .collection('cash_registers')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final incassationsSnap = await _firestore
          .collection('cash_register_incassations')
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
        _sales = filterRowsByUserShopScope(
          userData: userData,
          rows: buildSalesLedger(sales: sales, transactions: transactions),
        );
        _cogsItems = resolveSalesCogsItems(
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
        _expenses = filterRowsByUserShopScope(
          userData: userData,
          rows: expSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _shops = filterRowsByUserShopScope(
          userData: userData,
          rows: shopsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        final registers = registersSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _registers = filterRowsByUserShopScope(
          userData: userData,
          rows: registers,
        );
        _incassations = filterIncassationsByUserShopScope(
          userData: userData,
          cashRegisters: registers,
          incassations: incassationsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
      });
    } catch (e) {
      debugPrint('Error loading shop profit: $e');
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

  Map<String, dynamic> get _shopLedger => buildShopFinanceLedger(
        shops: _shops,
        salesLedger: _sales,
        cogsEntries: _cogsItems,
        shopExpenses: _expenses,
        cashRegisters: _registers,
        cashRegisterIncassations: _incassations,
      );

  Map<String, dynamic> get _summary =>
      Map<String, dynamic>.from(_shopLedger['summary'] as Map? ?? const {});

  double get _totalRevenue => _toNum(_summary['revenue']);
  double get _totalCogs => _toNum(_summary['cogs']);
  double get _totalGrossProfit => _toNum(_summary['gross_profit']);
  double get _totalExpenses => _toNum(_summary['expenses']);
  double get _totalProfit => _toNum(_summary['profit']);

  List<_ProfitRow> get _rows {
    final rows = List<Map<String, dynamic>>.from(
        _shopLedger['rows'] as List? ?? const []);
    return rows
        .map(
          (row) => _ProfitRow(
            name: (row['shop_name'] ?? '').toString(),
            revenue: _toNum(row['revenue']),
            cogs: _toNum(row['cogs']),
            grossProfit: _toNum(row['gross_profit']),
            expenses: _toNum(row['expenses']),
            cashTurnover: _toNum(row['cash_turnover']),
            reconciliationGap: _toNum(row['reconciliation_gap']),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.view')) {
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
                  child: const Icon(Icons.insights_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Прибыль по магазинам',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Выручка, COGS и net profit по каждой точке',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
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
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Расходы',
                  value: _formatMoney(_totalExpenses),
                  amount: _totalExpenses,
                  icon: Icons.trending_down,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Прибыль',
                  value: _formatMoney(_totalProfit),
                  amount: _totalProfit,
                  icon: Icons.trending_up,
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
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Рентабельность по магазинам',
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
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
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

  Widget _tableHeader() {
    return const Row(
      children: [
        _HeaderCell('Магазин', flex: 3),
        _HeaderCell('Выручка', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Расходы', flex: 2),
        _HeaderCell('Net', flex: 2),
        _HeaderCell('Кассы', flex: 2),
        _HeaderCell('Сверка', flex: 1),
      ],
    );
  }

  Widget _tableRow(_ProfitRow row) {
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
          _Cell(_formatMoney(row.revenue), flex: 2, amount: row.revenue),
          _Cell(_formatMoney(row.cogs), flex: 2, amount: row.cogs),
          _Cell(
            _formatMoney(row.grossProfit),
            flex: 2,
            amount: row.grossProfit,
          ),
          _Cell(_formatMoney(row.expenses), flex: 2, amount: row.expenses),
          _Cell(_formatMoney(row.profit), flex: 2, amount: row.profit),
          _Cell(_formatMoney(row.cashTurnover),
              flex: 2, amount: row.cashTurnover),
          _Cell(_formatMoney(row.reconciliationGap),
              flex: 1, amount: row.reconciliationGap),
        ],
      ),
    );
  }
}

class _ProfitRow {
  final String name;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double cashTurnover;
  final double reconciliationGap;
  double get profit => grossProfit - expenses;

  _ProfitRow({
    required this.name,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.cashTurnover,
    required this.reconciliationGap,
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
            positiveColor: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
      ),
    );
  }
}
