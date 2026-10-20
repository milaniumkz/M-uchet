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
import '/utils/accounting_workflow.dart';
import '/utils/business_event_support.dart';
import '/utils/transaction_sync.dart';
import '/utils/effective_company_support.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/inventory_balance_service.dart';
import '/utils/inventory_batch_support.dart';
import '/utils/inventory_batch_metrics_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/order_lifecycle_support.dart';
import '/utils/warehouse_batch_report_support.dart';
import '/utils/warehouse_inventory_support.dart' as warehouse_inventory;
import '/utils/warehouse_batch_support.dart';
import '/utils/warehouse_scope_support.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class WarehouseWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final bool embedded;

  const WarehouseWidget({
    super.key,
    this.width,
    this.height,
    this.embedded = false,
  });

  @override
  State<WarehouseWidget> createState() => _WarehouseWidgetState();
}

class _WarehouseWidgetState extends State<WarehouseWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _virtualWarehouses = [
    'Официальные товары',
    'Неофициальные товары',
  ];
  static const _baseWarehouses = [
    'Основной склад',
    'Склад в эксплуатации',
  ];

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _warehouseDocs = [];
  List<Map<String, dynamic>> _moves = [];
  List<Map<String, dynamic>> _batchDocs = [];
  List<WarehouseMovementEntryView> _moveViews = [];
  final Set<String> _expandedWarehouses = <String>{};
  final TextEditingController _searchController = TextEditingController();
  bool _loading = false;
  String _companyId = '';
  String _userName = '';
  String _userId = '';
  bool _shopWarehouseScope = false;
  String _currencyCode = 'KZT';
  String _companyProductType = '';

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

  Color get _tabSelectedColor => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.96)
      : const Color(0xFF1F2A37);

  Color get _tabUnselectedColor => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.68)
      : FlutterFlowTheme.of(context).secondaryText;

  Color get _mutedText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.72)
      : FlutterFlowTheme.of(context).secondaryText;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _effectiveCompanyId() {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: _auth.currentUser?.uid ?? '',
    );
  }

  bool _isShopRole() {
    return isShopScopedRole(currentUserDocument?.snapshotData);
  }

  Set<String> _resolveAllowedWarehouseNames({
    required List<Map<String, dynamic>> warehouseDocs,
  }) {
    return resolveAllowedWarehouseNames(
      userData: currentUserDocument?.snapshotData,
      warehouseDocs: warehouseDocs,
    );
  }

  Future<bool> _ensureVirtualWarehouses(
    String companyId,
    QuerySnapshot snap,
  ) async {
    if (companyId.isEmpty) return false;
    final existing = snap.docs
        .map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return (data['name'] ?? '').toString().trim();
        })
        .where((name) => name.isNotEmpty)
        .toSet();
    final batch = _firestore.batch();
    var needsCommit = false;
    for (final name in [..._virtualWarehouses, ..._baseWarehouses]) {
      if (existing.contains(name)) continue;
      final ref = _firestore.collection('warehouses').doc();
      batch.set(ref, {
        'idCompany': companyId,
        'name': name,
        'isVirtual': _virtualWarehouses.contains(name),
        ...warehouseTypeFields(warehouseTypeFromLegacy(warehouse: name)),
        'created_at': FieldValue.serverTimestamp(),
      });
      needsCommit = true;
    }
    if (needsCommit) {
      await batch.commit();
    }
    return needsCommit;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _items = [];
          _warehouseDocs = [];
          _moves = [];
          _moveViews = [];
        });
        return;
      }

      final effectiveCompanyId = _effectiveCompanyId();
      final displayName = (currentUserDocument?.displayName ??
              user.displayName ??
              user.email ??
              '')
          .toString()
          .trim();

      final results = await Future.wait<dynamic>([
        _firestore
            .collection('nomenklatura')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('warehouses')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('warehouse_movements')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('inventory_batches')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
      ]);

      final itemsSnap = results[0] as QuerySnapshot;
      var warehousesSnap = results[1] as QuerySnapshot;
      final movesSnap = results[2] as QuerySnapshot;
      final batchesSnap = results[3] as QuerySnapshot;
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      final createdVirtualWarehouses =
          await _ensureVirtualWarehouses(effectiveCompanyId, warehousesSnap);
      if (createdVirtualWarehouses) {
        warehousesSnap = await _firestore
            .collection('warehouses')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache));
      }
      final warehouseDocs = warehousesSnap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return {'id': d.id, ...data};
      }).toList();

      final allItems = itemsSnap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return {'id': d.id, ...data};
      }).toList();
      final allMoves = movesSnap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return {'id': d.id, ...data};
      }).toList()
        ..sort((a, b) {
          final aDate = _recordDate(a['created_at'] ?? a['createdAt']);
          final bDate = _recordDate(b['created_at'] ?? b['createdAt']);
          return bDate.compareTo(aDate);
        });
      final recentMoves = allMoves.take(200).toList();
      final allBatches = batchesSnap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return {'id': d.id, ...data};
      }).toList();
      final valuedItems = List<Map<String, dynamic>>.from(
        enrichWarehouseItemsWithBatchValuation(
          items: allItems,
          inventoryBatches: allBatches,
        )['items'] as List,
      );
      final allowedWarehouses = _resolveAllowedWarehouseNames(
        warehouseDocs: warehouseDocs,
      );
      final hasScope = allowedWarehouses.isNotEmpty && _isShopRole();
      final visibleItems = hasScope
          ? valuedItems
              .where((i) => allowedWarehouses.contains(_warehouseName(i)))
              .toList()
          : valuedItems;
      final visibleWarehouseDocs = hasScope
          ? warehouseDocs
              .where((w) =>
                  w['isVirtual'] == true ||
                  allowedWarehouses.contains((w['name'] ?? '').toString()))
              .toList()
          : warehouseDocs;
      final visibleMoves = hasScope
          ? recentMoves
              .where((m) =>
                  allowedWarehouses
                      .contains((m['from_warehouse'] ?? '').toString()) ||
                  allowedWarehouses
                      .contains((m['to_warehouse'] ?? '').toString()))
              .toList()
          : recentMoves;
      final visibleBatches = hasScope
          ? allBatches
              .where((b) => allowedWarehouses.contains(
                    (b['warehouse_name'] ?? b['warehouse'] ?? '').toString(),
                  ))
              .toList()
          : allBatches;

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _companyProductType =
            (profileData['productType'] ?? profileData['product_type'] ?? '')
                .toString()
                .trim();
        _companyId = effectiveCompanyId;
        _userName = displayName;
        _userId = user.uid;
        _items = visibleItems;
        _warehouseDocs = visibleWarehouseDocs;
        _moves = visibleMoves;
        _batchDocs = visibleBatches;
        _moveViews = visibleMoves
            .map((move) => WarehouseMovementEntryView.fromMap(
                  move,
                  kind: warehouse_inventory.warehouseMovementKind(move),
                ))
            .toList();
        _shopWarehouseScope = hasScope;
      });
    } catch (e) {
      debugPrint('Error loading warehouses: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _warehouseName(Map<String, dynamic> item) =>
      warehouse_inventory.warehouseDisplayName(item);

  DateTime _recordDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, dynamic> get _inventorySummary =>
      warehouse_inventory.buildWarehouseInventorySummary(
        warehouseDocs: _warehouseDocs,
        items: _items,
        moves: _moves,
        virtualWarehouses: _virtualWarehouses,
      );

  int get _totalWarehouses =>
      ((_inventorySummary['totalWarehouses'] as num?) ?? 0).toInt();
  int get _totalPositions =>
      ((_inventorySummary['totalPositions'] as num?) ?? 0).toInt();
  double get _totalValue =>
      ((_inventorySummary['totalValue'] as num?) ?? 0).toDouble();

  List<_WarehouseStats> _warehouseStatsByBucket(bool official) {
    final key = official ? 'official' : 'unofficial';
    final rows = List<Map<String, dynamic>>.from(
      _inventorySummary[key] as List? ?? const [],
    );
    return rows
        .map(
          (row) => _WarehouseStats(
            name: (row['name'] ?? '').toString(),
            parent: (row['parent'] ?? '').toString(),
            positions: (row['positions'] as num?)?.toInt() ?? 0,
            stock: (row['stock'] as num?)?.toDouble() ?? 0,
            value: (row['value'] as num?)?.toDouble() ?? 0,
            incoming: (row['incoming'] as num?)?.toDouble() ?? 0,
            outgoing: (row['outgoing'] as num?)?.toDouble() ?? 0,
            lastMove: row['lastMove'] as DateTime?,
            costingMethods:
                List<String>.from(row['costing_methods'] as List? ?? const []),
          ),
        )
        .toList();
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  bool _matchesSearch(Iterable<String?> values) {
    final query = _searchQuery;
    if (query.isEmpty) return true;
    for (final value in values) {
      if ((value ?? '').toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  List<_WarehouseStats> _filterWarehouseStats(List<_WarehouseStats> rows) {
    if (_searchQuery.isEmpty) return rows;
    return rows.where((row) => _matchesSearch([row.name, row.parent])).toList();
  }

  List<WarehouseMovementEntryView> _filterMovementRows(
    List<WarehouseMovementEntryView> rows,
  ) {
    if (_searchQuery.isEmpty) return rows;
    return rows
        .where(
          (row) => _matchesSearch([
            row.productTitle,
            row.fromWarehouse,
            row.toWarehouse,
            row.userName,
          ]),
        )
        .toList();
  }

  List<Map<String, dynamic>> _filterBatchRows(List<Map<String, dynamic>> rows) {
    if (_searchQuery.isEmpty) return rows;
    return rows
        .where(
          (row) => _matchesSearch([
            (row['product_name'] ?? '').toString(),
            (row['warehouse_name'] ?? '').toString(),
            (row['ledger_scope_label'] ?? '').toString(),
            (row['costing_method_label'] ?? '').toString(),
          ]),
        )
        .toList();
  }

  Future<bool> _ensureUnlocked() async {
    final companyId =
        _companyId.isNotEmpty ? _companyId : _effectiveCompanyId();
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

  Future<void> _showMoveDialog() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _MoveProductDialog(
        items: _items,
        warehouses: _warehouseDocs,
        companyId: _companyId,
        userId: _userId,
        userName: _userName,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _showWriteOffDialog() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _StockAdjustmentDialog(
        title: 'Списание товара',
        actionLabel: 'Списать',
        isReturn: false,
        items: _items,
        companyId: _companyId,
        userId: _auth.currentUser?.uid ?? '',
        userName: currentUserDocument?.displayName ??
            _auth.currentUser?.displayName ??
            _auth.currentUser?.email ??
            '',
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _showReturnDialog() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _StockAdjustmentDialog(
        title: 'Возврат товара',
        actionLabel: 'Принять возврат',
        isReturn: true,
        items: _items,
        companyId: _companyId,
        userId: _auth.currentUser?.uid ?? '',
        userName: currentUserDocument?.displayName ??
            _auth.currentUser?.displayName ??
            _auth.currentUser?.email ??
            '',
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _showAddWarehouseDialog() async {
    showDialog(
      context: context,
      builder: (context) => _AddWarehouseDialog(
        companyId: _companyId,
        userId: _userId,
        virtualWarehouses: _virtualWarehouses,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _showProductTypeDialog() async {
    if (!await _ensureUnlocked()) return;
    if (!mounted) return;
    final controller = TextEditingController(text: _companyProductType);
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Тип товара компании'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Например: квартиры, яблоки, материалы',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (value == null) return;
      await _firestore.collection('company_profile').doc(_companyId).set({
        'productType': value,
        'product_type': value,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _loadData();
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('warehouse.view')) {
      return PermissionsHelper.noAccess();
    }
    final isEmbedded = widget.embedded;
    return ResponsiveFrame(
      backgroundColor: _pageBackground,
      child: DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isEmbedded)
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
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warehouse_outlined,
                          color: Color(0xFF9E7B4F)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Склады',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Управление складами и учет перемещений товаров',
                            style: TextStyle(
                              fontSize: 13,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showProductTypeDialog,
                      icon: const Icon(Icons.category_outlined, size: 16),
                      label: Text(_companyProductType.isEmpty
                          ? 'Тип товара'
                          : _companyProductType),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _panelSurface,
                        foregroundColor:
                            FlutterFlowTheme.of(context).primaryText,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: _panelBorder),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showMoveDialog,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Переместить товар'),
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
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showWriteOffDialog,
                      icon: const Icon(Icons.remove_circle_outline, size: 16),
                      label: const Text('Списание'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showReturnDialog,
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Возврат'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlutterFlowTheme.of(context).success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddWarehouseDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Добавить склад'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC8A06A),
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
            if (!isEmbedded) const SizedBox(height: 12),
            if (!isEmbedded && _shopWarehouseScope)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Показаны только склады, закрепленные за магазином пользователя.',
                  style: TextStyle(
                      fontSize: 12,
                      color: FlutterFlowTheme.of(context).secondaryText),
                ),
              ),
            if (!isEmbedded && _shopWarehouseScope) const SizedBox(height: 8),
            if (!isEmbedded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _statCard(
                      title: 'Склады',
                      value: '$_totalWarehouses',
                      icon: Icons.warehouse_outlined,
                      iconBg: FlutterFlowTheme.of(context).accent1,
                      iconColor: FlutterFlowTheme.of(context).primary,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      title: 'Позиции товаров',
                      value: '$_totalPositions',
                      icon: Icons.inventory_2_outlined,
                      iconBg: FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.14),
                      iconColor: FlutterFlowTheme.of(context).warning,
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      title: 'Стоимость товаров',
                      value: _formatMoney(_totalValue),
                      icon: Icons.attach_money,
                      iconBg: FlutterFlowTheme.of(context)
                          .success
                          .withValues(alpha: 0.14),
                      iconColor: FlutterFlowTheme.of(context).success,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextFormField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Поиск по наименованию',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: _panelSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _panelBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _panelBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                  ),
                ),
              ),
            ),
            if (!isEmbedded) const SizedBox(height: 16),
            if (isEmbedded) const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                labelColor: _tabSelectedColor,
                unselectedLabelColor: _tabUnselectedColor,
                indicatorColor: const Color(0xFFC8A06A),
                dividerColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: 'Склады'),
                  Tab(text: 'Журнал'),
                  Tab(text: 'Партии'),
                  Tab(text: 'Акты'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildWarehousesView(),
                        _buildJournalSection(),
                        _buildBatchesSection(),
                        _buildActsSection(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehousesView() {
    final official = _filterWarehouseStats(_warehouseStatsByBucket(true));
    final unofficial = _filterWarehouseStats(_warehouseStatsByBucket(false));
    return Container(
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
            'Склады по типам',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 980;
                if (narrow) {
                  return ListView(
                    children: [
                      _warehouseColumn(
                        title: 'Официальные товары',
                        rows: official,
                        accent: FlutterFlowTheme.of(context).primary,
                      ),
                      const SizedBox(height: 12),
                      _warehouseColumn(
                        title: 'Неофициальные товары',
                        rows: unofficial,
                        accent: FlutterFlowTheme.of(context).warning,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _warehouseColumn(
                        title: 'Официальные товары',
                        rows: official,
                        accent: FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _warehouseColumn(
                        title: 'Неофициальные товары',
                        rows: unofficial,
                        accent: FlutterFlowTheme.of(context).warning,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _warehouseColumn({
    required String title,
    required List<_WarehouseStats> rows,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              const Spacer(),
              Text(
                '${rows.length} складов',
                style: TextStyle(
                  fontSize: 12,
                  color: _mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Склады не найдены',
                style: TextStyle(color: _mutedText),
              ),
            )
          else
            ...rows.map((row) => _warehouseExpandableCard(row, accent)),
        ],
      ),
    );
  }

  Widget _warehouseExpandableCard(_WarehouseStats row, Color accent) {
    final expanded = _expandedWarehouses.contains(row.name);
    String lastMoveText = '—';
    if (row.lastMove != null) {
      lastMoveText = dateTimeFormat(
        'dd.MM.yyyy HH:mm',
        row.lastMove!,
        locale: FFLocalizations.of(context).languageCode,
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _panelBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            if (expanded) {
              _expandedWarehouses.remove(row.name);
            } else {
              _expandedWarehouses.add(row.name);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                    ),
                  ),
                  Text(
                    '${row.positions} поз.',
                    style: TextStyle(fontSize: 12, color: _mutedText),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: accent,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                if (row.costingMethods.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Методы списания: ${row.costingMethods.join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _warehouseMetric(
                          'Остаток', '${row.stock.toStringAsFixed(0)} шт'),
                    ),
                    Expanded(
                      child: _warehouseMetric(
                          'Стоимость', _formatMoney(row.value)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _warehouseMetric(
                          'Приход', '${row.incoming.toStringAsFixed(0)} шт'),
                    ),
                    Expanded(
                      child: _warehouseMetric(
                          'Списание', '${row.outgoing.toStringAsFixed(0)} шт'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Последнее движение: $lastMoveText',
                    style: TextStyle(
                        fontSize: 12,
                        color: FlutterFlowTheme.of(context).secondaryText),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _warehouseMetric(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: _mutedText),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJournalSection() {
    final moveRows = _filterMovementRows(
      _moveViews.where((m) => m.kind == 'move').toList(),
    );
    final writeOffRows = _filterMovementRows(
      _moveViews.where((m) => m.kind == 'writeoff').toList(),
    );
    final returnRows = _filterMovementRows(
      _moveViews.where((m) => m.kind == 'return').toList(),
    );

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _panelSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _panelBorder),
            ),
            child: TabBar(
              labelColor: _tabSelectedColor,
              unselectedLabelColor: _tabUnselectedColor,
              indicatorColor: const Color(0xFFC8A06A),
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(text: 'Перемещения'),
                Tab(text: 'Списания'),
                Tab(text: 'Возвраты'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                _buildMovementsView(
                  title: 'Журнал перемещений',
                  rows: moveRows,
                  emptyText: 'Перемещений пока нет',
                ),
                _buildMovementsView(
                  title: 'Журнал списаний',
                  rows: writeOffRows,
                  emptyText: 'Списаний пока нет',
                ),
                _buildMovementsView(
                  title: 'Журнал возвратов',
                  rows: returnRows,
                  emptyText: 'Возвратов пока нет',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchesSection() {
    final report = buildWarehouseBatchReport(
      inventoryBatches: _batchDocs,
      products: _items,
    );
    final rows = _filterBatchRows(
      List<Map<String, dynamic>>.from(report['rows'] as List),
    );
    final methodCounts = Map<String, int>.from(
      report['method_counts'] as Map? ?? const {},
    );
    final totalBatches = (report['total_batches'] as num?)?.toInt() ?? 0;
    final totalQty = (report['total_qty'] as num?)?.toDouble() ?? 0;
    final totalValue = (report['total_value'] as num?)?.toDouble() ?? 0;

    return Container(
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
            'Активные партии',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                title: 'Партии',
                value: '$totalBatches',
                icon: Icons.layers_outlined,
                iconBg: FlutterFlowTheme.of(context)
                    .accent1
                    .withValues(alpha: 0.18),
                iconColor: FlutterFlowTheme.of(context).primary,
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Остаток',
                value: '${totalQty.toStringAsFixed(0)} шт',
                icon: Icons.inventory_2_outlined,
                iconBg: FlutterFlowTheme.of(context)
                    .warning
                    .withValues(alpha: 0.14),
                iconColor: FlutterFlowTheme.of(context).warning,
              ),
              const SizedBox(width: 12),
              _statCard(
                title: 'Стоимость',
                value: _formatMoney(totalValue),
                icon: Icons.attach_money,
                iconBg: FlutterFlowTheme.of(context)
                    .success
                    .withValues(alpha: 0.14),
                iconColor: FlutterFlowTheme.of(context).success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (methodCounts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: methodCounts.entries
                  .map(
                    (entry) => Chip(
                      label: Text('${entry.key}: ${entry.value}'),
                      backgroundColor: _panelSurface,
                      side: BorderSide(color: _panelBorder),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          _batchHeader(),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'Активных партий пока нет',
                      style: TextStyle(color: _mutedText),
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) => _batchRow(rows[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsView({
    required String title,
    required List<WarehouseMovementEntryView> rows,
    required String emptyText,
  }) {
    return Container(
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
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _movementHeader(),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: TextStyle(color: _mutedText),
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      return _movementRow(rows[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActsSection() {
    final rows = _filterMovementRows(
      _moveViews
          .where((m) => m.kind == 'writeoff' || m.kind == 'return')
          .toList(),
    );
    return Container(
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
            'Акты списания / инвентаризации',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _HeaderCell('Дата', flex: 2),
              _HeaderCell('Акт', flex: 2),
              _HeaderCell('Товар', flex: 3),
              _HeaderCell('Кол-во', flex: 1),
              _HeaderCell('Фото', flex: 2),
              _HeaderCell('Комментарий', flex: 3),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'Актов пока нет',
                      style: TextStyle(color: _mutedText),
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) => _actRow(rows[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actRow(WarehouseMovementEntryView item) {
    final dateText = item.createdAt == null
        ? '-'
        : dateTimeFormat(
            'dd.MM.yyyy HH:mm',
            item.createdAt!,
            locale: FFLocalizations.of(context).languageCode,
          );
    final actType = item.kind == 'return' ? 'Инвентаризация' : 'Списание';
    final photoText =
        item.photoUrls.isEmpty ? '-' : '${item.photoUrls.length} фото';
    return LiveDiffHighlight(
      timestamp: item.createdAt,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color:
                  FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            _Cell(dateText, flex: 2),
            _Cell(actType, flex: 2, bold: true),
            _Cell(item.productTitle.isEmpty ? '-' : item.productTitle, flex: 3),
            _Cell(item.qty.toStringAsFixed(0), flex: 1),
            _Cell(photoText, flex: 2),
            _Cell(item.reason.isEmpty ? '-' : item.reason, flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _batchHeader() {
    return const Row(
      children: [
        _HeaderCell('Дата', flex: 2),
        _HeaderCell('Товар', flex: 3),
        _HeaderCell('Склад', flex: 2),
        _HeaderCell('Контур', flex: 2),
        _HeaderCell('Метод', flex: 2),
        _HeaderCell('Остаток', flex: 1),
        _HeaderCell('Себест.', flex: 1),
        _HeaderCell('Стоимость', flex: 2),
      ],
    );
  }

  Widget _batchRow(Map<String, dynamic> row) {
    final receivedAt = row['received_at'] as DateTime?;
    final dateText = receivedAt == null
        ? '-'
        : dateTimeFormat(
            'dd.MM.yyyy',
            receivedAt,
            locale: FFLocalizations.of(context).languageCode,
          );
    final qty = ((row['qty_remaining'] as num?) ?? 0).toDouble();
    final unitCost = ((row['unit_cost'] as num?) ?? 0).toDouble();
    final totalValue = ((row['total_value'] as num?) ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          _Cell(dateText, flex: 2),
          _Cell((row['product_name'] ?? '-').toString(), flex: 3, bold: true),
          _Cell((row['warehouse_name'] ?? '-').toString(), flex: 2),
          _Cell((row['ledger_scope_label'] ?? '-').toString(), flex: 2),
          _Cell((row['costing_method_label'] ?? '-').toString(), flex: 2),
          _Cell(qty.toStringAsFixed(0), flex: 1),
          _Cell(_formatMoney(unitCost), flex: 1),
          _Cell(_formatMoney(totalValue), flex: 2),
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

  Widget _movementHeader() {
    return const Row(
      children: [
        _HeaderCell('Дата', flex: 2),
        _HeaderCell('Товар', flex: 3),
        _HeaderCell('Откуда', flex: 2),
        _HeaderCell('Куда', flex: 2),
        _HeaderCell('Кол-во', flex: 1),
        _HeaderCell('Фото', flex: 1),
        _HeaderCell('Пользователь', flex: 2),
      ],
    );
  }

  Widget _movementRow(WarehouseMovementEntryView item) {
    final dateText = item.createdAt != null
        ? dateTimeFormat(
            'dd.MM.yyyy HH:mm',
            item.createdAt!,
            locale: FFLocalizations.of(context).languageCode,
          )
        : '-';

    return LiveDiffHighlight(
      timestamp: item.createdAt,
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
            _Cell(dateText, flex: 2),
            _Cell(item.productTitle.isEmpty ? '-' : item.productTitle,
                flex: 3, bold: true),
            _Cell(item.fromWarehouse.isEmpty ? '-' : item.fromWarehouse,
                flex: 2),
            _Cell(item.toWarehouse.isEmpty ? '-' : item.toWarehouse, flex: 2),
            _Cell(item.qty.toStringAsFixed(0), flex: 1),
            _Cell(item.photoUrls.isEmpty ? '-' : '${item.photoUrls.length}',
                flex: 1),
            _Cell(item.userName.isEmpty ? '-' : item.userName, flex: 2),
          ],
        ),
      ),
    );
  }
}

class _StockAdjustmentDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final bool isReturn;
  final List<Map<String, dynamic>> items;
  final String companyId;
  final String userId;
  final String userName;
  final VoidCallback onSaved;

  const _StockAdjustmentDialog({
    required this.title,
    required this.actionLabel,
    required this.isReturn,
    required this.items,
    required this.companyId,
    required this.userId,
    required this.userName,
    required this.onSaved,
  });

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedProductId;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _photoUrlsController = TextEditingController();
  String _typeUchet = 'Bu';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _typeUchet = normalizeLegacyTypeUchet(FFAppState().accountingMode);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    _photoUrlsController.dispose();
    super.dispose();
  }

  double _toNum(String v) {
    return double.tryParse(v.replaceAll(',', '.')) ?? 0;
  }

  List<String> _photoUrls() {
    return _photoUrlsController.text
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _pickActPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files
        .map((file) => (file.path ?? file.name).trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final existing = _photoUrls();
    final merged = <String>[...existing];
    for (final value in picked) {
      if (!merged.contains(value)) merged.add(value);
    }
    setState(() {
      _photoUrlsController.text = merged.join('\n');
    });
  }

  String _warehouseName(Map<String, dynamic> item) {
    final raw = (item['warehouse'] ?? '').toString().trim();
    return raw.isEmpty ? 'Не указан' : raw;
  }

  String _costingMethodLabel(Map<String, dynamic> item) {
    final method = resolveInventoryCostingMethod(productData: item);
    return method == InventoryCostingMethod.weightedAverage
        ? 'Средневзвешенная'
        : 'FIFO';
  }

  Future<List<InventoryBatchEntry>> _loadProductBatches({
    required String companyId,
    required String productId,
  }) async {
    final snap = await _firestore
        .collection('inventory_batches')
        .where('idCompany', isEqualTo: companyId)
        .where('product_id', isEqualTo: productId)
        .get();
    return snap.docs
        .map((doc) => InventoryBatchEntry.fromMap({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  Future<double?> _requestWarehouseExchangeRate({
    required AccountSelection account,
    required double amount,
  }) async {
    final data = account.snapshotData ?? const <String, dynamic>{};
    final accountCurrency = originalCurrencyFromData(data, fallback: 'KZT');
    final companyCurrency =
        companyCurrencyFromData(data, fallback: accountCurrency);
    if (normalizeCurrencyCode(accountCurrency) ==
        normalizeCurrencyCode(companyCurrency)) {
      return 1.0;
    }
    final controller = TextEditingController(text: '1');
    try {
      return await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          double rateValue() =>
              double.tryParse(
                controller.text.replaceAll(' ', '').replaceAll(',', '.'),
              ) ??
              0.0;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final companyAmount = amount * rateValue();
              return AlertDialog(
                title: const Text('Курс для складской операции'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Счет: ${account.title} ($accountCurrency)'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Курс $accountCurrency → $companyCurrency',
                        helperText:
                            'В отчетах: ${formatMoneyWithCurrency(companyAmount, currencyCode: companyCurrency)}',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: rateValue() <= 0
                        ? null
                        : () => Navigator.pop(dialogContext, rateValue()),
                    child: const Text('Применить'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final missingFields = validateRequiredFields(
      accountingMode: _typeUchet,
      stage: AccountingWorkflowStage.warehouse,
      payload: <String, dynamic>{
        'product_id': _selectedProductId ?? '',
        'qty': _qtyController.text.trim(),
        'reason': _reasonController.text.trim(),
      },
    );
    if (missingFields.isNotEmpty) {
      final translated = missingFields.map((f) {
        switch (f) {
          case 'product_id':
            return 'товар';
          case 'qty':
            return 'количество';
          case 'reason':
            return 'причина';
          default:
            return f;
        }
      }).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заполните обязательные поля: $translated')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final product =
          widget.items.firstWhere((i) => i['id'] == _selectedProductId);
      final qty = _toNum(_qtyController.text);
      if (qty <= 0) throw Exception('Количество должно быть больше нуля');

      final effectiveCompanyId = widget.companyId.isNotEmpty
          ? widget.companyId
          : (currentUserDocument?.idCompany.trim().isNotEmpty ?? false)
              ? currentUserDocument!.idCompany
              : (_auth.currentUser?.uid ?? '');

      final productRef =
          _firestore.collection('nomenklatura').doc(product['id']);
      final photoUrls = _photoUrls();
      final rawStock = (product['stock'] ?? 0).toDouble();
      final purchase = (product['purchase_price'] ?? 0).toDouble();
      final warehouse = _warehouseName(product);
      final warehouseId =
          (product['warehouse_id'] ?? product['warehouse'] ?? '').toString();
      final ledgerScope = ledgerScopeFromLegacyValue(_typeUchet);
      var newStock = rawStock;
      var stockValue =
          (product['stock_value'] ?? (rawStock * purchase)).toDouble();
      var batchCount = 0;
      var transactionAmount = purchase * qty;

      final writeBatch = _firestore.batch();
      if (widget.isReturn) {
        newStock = rawStock + qty;
        stockValue += qty * purchase;
        writeBatch.set(
          _firestore.collection('inventory_batches').doc(),
          buildInventoryBatchPayload(
            companyId: effectiveCompanyId,
            productId: product['id'].toString(),
            productName: (product['name'] ?? '').toString(),
            warehouseId: warehouseId,
            warehouseName: warehouse,
            ledgerScope: ledgerScope,
            qtyInitial: qty,
            qtyRemaining: qty,
            unitCost: purchase,
            sourceDocType: 'warehouse_return',
            sourceDocId: product['id'].toString(),
          ),
        );
        batchCount = 1;
      } else {
        final batches = inventoryBatchesForProduct(
          batches: await _loadProductBatches(
            companyId: effectiveCompanyId,
            productId: product['id'].toString(),
          ),
          warehouseId: warehouseId,
          ledgerScope: ledgerScope,
        );
        final plan = buildWarehouseWriteoffPlan(
          firestore: _firestore,
          companyId: effectiveCompanyId,
          productId: product['id'].toString(),
          productName: (product['name'] ?? '').toString(),
          warehouseId: warehouseId,
          warehouseName: warehouse,
          ledgerScope: ledgerScope,
          batches: batches,
          qty: qty,
        );
        for (final write in plan.batchWrites) {
          writeBatch.set(
            write.reference,
            write.data,
            SetOptions(merge: write.merge),
          );
        }
        newStock = plan.sourceQtyRemaining;
        stockValue = plan.sourceValueRemaining;
        batchCount = plan.mutatedBatchCount;
        transactionAmount = plan.totalCost;
      }

      final amount = transactionAmount;
      final account =
          await TransactionSync.selectAccount(effectiveCompanyId, tip: 'bank');
      final exchangeRate = amount > 0
          ? await _requestWarehouseExchangeRate(
              account: account,
              amount: amount,
            )
          : 1.0;
      if (exchangeRate == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }

      writeBatch.update(productRef, {
        'stock': newStock,
        'stock_value': stockValue,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await writeBatch.commit();

      final movementFrom = widget.isReturn ? 'Возврат' : warehouse;
      final movementTo = widget.isReturn ? warehouse : 'Списание';
      await _firestore.collection('warehouse_movements').add({
        'idCompany': effectiveCompanyId,
        'user_id': widget.userId.isNotEmpty
            ? widget.userId
            : (_auth.currentUser?.uid ?? ''),
        'user_name': widget.userName.isNotEmpty
            ? widget.userName
            : (currentUserDocument?.displayName ??
                _auth.currentUser?.displayName ??
                _auth.currentUser?.email ??
                ''),
        'product_id': product['id'],
        'product_name': product['name'],
        'product_code': product['code'],
        'from_warehouse': movementFrom,
        'to_warehouse': movementTo,
        'qty': qty,
        'movement_kind': widget.isReturn ? 'return' : 'writeoff',
        'batch_count': batchCount,
        'photo_urls': photoUrls,
        'photo_names': photoUrls.map((url) => url.split('/').last).toList(),
        'attachment_count': photoUrls.length,
        'act_number':
            '${widget.isReturn ? 'INV' : 'WO'}-${DateTime.now().millisecondsSinceEpoch}',
        'created_at': FieldValue.serverTimestamp(),
        'reason': _reasonController.text.trim(),
        ...workflowMeta(
          stage: AccountingWorkflowStage.warehouse,
          accountingMode: _typeUchet,
          status: AccountingWorkflowStatus.posted,
        ),
      });
      await _firestore.collection('business_events').add(
            buildBusinessEventPayload(
              companyId: effectiveCompanyId,
              type: BusinessEventType.inventoryMoved,
              ledgerScope: ledgerScopeFromLegacyValue(_typeUchet),
              aggregateId: product['id']?.toString(),
              productId: product['id']?.toString(),
              warehouseId: warehouseId,
              warehouseName: warehouse,
              quantity: qty,
              cost: transactionAmount,
              notes: widget.isReturn
                  ? 'warehouse_return:${_reasonController.text.trim()}'
                  : 'warehouse_writeoff:${_reasonController.text.trim()}',
            ),
          );

      await _firestore.collection('tranzaction').add({
        ...createTranzactionRecordData(
          type: 'decome',
          typeUchet: _typeUchet,
          ledgerScope: ledgerScopeFromLegacyValue(_typeUchet).storageValue,
          kat: widget.isReturn ? 'Возврат' : 'Списание',
          text: widget.isReturn
              ? 'Возврат товара ${product['name']}'
              : 'Списание товара ${product['name']}',
          summa: amount,
          nds: false,
          summaNds: 0,
          idCompany: effectiveCompanyId,
          schetId: account.reference,
          schetTitle: account.title,
        ),
        ...mapToFirestore(
          transactionMoneyFieldsForAccountData(
            amountOriginal: amount,
            accountData: account.snapshotData,
            exchangeRateToCompany: exchangeRate,
            exchangeRateDate: DateTime.now(),
            exchangeRateSource:
                exchangeRate == 1.0 ? 'same_currency' : 'manual_warehouse',
          ),
        ),
        ...mapToFirestore({'date': FieldValue.serverTimestamp()}),
        ...workflowMeta(
          stage: AccountingWorkflowStage.warehouse,
          accountingMode: _typeUchet,
          status: AccountingWorkflowStatus.posted,
        ),
      });

      await TransactionSync.recomputeAllForCompany(effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('nomenklatura', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('inventory_batches', effectiveCompanyId);
      FirestoreQueryCache.instance.invalidateCompanyCollection(
          'warehouse_movements', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('business_events', effectiveCompanyId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error adjusting stock: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Товар',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.items.map((item) {
                    final title = [
                      (item['name'] ?? '').toString(),
                      (item['code'] ?? '').toString().isEmpty
                          ? null
                          : '(${item['code']})'
                    ].whereType<String>().join(' ');
                    return DropdownMenuItem(
                      value: item['id'] as String,
                      child: Text(
                        '${title.isEmpty ? 'Без названия' : title} · ${_warehouseName(item)} · ${_costingMethodLabel(item)}',
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedProductId = v),
                  validator: (v) => v == null ? 'Выберите товар' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _qtyController,
                  decoration: const InputDecoration(
                    labelText: 'Количество',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите количество';
                    }
                    if (_toNum(v) <= 0) {
                      return 'Количество должно быть больше 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _typeUchet,
                  decoration: const InputDecoration(
                    labelText: 'Тип учета',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Up1', child: Text('Управленческий (С)')),
                    DropdownMenuItem(value: 'Bu', child: Text('Бухгалтерский')),
                  ],
                  onChanged: (v) => setState(() {
                    _typeUchet = v ?? 'Bu';
                    FFAppState().accountingMode = _typeUchet;
                  }),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Причина / комментарий',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _photoUrlsController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Фото к акту',
                    helperText:
                        'Вставьте ссылки на фото через запятую или с новой строки',
                    border: OutlineInputBorder(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickActPhotos,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Прикрепить фото'),
                  ),
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
                            : Text(widget.actionLabel),
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
}

class _WarehouseStats {
  _WarehouseStats({
    required this.name,
    required this.parent,
    this.positions = 0,
    this.stock = 0,
    this.value = 0,
    this.incoming = 0,
    this.outgoing = 0,
    this.lastMove,
    this.costingMethods = const <String>[],
  });

  final String name;
  final String parent;
  int positions = 0;
  double stock = 0;
  double value = 0;
  double incoming = 0;
  double outgoing = 0;
  DateTime? lastMove;
  List<String> costingMethods;
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

  const _Cell(this.text, {required this.flex, this.bold = false});

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
            null,
            positiveColor: const Color(0xFF1F2A37),
          ),
        ),
      ),
    );
  }
}

class _MoveProductDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> warehouses;
  final String companyId;
  final String userId;
  final String userName;
  final VoidCallback onSaved;

  const _MoveProductDialog({
    required this.items,
    required this.warehouses,
    required this.companyId,
    required this.userId,
    required this.userName,
    required this.onSaved,
  });

  @override
  State<_MoveProductDialog> createState() => _MoveProductDialogState();
}

class _MoveProductDialogState extends State<_MoveProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _inventoryBalanceService = InventoryBalanceService();

  String? _selectedProductId;
  final TextEditingController _qtyController = TextEditingController();
  String? _selectedTargetWarehouse;
  bool _saving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  double _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  List<String> get _warehouseOptions {
    final names = <String>{};
    for (final w in widget.warehouses) {
      if (w['isVirtual'] == true) continue;
      final name = (w['name'] ?? '').toString().trim();
      if (name.isNotEmpty) names.add(name);
    }
    final result = names.toList()..sort();
    return result;
  }

  Map<String, Map<String, dynamic>> get _warehouseMetaByName {
    final map = <String, Map<String, dynamic>>{};
    for (final w in widget.warehouses) {
      if (w['isVirtual'] == true) continue;
      final name = (w['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      map[name] = w;
    }
    return map;
  }

  String _warehouseName(Map<String, dynamic> item) {
    final raw = (item['warehouse'] ?? '').toString().trim();
    return raw.isEmpty ? 'Не указан' : raw;
  }

  String _costingMethodLabel(Map<String, dynamic> item) {
    final method = resolveInventoryCostingMethod(productData: item);
    return method == InventoryCostingMethod.weightedAverage
        ? 'Средневзвешенная'
        : 'FIFO';
  }

  bool _isOfficialWarehouseName(String name) {
    final normalized = name.trim();
    final warehouseMeta =
        _warehouseMetaByName[normalized] ?? const <String, dynamic>{};
    return warehouseTypeFromLegacy(
      rawWarehouseType:
          (warehouseMeta['warehouseType'] ?? warehouseMeta['warehouse_type'])
              .toString(),
      isOfficial: warehouseMeta['isOfficial'] ?? warehouseMeta['is_official'],
      warehouse: normalized,
      parentWarehouse:
          (warehouseMeta['parentWarehouse'] ?? warehouseMeta['parent'])
              .toString(),
    ).isOfficial;
  }

  bool? _isOfficialMarker(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return warehouseTypeFromLegacy(warehouse: trimmed).isOfficial;
  }

  bool _isOfficialProduct(Map<String, dynamic> product) {
    final byBool =
        product['official'] ?? product['isOfficial'] ?? product['is_official'];
    if (byBool is bool) return byBool;

    final fromType = _isOfficialMarker(
      (product['warehouseType'] ?? product['warehouse_type'] ?? '')
          .toString()
          .trim(),
    );
    if (fromType != null) return fromType;

    final fromWarehouse = _isOfficialMarker(
      (product['warehouse'] ?? '').toString().trim(),
    );
    if (fromWarehouse != null) return fromWarehouse;

    return true;
  }

  Future<List<InventoryBatchEntry>> _loadProductBatches({
    required String companyId,
    required String productId,
  }) async {
    final snap = await _firestore
        .collection('inventory_batches')
        .where('idCompany', isEqualTo: companyId)
        .where('product_id', isEqualTo: productId)
        .get();
    return snap.docs
        .map((doc) => InventoryBatchEntry.fromMap({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  Future<List<InventoryReservationEntry>> _loadProductReservations({
    required String companyId,
    required String productId,
  }) async {
    final snap = await _firestore
        .collection('inventory_reservations')
        .where('idCompany', isEqualTo: companyId)
        .where('product_id', isEqualTo: productId)
        .get();
    return snap.docs
        .map((doc) => InventoryReservationEntry.fromMap({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  List<String> get _targetWarehouseOptions {
    final product = widget.items.firstWhere(
      (i) => i['id'] == _selectedProductId,
      orElse: () => const <String, dynamic>{},
    );
    if (product.isEmpty) return _warehouseOptions;

    final current = _warehouseName(product);
    final productOfficial = _isOfficialProduct(product);

    return _warehouseOptions
        .where((w) =>
            w != current && _isOfficialWarehouseName(w) == productOfficial)
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final product =
          widget.items.firstWhere((i) => i['id'] == _selectedProductId);
      final target = (_selectedTargetWarehouse ?? '').trim();

      if (target.isEmpty) {
        throw Exception('Склад назначения не указан');
      }

      final current = _warehouseName(product);
      final qty = _toNum(_qtyController.text);
      if (qty <= 0) throw Exception('Количество должно быть больше нуля');
      if (current == target) {
        Navigator.pop(context);
        return;
      }

      final productOfficial = _isOfficialProduct(product);
      final currentOfficial = _isOfficialWarehouseName(current);
      final targetOfficial = _isOfficialWarehouseName(target);
      if (currentOfficial != targetOfficial ||
          productOfficial != targetOfficial) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              productOfficial
                  ? 'Нельзя переносить официальный (белый) товар в неофициальный (серый) склад.'
                  : 'Нельзя переносить серый товар в официальный склад.',
            ),
          ),
        );
        return;
      }

      final effectiveCompanyId = widget.companyId.isNotEmpty
          ? widget.companyId
          : (currentUserDocument?.idCompany.trim().isNotEmpty ?? false)
              ? currentUserDocument!.idCompany
              : (_auth.currentUser?.uid ?? '');

      if (effectiveCompanyId.isEmpty) {
        throw Exception('Компания не определена');
      }

      final productRef =
          _firestore.collection('nomenklatura').doc(product['id']);
      final purchase =
          _toNum(product['purchase_price'] ?? product['cost_price']);
      final sourceWarehouseId =
          (product['warehouse_id'] ?? product['warehouse'] ?? '').toString();
      final ledgerScope = ledgerScopeFromLegacyValue(
        (product['typeUchet'] ?? product['ledger_scope'] ?? 'Bu').toString(),
      );
      final sourceBatches = inventoryBatchesForProduct(
        batches: await _loadProductBatches(
          companyId: effectiveCompanyId,
          productId: product['id'].toString(),
        ),
        warehouseId: sourceWarehouseId,
        ledgerScope: ledgerScope,
      );
      final sourceReservations = await _loadProductReservations(
        companyId: effectiveCompanyId,
        productId: product['id'].toString(),
      );
      final physicalQty = _inventoryBalanceService.getStockQty(
        batches: sourceBatches,
        ledgerScope: ledgerScope,
        productId: product['id'].toString(),
        warehouseId: sourceWarehouseId,
      );
      final availableQty = _inventoryBalanceService.getAvailableQty(
        batches: sourceBatches,
        reservations: sourceReservations,
        ledgerScope: ledgerScope,
        productId: product['id'].toString(),
        warehouseId: sourceWarehouseId,
      );
      if (qty > availableQty) {
        throw Exception('Количество больше доступного остатка');
      }
      final writeBatch = _firestore.batch();
      double movedValue = qty * purchase;

      if (qty >= physicalQty) {
        writeBatch.update(productRef, {
          'warehouse': target,
          'warehouse_id': target,
          'updated_at': FieldValue.serverTimestamp(),
        });
        for (final batch in sourceBatches) {
          writeBatch.set(
            _firestore.collection('inventory_batches').doc(batch.id),
            {
              'warehouse_id': target,
              'warehouse_name': target,
              'updated_at': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      } else {
        final sku = (product['sku'] ?? '').toString().trim();
        final code = (product['code'] ?? '').toString().trim();
        Query<Map<String, dynamic>> query = _firestore
            .collection('nomenklatura')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .where('warehouse', isEqualTo: target);
        if (sku.isNotEmpty) {
          query = query.where('sku', isEqualTo: sku);
        } else if (code.isNotEmpty) {
          query = query.where('code', isEqualTo: code);
        }
        final targetSnap = await query.limit(1).get();
        late final DocumentReference<Map<String, dynamic>> targetRef;
        late final String targetProductId;
        double targetStock = 0;
        double targetStockValue = 0;
        if (targetSnap.docs.isNotEmpty &&
            targetSnap.docs.first.id != (product['id'] ?? '').toString()) {
          targetRef = targetSnap.docs.first.reference;
          final data = targetSnap.docs.first.data();
          targetProductId = targetSnap.docs.first.id;
          targetStock = _toNum(data['stock']);
          targetStockValue =
              _toNum(data['stock_value'] ?? (targetStock * purchase));
        } else {
          targetRef = _firestore.collection('nomenklatura').doc();
          targetProductId = targetRef.id;
          final cloned = Map<String, dynamic>.from(product)
            ..remove('id')
            ..remove('created_at')
            ..remove('updated_at');
          writeBatch.set(targetRef, {
            ...cloned,
            'idCompany': effectiveCompanyId,
            'warehouse': target,
            'warehouse_id': target,
            ...warehouseTypeFields(
              warehouseTypeFromLegacy(warehouse: target),
            ),
            'stock': 0,
            'stock_value': 0,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        final plan = buildWarehouseMovePlan(
          firestore: _firestore,
          companyId: effectiveCompanyId,
          sourceProductId: product['id'].toString(),
          sourceProductName: (product['name'] ?? '').toString(),
          sourceWarehouseId: sourceWarehouseId,
          sourceWarehouseName: current,
          targetProductId: targetProductId,
          targetWarehouseId: target,
          targetWarehouseName: target,
          ledgerScope: ledgerScope,
          sourceBatches: sourceBatches,
          qty: qty,
        );
        writeBatch.update(productRef, {
          'stock': plan.sourceQtyRemaining,
          'stock_value': plan.sourceValueRemaining,
          'updated_at': FieldValue.serverTimestamp(),
        });
        movedValue = plan.movedValue;
        writeBatch.set(
          targetRef,
          {
            'stock': targetStock + plan.movedQty,
            'stock_value': targetStockValue + plan.movedValue,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        for (final write in plan.batchWrites) {
          writeBatch.set(
            write.reference,
            write.data,
            SetOptions(merge: write.merge),
          );
        }
      }
      await writeBatch.commit();

      await _firestore.collection('warehouse_movements').add({
        'idCompany': effectiveCompanyId,
        'user_id': widget.userId.isNotEmpty
            ? widget.userId
            : (_auth.currentUser?.uid ?? ''),
        'user_name': widget.userName.isNotEmpty
            ? widget.userName
            : (currentUserDocument?.displayName ??
                _auth.currentUser?.displayName ??
                _auth.currentUser?.email ??
                ''),
        'product_id': product['id'],
        'product_name': product['name'],
        'product_code': product['code'],
        'from_warehouse': current,
        'to_warehouse': target,
        'qty': qty,
        'movement_kind': 'move',
        'created_at': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('business_events').add(
            buildBusinessEventPayload(
              companyId: effectiveCompanyId,
              type: BusinessEventType.inventoryMoved,
              ledgerScope: ledgerScope,
              aggregateId: product['id']?.toString(),
              productId: product['id']?.toString(),
              warehouseId: sourceWarehouseId,
              warehouseName: current,
              quantity: qty,
              cost: movedValue,
              notes: 'warehouse_move:$target',
            ),
          );

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('nomenklatura', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('inventory_batches', effectiveCompanyId);
      FirestoreQueryCache.instance.invalidateCompanyCollection(
          'warehouse_movements', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('business_events', effectiveCompanyId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error moving product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Не удалось выполнить перемещение товара')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('Перемещение товара',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Товар',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.items.map((item) {
                    final title = [
                      (item['name'] ?? '').toString(),
                      (item['code'] ?? '').toString().isEmpty
                          ? null
                          : '(${item['code']})'
                    ].whereType<String>().join(' ');
                    return DropdownMenuItem(
                      value: item['id'] as String,
                      child: Text(
                        '${title.isEmpty ? 'Без названия' : title} · ${_warehouseName(item)} · ${_costingMethodLabel(item)}',
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedProductId = v;
                      final product = widget.items.firstWhere(
                        (i) => i['id'] == v,
                        orElse: () => const <String, dynamic>{},
                      );
                      final current = _warehouseName(product);
                      final options = _targetWarehouseOptions;
                      if (options.isEmpty) {
                        _selectedTargetWarehouse = null;
                      } else if (_selectedTargetWarehouse == null ||
                          !options.contains(_selectedTargetWarehouse)) {
                        _selectedTargetWarehouse = options.first;
                      } else if (current == _selectedTargetWarehouse) {
                        _selectedTargetWarehouse = options.first;
                      }
                    });
                  },
                  validator: (v) => v == null ? 'Выберите товар' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _qtyController,
                  decoration: const InputDecoration(
                    labelText: 'Количество',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите количество';
                    }
                    if (_toNum(v) <= 0) {
                      return 'Количество должно быть больше 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTargetWarehouse,
                  decoration: const InputDecoration(
                    labelText: 'Склад назначения',
                    border: OutlineInputBorder(),
                  ),
                  items: _targetWarehouseOptions
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedTargetWarehouse = v),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Укажите склад' : null,
                ),
                if (_selectedProductId != null &&
                    _targetWarehouseOptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Нет доступных складов того же типа (официальный/неофициальный).',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFFB42318)),
                      ),
                    ),
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
                            : const Text('Переместить'),
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
}

class _AddWarehouseDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final String companyId;
  final String userId;
  final List<String> virtualWarehouses;

  const _AddWarehouseDialog({
    required this.onSaved,
    required this.companyId,
    required this.userId,
    required this.virtualWarehouses,
  });

  @override
  State<_AddWarehouseDialog> createState() => _AddWarehouseDialogState();
}

class _AddWarehouseDialogState extends State<_AddWarehouseDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _name = TextEditingController();
  String? _parentWarehouse;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _effectiveCompanyId(User user) {
    if (widget.companyId.trim().isNotEmpty &&
        widget.companyId.trim() != '__all__') {
      return widget.companyId.trim();
    }
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');
      final effectiveCompanyId = _effectiveCompanyId(user);
      final parentWarehouse =
          (_parentWarehouse ?? widget.virtualWarehouses.first).trim();

      await _firestore.collection('warehouses').add({
        'name': _name.text.trim(),
        'user_id': widget.userId.isEmpty ? user.uid : widget.userId,
        'idCompany': effectiveCompanyId,
        'parentWarehouse': parentWarehouse,
        'isVirtual': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('warehouses', effectiveCompanyId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error saving warehouse: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('Добавить склад',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Название склада',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите название';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                      _parentWarehouse ?? widget.virtualWarehouses.first,
                  decoration: const InputDecoration(
                    labelText: 'Тип склада',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.virtualWarehouses
                      .map((w) => DropdownMenuItem(
                            value: w,
                            child: Text(w),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _parentWarehouse = v),
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
                            : const Text('Добавить'),
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
}
