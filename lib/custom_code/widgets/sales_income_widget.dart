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
import '/utils/effective_company_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/sales_ledger_support.dart';
import '/utils/sales_profit_breakdown_support.dart';
import '/utils/warehouse_scope_support.dart';

class SalesIncomeWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesIncomeWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesIncomeWidget> createState() => _SalesIncomeWidgetState();
}

class _SalesIncomeWidgetState extends State<SalesIncomeWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<SaleEntryView> _sales = [];
  Map<String, double> _cogsBySaleId = {};
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
          .orderBy('created_at', descending: true)
          .limit(200)
          .getCached();
      final txSnap = await _firestore
          .collection('tranzaction')
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
        ).map(SaleEntryView.fromMap).toList();
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
        _cogsBySaleId = buildSaleCogsBySaleId(
          cogsEntries: cogsItems,
        );
      });
    } catch (e) {
      debugPrint('Error loading sales income: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  double get _total => _sales.fold(0, (s, i) => s + i.amount);
  double get _totalCogs =>
      _sales.fold(0, (s, i) => s + (_cogsBySaleId[i.id] ?? 0));
  double get _grossProfit => _total - _totalCogs;

  double get _monthTotal {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return _sales.fold(0, (s, i) {
      final dt = i.createdAt;
      if (dt != null &&
          dt.isAfter(start.subtract(const Duration(seconds: 1)))) {
        return s + i.amount;
      }
      return s;
    });
  }

  int get _salesCount => _sales.length;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
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
                    color: theme.accent1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.payments_outlined, color: theme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Доходы магазинов',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Выручка и список продаж',
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
            child: Row(
              children: [
                _statCard(
                  title: 'Выручка',
                  value: _formatMoney(_total),
                  amount: _total,
                  icon: Icons.attach_money,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'За месяц',
                  value: _formatMoney(_monthTotal),
                  amount: _monthTotal,
                  icon: Icons.calendar_month_outlined,
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
                  title: 'Валовая',
                  value: _formatMoney(_grossProfit),
                  amount: _grossProfit,
                  icon: Icons.stacked_line_chart,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Продажи',
                  value: _salesCount.toString(),
                  icon: Icons.receipt_long,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
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
                        Text(
                          'Последние продажи',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _sales.isEmpty
                              ? Center(
                                  child: Text(
                                    'Продаж не найдено',
                                    style: TextStyle(color: _mutedText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _sales.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_sales[index]);
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
    final theme = FlutterFlowTheme.of(context);
    return Expanded(
      child: Container(
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
                      style: TextStyle(fontSize: 12, color: _mutedText)),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: amountTextColor(
                        context,
                        amount,
                        positiveColor: theme.primaryText,
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
        _HeaderCell('Дата', flex: 2),
        _HeaderCell('Магазин', flex: 3),
        _HeaderCell('Клиент', flex: 3),
        _HeaderCell('Сумма', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
      ],
    );
  }

  Widget _tableRow(SaleEntryView item) {
    final dt = item.createdAt;
    final dateText = dt == null
        ? '-'
        : dateTimeFormat(
            'dd.MM.yyyy HH:mm',
            dt,
            locale: FFLocalizations.of(context).languageCode,
          );
    final shop = item.shopName;
    final client = item.clientName;
    final amount = item.amount;
    final cogs = _cogsBySaleId[item.id] ?? 0;
    final grossProfit = amount - cogs;
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
          _Cell(dateText, flex: 2),
          _Cell(shop.isEmpty ? '-' : shop, flex: 3, bold: true),
          _Cell(client.isEmpty ? '-' : client, flex: 3),
          _Cell(_formatMoney(amount), flex: 2, amount: amount),
          _Cell(_formatMoney(cogs), flex: 2, amount: cogs),
          _Cell(_formatMoney(grossProfit), flex: 2, amount: grossProfit),
        ],
      ),
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
