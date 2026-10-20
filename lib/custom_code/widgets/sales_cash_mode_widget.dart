// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/utils/app_money_format.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/country_profile.dart';
import '/utils/transaction_sync.dart';
import '/utils/sale_flow_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/effective_company_support.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/cash_shift_support.dart';
import '/utils/cash_mode_support.dart';
import '/utils/money_wallet_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/sales_ledger_support.dart';
import '/utils/sales_profit_breakdown_support.dart';
import '/utils/debt_register_support.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class SalesCashModeWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesCashModeWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesCashModeWidget> createState() => _SalesCashModeWidgetState();
}

class _SalesCashModeWidgetState extends State<SalesCashModeWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  String _companyId = '';
  List<Map<String, dynamic>> _productDocs = [];
  List<Map<String, dynamic>> _serviceDocs = [];
  List<CatalogEntryView> _products = [];
  List<CatalogEntryView> _services = [];
  List<ClientEntryView> _clients = [];
  Map<String, double> _clientOutstandingAr = {};
  List<Map<String, dynamic>> _registerHistoryDocs = [];
  List<CashRegisterShiftEntryView> _registerHistory = [];
  List<String> _knownRegisterNames = [];
  List<Map<String, dynamic>> _cartDocs = [];
  Map<String, double> _cogsByRegisterKey = {};
  final Map<String, AccountSelection> _paymentAccountCache = {};
  String _search = '';
  String _saleTarget = 'products';
  String _payment = 'cash';
  String _typeUchet = 'Up1';
  String _companyDisplayCurrency = 'KZT';
  String? _selectedClientId;
  double _discount = 0;
  final _saleExchangeRate = TextEditingController(text: '1');

  Map<String, dynamic>? _shiftDoc;
  CashRegisterShiftEntryView? _shift;
  final _endCash = TextEditingController();

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDarkTheme ? const Color(0xFF131A26) : const Color(0xFFF7F8FA);
  Color get _panelBorder => FlutterFlowTheme.of(context).alternate;
  Color get _mutedText => FlutterFlowTheme.of(context).secondaryText;
  Color get _softText =>
      _isDarkTheme ? const Color(0xFF9AA4B2) : const Color(0xFF6B7280);

  CartEntryView _cartItem(Map<String, dynamic> item) =>
      CartEntryView.fromMap(item);
  List<CartEntryView> get _cart =>
      _cartDocs.map(CartEntryView.fromMap).toList();

  @override
  void initState() {
    super.initState();
    markCompanyReloadBaseline();
    _loadData();
  }

  @override
  void dispose() {
    _endCash.dispose();
    _saleExchangeRate.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final shouldShowBlockingLoader =
        _products.isEmpty && _services.isEmpty && _shift == null;
    if (shouldShowBlockingLoader) {
      setState(() => _loading = true);
    }
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _products = [];
          _services = [];
          _productDocs = [];
          _serviceDocs = [];
          _clients = [];
          _registerHistoryDocs = [];
          _registerHistory = [];
          _knownRegisterNames = [];
          _shiftDoc = null;
          _shift = null;
          _cartDocs = [];
          _loading = false;
        });
        return;
      }
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final results = await Future.wait([
        _firestore
            .collection('nomenklatura')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('services')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore
            .collection('cash_registers')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .getCached(),
        _firestore.collection('company_profile').doc(effectiveCompanyId).get(),
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

      final productsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final servicesSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final registersSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final profileSnap = results[3] as DocumentSnapshot<Map<String, dynamic>>;
      final salesSnap = results[4] as QuerySnapshot<Map<String, dynamic>>;
      final txSnap = results[5] as QuerySnapshot<Map<String, dynamic>>;
      final salesItemsSnap = results[6] as QuerySnapshot<Map<String, dynamic>>;
      final legacyCogsSnap = results[7] as QuerySnapshot<Map<String, dynamic>>;
      final profileData = profileSnap.data() ?? const <String, dynamic>{};
      final countryProfile = countryProfileFromData(profileData);
      final companyCurrency = companyCurrencyFromProfileData(
        profileData,
        fallback: countryProfile.baseCurrency,
      );

      final registerRows = registersSnap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, ...data};
      }).toList();
      registerRows.sort((a, b) {
        final ad = _timestampMs(a['opened_at'] ?? a['created_at']);
        final bd = _timestampMs(b['opened_at'] ?? b['created_at']);
        return bd.compareTo(ad);
      });
      final knownRegisterNames = registerRows
          .map((row) => (row['cash_register_name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      Map<String, dynamic>? shiftDoc;
      CashRegisterShiftEntryView? shift;
      for (final row in registerRows) {
        final entry = CashRegisterShiftEntryView.fromMap(row);
        final openedBy = entry.openedByUserId;
        if (entry.isOpen && openedBy == user.uid) {
          shiftDoc = row;
          shift = entry;
          break;
        }
      }
      final sales = salesSnap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, ...data};
      }).toList();
      final transactions = txSnap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, ...data};
      }).toList();
      final cogsItems = resolveSalesCogsItems(
        cogsEntries: salesItemsSnap.docs.map((d) {
          final data = d.data();
          return {'id': d.id, ...data};
        }).toList(),
        legacyCogsItems: legacyCogsSnap.docs.map((d) {
          final data = d.data();
          return {'id': d.id, ...data};
        }).toList(),
      );
      final registerProfitRows = buildCashRegisterProfitRows(
        salesLedger: buildSalesLedger(sales: sales, transactions: transactions),
        cogsEntries: cogsItems,
      );
      final cogsByRegisterKey = <String, double>{};
      for (final row in registerProfitRows) {
        final id = (row['cash_register_id'] ?? '').toString().trim();
        final name = (row['register_name'] ?? '').toString().trim();
        final cogs = (row['cogs'] as num?)?.toDouble() ?? 0;
        if (id.isNotEmpty) cogsByRegisterKey['id:$id'] = cogs;
        if (name.isNotEmpty)
          cogsByRegisterKey['name:${name.toLowerCase()}'] = cogs;
      }

      setState(() {
        _companyId = effectiveCompanyId;
        _companyDisplayCurrency = companyCurrency;
        _productDocs = productsSnap.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            ...data,
            'item_kind': 'product',
          };
        }).toList();
        _serviceDocs = servicesSnap.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            ...data,
            'item_kind': 'service',
          };
        }).toList();
        _products = _productDocs.map(CatalogEntryView.fromMap).toList();
        _services = _serviceDocs.map(CatalogEntryView.fromMap).toList();
        _registerHistoryDocs = registerRows;
        _registerHistory =
            registerRows.map(CashRegisterShiftEntryView.fromMap).toList();
        _knownRegisterNames = knownRegisterNames;
        _cogsByRegisterKey = cogsByRegisterKey;
        _shiftDoc = shiftDoc;
        _shift = shift;
        _loading = false;
      });
      _paymentAccountCache.clear();
      unawaited(_loadClientsInBackground(effectiveCompanyId));
    } catch (e) {
      debugPrint('Error loading cash mode: $e');
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadClientsInBackground(String companyId) async {
    try {
      final clientsSnap = await _firestore
          .collection('clients')
          .where('idCompany', isEqualTo: companyId)
          .getCached() as QuerySnapshot<Map<String, dynamic>>;
      final debtsSnap = await _firestore
          .collection('debt_register')
          .where('idCompany', isEqualTo: companyId)
          .where('type', isEqualTo: 'AR')
          .getCached() as QuerySnapshot<Map<String, dynamic>>;
      if (!mounted || companyId != _companyId) return;
      setState(() {
        final rows = clientsSnap.docs.map<Map<String, dynamic>>((d) {
          final data = Map<String, dynamic>.from(d.data());
          return <String, dynamic>{'id': d.id, ...data};
        }).toList();
        _clients = rows.map(ClientEntryView.fromMap).toList();
        final outstanding = <String, double>{};
        for (final doc in debtsSnap.docs) {
          final debt = DebtRecordView.fromMap({
            'id': doc.id,
            ...doc.data(),
          });
          if (!debt.isOpen || debt.type != DebtType.ar) continue;
          final counterpartyId = debt.counterpartyId.trim();
          if (counterpartyId.isEmpty) continue;
          outstanding[counterpartyId] =
              (outstanding[counterpartyId] ?? 0) + debt.remainingAmount;
        }
        _clientOutstandingAr = outstanding;
      });
    } catch (e) {
      debugPrint('Error loading cash mode clients: $e');
    }
  }

  List<CatalogEntryView> get _filteredItems {
    final source = _saleTarget == 'services' ? _services : _products;
    if (_search.trim().isEmpty) return source;
    final q = _search.trim().toLowerCase();
    return source.where((entry) {
      return entry.name.toLowerCase().contains(q) ||
          entry.code.toLowerCase().contains(q) ||
          entry.barcode.toLowerCase().contains(q);
    }).toList();
  }

  int _timestampMs(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  double _lastEndingCashForRegister(String registerName) {
    final normalized = registerName.trim().toLowerCase();
    if (normalized.isEmpty) return 0;
    for (final row in _registerHistory) {
      final name = row.cashRegisterName.trim().toLowerCase();
      if (name != normalized || row.status != 'closed') continue;
      final endingCash = row.endingCash;
      if (endingCash > 0) return endingCash;
      return row.startingCash;
    }
    return 0;
  }

  bool _hasOpenShiftForRegister(String registerName) {
    final normalized = registerName.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _registerHistory.any((row) {
      final name = row.cashRegisterName.trim().toLowerCase();
      return row.isOpen && name == normalized;
    });
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value,
        currencyCode: _companyDisplayCurrency);
  }

  Future<AccountSelection> _selectAccountForPaymentCached(
    String companyId,
    String payment,
  ) async {
    final cacheKey = '$companyId::$payment';
    final cached = _paymentAccountCache[cacheKey];
    if (cached != null &&
        cached.reference != null &&
        cached.title.trim().isNotEmpty) {
      return cached;
    }
    final selected =
        await TransactionSync.selectAccountForPayment(companyId, payment);
    if (selected.reference != null && selected.title.trim().isNotEmpty) {
      _paymentAccountCache[cacheKey] = selected;
    }
    return selected;
  }

  double get _saleExchangeRateValue =>
      double.tryParse(
        _saleExchangeRate.text.replaceAll(' ', '').replaceAll(',', '.'),
      ) ??
      1.0;

  String _accountCurrency(AccountSelection account) {
    return originalCurrencyFromData(
      account.snapshotData ?? const <String, dynamic>{},
      fallback: 'KZT',
    );
  }

  String _companyCurrency(AccountSelection account) {
    return companyCurrencyFromData(
      account.snapshotData ?? const <String, dynamic>{},
      fallback: _accountCurrency(account),
    );
  }

  bool _needsSaleExchangeRate(AccountSelection account) {
    if (account.reference == null || account.snapshotData == null) return false;
    return normalizeCurrencyCode(_accountCurrency(account)) !=
        normalizeCurrencyCode(_companyCurrency(account));
  }

  double _saleCompanyAmount(AccountSelection account) {
    return _total *
        (_needsSaleExchangeRate(account) ? _saleExchangeRateValue : 1);
  }

  String _requiredAccountingModeForCatalog(CatalogEntryView product) {
    return requiredAccountingModeForCatalogEntry(product);
  }

  String? _cartAccountingMode() {
    return cartAccountingModeFromEntries(_cart);
  }

  bool _isProductCompatibleWithCart(CatalogEntryView product) {
    return productCompatibleWithCart(product, _cart);
  }

  void _showWarehouseMismatchSaleWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Нельзя смешивать официальный и неофициальный товар в одной продаже.',
        ),
      ),
    );
  }

  void _addToCart(CatalogEntryView entry) {
    final kind = entry.itemKind;
    if (kind == 'product' && !_isProductCompatibleWithCart(entry)) {
      _showWarehouseMismatchSaleWarning();
      return;
    }
    final idx = _cartDocs.indexWhere(
      (c) =>
          c['id'] == entry.id &&
          (c['item_kind'] ?? 'product').toString() == kind,
    );
    setState(() {
      final isProduct = entry.isProduct;
      final maxQty = isProduct ? entry.stock.toInt() : 999999;
      if (isProduct && maxQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет остатка на складе')));
        return;
      }
      if (idx >= 0) {
        final nextQty = _cartItem(_cartDocs[idx]).qty + 1;
        if (isProduct && nextQty > maxQty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Доступно только $maxQty шт',
              ),
            ),
          );
          return;
        }
        _cartDocs[idx]['qty'] = nextQty;
      } else {
        final source = kind == 'service'
            ? _serviceDocs.firstWhere(
                (doc) => (doc['id'] ?? '').toString() == entry.id,
              )
            : _productDocs.firstWhere(
                (doc) => (doc['id'] ?? '').toString() == entry.id,
              );
        _cartDocs.add({
          ...source,
          'item_kind': kind,
          'qty': 1,
        });
      }
      if (kind == 'product') {
        _typeUchet = _requiredAccountingModeForCatalog(entry);
      }
    });
  }

  void _updateQty(int index, int qty) {
    if (index < 0 || index >= _cartDocs.length) return;
    setState(() {
      final item = _cart[index];
      final isProduct = item.isProduct;
      final maxQty = isProduct ? item.stock.toInt() : 999999;
      final nextQty = isProduct && qty > maxQty ? maxQty : qty;
      if (isProduct && qty > maxQty && maxQty > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Доступно только $maxQty шт')),
        );
      }
      if (isProduct && maxQty <= 0) {
        _cartDocs.removeAt(index);
        return;
      }
      if (qty <= 0) {
        _cartDocs.removeAt(index);
      } else {
        _cartDocs[index]['qty'] = nextQty;
      }
    });
  }

  Future<void> _editQty(int index) async {
    if (index < 0 || index >= _cartDocs.length) return;
    final item = _cart[index];
    final isProduct = item.isProduct;
    final current = item.qty;
    final maxQty = isProduct ? item.stock.toInt() : 999999;
    final controller = TextEditingController(text: current.toString());
    final newQty = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Количество товара'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Введите количество',
              helperText:
                  isProduct ? 'Доступно: $maxQty шт' : 'Количество услуг',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
    if (newQty == null) return;
    _updateQty(index, newQty);
  }

  double get _subtotal {
    return _cart.fold(0, (s, item) {
      return s + item.effectivePrice * item.qty;
    });
  }

  double get _total {
    final discountValue = _subtotal * (_discount / 100);
    return _subtotal - discountValue;
  }

  double get _averageCheck {
    final checks = _shift?.transactions ?? 0;
    if (checks <= 0) return 0;
    return (_shift?.averageCheck ?? 0);
  }

  double get _shiftCogs {
    final shift = _shift;
    if (shift == null) return 0;
    if (shift.id.isNotEmpty) {
      final byId = _cogsByRegisterKey['id:${shift.id}'];
      if (byId != null) return byId;
    }
    final name = shift.cashRegisterName.trim();
    if (name.isNotEmpty) {
      return _cogsByRegisterKey['name:${name.toLowerCase()}'] ?? 0;
    }
    return 0;
  }

  double get _shiftGrossProfit => (_shift?.turnover ?? 0) - _shiftCogs;

  String get _selectedClientName {
    if (_selectedClientId == null || _selectedClientId!.isEmpty) return '';
    final match = _clients.where((c) => c.id == _selectedClientId);
    if (match.isEmpty) return '';
    return match.first.name.trim();
  }

  ClientEntryView? get _selectedClientView {
    final clientId = (_selectedClientId ?? '').trim();
    if (clientId.isEmpty) return null;
    for (final client in _clients) {
      if (client.id == clientId) return client;
    }
    return null;
  }

  double get _selectedClientOutstandingAr {
    final clientId = (_selectedClientId ?? '').trim();
    if (clientId.isEmpty) return 0;
    return _clientOutstandingAr[clientId] ?? 0;
  }

  double get _selectedClientProjectedAr =>
      _selectedClientOutstandingAr + (_payment == 'debt' ? _total : 0);

  bool get _isSelectedClientCreditLimitExceeded {
    final client = _selectedClientView;
    if (client == null || client.creditLimit <= 0 || _payment != 'debt') {
      return false;
    }
    return _selectedClientProjectedAr - client.creditLimit > 0.000001;
  }

  Future<bool> _confirmDebtLimitExceeded() async {
    final client = _selectedClientView;
    if (client == null || !_isSelectedClientCreditLimitExceeded) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Превышение кредитного лимита'),
        content: Text(
          'У клиента "${client.name}" лимит ${_formatMoney(client.creditLimit)}, '
          'текущая дебиторка ${_formatMoney(_selectedClientOutstandingAr)}, '
          'после продажи станет ${_formatMoney(_selectedClientProjectedAr)}. '
          'Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openShift() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final shiftSetup = await _requestCashierByPin();
    if (shiftSetup == null) return;
    final cashierEntry = shiftSetup.cashier;
    final cashRegisterName = shiftSetup.cashRegisterName.trim();
    final startCash = shiftSetup.startingCash;
    if (cashRegisterName.isEmpty) return;
    final openGeo = await _captureGeoPoint();
    final openedByUserName = currentUserDocument?.displayName ??
        user.displayName ??
        user.email ??
        '';
    final openPayload = buildCashShiftOpenPayload(
      companyId: _companyId,
      userId: user.uid,
      openedByUserName: openedByUserName,
      cashier: cashierEntry,
      cashRegisterName: cashRegisterName,
      startingCash: startCash,
      openGeo: openGeo,
    );
    final docRef =
        await _firestore.collection('cash_registers').add(openPayload);
    await ensureWalletForCashRegister(
      firestore: _firestore,
      registerData: {
        'id': docRef.id,
        ...openPayload,
      },
    );
    await _firestore.collection('staff_schedule').doc(docRef.id).set(
          buildStaffScheduleOpenPayload(
            companyId: _companyId,
            shiftId: docRef.id,
            userId: user.uid,
            cashier: cashierEntry,
            openGeo: openGeo,
          ),
          SetOptions(merge: true),
        );
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('cash_registers', _companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('staff_schedule', _companyId);
    setState(() {
      _shiftDoc = {
        'id': docRef.id,
        ...openPayload,
      };
      _shift = CashRegisterShiftEntryView.fromMap(_shiftDoc!);
      _registerHistoryDocs = [_shiftDoc!, ..._registerHistoryDocs];
      _registerHistory = [_shift!, ..._registerHistory];
    });
  }

  Future<void> _closeShift() async {
    if (_shift == null) return;
    final shiftId = _shift!.id;
    if (shiftId.isEmpty) return;
    final endCash = double.tryParse(_endCash.text.replaceAll(',', '.')) ?? 0;
    final closeGeo = await _captureGeoPoint();
    final shiftSnap =
        await _firestore.collection('cash_registers').doc(shiftId).get();
    final shiftData = shiftSnap.data() ?? const <String, dynamic>{};
    final openedAtRaw = shiftData['opened_at'];
    final openedAt = openedAtRaw is Timestamp ? openedAtRaw.toDate() : null;
    final closedAtLocal = DateTime.now();
    final workedMinutes = openedAt == null
        ? 0
        : closedAtLocal.difference(openedAt).inMinutes.clamp(0, 1000000);
    final workedHours = workedMinutes / 60.0;

    final closePatch = buildCashShiftClosePatch(
      endingCash: endCash,
      closeGeo: closeGeo,
      workedMinutes: workedMinutes,
      workedHours: workedHours,
    );
    await _firestore
        .collection('cash_registers')
        .doc(shiftId)
        .update(closePatch);
    await _firestore.collection('staff_schedule').doc(shiftId).set(
          buildStaffScheduleClosePayload(
            companyId: _companyId,
            shiftId: shiftId,
            cashierId:
                (shiftData['cashier_id'] ?? _shiftDoc?['cashier_id'] ?? '')
                    .toString(),
            cashierName: (shiftData['cashier_name'] ??
                    _shiftDoc?['cashier_name'] ??
                    _shiftDoc?['cash_register_name'] ??
                    '')
                .toString()
                .trim(),
            shopId: (shiftData['shop_id'] ?? _shiftDoc?['shop_id'] ?? '')
                .toString(),
            shopName: (shiftData['shop_name'] ?? _shiftDoc?['shop_name'] ?? '')
                .toString()
                .trim(),
            openedAt: shiftData['opened_at'],
            openedGeo:
                (shiftData['opened_geo'] ?? _shiftDoc?['opened_geo']) is Map
                    ? Map<String, dynamic>.from(
                        (shiftData['opened_geo'] ?? _shiftDoc?['opened_geo'])
                            as Map,
                      )
                    : null,
            closeGeo: closeGeo,
            workedMinutes: workedMinutes,
            workedHours: workedHours,
          ),
          SetOptions(merge: true),
        );
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('cash_registers', _companyId);
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('staff_schedule', _companyId);
    setState(() {
      _registerHistoryDocs = _registerHistoryDocs.map((row) {
        if ((row['id'] ?? '').toString() != shiftId) return row;
        return {
          ...row,
          ...closePatch,
        };
      }).toList();
      _registerHistory =
          _registerHistoryDocs.map(CashRegisterShiftEntryView.fromMap).toList();
      _shiftDoc = null;
      _shift = null;
      _cartDocs = [];
    });
  }

  Future<void> _pay() async {
    if (_cart.isEmpty || _shift == null) return;
    final user = _auth.currentUser;
    if (user == null) return;
    if (_payment == 'debt' && !await _confirmDebtLimitExceeded()) return;
    final saleTypeUchet = _cartAccountingMode() ?? _typeUchet;
    final incompatible = _cart.where((item) {
      if (!item.isProduct) return false;
      return (item.isOfficial ? 'Bu' : 'Up1') != saleTypeUchet;
    });
    if (incompatible.isNotEmpty) {
      _showWarehouseMismatchSaleWarning();
      return;
    }

    final account = _payment == 'debt'
        ? AccountSelection()
        : await _selectAccountForPaymentCached(_companyId, _payment);
    if (_payment != 'debt' &&
        _needsSaleExchangeRate(account) &&
        _saleExchangeRateValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите курс больше нуля')),
      );
      return;
    }

    final cashSales = _shift!.cashSales + (_payment == 'cash' ? _total : 0);
    final cardSales = _shift!.cardSales + (_payment == 'card' ? _total : 0);
    final transactions = _shift!.transactions + 1;

    final plan = await buildCashSaleWritePlan(
      firestore: _firestore,
      companyId: _companyId,
      cashierId:
          _shift?.cashierId.isNotEmpty == true ? _shift!.cashierId : user.uid,
      cashierName: _shift?.cashierName.isNotEmpty == true
          ? _shift!.cashierName
          : (currentUserDocument?.displayName ??
                  user.displayName ??
                  user.email ??
                  '')
              .toString(),
      shopId: _shift?.shopId ?? '',
      shopName: _shift?.shopName ?? '',
      cashRegisterId: _shift?.id ?? '',
      cashRegisterName: _shift?.cashRegisterName.isNotEmpty == true
          ? _shift!.cashRegisterName
          : (_shift?.cashierName.isNotEmpty == true
              ? _shift!.cashierName
              : (currentUserDocument?.displayName ??
                      user.displayName ??
                      user.email ??
                      '')
                  .toString()),
      clientId: _selectedClientId ?? '',
      clientName: _selectedClientName,
      amount: _total,
      discount: _discount,
      paymentMethod: _payment,
      typeUchet: saleTypeUchet,
      ledgerScope: ledgerScopeFromLegacyValue(saleTypeUchet),
      cart: _cartDocs,
      accountReference: account.reference,
      accountTitle: account.title,
      nextCashSales: cashSales,
      nextCardSales: cardSales,
      nextTransactions: transactions,
      exchangeRateToCompany:
          _needsSaleExchangeRate(account) ? _saleExchangeRateValue : 1.0,
      exchangeRateDate: DateTime.now(),
      exchangeRateSource: _needsSaleExchangeRate(account)
          ? 'manual_cash_sale'
          : 'same_currency',
    );

    final batch = _firestore.batch();
    batch.set(plan.saleRef, plan.saleData);
    batch.set(plan.transactionRef, plan.transactionData);
    for (final write in plan.entryWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.stockWrites) {
      batch.update(write.reference, write.data);
    }
    for (final write in plan.salesItemWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.serviceExecutionWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.inventoryBatchWrites) {
      if (write.merge) {
        batch.set(write.reference, write.data, SetOptions(merge: true));
      } else {
        batch.set(write.reference, write.data);
      }
    }
    for (final write in plan.cogsWrites) {
      if (write.merge) {
        batch.set(
          write.reference,
          write.data,
          SetOptions(merge: true),
        );
      } else {
        batch.set(write.reference, write.data);
      }
    }
    for (final write in plan.cogsEntryWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.batchConsumptionWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.debtWrites) {
      if (write.merge) {
        batch.set(write.reference, write.data, SetOptions(merge: true));
      } else {
        batch.set(write.reference, write.data);
      }
    }
    for (final write in plan.orderWrites) {
      if (write.merge) {
        batch.set(write.reference, write.data, SetOptions(merge: true));
      } else {
        batch.set(write.reference, write.data);
      }
    }
    for (final write in plan.orderItemWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.shipmentWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.paymentWrites) {
      batch.set(write.reference, write.data);
    }
    for (final write in plan.eventWrites) {
      batch.set(write.reference, write.data);
    }
    batch.update(
      _firestore.collection('cash_registers').doc(_shift!.id),
      plan.cashRegisterPatch,
    );
    await batch.commit();

    final saleCogsTotal = plan.cogsEntryWrites.fold<double>(0, (total, write) {
      final value = write.data['total_cost'];
      if (value is num) return total + value.toDouble();
      return total + (double.tryParse(value?.toString() ?? '') ?? 0);
    });

    unawaited(
      TransactionSync.recomputeAllForCompany(_companyId).catchError((error) {
        debugPrint('Cash mode sync error: $error');
      }),
    );

    final uiPatch = buildCashSaleUiStatePatch(
      productDocs: _productDocs,
      soldCartDocs: _cartDocs,
      stockWrites: plan.stockWrites,
      shiftDoc: _shiftDoc,
      cashSales: cashSales,
      cardSales: cardSales,
      transactions: transactions,
    );
    for (final collection in uiPatch.collectionsToInvalidate) {
      FirestoreQueryCache.instance
          .invalidateCompanyCollection(collection, _companyId);
    }

    setState(() {
      _productDocs = uiPatch.productDocs;
      _products = _productDocs.map(CatalogEntryView.fromMap).toList();
      _cartDocs = [];
      _discount = 0;
      _selectedClientId = null;
      _shiftDoc = uiPatch.shiftDoc;
      _shift = CashRegisterShiftEntryView.fromMap(uiPatch.shiftDoc);
      if (_shift != null) {
        if (_shift!.id.isNotEmpty) {
          _cogsByRegisterKey['id:${_shift!.id}'] =
              (_cogsByRegisterKey['id:${_shift!.id}'] ?? 0) + saleCogsTotal;
        }
        final registerName = _shift!.cashRegisterName.trim();
        if (registerName.isNotEmpty) {
          _cogsByRegisterKey['name:${registerName.toLowerCase()}'] =
              (_cogsByRegisterKey['name:${registerName.toLowerCase()}'] ?? 0) +
                  saleCogsTotal;
        }
      }
    });
  }

  Future<CashierShiftSetup?> _requestCashierByPin() async {
    final pinController = TextEditingController();
    final registerController = TextEditingController();
    String? errorText;
    final registerItems = List<String>.from(_knownRegisterNames);
    String? selectedExistingRegister =
        registerItems.isNotEmpty ? registerItems.first : null;
    bool useCustomRegister = registerItems.isEmpty;
    if (selectedExistingRegister != null) {
      registerController.text = selectedExistingRegister;
    }
    double startingCash = selectedExistingRegister == null
        ? 0
        : _lastEndingCashForRegister(selectedExistingRegister);
    CashierShiftSetup? selected;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Вход в режим кассы'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: 'PIN кассира',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: useCustomRegister
                        ? '__new__'
                        : selectedExistingRegister,
                    decoration: const InputDecoration(
                      labelText: 'Касса',
                    ),
                    items: [
                      ...registerItems.map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: '__new__',
                        child: Text('Новая касса'),
                      ),
                    ],
                    onChanged: (value) {
                      setLocalState(() {
                        errorText = null;
                        useCustomRegister = value == '__new__';
                        selectedExistingRegister =
                            useCustomRegister ? null : value;
                        if (!useCustomRegister && value != null) {
                          registerController.text = value;
                          startingCash = _lastEndingCashForRegister(value);
                        } else {
                          registerController.clear();
                          startingCash = 0;
                        }
                      });
                    },
                  ),
                  if (useCustomRegister) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: registerController,
                      decoration: const InputDecoration(
                        labelText: 'Название кассы',
                      ),
                      onChanged: (value) {
                        setLocalState(() {
                          errorText = null;
                          startingCash = _lastEndingCashForRegister(value);
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Старт наличных',
                    ),
                    child: Text(_formatMoney(startingCash)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final registerName = registerController.text.trim();
                    if (pin.isEmpty) {
                      setLocalState(() => errorText = 'Введите PIN');
                      return;
                    }
                    if (registerName.isEmpty) {
                      setLocalState(() => errorText = 'Выберите кассу');
                      return;
                    }
                    if (_hasOpenShiftForRegister(registerName)) {
                      setLocalState(
                        () =>
                            errorText = 'По этой кассе уже есть открытая смена',
                      );
                      return;
                    }
                    final cashier = await findCashierByPin(
                      firestore: _firestore,
                      companyId: _companyId,
                      pin: pin,
                    );
                    if (cashier == null) {
                      setLocalState(() => errorText = 'PIN неверный');
                      return;
                    }
                    if (!cashier.isActive) {
                      setLocalState(
                          () => errorText = 'Кассир неактивен для входа');
                      return;
                    }
                    if (!cashier.canOpenDrawer) {
                      setLocalState(() =>
                          errorText = 'Нет права на открытие кассовой смены');
                      return;
                    }
                    selected = CashierShiftSetup(
                      cashier: cashier,
                      cashRegisterName: registerName,
                      startingCash: _lastEndingCashForRegister(registerName),
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Войти'),
                ),
              ],
            );
          },
        );
      },
    );
    pinController.dispose();
    registerController.dispose();
    if (result == true && selected != null) {
      return selected;
    }
    return null;
  }

  Future<Map<String, dynamic>> _captureGeoPoint() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'status': 'service_disabled',
          'captured_at': DateTime.now().toIso8601String(),
        };
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return {
          'status': 'permission_denied',
          'captured_at': DateTime.now().toIso8601String(),
        };
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
      return {
        'status': 'ok',
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'captured_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'captured_at': DateTime.now().toIso8601String(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.cash')) {
      return PermissionsHelper.noAccess();
    }
    final shiftOpen = _shift != null;
    final isMobile = MediaQuery.of(context).size.width < 980;
    return ResponsiveFrame(
      backgroundColor: _pageBackground,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShiftHeader(shiftOpen),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statCard(
                        title: 'Наличные',
                        value: _formatMoney(_shift?.cashSales ?? 0),
                        icon: Icons.payments_outlined,
                        iconBg: FlutterFlowTheme.of(context)
                            .success
                            .withValues(alpha: 0.14),
                        iconColor: FlutterFlowTheme.of(context).success,
                      ),
                      _statCard(
                        title: 'Карта',
                        value: _formatMoney(_shift?.cardSales ?? 0),
                        icon: Icons.credit_card_rounded,
                        iconBg: FlutterFlowTheme.of(context).accent1,
                        iconColor: FlutterFlowTheme.of(context).primary,
                      ),
                      _statCard(
                        title: 'COGS',
                        value: _formatMoney(_shiftCogs),
                        icon: Icons.inventory_2_outlined,
                        iconBg: FlutterFlowTheme.of(context)
                            .warning
                            .withValues(alpha: 0.14),
                        iconColor: FlutterFlowTheme.of(context).warning,
                      ),
                      _statCard(
                        title: 'Валовая',
                        value: _formatMoney(_shiftGrossProfit),
                        icon: Icons.stacked_line_chart,
                        iconBg: FlutterFlowTheme.of(context)
                            .success
                            .withValues(alpha: 0.14),
                        iconColor: FlutterFlowTheme.of(context).success,
                      ),
                      _statCard(
                        title: 'Чеки',
                        value: (_shift?.transactions ?? 0).toStringAsFixed(0),
                        icon: Icons.receipt_long,
                        iconBg: FlutterFlowTheme.of(context)
                            .warning
                            .withValues(alpha: 0.14),
                        iconColor: FlutterFlowTheme.of(context).warning,
                      ),
                      _statCard(
                        title: 'Средний чек',
                        value: _formatMoney(_averageCheck),
                        icon: Icons.analytics_outlined,
                        iconBg: FlutterFlowTheme.of(context)
                            .accent2
                            .withValues(alpha: 0.14),
                        iconColor: FlutterFlowTheme.of(context).accent2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: isMobile
                        ? Column(
                            children: [
                              Expanded(flex: 5, child: _buildCatalogPanel()),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 6,
                                child: _buildCartPanel(shiftOpen: shiftOpen),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(flex: 3, child: _buildCatalogPanel()),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildCartPanel(shiftOpen: shiftOpen),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildShiftHeader(bool shiftOpen) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: _isDarkTheme
              ? [const Color(0xFF182131), const Color(0xFF1F2430)]
              : [const Color(0xFFFFFFFF), const Color(0xFFFFF8ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _isDarkTheme ? _panelBorder : const Color(0xFFFFE2C0),
        ),
      ),
      child: Wrap(
        runSpacing: 10,
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  FlutterFlowTheme.of(context).warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.point_of_sale_outlined,
                color: FlutterFlowTheme.of(context).warning),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Режим кассы',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              Text(
                shiftOpen
                    ? 'Смена активна. Добавляйте позиции и принимайте оплату.'
                    : 'Откройте смену, чтобы начать продажи.',
                style: TextStyle(fontSize: 13, color: _mutedText),
              ),
            ],
          ),
          if (shiftOpen)
            _shiftMetaChip(
              icon: Icons.point_of_sale_outlined,
              label:
                  'Касса: ${_shift?.cashRegisterName.isNotEmpty == true ? _shift!.cashRegisterName : "Не выбрана"}',
            ),
          if (shiftOpen)
            _shiftMetaChip(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Старт: ${_formatMoney(_shift?.startingCash ?? 0)}',
            ),
          if (shiftOpen)
            SizedBox(
              width: 210,
              child: TextField(
                controller: _endCash,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Наличные при закрытии',
                  prefixIcon: Icon(Icons.wallet),
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: shiftOpen ? _closeShift : _openShift,
            icon:
                Icon(shiftOpen ? Icons.lock_outline : Icons.lock_open_rounded),
            label: Text(shiftOpen ? 'Закрыть смену' : 'Открыть смену'),
            style: ElevatedButton.styleFrom(
              backgroundColor: shiftOpen
                  ? const Color(0xFFEF4444)
                  : FlutterFlowTheme.of(context).success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftMetaChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _softText),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: FlutterFlowTheme.of(context).primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: _saleTarget == 'services'
                  ? 'Поиск услуги...'
                  : 'Поиск товара...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTargetChip(
                text: 'Товары',
                icon: Icons.inventory_2_outlined,
                selected: _saleTarget == 'products',
                onTap: () => setState(() => _saleTarget = 'products'),
              ),
              const SizedBox(width: 8),
              _buildTargetChip(
                text: 'Услуги',
                icon: Icons.design_services_outlined,
                selected: _saleTarget == 'services',
                onTap: () => setState(() => _saleTarget = 'services'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Text(
                      _saleTarget == 'services'
                          ? 'Услуги не найдены'
                          : 'Товары не найдены',
                      style: TextStyle(color: _mutedText),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = _filteredItems[index];
                      final kind = entry.itemKind;
                      final price = entry.effectivePrice;
                      final stock = entry.stock.toStringAsFixed(0);
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _addToCart(entry),
                        child: Ink(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: FlutterFlowTheme.of(context).alternate),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.name.isEmpty ? '-' : entry.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      kind == 'service'
                                          ? 'Услуга'
                                          : 'Остаток: $stock',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatMoney(price),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.add_circle,
                                  color: FlutterFlowTheme.of(context).primary,
                                  size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel({required bool shiftOpen}) {
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
              Text(
                'Корзина • ${_cart.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _cart.isEmpty
                    ? null
                    : () {
                        setState(() => _cartDocs = []);
                      },
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Очистить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Text(
                      'Добавьте товар или услугу',
                      style: TextStyle(color: _mutedText),
                    ),
                  )
                : ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = _cart[index];
                      final qty = entry.qty;
                      final price = entry.effectivePrice;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.name.isEmpty ? '-' : entry.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_formatMoney(price)} x $qty = ${_formatMoney(price * qty)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _updateQty(index, qty - 1),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                InkWell(
                                  onTap: () => _editQty(index),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(minWidth: 34),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      qty.toString(),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _updateQty(index, qty + 1),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 16),
          Text('Подытог: ${_formatMoney(_subtotal)}'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Скидка, %'),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '0',
                  ),
                  onChanged: (v) => setState(
                    () => _discount =
                        (double.tryParse(v.replaceAll(',', '.')) ?? 0)
                            .clamp(0, 100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Итого: ${_formatMoney(_total)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _payment,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Оплата',
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Наличные')),
              DropdownMenuItem(value: 'card', child: Text('Карта')),
              DropdownMenuItem(value: 'debt', child: Text('В долг')),
            ],
            onChanged: (v) => setState(() {
              _payment = v ?? 'cash';
              _saleExchangeRate.text = '1';
            }),
          ),
          if (_payment != 'debt') ...[
            const SizedBox(height: 8),
            FutureBuilder<AccountSelection>(
              future: _selectAccountForPaymentCached(_companyId, _payment),
              builder: (context, snapshot) {
                final account = snapshot.data;
                if (account == null || account.reference == null) {
                  return const SizedBox.shrink();
                }
                final accountCurrency = _accountCurrency(account);
                final companyCurrency = _companyCurrency(account);
                if (!_needsSaleExchangeRate(account)) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Счет: ${account.title} • $accountCurrency, курс 1',
                      style: TextStyle(color: _softText, fontSize: 12),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _saleExchangeRate,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Курс $accountCurrency → $companyCurrency',
                        helperText:
                            'В отчетах: ${formatMoneyWithCurrency(_saleCompanyAmount(account), currencyCode: companyCurrency)}',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Счет: ${account.title} • сумма в $accountCurrency',
                      style: TextStyle(color: _softText, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedClientId,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Клиент',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Без клиента'),
              ),
              ..._clients.map(
                (client) => DropdownMenuItem<String>(
                  value: client.id,
                  child: Text(
                    client.displayLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() {
              final next = (v ?? '').trim();
              _selectedClientId = next.isEmpty ? null : next;
            }),
          ),
          if (_payment == 'debt' && _selectedClientView != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isSelectedClientCreditLimitExceeded
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isSelectedClientCreditLimitExceeded
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF7DD3FC),
                ),
              ),
              child: Text(
                'Дебиторка: ${_formatMoney(_selectedClientOutstandingAr)}'
                ' / Лимит: ${_formatMoney(_selectedClientView!.creditLimit)}'
                ' / После продажи: ${_formatMoney(_selectedClientProjectedAr)}',
                style: TextStyle(
                  color: _isSelectedClientCreditLimitExceeded
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF075985),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: shiftOpen && _cart.isNotEmpty ? _pay : null,
              icon: const Icon(Icons.payments_rounded),
              label: Text(
                shiftOpen
                    ? (_cart.isEmpty
                        ? 'Добавьте позиции для оплаты'
                        : 'Оплатить')
                    : 'Сначала откройте смену',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetChip({
    required String text,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
      selected: selected,
      onSelected: (v) {
        if (!v) return;
        onTap();
      },
      selectedColor: FlutterFlowTheme.of(context).accent1,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      labelStyle: TextStyle(
        color: selected
            ? FlutterFlowTheme.of(context).primary
            : FlutterFlowTheme.of(context).primaryText,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? FlutterFlowTheme.of(context).primary.withValues(alpha: 0.35)
            : FlutterFlowTheme.of(context).alternate,
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
    return Container(
      width: 250,
      height: 104,
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: _mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
    );
  }
}
