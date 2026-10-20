import '/admin/component/drawers/drawers_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/admin_company_support.dart';
import '/utils/permission_tree_selector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SuperAdminWidget extends StatefulWidget {
  const SuperAdminWidget({super.key});

  static const String routeName = 'superAdmin';
  static const String routePath = '/superAdmin';

  @override
  State<SuperAdminWidget> createState() => _SuperAdminWidgetState();
}

class _SuperAdminWidgetState extends State<SuperAdminWidget>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final TabController _tabController;
  late Future<List<_CompanyOption>> _companyOptionsFuture;
  static const String _allCompaniesValue = '__all__';
  String _selectedCompanyId = _allCompaniesValue;
  String _companySearch = '';
  bool _syncedInitialCompany = false;

  ThemeData _adminTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B1120),
      canvasColor: const Color(0xFF111827),
      cardColor: const Color(0xFF111827),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF111827)),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFC9A15B),
        secondary: Color(0xFF60A5FA),
        surface: Color(0xFF111827),
        error: Color(0xFFEF4444),
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xFFF8FAFC),
            displayColor: const Color(0xFFF8FAFC),
          ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF0F172A),
        labelStyle: TextStyle(color: Color(0xFFCBD5E1)),
        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFC9A15B)),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: Color(0xFFE5E7EB)),
        headingRowColor: WidgetStatePropertyAll<Color>(Color(0xFF0F172A)),
        dataRowColor: WidgetStatePropertyAll<Color>(Color(0xFF111827)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFE5E7EB)),
      dividerColor: const Color(0xFF334155),
    );
  }

  final List<_CollectionDef> _defs = const [
    _CollectionDef(
      id: 'companies',
      title: 'Компании',
      collection: 'companies',
      companyScoped: false,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('bin', 'БИН/ИНН'),
        _FieldDef('address', 'Адрес'),
        _FieldDef('oced', 'ОКЭД', type: _FieldType.list),
        _FieldDef('otrasl', 'Отрасль'),
        _FieldDef('forma', 'Форма собственности'),
        _FieldDef('nalog', 'Налоговый режим'),
        _FieldDef('valuta', 'Валюта'),
        _FieldDef('ndsPayer', 'Плательщик НДС', type: _FieldType.bool),
        _FieldDef('buh_enabled', 'Бухгалтерский учет', type: _FieldType.bool),
        _FieldDef('ownerId', 'Владелец UID'),
      ],
    ),
    _CollectionDef(
      id: 'users',
      title: 'Пользователи',
      collection: 'users',
      companyScoped: true,
      fields: [
        _FieldDef('uid', 'UID'),
        _FieldDef('display_name', 'Имя'),
        _FieldDef('phone_number', 'Телефон'),
        _FieldDef('role', 'Роль'),
        _FieldDef('position', 'Должность'),
      ],
    ),
    _CollectionDef(
      id: 'tariffs',
      title: 'Тарифы',
      collection: 'tariffs',
      companyScoped: false,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('price', 'Цена', type: _FieldType.number),
        _FieldDef('period', 'Период'),
        _FieldDef('max_companies', 'Лимит компаний', type: _FieldType.number),
        _FieldDef('permissions', 'Права', type: _FieldType.list),
        _FieldDef('is_active', 'Активен', type: _FieldType.bool),
      ],
    ),
    _CollectionDef(
      id: 'billing_invoices',
      title: 'Счета оплаты',
      collection: 'billing_invoices',
      companyScoped: true,
      fields: [
        _FieldDef('invoice_number', 'Номер'),
        _FieldDef('company_name', 'Компания'),
        _FieldDef('tariff_name', 'Тариф'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('status', 'Статус'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'roles',
      title: 'Роли',
      collection: 'roles',
      companyScoped: true,
      fields: [
        _FieldDef('id', 'ID роли'),
        _FieldDef('name', 'Название'),
        _FieldDef('permissions', 'Права (через запятую/с новой строки)',
            type: _FieldType.list),
        _FieldDef(
          'allowed_company_ids',
          'Доступные компании (ID, список)',
          type: _FieldType.list,
        ),
      ],
    ),
    _CollectionDef(
      id: 'role_templates',
      title: 'Стандартные роли',
      collection: 'role_templates',
      companyScoped: false,
      fields: [
        _FieldDef('id', 'ID шаблона'),
        _FieldDef('name', 'Название'),
        _FieldDef('description', 'Описание'),
        _FieldDef('permissions', 'Права (через запятую/с новой строки)',
            type: _FieldType.list),
      ],
    ),
    _CollectionDef(
      id: 'sheta',
      title: 'Счета',
      collection: 'sheta',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Название'),
        _FieldDef('tip', 'Тип'),
        _FieldDef('summa', 'Баланс', type: _FieldType.number),
        _FieldDef('coment', 'Комментарий'),
      ],
    ),
    _CollectionDef(
      id: 'scheta',
      title: 'Счета legacy',
      collection: 'scheta',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Название'),
        _FieldDef('tip', 'Тип'),
        _FieldDef('summa', 'Баланс', type: _FieldType.number),
        _FieldDef('coment', 'Комментарий'),
      ],
    ),
    _CollectionDef(
      id: 'accounting_entries',
      title: 'Проводки',
      collection: 'accounting_entries',
      companyScoped: true,
      fields: [
        _FieldDef('entry_date', 'Дата'),
        _FieldDef('description', 'Описание'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('debit_account_title', 'Дебет'),
        _FieldDef('credit_account_title', 'Кредит'),
        _FieldDef('source_type', 'Источник'),
        _FieldDef('source_id', 'ID источника'),
      ],
    ),
    _CollectionDef(
      id: 'statRashod',
      title: 'Статьи бюджета',
      collection: 'statRashod',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Название'),
        _FieldDef('type', 'Тип'),
        _FieldDef('parentId', 'Родитель'),
        _FieldDef('periodicity', 'Периодичность'),
        _FieldDef('isGroup', 'Группа', type: _FieldType.bool),
      ],
    ),
    _CollectionDef(
      id: 'expense_plans',
      title: 'Планы бюджета',
      collection: 'expense_plans',
      companyScoped: true,
      fields: [
        _FieldDef('category_name', 'Статья'),
        _FieldDef('period_key', 'Период'),
        _FieldDef('planned_amount', 'План', type: _FieldType.number),
        _FieldDef('ledger_scope', 'Контур'),
        _FieldDef('notes', 'Комментарий'),
      ],
    ),
    _CollectionDef(
      id: 'obyaz',
      title: 'Обязательства',
      collection: 'obyaz',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('counterparty', 'Контрагент'),
        _FieldDef('type', 'Тип'),
        _FieldDef('summa', 'Сумма', type: _FieldType.number),
        _FieldDef('status', 'Статус'),
        _FieldDef('date', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'nomenklatura',
      title: 'Товары',
      collection: 'nomenklatura',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('code', 'Код'),
        _FieldDef('sku', 'Артикул'),
        _FieldDef('warehouse', 'Склад'),
        _FieldDef('stock', 'Остаток', type: _FieldType.number),
        _FieldDef('sale_price', 'Цена продажи', type: _FieldType.number),
      ],
    ),
    _CollectionDef(
      id: 'items',
      title: 'Позиции номенклатуры',
      collection: 'items',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('type', 'Тип'),
        _FieldDef('sku', 'Артикул'),
        _FieldDef('price', 'Цена', type: _FieldType.number),
        _FieldDef('cost', 'Себестоимость', type: _FieldType.number),
        _FieldDef('isActive', 'Активна', type: _FieldType.bool),
      ],
    ),
    _CollectionDef(
      id: 'services',
      title: 'Услуги',
      collection: 'services',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('category', 'Категория'),
        _FieldDef('price', 'Цена', type: _FieldType.number),
        _FieldDef('cost', 'Себестоимость', type: _FieldType.number),
        _FieldDef('isActive', 'Активна', type: _FieldType.bool),
      ],
    ),
    _CollectionDef(
      id: 'tranzaction',
      title: 'Транзакции',
      collection: 'tranzaction',
      companyScoped: true,
      fields: [
        _FieldDef('type', 'Тип'),
        _FieldDef('typeUchet', 'Учет'),
        _FieldDef('kat', 'Категория'),
        _FieldDef('text', 'Описание'),
        _FieldDef('summa', 'Сумма', type: _FieldType.number),
        _FieldDef('schetTitle', 'Счет'),
      ],
    ),
    _CollectionDef(
      id: 'sales',
      title: 'Продажи',
      collection: 'sales',
      companyScoped: true,
      fields: [
        _FieldDef('date', 'Дата'),
        _FieldDef('total', 'Итого', type: _FieldType.number),
        _FieldDef('payment_method', 'Оплата'),
        _FieldDef('cashier_name', 'Кассир'),
        _FieldDef('shop_name', 'Точка'),
        _FieldDef('status', 'Статус'),
      ],
    ),
    _CollectionDef(
      id: 'sales_items',
      title: 'Позиции продаж',
      collection: 'sales_items',
      companyScoped: true,
      fields: [
        _FieldDef('sale_id', 'ID продажи'),
        _FieldDef('product_name', 'Товар/услуга'),
        _FieldDef('quantity', 'Количество', type: _FieldType.number),
        _FieldDef('price', 'Цена', type: _FieldType.number),
        _FieldDef('cost', 'Себестоимость', type: _FieldType.number),
      ],
    ),
    _CollectionDef(
      id: 'warehouses',
      title: 'Склады',
      collection: 'warehouses',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('parentWarehouse', 'Группа'),
        _FieldDef('type', 'Тип'),
        _FieldDef('isVirtual', 'Виртуальный', type: _FieldType.bool),
      ],
    ),
    _CollectionDef(
      id: 'cash_registers',
      title: 'Кассы',
      collection: 'cash_registers',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('status', 'Статус'),
        _FieldDef('cashier_name', 'Кассир'),
        _FieldDef('opening_balance', 'Начальный остаток',
            type: _FieldType.number),
        _FieldDef('current_balance', 'Текущий остаток',
            type: _FieldType.number),
      ],
    ),
    _CollectionDef(
      id: 'employees',
      title: 'Сотрудники',
      collection: 'employees',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'ФИО'),
        _FieldDef('phone', 'Телефон'),
        _FieldDef('role', 'Роль'),
        _FieldDef('position', 'Должность'),
        _FieldDef('department', 'Отдел'),
        _FieldDef('isActive', 'Активен', type: _FieldType.bool),
      ],
    ),
    _CollectionDef(
      id: 'clients',
      title: 'Клиенты',
      collection: 'clients',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('phone', 'Телефон'),
        _FieldDef('email', 'Email'),
        _FieldDef('type', 'Тип'),
        _FieldDef('comment', 'Комментарий'),
      ],
    ),
    _CollectionDef(
      id: 'suppliers',
      title: 'Поставщики',
      collection: 'suppliers',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('bin', 'БИН/ИНН'),
        _FieldDef('phone', 'Телефон'),
        _FieldDef('email', 'Email'),
        _FieldDef('comment', 'Комментарий'),
      ],
    ),
    _CollectionDef(
      id: 'investments',
      title: 'Инвестиции',
      collection: 'investments',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Название'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('status', 'Статус'),
        _FieldDef('date', 'Дата'),
        _FieldDef('comment', 'Комментарий'),
      ],
    ),
    _CollectionDef(
      id: 'marketing_campaigns',
      title: 'Маркетинг',
      collection: 'marketing_campaigns',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('channel', 'Канал'),
        _FieldDef('budget', 'Бюджет', type: _FieldType.number),
        _FieldDef('status', 'Статус'),
        _FieldDef('date', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'support_tickets',
      title: 'Поддержка',
      collection: 'support_tickets',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Тема'),
        _FieldDef('message', 'Сообщение', type: _FieldType.multiline),
        _FieldDef('status', 'Статус'),
        _FieldDef('priority', 'Приоритет'),
        _FieldDef('user_id', 'Пользователь'),
      ],
    ),
    _CollectionDef(
      id: 'admin_notifications',
      title: 'Уведомления админки',
      collection: 'admin_notifications',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Заголовок'),
        _FieldDef('message', 'Сообщение', type: _FieldType.multiline),
        _FieldDef('status', 'Статус'),
        _FieldDef('type', 'Тип'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'fin_models',
      title: 'Финмодели',
      collection: 'fin_models',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('period', 'Период'),
        _FieldDef('status', 'Статус'),
        _FieldDef('comment', 'Комментарий'),
      ],
    ),
    _CollectionDef(
      id: 'company_profile',
      title: 'Профили компаний',
      collection: 'company_profile',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('bin', 'БИН/ИНН'),
        _FieldDef('user_id', 'Владелец'),
        _FieldDef('valuta', 'Валюта'),
        _FieldDef('oced', 'ОКЭД', type: _FieldType.list),
        _FieldDef('updated_at', 'Обновлено'),
      ],
    ),
    _CollectionDef(
      id: 'ushet',
      title: 'Фин. итоги',
      collection: 'ushet',
      companyScoped: true,
      fields: [
        _FieldDef('doxodBu', 'Доход БУ', type: _FieldType.number),
        _FieldDef('rashodBu', 'Расход БУ', type: _FieldType.number),
        _FieldDef('BalanceBu', 'Остаток БУ', type: _FieldType.number),
        _FieldDef('nds', 'НДС', type: _FieldType.number),
        _FieldDef('kpn', 'КПН / налог на доходы', type: _FieldType.number),
      ],
    ),
    _CollectionDef(
      id: 'money_wallets',
      title: 'Денежные кошельки',
      collection: 'money_wallets',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Название'),
        _FieldDef('type', 'Тип'),
        _FieldDef('balance', 'Баланс', type: _FieldType.number),
        _FieldDef('account_id', 'Счет'),
        _FieldDef('updated_at', 'Обновлено'),
      ],
    ),
    _CollectionDef(
      id: 'warehouse_movements',
      title: 'Движения склада',
      collection: 'warehouse_movements',
      companyScoped: true,
      fields: [
        _FieldDef('product_name', 'Товар'),
        _FieldDef('warehouse', 'Склад'),
        _FieldDef('type', 'Тип'),
        _FieldDef('quantity', 'Кол-во', type: _FieldType.number),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'inventory_batches',
      title: 'Партии склада',
      collection: 'inventory_batches',
      companyScoped: true,
      fields: [
        _FieldDef('product_name', 'Товар'),
        _FieldDef('warehouse_name', 'Склад'),
        _FieldDef('quantity_remaining', 'Остаток', type: _FieldType.number),
        _FieldDef('unit_cost', 'Себестоимость', type: _FieldType.number),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'inventory_reservations',
      title: 'Резервы склада',
      collection: 'inventory_reservations',
      companyScoped: true,
      fields: [
        _FieldDef('order_id', 'Заказ'),
        _FieldDef('product_name', 'Товар'),
        _FieldDef('quantity', 'Кол-во', type: _FieldType.number),
        _FieldDef('status', 'Статус'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'batches',
      title: 'Партии',
      collection: 'batches',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('product_id', 'Товар'),
        _FieldDef('quantity', 'Кол-во', type: _FieldType.number),
        _FieldDef('cost', 'Стоимость', type: _FieldType.number),
      ],
    ),
    _CollectionDef(
      id: 'cogs_register',
      title: 'Себестоимость продаж',
      collection: 'cogs_register',
      companyScoped: true,
      fields: [
        _FieldDef('sale_id', 'Продажа'),
        _FieldDef('product_name', 'Товар'),
        _FieldDef('quantity', 'Кол-во', type: _FieldType.number),
        _FieldDef('total_cost', 'Себестоимость', type: _FieldType.number),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'sale_item_cogs',
      title: 'COGS позиций',
      collection: 'sale_item_cogs',
      companyScoped: true,
      fields: [
        _FieldDef('sale_id', 'Продажа'),
        _FieldDef('sale_item_id', 'Позиция'),
        _FieldDef('cost', 'Себестоимость', type: _FieldType.number),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'batch_consumptions',
      title: 'Списания партий',
      collection: 'batch_consumptions',
      companyScoped: true,
      fields: [
        _FieldDef('batch_id', 'Партия'),
        _FieldDef('sale_id', 'Продажа'),
        _FieldDef('quantity', 'Кол-во', type: _FieldType.number),
        _FieldDef('cost', 'Стоимость', type: _FieldType.number),
      ],
    ),
    _CollectionDef(
      id: 'shops',
      title: 'Магазины',
      collection: 'shops',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('address', 'Адрес'),
        _FieldDef('status', 'Статус'),
        _FieldDef('manager_name', 'Директор'),
      ],
    ),
    _CollectionDef(
      id: 'shop_expenses',
      title: 'Расходы магазинов',
      collection: 'shop_expenses',
      companyScoped: true,
      fields: [
        _FieldDef('shop_name', 'Магазин'),
        _FieldDef('category', 'Категория'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('date', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'cashiers',
      title: 'Кассиры',
      collection: 'cashiers',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'ФИО'),
        _FieldDef('phone', 'Телефон'),
        _FieldDef('shop_name', 'Магазин'),
        _FieldDef('status', 'Статус'),
      ],
    ),
    _CollectionDef(
      id: 'cash_register_incassations',
      title: 'Инкассации',
      collection: 'cash_register_incassations',
      companyScoped: true,
      fields: [
        _FieldDef('cash_register_name', 'Касса'),
        _FieldDef('shop_name', 'Магазин'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'staff_schedule',
      title: 'График сотрудников',
      collection: 'staff_schedule',
      companyScoped: true,
      fields: [
        _FieldDef('employee_name', 'Сотрудник'),
        _FieldDef('role_name', 'Роль'),
        _FieldDef('shop_name', 'Магазин'),
        _FieldDef('date', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'customer_orders',
      title: 'Заказы клиентов',
      collection: 'customer_orders',
      companyScoped: true,
      fields: [
        _FieldDef('order_number', 'Номер'),
        _FieldDef('customer_name', 'Клиент'),
        _FieldDef('status', 'Статус'),
        _FieldDef('total_amount', 'Сумма', type: _FieldType.number),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'customer_order_items',
      title: 'Позиции заказов',
      collection: 'customer_order_items',
      companyScoped: true,
      fields: [
        _FieldDef('order_id', 'Заказ'),
        _FieldDef('product_name', 'Товар/услуга'),
        _FieldDef('quantity_ordered', 'Кол-во', type: _FieldType.number),
        _FieldDef('unit_price', 'Цена', type: _FieldType.number),
      ],
    ),
    _CollectionDef(
      id: 'shipments',
      title: 'Отгрузки',
      collection: 'shipments',
      companyScoped: true,
      fields: [
        _FieldDef('order_id', 'Заказ'),
        _FieldDef('status', 'Статус'),
        _FieldDef('warehouse_name', 'Склад'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'order_payments',
      title: 'Оплаты заказов',
      collection: 'order_payments',
      companyScoped: true,
      fields: [
        _FieldDef('order_id', 'Заказ'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('payment_method', 'Оплата'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'debt_register',
      title: 'Долги',
      collection: 'debt_register',
      companyScoped: true,
      fields: [
        _FieldDef('counterparty', 'Контрагент'),
        _FieldDef('type', 'Тип'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('status', 'Статус'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'debt_payment_links',
      title: 'Платежи по долгам',
      collection: 'debt_payment_links',
      companyScoped: true,
      fields: [
        _FieldDef('debt_id', 'Долг'),
        _FieldDef('transaction_id', 'Платеж'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'business_events',
      title: 'Бизнес-события',
      collection: 'business_events',
      companyScoped: true,
      fields: [
        _FieldDef('event_type', 'Тип'),
        _FieldDef('title', 'Название'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('source_type', 'Источник'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'service_categories',
      title: 'Категории услуг',
      collection: 'service_categories',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('description', 'Описание'),
      ],
    ),
    _CollectionDef(
      id: 'service_cost_models',
      title: 'Себестоимость услуг',
      collection: 'service_cost_models',
      companyScoped: true,
      fields: [
        _FieldDef('service_name', 'Услуга'),
        _FieldDef('cost', 'Себестоимость', type: _FieldType.number),
        _FieldDef('updated_at', 'Обновлено'),
      ],
    ),
    _CollectionDef(
      id: 'service_executions',
      title: 'Выполненные услуги',
      collection: 'service_executions',
      companyScoped: true,
      fields: [
        _FieldDef('service_name', 'Услуга'),
        _FieldDef('customer_name', 'Клиент'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('date', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'nomenclature_categories',
      title: 'Категории номенклатуры',
      collection: 'nomenclature_categories',
      companyScoped: true,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('type', 'Тип'),
        _FieldDef('parent_id', 'Родитель'),
      ],
    ),
    _CollectionDef(
      id: 'taxes',
      title: 'Налоги компании',
      collection: 'taxes',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Название'),
        _FieldDef('rate', 'Ставка', type: _FieldType.number),
        _FieldDef('period', 'Период'),
      ],
    ),
    _CollectionDef(
      id: 'company_expenses',
      title: 'Расходы компании',
      collection: 'company_expenses',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Название'),
        _FieldDef('category', 'Категория'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('date', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'balance_manual_values',
      title: 'Ручной баланс',
      collection: 'balance_manual_values',
      companyScoped: true,
      fields: [
        _FieldDef('title', 'Название'),
        _FieldDef('amount', 'Сумма', type: _FieldType.number),
        _FieldDef('period', 'Период'),
      ],
    ),
    _CollectionDef(
      id: 'audit_1c_runs',
      title: 'Запуски аудита 1С',
      collection: 'audit_1c_runs',
      companyScoped: true,
      fields: [
        _FieldDef('status', 'Статус'),
        _FieldDef('started_at', 'Старт'),
        _FieldDef('finished_at', 'Финиш'),
        _FieldDef('message', 'Сообщение', type: _FieldType.multiline),
      ],
    ),
    _CollectionDef(
      id: 'audit_1c_sync_settings',
      title: 'Настройки аудита 1С',
      collection: 'audit_1c_sync_settings',
      companyScoped: true,
      fields: [
        _FieldDef('type', 'Тип'),
        _FieldDef('xml_url', 'URL'),
        _FieldDef('auto_enabled', 'Авто', type: _FieldType.bool),
        _FieldDef('interval_minutes', 'Интервал', type: _FieldType.number),
      ],
    ),
    _CollectionDef(
      id: 'blocked_apps',
      title: 'Блокировки приложений',
      collection: 'blocked_apps',
      companyScoped: true,
      fields: [
        _FieldDef('app_name', 'Приложение'),
        _FieldDef('package_name', 'Пакет'),
        _FieldDef('is_blocked', 'Заблокировано', type: _FieldType.bool),
      ],
    ),
    _CollectionDef(
      id: 'devices',
      title: 'Устройства',
      collection: 'devices',
      companyScoped: true,
      fields: [
        _FieldDef('device_id', 'Устройство'),
        _FieldDef('user_id', 'Пользователь'),
        _FieldDef('status', 'Статус'),
        _FieldDef('last_seen_at', 'Последний вход'),
      ],
    ),
    _CollectionDef(
      id: 'device_commands',
      title: 'Команды устройств',
      collection: 'device_commands',
      companyScoped: true,
      fields: [
        _FieldDef('device_id', 'Устройство'),
        _FieldDef('command_type', 'Команда'),
        _FieldDef('status', 'Статус'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'security_pins',
      title: 'PIN безопасности',
      collection: 'security_pins',
      companyScoped: true,
      fields: [
        _FieldDef('user_id', 'Пользователь'),
        _FieldDef('updated_at', 'Обновлено'),
      ],
    ),
    _CollectionDef(
      id: 'data_restore_requests',
      title: 'Запросы восстановления',
      collection: 'data_restore_requests',
      companyScoped: true,
      fields: [
        _FieldDef('status', 'Статус'),
        _FieldDef('requested_by', 'Кто запросил'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'data_delete_requests',
      title: 'Запросы удаления',
      collection: 'data_delete_requests',
      companyScoped: true,
      fields: [
        _FieldDef('status', 'Статус'),
        _FieldDef('requested_by', 'Кто запросил'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'security_settings',
      title: 'Настройки безопасности',
      collection: 'security_settings',
      companyScoped: false,
      fields: [
        _FieldDef('require_2fa', '2FA', type: _FieldType.bool),
        _FieldDef('session_ttl_days', 'TTL дней', type: _FieldType.number),
        _FieldDef('updated_at', 'Обновлено'),
      ],
    ),
    _CollectionDef(
      id: 'security_logs',
      title: 'Логи безопасности',
      collection: 'security_logs',
      companyScoped: false,
      fields: [
        _FieldDef('event', 'Событие'),
        _FieldDef('user', 'Пользователь'),
        _FieldDef('ip', 'IP'),
        _FieldDef('status', 'Статус'),
        _FieldDef('created_at', 'Дата'),
      ],
    ),
    _CollectionDef(
      id: 'app_settings',
      title: 'Настройки приложения',
      collection: 'app_settings',
      companyScoped: false,
      fields: [
        _FieldDef('key', 'Ключ'),
        _FieldDef('title', 'Название'),
        _FieldDef('value', 'Значение', type: _FieldType.multiline),
        _FieldDef('is_active', 'Активна', type: _FieldType.bool),
      ],
    ),
    _CollectionDef(
      id: 'country',
      title: 'Страны',
      collection: 'country',
      companyScoped: false,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('code', 'Код'),
      ],
    ),
    _CollectionDef(
      id: 'valuta',
      title: 'Валюты',
      collection: 'valuta',
      companyScoped: false,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('code', 'Код'),
        _FieldDef('symbol', 'Символ'),
      ],
    ),
    _CollectionDef(
      id: 'currencies',
      title: 'Валюты компаний',
      collection: 'currencies',
      companyScoped: true,
      fields: [
        _FieldDef('code', 'Код'),
        _FieldDef('name', 'Название'),
        _FieldDef('symbol', 'Символ'),
        _FieldDef('created_at', 'Создано'),
        _FieldDef('updated_at', 'Обновлено'),
      ],
    ),
    _CollectionDef(
      id: 'oced',
      title: 'ОКЭД',
      collection: 'oced',
      companyScoped: false,
      fields: [
        _FieldDef('code', 'Код'),
        _FieldDef('name', 'Название'),
        _FieldDef('description', 'Описание'),
      ],
    ),
    _CollectionDef(
      id: 'otrasli',
      title: 'Отрасли',
      collection: 'otrasli',
      companyScoped: false,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('description', 'Описание'),
      ],
    ),
    _CollectionDef(
      id: 'forma',
      title: 'Формы собственности',
      collection: 'forma',
      companyScoped: false,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('code', 'Код'),
      ],
    ),
    _CollectionDef(
      id: 'nalogi',
      title: 'Налоги',
      collection: 'nalogi',
      companyScoped: false,
      fields: [
        _FieldDef('name', 'Название'),
        _FieldDef('rate', 'Ставка', type: _FieldType.number),
        _FieldDef('description', 'Описание'),
      ],
    ),
    _CollectionDef(
      id: 'activity_log',
      title: 'Логи действий',
      collection: 'activity_log',
      companyScoped: true,
      fields: [
        _FieldDef('created_at', 'Дата'),
        _FieldDef('user_name', 'Пользователь'),
        _FieldDef('user_id', 'UID'),
        _FieldDef('user_phone', 'Телефон'),
        _FieldDef('action', 'Действие'),
        _FieldDef('entity', 'Объект'),
        _FieldDef('entity_id', 'ID объекта'),
        _FieldDef('entity_title', 'Название'),
        _FieldDef('source', 'Источник'),
        _FieldDef('diff', 'Изменения', type: _FieldType.multiline),
        _FieldDef('before', 'До', type: _FieldType.multiline),
        _FieldDef('after', 'После', type: _FieldType.multiline),
        _FieldDef('details', 'Детали', type: _FieldType.multiline),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _defs.length, vsync: this);
    _companyOptionsFuture = _loadCompanyOptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _requestedTabId =>
      (GoRouterState.of(context).uri.queryParameters['tab'] ?? '').trim();

  bool get _isRoleTemplatesFocused => _requestedTabId == 'role_templates';

  _CollectionDef get _roleTemplatesDef =>
      _defs.firstWhere((def) => def.id == 'role_templates');

  void _syncTabFromQuery() {
    final tabId = _requestedTabId;
    if (tabId.isEmpty) return;
    final index = _defs.indexWhere((def) => def.id == tabId.trim());
    if (index < 0 || _tabController.index == index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabController.index == index) return;
      _tabController.animateTo(index);
    });
  }

  bool get _isSuperAdmin {
    final role = (currentUserDocument?.role ?? '').toString().toLowerCase();
    final isAdminFlag = currentUserDocument?.snapshotData['is_admin'] == true;
    return isAdminFlag ||
        role == 'admin' ||
        role == 'super_admin' ||
        role == 'superadmin' ||
        role == 'owner';
  }

  String get _selectedRealCompanyId {
    final cid = _selectedCompanyId.trim();
    return cid == _allCompaniesValue ? '' : cid;
  }

  bool _isValidCompanyId(String value) {
    return isValidAdminCompanyId(value, allCompaniesValue: _allCompaniesValue);
  }

  String _companyIdFromData(
    String docId,
    Map<String, dynamic> data, {
    bool allowProfileDocId = false,
  }) {
    return companyAdminIdFromData(
      docId,
      data,
      allCompaniesValue: _allCompaniesValue,
      allowDocId: allowProfileDocId,
    );
  }

  Set<String> _companyIdsFromData(String docId, Map<String, dynamic> data) {
    final ids = <String>{};
    final single = _companyIdFromData(docId, data);
    if (_isValidCompanyId(single)) ids.add(single);
    for (final key in const [
      'companyIds',
      'company_ids',
      'allowed_company_ids',
      'companies',
    ]) {
      final value = data[key];
      if (value is Iterable) {
        for (final item in value) {
          final id = item.toString().trim();
          if (_isValidCompanyId(id)) ids.add(id);
        }
      } else {
        final raw = value?.toString().trim() ?? '';
        if (raw.isEmpty) continue;
        for (final part in raw.split(RegExp(r'[\n,;]'))) {
          final id = part.trim();
          if (_isValidCompanyId(id)) ids.add(id);
        }
      }
    }
    final active = data['activeCompanyId']?.toString().trim() ?? '';
    if (_isValidCompanyId(active)) ids.add(active);
    return ids;
  }

  bool _documentBelongsToSelectedCompany(
    _CollectionDef def,
    String docId,
    Map<String, dynamic> data,
  ) {
    if (!def.companyScoped || _selectedRealCompanyId.isEmpty) return true;
    return _companyIdsFromData(docId, data).contains(_selectedRealCompanyId);
  }

  String _companyDisplayName(Map<String, dynamic> data, String id) {
    return companyAdminDisplayName(data);
  }

  String _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _companySignature(Map<String, dynamic> data) {
    final name = companyAdminDisplayName(data).toLowerCase();
    final bin = _firstText(data, ['bin', 'BIN', 'iin']).toLowerCase();
    final owner = _firstText(data, ['ownerId', 'user_id']).toLowerCase();
    return '$name|$bin|$owner';
  }

  List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return const [];
    return raw
        .split(RegExp(r'[\n,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<List<_CompanyOption>> _loadCompanyOptions() async {
    final byId = <String, _CompanyOption>{};

    final companiesSnap = await _firestore.collection('companies').get();
    for (final doc in companiesSnap.docs) {
      final data = doc.data();
      if (!_isValidCompanyId(doc.id)) continue;
      byId[doc.id] = _CompanyOption(
        id: doc.id,
        name: _companyDisplayName(data, doc.id),
      );
    }

    final profilesSnap = await _firestore.collection('company_profile').get();
    for (final doc in profilesSnap.docs) {
      final data = doc.data();
      final id = _companyIdFromData(doc.id, data, allowProfileDocId: true);
      if (!_isValidCompanyId(id)) {
        continue;
      }
      final name = _companyDisplayName(data, id);
      byId[id] = _CompanyOption(id: id, name: name);
    }

    final usersSnap = await _firestore.collection('users').get();
    for (final doc in usersSnap.docs) {
      final data = doc.data();
      for (final id in _companyIdsFromData(doc.id, data)) {
        final userCompanyName =
            _firstText(data, ['company_name', 'nameCompany']);
        byId.putIfAbsent(
          id,
          () => _CompanyOption(
            id: id,
            name: userCompanyName.isEmpty ? 'Компания $id' : userCompanyName,
          ),
        );
      }
    }

    final items = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  void _reloadCompanyOptions() {
    setState(() {
      _companyOptionsFuture = _loadCompanyOptions();
    });
  }

  Query<Map<String, dynamic>> _queryFor(_CollectionDef def) {
    Query<Map<String, dynamic>> query = _firestore.collection(def.collection);
    if (def.companyScoped) {
      if (def.collection == 'activity_log') {
        return query.orderBy('created_at', descending: true).limit(500);
      }
      return query.limit(500);
    }
    if (def.collection == 'activity_log') {
      return query.orderBy('created_at', descending: true).limit(500);
    }
    return query.limit(200);
  }

  void _openCompanyLogs(String companyId) {
    final index = _defs.indexWhere((def) => def.id == 'activity_log');
    if (index < 0) return;
    setState(() {
      _selectedCompanyId = companyId.trim();
    });
    _setGlobalActiveCompany(companyId);
    _tabController.animateTo(index);
  }

  List<_AdminRow> _buildMergedCompanyRows({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> companies,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> profiles,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    final profileById = <String, Map<String, dynamic>>{};
    final skippedProfiles = <Map<String, dynamic>>[];

    for (final doc in profiles) {
      final data = doc.data();
      final id = _companyIdFromData(doc.id, data, allowProfileDocId: true);
      if (!_isValidCompanyId(id)) {
        skippedProfiles.add({...data, 'profileDocId': doc.id});
        continue;
      }
      profileById[id] = {...data, 'idCompany': id};
    }

    for (final doc in companies) {
      if (!_isValidCompanyId(doc.id)) continue;
      final data = {
        ...?profileById[doc.id],
        ...doc.data(),
      };
      byId[doc.id] = _normalizeCompanyRow(doc.id, data);
    }

    for (final profile in skippedProfiles) {
      final profileSignature = _companySignature(profile);
      if (profileSignature == '||') continue;
      for (final entry in byId.entries.toList()) {
        if (_companySignature(entry.value) != profileSignature) continue;
        byId[entry.key] = _normalizeCompanyRow(
          entry.key,
          {
            ...profile,
            ...entry.value,
          },
        );
        break;
      }
    }

    for (final entry in profileById.entries) {
      if (byId.containsKey(entry.key)) continue;
      final profileSignature = _companySignature(entry.value);
      final duplicateRealCompany = byId.values.any(
        (data) => _companySignature(data) == profileSignature,
      );
      if (duplicateRealCompany) continue;
      byId[entry.key] = _normalizeCompanyRow(entry.key, entry.value);
    }

    for (final doc in users) {
      final data = doc.data();
      for (final id in _companyIdsFromData(doc.id, data)) {
        if (byId.containsKey(id)) {
          final existing = byId[id]!;
          byId[id] = {
            ...existing,
            'ownerId': _firstText(existing, ['ownerId', 'user_id']).isNotEmpty
                ? existing['ownerId']
                : doc.id,
          };
          continue;
        }
        final userCompanyName =
            _firstText(data, ['company_name', 'nameCompany']);
        byId[id] = _normalizeCompanyRow(id, {
          'idCompany': id,
          'name': userCompanyName.isEmpty ? 'Компания $id' : userCompanyName,
          'ownerId': doc.id,
          'source': 'users',
        });
      }
    }

    final q = _companySearch.trim().toLowerCase();
    final rows = byId.entries
        .map((entry) => _AdminRow(id: entry.key, data: entry.value))
        .where((row) {
      if (q.isEmpty) return true;
      return [
        row.id,
        row.data['name'],
        row.data['bin'],
        row.data['oced'],
        row.data['otrasl'],
        row.data['forma'],
        row.data['nalog'],
        row.data['valuta'],
        row.data['ownerId'],
      ].any((value) => _fmt(value).toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) {
        final aName = (a.data['name'] ?? '').toString().toLowerCase();
        final bName = (b.data['name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });
    return rows;
  }

  Map<String, dynamic> _normalizeCompanyRow(
    String id,
    Map<String, dynamic> data,
  ) {
    return {
      ...data,
      'id': id,
      'name': companyAdminDisplayName(data),
      'bin': _firstText(data, ['bin', 'BIN', 'iin']),
      'address': _firstText(data, ['address', 'adres']),
      'oced': _stringList(data['oced'] ?? data['oked'] ?? data['OKED']),
      'otrasl': _firstText(data, ['otrasl', 'business_type']),
      'forma': _firstText(data, ['forma', 'legal_form']),
      'nalog': _firstText(data, ['nalog', 'tax_regime']),
      'valuta': _firstText(data, ['valuta', 'currency']),
      'ownerId': _firstText(data, ['ownerId', 'user_id']),
      'ndsPayer': data['ndsPayer'] == true || data['nds_payer'] == true,
      'buh_enabled': data['buh_enabled'] == true ||
          data['buhEnabled'] == true ||
          data['buh'] == true,
    };
  }

  Future<Map<String, dynamic>> _fullCompanyData(
    String id,
    Map<String, dynamic> fallback,
  ) async {
    final companySnap = await _firestore.collection('companies').doc(id).get();
    final profileSnap =
        await _firestore.collection('company_profile').doc(id).get();
    return {
      ...fallback,
      if (profileSnap.exists) ...(profileSnap.data() ?? {}),
      if (companySnap.exists) ...(companySnap.data() ?? {}),
      'id': id,
    };
  }

  Future<void> _showRawCompanyDetails(
    String id,
    Map<String, dynamic> fallback,
  ) async {
    final data = await _fullCompanyData(id, fallback);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Все поля компании: ${_companyDisplayName(data, id)}'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: SelectableText(
              data.entries
                  .map((entry) => '${entry.key}: ${_fmt(entry.value)}')
                  .join('\n'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  String _activeCompanyFromUser() {
    final active = (currentUserDocument?.snapshotData['activeCompanyId'] ?? '')
        .toString()
        .trim();
    if (active.isNotEmpty) return active;
    return (currentUserDocument?.idCompany ?? '').toString().trim();
  }

  Future<void> _setGlobalActiveCompany(String companyId) async {
    final cid = companyId.trim();
    if (cid.isEmpty || currentUserReference == null) return;
    await currentUserReference!.update({
      'activeCompanyId': cid,
      'idCompany': cid,
      'companyIds': FieldValue.arrayUnion([cid]),
    });
  }

  void _applyCompanyFieldAliases(Map<String, dynamic> payload) {
    final name = _firstText(payload, ['name', 'nameCompany', 'name_Company']);
    if (name.isNotEmpty) {
      payload['name'] = name;
      payload['nameCompany'] = name;
      payload['name_Company'] = name;
      payload['company_name'] = name;
    }

    final bin = _firstText(payload, ['bin', 'BIN', 'iin']);
    if (bin.isNotEmpty) {
      payload['bin'] = bin;
      payload['BIN'] = bin;
    }

    final address = _firstText(payload, ['address', 'adres']);
    if (address.isNotEmpty) {
      payload['address'] = address;
      payload['adres'] = address;
    }

    final oced = payload['oced'] ?? payload['oked'] ?? payload['OKED'];
    if (oced != null) {
      final normalized = _stringList(oced);
      payload['oced'] = normalized;
      payload['oked'] = normalized;
      payload['OKED'] = normalized;
    }

    final otrasl = _firstText(payload, ['otrasl', 'business_type']);
    if (otrasl.isNotEmpty) {
      payload['otrasl'] = otrasl;
      payload['business_type'] = otrasl;
    }

    final forma = _firstText(payload, ['forma', 'legal_form']);
    if (forma.isNotEmpty) {
      payload['forma'] = forma;
      payload['legal_form'] = forma;
    }

    final nalog = _firstText(payload, ['nalog', 'tax_regime']);
    if (nalog.isNotEmpty) {
      payload['nalog'] = nalog;
      payload['tax_regime'] = nalog;
    }

    final valuta = _firstText(payload, ['valuta', 'currency']);
    if (valuta.isNotEmpty) {
      payload['valuta'] = valuta;
      payload['currency'] = valuta;
    }
  }

  Future<void> _deleteDoc(_CollectionDef def, String id) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить запись?'),
            content: Text('Коллекция: ${def.collection}\nID: $id'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await _firestore.collection(def.collection).doc(id).delete();
    if (def.collection == 'companies') {
      await _firestore.collection('company_profile').doc(id).delete();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Запись удалена')),
    );
  }

  Future<void> _openEditDialog(
    _CollectionDef def, {
    Map<String, dynamic>? existing,
    String? id,
  }) async {
    final isCreate = existing == null;
    if (def.collection == 'companies' && existing != null && id != null) {
      existing = await _fullCompanyData(id, existing);
      if (!mounted) return;
    }
    if (def.collection == 'roles') {
      if (isCreate && _selectedRealCompanyId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Для создания роли выберите конкретную компанию.'),
          ),
        );
        return;
      }
      await _openRoleDialog(
        existing: existing,
        id: id,
        collection: 'roles',
        companyScoped: true,
      );
      return;
    }
    if (def.collection == 'role_templates') {
      await _openRoleDialog(
        existing: existing,
        id: id,
        collection: 'role_templates',
        companyScoped: false,
      );
      return;
    }
    if (def.companyScoped && isCreate && _selectedRealCompanyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Для создания записи выберите конкретную компанию, не "Все".'),
        ),
      );
      return;
    }
    final controllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};
    for (final f in def.fields) {
      final raw = existing?[f.key];
      if (f.type == _FieldType.bool) {
        boolValues[f.key] = raw == true;
      } else {
        final text = raw is List
            ? raw.map((e) => e.toString()).join('\n')
            : (raw == null ? '' : raw.toString());
        controllers[f.key] = TextEditingController(text: text);
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title:
              Text('${isCreate ? 'Добавить' : 'Редактировать'}: ${def.title}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: def.fields.map((f) {
                  if (f.type == _FieldType.bool) {
                    return StatefulBuilder(
                      builder: (context, setInnerState) => SwitchListTile(
                        title: Text(f.label),
                        value: boolValues[f.key] ?? false,
                        onChanged: (v) => setInnerState(() {
                          boolValues[f.key] = v;
                        }),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[f.key],
                      keyboardType: f.type == _FieldType.number
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      maxLines: (f.type == _FieldType.multiline ||
                              f.type == _FieldType.list)
                          ? 3
                          : 1,
                      decoration: InputDecoration(
                        labelText: f.label,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isCreate ? 'Создать' : 'Сохранить'),
            ),
          ],
        );
      },
    );

    for (final c in controllers.values) {
      c.dispose();
    }
    if (saved != true) return;

    final payload = <String, dynamic>{};
    for (final f in def.fields) {
      if (f.type == _FieldType.bool) {
        payload[f.key] = boolValues[f.key] ?? false;
      } else {
        final raw = (controllers[f.key]?.text ?? '').trim();
        if (raw.isEmpty) continue;
        if (f.type == _FieldType.number) {
          payload[f.key] = double.tryParse(raw.replaceAll(',', '.')) ?? 0.0;
        } else if (f.type == _FieldType.list) {
          payload[f.key] = raw
              .split(RegExp(r'[\n,;]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } else {
          payload[f.key] = raw;
        }
      }
    }
    if (def.companyScoped && _selectedRealCompanyId.isNotEmpty) {
      payload['idCompany'] = _selectedRealCompanyId;
    }
    if (def.collection == 'roles' && _selectedRealCompanyId.isNotEmpty) {
      payload['allowed_company_ids'] = [_selectedRealCompanyId];
    }
    payload['updated_at'] = FieldValue.serverTimestamp();
    if (isCreate) {
      payload['created_at'] = FieldValue.serverTimestamp();
    }
    if (def.collection == 'companies') {
      _applyCompanyFieldAliases(payload);
    }

    final col = _firestore.collection(def.collection);
    if (isCreate) {
      if (def.collection == 'users') {
        final uid = (payload['uid'] ?? '').toString().trim();
        if (uid.isNotEmpty) {
          await col.doc(uid).set(payload, SetOptions(merge: true));
        } else {
          await col.add(payload);
        }
      } else if (def.collection == 'companies') {
        final doc = col.doc();
        payload['id'] = doc.id;
        await doc.set(payload, SetOptions(merge: true));
      } else {
        await col.add(payload);
      }
    } else if (id != null) {
      await col.doc(id).set(payload, SetOptions(merge: true));
    }

    if (def.collection == 'companies') {
      final companyId = isCreate ? (payload['id'] ?? '').toString().trim() : id;
      final targetId = (companyId ?? '').trim();
      if (targetId.isNotEmpty) {
        await _firestore.collection('company_profile').doc(targetId).set({
          'idCompany': targetId,
          ...payload,
        }, SetOptions(merge: true));
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isCreate ? 'Запись создана' : 'Запись обновлена')),
    );
  }

  Future<void> _openRoleDialog({
    Map<String, dynamic>? existing,
    String? id,
    required String collection,
    required bool companyScoped,
  }) async {
    final isCreate = existing == null;
    final initialPermissions = ((existing?['permissions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();

    final result = await showDialog<_RoleDialogResult>(
      context: context,
      builder: (context) => _RolePermissionsDialog(
        initialRoleId: (existing?['id'] ?? '').toString(),
        initialName: (existing?['name'] ?? '').toString(),
        initialDescription: (existing?['description'] ?? '').toString(),
        initialPermissions: initialPermissions,
      ),
    );
    if (result == null) return;

    final cid = _selectedRealCompanyId;
    final payload = <String, dynamic>{
      'type': collection == 'role_templates' ? 'default_role' : 'role',
      'id': result.roleId.trim(),
      'name': result.name.trim(),
      'description': result.description,
      'permissions': result.permissions.toList(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (companyScoped && cid.isNotEmpty) {
      payload['idCompany'] = cid;
      payload['allowed_company_ids'] = [cid];
    }
    if (isCreate) {
      payload['created_at'] = FieldValue.serverTimestamp();
    }

    final col = _firestore.collection(collection);
    if (isCreate) {
      final roleDocId = result.roleId.trim();
      if (roleDocId.isNotEmpty) {
        await col.doc(roleDocId).set(payload, SetOptions(merge: true));
      } else {
        await col.add(payload);
      }
    } else if (id != null) {
      await col.doc(id).set(payload, SetOptions(merge: true));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCreate ? 'Запись ролей сохранена' : 'Запись ролей обновлена',
        ),
      ),
    );
  }

  String _fmt(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) {
      return dateTimeFormat('dd.MM.yyyy HH:mm', value.toDate());
    }
    if (value is num) {
      return formatNumber(
        value,
        formatType: FormatType.custom,
        format: '#,##0.##',
        locale: 'ru_RU',
      ).replaceAll('\u00A0', ' ');
    }
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    if (value is Map) {
      if (value.isEmpty) return '-';
      return value.entries
          .map((entry) => '${entry.key}: ${_fmt(entry.value)}')
          .join('\n');
    }
    if (value is DocumentReference) return value.path;
    return value.toString();
  }

  Widget _buildTab(_CollectionDef def) {
    if (def.collection == 'companies') {
      return _buildCompaniesTab(def);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final headingColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final bodyColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    return Column(
      children: [
        if (def.collection == 'role_templates' && !_isRoleTemplatesFocused)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Text(
              'Здесь настраиваются стандартные роли пользователей. Эти шаблоны автоматически применяются для следующих зарегистрированных компаний при создании набора ролей по умолчанию.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Text(def.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openEditDialog(def),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _queryFor(def).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Ошибка загрузки раздела',
                    style: TextStyle(color: bodyColor),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs
                  .where((d) =>
                      _documentBelongsToSelectedCompany(def, d.id, d.data()))
                  .toList();
              if (docs.isEmpty) {
                return Center(
                  child: Text('Нет данных', style: TextStyle(color: bodyColor)),
                );
              }
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dataTableTheme: DataTableThemeData(
                      headingTextStyle: TextStyle(
                        color: headingColor,
                        fontWeight: FontWeight.w700,
                      ),
                      dataTextStyle: TextStyle(color: bodyColor),
                      headingRowColor: WidgetStatePropertyAll<Color>(surface),
                      dataRowColor: WidgetStatePropertyAll<Color>(surface),
                    ),
                    iconTheme: IconThemeData(color: bodyColor),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('ID')),
                            ...def.fields
                                .map((f) => DataColumn(label: Text(f.label))),
                            const DataColumn(label: Text('Действия')),
                          ],
                          rows: docs.map((d) {
                            final m = d.data();
                            return DataRow(
                              cells: [
                                DataCell(
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      d.id,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: bodyColor),
                                    ),
                                  ),
                                ),
                                ...def.fields.map((f) => DataCell(
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 220),
                                        child: Text(
                                          _fmt(m[f.key]),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: bodyColor),
                                        ),
                                      ),
                                    )),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Редактировать',
                                        onPressed: () => _openEditDialog(def,
                                            existing: m, id: d.id),
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: bodyColor,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Удалить',
                                        onPressed: () => _deleteDoc(def, d.id),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompaniesTab(_CollectionDef def) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final headingColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final bodyColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Text(
                def.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: (value) => setState(() => _companySearch = value),
                  style: TextStyle(color: bodyColor),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: bodyColor),
                    hintText: 'Поиск: название, БИН/ИНН, ОКЭД, ID',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: border),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openEditDialog(def),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('companies').snapshots(),
            builder: (context, companiesSnapshot) {
              if (companiesSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Ошибка загрузки companies: ${companiesSnapshot.error}',
                    style: TextStyle(color: bodyColor),
                  ),
                );
              }
              if (!companiesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore.collection('company_profile').snapshots(),
                builder: (context, profilesSnapshot) {
                  if (profilesSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Ошибка загрузки company_profile: ${profilesSnapshot.error}',
                        style: TextStyle(color: bodyColor),
                      ),
                    );
                  }
                  if (!profilesSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore.collection('users').snapshots(),
                    builder: (context, usersSnapshot) {
                      if (usersSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Ошибка загрузки users: ${usersSnapshot.error}',
                            style: TextStyle(color: bodyColor),
                          ),
                        );
                      }
                      if (!usersSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rows = _buildMergedCompanyRows(
                        companies: companiesSnapshot.data!.docs,
                        profiles: profilesSnapshot.data!.docs,
                        users: usersSnapshot.data!.docs,
                      );
                      if (rows.isEmpty) {
                        return Center(
                          child: Text(
                            _companySearch.trim().isEmpty
                                ? 'Компании не найдены'
                                : 'По запросу ничего не найдено',
                            style: TextStyle(color: bodyColor),
                          ),
                        );
                      }
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dataTableTheme: DataTableThemeData(
                              headingTextStyle: TextStyle(
                                color: headingColor,
                                fontWeight: FontWeight.w700,
                              ),
                              dataTextStyle: TextStyle(color: bodyColor),
                              headingRowColor:
                                  WidgetStatePropertyAll<Color>(surface),
                              dataRowColor:
                                  WidgetStatePropertyAll<Color>(surface),
                            ),
                            iconTheme: IconThemeData(color: bodyColor),
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    const DataColumn(label: Text('ID')),
                                    ...def.fields.map(
                                      (f) => DataColumn(label: Text(f.label)),
                                    ),
                                    const DataColumn(label: Text('Действия')),
                                  ],
                                  rows: rows.map((row) {
                                    final data = row.data;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxWidth: 180),
                                            child: Text(
                                              row.id,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  TextStyle(color: bodyColor),
                                            ),
                                          ),
                                        ),
                                        ...def.fields.map(
                                          (f) => DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 220,
                                              ),
                                              child: Text(
                                                _fmt(data[f.key]),
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    TextStyle(color: bodyColor),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                tooltip: 'Редактировать',
                                                onPressed: () =>
                                                    _openEditDialog(
                                                  def,
                                                  existing: data,
                                                  id: row.id,
                                                ),
                                                icon: Icon(
                                                  Icons.edit_outlined,
                                                  size: 18,
                                                  color: bodyColor,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Все поля',
                                                onPressed: () =>
                                                    _showRawCompanyDetails(
                                                  row.id,
                                                  data,
                                                ),
                                                icon: Icon(
                                                  Icons.article_outlined,
                                                  size: 18,
                                                  color: bodyColor,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Логи компании',
                                                onPressed: () =>
                                                    _openCompanyLogs(row.id),
                                                icon: Icon(
                                                  Icons.history_outlined,
                                                  size: 18,
                                                  color: bodyColor,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Удалить',
                                                onPressed: () =>
                                                    _deleteDoc(def, row.id),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTemplatesFocusedView() {
    final def = _roleTemplatesDef;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                'Роли',
                style: FlutterFlowTheme.of(context).headlineMedium,
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            'Здесь только стандартные роли для новых компаний: список ролей, добавление новых ролей и настройка прав у существующих.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ),
        Expanded(child: _buildTab(def)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncTabFromQuery();
    if (!_isSuperAdmin) {
      return Theme(
        data: _adminTheme(context),
        child: Scaffold(
          backgroundColor: const Color(0xFF0B1120),
          body: Center(
            child: Text(
              'Доступ запрещен',
              style: FlutterFlowTheme.of(context).headlineSmall,
            ),
          ),
        ),
      );
    }

    return Theme(
      data: _adminTheme(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        drawer: const Drawer(
          child: DrawersWidget(),
        ),
        body: Row(
          children: [
            if (responsiveVisibility(
                context: context, phone: false, tablet: false))
              Container(
                width: 270,
                decoration: const BoxDecoration(color: Color(0xFF111D31)),
                child: const DrawersWidget(),
              ),
            Expanded(
              child: SafeArea(
                child: _isRoleTemplatesFocused
                    ? _buildRoleTemplatesFocusedView()
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                Text(
                                  'Супер-админ',
                                  style: FlutterFlowTheme.of(context)
                                      .headlineMedium,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: FutureBuilder<List<_CompanyOption>>(
                                    future: _companyOptionsFuture,
                                    builder: (context, snap) {
                                      final companies =
                                          snap.data ?? const <_CompanyOption>[];
                                      final items = companies
                                          .map((company) =>
                                              DropdownMenuItem<String>(
                                                value: company.id,
                                                child: Text(
                                                  '${company.name} (${company.id})',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ))
                                          .toList();

                                      if (_selectedCompanyId.isEmpty &&
                                          companies.isNotEmpty) {
                                        final userActive =
                                            _activeCompanyFromUser();
                                        final hasUserActive = companies
                                            .any((c) => c.id == userActive);
                                        _selectedCompanyId = hasUserActive
                                            ? userActive
                                            : _allCompaniesValue;
                                      }

                                      if (!_syncedInitialCompany &&
                                          _selectedCompanyId.isNotEmpty &&
                                          _selectedCompanyId !=
                                              _allCompaniesValue) {
                                        _syncedInitialCompany = true;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          _setGlobalActiveCompany(
                                              _selectedCompanyId);
                                        });
                                      }

                                      return DropdownButtonFormField<String>(
                                        initialValue: _selectedCompanyId.isEmpty
                                            ? null
                                            : _selectedCompanyId,
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: _allCompaniesValue,
                                            child: Text('Все компании'),
                                          ),
                                          ...items,
                                        ],
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(
                                              () => _selectedCompanyId = v);
                                          if (v != _allCompaniesValue) {
                                            _setGlobalActiveCompany(v);
                                          }
                                        },
                                        selectedItemBuilder: (context) => [
                                          const Text('Все компании'),
                                          ...companies.map(
                                            (company) => Text(
                                              company.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Компания',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Обновить компании',
                                  onPressed: _reloadCompanyOptions,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                          ),
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: const Color(0xFFF8FAFC),
                            unselectedLabelColor: const Color(0xFF94A3B8),
                            indicatorColor: const Color(0xFFC9A15B),
                            tabs: _defs.map((d) => Tab(text: d.title)).toList(),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: _defs.map(_buildTab).toList(),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FieldType { text, number, bool, multiline, list }

class _FieldDef {
  const _FieldDef(this.key, this.label, {this.type = _FieldType.text});
  final String key;
  final String label;
  final _FieldType type;
}

class _CompanyOption {
  const _CompanyOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _AdminRow {
  const _AdminRow({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;
}

class _CollectionDef {
  const _CollectionDef({
    required this.id,
    required this.title,
    required this.collection,
    required this.companyScoped,
    required this.fields,
  });

  final String id;
  final String title;
  final String collection;
  final bool companyScoped;
  final List<_FieldDef> fields;
}

class _RoleDialogResult {
  const _RoleDialogResult({
    required this.roleId,
    required this.name,
    required this.description,
    required this.permissions,
  });

  final String roleId;
  final String name;
  final String description;
  final Set<String> permissions;
}

class _RolePermissionsDialog extends StatefulWidget {
  const _RolePermissionsDialog({
    required this.initialRoleId,
    required this.initialName,
    required this.initialDescription,
    required this.initialPermissions,
  });

  final String initialRoleId;
  final String initialName;
  final String initialDescription;
  final Set<String> initialPermissions;

  @override
  State<_RolePermissionsDialog> createState() => _RolePermissionsDialogState();
}

class _RolePermissionsDialogState extends State<_RolePermissionsDialog> {
  late final TextEditingController _roleIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _roleIdController = TextEditingController(text: widget.initialRoleId);
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
    _selected = Set<String>.from(widget.initialPermissions);
  }

  @override
  void dispose() {
    _roleIdController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Роль: доступы'),
      content: SizedBox(
        width: 820,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 640),
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: _roleIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID роли (необязательно)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Название роли'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Text(
                    'Настройка шаблона идет по структуре пользовательского бокового меню: основной раздел, затем подразделы, затем отдельные функции и кнопки.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PermissionTreeSelector(
                  selected: _selected,
                  onChanged: (value) => setState(() => _selected = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _RoleDialogResult(
                roleId: _roleIdController.text.trim(),
                name: name,
                description: _descriptionController.text.trim(),
                permissions: _selected,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
