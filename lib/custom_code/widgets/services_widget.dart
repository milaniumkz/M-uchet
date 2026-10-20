// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/effective_company_support.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/app_money_format.dart';
import '/utils/country_profile.dart';
import '/utils/country_tax_profile.dart';
import '/utils/ledger_scope.dart';
import '/utils/report_export_service.dart';
import '/utils/service_supplier_support.dart';
import '/utils/service_accounting_support.dart';

import '/custom_code/widgets/editing_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServicesWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const ServicesWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<ServicesWidget> createState() => _ServicesWidgetState();
}

class _ServicesWidgetState extends State<ServicesWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Set<String> _blockedServiceNames = {
    'официальные товары',
    'неофициальные товары',
  };

  final TextEditingController _searchController = TextEditingController();
  final Map<String, Map<String, dynamic>> _itemDocs = {};
  List<Map<String, dynamic>> _executionDocs = [];
  List<ServiceEntryView> _items = [];
  List<ServiceEntryView> _filtered = [];
  String _currencyCode = 'KZT';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _items = [];
          _filtered = [];
          _itemDocs.clear();
        });
        return;
      }

      final effectiveCompanyId = _effectiveCompanyId(user);

      final snap = await _firestore
          .collection('services')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .get();
      final executionSnap = await _firestore
          .collection('service_executions')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .limit(2000)
          .getCached();
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      final docs = <String, Map<String, dynamic>>{};
      final list = snap.docs.map((d) {
        final raw = d.data();
        final data = Map<String, dynamic>.from(raw);
        final row = {'id': d.id, ...data};
        docs[d.id] = row;
        return ServiceEntryView.fromMap(row);
      }).where((row) {
        final name = row.name.trim().toLowerCase();
        return !_blockedServiceNames.contains(name);
      }).toList();

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _itemDocs
          ..clear()
          ..addAll(docs);
        _executionDocs = executionSnap.docs.map((doc) {
          final raw = Map<String, dynamic>.from(doc.data() as Map);
          return <String, dynamic>{'id': doc.id, ...raw};
        }).toList();
        _items = list;
        _filtered = List.from(list);
      });
    } catch (e) {
      debugPrint('Error loading services: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _effectiveCompanyId(User user) {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = List.from(_items));
      return;
    }

    setState(() {
      _filtered = _items.where((i) {
        final name = i.name.toLowerCase();
        final code = i.code.toLowerCase();
        return name.contains(q) || code.contains(q);
      }).toList();
    });
  }

  int get _total => _items.length;
  int get _active => _items.length;
  double get _avgMargin => _items.isEmpty
      ? 0
      : _items.fold<double>(
              0, (total, item) => total + (item.price - item.defaultUnitCost)) /
          _items.length;
  List<ServiceReportRow> get _executionRows {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return buildServiceReportRows(
      executionDocs: _executionDocs,
      breakdown: 'service',
      start: start,
      end: end,
    );
  }

  double get _executionRevenue =>
      _executionRows.fold<double>(0, (total, row) => total + row.revenue);
  double get _executionCost =>
      _executionRows.fold<double>(0, (total, row) => total + row.cost);
  double get _executionMargin =>
      _executionRows.fold<double>(0, (total, row) => total + row.margin);

  int get _categoriesCount {
    final set = <String>{};
    for (final i in _items) {
      final cat = i.category;
      if (cat.isNotEmpty) set.add(cat);
    }
    return set.length;
  }

  String _money(double v) {
    return formatMoneyWithCurrency(v, currencyCode: _currencyCode);
  }

  Future<void> _exportExecutionsExcel() {
    final rows = buildServiceReportExportRows(
      title: 'Услуги за месяц',
      bodyRows: <List<String>>[
        <String>[
          'Услуга',
          'Кол-во',
          'Выручка',
          'Себестоимость',
          'Маржа',
          'Маржа %'
        ],
        ..._executionRows.map(
          (row) => <String>[
            row.label,
            row.quantity.toStringAsFixed(2),
            row.revenue.toStringAsFixed(2),
            row.cost.toStringAsFixed(2),
            row.margin.toStringAsFixed(2),
            row.marginPercent.toStringAsFixed(2),
          ],
        ),
      ],
    );
    return exportReportExcel(
      filename: 'services-month.xls',
      title: 'Услуги за месяц',
      rows: rows,
    );
  }

  Future<void> _exportExecutionsPdf() {
    final rows = buildServiceReportExportRows(
      title: 'Услуги за месяц',
      bodyRows: <List<String>>[
        <String>[
          'Услуга',
          'Кол-во',
          'Выручка',
          'Себестоимость',
          'Маржа',
          'Маржа %'
        ],
        ..._executionRows.map(
          (row) => <String>[
            row.label,
            row.quantity.toStringAsFixed(2),
            row.revenue.toStringAsFixed(2),
            row.cost.toStringAsFixed(2),
            row.margin.toStringAsFixed(2),
            row.marginPercent.toStringAsFixed(2),
          ],
        ),
      ],
    );
    return exportReportPdf(
      filename: 'services-month.pdf',
      title: 'Услуги за месяц',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionsHelper.has('services.view')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                  child: const Icon(Icons.home_repair_service,
                      color: Color(0xFF9E7B4F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Услуги',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Управление услугами компании',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Добавить услугу'),
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
                    OutlinedButton.icon(
                      onPressed:
                          _executionRows.isEmpty ? null : _exportExecutionsPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _executionRows.isEmpty
                          ? null
                          : _exportExecutionsExcel,
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('Excel'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: _statCard('Всего услуг', _total.toString(),
                      const Color(0xFF1F2A37)),
                ),
                SizedBox(
                  width: 180,
                  child: _statCard('Активных', _active.toString(),
                      FlutterFlowTheme.of(context).success),
                ),
                SizedBox(
                  width: 180,
                  child: _statCard('Категорий', _categoriesCount.toString(),
                      const Color(0xFFC8A06A)),
                ),
                SizedBox(
                  width: 180,
                  child: _statCard('Сред. маржа', _money(_avgMargin),
                      const Color(0xFF0F766E)),
                ),
                SizedBox(
                  width: 180,
                  child: _statCard('Выручка мес.', _money(_executionRevenue),
                      const Color(0xFF1D4ED8)),
                ),
                SizedBox(
                  width: 180,
                  child: _statCard('Себест. мес.', _money(_executionCost),
                      const Color(0xFF7C3AED)),
                ),
                SizedBox(
                  width: 180,
                  child: _statCard('Валовая мес.', _money(_executionMargin),
                      const Color(0xFF0F766E)),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[500], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск услуг...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      return _serviceCard(_filtered[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(ServiceEntryView i) {
    final name = i.name.isEmpty ? 'Без названия' : i.name;
    final code = i.code.isEmpty ? 'SRV000000' : i.code;
    final desc = i.description;
    final price = i.price;
    final category = i.category.isEmpty ? 'Прочее' : i.category;
    final vat = i.vat.toString();
    final unitCost = i.defaultUnitCost;
    final margin = price - unitCost;
    final raw = _itemDocs[i.id] ?? <String, dynamic>{'id': i.id};

    return LiveDiffHighlight(
      timestamp: i.updatedAt ?? i.createdAt,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.settings, color: Color(0xFF9E7B4F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(code,
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  FlutterFlowTheme.of(context).secondaryText)),
                    ],
                  ),
                ),
                if (EditingHelper.canEditExisting())
                  IconButton(
                    onPressed: () => _showAddDialog(existing: raw),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (EditingHelper.canEditExisting())
                  IconButton(
                    onPressed: () => _delete(i.id),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
              ],
            ),
            if (desc.toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(desc,
                  style: TextStyle(
                      color: FlutterFlowTheme.of(context).secondaryText)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _pill(_money(price)),
                const SizedBox(width: 8),
                _pill(category),
                const SizedBox(width: 8),
                _pill('НДС $vat%'),
                const SizedBox(width: 8),
                _pill(i.costingType.label),
                const SizedBox(width: 8),
                _pill('Себ. ${_money(unitCost)}'),
                const SizedBox(width: 8),
                _pill('Маржа ${_money(margin)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statCard(String title, String value, Color valueColor) {
    return Container(
      height: 80,
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
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
        ],
      ),
    );
  }

  void _showAddDialog({Map<String, dynamic>? existing}) {
    if (existing != null && !EditingHelper.guardEdit(context)) return;
    showDialog(
      context: context,
      builder: (context) => AddServiceDialog(
        onSaved: _load,
        existing: existing,
      ),
    );
  }

  Future<void> _delete(String id) async {
    if (!EditingHelper.guardEdit(context)) return;
    final user = _auth.currentUser;
    final effectiveCompanyId = user == null ? '' : _effectiveCompanyId(user);
    await _firestore.collection('services').doc(id).delete();
    if (effectiveCompanyId.isNotEmpty) {
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('services', effectiveCompanyId);
    } else {
      FirestoreQueryCache.instance.invalidateCollection('services');
    }
    _load();
  }
}

class AddServiceDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existing;

  const AddServiceDialog({super.key, required this.onSaved, this.existing});

  @override
  State<AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<AddServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _name = TextEditingController();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _vat = TextEditingController();
  final _fixedCost = TextEditingController();
  final _variableCost = TextEditingController();
  final _defaultUnitCost = TextEditingController();
  final _notes = TextEditingController();

  bool _saving = false;
  List<String> _categoryOptions = [];
  String _selectedCategory = '';
  LedgerScope _ledgerScope = LedgerScope.accounting;
  ServiceCostingType _costingType = ServiceCostingType.fixed;
  bool _isActive = true;
  String _currency = 'KZT';
  String _currencySymbol = moneySymbolForCurrency('KZT');
  List<String> _currencyOptions = const ['KZT', 'TJS', 'RUB', 'USD', 'EUR'];

  @override
  void initState() {
    super.initState();
    _initCompanyDefaults();
    final ex = widget.existing;
    if (ex != null) {
      _name.text = ex['name'] ?? '';
      _code.text = ex['code'] ?? '';
      _description.text = ex['description'] ?? '';
      _price.text = (ex['price'] ?? '').toString();
      _selectedCategory = (ex['category'] ?? '').toString().trim();
      _vat.text = (ex['vat'] ?? _vat.text).toString();
      _ledgerScope = ledgerScopeFromData(ex);
      _costingType = serviceCostingTypeFromValue(
        (ex['costing_type'] ?? ex['service_costing_type'] ?? '').toString(),
      );
      _fixedCost.text = (ex['fixed_cost'] ?? '').toString();
      _variableCost.text = (ex['variable_cost'] ?? '').toString();
      _defaultUnitCost.text = (ex['default_unit_cost'] ?? '').toString();
      _notes.text = (ex['notes'] ?? '').toString();
      _currency = (ex['currency'] ?? 'KZT').toString();
      _currencySymbol = moneySymbolForCurrency(_currency);
      _isActive = ex['is_active'] != false;
    }
    _loadCategories();
  }

  Future<void> _initCompanyDefaults() async {
    final user = _auth.currentUser;
    if (user == null) {
      _vat.text = taxProfileForCountry(countryCode: 'KZ')
          .vatRatePercent
          .toStringAsFixed(0);
      return;
    }
    final companyId = _effectiveCompanyId(user);
    Map<String, dynamic> profileData = const <String, dynamic>{};
    try {
      final snap =
          await _firestore.collection('company_profile').doc(companyId).get();
      profileData = snap.data() ?? const <String, dynamic>{};
    } catch (_) {}
    final countryProfile = countryProfileFromData(profileData);
    final taxProfile = taxProfileForCountry(
      countryCode: countryProfile.countryCode,
      date: DateTime.now(),
    );
    final currency = companyCurrencyFromProfileData(profileData,
        fallback: countryProfile.baseCurrency);
    final currencies = await _loadCurrencyOptions(countryProfile.countryCode);
    if (!mounted) return;
    setState(() {
      if (_vat.text.trim().isEmpty) {
        _vat.text = taxProfile.vatRatePercent.toStringAsFixed(0);
      }
      _currencyOptions = currencies;
      if (widget.existing == null) {
        _currency = currency;
      }
      if (!_currencyOptions.contains(_currency)) {
        _currencyOptions = [_currency, ..._currencyOptions];
      }
      _currencySymbol = moneySymbolForCurrency(_currency);
    });
  }

  Future<List<String>> _loadCurrencyOptions(String countryCode) async {
    final options = <String>{};
    try {
      final snap = await queryValutaRecordOnce();
      for (final record in snap) {
        final explicit = record.countryCode.trim();
        final recordCountry = explicit.isEmpty
            ? countryProfileFromData(record.snapshotData).countryCode
            : countryProfileForCode(explicit).countryCode;
        if (explicit.isEmpty && countryCode != 'KZ') continue;
        if (recordCountry != countryCode) continue;
        final code = normalizeCurrencyCode(record.kod);
        if (code.isNotEmpty) options.add(code);
      }
    } catch (_) {}
    options.add(countryProfileForCode(countryCode).baseCurrency);
    options.addAll(['USD', 'EUR', 'RUB']);
    final list = options.toList()
      ..sort((a, b) {
        final base = countryProfileForCode(countryCode).baseCurrency;
        if (a == base) return -1;
        if (b == base) return 1;
        return a.compareTo(b);
      });
    return list;
  }

  String _ledgerScopeLabel(LedgerScope scope) {
    switch (scope) {
      case LedgerScope.management:
        return 'Управленческий (С)';
      case LedgerScope.accounting:
        return 'Бухгалтерский';
      case LedgerScope.both:
        return 'Общий';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    _price.dispose();
    _vat.dispose();
    _fixedCost.dispose();
    _variableCost.dispose();
    _defaultUnitCost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final companyId = _effectiveCompanyId(user);
      final options = <String>{};
      // Primary source of truth: categories from existing services
      final servicesSnap = await _firestore
          .collection('services')
          .where('idCompany', isEqualTo: companyId)
          .get();
      for (final doc in servicesSnap.docs) {
        final raw = doc.data();
        final data = Map<String, dynamic>.from(raw);
        final title = (data['category'] ?? '').toString().trim();
        if (title.isNotEmpty) options.add(title);
      }

      // Optional registry, may be blocked by rules for non-admin users
      try {
        final categoriesSnap = await _firestore
            .collection('service_categories')
            .where('idCompany', isEqualTo: companyId)
            .get();
        for (final doc in categoriesSnap.docs) {
          final raw = doc.data();
          final data = Map<String, dynamic>.from(raw);
          final title = (data['title'] ?? '').toString().trim();
          if (title.isNotEmpty) options.add(title);
        }
      } catch (_) {}

      if (_selectedCategory.isNotEmpty) {
        options.add(_selectedCategory);
      }
      if (options.isEmpty) {
        options.add('Прочее');
      }

      final sorted = options.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _categoryOptions = sorted;
        if (_selectedCategory.isEmpty ||
            !_categoryOptions.contains(_selectedCategory)) {
          _selectedCategory = _categoryOptions.first;
        }
      });
    } catch (e) {
      debugPrint('Error loading service categories: $e');
    }
  }

  Future<void> _createCategory() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая категория услуги'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название категории',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();

    final normalized = (title ?? '').trim();
    if (normalized.isEmpty) return;
    final companyId = _effectiveCompanyId(user);
    final lower = normalized.toLowerCase();
    // Always allow local category creation in UI (no hard dependency on rules)
    if (!mounted) return;
    setState(() {
      if (!_categoryOptions.contains(normalized)) {
        _categoryOptions = [..._categoryOptions, normalized]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
      _selectedCategory = normalized;
    });

    // Best-effort save to dedicated categories registry
    try {
      final exists = await _firestore
          .collection('service_categories')
          .where('idCompany', isEqualTo: companyId)
          .where('normalized_title', isEqualTo: lower)
          .limit(1)
          .get();
      if (exists.docs.isEmpty) {
        await _firestore.collection('service_categories').add({
          'idCompany': companyId,
          'title': normalized,
          'normalized_title': lower,
          'user_id': user.uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existing != null && !EditingHelper.guardEdit(context)) return;
    final serviceName = _name.text.trim().toLowerCase();
    if (_ServicesWidgetState._blockedServiceNames.contains(serviceName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Это складской тип, а не услуга. Укажите название услуги.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      final effectiveCompanyId = _effectiveCompanyId(user);

      final servicesRef = widget.existing == null
          ? _firestore.collection('services').doc()
          : _firestore.collection('services').doc(widget.existing!['id']);
      final data = buildServicePayload(
        companyId: effectiveCompanyId,
        userId: user.uid,
        name: _name.text,
        code: _code.text,
        description: _description.text,
        price: double.parse(_price.text),
        category: _selectedCategory,
        vat: int.parse(_vat.text),
        isCreate: widget.existing == null,
        isActive: _isActive,
        ledgerScope: _ledgerScope,
        costingType: _costingType,
        fixedCost: double.tryParse(_fixedCost.text.replaceAll(',', '.')) ?? 0,
        variableCost:
            double.tryParse(_variableCost.text.replaceAll(',', '.')) ?? 0,
        defaultUnitCost:
            double.tryParse(_defaultUnitCost.text.replaceAll(',', '.')) ?? 0,
        currency: _currency,
        notes: _notes.text,
      );
      final costModelData = buildServiceCostModelPayload(
        companyId: effectiveCompanyId,
        serviceId: servicesRef.id,
        costingType: _costingType,
        fixedCost: double.tryParse(_fixedCost.text.replaceAll(',', '.')) ?? 0,
        variableCost:
            double.tryParse(_variableCost.text.replaceAll(',', '.')) ?? 0,
        defaultUnitCost:
            double.tryParse(_defaultUnitCost.text.replaceAll(',', '.')) ?? 0,
        currency: _currency,
        ledgerScope: _ledgerScope,
        notes: _notes.text,
        isCreate: widget.existing == null,
      );
      final batch = _firestore.batch();
      batch.set(servicesRef, data, SetOptions(merge: widget.existing != null));
      batch.set(
        _firestore.collection('service_cost_models').doc(servicesRef.id),
        costModelData,
        SetOptions(merge: true),
      );
      await batch.commit();

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('services', effectiveCompanyId);
      FirestoreQueryCache.instance.invalidateCompanyCollection(
          'service_cost_models', effectiveCompanyId);
      navigator.pop();
      widget.onSaved();
    } catch (e) {
      debugPrint('Error saving service: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Редактировать услугу' : 'Добавить услугу',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Название', border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                      labelText: 'Код', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                      labelText: 'Описание', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  decoration: InputDecoration(
                      labelText: 'Цена ($_currencySymbol)',
                      border: const OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null
                      ? 'Введите корректную цену'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LedgerScope>(
                  initialValue: _ledgerScope,
                  decoration: const InputDecoration(
                    labelText: 'Контур учета',
                    border: OutlineInputBorder(),
                  ),
                  items: LedgerScope.values
                      .map((scope) => DropdownMenuItem<LedgerScope>(
                            value: scope,
                            child: Text(_ledgerScopeLabel(scope)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _ledgerScope = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ServiceCostingType>(
                  initialValue: _costingType,
                  decoration: const InputDecoration(
                    labelText: 'Модель себестоимости',
                    border: OutlineInputBorder(),
                  ),
                  items: ServiceCostingType.values
                      .map((type) => DropdownMenuItem<ServiceCostingType>(
                            value: type,
                            child: Text(type.label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _costingType = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fixedCost,
                        decoration: const InputDecoration(
                          labelText: 'Фиксированная себестоимость',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _variableCost,
                        decoration: const InputDecoration(
                          labelText: 'Переменная себестоимость',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _defaultUnitCost,
                        decoration: const InputDecoration(
                          labelText: 'Себестоимость по умолчанию',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Валюта',
                          border: OutlineInputBorder(),
                        ),
                        items: _currencyOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _currency = value;
                            _currencySymbol = moneySymbolForCurrency(value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory.isEmpty
                            ? null
                            : _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Категория услуги',
                          border: OutlineInputBorder(),
                        ),
                        items: _categoryOptions
                            .map((c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedCategory = v);
                        },
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Выберите категорию'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _createCategory,
                        icon: const Icon(Icons.add),
                        label: const Text('Категория'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vat,
                  decoration: const InputDecoration(
                      labelText: 'НДС %', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Примечания к модели себестоимости',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Активна'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
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
                            : Text(isEdit ? 'Сохранить' : 'Добавить'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _effectiveCompanyId(User user) {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
  }
}

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
