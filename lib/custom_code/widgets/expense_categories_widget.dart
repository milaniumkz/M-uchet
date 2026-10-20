// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/custom_code/widgets/editing_helper.dart';
import '/utils/accounting_accounts.dart';
import '/utils/app_money_format.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/expense_plan_analytics_support.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseCategoriesWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const ExpenseCategoriesWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<ExpenseCategoriesWidget> createState() =>
      _ExpenseCategoriesWidgetState();
}

enum _BudgetDisplayMode { yearTotal, byMonths }

String _budgetCurrencySymbol() => moneySymbolForCurrency('KZT');

String _formatBudgetCurrency(
  double amount, {
  String? currencyCode,
}) {
  return formatMoneyWithCurrency(
    amount,
    currencyCode: currencyCode,
    symbol: currencyCode == null ? moneySymbolForCurrency('KZT') : null,
  );
}

class _ExpenseCategoriesWidgetState extends State<ExpenseCategoriesWidget> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _budgetTableScrollController = ScrollController();
  static const _legacyProfessionalServicesTitle =
      'Юридические и бухгалтерские услуги (внешние)';
  static const _legalServicesTitle = 'Юридические услуги (внешние)';
  static const _accountingServicesTitle = 'Бухгалтерские услуги (внешние)';
  static const _legacyTaxTitle = 'Налог';
  static const _taxesTitle = 'Налоги';
  static const _legacyCostPriceTitle = 'Себестоимость продукта / услуги';
  static const _purchaseGoodsTitle = 'Закуп товара';
  static const _purchaseEquipmentTitle = 'Закуп оборудования';
  static const _reservesAndRisksTitle = 'Резервы и риски';
  static const _legacyItTitle = 'IT и автоматизация (общехозяйственные)';
  static const _itTitle = 'IT и автоматизация';
  static const _oneTimePeriodicity = 'Разово';
  static const _semiAnnualPeriodicity = 'Раз в 6 месяцев';

  static const _expensePeriodicities = [
    _oneTimePeriodicity,
    'Ежемесячно',
    'Ежеквартально',
    _semiAnnualPeriodicity,
    'Ежегодно',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _accountingEntries = [];
  List<Map<String, dynamic>> _businessEvents = [];
  List<Map<String, dynamic>> _expensePlans = [];
  List<Map<String, dynamic>> _budgetProjects = [];
  List<Map<String, dynamic>> _shops = [];
  final Map<String, double> _actualByCategory = {};
  final Map<String, double> _actualPreviousYearByCategory = {};
  bool _loading = false;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _rangeStartMonth = 1;
  int _rangeEndMonth = 12;
  _BudgetDisplayMode _budgetDisplayMode = _BudgetDisplayMode.byMonths;
  bool _incomeExpanded = false;
  bool _expenseExpanded = false;
  bool _budgetDeviationExpanded = false;
  bool _budgetPreviousYearExpanded = false;
  String _budgetCurrencyCode = 'KZT';
  String _viewMode = 'table';
  final Set<String> _enabledChartSeries = <String>{
    'Доходы План',
    'Доходы Факт',
    'Доходы Факт прошлого года',
    'Расходы План',
    'Расходы Факт',
    'Расходы Факт прошлого года',
    'Налоги',
    'Чистая прибыль',
  };
  final Map<String, bool> _groupExpanded = {};
  final Set<String> _defaultsEnsuredCompanyIds = <String>{};

  static const _incomeDefaults = [
    'Доход от основной деятельности',
    'Доход от неосновной деятельности',
    'Прочие доходы',
  ];

  static const _expenseDefaults = [
    'Маркетинг (всё включено)',
    'Отдел продаж (всё включено)',
    'Администрация (не доходная)',
    'Закуп товара',
    _purchaseEquipmentTitle,
    _itTitle,
    'Аренда / инфраструктура',
    'Финансовые расходы',
    'Оплата кредита',
    'Инвестиции',
    'Растаможка и логистика',
    'Основной ФОТ',
    _legalServicesTitle,
    _accountingServicesTitle,
    'НДС',
    'Налоги',
    'Резервы и риски',
    'Строительные работы',
  ];

  static final Map<String, int> _incomeOrder = {
    for (var i = 0; i < _incomeDefaults.length; i++) _incomeDefaults[i]: i,
  };

  static final Map<String, int> _expenseOrder = {
    for (var i = 0; i < _expenseDefaults.length; i++) _expenseDefaults[i]: i,
  };

  static const Map<String, List<String>> _defaultExpenseChildren = {
    'Оплата кредита': ['Основной долг', 'Проценты'],
    'Строительные работы': [
      'Проектирование',
      'Материалы',
      'Работы подрядчиков',
      'Машины/Механизмы',
      'Разрешения и налоги',
      'Непредвиденные расходы',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _budgetTableScrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollBudgetTableBy(double delta) async {
    if (!_budgetTableScrollController.hasClients) return;
    final position = _budgetTableScrollController.position;
    final target = (_budgetTableScrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    await _budgetTableScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  String _effectiveCompanyId() {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: _auth.currentUser?.uid ?? '',
    );
  }

  List<String> _queryCompanyIds() {
    return resolveQueryCompanyIds(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: _auth.currentUser?.uid ?? '',
    );
  }

  String _normalizedPeriodicity(dynamic value) {
    final periodicity = value?.toString().trim() ?? '';
    return _expensePeriodicities.contains(periodicity)
        ? periodicity
        : _oneTimePeriodicity;
  }

  String _categoryPeriodicity(Map<String, dynamic> category) {
    return _normalizedPeriodicity(category['periodicity']);
  }

  static double _parsePlanValue(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().trim().replaceAll(',', '.') ?? '') ??
        0;
  }

  static Map<String, dynamic> _normalizedPlanByYear(dynamic source) {
    if (source is! Map) return <String, dynamic>{};
    final normalized = <String, dynamic>{};
    source.forEach((yearKey, yearValue) {
      final yearMap = <String, dynamic>{};
      if (yearValue is Map) {
        yearValue.forEach((monthKey, monthValue) {
          yearMap[monthKey.toString()] = monthValue;
        });
      }
      normalized[yearKey.toString()] = yearMap;
    });
    return normalized;
  }

  static Map<String, dynamic> _planYearMap(dynamic source, int year) {
    final normalized = _normalizedPlanByYear(source);
    final yearMap = normalized[year.toString()];
    if (yearMap is Map<String, dynamic>) {
      return yearMap;
    }
    if (yearMap is Map) {
      return Map<String, dynamic>.from(yearMap);
    }
    return <String, dynamic>{};
  }

  static double _planValueForMonth(
    dynamic source,
    int year,
    int month,
  ) {
    final yearMap = _planYearMap(source, year);
    return _parsePlanValue(yearMap[month.toString()]);
  }

  String _incomeSourceId(Map<String, dynamic> row) {
    return (row['sales_source_id'] ?? row['shop_id'] ?? '').toString().trim();
  }

  String _incomeSourceName(Map<String, dynamic> row) {
    return (row['sales_source_name'] ?? row['shop_name'] ?? row['title'] ?? '')
        .toString()
        .trim();
  }

  Future<List<Map<String, dynamic>>> _loadCompanyScopedDocs(
    String collectionName, {
    int? limitPerQuery,
    bool preferFresh = false,
  }) async {
    final companyIds = _queryCompanyIds();
    if (companyIds.isEmpty) return const <Map<String, dynamic>>[];

    final docsById = <String, Map<String, dynamic>>{};
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final field in const ['idCompany', 'companyId', 'company_id']) {
      for (final chunk in splitCompanyIdsForWhereIn(companyIds)) {
        Query<Map<String, dynamic>> query =
            _firestore.collection(collectionName);
        if (chunk.length == 1) {
          query = query.where(field, isEqualTo: chunk.first);
        } else {
          query = query.where(field, whereIn: chunk);
        }
        if (limitPerQuery != null) {
          query = query.limit(limitPerQuery);
        }
        if (!preferFresh) {
          futures.add(query.get());
        } else {
          futures.add(() async {
            try {
              return await query.get(const GetOptions(source: Source.server));
            } catch (_) {
              return query.get();
            }
          }());
        }
      }
    }
    final snapshots = await Future.wait(futures);
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        final data = doc.data();
        docsById[doc.id] = <String, dynamic>{
          'id': doc.id,
          ...(data is Map<String, dynamic>
              ? data
              : data is Map
                  ? Map<String, dynamic>.from(data)
                  : const <String, dynamic>{}),
        };
      }
    }
    return docsById.values.toList();
  }

  Future<void> _ensureDefaultsIfNeeded(List<String> companyIds) async {
    final pending = companyIds
        .where((companyId) => !_defaultsEnsuredCompanyIds.contains(companyId))
        .toList();
    if (pending.isEmpty) {
      return;
    }
    await Future.wait(pending.map(_ensureDefaults));
    _defaultsEnsuredCompanyIds.addAll(pending);
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _categories = [];
          _transactions = [];
          _accountingEntries = [];
          _businessEvents = [];
          _budgetProjects = [];
        });
        return;
      }

      final companyIds = _queryCompanyIds();
      if (companyIds.isEmpty) {
        setState(() {
          _categories = [];
          _transactions = [];
          _accountingEntries = [];
          _businessEvents = [];
          _budgetProjects = [];
        });
        return;
      }

      await _ensureDefaultsIfNeeded(companyIds);

      final results = await Future.wait([
        _firestore
            .collection('company_profile')
            .doc(_effectiveCompanyId())
            .get(),
        _loadCompanyScopedDocs('statRashod', preferFresh: true),
        _loadCompanyScopedDocs('tranzaction', limitPerQuery: 2000),
        _loadCompanyScopedDocs('accounting_entries', limitPerQuery: 5000),
        _loadCompanyScopedDocs('shops'),
        _loadCompanyScopedDocs('expense_plans', limitPerQuery: 1000),
        _loadCompanyScopedDocs('business_events', limitPerQuery: 4000),
        _loadCompanyScopedDocs('budget_projects', limitPerQuery: 1000),
      ]);

      setState(() {
        final profileSnap =
            results[0] as DocumentSnapshot<Map<String, dynamic>>;
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final profile = countryProfileFromData(profileData);
        _budgetCurrencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: profile.baseCurrency,
        );
        _categories = List<Map<String, dynamic>>.from(results[1] as Iterable);
        _transactions = List<Map<String, dynamic>>.from(results[2] as Iterable);
        _accountingEntries =
            List<Map<String, dynamic>>.from(results[3] as Iterable);
        _shops = List<Map<String, dynamic>>.from(results[4] as Iterable);
        _expensePlans = List<Map<String, dynamic>>.from(results[5] as Iterable);
        _businessEvents =
            List<Map<String, dynamic>>.from(results[6] as Iterable);
        _budgetProjects =
            List<Map<String, dynamic>>.from(results[7] as Iterable);
      });
      _recomputeActual();
    } catch (e) {
      debugPrint('Error loading statRashod: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatBudgetTableValue(double amount) {
    if (!amount.isFinite) return '0';
    final sign = amount < 0 ? '-' : '';
    final absolute = amount.abs().toStringAsFixed(0);
    final formatted = absolute.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$sign$formatted';
  }

  String _formatBudgetMoney(double amount) {
    return _formatBudgetCurrency(amount, currencyCode: _budgetCurrencyCode);
  }

  String _previousYearFactLabel() {
    final shortYear = ((_selectedYear - 1) % 100).toString().padLeft(2, '0');
    return 'Факт $shortYear';
  }

  bool get _isDarkBudgetTheme =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _budgetPageBackground => _isDarkBudgetTheme
      ? FlutterFlowTheme.of(context).primaryBackground
      : const Color(0xFFF7F8FA);

  Color get _budgetIncomeColor =>
      _isDarkBudgetTheme ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);

  Color get _budgetIncomeDetailColor =>
      _isDarkBudgetTheme ? const Color(0xFF86EFAC) : const Color(0xFF166534);

  Color get _budgetExpenseColor =>
      _isDarkBudgetTheme ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  Color get _budgetExpenseDetailColor =>
      _isDarkBudgetTheme ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

  Color get _budgetTaxesColor =>
      _isDarkBudgetTheme ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

  Color get _budgetProfitColor =>
      _isDarkBudgetTheme ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

  Future<void> _ensureDefaults(String companyId) async {
    if (companyId.isEmpty) return;
    final existing = await _firestore
        .collection('statRashod')
        .where('idCompany', isEqualTo: companyId)
        .where('is_default', isEqualTo: true)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await _ensureSplitProfessionalServices(companyId);
      await _ensureTaxesCategoryTitle(companyId);
      await _ensurePurchaseCategoryTitle(companyId);
      await _ensureExpenseDefaultMigrations(companyId);
      return;
    }
    final batch = _firestore.batch();
    for (final title in _incomeDefaults) {
      final ref = _firestore.collection('statRashod').doc();
      batch.set(ref, _defaultCategoryPayload(companyId, title, 'income'));
    }
    for (final title in _expenseDefaults) {
      final ref = _firestore.collection('statRashod').doc();
      batch.set(ref, _defaultCategoryPayload(companyId, title, 'expense'));
      final children = _defaultExpenseChildren[title] ?? const <String>[];
      for (final childTitle in children) {
        final childRef = _firestore.collection('statRashod').doc();
        batch.set(
          childRef,
          _defaultCategoryPayload(
            companyId,
            childTitle,
            'expense',
            parentId: ref.id,
            isGroup: false,
          ),
        );
      }
    }
    await batch.commit();
  }

  Map<String, dynamic> _defaultCategoryPayload(
    String companyId,
    String title,
    String type, {
    String parentId = '',
    bool isGroup = true,
    String periodicity = _oneTimePeriodicity,
  }) {
    return {
      'title': title,
      'subtitle': '',
      'description': '',
      'type': type,
      'parentId': parentId,
      'is_group': isGroup,
      'is_default': true,
      'planByYear': {},
      'budget': 0,
      'spent': 0,
      'currency': _budgetCurrencySymbol(),
      'is_active': true,
      'user_id': _auth.currentUser?.uid ?? '',
      'idCompany': companyId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      if (type == 'expense') 'periodicity': periodicity,
    };
  }

  Future<void> _ensureSplitProfessionalServices(String companyId) async {
    final snap = await _firestore
        .collection('statRashod')
        .where('idCompany', isEqualTo: companyId)
        .where('type', isEqualTo: 'expense')
        .where('is_default', isEqualTo: true)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? legacyDoc;
    var hasLegal = false;
    var hasAccounting = false;

    for (final doc in snap.docs) {
      final title = (doc.data()['title'] ?? '').toString().trim();
      if (title == _legacyProfessionalServicesTitle) legacyDoc = doc;
      if (title == _legalServicesTitle) hasLegal = true;
      if (title == _accountingServicesTitle) hasAccounting = true;
    }

    if (legacyDoc == null && hasLegal && hasAccounting) return;

    final batch = _firestore.batch();

    if (legacyDoc != null && !hasLegal) {
      batch.update(legacyDoc.reference, {
        'title': _legalServicesTitle,
        'updated_at': FieldValue.serverTimestamp(),
      });
      hasLegal = true;
    }

    if (!hasAccounting) {
      final ref = _firestore.collection('statRashod').doc();
      batch.set(
        ref,
        _defaultCategoryPayload(
          companyId,
          _accountingServicesTitle,
          'expense',
        ),
      );
    }

    await batch.commit();
  }

  Future<void> _ensureTaxesCategoryTitle(String companyId) async {
    final snap = await _firestore
        .collection('statRashod')
        .where('idCompany', isEqualTo: companyId)
        .where('type', isEqualTo: 'expense')
        .where('is_default', isEqualTo: true)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? legacyDoc;
    var hasTaxes = false;

    for (final doc in snap.docs) {
      final title = (doc.data()['title'] ?? '').toString().trim();
      if (title == _legacyTaxTitle) legacyDoc = doc;
      if (title == _taxesTitle) hasTaxes = true;
    }

    if (legacyDoc == null || hasTaxes) return;

    await legacyDoc.reference.update({
      'title': _taxesTitle,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensurePurchaseCategoryTitle(String companyId) async {
    final snap = await _firestore
        .collection('statRashod')
        .where('idCompany', isEqualTo: companyId)
        .where('type', isEqualTo: 'expense')
        .where('is_default', isEqualTo: true)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? legacyDoc;
    var hasPurchase = false;

    for (final doc in snap.docs) {
      final title = (doc.data()['title'] ?? '').toString().trim();
      if (title == _legacyCostPriceTitle) legacyDoc = doc;
      if (title == _purchaseGoodsTitle) hasPurchase = true;
    }

    if (legacyDoc == null || hasPurchase) return;

    await legacyDoc.reference.update({
      'title': _purchaseGoodsTitle,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureExpenseDefaultMigrations(String companyId) async {
    final snap = await _firestore
        .collection('statRashod')
        .where('idCompany', isEqualTo: companyId)
        .where('type', isEqualTo: 'expense')
        .get();

    final docs = snap.docs;
    final docsByTitle = <String, String>{};
    for (final doc in docs) {
      final title = (doc.data()['title'] ?? '').toString().trim();
      if (title.isNotEmpty && !docsByTitle.containsKey(title)) {
        docsByTitle[title] = doc.id;
      }
    }

    final batch = _firestore.batch();

    final legacyItId = docsByTitle[_legacyItTitle];
    final hasNewIt = docsByTitle.containsKey(_itTitle);
    if (legacyItId != null && !hasNewIt) {
      batch.update(_firestore.collection('statRashod').doc(legacyItId), {
        'title': _itTitle,
        'updated_at': FieldValue.serverTimestamp(),
      });
      docsByTitle[_itTitle] = legacyItId;
      docsByTitle.remove(_legacyItTitle);
    }

    final requiredGroups = <String>[
      _purchaseGoodsTitle,
      _purchaseEquipmentTitle,
      _itTitle,
      'Оплата кредита',
      'Инвестиции',
      'Растаможка и логистика',
      'Основной ФОТ',
      'Строительные работы',
    ];
    for (final title in requiredGroups) {
      if (!docsByTitle.containsKey(title)) {
        final ref = _firestore.collection('statRashod').doc();
        batch.set(ref, _defaultCategoryPayload(companyId, title, 'expense'));
        docsByTitle[title] = ref.id;
      }
    }

    for (final entry in _defaultExpenseChildren.entries) {
      final groupId = docsByTitle[entry.key] ?? '';
      if (groupId.isEmpty) continue;
      final childTitles = entry.value;
      for (final childTitle in childTitles) {
        final hasChild = docs.any(
          (doc) =>
              (doc.data()['title'] ?? '').toString().trim() == childTitle &&
              (doc.data()['parentId'] ?? '').toString().trim() == groupId,
        );
        if (!hasChild) {
          final ref = _firestore.collection('statRashod').doc();
          batch.set(
            ref,
            _defaultCategoryPayload(
              companyId,
              childTitle,
              'expense',
              parentId: groupId,
              isGroup: false,
            ),
          );
        }
      }
    }

    for (final doc in docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};
      if ((data['type'] ?? '').toString() == 'expense' &&
          _normalizedPeriodicity(data['periodicity']) !=
              (data['periodicity'] ?? '').toString().trim()) {
        updates['periodicity'] = _oneTimePeriodicity;
      }
      if (updates.isNotEmpty) {
        updates['updated_at'] = FieldValue.serverTimestamp();
        batch.update(doc.reference, updates);
      }
    }

    await batch.commit();
  }

  void _recomputeActual() {
    _actualByCategory.clear();
    _actualPreviousYearByCategory.clear();
    final months = _monthsInPeriod();
    for (final t in _budgetActualDocs()) {
      final rawDate = t['date'];
      DateTime? date;
      if (rawDate is Timestamp) {
        date = rawDate.toDate();
      } else if (rawDate is DateTime) {
        date = rawDate;
      } else if (rawDate is String) {
        date = DateTime.tryParse(rawDate);
      }
      if (date == null) continue;
      if (!months.contains(date.month)) continue;
      final type = _normalizedBudgetTxType(t['type']);
      final cat = _budgetTxCategoryTitle(t);
      if (cat.isEmpty) continue;
      final amount = _txAmount(t);
      final key = '$type|$cat';
      if (date.year == _selectedYear) {
        _actualByCategory[key] = (_actualByCategory[key] ?? 0) + amount;
      } else if (date.year == _selectedYear - 1) {
        _actualPreviousYearByCategory[key] =
            (_actualPreviousYearByCategory[key] ?? 0) + amount;
      }
    }
  }

  double _planFor(
    Map<String, dynamic> c, {
    List<int>? months,
  }) {
    final monthsToSum = months ?? _monthsInPeriod();
    double total = 0;
    for (final month in monthsToSum) {
      total += _planValueForMonth(c['planByYear'], _selectedYear, month);
    }
    return total;
  }

  double _actualFor(
    Map<String, dynamic> c, {
    bool previousYear = false,
  }) {
    final type = (c['type'] ?? 'expense') == 'income' ? 'income' : 'decome';
    final title = (c['title'] ?? '').toString();
    if (title.isEmpty) return 0;
    final source =
        previousYear ? _actualPreviousYearByCategory : _actualByCategory;
    return source['$type|$title'] ?? 0;
  }

  String _normalizedBudgetTxType(dynamic rawType) {
    final normalized = rawType?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'income' ||
        normalized == 'доход' ||
        normalized == 'doxod') {
      return 'income';
    }
    return 'decome';
  }

  String _budgetTxCategoryTitle(Map<String, dynamic> tx) {
    for (final value in [
      tx['budget_category'],
      tx['category_name'],
      tx['category'],
      tx['kat'],
      tx['title'],
    ]) {
      final title = value?.toString().trim() ?? '';
      final normalized = title.toLowerCase();
      if (title.isNotEmpty &&
          normalized != 'decome' &&
          normalized != 'income' &&
          normalized != 'doxod' &&
          normalized != 'расход' &&
          normalized != 'доход') {
        if (_normalizedBudgetTxType(tx['type']) == 'decome' &&
            normalized.contains('маркетинг')) {
          return 'Маркетинг (всё включено)';
        }
        return title;
      }
    }
    final text = (tx['text'] ?? tx['comment'] ?? '').toString().toLowerCase();
    if (text.contains('маркетинг')) return 'Маркетинг (всё включено)';
    if (text.contains('осмс') ||
        text.contains('налог') ||
        text.contains('кпн') ||
        text.contains('ндс')) {
      return _taxesTitle;
    }
    if (text.contains('роялти') || text.contains('лицензи')) {
      return 'Доход от неосновной деятельности';
    }
    return _normalizedBudgetTxType(tx['type']) == 'income'
        ? 'Доход от основной деятельности'
        : 'Администрация (не доходная)';
  }

  double _actualForCategoryMonth(
    Map<String, dynamic> category,
    int month, {
    bool previousYear = false,
  }) {
    final type =
        (category['type'] ?? 'expense') == 'income' ? 'income' : 'decome';
    final title = (category['title'] ?? '').toString().trim();
    if (title.isEmpty) return 0;
    final targetYear = previousYear ? _selectedYear - 1 : _selectedYear;
    return _budgetActualDocs().fold<double>(0, (total, tx) {
      final txDate = _txDate(tx);
      if (txDate == null ||
          txDate.year != targetYear ||
          txDate.month != month ||
          _normalizedBudgetTxType(tx['type']) != type ||
          _budgetTxCategoryTitle(tx) != title) {
        return total;
      }
      return total + _txAmount(tx);
    });
  }

  List<Map<String, dynamic>> _budgetActualDocs() {
    return buildBudgetActualDocs(
      transactions: _transactions,
      accountingEntries: _accountingEntries,
    );
  }

  double _actualForStoreMonth(
    String sourceId,
    String sourceName,
    int month, {
    bool previousYear = false,
  }) {
    final targetYear = previousYear ? _selectedYear - 1 : _selectedYear;
    var total = 0.0;
    for (final tx in _transactions) {
      final txDate = _txDate(tx);
      if (txDate == null ||
          txDate.year != targetYear ||
          txDate.month != month) {
        continue;
      }
      if (_normalizedBudgetTxType(tx['type']) != 'income') continue;
      final txSourceId =
          (tx['sales_source_id'] ?? tx['shop_id'] ?? '').toString().trim();
      final txSourceName =
          (tx['sales_source_name'] ?? tx['shop_name'] ?? '').toString().trim();
      final matches = sourceId.isNotEmpty
          ? txSourceId == sourceId
          : sourceName.isNotEmpty && txSourceName == sourceName;
      if (!matches) continue;
      total += _txAmount(tx);
    }
    return total;
  }

  double _systemActualForType(
    String type, {
    int? month,
    bool previousYear = false,
  }) {
    final normalizedType = type == 'income' ? 'income' : 'decome';
    final targetYear = previousYear ? _selectedYear - 1 : _selectedYear;
    final months = month == null ? _monthsInPeriod() : <int>[month];
    var total = 0.0;

    for (final entry in _accountingEntries) {
      final date = _entryDate(entry);
      if (date == null ||
          date.year != targetYear ||
          !months.contains(date.month)) {
        continue;
      }
      if (_entryActualType(entry) != normalizedType) continue;
      total += _entryAmount(entry);
    }

    for (final tx in _transactions) {
      final entryIds = tx['entry_ids'];
      if (entryIds is Iterable && entryIds.isNotEmpty) continue;
      final date = _txDate(tx);
      if (date == null ||
          date.year != targetYear ||
          !months.contains(date.month)) {
        continue;
      }
      if (_normalizedBudgetTxType(tx['type']) != normalizedType) continue;
      total += _txAmount(tx);
    }

    return total;
  }

  String _entryActualType(Map<String, dynamic> entry) {
    final flowType = (entry['money_flow_type'] ?? entry['moneyFlowType'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final debitId =
        (entry['debit_account_id'] ?? entry['debitAccountId'] ?? '').toString();
    final creditId =
        (entry['credit_account_id'] ?? entry['creditAccountId'] ?? '')
            .toString();
    final debitTitle =
        (entry['debit_account_title'] ?? entry['debitAccountTitle'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final isLegacyPayableExpense =
        debitId.startsWith('virtual:liability:payable:') ||
            debitTitle == 'кредиторка' ||
            debitTitle == 'кредиторская задолженность';

    if (accountNatureForId(creditId) == AccountNature.income) {
      return 'income';
    }
    if (accountNatureForId(debitId) == AccountNature.expense ||
        isLegacyPayableExpense) {
      if (flowType == 'TRANSFER' || flowType == 'INVESTING') return '';
      return 'decome';
    }
    return '';
  }

  DateTime? _entryDate(Map<String, dynamic> entry) {
    final raw = entry['entry_date'] ??
        entry['date'] ??
        entry['created_at'] ??
        entry['updated_at'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  double _entryAmount(Map<String, dynamic> entry) {
    final value = entry['amount'] ?? entry['summa'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  double _actualForGroupMonth(
    Map<String, dynamic> group,
    int month, [
    bool previousYear = false,
  ]) {
    final ownValue =
        _actualForCategoryMonth(group, month, previousYear: previousYear);
    final children = _tableChildrenForGroup(group);
    if (children.isEmpty) {
      return ownValue;
    }
    if ((group['type'] ?? 'expense').toString() == 'income') {
      final uniqueSources = <String, Map<String, String>>{};
      for (final child in children) {
        final sourceId = _incomeSourceId(child);
        final sourceName = _incomeSourceName(child);
        if (sourceId.isEmpty && sourceName.isEmpty) continue;
        final key = sourceId.isNotEmpty ? 'id:$sourceId' : 'name:$sourceName';
        uniqueSources[key] = {
          'id': sourceId,
          'name': sourceName,
        };
      }
      if (uniqueSources.isNotEmpty) {
        return ownValue +
            uniqueSources.values.fold<double>(
              0,
              (total, source) =>
                  total +
                  _actualForStoreMonth(
                    source['id'] ?? '',
                    source['name'] ?? '',
                    month,
                    previousYear: previousYear,
                  ),
            );
      }
    }
    return children.fold<double>(
      ownValue,
      (total, child) =>
          total +
          _actualForCategoryMonth(
            child,
            month,
            previousYear: previousYear,
          ),
    );
  }

  double _planForGroupMonth(Map<String, dynamic> group, int month) {
    final ownValue = _planFor(group, months: [month]);
    final children = _tableChildrenForGroup(group);
    if (children.isEmpty) {
      return ownValue;
    }
    final childrenValue = children.fold<double>(
      0,
      (total, child) => total + _planFor(child, months: [month]),
    );
    return ownValue != 0 ? ownValue : childrenValue;
  }

  double _sumTableGroupMonth(
    List<Map<String, dynamic>> groups,
    int month,
  ) {
    return groups.fold<double>(
      0,
      (total, group) => total + _tableValueForGroupMonth(group, month),
    );
  }

  double _sumPlanGroupMonth(
    List<Map<String, dynamic>> groups,
    int month,
  ) {
    return groups.fold<double>(
      0,
      (total, group) => total + _planForGroupMonth(group, month),
    );
  }

  double _sumActualGroupMonth(
    List<Map<String, dynamic>> groups,
    int month, [
    bool previousYear = false,
  ]) {
    return groups.fold<double>(
      0,
      (total, group) =>
          total +
          _actualForGroupMonth(
            group,
            month,
            previousYear,
          ),
    );
  }

  double _tableValueForCategoryMonth(Map<String, dynamic> category, int month) {
    final planned = _planFor(category, months: [month]);
    if (planned != 0) {
      return planned;
    }
    return _actualForCategoryMonth(category, month);
  }

  double _tableValueForGroupMonth(Map<String, dynamic> group, int month) {
    final children = _tableChildrenForGroup(group);
    if (children.isEmpty) {
      return _tableValueForCategoryMonth(group, month);
    }
    return children.fold<double>(
      0,
      (total, child) => total + _tableValueForCategoryMonth(child, month),
    );
  }

  String _expenseTableLabel(Map<String, dynamic> category) {
    final title = (category['title'] ?? '').toString().trim();
    final periodicity = _categoryPeriodicity(category);
    if (title.isEmpty) {
      return periodicity == _oneTimePeriodicity
          ? 'Статья расходов'
          : 'Статья расходов · $periodicity';
    }
    return periodicity == _oneTimePeriodicity ? title : '$title · $periodicity';
  }

  String _monthLabel(int month) {
    const names = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return names[month - 1];
  }

  List<Map<String, dynamic>> _groupsByType(String type) {
    final groups = _categories
        .where((c) =>
            (c['type'] ?? 'expense').toString() == type &&
            (c['is_group'] == true || (c['parentId'] ?? '').toString().isEmpty))
        .where(_groupMatchesSearch)
        .toList();
    final orderMap = type == 'income' ? _incomeOrder : _expenseOrder;
    groups.sort((a, b) {
      final aTitle = (a['title'] ?? '').toString();
      final bTitle = (b['title'] ?? '').toString();
      final aIndex = _sortIndexForCategoryTitle(aTitle, type, orderMap);
      final bIndex = _sortIndexForCategoryTitle(bTitle, type, orderMap);
      if (aIndex != bIndex) return aIndex.compareTo(bIndex);
      return aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
    });
    return groups;
  }

  List<Map<String, dynamic>> _tableGroupsByType(String type) {
    final groups = _categories
        .where((c) =>
            (c['type'] ?? 'expense').toString() == type &&
            (c['is_group'] == true || (c['parentId'] ?? '').toString().isEmpty))
        .toList();
    final defaults = type == 'income' ? _incomeDefaults : _expenseDefaults;

    final byTitle = <String, Map<String, dynamic>>{
      for (final group in groups)
        (group['title'] ?? '').toString().trim(): group,
    };
    final merged = <Map<String, dynamic>>[];

    for (final title in defaults) {
      final existing = byTitle.remove(title);
      if (existing != null) {
        merged.add(existing);
      } else {
        merged.add(<String, dynamic>{
          'id': '__default_${type}_$title',
          'title': title,
          'type': type,
          'is_group': true,
          'parentId': '',
          'periodicity': _oneTimePeriodicity,
        });
      }
    }

    final extras = byTitle.values.toList()
      ..sort((a, b) {
        final aTitle = (a['title'] ?? '').toString().toLowerCase();
        final bTitle = (b['title'] ?? '').toString().toLowerCase();
        return aTitle.compareTo(bTitle);
      });
    merged.addAll(extras);
    return merged;
  }

  List<Map<String, dynamic>> _tableChildrenForGroup(
      Map<String, dynamic> group) {
    final groupId = (group['id'] ?? '').toString();
    final title = (group['title'] ?? '').toString().trim();
    final actualChildren = _childrenFor(groupId);
    if ((group['type'] ?? '').toString() != 'expense') {
      return actualChildren;
    }

    final defaultChildren = _defaultExpenseChildren[title] ?? const <String>[];
    if (defaultChildren.isEmpty) {
      return actualChildren;
    }

    final byTitle = <String, Map<String, dynamic>>{
      for (final child in actualChildren)
        (child['title'] ?? '').toString().trim(): child,
    };
    final merged = <Map<String, dynamic>>[];
    for (final childTitle in defaultChildren) {
      final existing = byTitle.remove(childTitle);
      if (existing != null) {
        merged.add(existing);
      } else {
        merged.add(<String, dynamic>{
          'id': '__default_expense_child__$title::$childTitle',
          'title': childTitle,
          'type': 'expense',
          'is_group': false,
          'parentId': groupId,
          'periodicity': _oneTimePeriodicity,
        });
      }
    }
    final extras = byTitle.values.toList()
      ..sort((a, b) {
        final aTitle = (a['title'] ?? '').toString().toLowerCase();
        final bTitle = (b['title'] ?? '').toString().toLowerCase();
        return aTitle.compareTo(bTitle);
      });
    merged.addAll(extras);
    return merged;
  }

  Future<Map<String, dynamic>> _ensurePersistedTableGroup(
    Map<String, dynamic> group,
  ) async {
    final groupId = (group['id'] ?? '').toString().trim();
    if (groupId.isNotEmpty && !groupId.startsWith('__default_')) {
      return group;
    }

    final title = (group['title'] ?? '').toString().trim();
    final type = (group['type'] ?? 'expense').toString().trim();
    final existing = _categories.firstWhere(
      (item) =>
          (item['title'] ?? '').toString().trim() == title &&
          (item['type'] ?? '').toString().trim() == type &&
          ((item['parentId'] ?? '').toString().trim().isEmpty) &&
          (item['is_group'] == true ||
              (item['parentId'] ?? '').toString().isEmpty),
      orElse: () => const <String, dynamic>{},
    );
    if (existing.isNotEmpty) {
      return existing;
    }

    final companyId = _effectiveCompanyId();
    final ref = _firestore.collection('statRashod').doc();
    await ref.set(_defaultCategoryPayload(companyId, title, type));
    if (companyId.isNotEmpty) {
      FirestoreQueryCache.instance.invalidateCompanyCollection(
        'statRashod',
        companyId,
      );
    }
    await _loadCategories();
    return _categories.firstWhere(
      (item) =>
          (item['title'] ?? '').toString().trim() == title &&
          (item['type'] ?? '').toString().trim() == type &&
          ((item['parentId'] ?? '').toString().trim().isEmpty),
      orElse: () => <String, dynamic>{
        ...group,
        'id': ref.id,
      },
    );
  }

  bool _groupMatchesSearch(Map<String, dynamic> group) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final title = (group['title'] ?? '').toString().toLowerCase();
    if (title.contains(query)) return true;
    return _childrenFor((group['id'] ?? '').toString()).any((child) {
      final childTitle = (child['title'] ?? '').toString().toLowerCase();
      return childTitle.contains(query);
    });
  }

  int _sortIndexForCategoryTitle(
    String title,
    String type,
    Map<String, int> orderMap,
  ) {
    if (type == 'expense' && title.trim() == _reservesAndRisksTitle) {
      return 100000;
    }
    return orderMap[title] ?? 1000;
  }

  List<Map<String, dynamic>> _childrenFor(String groupId) {
    if (groupId.isEmpty) return [];
    return _categories
        .where((c) => (c['parentId'] ?? '').toString() == groupId)
        .toList();
  }

  List<int> _monthsInPeriod() {
    final start =
        _rangeStartMonth <= _rangeEndMonth ? _rangeStartMonth : _rangeEndMonth;
    final end =
        _rangeEndMonth >= _rangeStartMonth ? _rangeEndMonth : _rangeStartMonth;
    return List.generate(end - start + 1, (index) => start + index);
  }

  double _planForGroup(Map<String, dynamic> group) {
    final children = _childrenFor(group['id']?.toString() ?? '');
    if (children.isNotEmpty) {
      return children.fold<double>(0, (total, c) => total + _planFor(c));
    }
    return _planFor(group);
  }

  double _actualForGroup(
    Map<String, dynamic> group, {
    bool previousYear = false,
  }) {
    final children = _childrenFor(group['id']?.toString() ?? '');
    if (children.isNotEmpty) {
      return children.fold<double>(
          0, (total, c) => total + _actualFor(c, previousYear: previousYear));
    }
    return _actualFor(group, previousYear: previousYear);
  }

  double _totalPlanForType(String type) {
    final groups = _groupsByType(type);
    return groups.fold<double>(
        0, (total, group) => total + _planForGroup(group));
  }

  double _totalActualForType(String type, {bool previousYear = false}) {
    return _systemActualForType(type, previousYear: previousYear);
  }

  double get _budgetIncomeActual => _totalActualForType('income');

  double get _budgetTaxesActual {
    final taxGroup = _groupsByType('expense').firstWhere(
      (group) => (group['title'] ?? '').toString().trim() == _taxesTitle,
      orElse: () => const <String, dynamic>{},
    );
    if (taxGroup.isEmpty) return 0;
    return _actualForGroup(taxGroup);
  }

  double get _budgetExpenseActualExcludingTaxes {
    return _totalActualForType('expense') - _budgetTaxesActual;
  }

  double get _budgetNetProfit =>
      _budgetIncomeActual -
      _budgetExpenseActualExcludingTaxes -
      _budgetTaxesActual;

  double get _selectedBudgetNetProfit {
    final points = _budgetChartPoints;
    if (points.isEmpty) return 0;
    return points.fold<double>(
      0,
      (total, point) => total + point.fact,
    );
  }

  List<DateTime> _budgetChartMonths() {
    if (_budgetDisplayMode == _BudgetDisplayMode.yearTotal) {
      return List.generate(
        12,
        (index) => DateTime(_selectedYear, index + 1),
      );
    }
    return _monthsInPeriod()
        .map((month) => DateTime(_selectedYear, month))
        .toList(growable: false);
  }

  _BudgetChartPoint _buildBudgetPointForDate(DateTime date) {
    final month = date.month;
    final incomeGroups = _tableGroupsByType('income');
    final allExpenseGroups = _tableGroupsByType('expense');
    final expenseGroups = allExpenseGroups
        .where(
            (group) => (group['title'] ?? '').toString().trim() != _taxesTitle)
        .toList(growable: false);
    final taxesGroups = allExpenseGroups
        .where(
            (group) => (group['title'] ?? '').toString().trim() == _taxesTitle)
        .toList(growable: false);

    final monthIncome = _sumTableGroupMonth(incomeGroups, month);
    final monthExpense = _sumTableGroupMonth(expenseGroups, month);
    final monthTaxes = _sumTableGroupMonth(taxesGroups, month);
    final monthPlanIncome = _sumPlanGroupMonth(incomeGroups, month);
    final monthPlanExpense = _sumPlanGroupMonth(expenseGroups, month);
    final monthPlanTaxes = _sumPlanGroupMonth(taxesGroups, month);
    final monthActualIncome = _systemActualForType('income', month: month);
    final monthActualExpense = _systemActualForType('expense', month: month);
    final monthPreviousYearIncome =
        _systemActualForType('income', month: month, previousYear: true);
    final monthPreviousYearExpense =
        _systemActualForType('expense', month: month, previousYear: true);
    return _BudgetChartPoint(
      label: _monthLabel(date.month),
      income: monthPlanIncome,
      incomeFact: monthActualIncome,
      incomePreviousYear: monthPreviousYearIncome,
      expense: monthPlanExpense,
      expenseFact: monthActualExpense,
      expensePreviousYear: monthPreviousYearExpense,
      taxes: monthTaxes,
      netProfit: monthIncome - monthExpense - monthTaxes,
      plan: monthPlanIncome - monthPlanExpense - monthPlanTaxes,
      fact: computeBudgetActualNetProfit(
        incomeActual: monthActualIncome,
        expenseActual: monthActualExpense,
      ),
    );
  }

  double _txAmount(Map<String, dynamic> tx) {
    final value = tx['amount_company'] ??
        tx['amountCompany'] ??
        tx['amount'] ??
        tx['summa'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  DateTime? _txDate(Map<String, dynamic> tx) {
    final rawDate = tx['date'] ?? tx['created_at'] ?? tx['updated_at'];
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is DateTime) return rawDate;
    if (rawDate is String) return DateTime.tryParse(rawDate);
    return null;
  }

  List<_BudgetChartPoint> get _budgetChartPoints {
    return _budgetChartMonths()
        .map(_buildBudgetPointForDate)
        .toList(growable: false);
  }

  bool _isGroupExpanded(String id) => _groupExpanded[id] ?? false;

  void _toggleGroupExpanded(String id) {
    setState(() {
      _groupExpanded[id] = !(_groupExpanded[id] ?? false);
    });
  }

  void _expandIncomeGroup(String id) {
    if (id.trim().isEmpty) return;
    setState(() {
      _incomeExpanded = true;
      _groupExpanded[id] = true;
    });
  }

  double _actualForStore(
    String sourceId,
    String sourceName, {
    bool previousYear = false,
  }) {
    final months = _monthsInPeriod();
    final targetYear = previousYear ? _selectedYear - 1 : _selectedYear;
    var total = 0.0;
    for (final t in _transactions) {
      final rawDate = t['date'];
      DateTime? date;
      if (rawDate is Timestamp) {
        date = rawDate.toDate();
      } else if (rawDate is DateTime) {
        date = rawDate;
      }
      if (date == null ||
          date.year != targetYear ||
          !months.contains(date.month)) {
        continue;
      }
      final type = (t['type'] ?? '').toString().trim().toLowerCase();
      if (type != 'income' && type != 'доход' && type != 'doxod') continue;
      final txSourceId =
          (t['sales_source_id'] ?? t['shop_id'] ?? '').toString().trim();
      final txSourceName =
          (t['sales_source_name'] ?? t['shop_name'] ?? '').toString().trim();
      final matches = sourceId.isNotEmpty
          ? txSourceId == sourceId
          : sourceName.isNotEmpty && txSourceName == sourceName;
      if (!matches) continue;
      total += _txAmount(t);
    }
    return total;
  }

  List<Map<String, dynamic>> _incomeStoresForGroup(
    Map<String, dynamic> group,
    List<Map<String, dynamic>> children,
  ) {
    final rows = children
        .where((c) =>
            _incomeSourceId(c).isNotEmpty || _incomeSourceName(c).isNotEmpty)
        .map((c) {
      final sourceId = _incomeSourceId(c);
      final sourceName = _incomeSourceName(c);
      return {
        'id': (c['id'] ?? '').toString(),
        'title': sourceName.isEmpty ? 'Без источника' : sourceName,
        'sales_source_id': sourceId,
        'sales_source_name': sourceName,
        'actual': _actualForStore(sourceId, sourceName),
        'actualPreviousYear':
            _actualForStore(sourceId, sourceName, previousYear: true),
      };
    }).toList();
    rows.sort((a, b) =>
        ((b['actual'] ?? 0) as double).compareTo((a['actual'] ?? 0) as double));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionsHelper.has('money.expense_categories')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: _budgetPageBackground,
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
                    color: const Color(0xFFC8A06A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.bar_chart_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Бюджет',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Управление бюджетом и статьями расходов',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showFillPlanDialog,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Заполнить План'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        FlutterFlowTheme.of(context).secondaryBackground,
                    foregroundColor: const Color(0xFFC8A06A),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFC8A06A)),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Заполнить бюджет'),
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
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                DropdownButton<int>(
                  value: _selectedYear,
                  items: List.generate(5, (i) {
                    final year = DateTime.now().year - 2 + i;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedYear = v);
                    _recomputeActual();
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<_BudgetDisplayMode>(
                  value: _budgetDisplayMode,
                  items: const [
                    DropdownMenuItem(
                      value: _BudgetDisplayMode.yearTotal,
                      child: Text('За год'),
                    ),
                    DropdownMenuItem(
                      value: _BudgetDisplayMode.byMonths,
                      child: Text('По месяцам'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _budgetDisplayMode = v);
                    _recomputeActual();
                  },
                ),
                if (_budgetDisplayMode == _BudgetDisplayMode.byMonths) ...[
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _rangeStartMonth,
                    items: List.generate(12, (i) {
                      final month = i + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text('От ${_monthLabel(month)}'),
                      );
                    }),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _rangeStartMonth = v;
                        if (_rangeEndMonth < _rangeStartMonth) {
                          _rangeEndMonth = _rangeStartMonth;
                        }
                      });
                      _recomputeActual();
                    },
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _rangeEndMonth,
                    items: List.generate(12, (i) {
                      final month = i + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text('До ${_monthLabel(month)}'),
                      );
                    }),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _rangeEndMonth = v;
                        if (_rangeStartMonth > _rangeEndMonth) {
                          _rangeStartMonth = _rangeEndMonth;
                        }
                      });
                      _recomputeActual();
                    },
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 820;
                final search = Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
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
                );
                final risk = _selectedBudgetNetProfit < 0
                    ? Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 18, color: Color(0xFFB91C1C)),
                            SizedBox(width: 8),
                            Text(
                              'Неоправданный риск',
                              style: TextStyle(
                                color: Color(0xFFB91C1C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink();
                final switcher = SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'table',
                      label: Text('Таблица'),
                      icon: Icon(Icons.table_rows_outlined, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'chart',
                      label: Text('График'),
                      icon: Icon(Icons.show_chart, size: 18),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (value) {
                    if (value.isEmpty) return;
                    setState(() => _viewMode = value.first);
                  },
                );

                if (compact) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: switcher,
                          )),
                          if (_selectedBudgetNetProfit < 0) ...[
                            const SizedBox(width: 8),
                            risk,
                          ],
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    if (_selectedBudgetNetProfit < 0) ...[
                      risk,
                      const SizedBox(width: 12),
                    ],
                    switcher,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _viewMode == 'chart'
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          _buildBudgetOverviewChart(),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          _buildBudgetMonthlyTable(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetMonthlyTable() {
    final points = _budgetChartPoints;
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: const Text('Недостаточно данных для таблицы по месяцам'),
      );
    }
    final months =
        _budgetChartMonths().map((date) => date.month).toList(growable: false);
    final incomeGroups = _tableGroupsByType('income');
    final allExpenseGroups = _tableGroupsByType('expense');
    final expenseGroups = allExpenseGroups
        .where(
            (group) => (group['title'] ?? '').toString().trim() != _taxesTitle)
        .toList(growable: false);
    final taxesGroup = allExpenseGroups.firstWhere(
      (group) => (group['title'] ?? '').toString().trim() == _taxesTitle,
      orElse: () => const <String, dynamic>{},
    );

    List<double> aggregateGroupPlanValues(List<Map<String, dynamic>> groups) {
      return months
          .map((month) => groups.fold<double>(
                0,
                (runningTotal, group) =>
                    runningTotal + _planForGroupMonth(group, month),
              ))
          .toList(growable: false);
    }

    List<double> aggregateGroupActualValues(List<Map<String, dynamic>> groups) {
      return months
          .map((month) => groups.fold<double>(
                0,
                (runningTotal, group) =>
                    runningTotal + _actualForGroupMonth(group, month),
              ))
          .toList(growable: false);
    }

    List<double> aggregateGroupPreviousYearValues(
        List<Map<String, dynamic>> groups) {
      return months
          .map((month) => groups.fold<double>(
                0,
                (runningTotal, group) =>
                    runningTotal +
                    _actualForGroupMonth(
                      group,
                      month,
                      true,
                    ),
              ))
          .toList(growable: false);
    }

    final incomeSummaryPlanValues = aggregateGroupPlanValues(incomeGroups);
    final incomeSummaryActualValues = months
        .map((month) => _systemActualForType('income', month: month))
        .toList(growable: false);
    final incomeSummaryPreviousYearValues = months
        .map((month) =>
            _systemActualForType('income', month: month, previousYear: true))
        .toList(growable: false);
    final expenseSummaryPlanValues = aggregateGroupPlanValues(expenseGroups);
    final expenseSummaryActualValues =
        aggregateGroupActualValues(expenseGroups);
    final expenseSummaryPreviousYearValues =
        aggregateGroupPreviousYearValues(expenseGroups);
    final taxesSummaryPlanValues = taxesGroup.isEmpty
        ? List<double>.filled(months.length, 0)
        : months
            .map((month) => _planForGroupMonth(taxesGroup, month))
            .toList(growable: false);
    final taxesSummaryActualValues = taxesGroup.isEmpty
        ? points.map((item) => item.taxes).toList(growable: false)
        : months
            .map((month) => _actualForGroupMonth(taxesGroup, month))
            .toList(growable: false);
    final taxesSummaryPreviousYearValues = taxesGroup.isEmpty
        ? List<double>.filled(months.length, 0)
        : months
            .map((month) => _actualForGroupMonth(
                  taxesGroup,
                  month,
                  true,
                ))
            .toList(growable: false);
    final netProfitSummaryPlanValues = List<double>.generate(
      months.length,
      (index) =>
          incomeSummaryPlanValues[index] -
          expenseSummaryPlanValues[index] -
          taxesSummaryPlanValues[index],
      growable: false,
    );
    final netProfitSummaryActualValues = List<double>.generate(
      months.length,
      (index) =>
          incomeSummaryActualValues[index] -
          expenseSummaryActualValues[index] -
          taxesSummaryActualValues[index],
      growable: false,
    );
    final netProfitSummaryPreviousYearValues = List<double>.generate(
      months.length,
      (index) =>
          incomeSummaryPreviousYearValues[index] -
          expenseSummaryPreviousYearValues[index] -
          taxesSummaryPreviousYearValues[index],
      growable: false,
    );
    late double titleColumnWidth;
    late double metricGroupWidth;
    late double metricValueWidth;
    const groupHeaderRowHeight = 36.0;
    const subHeaderRowHeight = 32.0;
    const dataRowHeight = 62.0;
    final previousYearFullLabel = 'Факт ${_selectedYear - 1} года';
    final visibleMetricColumnsCount = 2 +
        (_budgetDeviationExpanded ? 1 : 0) +
        (_budgetPreviousYearExpanded ? 1 : 0);

    String shortenTableHeader(String value) {
      return value.trim();
    }

    Widget monthCell(
      String text, {
      bool header = false,
      bool center = false,
      Color? color,
      double? width,
      FontWeight? fontWeight,
      double? height,
    }) {
      return Container(
        width: width ?? metricGroupWidth,
        height: height ?? (header ? groupHeaderRowHeight : dataRowHeight),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        alignment: center
            ? Alignment.center
            : (header ? Alignment.centerLeft : Alignment.centerRight),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: FlutterFlowTheme.of(context).alternate,
            ),
            bottom: BorderSide(
              color: FlutterFlowTheme.of(context).alternate,
            ),
          ),
        ),
        child: header
            ? Text(
                shortenTableHeader(text),
                maxLines: 2,
                overflow: TextOverflow.visible,
                textAlign: center ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: fontWeight ?? FontWeight.w700,
                  color: color ?? FlutterFlowTheme.of(context).primaryText,
                ),
              )
            : Text(
                text.trim(),
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: center ? TextAlign.center : TextAlign.right,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: fontWeight ?? FontWeight.w600,
                  color: color ?? FlutterFlowTheme.of(context).primaryText,
                ),
              ),
      );
    }

    Widget metricValueCell(
      double value, {
      required Color color,
      FontWeight? fontWeight,
      double? width,
    }) {
      return Container(
        width: width ?? metricValueWidth,
        height: dataRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: FlutterFlowTheme.of(context).alternate,
            ),
            bottom: BorderSide(
              color: FlutterFlowTheme.of(context).alternate,
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatBudgetTableValue(value),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: fontWeight ?? FontWeight.w600,
              color: color,
            ),
          ),
        ),
      );
    }

    List<Widget> metricCells(
      double plan,
      double fact, {
      double previousYear = 0,
      required Color baseColor,
      FontWeight? fontWeight,
      double? cellWidth,
    }) {
      final diff = plan - fact;
      final diffDisplay = fact > plan ? fact - plan : diff.abs();
      final diffColor = fact > plan
          ? _budgetIncomeColor
          : fact < plan
              ? _budgetExpenseColor
              : FlutterFlowTheme.of(context).secondaryText;
      final diffValue =
          fact == plan ? 0.0 : (fact > plan ? diffDisplay : -diffDisplay);
      final cells = <Widget>[
        metricValueCell(
          plan,
          color: baseColor,
          fontWeight: fontWeight,
          width: cellWidth,
        ),
        metricValueCell(
          fact,
          color: baseColor.withValues(alpha: 0.92),
          fontWeight: fontWeight,
          width: cellWidth,
        ),
      ];
      if (_budgetDeviationExpanded) {
        cells.add(
          metricValueCell(
            diffValue,
            color: diffColor,
            fontWeight: fontWeight,
            width: cellWidth,
          ),
        );
      }
      if (_budgetPreviousYearExpanded) {
        cells.add(
          metricValueCell(
            previousYear,
            color: FlutterFlowTheme.of(context).secondaryText,
            fontWeight: fontWeight,
            width: cellWidth,
          ),
        );
      }
      return cells;
    }

    Widget buildStaticRow(
      String label,
      List<double> planValues,
      List<double> actualValues,
      List<double> previousYearValues,
      Color color,
    ) {
      final totalPlan = planValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalActual = actualValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalPreviousYear = previousYearValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      return Row(
        children: [
          monthCell(
            label,
            header: true,
            color: color,
            width: titleColumnWidth,
            height: dataRowHeight,
          ),
          ...metricCells(
            totalPlan,
            totalActual,
            previousYear: totalPreviousYear,
            baseColor: color,
            fontWeight: FontWeight.w700,
          ),
          ...List.generate(
            planValues.length,
            (index) => Row(
              mainAxisSize: MainAxisSize.min,
              children: metricCells(
                planValues[index],
                actualValues[index],
                previousYear: previousYearValues[index],
                baseColor: color,
              ),
            ),
          ),
        ],
      );
    }

    Widget buildExpandableRow(
      String label,
      List<double> planValues,
      List<double> actualValues,
      List<double> previousYearValues,
      Color color, {
      required bool expanded,
      required VoidCallback onTap,
    }) {
      final totalPlan = planValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalActual = actualValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalPreviousYear = previousYearValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      return Row(
        children: [
          InkWell(
            onTap: onTap,
            child: Container(
              width: titleColumnWidth,
              height: dataRowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                  ),
                  bottom: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: color,
                  ),
                ],
              ),
            ),
          ),
          ...metricCells(
            totalPlan,
            totalActual,
            previousYear: totalPreviousYear,
            baseColor: color,
            fontWeight: FontWeight.w700,
          ),
          ...List.generate(
            planValues.length,
            (index) => Row(
              mainAxisSize: MainAxisSize.min,
              children: metricCells(
                planValues[index],
                actualValues[index],
                previousYear: previousYearValues[index],
                baseColor: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    Widget buildDetailRow(
      String label,
      List<double> planValues,
      List<double> actualValues, {
      List<double>? previousYearValues,
      required Color color,
      double indent = 0,
      FontWeight fontWeight = FontWeight.w500,
    }) {
      final totalPlan = planValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalActual = actualValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final resolvedPreviousYearValues =
          previousYearValues ?? List<double>.filled(planValues.length, 0);
      final totalPreviousYear = resolvedPreviousYearValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      return Row(
        children: [
          Container(
            width: titleColumnWidth,
            height: dataRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
                bottom: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: indent),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: fontWeight,
                  color: color,
                ),
              ),
            ),
          ),
          ...metricCells(
            totalPlan,
            totalActual,
            previousYear: totalPreviousYear,
            baseColor: color,
            fontWeight: fontWeight,
          ),
          ...List.generate(
            planValues.length,
            (index) => Row(
              mainAxisSize: MainAxisSize.min,
              children: metricCells(
                planValues[index],
                actualValues[index],
                previousYear: resolvedPreviousYearValues[index],
                baseColor: color,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ],
      );
    }

    Widget buildGroupTableRow(
      Map<String, dynamic> group,
      List<Map<String, dynamic>> children, {
      required Color color,
      required String fallbackLabel,
    }) {
      final groupId = (group['id'] ?? '').toString();
      final expanded = children.isNotEmpty && _isGroupExpanded(groupId);
      final planValues = months
          .map((month) => _planForGroupMonth(group, month))
          .toList(growable: false);
      final actualValues = months
          .map((month) => _actualForGroupMonth(group, month))
          .toList(growable: false);
      final previousYearValues = months
          .map((month) => _actualForGroupMonth(
                group,
                month,
                true,
              ))
          .toList(growable: false);
      final totalPlan = planValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalActual = actualValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalPreviousYear = previousYearValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final label = (group['type'] ?? '').toString() == 'expense'
          ? _expenseTableLabel(group)
          : (((group['title'] ?? '').toString().trim().isEmpty)
              ? fallbackLabel
              : (group['title'] ?? '').toString());

      return Column(
        children: [
          Row(
            children: [
              Container(
                width: titleColumnWidth,
                height: dataRowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    bottom: BorderSide(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (children.isNotEmpty)
                      InkWell(
                        onTap: () => _toggleGroupExpanded(groupId),
                        child: Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: color,
                        ),
                      )
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () async {
                        final persistedGroup =
                            await _ensurePersistedTableGroup(group);
                        if (!mounted) return;
                        _showAddDialog(
                          type:
                              (persistedGroup['type'] ?? 'expense').toString(),
                          parentId: (persistedGroup['id'] ?? '').toString(),
                        );
                      },
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              ...metricCells(
                totalPlan,
                totalActual,
                previousYear: totalPreviousYear,
                baseColor: color,
                fontWeight: FontWeight.w700,
              ),
              ...List.generate(
                planValues.length,
                (index) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: metricCells(
                    planValues[index],
                    actualValues[index],
                    previousYear: previousYearValues[index],
                    baseColor: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (expanded)
            ...children.map(
              (child) => buildDetailRow(
                (child['type'] ?? '').toString() == 'expense'
                    ? _expenseTableLabel(child)
                    : (((child['title'] ?? '').toString().trim().isEmpty)
                        ? 'Подстатья'
                        : (child['title'] ?? '').toString()),
                months.map((month) => _planFor(child, months: [month])).toList(
                      growable: false,
                    ),
                months
                    .map((month) => _actualForCategoryMonth(child, month))
                    .toList(growable: false),
                previousYearValues: months
                    .map((month) => _actualForCategoryMonth(
                          child,
                          month,
                          previousYear: true,
                        ))
                    .toList(growable: false),
                color: color.withValues(alpha: 0.92),
                indent: 18,
              ),
            ),
        ],
      );
    }

    Widget buildMetricsRowContent(
      List<double> planValues,
      List<double> actualValues, {
      required List<double> previousYearValues,
      required Color baseColor,
      FontWeight? fontWeight,
      required List<double> valueWidthsByGroup,
    }) {
      final totalPlan = planValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalActual = actualValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      final totalPreviousYear = previousYearValues.fold<double>(
          0, (runningTotal, value) => runningTotal + value);
      return Row(
        children: [
          ...metricCells(
            totalPlan,
            totalActual,
            previousYear: totalPreviousYear,
            baseColor: baseColor,
            fontWeight: fontWeight,
            cellWidth: valueWidthsByGroup[0],
          ),
          ...List.generate(
            planValues.length,
            (index) => Row(
              mainAxisSize: MainAxisSize.min,
              children: metricCells(
                planValues[index],
                actualValues[index],
                previousYear: previousYearValues[index],
                baseColor: baseColor,
                fontWeight: fontWeight,
                cellWidth: valueWidthsByGroup[index + 1],
              ),
            ),
          ),
        ],
      );
    }

    Widget stickyColumnCell({
      required double height,
      required Widget child,
      EdgeInsetsGeometry? padding,
    }) {
      return Container(
        width: titleColumnWidth,
        height: height,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: FlutterFlowTheme.of(context).alternate,
            ),
            bottom: BorderSide(
              color: FlutterFlowTheme.of(context).alternate,
            ),
          ),
        ),
        child: child,
      );
    }

    Widget buildStickyHeaderCell() {
      return stickyColumnCell(
        height: groupHeaderRowHeight + subHeaderRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          'Показатель',
          maxLines: 2,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
      );
    }

    Widget buildStickyStaticLeft(
      String label,
      Color color,
    ) {
      return stickyColumnCell(
        height: dataRowHeight,
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }

    Widget buildStickyExpandableLeft(
      String label,
      Color color, {
      required bool expanded,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        child: stickyColumnCell(
          height: dataRowHeight,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      );
    }

    Widget buildStickyDetailLeft(
      String label,
      Color color, {
      double indent = 0,
      FontWeight fontWeight = FontWeight.w500,
    }) {
      return stickyColumnCell(
        height: dataRowHeight,
        child: Padding(
          padding: EdgeInsets.only(left: indent),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: 11,
              fontWeight: fontWeight,
              color: color,
            ),
          ),
        ),
      );
    }

    Widget buildStickyGroupLeft(
      Map<String, dynamic> group,
      List<Map<String, dynamic>> children, {
      required Color color,
      required String fallbackLabel,
    }) {
      final groupId = (group['id'] ?? '').toString();
      final expanded = children.isNotEmpty && _isGroupExpanded(groupId);
      final label = (group['type'] ?? '').toString() == 'expense'
          ? _expenseTableLabel(group)
          : (((group['title'] ?? '').toString().trim().isEmpty)
              ? fallbackLabel
              : (group['title'] ?? '').toString());
      return stickyColumnCell(
        height: dataRowHeight,
        child: Row(
          children: [
            if (children.isNotEmpty)
              InkWell(
                onTap: () => _toggleGroupExpanded(groupId),
                child: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: color,
                ),
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () async {
                final persistedGroup = await _ensurePersistedTableGroup(group);
                if (!mounted) return;
                _showAddDialog(
                  type: (persistedGroup['type'] ?? 'expense').toString(),
                  parentId: (persistedGroup['id'] ?? '').toString(),
                );
              },
              icon: Icon(
                Icons.add_circle_outline_rounded,
                size: 18,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    void collectBudgetMetricValues(
      List<double> bucket,
      List<double> values,
    ) {
      final safeValues =
          values.where((value) => value.isFinite).toList(growable: false);
      bucket.addAll(safeValues);
      if (safeValues.isNotEmpty) {
        bucket.add(
          safeValues.fold<double>(
            0,
            (runningTotal, value) => runningTotal + value,
          ),
        );
      }
    }

    void collectBudgetMetricValuesByGroup(
      List<List<double>> buckets,
      List<double> planValues,
      List<double> actualValues,
      List<double> previousYearValues,
    ) {
      void addValues(
        int bucketIndex,
        double plan,
        double fact,
        double previousYear,
      ) {
        buckets[bucketIndex].add(plan);
        buckets[bucketIndex].add(fact);
        if (_budgetDeviationExpanded) {
          buckets[bucketIndex].add(fact - plan);
        }
        if (_budgetPreviousYearExpanded) {
          buckets[bucketIndex].add(previousYear);
        }
      }

      addValues(
        0,
        planValues.fold<double>(0, (sum, value) => sum + value),
        actualValues.fold<double>(0, (sum, value) => sum + value),
        previousYearValues.fold<double>(0, (sum, value) => sum + value),
      );

      for (var index = 0; index < planValues.length; index++) {
        addValues(
          index + 1,
          planValues[index],
          actualValues[index],
          previousYearValues[index],
        );
      }
    }

    double resolveBudgetMetricValueWidth(List<double> values) {
      final safeValues =
          values.where((value) => value.isFinite).toList(growable: false);
      if (safeValues.isEmpty ||
          safeValues.every((value) => value.abs() < 0.001)) {
        return 44.0;
      }
      final maxFormattedLength = safeValues
          .map((value) => _formatBudgetTableValue(value).length)
          .fold<int>(0,
              (maxLength, length) => length > maxLength ? length : maxLength);
      double width = 44.0;
      if (maxFormattedLength <= 1) {
        width = 44.0;
      } else if (maxFormattedLength <= 4) {
        width = 50.0;
      } else if (maxFormattedLength <= 6) {
        width = 58.0;
      } else if (maxFormattedLength <= 8) {
        width = 68.0;
      } else if (maxFormattedLength <= 10) {
        width = 78.0;
      } else if (maxFormattedLength <= 12) {
        width = 88.0;
      } else {
        width = 96.0;
      }
      return width;
    }

    Widget buildBudgetOptionalColumnToggle({
      required String label,
      required bool expanded,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: FlutterFlowTheme.of(context).alternate),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                expanded
                    ? Icons.remove_circle_outline_rounded
                    : Icons.add_circle_outline_rounded,
                size: 15,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableTableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 40;
        final metricValueBucketsByGroup =
            List.generate(months.length + 1, (_) => <double>[]);
        collectBudgetMetricValuesByGroup(
          metricValueBucketsByGroup,
          incomeSummaryPlanValues,
          incomeSummaryActualValues,
          incomeSummaryPreviousYearValues,
        );
        collectBudgetMetricValuesByGroup(
          metricValueBucketsByGroup,
          expenseSummaryPlanValues,
          expenseSummaryActualValues,
          expenseSummaryPreviousYearValues,
        );
        collectBudgetMetricValuesByGroup(
          metricValueBucketsByGroup,
          taxesSummaryPlanValues,
          taxesSummaryActualValues,
          taxesSummaryPreviousYearValues,
        );
        collectBudgetMetricValuesByGroup(
          metricValueBucketsByGroup,
          netProfitSummaryPlanValues,
          netProfitSummaryActualValues,
          netProfitSummaryPreviousYearValues,
        );
        for (final group in incomeGroups) {
          final groupPlanValues = months
              .map((month) => _planForGroupMonth(group, month))
              .toList(growable: false);
          final groupActualValues = months
              .map((month) => _actualForGroupMonth(group, month))
              .toList(growable: false);
          final groupPreviousYearValues = months
              .map((month) => _actualForGroupMonth(group, month, true))
              .toList(growable: false);
          collectBudgetMetricValuesByGroup(
            metricValueBucketsByGroup,
            groupPlanValues,
            groupActualValues,
            groupPreviousYearValues,
          );
          for (final child in _tableChildrenForGroup(group)) {
            collectBudgetMetricValuesByGroup(
              metricValueBucketsByGroup,
              months
                  .map((month) => _planFor(child, months: [month]))
                  .toList(growable: false),
              months
                  .map((month) => _actualForCategoryMonth(child, month))
                  .toList(growable: false),
              months
                  .map((month) => _actualForCategoryMonth(
                        child,
                        month,
                        previousYear: true,
                      ))
                  .toList(growable: false),
            );
          }
        }
        for (final group in expenseGroups) {
          final groupPlanValues = months
              .map((month) => _planForGroupMonth(group, month))
              .toList(growable: false);
          final groupActualValues = months
              .map((month) => _actualForGroupMonth(group, month))
              .toList(growable: false);
          final groupPreviousYearValues = months
              .map((month) => _actualForGroupMonth(group, month, true))
              .toList(growable: false);
          collectBudgetMetricValuesByGroup(
            metricValueBucketsByGroup,
            groupPlanValues,
            groupActualValues,
            groupPreviousYearValues,
          );
          for (final child in _tableChildrenForGroup(group)) {
            collectBudgetMetricValuesByGroup(
              metricValueBucketsByGroup,
              months
                  .map((month) => _planFor(child, months: [month]))
                  .toList(growable: false),
              months
                  .map((month) => _actualForCategoryMonth(child, month))
                  .toList(growable: false),
              months
                  .map((month) => _actualForCategoryMonth(
                        child,
                        month,
                        previousYear: true,
                      ))
                  .toList(growable: false),
            );
          }
        }
        titleColumnWidth = (availableTableWidth * 0.28).clamp(210.0, 300.0);
        final metricValueWidthsByGroup = metricValueBucketsByGroup
            .map(
              (values) => resolveBudgetMetricValueWidth(values),
            )
            .toList(growable: false);
        metricValueWidth = metricValueWidthsByGroup.isNotEmpty
            ? metricValueWidthsByGroup.first
            : 52.0;
        final metricGroupWidthsByGroup = metricValueWidthsByGroup
            .map((width) => width * visibleMetricColumnsCount)
            .toList(growable: false);
        metricGroupWidth = metricGroupWidthsByGroup.isNotEmpty
            ? metricGroupWidthsByGroup.first
            : metricValueWidth * visibleMetricColumnsCount;
        final metricsTableWidth = metricGroupWidthsByGroup.fold<double>(
          0,
          (sum, width) => sum + width,
        );
        final scrollAreaWidth = (availableTableWidth - titleColumnWidth) < 0
            ? 0.0
            : (availableTableWidth - titleColumnWidth);
        final hasHorizontalOverflow = metricsTableWidth > scrollAreaWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FlutterFlowTheme.of(context).alternate),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Таблица бюджета по месяцам',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hasHorizontalOverflow) ...[
                      IconButton(
                        onPressed: () => _scrollBudgetTableBy(-360),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Прокрутить влево',
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        onPressed: () => _scrollBudgetTableBy(360),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Прокрутить вправо',
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    buildBudgetOptionalColumnToggle(
                      label: _budgetDeviationExpanded
                          ? 'Скрыть отклонение'
                          : 'Отклонение',
                      expanded: _budgetDeviationExpanded,
                      onTap: () {
                        setState(() {
                          _budgetDeviationExpanded = !_budgetDeviationExpanded;
                        });
                      },
                    ),
                    buildBudgetOptionalColumnToggle(
                      label: _budgetPreviousYearExpanded
                          ? 'Скрыть ${previousYearFullLabel.toLowerCase()}'
                          : previousYearFullLabel,
                      expanded: _budgetPreviousYearExpanded,
                      onTap: () {
                        setState(() {
                          _budgetPreviousYearExpanded =
                              !_budgetPreviousYearExpanded;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Scrollbar(
                controller: _budgetTableScrollController,
                thumbVisibility: hasHorizontalOverflow,
                trackVisibility: hasHorizontalOverflow,
                interactive: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: titleColumnWidth,
                      child: Column(
                        children: [
                          buildStickyHeaderCell(),
                          buildStickyExpandableLeft(
                            'Доходы',
                            _budgetIncomeColor,
                            expanded: _incomeExpanded,
                            onTap: () {
                              setState(
                                  () => _incomeExpanded = !_incomeExpanded);
                            },
                          ),
                          if (_incomeExpanded) ...[
                            ...incomeGroups.expand((group) {
                              final children = _tableChildrenForGroup(group);
                              return <Widget>[
                                buildStickyGroupLeft(
                                  group,
                                  children,
                                  color: _budgetIncomeDetailColor,
                                  fallbackLabel: 'Доходы',
                                ),
                                if (children.isNotEmpty &&
                                    _isGroupExpanded(
                                        (group['id'] ?? '').toString()))
                                  ...children.map(
                                    (child) => buildStickyDetailLeft(
                                      (child['type'] ?? '').toString() ==
                                              'expense'
                                          ? _expenseTableLabel(child)
                                          : (((child['title'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isEmpty)
                                              ? 'Подстатья'
                                              : (child['title'] ?? '')
                                                  .toString()),
                                      _budgetIncomeDetailColor.withValues(
                                          alpha: 0.92),
                                      indent: 18,
                                    ),
                                  ),
                              ];
                            }),
                          ],
                          buildStickyExpandableLeft(
                            'Расходы',
                            _budgetExpenseColor,
                            expanded: _expenseExpanded,
                            onTap: () {
                              setState(
                                  () => _expenseExpanded = !_expenseExpanded);
                            },
                          ),
                          if (_expenseExpanded) ...[
                            ...expenseGroups.expand((group) {
                              final children = _tableChildrenForGroup(group);
                              return <Widget>[
                                buildStickyGroupLeft(
                                  group,
                                  children,
                                  color: _budgetExpenseDetailColor,
                                  fallbackLabel: 'Расходы',
                                ),
                                if (children.isNotEmpty &&
                                    _isGroupExpanded(
                                        (group['id'] ?? '').toString()))
                                  ...children.map(
                                    (child) => buildStickyDetailLeft(
                                      (child['type'] ?? '').toString() ==
                                              'expense'
                                          ? _expenseTableLabel(child)
                                          : (((child['title'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isEmpty)
                                              ? 'Подстатья'
                                              : (child['title'] ?? '')
                                                  .toString()),
                                      _budgetExpenseDetailColor.withValues(
                                          alpha: 0.92),
                                      indent: 18,
                                    ),
                                  ),
                              ];
                            }),
                          ],
                          buildStickyStaticLeft(
                            'Налоги',
                            _budgetTaxesColor,
                          ),
                          buildStickyStaticLeft(
                            'Чистая прибыль',
                            _budgetProfitColor,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _budgetTableScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: metricsTableWidth,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  monthCell(
                                    'Итого',
                                    header: true,
                                    center: true,
                                    width: metricGroupWidthsByGroup[0],
                                  ),
                                  ...List.generate(
                                    points.length,
                                    (index) => monthCell(
                                      points[index].label,
                                      header: true,
                                      center: true,
                                      width:
                                          metricGroupWidthsByGroup[index + 1],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: List.generate(
                                  months.length + 1,
                                  (groupIndex) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      monthCell(
                                        'План',
                                        header: true,
                                        center: true,
                                        width: metricValueWidthsByGroup[
                                            groupIndex],
                                        height: subHeaderRowHeight,
                                      ),
                                      monthCell(
                                        'Факт',
                                        header: true,
                                        center: true,
                                        width: metricValueWidthsByGroup[
                                            groupIndex],
                                        height: subHeaderRowHeight,
                                      ),
                                      if (_budgetDeviationExpanded)
                                        monthCell(
                                          'Отклонение',
                                          header: true,
                                          center: true,
                                          width: metricValueWidthsByGroup[
                                              groupIndex],
                                          height: subHeaderRowHeight,
                                        ),
                                      if (_budgetPreviousYearExpanded)
                                        monthCell(
                                          previousYearFullLabel,
                                          header: true,
                                          center: true,
                                          width: metricValueWidthsByGroup[
                                              groupIndex],
                                          height: subHeaderRowHeight,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              buildMetricsRowContent(
                                incomeSummaryPlanValues,
                                incomeSummaryActualValues,
                                previousYearValues:
                                    incomeSummaryPreviousYearValues,
                                baseColor: _budgetIncomeColor,
                                fontWeight: FontWeight.w700,
                                valueWidthsByGroup: metricValueWidthsByGroup,
                              ),
                              if (_incomeExpanded) ...[
                                ...incomeGroups.expand((group) {
                                  final children =
                                      _tableChildrenForGroup(group);
                                  final groupPlanValues = months
                                      .map((month) =>
                                          _planForGroupMonth(group, month))
                                      .toList(growable: false);
                                  final groupActualValues = months
                                      .map((month) =>
                                          _actualForGroupMonth(group, month))
                                      .toList(growable: false);
                                  final groupPreviousYearValues = months
                                      .map((month) => _actualForGroupMonth(
                                            group,
                                            month,
                                            true,
                                          ))
                                      .toList(growable: false);
                                  return <Widget>[
                                    buildMetricsRowContent(
                                      groupPlanValues,
                                      groupActualValues,
                                      previousYearValues:
                                          groupPreviousYearValues,
                                      baseColor: _budgetIncomeDetailColor,
                                      fontWeight: FontWeight.w700,
                                      valueWidthsByGroup:
                                          metricValueWidthsByGroup,
                                    ),
                                    if (children.isNotEmpty &&
                                        _isGroupExpanded(
                                            (group['id'] ?? '').toString()))
                                      ...children.map(
                                        (child) => buildMetricsRowContent(
                                          months
                                              .map((month) => _planFor(
                                                    child,
                                                    months: [month],
                                                  ))
                                              .toList(growable: false),
                                          months
                                              .map((month) =>
                                                  _actualForCategoryMonth(
                                                    child,
                                                    month,
                                                  ))
                                              .toList(growable: false),
                                          previousYearValues: months
                                              .map((month) =>
                                                  _actualForCategoryMonth(
                                                    child,
                                                    month,
                                                    previousYear: true,
                                                  ))
                                              .toList(growable: false),
                                          baseColor: _budgetIncomeDetailColor
                                              .withValues(alpha: 0.92),
                                          valueWidthsByGroup:
                                              metricValueWidthsByGroup,
                                        ),
                                      ),
                                  ];
                                }),
                              ],
                              buildMetricsRowContent(
                                expenseSummaryPlanValues,
                                expenseSummaryActualValues,
                                previousYearValues:
                                    expenseSummaryPreviousYearValues,
                                baseColor: _budgetExpenseColor,
                                fontWeight: FontWeight.w700,
                                valueWidthsByGroup: metricValueWidthsByGroup,
                              ),
                              if (_expenseExpanded) ...[
                                ...expenseGroups.expand((group) {
                                  final children =
                                      _tableChildrenForGroup(group);
                                  final groupPlanValues = months
                                      .map((month) =>
                                          _planForGroupMonth(group, month))
                                      .toList(growable: false);
                                  final groupActualValues = months
                                      .map((month) =>
                                          _actualForGroupMonth(group, month))
                                      .toList(growable: false);
                                  final groupPreviousYearValues = months
                                      .map((month) => _actualForGroupMonth(
                                            group,
                                            month,
                                            true,
                                          ))
                                      .toList(growable: false);
                                  return <Widget>[
                                    buildMetricsRowContent(
                                      groupPlanValues,
                                      groupActualValues,
                                      previousYearValues:
                                          groupPreviousYearValues,
                                      baseColor: _budgetExpenseDetailColor,
                                      fontWeight: FontWeight.w700,
                                      valueWidthsByGroup:
                                          metricValueWidthsByGroup,
                                    ),
                                    if (children.isNotEmpty &&
                                        _isGroupExpanded(
                                            (group['id'] ?? '').toString()))
                                      ...children.map(
                                        (child) => buildMetricsRowContent(
                                          months
                                              .map((month) => _planFor(
                                                    child,
                                                    months: [month],
                                                  ))
                                              .toList(growable: false),
                                          months
                                              .map((month) =>
                                                  _actualForCategoryMonth(
                                                    child,
                                                    month,
                                                  ))
                                              .toList(growable: false),
                                          previousYearValues: months
                                              .map((month) =>
                                                  _actualForCategoryMonth(
                                                    child,
                                                    month,
                                                    previousYear: true,
                                                  ))
                                              .toList(growable: false),
                                          baseColor: _budgetExpenseDetailColor
                                              .withValues(alpha: 0.92),
                                          valueWidthsByGroup:
                                              metricValueWidthsByGroup,
                                        ),
                                      ),
                                  ];
                                }),
                              ],
                              buildMetricsRowContent(
                                taxesSummaryPlanValues,
                                taxesSummaryActualValues,
                                previousYearValues:
                                    taxesSummaryPreviousYearValues,
                                baseColor: _budgetTaxesColor,
                                fontWeight: FontWeight.w700,
                                valueWidthsByGroup: metricValueWidthsByGroup,
                              ),
                              buildMetricsRowContent(
                                netProfitSummaryPlanValues,
                                netProfitSummaryActualValues,
                                previousYearValues:
                                    netProfitSummaryPreviousYearValues,
                                baseColor: _budgetProfitColor,
                                fontWeight: FontWeight.w700,
                                valueWidthsByGroup: metricValueWidthsByGroup,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasHorizontalOverflow)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Text(
                    'Левая колонка зафиксирована, прокрутка работает только для месячных столбцов.',
                    style: TextStyle(
                      fontSize: 11,
                      color: FlutterFlowTheme.of(context).secondaryText,
                      height: 1.3,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Text(
                  'План и Факт показаны сразу. Отклонение и Факт прошлого года раскрываются по кнопкам выше.',
                  style: TextStyle(
                    fontSize: 11,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetOverviewChart() {
    final points = _budgetChartPoints;
    List<double> sanitizedValues(Iterable<double> values) {
      return values
          .map((value) => value.isFinite ? value : 0.0)
          .toList(growable: false);
    }

    final allSeries = <_BudgetLineSeries>[
      _BudgetLineSeries(
        'Доходы План',
        _budgetIncomeColor,
        sanitizedValues(points.map((item) => item.income)),
      ),
      _BudgetLineSeries(
        'Доходы Факт',
        _budgetIncomeDetailColor,
        sanitizedValues(points.map((item) => item.incomeFact)),
      ),
      _BudgetLineSeries(
        'Доходы Факт прошлого года',
        _budgetIncomeColor.withValues(alpha: 0.72),
        sanitizedValues(points.map((item) => item.incomePreviousYear)),
      ),
      _BudgetLineSeries(
        'Расходы План',
        _budgetExpenseColor,
        sanitizedValues(points.map((item) => item.expense)),
      ),
      _BudgetLineSeries(
        'Расходы Факт',
        _budgetExpenseDetailColor,
        sanitizedValues(points.map((item) => item.expenseFact)),
      ),
      _BudgetLineSeries(
        'Расходы Факт прошлого года',
        _budgetExpenseColor.withValues(alpha: 0.72),
        sanitizedValues(points.map((item) => item.expensePreviousYear)),
      ),
      _BudgetLineSeries(
        'Налоги',
        _budgetTaxesColor,
        sanitizedValues(points.map((item) => item.taxes)),
      ),
      _BudgetLineSeries(
        'Чистая прибыль',
        _budgetProfitColor,
        sanitizedValues(points.map((item) => item.netProfit)),
      ),
    ];
    final series = allSeries
        .where((item) => _enabledChartSeries.contains(item.name))
        .toList(growable: false);
    final scaleMin = _budgetChartScaleMin(points, series);
    final scaleMax = _budgetChartScaleMax(points, series);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'График бюджета',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (points.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: Text('Недостаточно данных для графика')),
            )
          else ...[
            if (series.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: Text('Включите хотя бы один показатель')),
              )
            else
              SizedBox(
                height: 230,
                width: double.infinity,
                child: CustomPaint(
                  painter: _BudgetLineChartPainter(
                    series: series,
                    labels: points
                        .map((item) => item.label)
                        .toList(growable: false),
                    minValue: scaleMin,
                    maxValue: scaleMax,
                    axisColor: FlutterFlowTheme.of(context).alternate,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: allSeries.map(
                  (item) {
                    final enabled = _enabledChartSeries.contains(item.name);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          setState(() {
                            if (enabled) {
                              _enabledChartSeries.remove(item.name);
                            } else {
                              _enabledChartSeries.add(item.name);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .primaryBackground
                                .withValues(alpha: enabled ? 1 : 0.58),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: enabled
                                  ? item.color
                                  : FlutterFlowTheme.of(context).alternate,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: enabled
                                      ? item.color
                                      : item.color.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: enabled
                                      ? FlutterFlowTheme.of(context).primaryText
                                      : FlutterFlowTheme.of(context)
                                          .secondaryText,
                                  decoration: enabled
                                      ? TextDecoration.none
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _budgetChartScaleMax(
    List<_BudgetChartPoint> points,
    List<_BudgetLineSeries> series,
  ) {
    final values = <double>[
      for (final item in series) ...item.values,
    ]..removeWhere((value) => !value.isFinite);
    if (values.isEmpty) {
      return 1;
    }
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final range = (rawMax - rawMin).abs();
    final padding = range > 0 ? range * 0.12 : rawMax.abs() * 0.12 + 1;
    if (rawMax <= 0) {
      return padding;
    }
    return rawMax + padding;
  }

  double _budgetChartScaleMin(
    List<_BudgetChartPoint> points,
    List<_BudgetLineSeries> series,
  ) {
    final values = <double>[
      for (final item in series) ...item.values,
    ]..removeWhere((value) => !value.isFinite);
    if (values.isEmpty) {
      return 0;
    }
    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    final range = (rawMax - rawMin).abs();
    final padding = range > 0 ? range * 0.12 : rawMax.abs() * 0.12 + 1;
    if (rawMin >= 0) {
      final dynamicMin = rawMin - padding;
      return dynamicMin < 0 ? 0 : dynamicMin;
    }
    return rawMin - padding;
  }

  Widget _buildTypeSection(String type, String title, Color tint) {
    final groups = _groupsByType(type);
    final isExpanded = type == 'income' ? _incomeExpanded : _expenseExpanded;
    final totalPlan = _totalPlanForType(type);
    final totalActual = _totalActualForType(type);
    final totalActualPreviousYear =
        _totalActualForType(type, previousYear: true);
    final totalDiff = totalPlan - totalActual;
    if (groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Text('Нет категорий',
            style:
                TextStyle(color: FlutterFlowTheme.of(context).secondaryText)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tint.withValues(alpha: 0.22),
          FlutterFlowTheme.of(context).secondaryBackground,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.alphaBlend(
            tint.withValues(alpha: 0.65),
            FlutterFlowTheme.of(context).alternate,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                if (type == 'income') {
                  _incomeExpanded = !_incomeExpanded;
                } else {
                  _expenseExpanded = !_expenseExpanded;
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1150;
                  final titleSurface = Color.alphaBlend(
                    tint.withValues(alpha: 0.32),
                    FlutterFlowTheme.of(context).secondaryBackground,
                  );
                  final titleBlock = Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          type == 'income'
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: _isDarkBudgetTheme
                              ? FlutterFlowTheme.of(context).primaryBackground
                              : const Color(0xFF1F2A37),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                      ),
                    ],
                  );

                  final metricsBlock = Wrap(
                    alignment:
                        compact ? WrapAlignment.start : WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _budgetMetricChip('Статей', '${groups.length}'),
                      _budgetMetricChip(
                          'Факт 25', _formatBudgetMoney(totalPlan)),
                      _budgetMetricChip(
                          'Факт', _formatBudgetMoney(totalActual)),
                      _budgetMetricChip(
                        'Откл.',
                        _formatBudgetMoney(totalDiff),
                        color: totalDiff >= 0
                            ? FlutterFlowTheme.of(context).success
                            : const Color(0xFFE13B3B),
                      ),
                      _budgetMetricChip(
                        _previousYearFactLabel(),
                        _formatBudgetMoney(totalActualPreviousYear),
                      ),
                    ],
                  );

                  final expandIcon = Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  );

                  if (compact) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: titleSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tint.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: titleBlock),
                              const SizedBox(width: 8),
                              expandIcon,
                            ],
                          ),
                          const SizedBox(height: 10),
                          metricsBlock,
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: titleSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: tint.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 4, child: titleBlock),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 740,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: metricsBlock,
                          ),
                        ),
                        const SizedBox(width: 8),
                        expandIcon,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groups.map((g) {
                  final children = _childrenFor(g['id']?.toString() ?? '');
                  return _buildGroupCard(g, children, tint);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    Map<String, dynamic> group,
    List<Map<String, dynamic>> children,
    Color tint,
  ) {
    final title = (group['title'] ?? '').toString();
    final hasChildren = children.isNotEmpty;
    final isIncome = (group['type'] ?? 'expense').toString() == 'income';
    final incomeStores = isIncome
        ? _incomeStoresForGroup(group, children)
        : const <Map<String, dynamic>>[];
    final hasExpandableContent =
        isIncome ? incomeStores.isNotEmpty : hasChildren;
    final groupId = (group['id'] ?? '').toString();
    final expanded = hasExpandableContent &&
        (_groupExpanded.containsKey(groupId)
            ? _isGroupExpanded(groupId)
            : (isIncome && incomeStores.isNotEmpty));
    final plan = hasChildren
        ? children.fold<double>(0, (s, c) => s + _planFor(c))
        : _planFor(group);
    final actual = isIncome
        ? incomeStores.fold<double>(
            0, (s, row) => s + ((row['actual'] ?? 0) as double))
        : hasChildren
            ? children.fold<double>(0, (s, c) => s + _actualFor(c))
            : _actualFor(group);
    final actualPreviousYear = isIncome
        ? incomeStores.fold<double>(
            0, (s, row) => s + ((row['actualPreviousYear'] ?? 0) as double))
        : hasChildren
            ? children.fold<double>(
                0, (s, c) => s + _actualFor(c, previousYear: true))
            : _actualFor(group, previousYear: true);
    final diff = plan - actual;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 960;
              final titleBlock = InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: hasExpandableContent
                    ? () => _toggleGroupExpanded(groupId)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.folder_open,
                          size: 16,
                          color: _isDarkBudgetTheme
                              ? FlutterFlowTheme.of(context).primaryBackground
                              : const Color(0xFF1F2A37),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? 'Категория' : title,
                              maxLines: compact ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                            if (!isIncome) ...[
                              const SizedBox(height: 4),
                              _periodicityBadge(_categoryPeriodicity(group)),
                            ],
                          ],
                        ),
                      ),
                      if (hasExpandableContent) ...[
                        const SizedBox(width: 6),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ],
                    ],
                  ),
                ),
              );

              final metricsBlock = Wrap(
                alignment: compact ? WrapAlignment.start : WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _budgetMetricChip('Факт 25', _formatBudgetMoney(plan)),
                  _budgetMetricChip('Факт', _formatBudgetMoney(actual)),
                  _budgetMetricChip(
                    'Откл.',
                    _formatBudgetMoney(diff),
                    color: diff >= 0
                        ? FlutterFlowTheme.of(context).success
                        : const Color(0xFFE13B3B),
                  ),
                  _budgetMetricChip(_previousYearFactLabel(),
                      _formatBudgetMoney(actualPreviousYear)),
                ],
              );

              final actionsBlock = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (EditingHelper.canEditExisting(
                      section: EditSection.budget))
                    IconButton(
                      onPressed: () => _editCategory(group),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.edit, size: 18),
                    ),
                  TextButton(
                    onPressed: () {
                      if (isIncome) {
                        _showAttachShopDialog(group);
                        return;
                      }
                      _showAddDialog(
                        type: (group['type'] ?? 'expense').toString(),
                        parentId: group['id']?.toString(),
                      );
                    },
                    style: _budgetActionStyle(),
                    child: Text(isIncome ? 'Источник продаж' : 'Добавить'),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 10),
                    metricsBlock,
                    const SizedBox(height: 6),
                    actionsBlock,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: titleBlock),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: metricsBlock,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: actionsBlock,
                    ),
                  ),
                ],
              );
            },
          ),
          if (expanded && !isIncome && children.isNotEmpty) ...[
            const Divider(height: 12),
            ...children.map((c) => _buildSubRow(c)),
          ],
          if (expanded && isIncome && incomeStores.isNotEmpty) ...[
            const Divider(height: 12),
            ...incomeStores.map(_buildIncomeStoreRow),
          ],
        ],
      ),
    );
  }

  Widget _buildSubRow(Map<String, dynamic> c) {
    final title = (c['title'] ?? '').toString();
    final plan = _planFor(c);
    final actual = _actualFor(c);
    final actualPreviousYear = _actualFor(c, previousYear: true);
    final diff = plan - actual;
    final periodicity = _categoryPeriodicity(c);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? 'Подкатегория' : title,
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: const TextStyle(height: 1.25),
              ),
              const SizedBox(height: 4),
              _periodicityBadge(periodicity),
            ],
          );
          final metricsBlock = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _budgetMetricChip('Факт 25', _formatBudgetMoney(plan)),
              _budgetMetricChip('Факт', _formatBudgetMoney(actual)),
              _budgetMetricChip(
                'Откл.',
                _formatBudgetMoney(diff),
                color: diff >= 0
                    ? FlutterFlowTheme.of(context).success
                    : const Color(0xFFE13B3B),
              ),
              _budgetMetricChip(
                _previousYearFactLabel(),
                _formatBudgetMoney(actualPreviousYear),
              ),
            ],
          );
          final actionsBlock = Wrap(
            spacing: 2,
            children: [
              if (EditingHelper.canEditExisting(section: EditSection.budget))
                IconButton(
                  onPressed: () => _editCategory(c),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(Icons.edit, size: 16),
                ),
              if (EditingHelper.canEditExisting(section: EditSection.budget))
                IconButton(
                  onPressed: () => _deleteCategory(c['id']),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Color(0xFFE13B3B),
                  ),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 8),
                metricsBlock,
                if (EditingHelper.canEditExisting(
                    section: EditSection.budget)) ...[
                  const SizedBox(height: 4),
                  actionsBlock,
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: titleBlock),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: metricsBlock,
                ),
              ),
              if (EditingHelper.canEditExisting(
                  section: EditSection.budget)) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actionsBlock,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _budgetMetricChip(String label, String value, {Color? color}) {
    final theme = FlutterFlowTheme.of(context);
    final chipFill = Color.alphaBlend(
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.02)
          : Colors.black.withValues(alpha: 0.015),
      theme.secondaryBackground,
    );
    final chipBorder = Theme.of(context).brightness == Brightness.dark
        ? theme.alternate.withValues(alpha: 0.8)
        : theme.alternate;
    final labelColor = Theme.of(context).brightness == Brightness.dark
        ? theme.primaryText.withValues(alpha: 0.78)
        : theme.secondaryText;
    final valueColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? theme.primaryText
            : const Color(0xFF1F2A37));
    return Container(
      constraints: const BoxConstraints(minWidth: 112, maxWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chipBorder),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 11,
                color: labelColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodicityBadge(String label) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isDarkBudgetTheme
            ? theme.secondaryBackground
            : const Color(0xFFF4EFE7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _isDarkBudgetTheme ? theme.alternate : const Color(0xFFE7D9C5),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color:
              _isDarkBudgetTheme ? theme.primaryText : const Color(0xFF8A6331),
        ),
      ),
    );
  }

  ButtonStyle _budgetActionStyle() {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton.styleFrom(
      minimumSize: const Size(112, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark
              ? theme.primary.withValues(alpha: 0.45)
              : const Color(0xFFD7E7FB),
        ),
      ),
      foregroundColor: isDark ? theme.primary : const Color(0xFF1D8BFF),
      backgroundColor: isDark
          ? Color.alphaBlend(
              theme.primary.withValues(alpha: 0.10),
              theme.secondaryBackground,
            )
          : const Color(0xFFF7FBFF),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildIncomeStoreRow(Map<String, dynamic> row) {
    final title = (row['title'] ?? '').toString();
    final actual = (row['actual'] ?? 0).toDouble();
    final actualPreviousYear = (row['actualPreviousYear'] ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final titleBlock = Text(
            title.isEmpty ? 'Источник продаж' : title,
            softWrap: true,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.25),
          );
          final metricsBlock = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _budgetMetricChip(
                'Факт',
                _formatBudgetMoney(actual),
                color: FlutterFlowTheme.of(context).success,
              ),
              _budgetMetricChip(
                _previousYearFactLabel(),
                _formatBudgetMoney(actualPreviousYear),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 8),
                metricsBlock,
                if (EditingHelper.canEditExisting(section: EditSection.budget))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => _detachShop(row['id']?.toString() ?? ''),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(
                        Icons.link_off_rounded,
                        size: 16,
                        color: Color(0xFFE13B3B),
                      ),
                    ),
                  ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: titleBlock),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: metricsBlock,
                ),
              ),
              if (EditingHelper.canEditExisting(section: EditSection.budget))
                SizedBox(
                  width: 72,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => _detachShop(row['id']?.toString() ?? ''),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(
                        Icons.link_off_rounded,
                        size: 16,
                        color: Color(0xFFE13B3B),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _planForMonth(Map<String, dynamic> item, int year, int month) {
    return _planValueForMonth(item['planByYear'], year, month);
  }

  double _availablePlanForParent(
    String parentId, {
    String? excludeId,
  }) {
    final parent = _categories.firstWhere(
      (c) => (c['id'] ?? '').toString() == parentId,
      orElse: () => const <String, dynamic>{},
    );
    if (parent.isEmpty) return 0;
    final parentPlan = _planForMonth(parent, _selectedYear, _selectedMonth);
    final allocated = _childrenFor(parentId).fold<double>(0, (total, child) {
      final childId = (child['id'] ?? '').toString();
      if (excludeId != null && childId == excludeId) return total;
      return total + _planForMonth(child, _selectedYear, _selectedMonth);
    });
    final available = parentPlan - allocated;
    return available < 0 ? 0 : available;
  }

  Map<int, double> _availablePlanForParentByMonth(
    String parentId, {
    String? excludeId,
  }) {
    final parent = _categories.firstWhere(
      (c) => (c['id'] ?? '').toString() == parentId,
      orElse: () => const <String, dynamic>{},
    );
    final available = <int, double>{
      for (var month = 1; month <= 12; month++) month: 0
    };
    if (parent.isEmpty) {
      return available;
    }
    for (var month = 1; month <= 12; month++) {
      final parentPlan = _planFor(parent, months: [month]);
      final allocated = _childrenFor(parentId).fold<double>(0, (total, child) {
        final childId = (child['id'] ?? '').toString();
        if (excludeId != null && childId == excludeId) return total;
        return total + _planFor(child, months: [month]);
      });
      final remainder = parentPlan - allocated;
      available[month] = remainder < 0 ? 0 : remainder;
    }
    return available;
  }

  Future<void> _showFillPlanDialog() async {
    final incomeGroups = _tableGroupsByType('income');
    final expenseGroups = _tableGroupsByType('expense');
    await showDialog(
      context: context,
      builder: (context) => BudgetPlanDialog(
        selectedYear: _selectedYear,
        incomeGroups: incomeGroups,
        expenseGroups: expenseGroups,
        onSaved: _loadCategories,
        ensureGroup: _ensurePersistedTableGroup,
      ),
    );
  }

  Future<void> _showAddDialog({String? type, String? parentId}) async {
    final groups = _categories.where((c) => c['is_group'] == true).toList();
    showDialog(
      context: context,
      builder: (context) => AddExpenseCategoryDialog(
        onAdded: _loadCategories,
        groups: groups,
        defaultType: type,
        defaultParentId: parentId,
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        maxExpensePlan: type == 'expense' && (parentId ?? '').trim().isNotEmpty
            ? _availablePlanForParent(parentId!.trim())
            : null,
        maxExpensePlanByMonth:
            type == 'expense' && (parentId ?? '').trim().isNotEmpty
                ? _availablePlanForParentByMonth(parentId!.trim())
                : null,
      ),
    );
  }

  Widget _buildProjectsBand() {
    final projects = _budgetProjects
        .where((project) => (project['title'] ?? project['name'] ?? '')
            .toString()
            .trim()
            .isNotEmpty)
        .toList()
      ..sort((a, b) => (a['title'] ?? a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['title'] ?? b['name'] ?? '').toString().toLowerCase()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work_outline_rounded,
                    size: 18,
                    color: FlutterFlowTheme.of(context).secondaryText),
                const SizedBox(width: 8),
                Text(
                  'Проекты',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAddProjectDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Проект'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (projects.isEmpty)
              Text(
                'Проекты пока не добавлены.',
                style: TextStyle(
                    color: FlutterFlowTheme.of(context).secondaryText),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: projects.map((project) {
                  final title =
                      (project['title'] ?? project['name'] ?? '').toString();
                  final status = (project['status'] ?? 'Активен').toString();
                  return Chip(
                    label: Text('$title · $status'),
                    backgroundColor:
                        FlutterFlowTheme.of(context).primaryBackground,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddProjectDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый проект'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название проекта',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();
    if (saved != true || title.isEmpty) return;
    final companyId = _effectiveCompanyId();
    await _firestore.collection('budget_projects').add({
      'idCompany': companyId,
      'title': title,
      'description': description,
      'status': 'Активен',
      'created_by': _auth.currentUser?.uid ?? '',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    if (companyId.isNotEmpty) {
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('budget_projects', companyId);
    }
    await _loadCategories();
  }

  Future<void> _detachShop(String id) async {
    if (id.trim().isEmpty) return;
    await _firestore.collection('statRashod').doc(id).delete();
    final companyId = _effectiveCompanyId();
    if (companyId.isNotEmpty) {
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('statRashod', companyId);
    }
    await _loadCategories();
  }

  Future<void> _showAttachShopDialog(Map<String, dynamic> group) async {
    final groupId = (group['id'] ?? '').toString().trim();
    final type = (group['type'] ?? '').toString().trim();
    if (groupId.isEmpty || type != 'income') return;

    String? selectedShopId;
    final amountController = TextEditingController();
    final maxIncomePlan = _availablePlanForParent(groupId);

    await showDialog(
      context: context,
      builder: (context) {
        final options = _shops
            .where((shop) => (shop['id'] ?? '').toString().trim().isNotEmpty)
            .toList()
          ..sort((a, b) => (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString()));
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                  'Привязать источник продаж: ${(group['title'] ?? '').toString()}'),
              content: options.isEmpty
                  ? const Text('Нет источников продаж для привязки.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedShopId,
                          decoration: const InputDecoration(
                            labelText: 'Источник продаж',
                            border: OutlineInputBorder(),
                          ),
                          items: options
                              .map((shop) => DropdownMenuItem<String>(
                                    value: (shop['id'] ?? '').toString(),
                                    child: Text((shop['name'] ?? 'Без названия')
                                        .toString()),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setModalState(() => selectedShopId = value),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText:
                                'План дохода по источнику (до ${_formatBudgetMoney(maxIncomePlan)})',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: options.isEmpty || selectedShopId == null
                      ? null
                      : () async {
                          final plannedAmount = double.tryParse(
                                amountController.text
                                    .trim()
                                    .replaceAll(',', '.'),
                              ) ??
                              0;
                          if (plannedAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Укажите План дохода по источнику.'),
                              ),
                            );
                            return;
                          }
                          if (plannedAmount > maxIncomePlan) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'План источника не может быть больше остатка по статье: ${_formatBudgetMoney(maxIncomePlan)}',
                                ),
                              ),
                            );
                            return;
                          }
                          final companyId = _effectiveCompanyId();
                          final user = _auth.currentUser;
                          final selectedShop = options.firstWhere(
                            (shop) =>
                                (shop['id'] ?? '').toString() == selectedShopId,
                          );
                          final shopId =
                              (selectedShop['id'] ?? '').toString().trim();
                          final shopName =
                              (selectedShop['name'] ?? 'Без названия')
                                  .toString()
                                  .trim();
                          final planByYear = <String, dynamic>{
                            _selectedYear.toString(): <String, dynamic>{
                              _selectedMonth.toString(): plannedAmount,
                            },
                          };

                          final alreadyLinked = _categories.firstWhere(
                            (c) =>
                                (c['type'] ?? '').toString() == 'income' &&
                                (c['is_group'] == false) &&
                                _incomeSourceId(c) == shopId,
                            orElse: () => const <String, dynamic>{},
                          );

                          if (alreadyLinked.isNotEmpty) {
                            await _firestore
                                .collection('statRashod')
                                .doc((alreadyLinked['id'] ?? '').toString())
                                .update({
                              'title': shopName,
                              'shop_id': shopId,
                              'shop_name': shopName,
                              'sales_source_id': shopId,
                              'sales_source_name': shopName,
                              'sales_source_type': 'shop',
                              'parentId': groupId,
                              'type': 'income',
                              'is_group': false,
                              'planByYear': planByYear,
                              'updated_at': FieldValue.serverTimestamp(),
                            });
                          } else {
                            await _firestore.collection('statRashod').add({
                              'title': shopName,
                              'description': '',
                              'type': 'income',
                              'parentId': groupId,
                              'is_group': false,
                              'shop_id': shopId,
                              'shop_name': shopName,
                              'sales_source_id': shopId,
                              'sales_source_name': shopName,
                              'sales_source_type': 'shop',
                              'is_default': false,
                              'planByYear': planByYear,
                              'currency': _budgetCurrencySymbol(),
                              'is_active': true,
                              'user_id': user?.uid ?? '',
                              'idCompany': companyId,
                              'created_at': FieldValue.serverTimestamp(),
                              'updated_at': FieldValue.serverTimestamp(),
                            });
                          }

                          if (companyId.isNotEmpty) {
                            FirestoreQueryCache.instance
                                .invalidateCompanyCollection(
                                    'statRashod', companyId);
                          }
                          if (context.mounted) Navigator.pop(context);
                          await _loadCategories();
                          _expandIncomeGroup(groupId);
                        },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    amountController.dispose();
  }

  Future<void> _editCategory(Map<String, dynamic> c) async {
    if (!EditingHelper.guardEdit(context, section: EditSection.budget)) return;
    final groups = _categories.where((g) => g['is_group'] == true).toList();
    showDialog(
      context: context,
      builder: (context) => AddExpenseCategoryDialog(
        onAdded: _loadCategories,
        existing: c,
        groups: groups,
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        maxExpensePlan: (c['type'] ?? '').toString() == 'expense' &&
                (c['is_group'] != true) &&
                (c['parentId'] ?? '').toString().trim().isNotEmpty
            ? _availablePlanForParent(
                  (c['parentId'] ?? '').toString().trim(),
                  excludeId: (c['id'] ?? '').toString(),
                ) +
                _planForMonth(c, _selectedYear, _selectedMonth)
            : null,
        maxExpensePlanByMonth: (c['type'] ?? '').toString() == 'expense' &&
                (c['is_group'] != true) &&
                (c['parentId'] ?? '').toString().trim().isNotEmpty
            ? () {
                final limits = _availablePlanForParentByMonth(
                  (c['parentId'] ?? '').toString().trim(),
                  excludeId: (c['id'] ?? '').toString(),
                );
                for (var month = 1; month <= 12; month++) {
                  limits[month] =
                      (limits[month] ?? 0) + _planFor(c, months: [month]);
                }
                return limits;
              }()
            : null,
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    if (!EditingHelper.guardEdit(context, section: EditSection.budget)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить статью?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection('statRashod').doc(id).delete();
      final user = _auth.currentUser;
      final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
      final effectiveCompanyId =
          rawCompanyId.isNotEmpty ? rawCompanyId : user?.uid ?? '';
      if (effectiveCompanyId.isNotEmpty) {
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('statRashod', effectiveCompanyId);
      } else {
        FirestoreQueryCache.instance.invalidateCollection('statRashod');
      }
      _loadCategories();
    }
  }
}

class AddExpenseCategoryDialog extends StatefulWidget {
  final VoidCallback onAdded;
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> groups;
  final String? defaultType;
  final String? defaultParentId;
  final int selectedYear;
  final int selectedMonth;
  final double? maxExpensePlan;
  final Map<int, double>? maxExpensePlanByMonth;

  const AddExpenseCategoryDialog({
    super.key,
    required this.onAdded,
    this.existing,
    this.groups = const [],
    this.defaultType,
    this.defaultParentId,
    required this.selectedYear,
    required this.selectedMonth,
    this.maxExpensePlan,
    this.maxExpensePlanByMonth,
  });

  @override
  State<AddExpenseCategoryDialog> createState() =>
      _AddExpenseCategoryDialogState();
}

class _AddExpenseCategoryDialogState extends State<AddExpenseCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final List<TextEditingController> _monthlyPlanControllers =
      List.generate(12, (_) => TextEditingController());
  static const _quarterLabels = [
    'I квартал',
    'II квартал',
    'III квартал',
    'IV квартал',
  ];
  static const _monthShortLabels = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  String _type = 'expense';
  String _parentId = '';
  String _periodicity = _ExpenseCategoriesWidgetState._oneTimePeriodicity;

  bool _isSubmitting = false;

  InputDecoration _fieldDecoration(String label) {
    const activeColor = Color(0xFFC8A06A);
    final theme = FlutterFlowTheme.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.secondaryText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: activeColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: theme.secondaryText,
      ),
      filled: true,
      fillColor: theme.secondaryBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.alternate),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.alternate),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: activeColor, width: 1.4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _titleController.text = ex['title'] ?? '';
      _descriptionController.text = ex['description'] ?? '';
      _type = (ex['type'] ?? 'expense').toString();
      _parentId = (ex['parentId'] ?? '').toString();
      _periodicity = _ExpenseCategoriesWidgetState._expensePeriodicities
              .contains((ex['periodicity'] ?? '').toString())
          ? (ex['periodicity'] ?? '').toString()
          : _ExpenseCategoriesWidgetState._oneTimePeriodicity;
      final yearMap = _ExpenseCategoriesWidgetState._planYearMap(
        ex['planByYear'],
        widget.selectedYear,
      );
      if (yearMap.isNotEmpty) {
        final amount = _ExpenseCategoriesWidgetState._planValueForMonth(
          ex['planByYear'],
          widget.selectedYear,
          widget.selectedMonth,
        );
        if (amount > 0) {
          _amountController.text = amount.toStringAsFixed(0);
        }
        for (var month = 1; month <= 12; month++) {
          final monthlyAmount =
              _ExpenseCategoriesWidgetState._planValueForMonth(
            ex['planByYear'],
            widget.selectedYear,
            month,
          );
          if (monthlyAmount > 0) {
            _monthlyPlanControllers[month - 1].text =
                monthlyAmount.toStringAsFixed(0);
          }
        }
      }
    } else {
      _type = (widget.defaultType ?? 'expense').toString();
      _periodicity = _ExpenseCategoriesWidgetState._oneTimePeriodicity;
      final defaultParent = (widget.defaultParentId ?? '').toString();
      if (defaultParent.isNotEmpty) {
        _parentId = defaultParent;
      } else {
        final firstGroup = widget.groups.firstWhere(
          (g) => (g['type'] ?? 'expense').toString() == _type,
          orElse: () => const {},
        );
        _parentId = (firstGroup['id'] ?? '').toString();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    for (final controller in _monthlyPlanControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existing != null &&
        !EditingHelper.guardEdit(context, section: EditSection.budget)) {
      return;
    }
    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );
      final isGroup = widget.existing?['is_group'] == true;
      if (!isGroup && _parentId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите раздел')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final isExpenseArticle = !isGroup && _type == 'expense';
      final enteredAmount =
          double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ??
              0;
      if (isExpenseArticle) {
        final monthlyLimits = widget.maxExpensePlanByMonth;
        if (monthlyLimits != null) {
          for (var month = 1; month <= 12; month++) {
            final enteredMonthly = double.tryParse(
                  _monthlyPlanControllers[month - 1]
                      .text
                      .trim()
                      .replaceAll(',', '.'),
                ) ??
                0;
            final limit = monthlyLimits[month] ?? 0;
            if (enteredMonthly > limit) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Подстатья за ${month.toString().padLeft(2, '0')} месяц не может быть больше остатка основной статьи: ${_formatBudgetCurrency(limit)}',
                  ),
                ),
              );
              setState(() => _isSubmitting = false);
              return;
            }
          }
        }
        final limit = widget.maxExpensePlan ?? 0;
        if (monthlyLimits == null && enteredAmount > limit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Сумма статьи не может быть больше остатка Плана: ${_formatBudgetCurrency(limit)}'),
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final planByYear = _ExpenseCategoriesWidgetState._normalizedPlanByYear(
        widget.existing?['planByYear'],
      );
      if (isExpenseArticle) {
        final yearKey = widget.selectedYear.toString();
        final yearMap = _ExpenseCategoriesWidgetState._planYearMap(
            planByYear, widget.selectedYear);
        if (widget.maxExpensePlanByMonth != null) {
          for (var month = 1; month <= 12; month++) {
            final enteredMonthly = double.tryParse(
                  _monthlyPlanControllers[month - 1]
                      .text
                      .trim()
                      .replaceAll(',', '.'),
                ) ??
                0;
            yearMap[month.toString()] = enteredMonthly;
          }
        } else {
          final monthKey = widget.selectedMonth.toString();
          yearMap[monthKey] = enteredAmount;
        }
        planByYear[yearKey] = yearMap;
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _type,
        'parentId': isGroup ? '' : _parentId.trim(),
        'is_group': isGroup ? true : false,
        'is_default': widget.existing?['is_default'] == true,
        'planByYear': planByYear,
        'currency': _budgetCurrencySymbol(),
        'is_active': true,
        'user_id': user.uid,
        'idCompany': effectiveCompanyId,
        'updated_at': FieldValue.serverTimestamp(),
        if (_type == 'expense') 'periodicity': _periodicity,
      };

      if (widget.existing == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        await _firestore.collection('statRashod').add(data);
      } else {
        await _firestore
            .collection('statRashod')
            .doc(widget.existing!['id'])
            .update(data);
      }

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('statRashod', effectiveCompanyId);
      navigator.pop();
      widget.onAdded();
    } catch (e) {
      debugPrint('Error saving statRashod: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final isGroup = widget.existing?['is_group'] == true;
    const typeOptions = [
      {'value': 'income', 'label': 'Доходы'},
      {'value': 'expense', 'label': 'Расходы'},
    ];
    final groupOptions = widget.groups
        .where((g) =>
            (g['type'] ?? 'expense').toString() == _type &&
            g['is_group'] == true)
        .toList()
      ..sort((a, b) {
        final aTitle = (a['title'] ?? '').toString().trim();
        final bTitle = (b['title'] ?? '').toString().trim();
        final aIndex = _type == 'expense'
            ? (aTitle == _ExpenseCategoriesWidgetState._reservesAndRisksTitle
                ? 100000
                : (_ExpenseCategoriesWidgetState._expenseOrder[aTitle] ?? 1000))
            : (_ExpenseCategoriesWidgetState._incomeOrder[aTitle] ?? 1000);
        final bIndex = _type == 'expense'
            ? (bTitle == _ExpenseCategoriesWidgetState._reservesAndRisksTitle
                ? 100000
                : (_ExpenseCategoriesWidgetState._expenseOrder[bTitle] ?? 1000))
            : (_ExpenseCategoriesWidgetState._incomeOrder[bTitle] ?? 1000);
        if (aIndex != bIndex) return aIndex.compareTo(bIndex);
        return aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
      });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Редактировать статью' : 'Добавить статью',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    maxLines: 2,
                    decoration: _fieldDecoration('Название'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Введите название' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: _fieldDecoration('Тип'),
                    items: typeOptions
                        .map((o) => DropdownMenuItem<String>(
                              value: o['value'],
                              child: Text(o['label']!),
                            ))
                        .toList(),
                    onChanged: isGroup
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _type = v;
                              if (_type != 'expense') {
                                _periodicity = _ExpenseCategoriesWidgetState
                                    ._oneTimePeriodicity;
                              }
                              final firstGroup = widget.groups.firstWhere(
                                (g) =>
                                    (g['type'] ?? 'expense').toString() == v &&
                                    g['is_group'] == true,
                                orElse: () => const {},
                              );
                              _parentId = (firstGroup['id'] ?? '').toString();
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  if (!isGroup)
                    DropdownButtonFormField<String>(
                      initialValue: _parentId.isEmpty ? null : _parentId,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: _fieldDecoration('Раздел'),
                      items: groupOptions
                          .map((g) => DropdownMenuItem<String>(
                                value: (g['id'] ?? '').toString(),
                                child: Text(
                                  (g['title'] ?? '').toString(),
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      selectedItemBuilder: (context) => groupOptions
                          .map(
                            (g) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                (g['title'] ?? '').toString(),
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _parentId = v ?? ''),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Выберите раздел' : null,
                    ),
                  if (!isGroup) const SizedBox(height: 12),
                  if (_type == 'expense') ...[
                    DropdownButtonFormField<String>(
                      initialValue: _periodicity,
                      decoration: _fieldDecoration('Периодичность'),
                      items: _ExpenseCategoriesWidgetState._expensePeriodicities
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _periodicity = value ??
                            _ExpenseCategoriesWidgetState._oneTimePeriodicity,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!isGroup && _type == 'expense') ...[
                    if (widget.maxExpensePlanByMonth != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'План подстатьи по месяцам',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: List.generate(4, (quarterIndex) {
                              final startMonth = quarterIndex * 3;
                              return SizedBox(
                                width: 122,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _quarterLabels[quarterIndex],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...List.generate(3, (monthOffset) {
                                      final index = startMonth + monthOffset;
                                      final month = index + 1;
                                      final limit = widget
                                              .maxExpensePlanByMonth?[month] ??
                                          0;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: TextFormField(
                                          controller:
                                              _monthlyPlanControllers[index],
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: _fieldDecoration(
                                            '${_monthShortLabels[index]} · до ${_formatBudgetCurrency(limit)}',
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      )
                    else
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _fieldDecoration(
                          widget.maxExpensePlan != null
                              ? 'Сумма расходов, можно позже (до ${_formatBudgetCurrency(widget.maxExpensePlan!)})'
                              : 'Сумма расходов, можно позже',
                        ),
                        validator: (value) {
                          final amount = double.tryParse(
                                  (value ?? '').trim().replaceAll(',', '.')) ??
                              0;
                          final limit = widget.maxExpensePlan;
                          if (limit != null && amount > limit) {
                            return 'Не больше ${_formatBudgetCurrency(limit)}';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _fieldDecoration('Описание'),
                    maxLines: 3,
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
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BudgetPlanDialog extends StatefulWidget {
  const BudgetPlanDialog({
    super.key,
    required this.selectedYear,
    required this.incomeGroups,
    required this.expenseGroups,
    required this.onSaved,
    required this.ensureGroup,
  });

  final int selectedYear;
  final List<Map<String, dynamic>> incomeGroups;
  final List<Map<String, dynamic>> expenseGroups;
  final VoidCallback onSaved;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> group)
      ensureGroup;

  @override
  State<BudgetPlanDialog> createState() => _BudgetPlanDialogState();
}

class _BudgetPlanDialogState extends State<BudgetPlanDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<TextEditingController>> _controllersByGroupId = {};
  bool _isSubmitting = false;
  late int _editingYear;

  static const _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static const _monthShortNames = [
    'Янв',
    'Фев',
    'Мар',
    'Апр',
    'Май',
    'Июн',
    'Июл',
    'Авг',
    'Сен',
    'Окт',
    'Ноя',
    'Дек',
  ];

  List<Map<String, dynamic>> get _allGroups => [
        ...widget.incomeGroups,
        ...widget.expenseGroups,
      ];

  @override
  void initState() {
    super.initState();
    _editingYear = widget.selectedYear;
    for (final group in _allGroups) {
      final groupId = (group['id'] ?? '').toString();
      _controllersByGroupId[groupId] = List.generate(12, (index) {
        return TextEditingController();
      });
    }
    _syncControllersForYear(_editingYear);
  }

  @override
  void dispose() {
    for (final controllers in _controllersByGroupId.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _syncControllersForYear(int year) {
    for (final group in _allGroups) {
      final groupId = (group['id'] ?? '').toString();
      final controllers = _controllersByGroupId[groupId] ?? const [];
      final planByYear = group['planByYear'];
      for (var index = 0; index < controllers.length; index++) {
        final amount = _ExpenseCategoriesWidgetState._planValueForMonth(
          planByYear,
          year,
          index + 1,
        );
        controllers[index].text = amount > 0 ? amount.toStringAsFixed(0) : '';
      }
    }
  }

  void _applySemiAnnualPlan(String groupId) {
    final controllers = _controllersByGroupId[groupId] ?? const [];
    if (controllers.length < 12) return;

    final amount = controllers
        .map((controller) => controller.text.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (amount.isEmpty) return;

    setState(() {
      for (var index = 0; index < controllers.length; index++) {
        controllers[index].text = (index == 0 || index == 6) ? amount : '';
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      for (final originalGroup in _allGroups) {
        final group = await widget.ensureGroup(originalGroup);
        final groupId = (originalGroup['id'] ?? '').toString();
        final controllers = _controllersByGroupId[groupId] ?? const [];
        final yearMap = <String, dynamic>{};
        for (var month = 1; month <= 12; month++) {
          final value = month - 1 < controllers.length
              ? double.tryParse(controllers[month - 1]
                      .text
                      .trim()
                      .replaceAll(',', '.')) ??
                  0
              : 0;
          yearMap[month.toString()] = value;
        }
        final planByYear = _ExpenseCategoriesWidgetState._normalizedPlanByYear(
          group['planByYear'],
        );
        planByYear[_editingYear.toString()] = yearMap;
        await _firestore.collection('statRashod').doc(group['id']).set({
          'title': (group['title'] ?? '').toString().trim(),
          'type': (group['type'] ?? 'expense').toString().trim(),
          'parentId': (group['parentId'] ?? '').toString().trim(),
          'is_group': group['is_group'] == true ||
              (group['parentId'] ?? '').toString().trim().isEmpty,
          'is_default': group['is_default'] == true,
          'currency': _budgetCurrencySymbol(),
          'is_active': true,
          'idCompany': (group['idCompany'] ?? '').toString().trim().isNotEmpty
              ? (group['idCompany'] ?? '').toString().trim()
              : resolveEffectiveCompanyId(
                  userData: currentUserDocument?.snapshotData,
                  fallbackUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                ),
          'user_id': (group['user_id'] ?? '').toString().trim().isNotEmpty
              ? (group['user_id'] ?? '').toString().trim()
              : FirebaseAuth.instance.currentUser?.uid ?? '',
          'planByYear': planByYear,
          'updated_at': FieldValue.serverTimestamp(),
          if ((group['type'] ?? 'expense').toString().trim() == 'expense')
            'periodicity':
                (group['periodicity'] ?? '').toString().trim().isNotEmpty
                    ? (group['periodicity'] ?? '').toString().trim()
                    : _ExpenseCategoriesWidgetState._oneTimePeriodicity,
        }, SetOptions(merge: true));
      }
      final companyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      if (companyId.isNotEmpty) {
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('statRashod', companyId);
      } else {
        FirestoreQueryCache.instance.invalidateCollection('statRashod');
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
      widget.onSaved();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildGroupSection(String title, List<Map<String, dynamic>> groups) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyFill = Color.alphaBlend(
      (isDark ? Colors.white : const Color(0xFFEC4899))
          .withValues(alpha: isDark ? 0.04 : 0.10),
      theme.secondaryBackground,
    );
    final emptyBorder = isDark
        ? theme.primary.withValues(alpha: 0.55)
        : const Color(0xFFF472B6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
        const SizedBox(height: 10),
        ...groups.map((group) {
          final groupId = (group['id'] ?? '').toString();
          final controllers = _controllersByGroupId[groupId] ?? const [];
          final groupTitle = (group['title'] ?? '').toString().trim().isEmpty
              ? title
              : (group['title'] ?? '').toString();
          final rawPeriodicity = (group['periodicity'] ?? '').toString().trim();
          final periodicity = _ExpenseCategoriesWidgetState
                  ._expensePeriodicities
                  .contains(rawPeriodicity)
              ? rawPeriodicity
              : _ExpenseCategoriesWidgetState._oneTimePeriodicity;
          final isSemiAnnualExpense =
              (group['type'] ?? '').toString().trim() == 'expense' &&
                  periodicity ==
                      _ExpenseCategoriesWidgetState._semiAnnualPeriodicity;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        groupTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    if (isSemiAnnualExpense) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _applySemiAnnualPlan(groupId),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(color: theme.alternate),
                        ),
                        child: Text(
                          'Раз в 6 месяцев',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(12, (index) {
                    final controller = index < controllers.length
                        ? controllers[index]
                        : TextEditingController();
                    final isEmpty = controller.text.trim().isEmpty;
                    return SizedBox(
                      width: 148,
                      child: TextFormField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) {
                          if (mounted) setState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: _monthShortNames[index],
                          helperText: _monthNames[index],
                          helperMaxLines: 1,
                          labelStyle: TextStyle(
                            color: theme.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          helperStyle: TextStyle(
                            color: theme.secondaryText,
                            fontSize: 10,
                            height: 1.0,
                          ),
                          filled: true,
                          fillColor:
                              isEmpty ? emptyFill : theme.primaryBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isEmpty ? emptyBorder : theme.alternate,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isEmpty
                                  ? emptyBorder
                                  : FlutterFlowTheme.of(context).primary,
                              width: 1.4,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Dialog(
      backgroundColor: theme.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Заполнить План на $_editingYear год',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('${DateTime.now().year} год'),
                    selected: _editingYear == DateTime.now().year,
                    onSelected: _isSubmitting
                        ? null
                        : (_) {
                            setState(() {
                              _editingYear = DateTime.now().year;
                              _syncControllersForYear(_editingYear);
                            });
                          },
                  ),
                  ChoiceChip(
                    label: Text('${DateTime.now().year + 1} год'),
                    selected: _editingYear == DateTime.now().year + 1,
                    onSelected: _isSubmitting
                        ? null
                        : (_) {
                            setState(() {
                              _editingYear = DateTime.now().year + 1;
                              _syncControllersForYear(_editingYear);
                            });
                          },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGroupSection('Доходы', widget.incomeGroups),
                      const SizedBox(height: 8),
                      _buildGroupSection('Расходы', widget.expenseGroups),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сохранить План'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetChartPoint {
  const _BudgetChartPoint({
    required this.label,
    required this.income,
    required this.incomeFact,
    required this.incomePreviousYear,
    required this.expense,
    required this.expenseFact,
    required this.expensePreviousYear,
    required this.taxes,
    required this.netProfit,
    required this.plan,
    required this.fact,
  });

  final String label;
  final double income;
  final double incomeFact;
  final double incomePreviousYear;
  final double expense;
  final double expenseFact;
  final double expensePreviousYear;
  final double taxes;
  final double netProfit;
  final double plan;
  final double fact;
}

class _BudgetLineSeries {
  const _BudgetLineSeries(this.name, this.color, this.values);

  final String name;
  final Color color;
  final List<double> values;
}

class _BudgetLineChartPainter extends CustomPainter {
  const _BudgetLineChartPainter({
    required this.series,
    required this.labels,
    required this.minValue,
    required this.maxValue,
    required this.axisColor,
  });

  final List<_BudgetLineSeries> series;
  final List<String> labels;
  final double minValue;
  final double maxValue;
  final Color axisColor;

  String _formatAxisValue(double value) {
    final rounded = value.round().abs().toString();
    final formatted = rounded.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return value < 0 ? '-$formatted' : formatted;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.values.isEmpty) return;
    const leftPadding = 72.0;
    const rightPadding = 12.0;
    const topPadding = 10.0;
    const bottomPadding = 34.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final count = series.first.values.length;
    final safeMaxValue = maxValue <= minValue ? minValue + 1 : maxValue;
    final safeRange = safeMaxValue - minValue;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final zeroY =
        topPadding + chartHeight - ((0 - minValue) / safeRange) * chartHeight;
    final baselineY =
        zeroY.clamp(topPadding, topPadding + chartHeight).toDouble();
    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftPadding, baselineY),
      Offset(leftPadding + chartWidth, baselineY),
      axisPaint,
    );

    final gridPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final axisLabelStyle = TextStyle(
      color: axisColor.withValues(alpha: 0.95),
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
    );
    for (var i = 0; i < 3; i++) {
      final y = topPadding + chartHeight * (i / 2);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );
      final tickValue = safeMaxValue - (safeRange * (i / 2));
      final axisTextPainter = TextPainter(
        text: TextSpan(
          text: _formatAxisValue(tickValue),
          style: axisLabelStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(minWidth: 0, maxWidth: leftPadding - 10);
      axisTextPainter.paint(
        canvas,
        Offset(
          leftPadding - axisTextPainter.width - 8,
          y - (axisTextPainter.height / 2),
        ),
      );
    }

    double yFor(double value) {
      return topPadding +
          chartHeight -
          ((value - minValue) / safeRange) * chartHeight;
    }

    for (final item in series) {
      final path = Path();
      for (var index = 0; index < item.values.length; index++) {
        final x = count == 1
            ? leftPadding + chartWidth / 2
            : leftPadding + chartWidth * (index / (count - 1));
        final y = yFor(item.values[index]);
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final paint = Paint()
        ..color = item.color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);

      for (var index = 0; index < item.values.length; index++) {
        final x = count == 1
            ? leftPadding + chartWidth / 2
            : leftPadding + chartWidth * (index / (count - 1));
        final y = yFor(item.values[index]);
        canvas.drawCircle(
          Offset(x, y),
          2.2,
          Paint()..color = item.color,
        );
      }
    }

    final labelStyle = TextStyle(
      color: axisColor.withValues(alpha: 0.95),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    for (var index = 0; index < count; index++) {
      final x = count == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + chartWidth * (index / (count - 1));
      final label = index < labels.length ? labels[index] : '';
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(minWidth: 0, maxWidth: 56);
      textPainter.paint(
        canvas,
        Offset(
          x - (textPainter.width / 2),
          topPadding + chartHeight + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetLineChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.labels != labels ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.axisColor != axisColor;
  }
}
