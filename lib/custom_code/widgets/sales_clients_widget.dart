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
import '/utils/accounting_entry_service.dart';
import '/utils/country_profile.dart';
import '/utils/debt_aging_service.dart';
import '/utils/debt_register_support.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/effective_company_support.dart';
import '/utils/export_transactions.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/money_flow_type.dart';
import '/utils/money_wallet_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/sales_client_profit_support.dart';
import '/utils/sales_ledger_support.dart';
import '/utils/transaction_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class SalesClientsWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SalesClientsWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SalesClientsWidget> createState() => _SalesClientsWidgetState();
}

class _SalesClientsWidgetState extends State<SalesClientsWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  String _companyId = '';
  List<Map<String, dynamic>> _clients = [];
  List<SaleEntryView> _sales = [];
  List<Map<String, dynamic>> _salesRaw = [];
  List<Map<String, dynamic>> _salesItems = [];
  List<Map<String, dynamic>> _cogsItems = [];
  List<DebtRecordView> _debts = [];
  List<Map<String, dynamic>> _debtRaw = [];
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
          _clients = [];
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
            .collection('clients')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('sales')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('sales_items')
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
            .collection('tranzaction')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection('debt_register')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .get(const GetOptions(source: Source.serverAndCache)),
      ]);
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      final clientsSnap = results[0] as QuerySnapshot;
      final salesSnap = results[1] as QuerySnapshot;
      final salesItemsSnap = results[2] as QuerySnapshot;
      final cogsEntrySnap = results[3] as QuerySnapshot;
      final legacyCogsSnap = results[4] as QuerySnapshot;
      final txSnap = results[5] as QuerySnapshot;
      final debtSnap = results[6] as QuerySnapshot;

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _companyId = effectiveCompanyId;
        _clients = clientsSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        final sales = salesSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _salesRaw = sales;
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
        final transactions = txSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _sales = buildSalesLedger(sales: sales, transactions: transactions)
            .map(SaleEntryView.fromMap)
            .toList();
        _debtRaw = debtSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _debts = _debtRaw.map(DebtRecordView.fromMap).toList();
      });
    } catch (e) {
      debugPrint('Error loading clients: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  String _clientTypeLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value == 'legal') return 'Юр.лицо';
    return 'Физ.лицо';
  }

  double get _totalRevenue => _sales.fold(0, (s, i) => s + i.amount);
  double get _totalCogs =>
      _clientProfitRows.fold(0, (total, row) => total + row.cogs);
  double get _totalGrossProfit =>
      _clientProfitRows.fold(0, (total, row) => total + row.grossProfit);
  int get _totalOrders => _sales.length;

  List<SalesClientProfitRow> get _clientProfitRows =>
      buildSalesClientProfitRows(
        salesLedger: _sales
            .map((sale) => {
                  'sale_id': sale.id,
                  'client_id': sale.clientId,
                  'client_name': sale.clientName,
                  'amount': sale.amount,
                  'created_at': sale.createdAt,
                })
            .toList(),
        salesItems: _salesItems,
      );

  Map<String, SalesClientProfitRow> get _statsByClient {
    final map = <String, SalesClientProfitRow>{};
    for (final row in _clientProfitRows) {
      map[row.key] = row;
      final normalizedName = row.clientName.trim().toLowerCase();
      if (normalizedName.isNotEmpty) {
        map.putIfAbsent('name:$normalizedName', () => row);
      }
    }
    return map;
  }

  int get _activeClients => _clients.where((c) {
        final id = (c['id'] ?? '').toString();
        final name = (c['name'] ?? '').toString();
        return _statsByClient.containsKey('id:$id') ||
            _statsByClient.containsKey('name:${name.trim().toLowerCase()}');
      }).length;

  double get _avgPurchase =>
      _totalOrders == 0 ? 0 : _totalRevenue / _totalOrders;

  double get _totalReceivables => _debts
      .where((debt) =>
          debt.type == DebtType.ar &&
          debt.isOpen &&
          debt.ledgerScope.matches(LedgerScope.management))
      .fold(0, (total, debt) => total + debt.remainingAmount);

  double get _totalReceivablesOriginal => _debts
      .where((debt) =>
          debt.type == DebtType.ar &&
          debt.ledgerScope.matches(LedgerScope.management))
      .fold(0, (total, debt) => total + debt.totalAmount);

  double get _totalReceivablesPaid => _debts
      .where((debt) =>
          debt.type == DebtType.ar &&
          debt.ledgerScope.matches(LedgerScope.management))
      .fold(
        0,
        (total, debt) =>
            total +
            (debt.totalAmount - debt.remainingAmount).clamp(0, double.infinity),
      );

  List<DebtRecordView> _receivableDebtsForClient(Map<String, dynamic> client) {
    final id = (client['id'] ?? '').toString().trim();
    final name = (client['name'] ?? '').toString().trim().toLowerCase();
    return _debts.where((debt) {
      if (debt.type != DebtType.ar || !debt.isOpen) return false;
      if (!debt.ledgerScope.matches(LedgerScope.management)) return false;
      if (id.isNotEmpty && debt.counterpartyId == id) return true;
      return name.isNotEmpty &&
          debt.counterpartyName.trim().toLowerCase() == name;
    }).toList()
      ..sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });
  }

  double _receivableOutstandingForClient(Map<String, dynamic> client) =>
      _receivableDebtsForClient(client)
          .fold(0, (total, debt) => total + debt.remainingAmount);

  double _creditLimitForClient(Map<String, dynamic> client) {
    final raw = client['credit_limit'] ?? client['creditLimit'];
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().replaceAll(',', '.')) ?? 0;
  }

  bool _isCreditLimitExceededForClient(Map<String, dynamic> client) {
    final creditLimit = _creditLimitForClient(client);
    if (creditLimit <= 0) return false;
    return _receivableOutstandingForClient(client) - creditLimit > 0.000001;
  }

  int get _limitExceededClientsCount =>
      _clients.where(_isCreditLimitExceededForClient).length;

  List<_ReceivableObjectRow> get _objectReceivableRows {
    final rows = <String, _ReceivableObjectRow>{};

    void add({
      required String objectName,
      required String unitNumber,
      required String clientName,
      required double total,
      required double remaining,
      DateTime? nextPaymentAt,
    }) {
      final key = [
        objectName.trim().toLowerCase(),
        unitNumber.trim().toLowerCase(),
        clientName.trim().toLowerCase(),
      ].where((e) => e.isNotEmpty).join('|');
      if (key.isEmpty) return;
      final row = rows.putIfAbsent(
        key,
        () => _ReceivableObjectRow(
          objectName: objectName.trim(),
          unitNumber: unitNumber.trim(),
          clientName: clientName.trim(),
        ),
      );
      row.total += total;
      row.remaining += remaining;
      final paid = (total - remaining).clamp(0, double.infinity).toDouble();
      row.paid += paid;
      if (nextPaymentAt != null &&
          (row.nextPaymentAt == null ||
              nextPaymentAt.isBefore(row.nextPaymentAt!))) {
        row.nextPaymentAt = nextPaymentAt;
      }
    }

    for (final raw in _salesRaw) {
      final sale = SaleEntryView.fromMap(raw);
      final objectName =
          (raw['object_name'] ?? raw['objectName'] ?? '').toString();
      final unitNumber =
          (raw['unit_number'] ?? raw['unitNumber'] ?? '').toString();
      if (objectName.trim().isEmpty && unitNumber.trim().isEmpty) continue;
      final total = sale.amount;
      final matchingDebts = _debts.where((debt) {
        if (debt.type != DebtType.ar || !debt.isOpen) return false;
        if (debt.counterpartyId.isNotEmpty &&
            debt.counterpartyId == sale.clientId) {
          return true;
        }
        return debt.counterpartyName.trim().toLowerCase() ==
            sale.clientName.trim().toLowerCase();
      }).toList();
      final remaining = matchingDebts.fold<double>(
        0,
        (sum, debt) => sum + debt.remainingAmount,
      );
      add(
        objectName: objectName,
        unitNumber: unitNumber,
        clientName: sale.clientName,
        total: total,
        remaining: remaining > 0 ? remaining : 0,
        nextPaymentAt: _nextPaymentDate(raw['payment_schedule']),
      );
    }

    for (final raw in _debtRaw) {
      final debt = DebtRecordView.fromMap(raw);
      final objectName =
          (raw['object_name'] ?? raw['objectName'] ?? '').toString();
      final unitNumber =
          (raw['unit_number'] ?? raw['unitNumber'] ?? '').toString();
      if (objectName.trim().isEmpty && unitNumber.trim().isEmpty) continue;
      add(
        objectName: objectName,
        unitNumber: unitNumber,
        clientName: debt.counterpartyName,
        total: debt.totalAmount,
        remaining: debt.remainingAmount,
        nextPaymentAt: _nextPaymentDate(
          raw['payment_schedule'] ?? raw['paymentSchedule'],
        ),
      );
    }

    return rows.values.toList()
      ..sort((a, b) => b.remaining.compareTo(a.remaining));
  }

  DateTime? _nextPaymentDate(dynamic schedule) {
    if (schedule is! Iterable) return null;
    final now = DateTime.now();
    DateTime? next;
    for (final item in schedule) {
      if (item is! Map) continue;
      final paid = item['paid'] == true || item['status'] == 'paid';
      if (paid) continue;
      final raw = item['date'] ?? item['due_date'] ?? item['dueDate'];
      DateTime? date;
      if (raw is DateTime) {
        date = raw;
      } else {
        try {
          final dynamic value = raw;
          final converted = value.toDate();
          if (converted is DateTime) date = converted;
        } catch (_) {
          date = DateTime.tryParse((raw ?? '').toString());
        }
      }
      if (date == null || date.isBefore(now)) continue;
      if (next == null || date.isBefore(next)) next = date;
    }
    return next;
  }

  Future<void> _showReceivablePaymentDialog(Map<String, dynamic> client) async {
    final debts = _receivableDebtsForClient(client);
    if (debts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Открытая дебиторка не найдена')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _ClientReceivablePaymentDialog(
        companyId: _companyId,
        client: client,
        debts: debts,
        onSaved: _loadData,
      ),
    );
  }

  Set<String> _saleIdsForClient(Map<String, dynamic> client) {
    final id = (client['id'] ?? '').toString().trim();
    final name = (client['name'] ?? '').toString().trim().toLowerCase();
    return _sales
        .where((sale) {
          if (id.isNotEmpty && sale.clientId == id) return true;
          return name.isNotEmpty &&
              sale.clientName.trim().toLowerCase() == name;
        })
        .map((sale) => sale.id)
        .where((saleId) => saleId.trim().isNotEmpty)
        .toSet();
  }

  Future<void> _showClientCogsDialog(Map<String, dynamic> client) async {
    final saleIds = _saleIdsForClient(client);
    final rows = buildSaleItemCogsReportRowsForSaleIds(
      cogsItems: _cogsItems,
      saleIds: saleIds,
    );
    final title = (client['name'] ?? 'Клиент').toString().trim();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('COGS: ${title.isEmpty ? 'Клиент' : title}'),
        content: SizedBox(
          width: 880,
          child: rows.isEmpty
              ? const Text('Детализация COGS отсутствует')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        row.productName.isEmpty
                            ? 'Без названия'
                            : row.productName,
                      ),
                      subtitle: Text(
                        '${row.warehouseName.isEmpty ? '—' : row.warehouseName} · ${row.costingMethod} · ${row.batchBreakdown.join(', ')}',
                      ),
                      trailing: Text(_formatMoney(row.totalCost)),
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

  Future<void> _exportClients() async {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет данных для выгрузки')),
      );
      return;
    }
    final rows = <List<String>>[
      [
        'Клиент',
        'Тип',
        'Телефон',
        'Email',
        'Покупки',
        'Сумма',
        'Последняя покупка',
        'Комментарий',
      ],
    ];
    for (final client in _clients) {
      final id = (client['id'] ?? '').toString();
      final name = (client['name'] ?? '').toString();
      final stats = _statsByClient['id:$id'] ??
          _statsByClient['name:${name.trim().toLowerCase()}'];
      final last = stats?.lastPurchaseAt;
      rows.add([
        name,
        _clientTypeLabel(client['client_type']),
        (client['phone'] ?? '').toString(),
        (client['email'] ?? '').toString(),
        (stats?.orders ?? 0).toString(),
        (stats?.revenue ?? 0).toStringAsFixed(2),
        last == null ? '' : dateTimeFormat('dd.MM.yyyy', last),
        (client['note'] ?? '').toString(),
      ]);
    }
    final now = DateTime.now();
    await exportTransactionsCsv(
      filename: 'clients_${now.year}-${now.month}-${now.day}.csv',
      rows: rows,
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _ClientDialog(
        companyId: _companyId,
        onSaved: _loadData,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    if (!EditingHelper.guardEdit(context)) return;
    showDialog(
      context: context,
      builder: (context) => _ClientDialog(
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
            title: const Text('Удалить клиента?'),
            content: Text(
              name.isEmpty
                  ? 'Клиент будет удален без возможности восстановления.'
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
      await _firestore.collection('clients').doc(item['id']).delete();
      await _firestore.collection('activity_log').add({
        'idCompany': _companyId,
        'user_id': _auth.currentUser?.uid ?? '',
        'user_name': currentUserDocument?.displayName ??
            _auth.currentUser?.displayName ??
            _auth.currentUser?.email ??
            '',
        'action': 'delete',
        'entity': 'client',
        'entity_id': item['id'],
        'entity_name': item['name'],
        'created_at': FieldValue.serverTimestamp(),
      });
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('clients', _companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('activity_log', _companyId);
      await _loadData();
    } catch (e) {
      debugPrint('Error deleting client: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('sales.clients')) {
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
                    color: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_outline,
                      color: Color(0xFFF97316)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Клиенты',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'База клиентов и история покупок',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _exportClients,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Экспорт в Excel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Добавить клиента'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).warning,
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
                  title: 'Клиенты',
                  value: _clients.length.toString(),
                  icon: Icons.people,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.12),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Активные',
                  value: _activeClients.toString(),
                  icon: Icons.trending_up,
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
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Средний чек',
                  value: _formatMoney(_avgPurchase),
                  amount: _avgPurchase,
                  icon: Icons.receipt_long,
                  iconBg: FlutterFlowTheme.of(context).accent1,
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Дебиторка',
                  value: _formatMoney(_totalReceivables),
                  amount: _totalReceivables,
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .warning
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).warning,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Должны получить',
                  value: _formatMoney(_totalReceivablesOriginal),
                  amount: _totalReceivablesOriginal,
                  icon: Icons.event_note_outlined,
                  iconBg: FlutterFlowTheme.of(context)
                      .primary
                      .withValues(alpha: 0.12),
                  iconColor: FlutterFlowTheme.of(context).primary,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Получили',
                  value: _formatMoney(_totalReceivablesPaid),
                  amount: _totalReceivablesPaid,
                  icon: Icons.done_all_rounded,
                  iconBg: FlutterFlowTheme.of(context)
                      .success
                      .withValues(alpha: 0.14),
                  iconColor: FlutterFlowTheme.of(context).success,
                ),
                const SizedBox(width: 12),
                _statCard(
                  title: 'Лимит превышен',
                  value: _limitExceededClientsCount.toString(),
                  amount: _limitExceededClientsCount,
                  icon: Icons.warning_amber_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFB91C1C),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _objectsReceivableSection(),
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
                          'Список клиентов',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _clients.isEmpty
                              ? Center(
                                  child: Text(
                                    'Клиенты не найдены',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _clients.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_clients[index]);
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

  Widget _objectsReceivableSection() {
    final rows = _objectReceivableRows;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Объекты / квартиры: график оплат и дебиторка',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              'Данных по объектам пока нет',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).secondaryText),
            )
          else ...[
            const Row(
              children: [
                _HeaderCell('Объект', flex: 3),
                _HeaderCell('Клиент', flex: 3),
                _HeaderCell('Должны получить', flex: 2),
                _HeaderCell('Получили', flex: 2),
                _HeaderCell('Осталось', flex: 2),
                _HeaderCell('Ближайший платеж', flex: 2),
              ],
            ),
            const Divider(height: 1),
            ...rows.take(8).map((row) {
              final title = [
                row.objectName,
                row.unitNumber.isEmpty ? null : 'кв. ${row.unitNumber}',
              ].whereType<String>().where((e) => e.isNotEmpty).join(' / ');
              final next = row.nextPaymentAt == null
                  ? '-'
                  : dateTimeFormat(
                      'dd.MM.yyyy',
                      row.nextPaymentAt,
                      locale: FFLocalizations.of(context).languageCode,
                    );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _Cell(title.isEmpty ? '-' : title, flex: 3, bold: true),
                    _Cell(row.clientName.isEmpty ? '-' : row.clientName,
                        flex: 3),
                    _Cell(_formatMoney(row.total), flex: 2, amount: row.total),
                    _Cell(_formatMoney(row.paid), flex: 2, amount: row.paid),
                    _Cell(_formatMoney(row.remaining),
                        flex: 2, amount: row.remaining),
                    _Cell(next, flex: 2),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return const Row(
      children: [
        _HeaderCell('Клиент', flex: 3),
        _HeaderCell('Тип', flex: 2),
        _HeaderCell('Телефон', flex: 2),
        _HeaderCell('Покупки', flex: 1),
        _HeaderCell('Сумма', flex: 2),
        _HeaderCell('COGS', flex: 2),
        _HeaderCell('Валовая', flex: 2),
        _HeaderCell('AR', flex: 2),
        _HeaderCell('Лимит', flex: 2),
        _HeaderCell('Риск', flex: 1),
        _HeaderCell('Последняя', flex: 2),
        _HeaderCell('Детали', flex: 1),
        _HeaderCell('Действия', flex: 1),
      ],
    );
  }

  Widget _tableRow(Map<String, dynamic> client) {
    final id = (client['id'] ?? '').toString();
    final name = (client['name'] ?? '').toString();
    final phone = (client['phone'] ?? '').toString();
    final clientType = _clientTypeLabel(client['client_type']);
    final stats = _statsByClient['id:$id'] ??
        _statsByClient['name:${name.trim().toLowerCase()}'];
    final last = stats?.lastPurchaseAt;
    final lastText = last == null
        ? '-'
        : dateTimeFormat(
            'dd.MM.yyyy',
            last,
            locale: FFLocalizations.of(context).languageCode,
          );
    final receivable = _receivableOutstandingForClient(client);
    final creditLimit = _creditLimitForClient(client);
    final limitExceeded = _isCreditLimitExceededForClient(client);

    return LiveDiffHighlight(
      timestamp: client['updated_at'] ?? client['created_at'],
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
            _Cell(name.isEmpty ? '-' : name, flex: 3, bold: true),
            _Cell(clientType, flex: 2),
            _Cell(phone.isEmpty ? '-' : phone, flex: 2),
            _Cell((stats?.orders ?? 0).toString(), flex: 1),
            _Cell(
              _formatMoney(stats?.revenue ?? 0),
              flex: 2,
              amount: stats?.revenue ?? 0,
            ),
            _Cell(
              _formatMoney(stats?.cogs ?? 0),
              flex: 2,
              amount: stats?.cogs ?? 0,
            ),
            _Cell(
              _formatMoney(stats?.grossProfit ?? 0),
              flex: 2,
              amount: stats?.grossProfit ?? 0,
            ),
            _Cell(
              _formatMoney(receivable),
              flex: 2,
              amount: receivable,
            ),
            _Cell(
              _formatMoney(creditLimit),
              flex: 2,
              amount: creditLimit,
            ),
            Expanded(
              flex: 1,
              child: Text(
                limitExceeded ? 'Лимит' : '—',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: limitExceeded ? const Color(0xFFB91C1C) : null,
                ),
              ),
            ),
            _Cell(lastText, flex: 2),
            Expanded(
              flex: 1,
              child: IconButton(
                onPressed: () => _showClientCogsDialog(client),
                icon: const Icon(Icons.receipt_long, size: 18),
                tooltip: 'COGS детализация',
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: () => _showEditDialog(client),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: receivable <= 0
                          ? null
                          : () => _showReceivablePaymentDialog(client),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      tooltip: 'Принять оплату',
                    ),
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: () => _confirmDelete(client),
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

class _ReceivableObjectRow {
  _ReceivableObjectRow({
    required this.objectName,
    required this.unitNumber,
    required this.clientName,
  });

  final String objectName;
  final String unitNumber;
  final String clientName;
  double total = 0;
  double paid = 0;
  double remaining = 0;
  DateTime? nextPaymentAt;
}

class _ClientDialog extends StatefulWidget {
  final String companyId;
  final Map<String, dynamic>? item;
  final VoidCallback onSaved;

  const _ClientDialog({
    required this.companyId,
    required this.onSaved,
    this.item,
  });

  @override
  State<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<_ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _note;
  late final TextEditingController _creditLimit;
  String _clientType = 'individual';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name =
        TextEditingController(text: (widget.item?['name'] ?? '').toString());
    _phone =
        TextEditingController(text: (widget.item?['phone'] ?? '').toString());
    _email =
        TextEditingController(text: (widget.item?['email'] ?? '').toString());
    _note =
        TextEditingController(text: (widget.item?['note'] ?? '').toString());
    final savedCreditLimit =
        (widget.item?['credit_limit'] ?? widget.item?['creditLimit'] ?? 0)
            .toString()
            .trim();
    _creditLimit = TextEditingController(
      text: savedCreditLimit.isEmpty ? '0' : savedCreditLimit,
    );
    final savedType = (widget.item?['client_type'] ?? '').toString().trim();
    _clientType = savedType == 'legal' ? 'legal' : 'individual';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _note.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.item != null && !EditingHelper.guardEdit(context)) return;
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');
      final currentCompanyId = (currentUserDocument?.idCompany ?? '').trim();
      final effectiveCompanyId = widget.companyId.isNotEmpty
          ? widget.companyId
          : currentCompanyId.isNotEmpty
              ? currentCompanyId
              : user.uid;

      final data = {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'note': _note.text.trim(),
        'credit_limit':
            double.tryParse(_creditLimit.text.trim().replaceAll(',', '.')) ?? 0,
        'client_type': _clientType,
        'user_id': user.uid,
        'idCompany': effectiveCompanyId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.item == null) {
        final docRef = await _firestore.collection('clients').add({
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
          'entity': 'client',
          'entity_id': docRef.id,
          'entity_name': _name.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore
            .collection('clients')
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
          'entity': 'client',
          'entity_id': widget.item!['id'],
          'entity_name': _name.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('clients', effectiveCompanyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('activity_log', effectiveCompanyId);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      debugPrint('Error saving client: $e');
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
                  isEdit ? 'Редактировать клиента' : 'Добавить клиента',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _field(_name, 'Имя', required: true),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    initialValue: _clientType,
                    decoration: const InputDecoration(
                      labelText: 'Тип клиента',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'individual',
                        child: Text('Физ.лицо'),
                      ),
                      DropdownMenuItem(
                        value: 'legal',
                        child: Text('Юр.лицо'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _clientType = value == 'legal' ? 'legal' : 'individual';
                      });
                    },
                  ),
                ),
                _field(_phone, 'Телефон'),
                _field(_email, 'Email'),
                _field(_note, 'Комментарий'),
                _field(_creditLimit, 'Кредитный лимит'),
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
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: (v) {
          if (required && (v == null || v.isEmpty)) return 'Обязательное поле';
          return null;
        },
      ),
    );
  }
}

class _ClientReceivablePaymentDialog extends StatefulWidget {
  const _ClientReceivablePaymentDialog({
    required this.companyId,
    required this.client,
    required this.debts,
    required this.onSaved,
  });

  final String companyId;
  final Map<String, dynamic> client;
  final List<DebtRecordView> debts;
  final Future<void> Function() onSaved;

  @override
  State<_ClientReceivablePaymentDialog> createState() =>
      _ClientReceivablePaymentDialogState();
}

class _ClientReceivablePaymentDialogState
    extends State<_ClientReceivablePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _textController = TextEditingController();
  bool _saving = false;
  DateTime? _date = DateTime.now();
  DocumentReference? _schetId;
  String _schetTitle = '';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  double get _outstandingTotal =>
      widget.debts.fold(0, (total, debt) => total + debt.remainingAmount);

  @override
  void initState() {
    super.initState();
    _amountController.text = _outstandingTotal.toStringAsFixed(0);
    final clientName = (widget.client['name'] ?? '').toString().trim();
    _textController.text = 'Погашение дебиторки: $clientName';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAccount() async {
    final selected = await TransactionSync.selectAccount(
      widget.companyId,
      tip: 'my',
    );
    setState(() {
      _schetId = selected.reference;
      _schetTitle = selected.title;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_schetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите счет для оплаты')),
      );
      return;
    }
    final amount = double.tryParse(
          _amountController.text.replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0;
    if (amount <= 0 || amount - _outstandingTotal > 0.000001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сумма оплаты превышает дебиторку')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final clientName = (widget.client['name'] ?? '').toString().trim();
      final clientId = (widget.client['id'] ?? '').toString().trim();
      final wallet = await ensureWalletForAccountReference(
        firestore: _firestore,
        accountRef: _schetId,
        fallbackTitle: _schetTitle,
      );
      final accountSnap = await _schetId?.get();
      final accountData = accountSnap?.data() is Map
          ? Map<String, dynamic>.from(accountSnap!.data() as Map)
          : null;
      final txRef = TranzactionRecord.collection.doc();
      final txData = {
        ...createTranzactionRecordData(
          type: 'income',
          typeUchet: LedgerScope.management.legacyTypeUchet,
          ledgerScope: LedgerScope.management.storageValue,
          kat: 'Погашение дебиторки',
          text: _textController.text.trim(),
          summa: amount,
          nds: false,
          summaNds: 0,
          idCompany: widget.companyId,
          schetId: _schetId,
          schetTitle: _schetTitle,
          walletId: wallet?.reference.id,
          walletName: wallet?.name,
          walletType: wallet?.type,
          moneyFlowType: MoneyFlowType.operating.storageValue,
          date: _date,
          status: 'Проведена',
          counterparty: clientName,
        ),
        ...mapToFirestore(
          transactionMoneyFieldsForAccountData(
            amountOriginal: amount,
            accountData: accountData,
            exchangeRateDate: _date,
          ),
        ),
        'client_id': clientId,
        'settles_receivable': true,
        'settlesReceivable': true,
      };
      await txRef.set({
        ...txData,
        ...mapToFirestore({'date': _date ?? FieldValue.serverTimestamp()}),
      });
      await createEntriesForTransaction(
        firestore: _firestore,
        transactionRef: txRef,
        transactionData: txData,
      );

      final paymentResult = applyDebtPaymentFifo(
        debts: widget.debts,
        paymentAmount: amount,
      );
      for (final debt in paymentResult.updatedDebts) {
        await _firestore.collection('debt_register').doc(debt.id).set(
              buildDebtRecordPayload(
                idCompany: debt.idCompany,
                type: debt.type,
                counterpartyId: debt.counterpartyId,
                counterpartyName: debt.counterpartyName,
                sourceDocumentId: debt.sourceDocumentId,
                sourceType: debt.sourceType,
                totalAmount: debt.totalAmount,
                remainingAmount: debt.remainingAmount,
                ledgerScope: debt.ledgerScope,
                currency: debt.currency,
                dueDate: debt.dueDate,
                createdAt: debt.createdAt,
                creditLimit: debt.creditLimit,
              ),
              SetOptions(merge: true),
            );
      }
      for (final allocation in paymentResult.allocations) {
        await _firestore.collection('debt_payment_links').doc().set(
              buildDebtPaymentLinkPayload(
                idCompany: widget.companyId,
                debtId: allocation.debtId,
                paymentTransactionId: txRef.id,
                amount: allocation.amount,
                ledgerScope: LedgerScope.management,
                createdAt: _date,
              ),
            );
      }

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('tranzaction', widget.companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('debt_register', widget.companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('debt_payment_links', widget.companyId);
      await TransactionSync.recomputeAllForCompany(widget.companyId);
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentResult.unappliedAmount > 0.000001
                ? 'Часть суммы не распределена: ${paymentResult.unappliedAmount.toStringAsFixed(2)}'
                : 'Оплата дебиторки сохранена',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error receiving AR payment: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = (widget.client['name'] ?? 'Клиент').toString();
    final aging = DebtAgingService.compute(
      debts: widget.debts,
      asOf: DateTime.now(),
      type: DebtType.ar,
    );
    return AlertDialog(
      title: Text('Погашение дебиторки: $clientName'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Открытая дебиторка: ${_outstandingTotal.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text(
                '0-30: ${aging.bucket0To30.toStringAsFixed(2)} · 90+: ${aging.bucket90Plus.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(
                        (value ?? '').replaceAll(' ', '').replaceAll(',', '.'),
                      ) ??
                      0;
                  if (amount <= 0) return 'Введите сумму';
                  if (amount - _outstandingTotal > 0.000001) {
                    return 'Сумма больше открытой дебиторки';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Дата',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _date == null
                        ? 'Не выбрана'
                        : dateTimeFormat('dd.MM.yyyy', _date),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickAccount,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Счёт',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _schetTitle.isEmpty ? 'Выбрать счёт' : _schetTitle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}
