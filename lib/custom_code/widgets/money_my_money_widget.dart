// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/custom_code/widgets/editing_helper.dart';
import '/custom_code/widgets/personal_finance_support.dart';
import '/utils/app_money_format.dart';
import '/utils/accounting_entry_service.dart';
import '/utils/country_profile.dart';
import '/utils/money_amount.dart';
import '/utils/money_flow_type.dart';
import '/utils/owner_investment_support.dart';
import '/utils/personal_money_entry_filter.dart';
import '/utils/transaction_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class MoneyMyMoneyWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const MoneyMyMoneyWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<MoneyMyMoneyWidget> createState() => _MoneyMyMoneyWidgetState();
}

class _MoneyMyMoneyWidgetState extends State<MoneyMyMoneyWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _projects = [];
  String _currencyCode = 'KZT';

  Map<String, dynamic> _docMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return Map<String, dynamic>.from(raw as Map);
  }

  List<String> _projectCompanyIds(String fallbackCompanyId) {
    final ids = <String>{};
    if (fallbackCompanyId.trim().isNotEmpty) ids.add(fallbackCompanyId.trim());
    final rawIds = currentUserDocument?.snapshotData['companyIds'];
    if (rawIds is Iterable) {
      for (final item in rawIds) {
        final id = item.toString().trim();
        if (id.isNotEmpty && id != '__all__') ids.add(id);
      }
    }
    final active = (currentUserDocument?.snapshotData['activeCompanyId'] ?? '')
        .toString()
        .trim();
    if (active.isNotEmpty) ids.add(active);
    final primary = (currentUserDocument?.snapshotData['idCompany'] ?? '')
        .toString()
        .trim();
    if (primary.isNotEmpty) ids.add(primary);
    return ids.toList();
  }

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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _wallets = [];
          _categories = [];
          _entries = [];
          _projects = [];
        });
        return;
      }
      final activeCompanyId = PersonalFinanceSupport.effectiveCompanyId(user);
      final projectCompanyIds = _projectCompanyIds(activeCompanyId);

      final results = await Future.wait([
        _firestore
            .collection(PersonalFinanceSupport.walletsCollection)
            .where('user_id', isEqualTo: user.uid)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection(PersonalFinanceSupport.categoriesCollection)
            .where('user_id', isEqualTo: user.uid)
            .get(const GetOptions(source: Source.serverAndCache)),
        _firestore
            .collection(PersonalFinanceSupport.entriesCollection)
            .where('user_id', isEqualTo: user.uid)
            .limit(1000)
            .get(const GetOptions(source: Source.serverAndCache)),
      ]);
      final walletsSnap = results[0];
      final categoriesSnap = results[1];
      final entriesSnap = results[2];
      final projectDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (var i = 0; i < projectCompanyIds.length; i += 10) {
        final chunk = projectCompanyIds.skip(i).take(10).toList();
        if (chunk.isEmpty) continue;
        final snap = await _firestore
            .collection('budget_projects')
            .where('idCompany', whereIn: chunk)
            .get(const GetOptions(source: Source.serverAndCache));
        projectDocs.addAll(snap.docs);
      }
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(activeCompanyId)
          .get();

      final wallets = walletsSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
          .toList();
      final categories = categoriesSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
          .toList();
      final entries = entriesSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
          .where(isPersonalMoneyEntry)
          .toList();
      final projects = projectDocs
          .map((d) => <String, dynamic>{'id': d.id, ..._docMap(d.data())})
          .toList();

      wallets.sort((a, b) => ((a['name'] ?? '').toString())
          .toLowerCase()
          .compareTo(((b['name'] ?? '').toString()).toLowerCase()));
      categories.sort((a, b) {
        final levelCompare = PersonalFinanceSupport.toNum(a['level'])
            .compareTo(PersonalFinanceSupport.toNum(b['level']));
        if (levelCompare != 0) return levelCompare;
        return ((a['title'] ?? '').toString())
            .toLowerCase()
            .compareTo(((b['title'] ?? '').toString()).toLowerCase());
      });
      entries.sort((a, b) {
        final bDate = PersonalFinanceSupport.parseDate(
              b['operation_date'] ?? b['date'],
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final aDate = PersonalFinanceSupport.parseDate(
              a['operation_date'] ?? a['date'],
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      projects.sort((a, b) => ((a['title'] ?? a['name'] ?? '').toString())
          .toLowerCase()
          .compareTo(
              ((b['title'] ?? b['name'] ?? '').toString()).toLowerCase()));

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _wallets = wallets;
        _categories = categories;
        _entries = entries;
        _projects = projects;
      });
    } catch (e) {
      debugPrint('Error loading personal money');
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _walletTotal => _wallets.fold<double>(
      0, (sum, item) => sum + PersonalFinanceSupport.toNum(item['balance']));

  double get _incomeTotal => _entries
      .where((item) => (item['entry_type'] ?? 'expense') == 'income')
      .fold<double>(
          0, (sum, item) => sum + PersonalFinanceSupport.toNum(item['amount']));

  bool _isOwnerInvestmentEntry(Map<String, dynamic> item) {
    final source = (item['source'] ?? '').toString().trim();
    if (source == 'personal_investment') {
      return true;
    }
    final values = <String>[
      (item['source_label'] ?? '').toString(),
      (item['category_title'] ?? '').toString(),
      (item['subcategory1_title'] ?? '').toString(),
      (item['subcategory2_title'] ?? '').toString(),
      (item['description'] ?? '').toString(),
    ].map((v) => v.trim().toLowerCase());
    return values.any((value) =>
        value.contains('вложен') ||
        value.contains('фин.пом') ||
        value.contains('фин пом') ||
        value.contains('финансовая помощь') ||
        value.contains('учредител'));
  }

  double get _expenseTotal => _entries
      .where((item) =>
          (item['entry_type'] ?? 'expense') != 'income' &&
          !_isOwnerInvestmentEntry(item))
      .fold<double>(
          0, (sum, item) => sum + PersonalFinanceSupport.toNum(item['amount']));

  List<Map<String, dynamic>> get _filteredEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries.where((item) {
      final wallet = (item['wallet_name'] ?? '').toString().toLowerCase();
      final desc = (item['description'] ?? '').toString().toLowerCase();
      final sourceLabel = (item['source_label'] ?? '').toString().toLowerCase();
      final categoryPath =
          PersonalFinanceSupport.buildCategoryPath(item).toLowerCase();
      return wallet.contains(query) ||
          desc.contains(query) ||
          sourceLabel.contains(query) ||
          categoryPath.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _rootCategories() => _categories
      .where((item) => (item['parent_id'] ?? '').toString().trim().isEmpty)
      .toList();

  List<Map<String, dynamic>> _childrenOf(String parentId) => _categories
      .where((item) => (item['parent_id'] ?? '').toString().trim() == parentId)
      .toList();

  String _formatMoney(double value) {
    return formatMoneyWithCurrency(value, currencyCode: _currencyCode);
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        scheduleReloadOnCompanyChange(_loadData);
        if (!PermissionsHelper.has('money.my')) {
          return PermissionsHelper.noAccess();
        }
        final theme = FlutterFlowTheme.of(context);
        final panelFill = Color.alphaBlend(
          Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.01),
          theme.secondaryBackground,
        );
        final panelBorder = Theme.of(context).brightness == Brightness.dark
            ? theme.alternate.withOpacity(0.85)
            : theme.alternate;
        final pageBackground = Theme.of(context).brightness == Brightness.dark
            ? theme.primaryBackground
            : const Color(0xFFF7F8FA);
        return ResponsiveFrame(
          backgroundColor: pageBackground,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statCard(
                          title: 'Баланс кошельков',
                          value: _formatMoney(_walletTotal),
                          amount: _walletTotal,
                          icon: Icons.account_balance_wallet_outlined,
                          iconBg: FlutterFlowTheme.of(context).accent1,
                          iconColor: FlutterFlowTheme.of(context).primary,
                          fillColor: panelFill,
                          borderColor: panelBorder,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          title: 'Доходы',
                          value: _formatMoney(_incomeTotal),
                          amount: _incomeTotal,
                          icon: Icons.trending_up,
                          iconBg: FlutterFlowTheme.of(context)
                              .success
                              .withValues(alpha: 0.14),
                          iconColor: FlutterFlowTheme.of(context).success,
                          fillColor: panelFill,
                          borderColor: panelBorder,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          title: 'Расходы',
                          value: _formatMoney(_expenseTotal),
                          amount: _expenseTotal,
                          icon: Icons.trending_down,
                          iconBg: FlutterFlowTheme.of(context)
                              .warning
                              .withValues(alpha: 0.14),
                          iconColor: FlutterFlowTheme.of(context).warning,
                          fillColor: panelFill,
                          borderColor: panelBorder,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 980;
                        if (compact) {
                          return Column(
                            children: [
                              _buildWalletsCard(),
                              const SizedBox(height: 16),
                              _buildCategoriesCard(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildWalletsCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildCategoriesCard()),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildEntriesCard(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.accent1,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: theme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Личные деньги',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Кошельки, личные категории, доходы и расходы пользователя',
                style: TextStyle(fontSize: 13, color: theme.secondaryText),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showWalletDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Кошелек'),
            ),
            ElevatedButton.icon(
              onPressed: () => _showCategoryDialog(),
              icon: const Icon(Icons.account_tree_outlined, size: 16),
              label: const Text('Категория'),
            ),
            ElevatedButton.icon(
              onPressed: _wallets.isEmpty ? null : () => _showEntryDialog(),
              icon: const Icon(Icons.swap_vert, size: 16),
              label: const Text('Операция'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletsCard() {
    return _panel(
      title: 'Кошельки',
      subtitle:
          _wallets.isEmpty ? 'Кошельков пока нет' : '${_wallets.length} шт.',
      child: Column(
        children: [
          _tableHeader(const [
            _HeaderSpec('Кошелек', 4),
            _HeaderSpec('Валюта', 2),
            _HeaderSpec('Баланс', 3),
            _HeaderSpec('', 2),
          ]),
          const Divider(height: 1),
          if (_wallets.isEmpty)
            _emptyState('Добавьте первый кошелек')
          else
            ..._wallets.map(_walletRow),
        ],
      ),
    );
  }

  Widget _buildCategoriesCard() {
    return _panel(
      title: 'Категории',
      subtitle: 'Основная категория -> подкатегория -> подкатегория 2',
      child: _rootCategories().isEmpty
          ? _emptyState('Категории пока не созданы')
          : Column(
              children: _rootCategories()
                  .map((category) => _categoryTile(category, level: 0))
                  .toList(),
            ),
    );
  }

  Widget _buildEntriesCard() {
    return _panel(
      title: 'Личные операции',
      subtitle: _filteredEntries.isEmpty
          ? 'Доходов и расходов пока нет'
          : '${_filteredEntries.length} операций',
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Поиск по наименованию',
                border: InputBorder.none,
                icon: Icon(Icons.search),
              ),
            ),
          ),
          _tableHeader(const [
            _HeaderSpec('Дата', 2),
            _HeaderSpec('Тип', 2),
            _HeaderSpec('Кошелек', 3),
            _HeaderSpec('Категория', 4),
            _HeaderSpec('Описание', 4),
            _HeaderSpec('Сумма', 2),
            _HeaderSpec('', 2),
          ]),
          const Divider(height: 1),
          if (_filteredEntries.isEmpty)
            _emptyState('Операции пока не добавлены')
          else
            ..._filteredEntries.map(_entryRow),
        ],
      ),
    );
  }

  Widget _categoryTile(Map<String, dynamic> item, {required int level}) {
    final theme = FlutterFlowTheme.of(context);
    final title = (item['title'] ?? '').toString();
    final children = _childrenOf((item['id'] ?? '').toString());
    final canAddChild = level < 2;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.alternate),
      ),
      child: ExpansionTile(
        title: Text(
          title.isEmpty ? 'Без названия' : title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.primaryText,
          ),
        ),
        subtitle: Text(
          _categoryLevelLabel(level),
          style: TextStyle(color: theme.secondaryText),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (canAddChild)
              IconButton(
                onPressed: () => _showCategoryDialog(parent: item),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                tooltip: 'Добавить вложенную категорию',
              ),
            if (EditingHelper.canEditExisting())
              IconButton(
                onPressed: () => _showCategoryDialog(existing: item),
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Редактировать',
              ),
            if (EditingHelper.canEditExisting())
              IconButton(
                onPressed: () => _deleteCategory(item),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                tooltip: 'Удалить',
              ),
          ],
        ),
        children: children.isEmpty
            ? [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Нет вложенных категорий',
                      style:
                          TextStyle(fontSize: 12, color: theme.secondaryText),
                    ),
                  ),
                ),
              ]
            : children
                .map((child) => _categoryTile(child, level: level + 1))
                .toList(),
      ),
    );
  }

  Widget _walletRow(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final currency = (item['currency'] ?? _currencyCode).toString();
    final balance = PersonalFinanceSupport.toNum(item['balance']);
    return InkWell(
      onTap: EditingHelper.canEditExisting()
          ? () => _showWalletDialog(existing: item)
          : null,
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
            _cell(name.isEmpty ? '-' : name, flex: 4, bold: true),
            _cell(currency, flex: 2),
            _cell(_formatMoney(balance),
                flex: 3, color: amountTextColor(context, balance)),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: () => _showWalletDialog(existing: item),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Переименовать кошелек',
                    ),
                  if (EditingHelper.canEditExisting())
                    IconButton(
                      onPressed: () => _deleteWallet(item['id'].toString()),
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

  Widget _entryRow(Map<String, dynamic> item) {
    final date = PersonalFinanceSupport.parseDate(
      item['operation_date'] ?? item['date'],
    );
    final wallet = (item['wallet_name'] ?? '').toString();
    final desc = (item['description'] ?? '').toString();
    final sourceLabel = (item['source_label'] ?? '').toString().trim();
    final amount = PersonalFinanceSupport.toNum(item['amount']);
    final type = (item['entry_type'] ?? 'expense').toString();
    final isOwnerInvestment = _isOwnerInvestmentEntry(item);
    final visibleType = isOwnerInvestment ? 'investment' : type;
    final categoryPath = PersonalFinanceSupport.buildCategoryPath(item);
    final visibleCategory = isOwnerInvestment
        ? ownerInvestmentDisplayLabel
        : categoryPath.isEmpty
            ? (sourceLabel.isEmpty ? '-' : sourceLabel)
            : sourceLabel.isEmpty
                ? categoryPath
                : '$categoryPath · $sourceLabel';
    return Container(
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
          _cell(
            date == null ? '-' : PersonalFinanceSupport.formatDate(date),
            flex: 2,
          ),
          _cell(PersonalFinanceSupport.entryTypeLabel(visibleType),
              flex: 2, bold: true),
          _cell(wallet.isEmpty ? '-' : wallet, flex: 3),
          _cell(visibleCategory, flex: 4),
          _cell(desc.isEmpty ? '-' : desc, flex: 4),
          _cell(
            _formatMoney(amount),
            flex: 2,
            color: visibleType == 'income'
                ? FlutterFlowTheme.of(context).success
                : visibleType == 'investment'
                    ? FlutterFlowTheme.of(context).primary
                    : FlutterFlowTheme.of(context).warning,
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (EditingHelper.canEditExisting())
                  IconButton(
                    onPressed: () => _showEntryDialog(existing: item),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                if (EditingHelper.canEditExisting())
                  IconButton(
                    onPressed: () => _deleteEntry(item),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = FlutterFlowTheme.of(context);
    final fillColor = Color.alphaBlend(
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.02)
          : Colors.black.withOpacity(0.01),
      theme.secondaryBackground,
    );
    final borderColor = Theme.of(context).brightness == Brightness.dark
        ? theme.alternate.withOpacity(0.85)
        : theme.alternate;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              )),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: theme.secondaryText)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: theme.secondaryText),
        ),
      ),
    );
  }

  Widget _tableHeader(List<_HeaderSpec> headers) {
    final theme = FlutterFlowTheme.of(context);
    final headerColor = Theme.of(context).brightness == Brightness.dark
        ? theme.primaryText.withOpacity(0.76)
        : theme.secondaryText;
    return Row(
      children: headers
          .map((header) => Expanded(
                flex: header.flex,
                child: Text(
                  header.text,
                  style: TextStyle(fontSize: 12, color: headerColor),
                ),
              ))
          .toList(),
    );
  }

  Widget _cell(
    String text, {
    required int flex,
    bool bold = false,
    Color? color,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: color ?? theme.primaryText,
        ),
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
    required Color fillColor,
    required Color borderColor,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Expanded(
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontSize: 12, color: theme.secondaryText)),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: amountTextColor(
                        context,
                        amount,
                        positiveColor: theme.primaryText,
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

  String _categoryLevelLabel(int level) {
    switch (level) {
      case 0:
        return 'Основная категория';
      case 1:
        return 'Подкатегория';
      default:
        return 'Подкатегория 2';
    }
  }

  void _showWalletDialog({Map<String, dynamic>? existing}) {
    if (existing != null && !EditingHelper.guardEdit(context)) return;
    showDialog(
      context: context,
      builder: (context) => _WalletDialog(
        existing: existing,
        defaultCurrencyCode: _currencyCode,
        onSaved: _loadData,
      ),
    );
  }

  void _showCategoryDialog({
    Map<String, dynamic>? existing,
    Map<String, dynamic>? parent,
  }) {
    if (existing != null && !EditingHelper.guardEdit(context)) return;
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        existing: existing,
        parent: parent,
        categories: _categories,
        onSaved: _loadData,
      ),
    );
  }

  void _showEntryDialog({Map<String, dynamic>? existing}) {
    if (existing != null && !EditingHelper.guardEdit(context)) return;
    showDialog(
      context: context,
      builder: (context) => _EntryDialog(
        existing: existing,
        wallets: _wallets,
        categories: _categories,
        projects: _projects,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _deleteWallet(String id) async {
    if (!EditingHelper.guardEdit(context)) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final companyId = PersonalFinanceSupport.effectiveCompanyId(user);
    final batch = _firestore.batch();
    for (final entry in _entries
        .where((item) => (item['wallet_id'] ?? '').toString() == id)) {
      batch.delete(_firestore
          .collection(PersonalFinanceSupport.entriesCollection)
          .doc(entry['id'].toString()));
    }
    batch.delete(_firestore
        .collection(PersonalFinanceSupport.walletsCollection)
        .doc(id));
    await batch.commit();
    FirestoreQueryCache.instance.invalidateCompanyCollection(
        PersonalFinanceSupport.walletsCollection, companyId);
    FirestoreQueryCache.instance.invalidateCompanyCollection(
        PersonalFinanceSupport.entriesCollection, companyId);
    await _loadData();
  }

  Future<void> _deleteCategory(Map<String, dynamic> item) async {
    if (!EditingHelper.guardEdit(context)) return;
    final id = (item['id'] ?? '').toString();
    final user = _auth.currentUser;
    if (user == null) return;
    final companyId = PersonalFinanceSupport.effectiveCompanyId(user);
    final idsToDelete = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final category in _categories) {
        final categoryId = (category['id'] ?? '').toString();
        final parentId = (category['parent_id'] ?? '').toString();
        if (categoryId.isNotEmpty &&
            idsToDelete.contains(parentId) &&
            idsToDelete.add(categoryId)) {
          changed = true;
        }
      }
    }
    final batch = _firestore.batch();
    for (final categoryId in idsToDelete) {
      batch.delete(_firestore
          .collection(PersonalFinanceSupport.categoriesCollection)
          .doc(categoryId));
    }
    for (final entry in _entries.where((entry) =>
        idsToDelete.contains((entry['category_id'] ?? '').toString()) ||
        idsToDelete.contains((entry['subcategory1_id'] ?? '').toString()) ||
        idsToDelete.contains((entry['subcategory2_id'] ?? '').toString()))) {
      batch.update(
        _firestore
            .collection(PersonalFinanceSupport.entriesCollection)
            .doc(entry['id'].toString()),
        {
          'category_id': FieldValue.delete(),
          'category_title': FieldValue.delete(),
          'subcategory1_id': FieldValue.delete(),
          'subcategory1_title': FieldValue.delete(),
          'subcategory2_id': FieldValue.delete(),
          'subcategory2_title': FieldValue.delete(),
        },
      );
    }
    await batch.commit();
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      PersonalFinanceSupport.categoriesCollection,
      companyId,
    );
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      PersonalFinanceSupport.entriesCollection,
      companyId,
    );
    await _loadData();
  }

  Future<void> _deleteEntry(Map<String, dynamic> item) async {
    if (!EditingHelper.guardEdit(context)) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final companyId = PersonalFinanceSupport.effectiveCompanyId(user);
    final walletId = (item['wallet_id'] ?? '').toString();
    final type = (item['entry_type'] ?? 'expense').toString();
    final amount = PersonalFinanceSupport.toNum(item['amount']);
    final projectTxId =
        (item['project_owner_transaction_id'] ?? '').toString().trim();
    final projectCompanyId =
        (item['project_company_id'] ?? item['idCompany'] ?? '')
            .toString()
            .trim();
    await _firestore
        .collection(PersonalFinanceSupport.entriesCollection)
        .doc(item['id'])
        .delete();
    if (projectTxId.isNotEmpty) {
      await _firestore.collection('tranzaction').doc(projectTxId).delete();
      if (projectCompanyId.isNotEmpty) {
        await TransactionSync.recomputeAllForCompany(projectCompanyId);
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('tranzaction', projectCompanyId);
        FirestoreQueryCache.instance.invalidateCompanyCollection(
            'accounting_entries', projectCompanyId);
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('sheta', projectCompanyId);
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('ushet', projectCompanyId);
      }
    }
    await PersonalFinanceSupport.applyWalletDelta(
      _firestore,
      walletId,
      -PersonalFinanceSupport.signedAmount(type, amount),
    );
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      PersonalFinanceSupport.entriesCollection,
      companyId,
    );
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      PersonalFinanceSupport.walletsCollection,
      companyId,
    );
    await _loadData();
  }
}

class _HeaderSpec {
  final String text;
  final int flex;

  const _HeaderSpec(this.text, this.flex);
}

class _WalletDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final String defaultCurrencyCode;
  final VoidCallback onSaved;

  const _WalletDialog({
    this.existing,
    required this.defaultCurrencyCode,
    required this.onSaved,
  });

  @override
  State<_WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends State<_WalletDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final TextEditingController _currency;
  final _balance = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency = TextEditingController(text: widget.defaultCurrencyCode);
    final ex = widget.existing;
    if (ex != null) {
      _name.text = (ex['name'] ?? '').toString();
      _currency.text = (ex['currency'] ?? _currency.text).toString();
      _balance.text = PersonalFinanceSupport.toNum(ex['balance']).toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existing != null && !EditingHelper.guardEdit(context)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final activeCompanyId = PersonalFinanceSupport.effectiveCompanyId(user);
      final data = {
        'name': _name.text.trim(),
        'currency': _currency.text.trim(),
        'balance': double.tryParse(_balance.text.replaceAll(',', '.')) ?? 0,
        'user_id': user.uid,
        'scope': 'owner_personal',
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.existing == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.walletsCollection)
            .add(data);
      } else {
        final walletId = widget.existing!['id'].toString();
        final oldName = (widget.existing!['name'] ?? '').toString();
        final newName = _name.text.trim();
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.walletsCollection)
            .doc(walletId)
            .update(data);
        if (oldName != newName) {
          final entries = await FirebaseFirestore.instance
              .collection(PersonalFinanceSupport.entriesCollection)
              .where('wallet_id', isEqualTo: walletId)
              .get();
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in entries.docs) {
            batch.update(doc.reference, {
              'wallet_name': newName,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
          FirestoreQueryCache.instance.invalidateCompanyCollection(
            PersonalFinanceSupport.entriesCollection,
            activeCompanyId,
          );
        }
      }

      FirestoreQueryCache.instance.invalidateCompanyCollection(
        PersonalFinanceSupport.walletsCollection,
        activeCompanyId,
      );
      final messenger = ScaffoldMessenger.maybeOf(context);
      final navigator = Navigator.of(context);
      if (mounted) {
        navigator.pop();
      }
      widget.onSaved();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(widget.existing == null
              ? 'Операция добавлена.'
              : 'Операция сохранена.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Редактировать кошелек' : 'Добавить кошелек'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _currency,
                decoration: const InputDecoration(labelText: 'Валюта'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _balance,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Стартовый баланс'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: Text(isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Map<String, dynamic>? parent;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onSaved;

  const _CategoryDialog({
    this.existing,
    this.parent,
    required this.categories,
    required this.onSaved,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  String _parentId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _title.text = (ex['title'] ?? '').toString();
      _parentId = (ex['parent_id'] ?? '').toString();
    } else if (widget.parent != null) {
      _parentId = (widget.parent!['id'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  int _levelForParent(String parentId) {
    if (parentId.trim().isEmpty) return 0;
    final parent = widget.categories.firstWhere(
      (item) => (item['id'] ?? '').toString() == parentId,
      orElse: () => const <String, dynamic>{},
    );
    return PersonalFinanceSupport.toNum(parent['level']).toInt() + 1;
  }

  List<Map<String, dynamic>> get _availableParents => widget.categories
      .where((item) => PersonalFinanceSupport.toNum(item['level']).toInt() < 2)
      .toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existing != null && !EditingHelper.guardEdit(context)) return;
    final level = _levelForParent(_parentId);
    if (level > 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Допускается только 2 уровня подкатегорий.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final activeCompanyId = PersonalFinanceSupport.effectiveCompanyId(user);
      final data = {
        'title': _title.text.trim(),
        'parent_id': _parentId,
        'level': level,
        'user_id': user.uid,
        'scope': 'owner_personal',
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (widget.existing == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.categoriesCollection)
            .add(data);
      } else {
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.categoriesCollection)
            .doc(widget.existing!['id'])
            .update(data);
      }

      FirestoreQueryCache.instance.invalidateCompanyCollection(
        PersonalFinanceSupport.categoriesCollection,
        activeCompanyId,
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Редактировать категорию' : 'Добавить категорию'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _parentId.isEmpty ? null : _parentId,
                decoration:
                    const InputDecoration(labelText: 'Родительская категория'),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Основная категория'),
                  ),
                  ..._availableParents.map(
                    (item) => DropdownMenuItem<String>(
                      value: (item['id'] ?? '').toString(),
                      child: Text((item['title'] ?? 'Без названия').toString()),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _parentId = value ?? ''),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Введите название' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: Text(isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }
}

class _EntryDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> wallets;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> projects;
  final VoidCallback onSaved;

  const _EntryDialog({
    this.existing,
    required this.wallets,
    required this.categories,
    required this.projects,
    required this.onSaved,
  });

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _amount = TextEditingController(text: '0');
  final _desc = TextEditingController();

  String _entryType = 'expense';
  String? _walletId;
  String? _categoryId;
  String? _subcategory1Id;
  String? _subcategory2Id;
  String? _projectId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _date.text = (ex['date'] ?? '').toString();
      _amount.text = PersonalFinanceSupport.toNum(ex['amount']).toString();
      _desc.text = (ex['description'] ?? '').toString();
      _entryType = (ex['entry_type'] ?? 'expense').toString();
      _walletId = (ex['wallet_id'] ?? '').toString().isEmpty
          ? null
          : (ex['wallet_id'] ?? '').toString();
      _categoryId = (ex['category_id'] ?? '').toString().isEmpty
          ? null
          : (ex['category_id'] ?? '').toString();
      _subcategory1Id = (ex['subcategory1_id'] ?? '').toString().isEmpty
          ? null
          : (ex['subcategory1_id'] ?? '').toString();
      _subcategory2Id = (ex['subcategory2_id'] ?? '').toString().isEmpty
          ? null
          : (ex['subcategory2_id'] ?? '').toString();
      _projectId = (ex['project_id'] ?? '').toString().isEmpty
          ? null
          : (ex['project_id'] ?? '').toString();
    } else {
      _date.text = PersonalFinanceSupport.formatDate(DateTime.now());
      if (widget.wallets.isNotEmpty) {
        _walletId = (widget.wallets.first['id'] ?? '').toString();
      }
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _categoriesForParent(String? parentId) => widget
      .categories
      .where((item) => (item['parent_id'] ?? '').toString() == (parentId ?? ''))
      .toList();

  Map<String, dynamic>? _findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in widget.categories) {
      if ((item['id'] ?? '').toString() == id) return item;
    }
    return null;
  }

  Map<String, dynamic>? _findProjectById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in widget.projects) {
      if ((item['id'] ?? '').toString() == id) return item;
    }
    return null;
  }

  double? _parseAmount() {
    final normalized = _amount.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll('о', '0')
        .replaceAll('О', '0')
        .replaceAll('o', '0')
        .replaceAll('O', '0');
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_walletId == null || _walletId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите кошелек.')),
      );
      return;
    }
    if (widget.existing != null && !EditingHelper.guardEdit(context)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final activeCompanyId = PersonalFinanceSupport.effectiveCompanyId(user);
      final wallet = widget.wallets.firstWhere(
        (item) => (item['id'] ?? '').toString() == _walletId,
        orElse: () => const <String, dynamic>{},
      );
      final category = _findById(_categoryId);
      final sub1 = _findById(_subcategory1Id);
      final sub2 = _findById(_subcategory2Id);
      final project = _findProjectById(_projectId);
      final projectId = (project?['id'] ?? '').toString();
      final projectTitle =
          (project?['title'] ?? project?['name'] ?? '').toString();
      final projectCompanyId =
          (project?['idCompany'] ?? project?['company_id'] ?? '')
              .toString()
              .trim();
      final isProjectTransfer = projectId.isNotEmpty;
      final targetCompanyId = isProjectTransfer ? projectCompanyId : '';
      if (isProjectTransfer && targetCompanyId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('У проекта не указана компания.')),
        );
        setState(() => _saving = false);
        return;
      }
      final amount = _parseAmount() ?? 0;
      final dateValue =
          PersonalFinanceSupport.parseDate(_date.text.trim()) ?? DateTime.now();
      final entryType = isProjectTransfer ? 'expense' : _entryType;
      final description = _desc.text.trim().isEmpty && isProjectTransfer
          ? 'Перевод на проект $projectTitle'
          : _desc.text.trim();

      final data = {
        'date': PersonalFinanceSupport.formatDate(dateValue),
        'operation_date': Timestamp.fromDate(dateValue),
        'entry_type': entryType,
        'wallet_id': _walletId,
        'wallet_name': (wallet['name'] ?? '').toString(),
        'category_id': _categoryId ?? '',
        'category_title': (category?['title'] ?? '').toString(),
        'subcategory1_id': _subcategory1Id ?? '',
        'subcategory1_title': (sub1?['title'] ?? '').toString(),
        'subcategory2_id': _subcategory2Id ?? '',
        'subcategory2_title': (sub2?['title'] ?? '').toString(),
        'amount': amount,
        'description': description,
        'scope': 'personal',
        'source': isProjectTransfer ? 'personal_project_transfer' : 'manual',
        'source_label': isProjectTransfer ? 'Перевод на проект' : '',
        'money_flow_type':
            isProjectTransfer ? MoneyFlowType.financing.storageValue : '',
        'moneyFlowType':
            isProjectTransfer ? MoneyFlowType.financing.storageValue : '',
        'project_id': projectId,
        'project': projectTitle,
        'project_title': projectTitle,
        'project_company_id': projectCompanyId,
        'section': personalMoneySection,
        'entry_scope': personalMoneySection,
        'user_id': user.uid,
        'idCompany': targetCompanyId,
        'owner_scope': 'global',
        'updated_at': FieldValue.serverTimestamp(),
      };

      final oldWalletId = (widget.existing?['wallet_id'] ?? '').toString();
      final oldType = (widget.existing?['entry_type'] ?? 'expense').toString();
      final oldAmount =
          PersonalFinanceSupport.toNum(widget.existing?['amount']);
      final oldProjectTxId =
          (widget.existing?['project_owner_transaction_id'] ?? '').toString();
      final oldProjectCompanyId = (widget.existing?['project_company_id'] ??
              widget.existing?['idCompany'] ??
              '')
          .toString()
          .trim();
      String projectTxId = oldProjectTxId;

      if (isProjectTransfer) {
        final account =
            await TransactionSync.selectAccount(targetCompanyId, tip: 'my');
        if (account.reference == null) {
          throw Exception('Не удалось найти счет средств владельца');
        }
        final txData = {
          ...createTranzactionRecordData(
            type: 'income',
            typeUchet: 'owner',
            moneyFlowType: MoneyFlowType.financing.storageValue,
            kat: 'Финансирование проекта',
            text: description,
            summa: amount,
            nds: false,
            summaNds: 0,
            idCompany: targetCompanyId,
            schetTitle: account.title,
            date: dateValue,
            status: 'Проведена',
            counterparty: 'Личные средства владельца',
          ),
          ...mapToFirestore(
            transactionMoneyFieldsForAccountData(
              amountOriginal: amount,
              accountData: account.snapshotData,
              exchangeRateDate: dateValue,
            ),
          ),
          'schet_id': account.reference!.id,
          'source': 'personal_project_transfer',
          'project_id': projectId,
          'project': projectTitle,
          'project_title': projectTitle,
        };
        final txRef = projectTxId.isEmpty
            ? FirebaseFirestore.instance.collection('tranzaction').doc()
            : FirebaseFirestore.instance
                .collection('tranzaction')
                .doc(projectTxId);
        await txRef.set(txData, SetOptions(merge: true));
        await createEntriesForTransaction(
          firestore: FirebaseFirestore.instance,
          transactionRef: txRef,
          transactionData: txData,
          overwriteExisting: true,
        );
        projectTxId = txRef.id;
        data['project_owner_transaction_id'] = projectTxId;
      } else if (oldProjectTxId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('tranzaction')
            .doc(oldProjectTxId)
            .delete();
        data['project_owner_transaction_id'] = FieldValue.delete();
      }

      if (widget.existing == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.entriesCollection)
            .add(data);
        await PersonalFinanceSupport.applyWalletDelta(
          FirebaseFirestore.instance,
          _walletId!,
          PersonalFinanceSupport.signedAmount(entryType, amount),
        );
      } else {
        await FirebaseFirestore.instance
            .collection(PersonalFinanceSupport.entriesCollection)
            .doc(widget.existing!['id'])
            .update(data);
        await PersonalFinanceSupport.applyWalletDelta(
          FirebaseFirestore.instance,
          oldWalletId,
          -PersonalFinanceSupport.signedAmount(oldType, oldAmount),
        );
        await PersonalFinanceSupport.applyWalletDelta(
          FirebaseFirestore.instance,
          _walletId!,
          PersonalFinanceSupport.signedAmount(entryType, amount),
        );
      }
      if (isProjectTransfer || oldProjectTxId.isNotEmpty) {
        if (targetCompanyId.isNotEmpty) {
          await TransactionSync.recomputeAllForCompany(targetCompanyId);
        }
        if (oldProjectCompanyId.isNotEmpty &&
            oldProjectCompanyId != targetCompanyId) {
          await TransactionSync.recomputeAllForCompany(oldProjectCompanyId);
        }
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('tranzaction', targetCompanyId);
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('accounting_entries', targetCompanyId);
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('sheta', targetCompanyId);
        FirestoreQueryCache.instance
            .invalidateCompanyCollection('ushet', targetCompanyId);
      }

      FirestoreQueryCache.instance.invalidateCompanyCollection(
        PersonalFinanceSupport.entriesCollection,
        activeCompanyId,
      );
      FirestoreQueryCache.instance.invalidateCompanyCollection(
        PersonalFinanceSupport.walletsCollection,
        activeCompanyId,
      );
      final messenger = ScaffoldMessenger.maybeOf(context);
      final navigator = Navigator.of(context);
      if (mounted) {
        navigator.pop();
      }
      widget.onSaved();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(widget.existing == null
              ? 'Операция добавлена.'
              : 'Операция сохранена.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final rootCategories = _categoriesForParent('');
    final sub1Categories = _categoriesForParent(_categoryId);
    final sub2Categories = _categoriesForParent(_subcategory1Id);
    final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.72;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(isEdit ? 'Редактировать операцию' : 'Добавить операцию'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 460,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxDialogHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _entryType,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Доход')),
                      DropdownMenuItem(value: 'expense', child: Text('Расход')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _entryType = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _walletId,
                    decoration: const InputDecoration(labelText: 'Кошелек'),
                    items: widget.wallets
                        .map(
                          (wallet) => DropdownMenuItem<String>(
                            value: (wallet['id'] ?? '').toString(),
                            child:
                                Text((wallet['name'] ?? 'Кошелек').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _walletId = value),
                  ),
                  if (widget.projects.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _projectId,
                      decoration:
                          const InputDecoration(labelText: 'Проект компании'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Без проекта'),
                        ),
                        ...widget.projects.map(
                          (project) => DropdownMenuItem<String>(
                            value: (project['id'] ?? '').toString(),
                            child: Text(
                              (project['title'] ?? project['name'] ?? 'Проект')
                                  .toString(),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _projectId = value;
                          if ((value ?? '').isNotEmpty) {
                            _entryType = 'expense';
                          }
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _date,
                    decoration: const InputDecoration(labelText: 'Дата'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration:
                        const InputDecoration(labelText: 'Основная категория'),
                    items: rootCategories
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: (item['id'] ?? '').toString(),
                            child:
                                Text((item['title'] ?? 'Категория').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _categoryId = value;
                        _subcategory1Id = null;
                        _subcategory2Id = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _subcategory1Id,
                    decoration:
                        const InputDecoration(labelText: 'Подкатегория'),
                    items: sub1Categories
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: (item['id'] ?? '').toString(),
                            child: Text(
                                (item['title'] ?? 'Подкатегория').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _subcategory1Id = value;
                        _subcategory2Id = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _subcategory2Id,
                    decoration:
                        const InputDecoration(labelText: 'Подкатегория 2'),
                    items: sub2Categories
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: (item['id'] ?? '').toString(),
                            child: Text(
                                (item['title'] ?? 'Подкатегория 2').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _subcategory2Id = value),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Сумма'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Введите сумму';
                      final amount = _parseAmount();
                      if (amount == null) return 'Введите число';
                      if (amount <= 0) return 'Сумма должна быть больше 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _desc,
                    decoration: const InputDecoration(labelText: 'Описание'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: Text(isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }
}
