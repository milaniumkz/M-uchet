// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/utils/app_money_format.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/country_profile.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/accounting_workflow.dart';
import '/utils/audit_log_service.dart';
import '/utils/transaction_sync.dart';
import '/utils/effective_company_support.dart';
import '/utils/inventory_batch_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/industry_scenarios.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/product_catalog_support.dart' as product_catalog;
import '/utils/nomenclature_mutation_support.dart';

import '/custom_code/widgets/editing_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

final List<String> _warehouseTypeOptions = WarehouseType.values
    .map((type) => type.bucketLabel)
    .toList(growable: false);
const _defaultNomenclatureCategories =
    product_catalog.defaultNomenclatureCategories;
const _sourceTypeManual = product_catalog.sourceTypeManual;
const _sourceTypeExcel = product_catalog.sourceTypeExcel;
const _inventoryCostingOptions = <InventoryCostingMethod>[
  InventoryCostingMethod.fifo,
  InventoryCostingMethod.weightedAverage,
];

String _inventoryCostingLabel(InventoryCostingMethod method) {
  return inventoryCostingMethodLabel(method);
}

String inventoryCostingMethodLabelFromData(Map<String, dynamic> data) {
  return _inventoryCostingLabel(
      resolveInventoryCostingMethod(productData: data));
}

WarehouseType _warehouseTypeFromOption(String value) {
  return warehouseTypeFromLegacy(warehouse: value);
}

String _warehouseTypeOption(WarehouseType type) {
  return type.bucketLabel;
}

String _warehouseTypeOptionFromData(Map<String, dynamic> data) {
  return _warehouseTypeOption(warehouseTypeFromData(data));
}

bool _warehouseDocBelongsToType(
  Map<String, dynamic> warehouseDoc,
  String warehouseType,
) {
  final targetType = _warehouseTypeFromOption(warehouseType);
  final docType = warehouseTypeFromData(warehouseDoc);
  return docType == targetType;
}

Widget _warehouseTypeDropdown({
  required String value,
  required ValueChanged<String?> onChanged,
}) {
  final selectedValue = value.isNotEmpty ? value : _warehouseTypeOptions.first;
  return DropdownButtonFormField<String>(
    initialValue: selectedValue,
    decoration: const InputDecoration(
      labelText: 'Вид склада',
      border: OutlineInputBorder(),
    ),
    items: _warehouseTypeOptions
        .map((type) => DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            ))
        .toList(),
    onChanged: onChanged,
    validator: (v) => (v == null || v.isEmpty) ? 'Обязательное поле' : null,
  );
}

class NomenclatureWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final Function()? onAddProduct;
  final Function()? onAddBatch;
  final bool embedded;

  const NomenclatureWidget({
    super.key,
    this.width,
    this.height,
    this.onAddProduct,
    this.onAddBatch,
    this.embedded = false,
  });

  @override
  State<NomenclatureWidget> createState() => _NomenclatureWidgetState();
}

class _NomenclatureWidgetState extends State<NomenclatureWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _nomenclatureCategories =
      List.from(_defaultNomenclatureCategories);
  String _selectedCategory = 'all';
  String _selectedAccountingFilter = 'all';
  String _selectedCostingFilter = 'all';
  String _sortBy = 'nameAsc';
  String _officialSortBy = 'invoiceDateDesc';
  String _unofficialSortBy = 'deliveryType';
  final Set<String> _expandedProductIds = <String>{};
  bool _collapseOfficialProducts = false;
  bool _collapseUnofficialProducts = false;
  bool _loading = false;
  String _companyId = '';
  String _userId = '';
  String _currencyCode = 'KZT';
  Map<String, dynamic> _industryScenario =
      industryScenarioForBusinessType(kBusinessTrade);

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_applySearch);
  }

  String _effectiveCompanyId() {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: _auth.currentUser?.uid ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _items = [];
          _filtered = [];
        });
        return;
      }

      final effectiveCompanyId = _effectiveCompanyId();
      final queryCompanyIds = resolveQueryCompanyIds(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: effectiveCompanyId,
      );
      final userId = user.uid;
      List<String> seededCategories = List.from(_defaultNomenclatureCategories);
      try {
        seededCategories = await _ensureDefaultNomenclatureCategories(
          effectiveCompanyId,
          userId: userId,
        );
      } catch (e) {
        // Do not block product loading if category registry is restricted.
        debugPrint('Skip ensuring nomenclature categories: $e');
      }

      final docsById = <String, Map<String, dynamic>>{};
      for (final field in const ['idCompany', 'companyId', 'company_id']) {
        for (final ids in splitCompanyIdsForWhereIn(queryCompanyIds)) {
          final snap = await _firestore
              .collection('nomenklatura')
              .where(field, whereIn: ids)
              .get(const GetOptions(source: Source.serverAndCache));
          for (final doc in snap.docs) {
            docsById[doc.id] = {'id': doc.id, ...doc.data()};
          }
        }
      }

      final list = docsById.values.toList();
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      List<String> categories;
      try {
        categories = await _loadNomenclatureCategories(
          seededCategories: seededCategories,
          items: list,
        );
      } catch (e) {
        debugPrint('Fallback categories from items only: $e');
        final fallback = <String>{..._defaultNomenclatureCategories};
        for (final item in list) {
          final title = (item['category'] ?? '').toString().trim();
          if (title.isNotEmpty) fallback.add(title);
        }
        categories = fallback.toList()..sort();
      }

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _industryScenario = industryScenarioForBusinessType(
          (profileData['business_type'] ?? profileData['businessType'])
              ?.toString(),
        );
        _companyId = effectiveCompanyId;
        _userId = userId;
        _items = list;
        _nomenclatureCategories = categories;
        if (_selectedCategory != 'all' &&
            !_nomenclatureCategories.contains(_selectedCategory)) {
          _selectedCategory = 'all';
        }
      });
      _applySearch();
    } catch (e) {
      debugPrint('Error loading nomenclature: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _items.where((i) {
        if (_selectedAccountingFilter != 'all') {
          final mode = (i['accounting_mode'] ?? '').toString().trim();
          if (mode.isNotEmpty && mode != _selectedAccountingFilter) {
            return false;
          }
        }
        final category = (i['category'] ?? '').toString().trim();
        if (_selectedCategory != 'all' && category != _selectedCategory) {
          return false;
        }
        if (_selectedCostingFilter != 'all') {
          final method = resolveInventoryCostingMethod(productData: i);
          if (method.storageValue != _selectedCostingFilter) {
            return false;
          }
        }
        if (q.isEmpty) return true;
        final name = (i['name'] ?? '').toString().toLowerCase();
        final code = (i['code'] ?? '').toString().toLowerCase();
        final sku = (i['sku'] ?? '').toString().toLowerCase();
        final barcode = (i['barcode'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            code.contains(q) ||
            sku.contains(q) ||
            barcode.contains(q);
      }).toList()
        ..sort((a, b) {
          String sa;
          String sb;
          switch (_sortBy) {
            case 'deliveryType':
              sa = (a['delivery_type'] ?? '').toString().toLowerCase();
              sb = (b['delivery_type'] ?? '').toString().toLowerCase();
              break;
            case 'driverName':
              sa = (a['driver_name'] ?? '').toString().toLowerCase();
              sb = (b['driver_name'] ?? '').toString().toLowerCase();
              break;
            case 'vehicleNumber':
              sa = (a['vehicle_number'] ?? '').toString().toLowerCase();
              sb = (b['vehicle_number'] ?? '').toString().toLowerCase();
              break;
            case 'stockDesc':
              final da = double.tryParse(
                      (a['stock'] ?? '0').toString().replaceAll(',', '.')) ??
                  0;
              final db = double.tryParse(
                      (b['stock'] ?? '0').toString().replaceAll(',', '.')) ??
                  0;
              return db.compareTo(da);
            default:
              sa = (a['name'] ?? '').toString().toLowerCase();
              sb = (b['name'] ?? '').toString().toLowerCase();
          }
          return sa.compareTo(sb);
        });
    });
  }

  Future<List<String>> _ensureDefaultNomenclatureCategories(
    String companyId, {
    required String userId,
  }) async {
    final merged = <String>{..._defaultNomenclatureCategories};
    final trimmedCompanyId = companyId.trim();
    if (trimmedCompanyId.isEmpty) {
      final list = merged.toList()..sort();
      return list;
    }
    try {
      final snap = await _firestore
          .collection('nomenclature_categories')
          .where('idCompany', isEqualTo: trimmedCompanyId)
          .get(const GetOptions(source: Source.serverAndCache));
      final existingTitles = <String>{};
      for (final doc in snap.docs) {
        final raw = doc.data();
        final data = Map<String, dynamic>.from(raw as Map);
        final title = (data['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        existingTitles.add(title);
        merged.add(title);
      }
      final missing = _defaultNomenclatureCategories
          .where((title) => !existingTitles.contains(title))
          .toList(growable: false);
      if (missing.isNotEmpty) {
        final batch = _firestore.batch();
        for (final title in missing) {
          final ref = _firestore.collection('nomenclature_categories').doc();
          batch.set(ref, {
            'idCompany': trimmedCompanyId,
            'title': title,
            'user_id': userId,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (_) {
      // Category registry can be unavailable for some roles.
    }
    final list = merged.toList()..sort();
    return list;
  }

  Future<List<String>> _loadNomenclatureCategories({
    required List<String> seededCategories,
    required List<Map<String, dynamic>> items,
  }) async {
    final merged = <String>{...seededCategories};
    for (final item in items) {
      final title = (item['category'] ?? '').toString().trim();
      if (title.isNotEmpty) {
        merged.add(title);
      }
    }
    final list = merged.toList()..sort();
    return list;
  }

  Future<void> _addNomenclatureCategory() async {
    final title = _newCategoryController.text.trim();
    if (title.isEmpty || _companyId.trim().isEmpty) return;
    if (_nomenclatureCategories.contains(title)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Такая категория уже есть')),
      );
      return;
    }
    await _firestore.collection('nomenclature_categories').add({
      'idCompany': _companyId.trim(),
      'title': title,
      'user_id': _userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    _newCategoryController.clear();
    await _loadItems();
    if (!mounted) return;
    setState(() {
      _selectedCategory = title;
    });
    _applySearch();
  }

  int get _totalCount => _items.length;
  double get _totalStockSum =>
      _items.fold(0, (s, i) => s + ((i['stock_value'] ?? 0).toDouble()));

  int get _attentionCount {
    return _items.where((i) {
      final stock = (i['stock'] ?? 0).toDouble();
      final min = (i['min_stock'] ?? 0).toDouble();
      return stock <= min;
    }).length;
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  String _groupDigits(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    var start = digits.length % 3;
    if (start == 0) start = 3;
    buffer.write(digits.substring(0, start));
    for (var i = start; i < digits.length; i += 3) {
      buffer.write(' ');
      buffer.write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }

  Future<void> _showAddProductDialog() async {
    final companyId =
        _companyId.isNotEmpty ? _companyId : _effectiveCompanyId();
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        onSaved: _loadItems,
        companyId: companyId,
        userId: _userId,
        categories: _nomenclatureCategories,
        defaultCategory: _selectedCategory == 'all'
            ? _defaultNomenclatureCategories.first
            : _selectedCategory,
        industryScenario: _industryScenario,
      ),
    );
  }

  Future<void> _showEditProductDialog(Map<String, dynamic> item) async {
    if (!EditingHelper.guardEdit(context, section: EditSection.goods)) return;
    showDialog(
      context: context,
      builder: (context) => EditProductDialog(
        item: item,
        onSaved: _loadItems,
        companyId: _companyId,
        userId: _userId,
        categories: _nomenclatureCategories,
        industryScenario: _industryScenario,
      ),
    );
  }

  Future<void> _showBulkCostingMethodDialog() async {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет товаров для изменения')),
      );
      return;
    }

    var selectedMethod = _selectedCostingFilter == 'WEIGHTED_AVERAGE'
        ? InventoryCostingMethod.weightedAverage
        : InventoryCostingMethod.fifo;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Изменить метод списания'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Будет обновлено товаров: ${_filtered.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InventoryCostingMethod>(
                initialValue: selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Новый метод списания',
                  border: OutlineInputBorder(),
                ),
                items: _inventoryCostingOptions
                    .map(
                      (method) => DropdownMenuItem<InventoryCostingMethod>(
                        value: method,
                        child: Text(_inventoryCostingLabel(method)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setLocalState(() => selectedMethod = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final effectiveCompanyId = _effectiveCompanyId();
    final affectedCount = _filtered.length;
    final batch = _firestore.batch();
    for (final item in _filtered) {
      final id = (item['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      batch.update(
        _firestore.collection('nomenklatura').doc(id),
        buildInventoryCostingMethodPatch(costingMethod: selectedMethod),
      );
    }
    await batch.commit();
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('nomenklatura', effectiveCompanyId);
    await _loadItems();
    if (!mounted) return;
    setState(() => _selectedCostingFilter = selectedMethod.storageValue);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Метод списания обновлён для $affectedCount товаров',
        ),
      ),
    );
  }

  Future<void> _showAddBatchDialog() async {
    showDialog(
      context: context,
      builder: (context) => AddBatchDialog(
        onSaved: _loadItems,
        companyId: _companyId,
        userId: _userId,
      ),
    );
  }

  Future<List<String>> _loadWarehouseOptionsForImport(String companyId) async {
    final options = <String>[..._warehouseTypeOptions];
    if (companyId.trim().isEmpty) return options;
    try {
      final snap = await _firestore
          .collection('warehouses')
          .where('idCompany', isEqualTo: companyId.trim())
          .getCached();
      final seen = <String>{...options};
      for (final doc in snap.docs) {
        final raw = doc.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        final name = (data['name'] ?? '').toString().trim();
        if (name.isNotEmpty && !seen.contains(name)) {
          options.add(name);
          seen.add(name);
        }
      }
    } catch (_) {}
    return options;
  }

  String _normalizeImportHeader(String input) {
    final h = input.trim().toLowerCase().replaceAll(' ', '');
    switch (h) {
      case 'наименование':
      case 'name':
        return 'name';
      case 'артикул':
      case 'sku':
      case 'article':
        return 'sku';
      case 'код':
      case 'code':
        return 'code';
      case 'тип':
      case 'type':
        return 'type';
      case 'категория':
      case 'номенклатура':
      case 'category':
        return 'category';
      case 'штрихкод':
      case 'barcode':
        return 'barcode';
      case 'ценазакупки':
      case 'purchaseprice':
      case 'purchase_price':
        return 'purchase_price';
      case 'ценапродажи':
      case 'saleprice':
      case 'sale_price':
        return 'sale_price';
      case 'остаток':
      case 'количество':
      case 'qty':
      case 'stock':
        return 'stock';
      case 'миностаток':
      case 'minstock':
      case 'min_stock':
        return 'min_stock';
      default:
        return h;
    }
  }

  List<String> _parseCsvLine(String line, String delimiter) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && ch == delimiter) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  Future<_FileImportResult> _importProductsFromCsvBytes({
    required Uint8List bytes,
    required String warehouse,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    final companyId =
        _companyId.isNotEmpty ? _companyId : _effectiveCompanyId();
    if (companyId.trim().isEmpty) throw Exception('Не определена компания');
    final userId = _userId.isNotEmpty ? _userId : user.uid;

    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = latin1.decode(bytes, allowInvalid: true);
    }

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.length < 2) {
      throw Exception('Файл пустой или не содержит строк данных');
    }

    final headerLine = lines.first;
    final delimiter =
        ';'.allMatches(headerLine).length >= ','.allMatches(headerLine).length
            ? ';'
            : ',';
    final headers = _parseCsvLine(headerLine, delimiter)
        .map(_normalizeImportHeader)
        .toList();

    var added = 0;
    var updated = 0;
    var skipped = 0;
    final mode = FFAppState().accountingMode;

    for (var rowIndex = 1; rowIndex < lines.length; rowIndex++) {
      final cells = _parseCsvLine(lines[rowIndex], delimiter);
      final row = <String, String>{};
      for (var i = 0; i < headers.length && i < cells.length; i++) {
        row[headers[i]] = cells[i].trim();
      }

      final name = (row['name'] ?? '').trim();
      if (name.isEmpty) {
        skipped++;
        continue;
      }

      final purchase =
          product_catalog.toNumFlexible(row['purchase_price'] ?? '');
      final sale = product_catalog.toNumFlexible(row['sale_price'] ?? '');
      final stockDelta = product_catalog.toNumFlexible(row['stock'] ?? '');
      final minStock = product_catalog.toNumFlexible(row['min_stock'] ?? '');
      final type = (row['type'] ?? 'Товар').trim();
      final category = (row['category'] ?? 'Товары').trim();
      var sku = (row['sku'] ?? '').trim();
      final code = (row['code'] ?? '').trim();
      final barcode = (row['barcode'] ?? '').trim();

      if (sku.isEmpty) {
        final generated = await product_catalog.generateUniqueArticleCode(
          _firestore,
          companyId,
          warehouse: warehouse,
        );
        if (generated == null) {
          skipped++;
          continue;
        }
        sku = generated;
      }

      DocumentSnapshot<Object?>? existing;
      final bySku = await _firestore
          .collection('nomenklatura')
          .where('idCompany', isEqualTo: companyId)
          .where('sku', isEqualTo: sku)
          .getCached();
      final bySkuPick =
          product_catalog.pickByWarehouseContour(bySku, warehouse);
      if (bySkuPick != null) {
        existing = bySkuPick;
      } else if (code.isNotEmpty) {
        final byCode = await _firestore
            .collection('nomenklatura')
            .where('idCompany', isEqualTo: companyId)
            .where('code', isEqualTo: code)
            .getCached();
        final byCodePick =
            product_catalog.pickByWarehouseContour(byCode, warehouse);
        if (byCodePick != null) {
          existing = byCodePick;
        }
      }

      if (existing != null) {
        final raw = existing.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        final prevStock = (data['stock'] ?? 0).toDouble();
        final nextStock = prevStock + stockDelta;
        final nextPurchase =
            purchase > 0 ? purchase : (data['purchase_price'] ?? 0).toDouble();
        final nextSale = sale > 0 ? sale : (data['sale_price'] ?? 0).toDouble();

        await existing.reference.update(
          buildNomenclatureProductPayload(
            companyId: companyId,
            userId: userId,
            name: name,
            code: code.isEmpty ? (data['code'] ?? '').toString() : code,
            type: type.isEmpty ? (data['type'] ?? 'Товар').toString() : type,
            category: category.isEmpty
                ? (data['category'] ?? 'Товары').toString()
                : category,
            sku: sku,
            barcode:
                barcode.isEmpty ? (data['barcode'] ?? '').toString() : barcode,
            warehouse: warehouse,
            purchaseText: nextPurchase.toString(),
            saleText: nextSale.toString(),
            stockText: nextStock.toString(),
            minStockText:
                (minStock > 0 ? minStock : (data['min_stock'] ?? 0)).toString(),
            sourceType: _sourceTypeExcel,
            accountingMode: mode,
            isCreate: false,
          ),
        );
        updated++;

        if (stockDelta > 0) {
          await _firestore.collection('warehouse_movements').add(
                buildWarehouseMovementPayload(
                  companyId: companyId,
                  userId: userId,
                  userName: currentUserDocument?.displayName ??
                      user.displayName ??
                      user.email ??
                      '',
                  productId: existing.id,
                  productName: name,
                  productCode: code,
                  fromWarehouse: 'Импорт файла',
                  toWarehouse: warehouse,
                  qty: stockDelta,
                  extra: workflowMeta(
                    stage: AccountingWorkflowStage.warehouse,
                    accountingMode: mode,
                    status: AccountingWorkflowStatus.posted,
                  ),
                ),
              );
        }
      } else {
        final doc = await _firestore.collection('nomenklatura').add(
              buildNomenclatureProductPayload(
                companyId: companyId,
                userId: userId,
                name: name,
                code: code,
                type: type.isEmpty ? 'Товар' : type,
                category: category.isEmpty ? 'Товары' : category,
                sku: sku,
                barcode: barcode,
                warehouse: warehouse,
                purchaseText: purchase.toString(),
                saleText: sale.toString(),
                stockText: stockDelta.toString(),
                minStockText: minStock.toString(),
                sourceType: _sourceTypeExcel,
                accountingMode: mode,
                isCreate: true,
              ),
            );
        added++;

        if (stockDelta > 0) {
          await _firestore.collection('warehouse_movements').add(
                buildWarehouseMovementPayload(
                  companyId: companyId,
                  userId: userId,
                  userName: currentUserDocument?.displayName ??
                      user.displayName ??
                      user.email ??
                      '',
                  productId: doc.id,
                  productName: name,
                  productCode: code,
                  fromWarehouse: 'Импорт файла',
                  toWarehouse: warehouse,
                  qty: stockDelta,
                  extra: workflowMeta(
                    stage: AccountingWorkflowStage.warehouse,
                    accountingMode: mode,
                    status: AccountingWorkflowStatus.posted,
                  ),
                ),
              );
        }
      }
    }

    FirestoreQueryCache.instance
        .invalidateCompanyCollection('nomenklatura', companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('warehouse_movements', companyId);
    await _loadItems();
    return _FileImportResult(added: added, updated: updated, skipped: skipped);
  }

  Future<void> _showImportFromFileDialog() async {
    final companyId =
        _companyId.isNotEmpty ? _companyId : _effectiveCompanyId();
    final warehouseOptions = await _loadWarehouseOptionsForImport(companyId);
    if (!mounted) return;

    String selectedWarehouse = warehouseOptions.first;
    String selectedFile = '';
    Uint8List? selectedBytes;
    bool importing = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Загрузка товаров из файла'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Поддерживается CSV (.csv, .txt). Первая строка должна быть заголовком.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedWarehouse,
                  decoration: const InputDecoration(
                    labelText: 'Склад назначения',
                    border: OutlineInputBorder(),
                  ),
                  items: warehouseOptions
                      .map((w) => DropdownMenuItem<String>(
                            value: w,
                            child: Text(w),
                          ))
                      .toList(),
                  onChanged: (v) => setLocalState(
                    () => selectedWarehouse = v ?? selectedWarehouse,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: importing
                      ? null
                      : () async {
                          final picked = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            withData: true,
                            allowedExtensions: const ['csv', 'txt'],
                          );
                          if (picked == null || picked.files.isEmpty) return;
                          final file = picked.files.first;
                          if (file.bytes == null || file.bytes!.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Не удалось прочитать файл'),
                              ),
                            );
                            return;
                          }
                          setLocalState(() {
                            selectedFile = file.name;
                            selectedBytes = file.bytes;
                          });
                        },
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    selectedFile.isEmpty
                        ? 'Выбрать файл'
                        : 'Файл: $selectedFile',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: importing ? null : () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: importing || selectedBytes == null
                  ? null
                  : () async {
                      setLocalState(() => importing = true);
                      final messenger = ScaffoldMessenger.of(this.context);
                      try {
                        final result = await _importProductsFromCsvBytes(
                          bytes: selectedBytes!,
                          warehouse: selectedWarehouse,
                        );
                        if (!dialogContext.mounted || !this.context.mounted) {
                          return;
                        }
                        Navigator.pop(dialogContext);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Импорт завершён: добавлено ${result.added}, обновлено ${result.updated}, пропущено ${result.skipped}',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        setLocalState(() => importing = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка импорта: $e')),
                        );
                      }
                    },
              child: importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Загрузить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionsHelper.has('nomenclature.view')) {
      return PermissionsHelper.noAccess();
    }
    final isEmbedded = widget.embedded;
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
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
                    child: const Icon(Icons.inventory_2_outlined,
                        color: Color(0xFF9E7B4F)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Список товаров',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Все товары компании',
                          style: TextStyle(
                            fontSize: 13,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showAddProductDialog();
                      widget.onAddProduct?.call();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Добавить товар'),
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
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showAddBatchDialog();
                      widget.onAddBatch?.call();
                    },
                    icon: const Icon(Icons.add_box_outlined, size: 16),
                    label: const Text('Добавить партию'),
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
                  OutlinedButton.icon(
                    onPressed: _showImportFromFileDialog,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Загрузить файл'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E40AF),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _showBulkCostingMethodDialog,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Метод списания'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF99F6E4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!isEmbedded) const SizedBox(height: 12),
          if (!isEmbedded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _statCard(
                    title: 'Позиции номенклатуры',
                    value: '$_totalCount',
                    icon: Icons.inventory_2,
                    iconBg: FlutterFlowTheme.of(context).accent1,
                    iconColor: FlutterFlowTheme.of(context).primary,
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    title: 'Сумма остатков',
                    value: _formatMoney(_totalStockSum),
                    icon: Icons.attach_money,
                    iconBg: FlutterFlowTheme.of(context)
                        .success
                        .withValues(alpha: 0.14),
                    iconColor: FlutterFlowTheme.of(context).success,
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    title: 'Требуют внимания',
                    value: '$_attentionCount',
                    sub: 'Ниже минимума',
                    icon: Icons.inventory_2_outlined,
                    iconBg: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.14),
                    iconColor: FlutterFlowTheme.of(context).warning,
                  ),
                ],
              ),
            ),
          if (!isEmbedded) const SizedBox(height: 16),
          if (isEmbedded) const SizedBox(height: 12),
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
                        hintText:
                            'Поиск по наименованию, коду, артикулу или штрихкоду...',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Номенклатура',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('Все'),
                      ),
                      ..._nomenclatureCategories.map(
                        (cat) => DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _selectedCategory = val);
                      _applySearch();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedAccountingFilter,
                    decoration: const InputDecoration(
                      labelText: 'Контур учета',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('Все'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Up1',
                        child: Text('Управленческий (С)'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Bu',
                        child: Text('Бухгалтерский'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _selectedAccountingFilter = val);
                      if (val != 'all') {
                        FFAppState().update(() {
                          FFAppState().accountingMode = val;
                        });
                      }
                      _applySearch();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCostingFilter,
                    decoration: const InputDecoration(
                      labelText: 'Метод списания',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('Все'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'FIFO',
                        child: Text('FIFO'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'WEIGHTED_AVERAGE',
                        child: Text('Средневзвешенная'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _selectedCostingFilter = val);
                      _applySearch();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _newCategoryController,
                    decoration: const InputDecoration(
                      labelText: 'Добавить категорию',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onFieldSubmitted: (_) => _addNomenclatureCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addNomenclatureCategory,
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DropdownButtonFormField<String>(
              initialValue: _sortBy,
              decoration: const InputDecoration(
                labelText: 'Сортировка товаров',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'nameAsc',
                  child: Text('По названию'),
                ),
                DropdownMenuItem(
                  value: 'deliveryType',
                  child: Text('По типу доставки'),
                ),
                DropdownMenuItem(
                  value: 'driverName',
                  child: Text('По водителю'),
                ),
                DropdownMenuItem(
                  value: 'vehicleNumber',
                  child: Text('По номеру машины'),
                ),
                DropdownMenuItem(
                  value: 'stockDesc',
                  child: Text('По остатку (убыв.)'),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() => _sortBy = val);
                _applySearch();
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildProductsColumnsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsColumnsView() {
    final official = _sortOfficial(
      _filtered.where(_isOfficialItem).toList(),
    );
    final unofficial = _sortUnofficial(
      _filtered.where((i) => !_isOfficialItem(i)).toList(),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _officialSortBy,
                  decoration: const InputDecoration(
                    labelText: 'Сортировка официальных',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'invoiceDateDesc',
                      child: Text('По дате накладной (новые)'),
                    ),
                    DropdownMenuItem(
                      value: 'invoiceDateAsc',
                      child: Text('По дате накладной (старые)'),
                    ),
                    DropdownMenuItem(
                      value: 'gtd',
                      child: Text('По ГТД'),
                    ),
                    DropdownMenuItem(
                      value: 'invoice',
                      child: Text('По накладной'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _officialSortBy = v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unofficialSortBy,
                  decoration: const InputDecoration(
                    labelText: 'Сортировка неофициальных',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'deliveryType',
                      child: Text('По типу доставки'),
                    ),
                    DropdownMenuItem(
                      value: 'driverName',
                      child: Text('По водителю'),
                    ),
                    DropdownMenuItem(
                      value: 'vehicleNumber',
                      child: Text('По гос. номеру'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _unofficialSortBy = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 980;
                if (narrow) {
                  return ListView(
                    children: [
                      _productsColumn(
                        'Официальные товары',
                        official,
                        collapsed: _collapseOfficialProducts,
                        onToggleCollapse: (value) {
                          setState(() => _collapseOfficialProducts = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _productsColumn(
                        'Неофициальные товары',
                        unofficial,
                        collapsed: _collapseUnofficialProducts,
                        onToggleCollapse: (value) {
                          setState(() => _collapseUnofficialProducts = value);
                        },
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: _productsColumn(
                          'Официальные товары',
                          official,
                          collapsed: _collapseOfficialProducts,
                          onToggleCollapse: (value) {
                            setState(() => _collapseOfficialProducts = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _productsColumn(
                          'Неофициальные товары',
                          unofficial,
                          collapsed: _collapseUnofficialProducts,
                          onToggleCollapse: (value) {
                            setState(() => _collapseUnofficialProducts = value);
                          },
                        ),
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

  DateTime? _parseAnyDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
    final m =
        RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$').firstMatch(raw);
    if (m != null) {
      final d = int.tryParse(m.group(1) ?? '') ?? 1;
      final mo = int.tryParse(m.group(2) ?? '') ?? 1;
      var y = int.tryParse(m.group(3) ?? '') ?? 2000;
      if (y < 100) y += 2000;
      return DateTime(y, mo, d);
    }
    return null;
  }

  List<Map<String, dynamic>> _sortOfficial(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      switch (_officialSortBy) {
        case 'gtd':
          return (a['gtd_number'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['gtd_number'] ?? '').toString().toLowerCase());
        case 'invoice':
          return (a['invoice_number'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['invoice_number'] ?? '').toString().toLowerCase());
        case 'invoiceDateAsc':
        case 'invoiceDateDesc':
          final da = _parseAnyDate(a['invoice_date']) ?? DateTime(1970);
          final db = _parseAnyDate(b['invoice_date']) ?? DateTime(1970);
          return _officialSortBy == 'invoiceDateAsc'
              ? da.compareTo(db)
              : db.compareTo(da);
        default:
          return (a['name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['name'] ?? '').toString().toLowerCase());
      }
    });
    return list;
  }

  List<Map<String, dynamic>> _sortUnofficial(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      switch (_unofficialSortBy) {
        case 'driverName':
          return (a['driver_name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['driver_name'] ?? '').toString().toLowerCase());
        case 'vehicleNumber':
          return (a['vehicle_number'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['vehicle_number'] ?? '').toString().toLowerCase());
        case 'deliveryType':
        default:
          return (a['delivery_type'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['delivery_type'] ?? '').toString().toLowerCase());
      }
    });
    return list;
  }

  Widget _productsColumn(
    String title,
    List<Map<String, dynamic>> items, {
    required bool collapsed,
    required ValueChanged<bool> onToggleCollapse,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Expanded(
                child: Text(
                  '$title (${items.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Свернуть',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 4),
                  Switch.adaptive(
                    value: collapsed,
                    onChanged: onToggleCollapse,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                items.isEmpty
                    ? 'Товаров нет'
                    : 'Список свернут (${items.length})',
                style: TextStyle(
                    color: FlutterFlowTheme.of(context).secondaryText),
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Товаров нет',
                style: TextStyle(
                    color: FlutterFlowTheme.of(context).secondaryText),
              ),
            )
          else
            ...items.map(_productExpandableCard),
        ],
      ),
    );
  }

  bool _isOfficialItem(Map<String, dynamic> item) {
    return warehouseTypeFromData(item).isOfficial;
  }

  String _productId(Map<String, dynamic> item) {
    return (item['id'] ?? item['sku'] ?? item['code'] ?? item['name'] ?? '')
        .toString();
  }

  String _productCostingLabel(Map<String, dynamic> item) {
    return _inventoryCostingLabel(
      resolveInventoryCostingMethod(productData: item),
    );
  }

  Widget _productExpandableCard(Map<String, dynamic> item) {
    final id = _productId(item);
    final expanded = _expandedProductIds.contains(id);
    final stock = _toDouble(item['stock']);
    final minStock = _toDouble(item['min_stock']);
    final lowStock = stock <= minStock;
    final isOfficial = _isOfficialItem(item);
    final sourceShort = product_catalog.productSourceShort(item);
    final sourceFull = product_catalog.productSourceFull(item);
    final title = (item['name'] ?? 'Без названия').toString();
    final sku = (item['sku'] ?? '-').toString();
    final costingLabel = _productCostingLabel(item);
    final industryKind = industryItemKindFromData(item);
    final industryLabel = industryItemKindLabel(industryKind);

    return LiveDiffHighlight(
      timestamp: item['updated_at'] ?? item['created_at'],
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (expanded) {
                    _expandedProductIds.remove(id);
                  } else {
                    _expandedProductIds.add(id);
                  }
                });
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Артикул: $sku',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText),
                          ),
                          Text(
                            'Списание: $costingLabel',
                            style: TextStyle(
                              fontSize: 11,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                          Text(
                            'Тип: $industryLabel',
                            style: TextStyle(
                              fontSize: 11,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                          if (isOfficial && sourceShort != '-')
                            Text(
                              'Источник: $sourceShort',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: lowStock
                            ? FlutterFlowTheme.of(context)
                                .error
                                .withValues(alpha: 0.14)
                            : FlutterFlowTheme.of(context)
                                .success
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${stock.toStringAsFixed(0)} шт',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: lowStock
                              ? FlutterFlowTheme.of(context).error
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Редактировать товар',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showEditProductDialog(item),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _detailChip('Код: ${(item['code'] ?? '-').toString()}'),
                    _detailChip(
                        'Номенклатура: ${(item['category'] ?? item['type'] ?? '-').toString()}'),
                    _detailChip('Отраслевой тип: $industryLabel'),
                    if ((item['object_name'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _detailChip(
                          'Объект: ${(item['object_name'] ?? '').toString()}'),
                    if ((item['unit_number'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _detailChip(
                          'Квартира: ${(item['unit_number'] ?? '').toString()}'),
                    if ((item['batch_number'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _detailChip(
                          'Партия: ${(item['batch_number'] ?? '').toString()}'),
                    _detailChip(
                        'Склад: ${(item['warehouse'] ?? 'Не указан').toString()}'),
                    _detailChip('Метод списания: $costingLabel'),
                    _detailChip(
                        'Закупка: ${_formatMoney(_toDouble(item['purchase_price']))}'),
                    _detailChip(
                        'Продажа: ${_formatMoney(_toDouble(item['sale_price']))}'),
                    if (isOfficial && sourceFull != '-')
                      _detailChip('Источник: $sourceFull'),
                    _detailChip(
                        'Мин. остаток: ${(item['min_stock'] ?? 0).toString()}'),
                    _detailChip(
                        'Тип доставки: ${(item['delivery_type'] ?? '-').toString()}'),
                    _detailChip(
                        'Водитель: ${(item['driver_name'] ?? '-').toString()}'),
                    _detailChip(
                        'Машина: ${(item['vehicle_number'] ?? '-').toString()}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, color: FlutterFlowTheme.of(context).primaryText),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    String? sub,
  }) {
    return Expanded(
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
                  if (sub != null) ...[
                    const SizedBox(height: 4),
                    Text(sub,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
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
}

class _FileImportResult {
  const _FileImportResult({
    required this.added,
    required this.updated,
    required this.skipped,
  });

  final int added;
  final int updated;
  final int skipped;
}

class AddProductDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final String companyId;
  final String userId;
  final List<String> categories;
  final String defaultCategory;
  final Map<String, dynamic> industryScenario;

  const AddProductDialog({
    super.key,
    required this.onSaved,
    required this.companyId,
    required this.userId,
    required this.categories,
    required this.defaultCategory,
    required this.industryScenario,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _name = TextEditingController();
  final _code = TextEditingController();
  final _type = TextEditingController(text: 'Товар');
  String _category = _defaultNomenclatureCategories.first;
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _warehouse = TextEditingController(text: 'Официальные товары');
  String _warehouseType = _warehouseTypeOptions.first;
  final _purchase = TextEditingController();
  final _sale = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '0');
  final _objectName = TextEditingController();
  final _unitNumber = TextEditingController();
  final _batchNumber = TextEditingController();
  late String _industryItemKind;
  InventoryCostingMethod _costingMethod = InventoryCostingMethod.fifo;

  bool _saving = false;
  String? _articleError;
  List<String> _companyOptions = [];
  final Map<String, String> _companyNames = {};
  String _selectedCompanyId = '';

  @override
  void initState() {
    super.initState();
    final fromDefault = widget.defaultCategory.trim();
    if (fromDefault.isNotEmpty) {
      _category = fromDefault;
    } else if (widget.categories.isNotEmpty) {
      _category = widget.categories.first;
    }
    _selectedCompanyId = _resolveCompanyId();
    _industryItemKind =
        (widget.industryScenario['industry_item_kind'] ?? kItemKindProduct)
            .toString();
    final label = industryItemKindLabel(_industryItemKind);
    if (_type.text.trim().isEmpty || _type.text.trim() == 'Товар') {
      _type.text = label;
    }
    _loadCompanyOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autofillArticleIfEmpty();
    });
  }

  String _resolveCompanyId() {
    if (_selectedCompanyId.trim().isNotEmpty) {
      return _selectedCompanyId.trim();
    }
    if (widget.companyId.isNotEmpty && widget.companyId != '__all__') {
      return widget.companyId;
    }
    final raw = (currentUserDocument?.idCompany ?? '').trim();
    if (raw.isNotEmpty && raw != '__all__') return raw;
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    if (active.isNotEmpty && active != '__all__') return active;
    final ids = currentUserDocument?.companyIds ?? const [];
    for (final id in ids) {
      final value = id.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return _auth.currentUser?.uid ?? '';
  }

  Future<void> _loadCompanyOptions() async {
    final options = <String>[];
    final seen = <String>{};

    void addId(String? raw) {
      final id = (raw ?? '').trim();
      if (id.isEmpty || id == '__all__' || seen.contains(id)) return;
      options.add(id);
      seen.add(id);
    }

    addId(widget.companyId);
    addId(currentUserDocument?.activeCompanyId);
    final rawCompany = (currentUserDocument?.idCompany ?? '').trim();
    if (rawCompany != '__all__') addId(rawCompany);
    for (final id in currentUserDocument?.companyIds ?? const []) {
      addId(id.toString());
    }
    addId(_auth.currentUser?.uid);

    final names = <String, String>{};
    for (final id in options) {
      var name = id;
      try {
        final doc = await _firestore.collection('companies').doc(id).get();
        if (doc.exists) {
          final raw = doc.data();
          final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
          final n = (data['name'] ?? data['title'] ?? '').toString().trim();
          if (n.isNotEmpty) name = n;
        }
      } catch (_) {}
      names[id] = name;
    }

    if (!mounted) return;
    setState(() {
      _companyOptions = options;
      _companyNames
        ..clear()
        ..addAll(names);
      if (_selectedCompanyId.isEmpty && _companyOptions.isNotEmpty) {
        _selectedCompanyId = _companyOptions.first;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _type.dispose();
    _sku.dispose();
    _barcode.dispose();
    _warehouse.dispose();
    _purchase.dispose();
    _sale.dispose();
    _stock.dispose();
    _minStock.dispose();
    _objectName.dispose();
    _unitNumber.dispose();
    _batchNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sku.text.trim().isEmpty) {
      await _autofillArticleIfEmpty();
    }
    if (!_formKey.currentState!.validate()) return;
    if (!await _ensureArticleUnique(_sku.text.trim())) {
      return;
    }
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      final effectiveCompanyId = _resolveCompanyId();

      final payload = buildNomenclatureProductPayload(
        companyId: effectiveCompanyId,
        userId: widget.userId.isEmpty ? user.uid : widget.userId,
        name: _name.text,
        code: _code.text,
        type: _type.text,
        category: _category,
        sku: _sku.text,
        barcode: _barcode.text,
        warehouse: _warehouse.text,
        purchaseText: _purchase.text,
        saleText: _sale.text,
        stockText: _stock.text,
        minStockText: _minStock.text,
        sourceType: _sourceTypeManual,
        accountingMode: FFAppState().accountingMode,
        costingMethod: _costingMethod,
        extra: _industryExtraPayload(),
        isCreate: true,
      );
      final doc = await _firestore.collection('nomenklatura').add(payload);
      await AuditLogService.logAction(
        companyId: effectiveCompanyId,
        action: 'create',
        entity: 'product',
        entityId: doc.id,
        entityTitle: _name.text,
        after: payload,
        details: const {'message': 'Создан товар/услуга'},
      );

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('nomenklatura', effectiveCompanyId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error saving product: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _industryExtraPayload() {
    final requiresWarehouse =
        widget.industryScenario['requires_warehouse'] != false;
    final usesBatches = widget.industryScenario['uses_batches'] == true;
    final usesPaymentSchedule =
        widget.industryScenario['uses_payment_schedule'] == true;
    final usesReceivables = widget.industryScenario['uses_receivables'] == true;
    return {
      'industry_item_kind': _industryItemKind,
      'item_kind':
          _industryItemKind == kItemKindService ? 'service' : 'product',
      'requires_warehouse': requiresWarehouse,
      'uses_batches': usesBatches,
      'uses_payment_schedule': usesPaymentSchedule,
      'uses_receivables': usesReceivables,
      'uses_contract_discounts':
          widget.industryScenario['uses_contract_discounts'] == true,
      if (_objectName.text.trim().isNotEmpty)
        'object_name': _objectName.text.trim(),
      if (_unitNumber.text.trim().isNotEmpty)
        'unit_number': _unitNumber.text.trim(),
      if (_batchNumber.text.trim().isNotEmpty)
        'batch_number': _batchNumber.text.trim(),
    };
  }

  Widget _articleGeneratorIcon() {
    return IconButton(
      icon: const Icon(Icons.shuffle),
      tooltip: 'Сгенерировать артикул',
      onPressed: _onGenerateArticlePressed,
    );
  }

  Future<void> _onGenerateArticlePressed() async {
    await _autofillArticleIfEmpty(force: true);
  }

  Future<void> _autofillArticleIfEmpty({bool force = false}) async {
    if (!force && _sku.text.trim().isNotEmpty) return;
    final companyId = _resolveCompanyId();
    if (companyId.isEmpty) return;
    final generated = await product_catalog.generateUniqueArticleCode(
      _firestore,
      companyId,
      warehouse: _warehouse.text.trim(),
    );
    if (generated == null) {
      if (!mounted && !force) return;
      if (force && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось найти уникальный артикул')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _sku.text = generated;
      _articleError = null;
    });
  }

  Future<bool> _ensureArticleUnique(String article) async {
    final companyId = _resolveCompanyId();
    if (companyId.isEmpty || article.trim().isEmpty) return true;
    try {
      final existing = await product_catalog.findProductByArticleForCompany(
        _firestore,
        companyId,
        article.trim(),
        warehouse: _warehouse.text.trim(),
      );
      final exists = existing != null;
      final message = exists ? 'Артикул уже используется' : null;
      if (mounted) {
        setState(() => _articleError = message);
      }
      if (exists) {
        if (!mounted) return false;
        final action = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Артикул уже используется'),
            content: const Text(
              'По этому артикулу уже есть товар. Заполнить карточку по найденному товару или ввести другой артикул?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'other'),
                child: const Text('Другой артикул'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, 'fill'),
                child: const Text('Заполнить карточку'),
              ),
            ],
          ),
        );
        if (action == 'fill') {
          final raw = existing.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          if (!mounted) return false;
          setState(() {
            _warehouseType = _warehouseTypeOptionFromData(data);
            _applyProductData(data);
          });
          await _autofillArticleIfEmpty(force: true);
          if (!mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Карточка заполнена по найденному товару. Новый артикул сгенерирован автоматически.',
              ),
            ),
          );
        } else {
          _sku.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _sku.text.length,
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error checking article uniqueness: $e');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCompanyId = _resolveCompanyId();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth > 740;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).accent1,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_outlined,
                                color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Добавить товар',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        title: 'Основные данные',
                        child: twoColumns
                            ? Row(
                                children: [
                                  Expanded(child: _companyDropdown()),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _field(_name, 'Название',
                                        required: true),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _companyDropdown(),
                                  _field(_name, 'Название', required: true),
                                ],
                              ),
                      ),
                      _sectionCard(
                        title: 'Идентификация',
                        child: twoColumns
                            ? Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _field(_code, 'Код')),
                                      const SizedBox(width: 10),
                                      Expanded(child: _field(_type, 'Вид')),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _field(
                                          _sku,
                                          'Артикул',
                                          required: true,
                                          validator: (_) => _articleError,
                                          onChanged: (_) {
                                            if (_articleError != null) {
                                              setState(
                                                  () => _articleError = null);
                                            }
                                          },
                                          suffixIcon: _articleGeneratorIcon(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _field(
                                          _barcode,
                                          'Штрихкод',
                                          suffixIcon: _barcodeScannerIcon(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _categoryDropdown(),
                                ],
                              )
                            : Column(
                                children: [
                                  _field(_code, 'Код'),
                                  _field(_type, 'Вид'),
                                  _field(
                                    _sku,
                                    'Артикул',
                                    required: true,
                                    validator: (_) => _articleError,
                                    onChanged: (_) {
                                      if (_articleError != null) {
                                        setState(() => _articleError = null);
                                      }
                                    },
                                    suffixIcon: _articleGeneratorIcon(),
                                  ),
                                  _field(
                                    _barcode,
                                    'Штрихкод',
                                    suffixIcon: _barcodeScannerIcon(),
                                  ),
                                  _categoryDropdown(),
                                ],
                              ),
                      ),
                      _sectionCard(
                        title: 'Отраслевой сценарий',
                        child: Column(
                          children: [
                            _industryKindDropdown(),
                            if (_industryItemKind == kItemKindRealEstateUnit)
                              twoColumns
                                  ? Row(
                                      children: [
                                        Expanded(
                                            child:
                                                _field(_objectName, 'Объект')),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: _field(
                                                _unitNumber, 'Квартира')),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _field(_objectName, 'Объект'),
                                        _field(_unitNumber, 'Квартира'),
                                      ],
                                    ),
                            if (_industryItemKind ==
                                    kItemKindAgricultureBatch ||
                                _industryItemKind == kItemKindMaterial)
                              _field(_batchNumber, 'Партия / поставка'),
                          ],
                        ),
                      ),
                      _sectionCard(
                        title: 'Склад и цены',
                        child: Column(
                          children: [
                            if (twoColumns)
                              Row(
                                children: [
                                  Expanded(child: _warehouseTypeField()),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _warehouseDropdown(
                                          effectiveCompanyId, _warehouseType)),
                                ],
                              )
                            else ...[
                              _warehouseTypeField(),
                              _warehouseDropdown(
                                  effectiveCompanyId, _warehouseType),
                            ],
                            if (twoColumns)
                              Row(
                                children: [
                                  Expanded(
                                    child: _field(_purchase, 'Цена закупки',
                                        number: true,
                                        onChanged: (_) => setState(() {})),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _field(_sale, 'Цена продажи',
                                        number: true,
                                        onChanged: (_) => setState(() {})),
                                  ),
                                ],
                              )
                            else ...[
                              _field(_purchase, 'Цена закупки',
                                  number: true,
                                  onChanged: (_) => setState(() {})),
                              _field(_sale, 'Цена продажи',
                                  number: true,
                                  onChanged: (_) => setState(() {})),
                            ],
                            _costingMethodDropdown(
                              value: _costingMethod,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _costingMethod = value);
                              },
                            ),
                            _markupRatioPreview(_purchase.text, _sale.text),
                          ],
                        ),
                      ),
                      _sectionCard(
                        title: 'Остатки',
                        child: twoColumns
                            ? Row(
                                children: [
                                  Expanded(
                                      child: _field(_stock, 'Остаток',
                                          number: true)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _field(_minStock, 'Мин. остаток',
                                          number: true)),
                                ],
                              )
                            : Column(
                                children: [
                                  _field(_stock, 'Остаток', number: true),
                                  _field(_minStock, 'Мин. остаток',
                                      number: true),
                                ],
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
                              onPressed: _saving ? null : _submit,
                              child: _saving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Добавить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false,
      bool number = false,
      String? Function(String?)? validator,
      void Function(String)? onChanged,
      Widget? suffixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: suffixIcon,
        ),
        onChanged: onChanged,
        validator: (v) {
          if (required && (v == null || v.isEmpty)) return 'Обязательное поле';
          if (number &&
              v != null &&
              v.isNotEmpty &&
              double.tryParse(v.replaceAll(',', '.')) == null) {
            return 'Введите число';
          }
          if (validator != null) {
            return validator(v);
          }
          return null;
        },
      ),
    );
  }

  Widget _companyDropdown() {
    final options = _companyOptions.isNotEmpty
        ? _companyOptions
        : <String>[_resolveCompanyId()];
    final current = _selectedCompanyId.isNotEmpty
        ? _selectedCompanyId
        : (options.isNotEmpty ? options.first : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: current.isEmpty ? null : current,
        decoration: const InputDecoration(
          labelText: 'Фирма',
          border: OutlineInputBorder(),
        ),
        items: options
            .map(
              (id) => DropdownMenuItem<String>(
                value: id,
                child: Text(_companyNames[id] ?? id),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() => _selectedCompanyId = v);
          _autofillArticleIfEmpty();
        },
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Выберите фирму' : null,
      ),
    );
  }

  Widget _warehouseDropdown(String companyId, String warehouseType) {
    final current = _warehouse.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('warehouses')
            .where('idCompany', isEqualTo: companyId)
            .snapshots(),
        builder: (context, snapshot) {
          final items = <String>[warehouseType];
          final seen = <String>{warehouseType};
          if (snapshot.hasData) {
            for (final doc in snapshot.data!.docs) {
              final raw = doc.data();
              final data = raw is Map<String, dynamic>
                  ? raw
                  : Map<String, dynamic>.from(raw as Map);
              final name = (data['name'] ?? '').toString().trim();
              if (name.isEmpty) continue;
              if (_warehouseBelongsToType(data, warehouseType) &&
                  !seen.contains(name)) {
                items.add(name);
                seen.add(name);
              }
            }
          }
          if (current.isNotEmpty && !seen.contains(current)) {
            items.add(current);
            seen.add(current);
          }
          final available = items;
          if (_warehouse.text.trim().isEmpty && available.isNotEmpty) {
            _warehouse.text = warehouseType;
          }
          return DropdownButtonFormField<String>(
            initialValue:
                _warehouse.text.trim().isEmpty ? null : _warehouse.text.trim(),
            decoration: const InputDecoration(
              labelText: 'Склад',
              border: OutlineInputBorder(),
            ),
            items: available
                .map((v) => DropdownMenuItem<String>(
                      value: v,
                      child: Text(v),
                    ))
                .toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() => _warehouse.text = val);
            },
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Обязательное поле' : null,
          );
        },
      ),
    );
  }

  bool _warehouseBelongsToType(
      Map<String, dynamic> warehouseDoc, String warehouseType) {
    return _warehouseDocBelongsToType(warehouseDoc, warehouseType);
  }

  Widget _markupRatioPreview(String purchase, String sale) {
    final ratio = product_catalog.markupCoeffFromPrices(
      purchase,
      sale,
      warehouse: _warehouse.text,
    );
    final ready = ratio > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Коэффициент наценки',
          border: OutlineInputBorder(),
        ),
        child: Text(
          ready ? ratio.toStringAsFixed(0) : 'Заполните цену закупки и продажи',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ready
                ? const Color(0xFF1F2A37)
                : FlutterFlowTheme.of(context).secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _warehouseTypeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _warehouseTypeDropdown(
        value: _warehouseType,
        onChanged: (val) {
          if (val == null) return;
          setState(() {
            _warehouseType = val;
            _warehouse.text = val;
          });
        },
      ),
    );
  }

  Future<void> _openBarcodeScanner() async {
    final code = await showDialog<String?>(
      context: context,
      builder: (context) => const BarcodeScannerDialog(),
    );
    if (code == null || code.trim().isEmpty) return;
    final trimmed = code.trim();
    _barcode.text = trimmed;
    await _populateFromBarcode(trimmed);
  }

  Future<void> _populateFromBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return;
    try {
      final snap = await _firestore
          .collection('nomenklatura')
          .where('barcode', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Товар по такому штрихкоду не найден')),
        );
        return;
      }
      final data = snap.docs.first.data();
      if (!mounted) return;
      setState(() {
        _warehouseType = _warehouseTypeOptionFromData(data);
        _applyProductData(data);
      });
    } catch (e) {
      debugPrint('Error pre-filling product by barcode: $e');
    }
  }

  void _applyProductData(Map<String, dynamic> data) {
    final name = _valueToText(data['name']);
    if (name.isNotEmpty) _name.text = name;
    final code = _valueToText(data['code']);
    if (code.isNotEmpty) _code.text = code;
    final type = _valueToText(data['type']);
    if (type.isNotEmpty) _type.text = type;
    final sku = _valueToText(data['sku']);
    if (sku.isNotEmpty) _sku.text = sku;
    final warehouse = _valueToText(data['warehouse']);
    if (warehouse.isNotEmpty) _warehouse.text = warehouse;
    final barcode = _valueToText(data['barcode']);
    if (barcode.isNotEmpty) _barcode.text = barcode;
    final purchase = _valueToText(data['purchase_price']);
    if (purchase.isNotEmpty) _purchase.text = purchase;
    final sale = _valueToText(data['sale_price']);
    if (sale.isNotEmpty) _sale.text = sale;
    final stock = _valueToText(data['stock']);
    if (stock.isNotEmpty) _stock.text = stock;
    final minStock = _valueToText(data['min_stock']);
    if (minStock.isNotEmpty) _minStock.text = minStock;
    _articleError = null;
    final category = _valueToText(data['category']);
    if (category.isNotEmpty) {
      _category = category;
    }
  }

  String _valueToText(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    return value.toString().trim();
  }

  Widget _barcodeScannerIcon() {
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner),
      tooltip: 'Сканировать штрихкод',
      onPressed: _openBarcodeScanner,
    );
  }

  Widget _categoryDropdown() {
    final options = widget.categories.isEmpty
        ? _defaultNomenclatureCategories
        : widget.categories;
    final current = options.contains(_category) ? _category : options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: const InputDecoration(
          labelText: 'Номенклатура',
          border: OutlineInputBorder(),
        ),
        items: options
            .map(
              (value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val == null) return;
          setState(() => _category = val);
        },
      ),
    );
  }

  Widget _industryKindDropdown() {
    final current = kIndustryItemKindLabels.containsKey(_industryItemKind)
        ? _industryItemKind
        : kItemKindProduct;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: const InputDecoration(
          labelText: 'Тип номенклатуры',
          border: OutlineInputBorder(),
        ),
        items: kIndustryItemKindLabels.entries
            .map(
              (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _industryItemKind = value;
            _type.text = industryItemKindLabel(value);
            if (value == kItemKindService) {
              _stock.text = '0';
              _minStock.text = '0';
            }
          });
        },
      ),
    );
  }

  Widget _costingMethodDropdown({
    required InventoryCostingMethod value,
    required ValueChanged<InventoryCostingMethod?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<InventoryCostingMethod>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'Метод списания себестоимости',
          border: OutlineInputBorder(),
        ),
        items: _inventoryCostingOptions
            .map(
              (method) => DropdownMenuItem<InventoryCostingMethod>(
                value: method,
                child: Text(_inventoryCostingLabel(method)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class EditProductDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onSaved;
  final String companyId;
  final String userId;
  final List<String> categories;
  final Map<String, dynamic> industryScenario;

  const EditProductDialog({
    super.key,
    required this.item,
    required this.onSaved,
    required this.companyId,
    required this.userId,
    required this.categories,
    required this.industryScenario,
  });

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _type;
  late String _category;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _warehouse;
  late final TextEditingController _purchase;
  late final TextEditingController _sale;
  late final TextEditingController _stock;
  late final TextEditingController _minStock;
  late final TextEditingController _objectName;
  late final TextEditingController _unitNumber;
  late final TextEditingController _batchNumber;
  late String _industryItemKind;
  InventoryCostingMethod _costingMethod = InventoryCostingMethod.fifo;

  bool _saving = false;
  String _warehouseType = _warehouseTypeOptions.first;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: (widget.item['name'] ?? '').toString());
    _code = TextEditingController(text: (widget.item['code'] ?? '').toString());
    _type = TextEditingController(text: (widget.item['type'] ?? '').toString());
    _category = (widget.item['category'] ?? '').toString().trim();
    if (_category.isEmpty) {
      _category = _defaultNomenclatureCategories.first;
    }
    _sku = TextEditingController(text: (widget.item['sku'] ?? '').toString());
    _barcode =
        TextEditingController(text: (widget.item['barcode'] ?? '').toString());
    _warehouse = TextEditingController(
        text: (widget.item['warehouse'] ?? '').toString());
    _purchase = TextEditingController(
        text: (widget.item['purchase_price'] ?? 0).toString());
    _sale = TextEditingController(
        text: (widget.item['sale_price'] ?? 0).toString());
    _stock =
        TextEditingController(text: (widget.item['stock'] ?? 0).toString());
    _minStock =
        TextEditingController(text: (widget.item['min_stock'] ?? 0).toString());
    _objectName = TextEditingController(
        text: (widget.item['object_name'] ?? '').toString());
    _unitNumber = TextEditingController(
        text: (widget.item['unit_number'] ?? '').toString());
    _batchNumber = TextEditingController(
        text: (widget.item['batch_number'] ?? '').toString());
    _industryItemKind = industryItemKindFromData({
      ...widget.industryScenario,
      ...widget.item,
    });
    _costingMethod = resolveInventoryCostingMethod(productData: widget.item);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _determineWarehouseType());
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _type.dispose();
    _sku.dispose();
    _barcode.dispose();
    _warehouse.dispose();
    _purchase.dispose();
    _sale.dispose();
    _stock.dispose();
    _minStock.dispose();
    _objectName.dispose();
    _unitNumber.dispose();
    _batchNumber.dispose();
    super.dispose();
  }

  double _toNum(String v) {
    return double.tryParse(v.replaceAll(',', '.')) ?? 0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');
      final currentUserCompany = currentUserDocument?.idCompany.trim() ?? '';

      final effectiveCompanyId = widget.companyId.isNotEmpty
          ? widget.companyId
          : currentUserCompany.isNotEmpty
              ? currentUserCompany
              : user.uid;

      final purchase = _toNum(_purchase.text);
      final stock = _toNum(_stock.text);

      final payload = buildNomenclatureProductPayload(
        companyId: effectiveCompanyId,
        userId: widget.userId.isEmpty ? user.uid : widget.userId,
        name: _name.text,
        code: _code.text,
        type: _type.text,
        category: _category,
        sku: _sku.text,
        barcode: _barcode.text,
        warehouse: _warehouse.text,
        purchaseText: purchase.toString(),
        saleText: _sale.text,
        stockText: stock.toString(),
        minStockText: _minStock.text,
        sourceType: _sourceTypeManual,
        accountingMode: normalizeLegacyTypeUchet(
            (widget.item['accounting_mode'] ?? '').toString()),
        costingMethod: _costingMethod,
        extra: _industryExtraPayload(),
        isCreate: false,
      );
      await _firestore
          .collection('nomenklatura')
          .doc(widget.item['id'])
          .update(payload);
      await AuditLogService.logAction(
        companyId: effectiveCompanyId,
        action: 'update',
        entity: 'product',
        entityId: (widget.item['id'] ?? '').toString(),
        entityTitle: _name.text,
        before: widget.item,
        after: payload,
        details: const {'message': 'Изменен товар/услуга'},
      );

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('nomenklatura', effectiveCompanyId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error updating product: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _industryExtraPayload() {
    final requiresWarehouse =
        widget.industryScenario['requires_warehouse'] != false;
    return {
      'industry_item_kind': _industryItemKind,
      'item_kind':
          _industryItemKind == kItemKindService ? 'service' : 'product',
      'requires_warehouse': requiresWarehouse,
      'uses_batches': widget.industryScenario['uses_batches'] == true,
      'uses_payment_schedule':
          widget.industryScenario['uses_payment_schedule'] == true,
      'uses_receivables': widget.industryScenario['uses_receivables'] == true,
      'uses_contract_discounts':
          widget.industryScenario['uses_contract_discounts'] == true,
      if (_objectName.text.trim().isNotEmpty)
        'object_name': _objectName.text.trim(),
      if (_unitNumber.text.trim().isNotEmpty)
        'unit_number': _unitNumber.text.trim(),
      if (_batchNumber.text.trim().isNotEmpty)
        'batch_number': _batchNumber.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCompanyId = _effectiveCompanyId();
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
                const Text('Редактировать товар',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _field(_name, 'Название', required: true),
                _field(_code, 'Код'),
                _field(_type, 'Вид'),
                _industryKindDropdown(),
                if (_industryItemKind == kItemKindRealEstateUnit) ...[
                  _field(_objectName, 'Объект'),
                  _field(_unitNumber, 'Квартира'),
                ],
                if (_industryItemKind == kItemKindAgricultureBatch ||
                    _industryItemKind == kItemKindMaterial)
                  _field(_batchNumber, 'Партия / поставка'),
                _categoryDropdown(),
                _field(_sku, 'Артикул'),
                _field(_barcode, 'Штрихкод'),
                _warehouseTypeDropdown(
                  value: _warehouseType,
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _warehouseType = val;
                      _warehouse.text = val;
                    });
                  },
                ),
                _warehouseDropdown(effectiveCompanyId, _warehouseType),
                _field(_purchase, 'Цена закупки',
                    number: true, onChanged: (_) => setState(() {})),
                _costingMethodDropdown(
                  value: _costingMethod,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _costingMethod = value);
                  },
                ),
                _markupRatioPreview(_purchase.text, _sale.text),
                _field(_sale, 'Цена продажи',
                    number: true, onChanged: (_) => setState(() {})),
                _field(_stock, 'Остаток', number: true),
                _field(_minStock, 'Мин. остаток', number: true),
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
      {bool required = false,
      bool number = false,
      void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
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

  Widget _markupRatioPreview(String purchase, String sale) {
    final ratio = product_catalog.markupCoeffFromPrices(
      purchase,
      sale,
      warehouse: _warehouse.text,
    );
    final ready = ratio > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Коэффициент наценки',
          border: OutlineInputBorder(),
        ),
        child: Text(
          ready ? ratio.toStringAsFixed(0) : 'Заполните цену закупки и продажи',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ready
                ? const Color(0xFF1F2A37)
                : FlutterFlowTheme.of(context).secondaryText,
          ),
        ),
      ),
    );
  }

  String _effectiveCompanyId() {
    final user = _auth.currentUser;
    if (widget.companyId.isNotEmpty) return widget.companyId;
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user?.uid ?? '',
    );
  }

  Future<void> _determineWarehouseType() async {
    final companyId = _effectiveCompanyId();
    final warehouseName = _warehouse.text.trim();
    final explicitType = warehouseTypeFromExplicitValue(
      (widget.item['warehouseType'] ?? widget.item['warehouse_type'])
          ?.toString(),
      isOfficial: widget.item['isOfficial'] ??
          widget.item['is_official'] ??
          widget.item['official'],
    );
    String resolved = explicitType != null
        ? _warehouseTypeOption(explicitType)
        : _warehouseTypeOptions.first;
    if (explicitType == null && warehouseName.isNotEmpty) {
      final snap = await _firestore
          .collection('warehouses')
          .where('idCompany', isEqualTo: companyId)
          .where('name', isEqualTo: warehouseName)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        resolved = _warehouseTypeOptionFromData(snap.docs.first.data());
      } else {
        resolved =
            _warehouseTypeOption(_warehouseTypeFromOption(warehouseName));
      }
    }
    if (!mounted) return;
    setState(() => _warehouseType = resolved);
  }

  Widget _warehouseDropdown(String companyId, String warehouseType) {
    final current = _warehouse.text.trim();
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('warehouses')
          .where('idCompany', isEqualTo: companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final items = <String>[warehouseType];
        final seen = <String>{warehouseType};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            final name = (data['name'] ?? '').toString().trim();
            if (name.isEmpty) continue;
            if (_warehouseDocBelongsToType(data, warehouseType) &&
                !seen.contains(name)) {
              items.add(name);
              seen.add(name);
            }
          }
        }
        if (current.isNotEmpty && !seen.contains(current)) {
          items.add(current);
          seen.add(current);
        }
        final available = items;
        if (_warehouse.text.trim().isEmpty && available.isNotEmpty) {
          _warehouse.text = warehouseType;
        }
        return DropdownButtonFormField<String>(
          initialValue:
              _warehouse.text.trim().isEmpty ? null : _warehouse.text.trim(),
          decoration: const InputDecoration(
            labelText: 'Склад',
            border: OutlineInputBorder(),
          ),
          items: available
              .map((v) => DropdownMenuItem<String>(
                    value: v,
                    child: Text(v),
                  ))
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() => _warehouse.text = val);
          },
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Обязательное поле' : null,
        );
      },
    );
  }

  Widget _categoryDropdown() {
    final options = widget.categories.isEmpty
        ? _defaultNomenclatureCategories
        : widget.categories;
    final current = options.contains(_category) ? _category : options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: const InputDecoration(
          labelText: 'Номенклатура',
          border: OutlineInputBorder(),
        ),
        items: options
            .map(
              (value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val == null) return;
          setState(() => _category = val);
        },
      ),
    );
  }

  Widget _industryKindDropdown() {
    final current = kIndustryItemKindLabels.containsKey(_industryItemKind)
        ? _industryItemKind
        : kItemKindProduct;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: const InputDecoration(
          labelText: 'Тип номенклатуры',
          border: OutlineInputBorder(),
        ),
        items: kIndustryItemKindLabels.entries
            .map(
              (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _industryItemKind = value;
            _type.text = industryItemKindLabel(value);
          });
        },
      ),
    );
  }

  Widget _costingMethodDropdown({
    required InventoryCostingMethod value,
    required ValueChanged<InventoryCostingMethod?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<InventoryCostingMethod>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'Метод списания себестоимости',
          border: OutlineInputBorder(),
        ),
        items: _inventoryCostingOptions
            .map(
              (method) => DropdownMenuItem<InventoryCostingMethod>(
                value: method,
                child: Text(_inventoryCostingLabel(method)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class AddBatchDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final String companyId;
  final String userId;

  const AddBatchDialog({
    super.key,
    required this.onSaved,
    required this.companyId,
    required this.userId,
  });

  @override
  State<AddBatchDialog> createState() => _AddBatchDialogState();
}

class _BatchItem {
  String article = '';
  String name = '';
  String price = '';
  String qty = '';
}

class _FundingRequestOption {
  const _FundingRequestOption({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidAmount,
    required this.status,
  });

  final String id;
  final String title;
  final double amount;
  final double paidAmount;
  final String status;
}

class _AddBatchDialogState extends State<AddBatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<_BatchItem> _items = [];
  final List<TextEditingController> _articleControllers = [];
  final List<String?> _batchArticleErrors = [];
  String _typeUchet = 'Bu';
  final _deliveryType = TextEditingController();
  final _vehicleNumber = TextEditingController();
  final _driverName = TextEditingController();
  final _driverPhone = TextEditingController();
  final _supplierName = TextEditingController();
  final _invoiceNumber = TextEditingController();
  final _invoiceDate = TextEditingController();
  final _gtdNumber = TextEditingController();
  final _deliveryNote = TextEditingController();
  String _fundingRequestId = '';
  String _fundingRequestTitle = '';
  double _fundingRequestPaidAmount = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _typeUchet = normalizeLegacyTypeUchet(FFAppState().accountingMode);
    _addBatchRow(notify: false);
  }

  String _resolveCompanyId() {
    if (widget.companyId.isNotEmpty && widget.companyId != '__all__') {
      return widget.companyId;
    }
    final raw = (currentUserDocument?.idCompany ?? '').trim();
    if (raw.isNotEmpty && raw != '__all__') return raw;
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    if (active.isNotEmpty && active != '__all__') return active;
    final ids = currentUserDocument?.companyIds ?? const [];
    for (final id in ids) {
      final value = id.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return _auth.currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _deliveryType.dispose();
    _vehicleNumber.dispose();
    _driverName.dispose();
    _driverPhone.dispose();
    _supplierName.dispose();
    _invoiceNumber.dispose();
    _invoiceDate.dispose();
    _gtdNumber.dispose();
    _deliveryNote.dispose();
    for (final controller in _articleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _toNum(String v) {
    return double.tryParse(v.replaceAll(',', '.'));
  }

  double _toNumValue(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  Future<List<_FundingRequestOption>> _loadPaidFundingRequests() async {
    final companyId = _resolveCompanyId();
    if (companyId.isEmpty) return const [];
    final snap = await _firestore
        .collection('funding_requests')
        .where('idCompany', isEqualTo: companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    final options = <_FundingRequestOption>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final paid = _toNumValue(data['paid_amount'] ??
          data['paidAmount'] ??
          data['total_paid'] ??
          data['totalPaid']);
      final status = (data['status'] ?? data['status_code'] ?? '').toString();
      if (paid <= 0 &&
          !status.toLowerCase().contains('оплач') &&
          !status.toLowerCase().contains('paid')) {
        continue;
      }
      final amount = _toNumValue(data['amount'] ?? data['total_amount']);
      final project = (data['project'] ?? '').toString().trim();
      final title = [
        project.isEmpty ? 'Заявка ${doc.id.substring(0, 6)}' : project,
        amount > 0 ? formatMoneyWithCurrency(amount) : null,
        paid > 0 ? 'оплачено ${formatMoneyWithCurrency(paid)}' : null,
      ].whereType<String>().join(' · ');
      options.add(_FundingRequestOption(
        id: doc.id,
        title: title,
        amount: amount,
        paidAmount: paid,
        status: status,
      ));
    }
    options.sort((a, b) => b.paidAmount.compareTo(a.paidAmount));
    return options;
  }

  Future<double?> _requestPurchaseExchangeRate({
    required AccountSelection account,
    required double amount,
  }) async {
    final data = account.snapshotData ?? const <String, dynamic>{};
    final accountCurrency = originalCurrencyFromData(data, fallback: 'KZT');
    final companyCurrency = companyCurrencyFromData(
      data,
      fallback: accountCurrency,
    );
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
                title: const Text('Курс для закупки'),
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

  void _addBatchRow({bool notify = true}) {
    final item = _BatchItem();
    final controller = TextEditingController();
    controller.addListener(() => item.article = controller.text);
    _items.add(item);
    _articleControllers.add(controller);
    _batchArticleErrors.add(null);
    if (notify) {
      setState(() {});
    }
  }

  void _removeBatchRow(int idx) {
    if (idx < 0 || idx >= _items.length) return;
    final controller = _articleControllers.removeAt(idx);
    controller.dispose();
    setState(() {
      _items.removeAt(idx);
      _batchArticleErrors.removeAt(idx);
    });
  }

  void _clearBatchArticleError(int idx) {
    if (idx < 0 || idx >= _batchArticleErrors.length) return;
    if (_batchArticleErrors[idx] != null) {
      setState(() => _batchArticleErrors[idx] = null);
    }
  }

  Future<void> _generateBatchArticle(int idx) async {
    if (idx < 0 || idx >= _articleControllers.length) return;
    final companyId = _resolveCompanyId();
    if (companyId.isEmpty) return;
    final generated = await product_catalog.generateUniqueArticleCode(
      _firestore,
      companyId,
      warehouse: product_catalog.warehouseByAccountingMode(_typeUchet),
    );
    if (generated == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось найти уникальный артикул')),
      );
      return;
    }
    final controller = _articleControllers[idx];
    controller.text = generated;
    _clearBatchArticleError(idx);
  }

  Future<bool> _ensureBatchArticlesUnique() async {
    final seen = <String>{};
    for (var idx = 0; idx < _articleControllers.length; idx++) {
      final article = _articleControllers[idx].text.trim();
      if (article.isEmpty) {
        setState(() => _batchArticleErrors[idx] = 'Обязательное поле');
        return false;
      }
      if (seen.contains(article)) {
        setState(() => _batchArticleErrors[idx] = 'Повторяющийся артикул');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Повторяющийся артикул')),
          );
        }
        return false;
      }
      seen.add(article);
    }
    if (_batchArticleErrors.any((e) => e != null)) {
      setState(() {
        for (var i = 0; i < _batchArticleErrors.length; i++) {
          _batchArticleErrors[i] = null;
        }
      });
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _ensureBatchArticlesUnique()) return;
    if (!mounted) return;
    final validationPayload = <String, dynamic>{
      'delivery_type': _deliveryType.text.trim(),
      'vehicle_number': _vehicleNumber.text.trim(),
      'driver_name': _driverName.text.trim(),
      'driver_phone': _driverPhone.text.trim(),
      'supplier_name': _supplierName.text.trim(),
      'invoice_date': _invoiceDate.text.trim(),
      'gtd_number': _gtdNumber.text.trim(),
    };
    final missingFields = validateRequiredFields(
      accountingMode: _typeUchet,
      stage: AccountingWorkflowStage.purchase,
      payload: validationPayload,
    );
    if (missingFields.isNotEmpty) {
      final translated = missingFields.map((f) {
        switch (f) {
          case 'delivery_type':
            return 'тип доставки';
          case 'vehicle_number':
            return 'номер машины';
          case 'driver_name':
            return 'водитель';
          case 'driver_phone':
            return 'телефон водителя';
          case 'supplier_name':
            return 'поставщик';
          case 'invoice_date':
            return 'дата накладной';
          case 'gtd_number':
            return 'ГТД';
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
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      final effectiveCompanyId = _resolveCompanyId();
      final targetWarehouse =
          product_catalog.warehouseByAccountingMode(_typeUchet);
      final plannedTotalCost = _items.fold<double>(0.0, (total, item) {
        final qty = _toNum(item.qty) ?? 0;
        final price = _toNum(item.price) ?? 0;
        return total + qty * price;
      });
      AccountSelection? purchaseAccount;
      double? purchaseExchangeRate;
      if (plannedTotalCost > 0) {
        purchaseAccount = await TransactionSync.selectAccount(
          effectiveCompanyId,
          tip: 'bank',
        );
        if (purchaseAccount.reference == null) {
          throw Exception('Не удалось определить счет для закупки');
        }
        purchaseExchangeRate = await _requestPurchaseExchangeRate(
          account: purchaseAccount,
          amount: plannedTotalCost,
        );
        if (purchaseExchangeRate == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
      }

      final batchDoc = await _firestore.collection('batches').add(
            buildPurchaseBatchHeaderPayload(
              companyId: effectiveCompanyId,
              userId: widget.userId.isEmpty ? user.uid : widget.userId,
              deliveryType: _deliveryType.text,
              vehicleNumber: _vehicleNumber.text,
              driverName: _driverName.text,
              driverPhone: _driverPhone.text,
              supplierName: _supplierName.text,
              invoiceNumber: _invoiceNumber.text,
              invoiceDate: _invoiceDate.text,
              gtdNumber: _gtdNumber.text,
              deliveryNote: _deliveryNote.text,
              accountingMode: _typeUchet,
              extra: {
                if (_fundingRequestId.isNotEmpty)
                  'funding_request_id': _fundingRequestId,
                if (_fundingRequestTitle.isNotEmpty)
                  'funding_request_title': _fundingRequestTitle,
                if (_fundingRequestPaidAmount > 0)
                  'funding_request_paid_amount': _fundingRequestPaidAmount,
              },
            ),
          );

      final writeBatch = _firestore.batch();
      double totalCost = 0.0;
      final movements = <Map<String, dynamic>>[];

      for (final item in _items) {
        final qty = _toNum(item.qty) ?? 0;
        final price = _toNum(item.price) ?? 0;
        totalCost += qty * price;

        final itemRef = batchDoc.collection('items').doc();
        writeBatch.set(
          itemRef,
          buildPurchaseBatchItemPayload(
            article: item.article,
            name: item.name,
            price: price,
            qty: qty,
          ),
        );

        DocumentSnapshot<Object?>? productDoc;
        final byCode = await _firestore
            .collection('nomenklatura')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .where('code', isEqualTo: item.article.trim())
            .getCached();

        final byCodePick =
            product_catalog.pickByWarehouseContour(byCode, targetWarehouse);
        if (byCodePick != null) {
          productDoc = byCodePick;
        } else {
          final bySku = await _firestore
              .collection('nomenklatura')
              .where('idCompany', isEqualTo: effectiveCompanyId)
              .where('sku', isEqualTo: item.article.trim())
              .getCached();
          final bySkuPick =
              product_catalog.pickByWarehouseContour(bySku, targetWarehouse);
          if (bySkuPick != null) productDoc = bySkuPick;
        }

        if (productDoc != null) {
          final raw = productDoc.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          final currentStock = (data['stock'] ?? 0).toDouble();
          final currentStockValue = (data['stock_value'] ?? 0).toDouble();
          final purchase =
              price > 0 ? price : (data['purchase_price'] ?? 0).toDouble();
          final warehouse =
              (data['warehouse'] ?? 'Официальные товары').toString();
          final warehouseId = (data['warehouse_id'] ?? warehouse).toString();

          writeBatch.update(productDoc.reference, {
            'stock': currentStock + qty,
            'purchase_price': purchase,
            'stock_value': currentStockValue + (qty * price),
            'inventory_costing_method': (data['inventory_costing_method'] ??
                    data['costing_method'] ??
                    InventoryCostingMethod.fifo.storageValue)
                .toString(),
            'costing_method': (data['inventory_costing_method'] ??
                    data['costing_method'] ??
                    InventoryCostingMethod.fifo.storageValue)
                .toString(),
            'delivery_type': _deliveryType.text.trim(),
            'vehicle_number': _vehicleNumber.text.trim(),
            'driver_name': _driverName.text.trim(),
            'driver_phone': _driverPhone.text.trim(),
            'supplier_name': _supplierName.text.trim(),
            'invoice_number': _invoiceNumber.text.trim(),
            'invoice_date': _invoiceDate.text.trim(),
            'gtd_number': _gtdNumber.text.trim(),
            'updated_at': FieldValue.serverTimestamp(),
          });
          writeBatch.set(
            _firestore.collection('inventory_batches').doc(),
            buildInventoryBatchPayload(
              companyId: effectiveCompanyId,
              productId: productDoc.id,
              productName: (data['name'] ?? item.name).toString(),
              warehouseId: warehouseId,
              warehouseName: warehouse.isEmpty ? targetWarehouse : warehouse,
              ledgerScope: ledgerScopeFromLegacyValue(_typeUchet),
              qtyInitial: qty,
              qtyRemaining: qty,
              unitCost: price,
              sourceDocType: 'purchase_batch',
              sourceDocId: batchDoc.id,
              sourceItemId: itemRef.id,
              extra: {
                if (_fundingRequestId.isNotEmpty)
                  'funding_request_id': _fundingRequestId,
                if (_fundingRequestTitle.isNotEmpty)
                  'funding_request_title': _fundingRequestTitle,
              },
            ),
          );

          movements.add({
            'product_id': productDoc.id,
            'product_name': data['name'] ?? item.name,
            'product_code': data['code'] ?? item.article,
            'from_warehouse': 'Поставщик',
            'to_warehouse':
                warehouse.isEmpty ? 'Официальные товары' : warehouse,
            'qty': qty,
            'delivery_type': _deliveryType.text.trim(),
            'vehicle_number': _vehicleNumber.text.trim(),
            'driver_name': _driverName.text.trim(),
            'driver_phone': _driverPhone.text.trim(),
            'supplier_name': _supplierName.text.trim(),
            'invoice_number': _invoiceNumber.text.trim(),
            'invoice_date': _invoiceDate.text.trim(),
            'gtd_number': _gtdNumber.text.trim(),
            'delivery_note': _deliveryNote.text.trim(),
          });
        } else {
          final productRef = _firestore.collection('nomenklatura').doc();
          final productName = item.name.trim().isEmpty
              ? 'Товар ${item.article.trim()}'
              : item.name.trim();
          final warehouseId = targetWarehouse;
          writeBatch.set(productRef, {
            'name': productName,
            'code': item.article.trim(),
            'type': 'Товар',
            'category': 'Товары',
            'sku': item.article.trim(),
            'barcode': '',
            'warehouse': targetWarehouse,
            'warehouse_id': warehouseId,
            ...warehouseTypeFields(
              warehouseTypeFromLegacy(warehouse: targetWarehouse),
            ),
            'purchase_price': price,
            'sale_price': price,
            'markup_ratio': 0.0,
            'stock': qty,
            'min_stock': 0,
            'stock_value': qty * price,
            ...inventoryCostingMethodFields(InventoryCostingMethod.fifo),
            ...product_catalog.sourceMeta(_sourceTypeManual),
            'delivery_type': _deliveryType.text.trim(),
            'vehicle_number': _vehicleNumber.text.trim(),
            'driver_name': _driverName.text.trim(),
            'driver_phone': _driverPhone.text.trim(),
            'supplier_name': _supplierName.text.trim(),
            'invoice_number': _invoiceNumber.text.trim(),
            'invoice_date': _invoiceDate.text.trim(),
            'gtd_number': _gtdNumber.text.trim(),
            'user_id': widget.userId.isEmpty ? user.uid : widget.userId,
            'idCompany': effectiveCompanyId,
            'accounting_mode': _typeUchet,
            'ledger_scope': ledgerScopeFromLegacyValue(_typeUchet).storageValue,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
          writeBatch.set(
            _firestore.collection('inventory_batches').doc(),
            buildInventoryBatchPayload(
              companyId: effectiveCompanyId,
              productId: productRef.id,
              productName: productName,
              warehouseId: warehouseId,
              warehouseName: targetWarehouse,
              ledgerScope: ledgerScopeFromLegacyValue(_typeUchet),
              qtyInitial: qty,
              qtyRemaining: qty,
              unitCost: price,
              sourceDocType: 'purchase_batch',
              sourceDocId: batchDoc.id,
              sourceItemId: itemRef.id,
              extra: {
                if (_fundingRequestId.isNotEmpty)
                  'funding_request_id': _fundingRequestId,
                if (_fundingRequestTitle.isNotEmpty)
                  'funding_request_title': _fundingRequestTitle,
              },
            ),
          );

          movements.add({
            'product_id': productRef.id,
            'product_name': productName,
            'product_code': item.article.trim(),
            'from_warehouse': 'Поставщик',
            'to_warehouse': targetWarehouse,
            'qty': qty,
            'delivery_type': _deliveryType.text.trim(),
            'vehicle_number': _vehicleNumber.text.trim(),
            'driver_name': _driverName.text.trim(),
            'driver_phone': _driverPhone.text.trim(),
            'supplier_name': _supplierName.text.trim(),
            'invoice_number': _invoiceNumber.text.trim(),
            'invoice_date': _invoiceDate.text.trim(),
            'gtd_number': _gtdNumber.text.trim(),
            'delivery_note': _deliveryNote.text.trim(),
          });
        }
      }

      await writeBatch.commit();

      if (totalCost > 0) {
        final account = purchaseAccount ??
            await TransactionSync.selectAccount(effectiveCompanyId,
                tip: 'bank');
        final accountRef = account.reference;
        if (accountRef == null) {
          throw Exception('Не удалось определить счет для закупки');
        }
        final txRef = _firestore.collection('tranzaction').doc();
        final txData = buildPurchaseTransactionPayload(
          companyId: effectiveCompanyId,
          accountingMode: _typeUchet,
          totalCost: totalCost,
          schetRef: accountRef,
          schetTitle: account.title,
          schetData: account.snapshotData,
          exchangeRateToCompany: purchaseExchangeRate,
          exchangeRateDate: DateTime.now(),
          exchangeRateSource:
              purchaseExchangeRate == null || purchaseExchangeRate == 1.0
                  ? 'same_currency'
                  : 'manual_purchase',
        );
        await txRef.set(txData);
        await createEntriesForTransaction(
          firestore: _firestore,
          transactionRef: txRef,
          transactionData: txData,
        );
        await TransactionSync.recomputeAllForCompany(effectiveCompanyId);
      }

      for (final move in movements) {
        await _firestore.collection('warehouse_movements').add({
          'idCompany': effectiveCompanyId,
          'user_id': widget.userId.isEmpty ? user.uid : widget.userId,
          'user_name': currentUserDocument?.displayName ??
              user.displayName ??
              user.email ??
              '',
          'product_id': move['product_id'],
          'product_name': move['product_name'],
          'product_code': move['product_code'],
          'from_warehouse': move['from_warehouse'],
          'to_warehouse': move['to_warehouse'],
          'qty': move['qty'],
          'delivery_type': move['delivery_type'],
          'vehicle_number': move['vehicle_number'],
          'driver_name': move['driver_name'],
          'driver_phone': move['driver_phone'],
          'supplier_name': move['supplier_name'],
          'invoice_number': move['invoice_number'],
          'invoice_date': move['invoice_date'],
          'gtd_number': move['gtd_number'],
          'delivery_note': move['delivery_note'],
          if (_fundingRequestId.isNotEmpty)
            'funding_request_id': _fundingRequestId,
          if (_fundingRequestTitle.isNotEmpty)
            'funding_request_title': _fundingRequestTitle,
          'created_at': FieldValue.serverTimestamp(),
          ...workflowMeta(
            stage: AccountingWorkflowStage.warehouse,
            accountingMode: _typeUchet,
            status: AccountingWorkflowStatus.posted,
          ),
        });

        if (_fundingRequestId.isNotEmpty) {
          await _firestore
              .collection('funding_requests')
              .doc(_fundingRequestId)
              .set({
            'inventory_batch_ids': FieldValue.arrayUnion([batchDoc.id]),
            'inventory_received_amount': FieldValue.increment(totalCost),
            'inventory_status': 'Поступило на склад',
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('nomenklatura', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('batches', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('inventory_batches', effectiveCompanyId);
      FirestoreQueryCache.instance.invalidateCompanyCollection(
          'warehouse_movements', effectiveCompanyId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error saving batch: $e');
    } finally {
      setState(() => _saving = false);
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
                const Text('Добавить партию',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Column(
                  children: _items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate),
                      ),
                      child: Column(
                        children: [
                          _batchArticleField(idx),
                          _field(item, 'Наименование', (v) => item.name = v),
                          _field(item, 'Цена', (v) => item.price = v,
                              number: true),
                          _field(item, 'Кол-во', (v) => item.qty = v,
                              number: true),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _removeBatchRow(idx),
                              child: const Text('Удалить строку'),
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addBatchRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить строку'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_typeUchet == 'Up1') ...[
                  _textField(_deliveryType, 'Тип доставки'),
                  _textField(_vehicleNumber, 'Номер машины'),
                  _textField(_driverName, 'Водитель'),
                  _textField(_driverPhone, 'Телефон водителя'),
                ] else ...[
                  _textField(_supplierName, 'Поставщик'),
                  _textField(_invoiceNumber, 'Накладная'),
                  _textField(_invoiceDate, 'Дата накладной'),
                  _textField(_gtdNumber, 'ГТД'),
                ],
                _textField(_deliveryNote, 'Комментарий по доставке'),
                const SizedBox(height: 8),
                FutureBuilder<List<_FundingRequestOption>>(
                  future: _loadPaidFundingRequests(),
                  builder: (context, snapshot) {
                    final options = snapshot.data ?? const [];
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue:
                          _fundingRequestId.isEmpty ? null : _fundingRequestId,
                      decoration: const InputDecoration(
                        labelText: 'Заявка на финансирование',
                        helperText:
                            'Связь: заявка → оплата → поступление → склад',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Без заявки'),
                        ),
                        ...options.map(
                          (request) => DropdownMenuItem(
                            value: request.id,
                            child: Text(
                              request.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        _FundingRequestOption? selected;
                        for (final request in options) {
                          if (request.id == value) {
                            selected = request;
                            break;
                          }
                        }
                        setState(() {
                          _fundingRequestId = value ?? '';
                          _fundingRequestTitle = selected?.title ?? '';
                          _fundingRequestPaidAmount = selected?.paidAmount ?? 0;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _typeUchet,
                  decoration: const InputDecoration(labelText: 'Тип учета'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Up1',
                      child: Text('Управленческий (С)'),
                    ),
                    DropdownMenuItem(
                      value: 'Bu',
                      child: Text('Бухгалтерский'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _typeUchet = v ?? 'Bu';
                    FFAppState().accountingMode = _typeUchet;
                    if (_typeUchet == 'Up1') {
                      _supplierName.clear();
                      _invoiceNumber.clear();
                      _invoiceDate.clear();
                      _gtdNumber.clear();
                    } else {
                      _deliveryType.clear();
                      _vehicleNumber.clear();
                      _driverName.clear();
                      _driverPhone.clear();
                    }
                  }),
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
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Сохранить партию'),
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

  Widget _batchArticleField(int idx) {
    final controller = _articleControllers[idx];
    final error = _batchArticleErrors[idx];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Артикул',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Сгенерировать артикул',
            onPressed: () => _generateBatchArticle(idx),
          ),
        ),
        validator: (value) {
          final trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) return 'Обязательное поле';
          if (error != null) return error;
          return null;
        },
        onChanged: (_) => _clearBatchArticleError(idx),
      ),
    );
  }

  Widget _field(
    _BatchItem item,
    String label,
    void Function(String) onChanged, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: label == 'Артикул'
            ? item.article
            : label == 'Наименование'
                ? item.name
                : label == 'Цена'
                    ? item.price
                    : item.qty,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Обязательное поле';
          if (number && double.tryParse(v.replaceAll(',', '.')) == null) {
            return 'Введите число';
          }
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  late final MobileScannerController _controller;
  bool _captured = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      autoStart: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _controller.start();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _status = 'Разрешите доступ к камере для сканера';
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_captured) return;
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue?.trim();
      if (text?.isNotEmpty ?? false) {
        _captured = true;
        _controller.stop();
        Navigator.of(context).pop(text);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 420,
          width: 360,
          child: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                fit: BoxFit.cover,
                onDetect: _onDetect,
                errorBuilder: (context, error, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _status = error.toString());
                  });
                  return ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        error.toString(),
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Поднесите штрихкод к камере',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _status!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
