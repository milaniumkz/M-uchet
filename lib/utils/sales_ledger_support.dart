import 'package:cloud_firestore/cloud_firestore.dart';
import 'ledger_scope.dart';

bool isSalesLedgerTransaction(Map<String, dynamic> transaction) {
  final type = (transaction['type'] ?? '').toString().trim().toLowerCase();
  if (type != 'income') return false;

  final saleId = (transaction['sale_id'] ?? '').toString().trim();
  if (saleId.isNotEmpty) return true;

  final source = (transaction['source'] ?? '').toString().trim().toLowerCase();
  return source == 'sales.cash_mode' || source == 'cash_mode';
}

DateTime? salesLedgerDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return null;
}

double salesLedgerNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

double salesLedgerCompanyAmount(Map<String, dynamic>? data) {
  final map = data ?? const <String, dynamic>{};
  return salesLedgerNum(
    map['amount_company'] ?? map['amountCompany'] ?? map['summa'],
  );
}

Map<String, dynamic> _normalizeDoc(Map<String, dynamic> raw, String id) {
  return <String, dynamic>{'id': id, ...raw};
}

DateTime? _entryDate(Map<String, dynamic> item) {
  return salesLedgerDate(item['created_at']) ??
      salesLedgerDate(item['date']) ??
      salesLedgerDate(item['updated_at']);
}

Map<String, dynamic> _buildLedgerEntry({
  required String id,
  required String companyId,
  required String saleId,
  required String transactionId,
  required double amount,
  required DateTime? createdAt,
  required String clientId,
  required String clientName,
  required String shopId,
  required String shopName,
  required String cashierId,
  required String cashierName,
  required String paymentMethod,
  required double discount,
  required String typeUchet,
  required LedgerScope ledgerScope,
  required String source,
  required bool orphanTransaction,
}) {
  return <String, dynamic>{
    'id': id,
    'idCompany': companyId,
    'sale_id': saleId,
    'transaction_id': transactionId,
    'amount': amount,
    'created_at': createdAt,
    'date': createdAt,
    'client_id': clientId,
    'client_name': clientName,
    'shop_id': shopId,
    'shop_name': shopName,
    'cashier_id': cashierId,
    'cashier_name': cashierName,
    'payment_method': paymentMethod,
    'discount': discount,
    'typeUchet': typeUchet,
    'ledger_scope': ledgerScope.storageValue,
    'source': source,
    'orphan_transaction': orphanTransaction,
  };
}

List<Map<String, dynamic>> buildSalesLedger({
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> transactions,
}) {
  final normalizedSales = sales
      .map((item) => _normalizeDoc(item, (item['id'] ?? '').toString()))
      .toList();
  final normalizedTransactions = transactions
      .map((item) => _normalizeDoc(item, (item['id'] ?? '').toString()))
      .where(isSalesLedgerTransaction)
      .toList();

  final txById = <String, Map<String, dynamic>>{};
  final txBySaleId = <String, Map<String, dynamic>>{};

  for (final tx in normalizedTransactions) {
    final txId = (tx['id'] ?? '').toString().trim();
    final saleId = (tx['sale_id'] ?? '').toString().trim();
    if (txId.isNotEmpty) {
      txById[txId] = tx;
    }
    if (saleId.isNotEmpty && !txBySaleId.containsKey(saleId)) {
      txBySaleId[saleId] = tx;
    }
  }

  final seenTransactionIds = <String>{};
  final ledger = <Map<String, dynamic>>[];

  for (final sale in normalizedSales) {
    final saleId = (sale['id'] ?? sale['sale_id'] ?? '').toString().trim();
    final linkedTxId = (sale['transaction_id'] ?? '').toString().trim();
    final tx = linkedTxId.isNotEmpty
        ? txById[linkedTxId] ?? txBySaleId[saleId]
        : txBySaleId[saleId];
    final txId = (tx?['id'] ?? linkedTxId).toString().trim();
    if (txId.isNotEmpty) {
      seenTransactionIds.add(txId);
    }

    final txAmount = salesLedgerCompanyAmount(tx);
    final saleAmount = salesLedgerNum(sale['amount']);
    final amount = txAmount > 0 ? txAmount : saleAmount;
    final createdAt = _entryDate(tx ?? const <String, dynamic>{}) ??
        _entryDate(sale) ??
        DateTime.now();

    ledger.add(_buildLedgerEntry(
      id: saleId.isNotEmpty
          ? saleId
          : (txId.isNotEmpty
              ? txId
              : createdAt.microsecondsSinceEpoch.toString()),
      companyId:
          (sale['idCompany'] ?? tx?['idCompany'] ?? '').toString().trim(),
      saleId: saleId,
      transactionId: txId,
      amount: amount,
      createdAt: createdAt,
      clientId: (sale['client_id'] ?? tx?['client_id'] ?? '').toString().trim(),
      clientName:
          (sale['client_name'] ?? tx?['client_name'] ?? '').toString().trim(),
      shopId: (sale['shop_id'] ?? tx?['shop_id'] ?? '').toString().trim(),
      shopName: (sale['shop_name'] ?? tx?['shop_name'] ?? '').toString().trim(),
      cashierId:
          (sale['cashier_id'] ?? tx?['cashier_id'] ?? '').toString().trim(),
      cashierName:
          (sale['cashier_name'] ?? tx?['cashier_name'] ?? '').toString().trim(),
      paymentMethod: (sale['payment_method'] ?? tx?['payment_method'] ?? '')
          .toString()
          .trim(),
      discount: salesLedgerNum(sale['discount']),
      typeUchet:
          (sale['typeUchet'] ?? tx?['typeUchet'] ?? '').toString().trim(),
      ledgerScope: ledgerScopeFromData(
        tx ?? sale,
      ),
      source: (tx?['source'] ?? sale['source'] ?? 'sales').toString().trim(),
      orphanTransaction: false,
    ));
  }

  for (final tx in normalizedTransactions) {
    final txId = (tx['id'] ?? '').toString().trim();
    if (txId.isEmpty || seenTransactionIds.contains(txId)) {
      continue;
    }
    final saleId = (tx['sale_id'] ?? '').toString().trim();
    final createdAt = _entryDate(tx) ?? DateTime.now();
    ledger.add(_buildLedgerEntry(
      id: saleId.isNotEmpty ? saleId : txId,
      companyId: (tx['idCompany'] ?? '').toString().trim(),
      saleId: saleId,
      transactionId: txId,
      amount: salesLedgerCompanyAmount(tx),
      createdAt: createdAt,
      clientId: (tx['client_id'] ?? '').toString().trim(),
      clientName: (tx['client_name'] ?? '').toString().trim(),
      shopId: (tx['shop_id'] ?? '').toString().trim(),
      shopName: (tx['shop_name'] ?? '').toString().trim(),
      cashierId: (tx['cashier_id'] ?? '').toString().trim(),
      cashierName: (tx['cashier_name'] ?? '').toString().trim(),
      paymentMethod: (tx['payment_method'] ?? '').toString().trim(),
      discount: 0,
      typeUchet: (tx['typeUchet'] ?? '').toString().trim(),
      ledgerScope: ledgerScopeFromData(tx),
      source: (tx['source'] ?? 'sales').toString().trim(),
      orphanTransaction: true,
    ));
  }

  ledger.sort((a, b) {
    final ad = _entryDate(a) ?? DateTime(1970);
    final bd = _entryDate(b) ?? DateTime(1970);
    return bd.compareTo(ad);
  });
  return ledger;
}
