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
import '/utils/company_lock.dart';
import '/utils/country_profile.dart';
import '/utils/sales_ledger_support.dart';
import '/utils/effective_company_support.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/shop_finance_ledger_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/warehouse_scope_support.dart';
import '/custom_code/widgets/editing_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class SalesShopsWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesShopsWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesShopsWidget> createState() => _SalesShopsWidgetState();
}

class _SalesShopsWidgetState extends State<SalesShopsWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  String _companyId = '';
  List<Map<String, dynamic>> _shopDocs = [];
  List<ShopEntryView> _shops = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _cogsItems = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _registers = [];
  List<Map<String, dynamic>> _incassations = [];
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
        setState(() {
          _shopDocs = [];
          _shops = [];
          _sales = [];
        });
        return;
      }

      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final results = await Future.wait<dynamic>([
        _firestore
            .collection('shops')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('sales')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('tranzaction')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('shop_expenses')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('cogs_register')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('sale_item_cogs')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('cash_registers')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('cash_register_incassations')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
      ]);
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      final shopsSnap = results[0] as QuerySnapshot;
      final salesSnap = results[1] as QuerySnapshot;
      final txSnap = results[2] as QuerySnapshot;
      final expensesSnap = results[3] as QuerySnapshot;
      final salesItemsSnap = results[4] as QuerySnapshot;
      final legacyCogsSnap = results[5] as QuerySnapshot;
      final registersSnap = results[6] as QuerySnapshot;
      final incassationsSnap = results[7] as QuerySnapshot;

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _companyId = effectiveCompanyId;
        final userData = currentUserDocument?.snapshotData;
        _shopDocs = filterRowsByUserShopScope(
          userData: userData,
          rows: shopsSnap.docs.map((d) {
            final raw = d.data();
            final data = raw is Map<String, dynamic>
                ? raw
                : Map<String, dynamic>.from(raw as Map);
            return {'id': d.id, ...data};
          }).toList(),
        );
        _shops = _shopDocs.map(ShopEntryView.fromMap).toList();
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
          rows: expensesSnap.docs.map((d) {
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
      debugPrint('Error loading shops: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  Map<String, dynamic> get _shopLedger => buildShopFinanceLedger(
        shops: _shopDocs,
        salesLedger: _sales,
        cogsEntries: _cogsItems,
        shopExpenses: _expenses,
        cashRegisters: _registers,
        cashRegisterIncassations: _incassations,
      );

  ShopFinanceLedgerEntryView get _ledgerSummary =>
      ShopFinanceLedgerEntryView.fromMap(
        Map<String, dynamic>.from(_shopLedger['summary'] as Map? ?? const {}),
      );

  Map<String, ShopFinanceLedgerEntryView> get _shopLedgerByKey {
    final rows = List<Map<String, dynamic>>.from(
        _shopLedger['rows'] as List? ?? const []);
    final views = rows.map(ShopFinanceLedgerEntryView.fromMap).toList();
    return {
      for (final row in views) row.key: row,
    };
  }

  double get _totalRevenue => _ledgerSummary.revenue;
  double get _totalCogs => _ledgerSummary.cogs;
  double get _grossProfit => _ledgerSummary.grossProfit;
  int get _activeStores => _shops.where((s) => s.isActive).length;
  double get _avgRevenue => _shops.isEmpty ? 0 : _totalRevenue / _shops.length;

  Future<bool> _ensureUnlocked() async {
    final companyId = _companyId.isNotEmpty
        ? _companyId
        : resolveEffectiveCompanyId(
            userData: currentUserDocument?.snapshotData,
            fallbackUserId: _auth.currentUser?.uid ?? '',
          );
    if (companyId.isEmpty) return true;
    final locked = await CompanyLock.isLocked(companyId);
    if (locked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Редактирование отключено после завершения первого входа.'),
        ),
      );
    }
    return !locked;
  }

  Future<void> _showAddDialog() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _ShopDialog(
        companyId: _companyId,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    if (!EditingHelper.guardEdit(context)) return;
    showDialog(
      context: context,
      builder: (context) => _ShopDialog(
        companyId: _companyId,
        onSaved: _loadData,
        item: item,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    if (!EditingHelper.guardEdit(context)) return;
    final name = (item['name'] ?? '').toString().trim();
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить магазин?'),
            content: Text(
              name.isEmpty
                  ? 'Магазин будет удален без возможности восстановления.'
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
      await _firestore.collection('shops').doc(item['id']).delete();
      await _firestore.collection('activity_log').add({
        'idCompany': _companyId,
        'user_id': _auth.currentUser?.uid ?? '',
        'user_name': currentUserDocument?.displayName ??
            _auth.currentUser?.displayName ??
            _auth.currentUser?.email ??
            '',
        'action': 'delete',
        'entity': 'shop',
        'entity_id': item['id'],
        'entity_name': item['name'],
        'created_at': FieldValue.serverTimestamp(),
      });
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('shops', _companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('activity_log', _companyId);
      await _loadData();
    } catch (e) {
      debugPrint('Error deleting shop: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.shops')) {
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
                  child: const Icon(Icons.storefront_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Магазины',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Управление торговыми точками и выручкой',
                        style: TextStyle(
                          fontSize: 13,
                          color: _mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Добавить магазин'),
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
                  title: 'Всего магазинов',
                  value: _shops.length.toString(),
                  icon: Icons.storefront,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: const Color(0xFF0284C7),
                ),
                _statCard(
                  title: 'Активные',
                  value: _activeStores.toString(),
                  icon: Icons.verified_user_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
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
                  title: 'Валовая прибыль',
                  value: _formatMoney(_grossProfit),
                  icon: Icons.stacked_line_chart,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                _statCard(
                  title: 'Средняя выручка',
                  value: _formatMoney(_avgRevenue),
                  icon: Icons.trending_up,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                _statCard(
                  title: 'Общая выручка',
                  value: _formatMoney(_totalRevenue),
                  icon: Icons.attach_money,
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
                      color: _panelSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Список магазинов',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _shops.isEmpty
                              ? Center(
                                  child: Text(
                                    'Магазины не найдены',
                                    style: TextStyle(color: _mutedText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _shops.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_shops[index]);
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
        _HeaderCell('Магазин', flex: 3),
        _HeaderCell('Адрес', flex: 3),
        _HeaderCell('Телефон', flex: 2),
        _HeaderCell('Ответственный', flex: 2),
        _HeaderCell('График', flex: 2),
        _HeaderCell('Склад', flex: 2),
        _HeaderCell('Выручка', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('Статус', flex: 1),
        _HeaderCell('Действия', flex: 1),
      ],
    );
  }

  Widget _tableRow(ShopEntryView shop) {
    final financeRow = _shopLedgerByKey['id:${shop.id}'] ??
        _shopLedgerByKey['name:${shop.name.toLowerCase()}'];
    final revenue = financeRow?.revenue ?? 0;
    final cogs = financeRow?.cogs ?? 0;
    final grossProfit = financeRow?.grossProfit ?? (revenue - cogs);
    final rawShop = _shopDocs.firstWhere(
      (item) => (item['id'] ?? '').toString() == shop.id,
      orElse: () => <String, dynamic>{},
    );

    return LiveDiffHighlight(
      timestamp: shop.updatedAt ?? shop.createdAt,
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
            _Cell(shop.name.isEmpty ? '-' : shop.name, flex: 3, bold: true),
            _Cell(shop.address.isEmpty ? '-' : shop.address, flex: 3),
            _Cell(shop.phone.isEmpty ? '-' : shop.phone, flex: 2),
            _Cell(shop.manager.isEmpty ? '-' : shop.manager, flex: 2),
            _Cell(shop.workingHours.isEmpty ? '-' : shop.workingHours, flex: 2),
            _Cell(shop.warehouseName.isEmpty ? '-' : shop.warehouseName,
                flex: 2),
            _Cell(_formatMoney(revenue), flex: 2, amount: revenue),
            _Cell(_formatMoney(cogs), flex: 2, amount: cogs),
            _Cell(_formatMoney(grossProfit), flex: 2, amount: grossProfit),
            _Cell(
              shop.status.toLowerCase() == 'active'
                  ? 'Активен'
                  : shop.status.toLowerCase() == 'closed'
                      ? 'Закрыт'
                      : 'Техн. работы',
              flex: 1,
              color: shop.status.toLowerCase() == 'active'
                  ? FlutterFlowTheme.of(context).success
                  : shop.status.toLowerCase() == 'closed'
                      ? Colors.red
                      : FlutterFlowTheme.of(context).warning,
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: rawShop.isEmpty
                          ? null
                          : () => _showEditDialog(rawShop),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: rawShop.isEmpty
                          ? null
                          : () => _confirmDelete(rawShop),
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

class _ShopDialog extends StatefulWidget {
  final String companyId;
  final Map<String, dynamic>? item;
  final VoidCallback onSaved;

  const _ShopDialog({
    required this.companyId,
    required this.onSaved,
    this.item,
  });

  @override
  State<_ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<_ShopDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _workingHours;
  late final TextEditingController _revenue;
  String _status = 'active';
  bool _saving = false;
  bool _loadingPositions = false;
  List<Map<String, dynamic>> _positions = [];
  String? _selectedPositionId;
  String _legacyManager = '';
  bool _loadingWarehouses = false;
  List<Map<String, dynamic>> _warehouses = [];
  List<String> _selectedWarehouseIds = [];
  List<String> _selectedWarehouseNames = [];
  String? _warehouseError;

  bool _isVirtualGroupWarehouse(Map<String, dynamic> w) {
    return w['isVirtual'] == true;
  }

  bool _isOfficialWarehouseDoc(Map<String, dynamic> w) {
    return warehouseTypeFromData(w).isOfficial;
  }

  String _warehouseDisplayName(Map<String, dynamic> w) {
    final name = (w['name'] ?? '').toString().trim();
    final suffix = _isOfficialWarehouseDoc(w) ? 'офиц.' : 'неофиц.';
    if (name.isEmpty) return suffix;
    return '$name ($suffix)';
  }

  String _selectedWarehouseChipLabel(int index) {
    if (index < 0 || index >= _selectedWarehouseNames.length) return '';
    final id = index < _selectedWarehouseIds.length
        ? _selectedWarehouseIds[index]
        : '';
    if (id.isNotEmpty) {
      for (final w in _warehouses) {
        if ((w['id'] ?? '').toString() == id) {
          return _warehouseDisplayName(w);
        }
      }
    }
    final name = _selectedWarehouseNames[index];
    if (name.isEmpty) return '';
    return name;
  }

  String _resolveCompanyId() {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: _auth.currentUser?.uid ?? '',
    );
  }

  @override
  void initState() {
    super.initState();
    _name =
        TextEditingController(text: (widget.item?['name'] ?? '').toString());
    _address =
        TextEditingController(text: (widget.item?['address'] ?? '').toString());
    _legacyManager = (widget.item?['manager'] ?? '').toString().trim();
    final existingPositionId =
        (widget.item?['manager_position_id'] ?? '').toString().trim();
    _selectedPositionId =
        existingPositionId.isEmpty ? null : existingPositionId;
    _phone =
        TextEditingController(text: (widget.item?['phone'] ?? '').toString());
    _workingHours = TextEditingController(
        text: (widget.item?['workingHours'] ?? '').toString());
    _revenue =
        TextEditingController(text: (widget.item?['revenue'] ?? 0).toString());
    _status = (widget.item?['status'] ?? 'active').toString();
    _selectedWarehouseIds = List<String>.from(
        (widget.item?['warehouseIds'] as List?)?.map((e) => e.toString()) ??
            const []);
    _selectedWarehouseNames = List<String>.from(
        (widget.item?['warehouseNames'] as List?)?.map((e) => e.toString()) ??
            const []);
    final legacyWarehouse =
        (widget.item?['warehouseName'] ?? '').toString().trim();
    if (_selectedWarehouseNames.isEmpty && legacyWarehouse.isNotEmpty) {
      _selectedWarehouseNames = [legacyWarehouse];
    }
    _loadPositions();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _workingHours.dispose();
    _revenue.dispose();
    super.dispose();
  }

  Future<void> _loadPositions() async {
    setState(() => _loadingPositions = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final effectiveCompanyId =
          widget.companyId.isNotEmpty ? widget.companyId : _resolveCompanyId();
      final snap = await _firestore
          .collection('roles')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .get(const GetOptions(source: Source.serverAndCache));
      final docs = snap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, ...data};
      }).where((row) {
        final type = (row['type'] ?? '').toString().toLowerCase().trim();
        return type == 'position';
      }).toList();
      docs.sort((a, b) {
        final an = (a['name'] ?? '').toString();
        final bn = (b['name'] ?? '').toString();
        return an.compareTo(bn);
      });

      String? selected = _selectedPositionId;
      if (selected == null && _legacyManager.isNotEmpty) {
        for (final row in docs) {
          final name = (row['name'] ?? '').toString().trim();
          if (name.toLowerCase() == _legacyManager.toLowerCase()) {
            selected = (row['id'] ?? '').toString();
            break;
          }
        }
      }
      final validSelected =
          docs.any((d) => (d['id'] ?? '').toString() == selected)
              ? selected
              : null;

      setState(() {
        _positions = docs;
        _selectedPositionId = validSelected;
      });
    } catch (e) {
      debugPrint('Error loading positions: $e');
    } finally {
      setState(() => _loadingPositions = false);
    }
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loadingWarehouses = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final effectiveCompanyId =
          widget.companyId.isNotEmpty ? widget.companyId : _resolveCompanyId();
      final snap = await _firestore
          .collection('warehouses')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .get(const GetOptions(source: Source.serverAndCache));
      final docs = snap.docs
          .map((d) {
            final data = d.data();
            return {'id': d.id, ...data};
          })
          .where((w) => !_isVirtualGroupWarehouse(w))
          .toList();
      docs.sort((a, b) {
        final an = (a['name'] ?? '').toString();
        final bn = (b['name'] ?? '').toString();
        return an.compareTo(bn);
      });
      final docsById = <String, Map<String, dynamic>>{
        for (final w in docs) (w['id'] ?? '').toString(): w
      };
      final validIds = _selectedWarehouseIds
          .where((id) => docsById.containsKey(id))
          .toList();
      final names = validIds
          .map((id) => (docsById[id]?['name'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toList();
      setState(() {
        _warehouses = docs;
        _selectedWarehouseIds = validIds;
        _selectedWarehouseNames = names;
      });
    } catch (e) {
      debugPrint('Error loading warehouses: $e');
    } finally {
      setState(() => _loadingWarehouses = false);
    }
  }

  Future<void> _pickWarehouses() async {
    final tempSelected = _selectedWarehouseIds.toSet();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выберите склады',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _warehouses.isEmpty
                          ? const Center(child: Text('Склады не найдены'))
                          : ListView.builder(
                              itemCount: _warehouses.length,
                              itemBuilder: (context, index) {
                                final w = _warehouses[index];
                                final id = (w['id'] ?? '').toString();
                                final label = _warehouseDisplayName(w);
                                final checked = tempSelected.contains(id);
                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(
                                      label.isEmpty ? 'Без названия' : label),
                                  onChanged: (v) {
                                    setModalState(() {
                                      if (v == true) {
                                        tempSelected.add(id);
                                      } else {
                                        tempSelected.remove(id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
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
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Готово'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    final selectedIds = tempSelected.toList();
    final selectedNames = <String>[];
    for (final id in selectedIds) {
      final match = _warehouses.where((w) => (w['id'] ?? '').toString() == id);
      if (match.isEmpty) continue;
      final name = (match.first['name'] ?? '').toString().trim();
      if (name.isNotEmpty) selectedNames.add(name);
    }
    setState(() {
      _selectedWarehouseIds = selectedIds;
      _selectedWarehouseNames = selectedNames;
      _warehouseError = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWarehouseIds.isEmpty && _selectedWarehouseNames.isEmpty) {
      setState(() => _warehouseError = 'Выберите хотя бы один склад');
      return;
    }
    if (widget.item != null && !EditingHelper.guardEdit(context)) return;
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');
      final effectiveCompanyId =
          widget.companyId.isNotEmpty ? widget.companyId : _resolveCompanyId();
      final selectedPosition = _positions.firstWhere(
        (p) => (p['id'] ?? '').toString() == (_selectedPositionId ?? ''),
        orElse: () => const <String, dynamic>{},
      );
      final selectedPositionName =
          (selectedPosition['name'] ?? '').toString().trim();
      final managerName = selectedPositionName.isNotEmpty
          ? selectedPositionName
          : _legacyManager;

      final data = {
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'manager': managerName,
        'manager_position_id': (_selectedPositionId ?? '').trim(),
        'manager_position_name': selectedPositionName,
        'phone': _phone.text.trim(),
        'workingHours': _workingHours.text.trim(),
        'warehouseName': _selectedWarehouseNames.join(', '),
        'warehouseNames': _selectedWarehouseNames,
        'warehouseIds': _selectedWarehouseIds,
        'revenue': double.tryParse(_revenue.text.replaceAll(',', '.')) ?? 0,
        'status': _status,
        'user_id': user.uid,
        'idCompany': effectiveCompanyId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.item == null) {
        final docRef = await _firestore.collection('shops').add({
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
          'entity': 'shop',
          'entity_id': docRef.id,
          'entity_name': _name.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore
            .collection('shops')
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
          'entity': 'shop',
          'entity_id': widget.item!['id'],
          'entity_name': _name.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('shops', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('activity_log', effectiveCompanyId);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error saving shop: $e');
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
                  isEdit ? 'Редактировать магазин' : 'Добавить магазин',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _field(_name, 'Название', required: true),
                _field(_address, 'Адрес'),
                _positionField(),
                _field(_phone, 'Телефон'),
                _field(_workingHours, 'График работы'),
                _warehousePicker(),
                _field(_revenue, 'Выручка', number: true),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Статус',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text('Активен'),
                    ),
                    DropdownMenuItem(
                      value: 'closed',
                      child: Text('Закрыт'),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Техн. работы'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
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

  Widget _field(TextEditingController c, String label,
      {bool required = false, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (required && (v == null || v.isEmpty)) return 'Обязательное поле';
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

  Widget _positionField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String?>(
        initialValue: _selectedPositionId,
        decoration: const InputDecoration(
          labelText: 'Ответственный (должность)',
          border: OutlineInputBorder(),
        ),
        hint: Text(_loadingPositions
            ? 'Загрузка должностей...'
            : 'Выберите должность'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Не выбрано'),
          ),
          ..._positions.map((p) {
            final id = (p['id'] ?? '').toString();
            final name = (p['name'] ?? '').toString().trim();
            return DropdownMenuItem<String?>(
              value: id,
              child: Text(name.isEmpty ? 'Без названия' : name),
            );
          }),
        ],
        onChanged: _loadingPositions
            ? null
            : (v) {
                setState(() {
                  _selectedPositionId = v;
                  if (v != null && v.isNotEmpty) {
                    _legacyManager = '';
                  }
                });
              },
      ),
    );
  }

  Widget _warehousePicker() {
    final chips = _selectedWarehouseNames.isNotEmpty
        ? Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_selectedWarehouseNames.length, (index) {
              final label = _selectedWarehouseChipLabel(index);
              return Chip(label: Text(label.isEmpty ? 'Без названия' : label));
            }),
          )
        : Text(
            'Не выбраны',
            style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Склады',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chips,
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loadingWarehouses ? null : _pickWarehouses,
                      icon: const Icon(Icons.warehouse_outlined, size: 16),
                      label: const Text('Выбрать склады'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlutterFlowTheme.of(context).primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                    if (_loadingWarehouses) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_warehouseError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _warehouseError!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
