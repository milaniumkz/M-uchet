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
import '/custom_code/widgets/editing_helper.dart';
import '/utils/country_profile.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/effective_company_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/security_hash.dart';
import '/utils/sales_ledger_support.dart';
import '/utils/sales_profit_breakdown_support.dart';
import '/utils/warehouse_scope_support.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class SalesCashiersWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesCashiersWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesCashiersWidget> createState() => _SalesCashiersWidgetState();
}

class _SalesCashiersWidgetState extends State<SalesCashiersWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  String _companyId = '';
  List<Map<String, dynamic>> _cashierDocs = [];
  List<CashierEntryView> _cashiers = [];
  List<SaleEntryView> _sales = [];
  Map<String, double> _cogsBySaleId = {};
  String _currencyCode = 'KZT';

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDarkTheme ? const Color(0xFF131A26) : const Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _cashierDocs = [];
          _cashiers = [];
          _sales = [];
        });
        return;
      }
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final results = await Future.wait([
        _firestore
            .collection('cashiers')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('sales')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('tranzaction')
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
      final cashiersSnap = results[0];
      final salesSnap = results[1];
      final txSnap = results[2];
      final salesItemsSnap = results[3];
      final legacyCogsSnap = results[4];
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
        _companyId = effectiveCompanyId;
        final userData = currentUserDocument?.snapshotData;
        _cashierDocs = filterRowsByUserShopScope(
          userData: userData,
          rows: cashiersSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _cashiers = _cashierDocs.map(CashierEntryView.fromMap).toList();
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
      debugPrint('Error loading cashiers: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  Map<String, _CashierStats> get _statsByCashier {
    final map = <String, _CashierStats>{};
    for (final sale in _sales) {
      final id = sale.cashierId;
      final name = sale.cashierName;
      final key = id.isNotEmpty ? id : name;
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => _CashierStats());
      map[key]!.orders += 1;
      map[key]!.revenue += sale.amount;
      map[key]!.cogs += _cogsBySaleId[sale.id] ?? 0;
    }
    return map;
  }

  int get _totalCashiers => _cashiers.length;
  int get _activeCashiers => _cashiers.where((c) => c.isActive).length;
  double get _totalRevenue => _sales.fold(0, (s, i) => s + i.amount);
  double get _totalCogs =>
      _sales.fold(0, (s, i) => s + (_cogsBySaleId[i.id] ?? 0));
  double get _grossProfit => _totalRevenue - _totalCogs;
  int get _totalOrders => _sales.length;
  double get _avgCheck => _totalOrders == 0 ? 0 : _totalRevenue / _totalOrders;

  List<CashierEntryView> get _filteredCashiers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _cashiers;
    return _cashiers.where((cashier) {
      return cashier.name.toLowerCase().contains(query) ||
          cashier.shopName.toLowerCase().contains(query) ||
          cashier.position.toLowerCase().contains(query);
    }).toList();
  }

  double? _cashierRating(CashierEntryView cashier) {
    final raw = _cashierDocs.firstWhere(
      (item) => (item['id'] ?? '').toString() == cashier.id,
      orElse: () => const <String, dynamic>{},
    );
    final value = raw['rating'] ?? raw['rate'] ?? raw['cashier_rating'];
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().replaceAll(',', '.'));
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _CashierDialog(
        companyId: _companyId,
        onSaved: _loadData,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    if (!EditingHelper.guardEdit(context)) return;
    showDialog(
      context: context,
      builder: (context) => _CashierDialog(
        companyId: _companyId,
        onSaved: _loadData,
        item: item,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    if (!EditingHelper.guardEdit(context)) return;
    final name = (item['name'] ?? '').toString().trim();
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить кассира?'),
            content: Text(
              name.isEmpty
                  ? 'Кассир будет удален без возможности восстановления.'
                  : 'Удалить "$name"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    try {
      await _firestore.collection('cashiers').doc(item['id']).delete();
      await _firestore.collection('activity_log').add({
        'idCompany': _companyId,
        'user_id': _auth.currentUser?.uid ?? '',
        'user_name': currentUserDocument?.displayName ??
            _auth.currentUser?.displayName ??
            _auth.currentUser?.email ??
            '',
        'action': 'delete',
        'entity': 'cashier',
        'entity_id': item['id'],
        'entity_name': item['name'],
        'created_at': FieldValue.serverTimestamp(),
      });
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('cashiers', _companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('activity_log', _companyId);
      await _loadData();
    } catch (e) {
      debugPrint('Error deleting cashier: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.cashiers')) {
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
                  child: const Icon(Icons.people_outline,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Кассиры',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Сотрудники кассы и их показатели',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Добавить кассира'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
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
                  title: 'Кассиры',
                  value: _totalCashiers.toString(),
                  icon: Icons.people,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                _statCard(
                  title: 'Активные',
                  value: _activeCashiers.toString(),
                  icon: Icons.verified_user_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                _statCard(
                  title: 'Выручка',
                  value: _formatMoney(_totalRevenue),
                  icon: Icons.attach_money,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
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
                  title: 'Средний чек',
                  value: _formatMoney(_avgCheck),
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
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Список кассиров',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Поиск по наименованию',
                              border: InputBorder.none,
                              icon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _filteredCashiers.isEmpty
                              ? Center(
                                  child: Text(
                                    'Кассиры не найдены',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _filteredCashiers.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_filteredCashiers[index]);
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
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return SizedBox(
      width: 260,
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
        _HeaderCell('PIN', flex: 1),
        _HeaderCell('Магазин', flex: 2),
        _HeaderCell('Должность', flex: 2),
        _HeaderCell('Телефон', flex: 2),
        _HeaderCell('Оклад', flex: 1),
        _HeaderCell('Комиссия', flex: 1),
        _HeaderCell('Статус', flex: 1),
        _HeaderCell('Выручка', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Действия', flex: 1),
      ],
    );
  }

  Widget _tableRow(CashierEntryView cashier) {
    final stats = _statsByCashier[cashier.id] ?? _statsByCashier[cashier.name];
    final revenue = stats?.revenue ?? 0;
    final cogs = stats?.cogs ?? 0;
    final grossProfit = revenue - cogs;
    final rating = _cashierRating(cashier);
    final rawCashier = _cashierDocs.firstWhere(
      (item) => (item['id'] ?? '').toString() == cashier.id,
      orElse: () => <String, dynamic>{},
    );

    return LiveDiffHighlight(
      timestamp: cashier.updatedAt ?? cashier.createdAt,
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
              cashier.name.isEmpty
                  ? '-'
                  : rating == null || rating <= 0
                      ? cashier.name
                      : '${cashier.name} ★${rating.toStringAsFixed(1)}',
              flex: 3,
              bold: true,
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  _Cell(
                    cashier.hasPin ? 'Настроен' : 'Не задан',
                    flex: 1,
                    color: cashier.hasPin
                        ? FlutterFlowTheme.of(context).success
                        : FlutterFlowTheme.of(context).secondaryText,
                  ),
                ],
              ),
            ),
            _Cell(cashier.shopName.isEmpty ? '-' : cashier.shopName, flex: 2),
            _Cell(cashier.position.isEmpty ? '-' : cashier.position, flex: 2),
            _Cell(cashier.phone.isEmpty ? '-' : cashier.phone, flex: 2),
            _Cell(_formatMoney(cashier.salary),
                flex: 1, amount: cashier.salary),
            _Cell('${cashier.commissionPercent.toStringAsFixed(0)}%', flex: 1),
            _Cell(
              cashier.isActive ? 'Активен' : 'Неактивен',
              flex: 1,
              color: cashier.isActive
                  ? FlutterFlowTheme.of(context).success
                  : Colors.red,
            ),
            _Cell(_formatMoney(revenue), flex: 2, amount: revenue),
            _Cell(_formatMoney(cogs), flex: 2, amount: cogs),
            _Cell(_formatMoney(grossProfit), flex: 2, amount: grossProfit),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: rawCashier.isEmpty
                          ? null
                          : () => _showEditDialog(rawCashier),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: rawCashier.isEmpty
                          ? null
                          : () => _confirmDelete(rawCashier),
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashierStats {
  int orders = 0;
  double revenue = 0;
  double cogs = 0;
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
  final Color? color;
  final num? amount;

  const _Cell(this.text,
      {required this.flex, this.bold = false, this.color, this.amount});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: color ??
              amountTextColor(
                context,
                amount,
                positiveColor: FlutterFlowTheme.of(context).primaryText,
              ),
        ),
      ),
    );
  }
}

class _CashierDialog extends StatefulWidget {
  final String companyId;
  final Map<String, dynamic>? item;
  final VoidCallback onSaved;

  const _CashierDialog({
    required this.companyId,
    required this.onSaved,
    this.item,
  });

  @override
  State<_CashierDialog> createState() => _CashierDialogState();
}

class _CashierDialogState extends State<_CashierDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _pin;
  late final TextEditingController _position;
  late final TextEditingController _salary;
  late final TextEditingController _commission;
  bool _isActive = true;
  bool _canDiscount = false;
  bool _canReturn = false;
  bool _canOpenDrawer = false;
  late final TextEditingController _maxDiscount;
  bool _loadingShops = false;
  List<ShopEntryView> _shops = [];
  String? _selectedShopId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name =
        TextEditingController(text: (widget.item?['name'] ?? '').toString());
    _phone =
        TextEditingController(text: (widget.item?['phone'] ?? '').toString());
    _pin = TextEditingController();
    _position = TextEditingController(
        text: (widget.item?['position'] ?? 'Кассир').toString());
    _salary =
        TextEditingController(text: (widget.item?['salary'] ?? 0).toString());
    _commission = TextEditingController(
        text: (widget.item?['commissionPercent'] ?? 0).toString());
    _selectedShopId = (widget.item?['shop_id'] ?? '').toString().trim();
    _isActive = (widget.item?['status'] ?? 'active').toString().toLowerCase() ==
        'active';
    final permissions =
        (widget.item?['permissions'] as Map?)?.cast<String, dynamic>() ?? {};
    _canDiscount = (permissions['canDiscount'] ?? false) == true;
    _canReturn = (permissions['canReturn'] ?? false) == true;
    _canOpenDrawer = (permissions['canOpenDrawer'] ?? false) == true;
    _maxDiscount = TextEditingController(
        text: (permissions['maxDiscount'] ?? 0).toString());
    _loadShops();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    _position.dispose();
    _salary.dispose();
    _commission.dispose();
    _maxDiscount.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() => _loadingShops = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
      final effectiveCompanyId = widget.companyId.isNotEmpty
          ? widget.companyId
          : rawCompanyId.isNotEmpty
              ? rawCompanyId
              : user.uid;

      final snap = await _firestore
          .collection('shops')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final docs = snap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return <String, dynamic>{'id': d.id, ...data};
      }).toList()
        ..sort((a, b) => (a['name'] ?? '').toString().compareTo(
              (b['name'] ?? '').toString(),
            ));
      final shops = docs.map(ShopEntryView.fromMap).toList();

      if ((_selectedShopId ?? '').isEmpty) {
        final currentName = (widget.item?['shop_name'] ?? '').toString().trim();
        if (currentName.isNotEmpty) {
          for (final s in shops) {
            if (s.name.trim() == currentName) {
              _selectedShopId = s.id;
              break;
            }
          }
        }
      }

      setState(() => _shops = shops);
    } catch (e) {
      debugPrint('Error loading shops for cashier: $e');
    } finally {
      setState(() => _loadingShops = false);
    }
  }

  String _selectedShopName() {
    final selectedId = (_selectedShopId ?? '').trim();
    if (selectedId.isNotEmpty) {
      for (final s in _shops) {
        if (s.id == selectedId) {
          final name = s.name.trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    return (widget.item?['shop_name'] ?? '').toString().trim();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.item != null && !EditingHelper.guardEdit(context)) return;
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');
      final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
      final effectiveCompanyId = widget.companyId.isNotEmpty
          ? widget.companyId
          : rawCompanyId.isNotEmpty
              ? rawCompanyId
              : user.uid;

      final enteredPin = _pin.text.trim();
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'position': _position.text.trim(),
        'salary': double.tryParse(_salary.text.replaceAll(',', '.')) ?? 0,
        'commissionPercent':
            double.tryParse(_commission.text.replaceAll(',', '.')) ?? 0,
        'shop_id': (_selectedShopId ?? '').trim(),
        'shop_name': _selectedShopName(),
        'status': _isActive ? 'active' : 'inactive',
        'permissions': {
          'canDiscount': _canDiscount,
          'canReturn': _canReturn,
          'canOpenDrawer': _canOpenDrawer,
          'maxDiscount':
              double.tryParse(_maxDiscount.text.replaceAll(',', '.')) ?? 0,
        },
        'user_id': user.uid,
        'idCompany': effectiveCompanyId,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (enteredPin.isNotEmpty) {
        data.addAll({
          'pin_hash': hashSensitiveValue(enteredPin),
          'pin_migrated_at': FieldValue.serverTimestamp(),
          'pin': FieldValue.delete(),
        });
      }

      if (widget.item == null) {
        final docRef = await _firestore.collection('cashiers').add({
          ...data,
          'created_at': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('activity_log').add({
          'idCompany': effectiveCompanyId,
          'user_id': user.uid,
          'user_name': currentUserDocument?.displayName ??
              user.displayName ??
              user.email ??
              '',
          'action': 'create',
          'entity': 'cashier',
          'entity_id': docRef.id,
          'entity_name': _name.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore
            .collection('cashiers')
            .doc(widget.item!['id'])
            .update(data);
        await _firestore.collection('activity_log').add({
          'idCompany': effectiveCompanyId,
          'user_id': user.uid,
          'user_name': currentUserDocument?.displayName ??
              user.displayName ??
              user.email ??
              '',
          'action': 'update',
          'entity': 'cashier',
          'entity_id': widget.item!['id'],
          'entity_name': _name.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('cashiers', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('activity_log', effectiveCompanyId);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error saving cashier: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit ? 'Редактировать кассира' : 'Добавить кассира',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _field(_name, 'Имя', required: true),
                _field(
                  _pin,
                  isEdit ? 'Новый PIN' : 'PIN',
                  required: !isEdit,
                  helperText:
                      isEdit ? 'Оставьте пустым, чтобы не менять PIN' : null,
                ),
                _field(_phone, 'Телефон'),
                _field(_position, 'Должность'),
                _field(_salary, 'Оклад', number: true),
                _field(_commission, 'Комиссия, %', number: true),
                _shopPicker(),
                SwitchListTile(
                  title: const Text('Активен'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Права доступа',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                CheckboxListTile(
                  title: const Text('Скидки'),
                  value: _canDiscount,
                  onChanged: (v) => setState(() => _canDiscount = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Возвраты'),
                  value: _canReturn,
                  onChanged: (v) => setState(() => _canReturn = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Открытие кассы'),
                  value: _canOpenDrawer,
                  onChanged: (v) => setState(() => _canOpenDrawer = v ?? false),
                ),
                _field(_maxDiscount, 'Макс. скидка, %', number: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    bool number = false,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (required && (v == null || v.isEmpty)) return 'Обязательное поле';
          if (!number && label.contains('PIN') && v != null && v.isNotEmpty) {
            final normalized = v.trim();
            if (!RegExp(r'^\d{4,8}$').hasMatch(normalized)) {
              return 'PIN должен быть из 4-8 цифр';
            }
          }
          if (number &&
              v != null &&
              v.isNotEmpty &&
              double.tryParse(v.replaceAll(',', '.')) == null) {
            return 'Введите число';
          }
          return null;
        },
      ),
    );
  }

  Widget _shopPicker() {
    if (_loadingShops) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    final selectedId = (_selectedShopId ?? '').trim();
    final hasSelected =
        selectedId.isNotEmpty && _shops.any((s) => s.id == selectedId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: hasSelected ? selectedId : null,
        decoration: const InputDecoration(
          labelText: 'Магазин',
          border: OutlineInputBorder(),
        ),
        items: _shops
            .map(
              (s) => DropdownMenuItem<String>(
                value: s.id,
                child: Text(s.name.isEmpty ? 'Без названия' : s.name),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _selectedShopId = value),
        validator: (value) => (value == null || value.trim().isEmpty)
            ? 'Выберите магазин из списка'
            : null,
      ),
    );
  }
}
