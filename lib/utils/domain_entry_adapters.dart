import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/ledger_scope.dart';
import '/utils/service_accounting_support.dart';
import '/utils/country_profile.dart';

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String _string(dynamic value) => value?.toString().trim() ?? '';

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class SaleEntryView {
  const SaleEntryView({
    required this.id,
    required this.companyId,
    required this.amount,
    required this.createdAt,
    required this.clientId,
    required this.shopName,
    required this.clientName,
    required this.cashierId,
    required this.cashierName,
    required this.cashRegisterId,
    required this.cashRegisterName,
    required this.discount,
    required this.paymentMethod,
    required this.ledgerScope,
    required this.typeUchet,
    required this.source,
  });

  final String id;
  final String companyId;
  final double amount;
  final DateTime? createdAt;
  final String clientId;
  final String shopName;
  final String clientName;
  final String cashierId;
  final String cashierName;
  final String cashRegisterId;
  final String cashRegisterName;
  final double discount;
  final String paymentMethod;
  final LedgerScope ledgerScope;
  final String typeUchet;
  final String source;

  factory SaleEntryView.fromMap(Map<String, dynamic> data) {
    return SaleEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      amount: _num(data['amount']),
      createdAt: _date(data['date']) ??
          _date(data['created_at']) ??
          _date(data['updated_at']),
      clientId: _string(data['client_id']),
      shopName: _string(data['shop_name']),
      clientName: _string(data['client_name']),
      cashierId: _string(data['cashier_id']),
      cashierName: _string(data['cashier_name']),
      cashRegisterId: _string(data['cash_register_id']),
      cashRegisterName: _string(data['cash_register_name']),
      discount: _num(data['discount']),
      paymentMethod: _string(data['payment_method']),
      ledgerScope: ledgerScopeFromData(data),
      typeUchet: normalizeLegacyTypeUchet(_string(data['typeUchet'])),
      source: _string(data['source']),
    );
  }
}

class ExpenseEntryView {
  const ExpenseEntryView({
    required this.id,
    required this.companyId,
    required this.amount,
    required this.createdAt,
    required this.shopName,
    required this.category,
    required this.ledgerScope,
    required this.typeUchet,
  });

  final String id;
  final String companyId;
  final double amount;
  final DateTime? createdAt;
  final String shopName;
  final String category;
  final LedgerScope ledgerScope;
  final String typeUchet;

  factory ExpenseEntryView.fromMap(Map<String, dynamic> data) {
    return ExpenseEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      amount: _num(data['amount']),
      createdAt: _date(data['date']) ??
          _date(data['created_at']) ??
          _date(data['updated_at']),
      shopName: _string(data['shop_name']),
      category: _string(data['category']),
      ledgerScope: ledgerScopeFromData(data),
      typeUchet: normalizeLegacyTypeUchet(_string(data['typeUchet'])),
    );
  }
}

class ServiceEntryView {
  const ServiceEntryView({
    required this.id,
    required this.companyId,
    required this.name,
    required this.code,
    required this.description,
    required this.category,
    required this.price,
    required this.vat,
    required this.isActive,
    required this.ledgerScope,
    required this.costingType,
    required this.fixedCost,
    required this.variableCost,
    required this.defaultUnitCost,
    required this.currency,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String code;
  final String description;
  final String category;
  final double price;
  final int vat;
  final bool isActive;
  final LedgerScope ledgerScope;
  final ServiceCostingType costingType;
  final double fixedCost;
  final double variableCost;
  final double defaultUnitCost;
  final String currency;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ServiceEntryView.fromMap(Map<String, dynamic> data) {
    return ServiceEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      name: _string(data['name']),
      code: _string(data['code']),
      description: _string(data['description']),
      category: _string(data['category']),
      price: _num(data['base_price']).abs() > 0
          ? _num(data['base_price'])
          : _num(data['price']),
      vat: _num(data['vat']).round(),
      isActive: data['is_active'] != false,
      ledgerScope: ledgerScopeFromData(data),
      costingType: serviceCostingTypeFromValue(
        _string(data['costing_type']).isEmpty
            ? _string(data['service_costing_type'])
            : _string(data['costing_type']),
      ),
      fixedCost: _num(data['fixed_cost']),
      variableCost: _num(data['variable_cost']),
      defaultUnitCost: _num(data['default_unit_cost']),
      currency: normalizeCurrencyCode(_string(data['currency'])),
      notes: _string(data['notes']),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }
}

class SupplierEntryView {
  const SupplierEntryView({
    required this.id,
    required this.companyId,
    required this.name,
    required this.legalName,
    required this.bin,
    required this.category,
    required this.contact,
    required this.phone,
    required this.email,
    required this.city,
    required this.note,
    required this.status,
    required this.rating,
    required this.turnover,
    required this.orders,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String legalName;
  final String bin;
  final String category;
  final String contact;
  final String phone;
  final String email;
  final String city;
  final String note;
  final String status;
  final double rating;
  final double turnover;
  final int orders;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'Активный';

  factory SupplierEntryView.fromMap(Map<String, dynamic> data) {
    return SupplierEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      name: _string(data['name']),
      legalName: _string(data['legal_name']),
      bin: _string(data['bin']),
      category: _string(data['category']),
      contact: _string(data['contact']),
      phone: _string(data['phone']),
      email: _string(data['email']),
      city: _string(data['city']),
      note: _string(data['note']),
      status: _string(data['status']).isEmpty
          ? 'Активный'
          : _string(data['status']),
      rating: _num(data['rating']),
      turnover: _num(data['turnover']),
      orders: _num(data['orders']).round(),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }
}

class ClientEntryView {
  const ClientEntryView({
    required this.id,
    required this.companyId,
    required this.name,
    required this.clientType,
    required this.creditLimit,
  });

  final String id;
  final String companyId;
  final String name;
  final String clientType;
  final double creditLimit;

  String get displayType {
    switch (clientType.toLowerCase()) {
      case 'legal':
        return 'Юр.лицо';
      default:
        return 'Физ.лицо';
    }
  }

  String get displayLabel {
    final title = name.isEmpty ? 'Без имени' : name;
    return '$title • $displayType';
  }

  factory ClientEntryView.fromMap(Map<String, dynamic> data) {
    return ClientEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      name: _string(data['name']),
      clientType: _string(data['client_type']),
      creditLimit: _num(
        data['credit_limit'] ?? data['creditLimit'],
      ),
    );
  }
}

class CashierEntryView {
  const CashierEntryView({
    required this.id,
    required this.companyId,
    required this.name,
    required this.shopId,
    required this.shopName,
    required this.phone,
    required this.position,
    required this.salary,
    required this.commissionPercent,
    required this.status,
    required this.canDiscount,
    required this.canReturn,
    required this.canOpenDrawer,
    required this.maxDiscount,
    required this.hasPin,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String shopId;
  final String shopName;
  final String phone;
  final String position;
  final double salary;
  final double commissionPercent;
  final String status;
  final bool canDiscount;
  final bool canReturn;
  final bool canOpenDrawer;
  final double maxDiscount;
  final bool hasPin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status.toLowerCase() == 'active';

  factory CashierEntryView.fromMap(Map<String, dynamic> data) {
    final permissions = data['permissions'] is Map
        ? Map<String, dynamic>.from(data['permissions'] as Map)
        : const <String, dynamic>{};
    return CashierEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      name: _string(data['name']),
      shopId: _string(data['shop_id']),
      shopName: _string(data['shop_name']),
      phone: _string(data['phone']),
      position: _string(data['position']),
      salary: _num(data['salary']),
      commissionPercent: _num(data['commissionPercent']),
      status:
          _string(data['status']).isEmpty ? 'active' : _string(data['status']),
      canDiscount: permissions['canDiscount'] == true,
      canReturn: permissions['canReturn'] == true,
      canOpenDrawer: permissions['canOpenDrawer'] == true,
      maxDiscount: _num(permissions['maxDiscount']),
      hasPin: _string(data['pin_hash']).isNotEmpty ||
          _string(data['pin']).isNotEmpty,
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }
}

class InventoryEntryView {
  const InventoryEntryView({
    required this.id,
    required this.companyId,
    required this.name,
    required this.article,
    required this.category,
    required this.categoryBeforeDiscount,
    required this.categoryAtDiscount,
    required this.warehouse,
    required this.warehouseType,
    required this.stock,
    required this.revenue,
    required this.profit,
    required this.abc,
    required this.discountPercent,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSaleAt,
    required this.discountStartedAt,
    required this.discountUpdatedAt,
    required this.minStock,
    required this.purchasePrice,
    required this.costPrice,
    required this.salePrice,
    required this.salesCount,
    required this.discountSalesCount,
    required this.discountSalesSum,
  });

  final String id;
  final String companyId;
  final String name;
  final String article;
  final String category;
  final String categoryBeforeDiscount;
  final String categoryAtDiscount;
  final String warehouse;
  final WarehouseType warehouseType;
  final double stock;
  final double revenue;
  final double profit;
  final String abc;
  final double discountPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSaleAt;
  final DateTime? discountStartedAt;
  final DateTime? discountUpdatedAt;
  final double minStock;
  final double purchasePrice;
  final double costPrice;
  final double salePrice;
  final double salesCount;
  final double discountSalesCount;
  final double discountSalesSum;

  bool get isOfficial => warehouseType.isOfficial;

  factory InventoryEntryView.fromMap(Map<String, dynamic> data) {
    return InventoryEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      name: _string(data['name']),
      article: _string(data['article']),
      category: _string(data['category']),
      categoryBeforeDiscount: _string(data['category_before_discount']),
      categoryAtDiscount: _string(data['category_at_discount']),
      warehouse: _string(data['warehouse']),
      warehouseType: warehouseTypeFromData(data),
      stock: _num(data['stock']),
      revenue: _num(data['revenue']),
      profit: _num(data['profit']),
      abc: _string(data['abc']).toUpperCase().isEmpty
          ? 'C'
          : _string(data['abc']).toUpperCase(),
      discountPercent: _num(data['discount_percent']),
      createdAt: _date(data['created_at']) ?? _date(data['date']),
      updatedAt: _date(data['updated_at']),
      lastSaleAt: _date(data['last_sale_at']) ?? _date(data['lastSaleAt']),
      discountStartedAt: _date(data['discount_started_at']),
      discountUpdatedAt: _date(data['discount_updated_at']),
      minStock: _num(data['min_stock']),
      purchasePrice: _num(data['purchase_price']),
      costPrice: _num(data['cost_price']),
      salePrice: _num(data['sale_price']) > 0
          ? _num(data['sale_price'])
          : _num(data['price']),
      salesCount: _num(data['salesCount']),
      discountSalesCount: _num(
          data['sales_with_discount_count'] ?? data['discount_sales_count']),
      discountSalesSum:
          _num(data['sales_with_discount_sum'] ?? data['discount_sales_sum']),
    );
  }
}

class ShopEntryView {
  const ShopEntryView({
    required this.id,
    required this.companyId,
    required this.name,
    required this.address,
    required this.manager,
    required this.phone,
    required this.workingHours,
    required this.warehouseName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String name;
  final String address;
  final String manager;
  final String phone;
  final String workingHours;
  final String warehouseName;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status.toLowerCase() == 'active';

  factory ShopEntryView.fromMap(Map<String, dynamic> data) {
    return ShopEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      name: _string(data['name']),
      address: _string(data['address']),
      manager: _string(data['manager']),
      phone: _string(data['phone']),
      workingHours: _string(data['workingHours']),
      warehouseName: _string(data['warehouseName']),
      status:
          _string(data['status']).isEmpty ? 'active' : _string(data['status']),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }
}

class ShopFinanceLedgerEntryView {
  const ShopFinanceLedgerEntryView({
    required this.key,
    required this.shopId,
    required this.shopName,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.profit,
    required this.cashTurnover,
    required this.endingCash,
    required this.incassations,
    required this.recordedIncassations,
    required this.reconciliationGap,
    required this.salesCount,
    required this.expenseCount,
    required this.registerCount,
    required this.incassationCount,
  });

  final String key;
  final String shopId;
  final String shopName;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double profit;
  final double cashTurnover;
  final double endingCash;
  final double incassations;
  final double recordedIncassations;
  final double reconciliationGap;
  final int salesCount;
  final int expenseCount;
  final int registerCount;
  final int incassationCount;

  factory ShopFinanceLedgerEntryView.fromMap(Map<String, dynamic> data) {
    return ShopFinanceLedgerEntryView(
      key: _string(data['key']),
      shopId: _string(data['shop_id']),
      shopName: _string(data['shop_name']),
      revenue: _num(data['revenue']),
      cogs: _num(data['cogs']),
      grossProfit: _num(data['gross_profit']),
      expenses: _num(data['expenses']),
      profit: _num(data['profit']),
      cashTurnover: _num(data['cash_turnover']),
      endingCash: _num(data['ending_cash']),
      incassations: _num(data['incassations']),
      recordedIncassations: _num(data['recorded_incassations']),
      reconciliationGap: _num(data['reconciliation_gap']),
      salesCount: _num(data['sales_count']).toInt(),
      expenseCount: _num(data['expense_count']).toInt(),
      registerCount: _num(data['register_count']).toInt(),
      incassationCount: _num(data['incassation_count']).toInt(),
    );
  }
}

class CashRegisterShiftEntryView {
  const CashRegisterShiftEntryView({
    required this.id,
    required this.companyId,
    required this.cashRegisterName,
    required this.cashierId,
    required this.cashierName,
    required this.shopId,
    required this.shopName,
    required this.typeUchet,
    required this.ledgerScope,
    required this.status,
    required this.openedByUserId,
    required this.openedAt,
    required this.createdAt,
    required this.cashSales,
    required this.cardSales,
    required this.transactions,
    required this.startingCash,
    required this.endingCash,
    required this.incassationTotal,
  });

  final String id;
  final String companyId;
  final String cashRegisterName;
  final String cashierId;
  final String cashierName;
  final String shopId;
  final String shopName;
  final String typeUchet;
  final LedgerScope ledgerScope;
  final String status;
  final String openedByUserId;
  final DateTime? openedAt;
  final DateTime? createdAt;
  final double cashSales;
  final double cardSales;
  final double transactions;
  final double startingCash;
  final double endingCash;
  final double incassationTotal;

  bool get isOpen => status.toLowerCase() == 'open';
  double get turnover => cashSales + cardSales;
  double get averageCheck => transactions <= 0 ? 0 : turnover / transactions;
  DateTime? get openedAtOrCreatedAt => openedAt ?? createdAt;

  factory CashRegisterShiftEntryView.fromMap(Map<String, dynamic> data) {
    return CashRegisterShiftEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      cashRegisterName: _string(data['cash_register_name']),
      cashierId: _string(data['cashier_id']),
      cashierName: _string(data['cashier_name']),
      shopId: _string(data['shop_id']),
      shopName: _string(data['shop_name']),
      typeUchet: normalizeLegacyTypeUchet(_string(data['typeUchet'])),
      ledgerScope: ledgerScopeFromData(data),
      status:
          _string(data['status']).isEmpty ? 'closed' : _string(data['status']),
      openedByUserId: _string(data['opened_by_user_id']),
      openedAt: _date(data['opened_at']),
      createdAt: _date(data['created_at']),
      cashSales: _num(data['cash_sales']),
      cardSales: _num(data['card_sales']),
      transactions: _num(data['transactions']),
      startingCash: _num(data['starting_cash']),
      endingCash: _num(data['ending_cash']),
      incassationTotal: _num(data['incassation_total']),
    );
  }
}

class CatalogEntryView {
  const CatalogEntryView({
    required this.id,
    required this.companyId,
    required this.name,
    required this.code,
    required this.barcode,
    required this.itemKind,
    required this.stock,
    required this.salePrice,
    required this.basePrice,
    required this.warehouseType,
    required this.ledgerScope,
  });

  final String id;
  final String companyId;
  final String name;
  final String code;
  final String barcode;
  final String itemKind;
  final double stock;
  final double salePrice;
  final double basePrice;
  final WarehouseType warehouseType;
  final LedgerScope ledgerScope;

  bool get isProduct => itemKind == 'product';
  bool get isService => itemKind == 'service';
  bool get isOfficial => warehouseType.isOfficial;
  double get effectivePrice => salePrice > 0 ? salePrice : basePrice;

  factory CatalogEntryView.fromMap(Map<String, dynamic> data) {
    return CatalogEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      name: _string(data['name']),
      code: _string(data['code']),
      barcode: _string(data['barcode']),
      itemKind: _string(data['item_kind']).isEmpty
          ? 'product'
          : _string(data['item_kind']),
      stock: _num(data['stock']),
      salePrice: _num(data['sale_price']),
      basePrice: _num(data['price']),
      warehouseType: warehouseTypeFromData(data),
      ledgerScope: ledgerScopeFromData(data),
    );
  }
}

class CartEntryView {
  const CartEntryView({
    required this.id,
    required this.name,
    required this.itemKind,
    required this.qty,
    required this.stock,
    required this.salePrice,
    required this.basePrice,
    required this.warehouseType,
    required this.ledgerScope,
  });

  final String id;
  final String name;
  final String itemKind;
  final int qty;
  final double stock;
  final double salePrice;
  final double basePrice;
  final WarehouseType warehouseType;
  final LedgerScope ledgerScope;

  bool get isProduct => itemKind == 'product';
  double get effectivePrice => salePrice > 0 ? salePrice : basePrice;
  bool get isOfficial => warehouseType.isOfficial;

  factory CartEntryView.fromMap(Map<String, dynamic> data) {
    return CartEntryView(
      id: _string(data['id']),
      name: _string(data['name']),
      itemKind: _string(data['item_kind']).isEmpty
          ? 'product'
          : _string(data['item_kind']),
      qty: _num(data['qty']).round(),
      stock: _num(data['stock']),
      salePrice: _num(data['sale_price']),
      basePrice: _num(data['price']),
      warehouseType: warehouseTypeFromData(data),
      ledgerScope: ledgerScopeFromData(data),
    );
  }
}

class WarehouseMovementEntryView {
  const WarehouseMovementEntryView({
    required this.id,
    required this.companyId,
    required this.kind,
    required this.createdAt,
    required this.productName,
    required this.productCode,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.qty,
    required this.userName,
    this.reason = '',
    this.photoUrls = const <String>[],
  });

  final String id;
  final String companyId;
  final String kind;
  final DateTime? createdAt;
  final String productName;
  final String productCode;
  final String fromWarehouse;
  final String toWarehouse;
  final double qty;
  final String userName;
  final String reason;
  final List<String> photoUrls;

  String get productTitle {
    return [productName, productCode.isEmpty ? null : '($productCode)']
        .whereType<String>()
        .join(' ');
  }

  factory WarehouseMovementEntryView.fromMap(
    Map<String, dynamic> data, {
    String? kind,
  }) {
    return WarehouseMovementEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      kind: kind ?? _string(data['movement_kind']),
      createdAt: _date(data['created_at']),
      productName: _string(data['product_name']),
      productCode: _string(data['product_code']),
      fromWarehouse: _string(data['from_warehouse']),
      toWarehouse: _string(data['to_warehouse']),
      qty: _num(data['qty']),
      userName: _string(data['user_name']).isEmpty
          ? _string(data['user_id'])
          : _string(data['user_name']),
      reason: _string(data['reason']),
      photoUrls: (data['photo_urls'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}

class InvestmentEntryView {
  const InvestmentEntryView({
    required this.id,
    required this.companyId,
    required this.amount,
    required this.returnAmount,
    required this.createdAt,
    required this.period,
    required this.name,
  });

  final String id;
  final String companyId;
  final double amount;
  final double returnAmount;
  final DateTime? createdAt;
  final String period;
  final String name;

  factory InvestmentEntryView.fromMap(Map<String, dynamic> data) {
    return InvestmentEntryView(
      id: _string(data['id']),
      companyId: _string(data['idCompany']),
      amount: _num(data['amount']),
      returnAmount: _num(data['return_amount']),
      createdAt: _date(data['date']) ??
          _date(data['created_at']) ??
          _date(data['updated_at']),
      period: _string(data['period']),
      name: _string(data['name']),
    );
  }
}

class MarginMonthEntryView {
  const MarginMonthEntryView({
    required this.monthKey,
    required this.date,
    required this.revenue,
    required this.cost,
  });

  final String monthKey;
  final DateTime? date;
  final double revenue;
  final double cost;

  factory MarginMonthEntryView.fromMap(Map<String, dynamic> data) {
    return MarginMonthEntryView(
      monthKey: _string(data['monthKey']),
      date: _date(data['date']),
      revenue: _num(data['revenue']),
      cost: _num(data['cost']),
    );
  }
}
