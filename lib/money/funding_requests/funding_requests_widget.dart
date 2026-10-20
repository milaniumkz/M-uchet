import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/custom_code/widgets/permissions_helper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/app_money_format.dart';
import '/utils/effective_company_support.dart';
import '/utils/report_export_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FundingRequestsWidget extends StatefulWidget {
  const FundingRequestsWidget({super.key});

  static String routeName = 'fundingRequests';
  static String routePath = '/fundingRequests';

  @override
  State<FundingRequestsWidget> createState() => _FundingRequestsWidgetState();
}

class _FundingLineDraft {
  final amountController = TextEditingController();
  final commentController = TextEditingController();
  String category = _FundingRequestsWidgetState.defaultCategories.first;
  String budgetArticle = '';

  void dispose() {
    amountController.dispose();
    commentController.dispose();
  }
}

class _FundingRequestsWidgetState extends State<FundingRequestsWidget> {
  static const defaultCategories = [
    'Товары',
    'Материалы',
    'Услуги',
    'Оплата труда',
    'Налоги',
    'Машины/Механизмы',
    'Канцелярские/Хозяйственные товары',
    'Основные средства',
    'Орг.техника',
  ];

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _dateController = TextEditingController();
  final _projectController = TextEditingController();
  final _commentController = TextEditingController();
  final _attachmentController = TextEditingController();
  final _departmentController = TextEditingController();
  final _lines = <_FundingLineDraft>[_FundingLineDraft()];
  String _projectId = '';
  String _projectTitle = '';
  String _branchId = '';
  String _branchTitle = '';
  String _registryPeriod = 'all';
  String _registryStatus = 'all';
  String _registryProject = 'all';
  String _registryCategory = 'all';
  bool _saving = false;
  int _refreshTick = 0;

  String get _companyId => resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: currentUserUid,
      ).trim();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  @override
  void dispose() {
    _dateController.dispose();
    _projectController.dispose();
    _commentController.dispose();
    _attachmentController.dispose();
    _departmentController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadCustomCategories() async {
    if (_companyId.isEmpty) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('funding_request_categories')
        .where('idCompany', isEqualTo: _companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    return snap.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadRequests() async {
    if (_companyId.isEmpty) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('funding_requests')
        .where('idCompany', isEqualTo: _companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    final docs = snap.docs;
    docs.sort((a, b) {
      final aTime = a.data()['created_at'];
      final bTime = b.data()['created_at'];
      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      return b.id.compareTo(a.id);
    });
    return docs;
  }

  Future<List<StatRashodRecord>> _loadBudgetArticles() {
    if (_companyId.isEmpty) return Future.value(const []);
    return queryStatRashodRecordOnce(
      queryBuilder: (q) => q.where('idCompany', isEqualTo: _companyId),
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadBudgetProjects() async {
    if (_companyId.isEmpty) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('budget_projects')
        .where('idCompany', isEqualTo: _companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    final docs = snap.docs;
    docs.sort((a, b) => (a.data()['title'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b.data()['title'] ?? '').toString().toLowerCase()));
    return docs;
  }

  Future<void> _addProject() async {
    if (_companyId.isEmpty) return;
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
    await FirebaseFirestore.instance.collection('budget_projects').add({
      'idCompany': _companyId,
      'company_id': _companyId,
      'title': title,
      'name': title,
      'description': description,
      'status': 'Активен',
      'created_by': currentUserUid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    FirestoreQueryCache.instance
        .invalidateCompanyCollection('budget_projects', _companyId);
    setState(() {
      _projectId = '';
      _projectTitle = '';
      _projectController.clear();
    });
    await _refresh();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadBranches() async {
    if (_companyId.isEmpty) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('company_branches')
        .where('idCompany', isEqualTo: _companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    final docs = snap.docs;
    docs.sort((a, b) => (a.data()['name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b.data()['name'] ?? '').toString().toLowerCase()));
    return docs;
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _refreshTick++);
  }

  List<String> _uniqueStrings(Iterable<String> values) {
    final seen = <String>{};
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && seen.add(value))
        .toList();
  }

  /*
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _customCategories() {
    if (_companyId.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('funding_request_categories')
        .where('idCompany', isEqualTo: _companyId)
        .snapshots()
        .map((snap) => snap.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _requests() {
    if (_companyId.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('funding_requests')
        .where('idCompany', isEqualTo: _companyId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs);
  }

  Stream<List<StatRashodRecord>> _budgetArticles() {
    if (_companyId.isEmpty) return const Stream.empty();
    return queryStatRashodRecord(
      queryBuilder: (q) => q.where('idCompany', isEqualTo: _companyId),
    );
  }
  */

  double _parseAmount(String raw) {
    final normalized = raw.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  String _userName() {
    final data = currentUserDocument?.snapshotData ?? const {};
    final name = (data['display_name'] ??
            data['fio'] ??
            data['name'] ??
            currentUserDisplayName)
        .toString()
        .trim();
    if (name.isNotEmpty) return name;
    if (currentPhoneNumber.trim().isNotEmpty) return currentPhoneNumber.trim();
    return currentUserEmail.trim().isEmpty ? 'Пользователь' : currentUserEmail;
  }

  String _userPosition() {
    final data = currentUserDocument?.snapshotData ?? const {};
    return (data['position'] ?? data['dolzhnost'] ?? data['role'] ?? '')
        .toString()
        .trim();
  }

  Map<String, dynamic> _signature(String role) => {
        'role': role,
        'user_id': currentUserUid,
        'name': _userName(),
        'position': _userPosition(),
        'signed_at': Timestamp.now(),
      };

  String _signatureText(dynamic raw) {
    if (raw is! Map) return 'не подписано';
    final data = Map<String, dynamic>.from(raw);
    final name = (data['name'] ?? '').toString().trim();
    final position = (data['position'] ?? '').toString().trim();
    return [
      if (name.isNotEmpty) name,
      if (position.isNotEmpty) position,
    ].join(', ');
  }

  Color _statusColor(String statusCode) {
    switch (statusCode) {
      case 'to_pay':
        return const Color(0xFF059669);
      case 'approved_by_manager':
        return const Color(0xFF2563EB);
      case 'responsible_signed':
        return const Color(0xFFD97706);
      case 'partially_paid':
        return const Color(0xFF7C3AED);
      case 'paid':
        return const Color(0xFF047857);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _signatureStageChip({
    required String title,
    required dynamic signature,
    String? approvedText,
    bool finalStage = false,
  }) {
    final signed = signature is Map;
    final color = signed
        ? (finalStage ? const Color(0xFF059669) : const Color(0xFF2563EB))
        : const Color(0xFF9CA3AF);
    final text = approvedText?.trim().isNotEmpty == true
        ? approvedText!.trim()
        : _signatureText(signature);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            signed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              '$title: $text',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: signed ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoText(List<String> parts) {
    final text = parts.where((part) => part.trim().isNotEmpty).join(' · ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: FlutterFlowTheme.of(context).bodySmall.override(
            color: FlutterFlowTheme.of(context).secondaryText,
            letterSpacing: 0,
          ),
    );
  }

  Widget _requestLines(dynamic rawLines) {
    if (rawLines is! Iterable || rawLines.isEmpty) {
      return const SizedBox.shrink();
    }
    final lines = rawLines
        .whereType<Map>()
        .map((line) => Map<String, dynamic>.from(line))
        .toList();
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Строки расходов',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 6),
        ...lines.map((line) {
          final amount = (line['amount'] as num?) ?? 0;
          final category = (line['category'] ?? '').toString();
          final article = (line['budget_article'] ?? '').toString();
          final comment = (line['comment'] ?? '').toString();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  formatMoneyWithCurrency(amount, currencyCode: 'TJS'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (category.isNotEmpty) Text('Категория: $category'),
                if (article.isNotEmpty) Text('Статья: $article'),
                if (comment.isNotEmpty) Text('Комментарий: $comment'),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<Map<String, dynamic>> _requestLineMaps(Map<String, dynamic> data) {
    final rawLines = data['lines'];
    if (rawLines is! Iterable) return const [];
    return rawLines
        .whereType<Map>()
        .map((line) => Map<String, dynamic>.from(line))
        .toList();
  }

  List<String> _requestBudgetArticles(Map<String, dynamic> data) {
    return _uniqueStrings(
      _requestLineMaps(data)
          .map((line) => (line['budget_article'] ?? '').toString().trim()),
    );
  }

  List<String> _requestCategories(Map<String, dynamic> data) {
    if (data['categories'] is Iterable) {
      return _uniqueStrings(
        (data['categories'] as Iterable).map((value) => value.toString()),
      );
    }
    return _uniqueStrings(
      _requestLineMaps(data).map((line) => (line['category'] ?? '').toString()),
    );
  }

  bool _matchesPeriod(Map<String, dynamic> data) {
    if (_registryPeriod == 'all') return true;
    final createdAt = data['created_at'];
    if (createdAt is! Timestamp) return true;
    final created = createdAt.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final createdDay = DateTime(created.year, created.month, created.day);
    switch (_registryPeriod) {
      case 'today':
        return createdDay == today;
      case 'week':
        return !createdDay.isBefore(today.subtract(const Duration(days: 7)));
      case 'two_weeks':
        return !createdDay.isBefore(today.subtract(const Duration(days: 14)));
      case 'month':
        return !createdDay.isBefore(today.subtract(const Duration(days: 30)));
      default:
        return true;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredRequests(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString();
      final project = (data['project'] ?? '').toString();
      final categories = _requestCategories(data);
      return _matchesPeriod(data) &&
          (_registryStatus == 'all' || status == _registryStatus) &&
          (_registryProject == 'all' || project == _registryProject) &&
          (_registryCategory == 'all' ||
              categories.contains(_registryCategory));
    }).toList();
  }

  List<List<String>> _requestExportRows(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final amount = (data['amount'] as num?) ?? 0;
    final paid = (data['paid_amount'] as num?) ?? 0;
    final rest = amount - paid;
    final rows = <List<String>>[
      ['Поле', 'Значение'],
      ['ID', doc.id],
      ['Дата', (data['date_text'] ?? '').toString()],
      ['Проект', (data['project'] ?? '').toString()],
      ['Филиал', (data['branch_name'] ?? data['branch'] ?? '').toString()],
      ['Подразделение', (data['department'] ?? '').toString()],
      ['Статус', (data['status'] ?? '').toString()],
      ['Сумма', amount.toString()],
      ['Оплачено', paid.toString()],
      ['Остаток', rest.toString()],
      ['Заявитель', _signatureText(data['applicant_signature'])],
      ['Ответственный', _signatureText(data['responsible_signature'])],
      ['Согласующий', _signatureText(data['approver_signature'])],
      ['Комментарий', (data['comment'] ?? '').toString()],
      ['Вложения', (data['attachments_text'] ?? '').toString()],
      [],
      ['Строки расходов'],
      ['Категория', 'Статья бюджета', 'Сумма', 'Комментарий'],
      ..._requestLineMaps(data).map((line) => [
            (line['category'] ?? '').toString(),
            (line['budget_article'] ?? '').toString(),
            ((line['amount'] as num?) ?? 0).toString(),
            (line['comment'] ?? '').toString(),
          ]),
    ];
    return buildExpenseReportExportRows(
      title: 'Заявка на финансирование',
      bodyRows: rows,
    );
  }

  List<List<String>> _registryExportRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return buildExpenseReportExportRows(
      title: 'Реестр заявок на финансирование',
      bodyRows: [
        [
          'ID',
          'Дата',
          'Проект',
          'Категории',
          'Статьи бюджета',
          'Статус',
          'Сумма',
          'Оплачено',
          'Остаток',
          'Ответственный',
        ],
        ...docs.map((doc) {
          final data = doc.data();
          final amount = (data['amount'] as num?) ?? 0;
          final paid = (data['paid_amount'] as num?) ?? 0;
          return [
            doc.id,
            (data['date_text'] ?? '').toString(),
            (data['project'] ?? '').toString(),
            _requestCategories(data).join(', '),
            _requestBudgetArticles(data).join(', '),
            (data['status'] ?? '').toString(),
            amount.toString(),
            paid.toString(),
            (amount - paid).toString(),
            _signatureText(data['responsible_signature']),
          ];
        }),
      ],
    );
  }

  Future<void> _exportRegistry(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return exportReportExcel(
      filename: 'funding-requests-register.xls',
      title: 'Реестр заявок на финансирование',
      rows: _registryExportRows(docs),
    );
  }

  Future<void> _exportRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return exportReportExcel(
      filename: 'funding-request-${doc.id}.xls',
      title: 'Заявка на финансирование',
      rows: _requestExportRows(doc),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    double width = 190,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _registryCell(String text, {bool header = false, double width = 130}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: header ? FontWeight.w800 : FontWeight.w500,
          color: header
              ? FlutterFlowTheme.of(context).primaryText
              : FlutterFlowTheme.of(context).secondaryText,
        ),
      ),
    );
  }

  Widget _requestsRegistry(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs,
  ) {
    final statuses = _uniqueStrings(
      allDocs.map((doc) => (doc.data()['status'] ?? '').toString()),
    )..sort();
    final projects = _uniqueStrings(
      allDocs.map((doc) => (doc.data()['project'] ?? '').toString()),
    )..sort();
    final categories = _uniqueStrings(
      allDocs.expand((doc) => _requestCategories(doc.data())),
    )..sort();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterDropdown(
                label: 'Период',
                value: _registryPeriod,
                width: 160,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Все')),
                  DropdownMenuItem(value: 'today', child: Text('Сегодня')),
                  DropdownMenuItem(value: 'week', child: Text('Неделя')),
                  DropdownMenuItem(value: 'two_weeks', child: Text('2 недели')),
                  DropdownMenuItem(value: 'month', child: Text('Месяц')),
                ],
                onChanged: (value) =>
                    setState(() => _registryPeriod = value ?? 'all'),
              ),
              _filterDropdown(
                label: 'Статус',
                value: statuses.contains(_registryStatus)
                    ? _registryStatus
                    : 'all',
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Все')),
                  ...statuses.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) =>
                    setState(() => _registryStatus = value ?? 'all'),
              ),
              _filterDropdown(
                label: 'Проект',
                value: projects.contains(_registryProject)
                    ? _registryProject
                    : 'all',
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Все')),
                  ...projects.map((project) => DropdownMenuItem(
                        value: project,
                        child: Text(project, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) =>
                    setState(() => _registryProject = value ?? 'all'),
              ),
              _filterDropdown(
                label: 'Категория',
                value: categories.contains(_registryCategory)
                    ? _registryCategory
                    : 'all',
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Все')),
                  ...categories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) =>
                    setState(() => _registryCategory = value ?? 'all'),
              ),
              ElevatedButton.icon(
                onPressed: filteredDocs.isEmpty
                    ? null
                    : () => _exportRegistry(filteredDocs),
                icon: const Icon(Icons.table_view_rounded),
                label: const Text('Excel реестр'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _registryCell('Дата', header: true, width: 90),
                    _registryCell('Проект', header: true, width: 150),
                    _registryCell('Категории', header: true, width: 190),
                    _registryCell('Статья бюджета', header: true, width: 180),
                    _registryCell('Статус', header: true, width: 150),
                    _registryCell('Сумма', header: true, width: 110),
                    _registryCell('Оплачено', header: true, width: 110),
                    _registryCell('Остаток', header: true, width: 110),
                    _registryCell('Ответственный', header: true, width: 180),
                  ],
                ),
                const SizedBox(height: 8),
                ...filteredDocs.map((doc) {
                  final data = doc.data();
                  final amount = (data['amount'] as num?) ?? 0;
                  final paid = (data['paid_amount'] as num?) ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: FlutterFlowTheme.of(context).alternate,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _registryCell((data['date_text'] ?? '').toString(),
                            width: 90),
                        _registryCell((data['project'] ?? '').toString(),
                            width: 150),
                        _registryCell(_requestCategories(data).join(', '),
                            width: 190),
                        _registryCell(_requestBudgetArticles(data).join(', '),
                            width: 180),
                        _registryCell((data['status'] ?? '').toString(),
                            width: 150),
                        _registryCell(
                            formatMoneyWithCurrency(amount,
                                currencyCode: 'TJS'),
                            width: 110),
                        _registryCell(
                            formatMoneyWithCurrency(paid, currencyCode: 'TJS'),
                            width: 110),
                        _registryCell(
                            formatMoneyWithCurrency(amount - paid,
                                currencyCode: 'TJS'),
                            width: 110),
                        _registryCell(
                            _signatureText(data['responsible_signature']),
                            width: 180),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory(int customCount) async {
    if (customCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Можно добавить максимум 5 новых категорий.')),
      );
      return;
    }
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название категории'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || _companyId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('funding_request_categories')
        .add({
      'idCompany': _companyId,
      'title': title,
      'custom': true,
      'created_by': currentUserUid,
      'created_at': Timestamp.now(),
    });
    await _refresh();
  }

  Future<void> _saveRequest(List<String> categories) async {
    if (!PermissionsHelper.has('funding_requests.create')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет права на создание заявок.')),
      );
      return;
    }
    if (_companyId.isEmpty || _saving) return;
    final lines = _lines
        .map((line) {
          final amount = _parseAmount(line.amountController.text);
          return {
            'category': line.category,
            'amount': amount,
            'budget_article': line.budgetArticle,
            'comment': line.commentController.text.trim(),
          };
        })
        .where((line) => (line['amount'] as double) > 0)
        .toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одну строку с суммой.')),
      );
      return;
    }
    setState(() => _saving = true);
    final total = lines.fold<double>(
      0,
      (sum, line) => sum + (line['amount'] as double),
    );
    try {
      await FirebaseFirestore.instance.collection('funding_requests').add({
        'idCompany': _companyId,
        'company_id': _companyId,
        'date_text': _dateController.text.trim(),
        'amount': total,
        'lines': lines,
        'categories': lines.map((line) => line['category']).toSet().toList(),
        'project': _projectTitle.isNotEmpty
            ? _projectTitle
            : _projectController.text.trim(),
        'project_id': _projectId,
        'branch': _branchTitle,
        'branch_id': _branchId,
        'branch_name': _branchTitle,
        'department': _departmentController.text.trim(),
        'comment': _commentController.text.trim(),
        'attachments_text': _attachmentController.text.trim(),
        'status': 'Новая',
        'status_code': 'new',
        'paid_amount': 0,
        'applicant_signature': _signature('Заявитель'),
        'created_by': currentUserUid,
        'created_by_name': _userName(),
        'created_at': Timestamp.now(),
        'updated_at': Timestamp.now(),
      });
      if (!mounted) return;
      setState(() {
        _projectController.clear();
        _projectId = '';
        _projectTitle = '';
        _branchId = '';
        _branchTitle = '';
        _departmentController.clear();
        _commentController.clear();
        _attachmentController.clear();
        for (final line in _lines) {
          line.dispose();
        }
        _lines
          ..clear()
          ..add(_FundingLineDraft()..category = categories.first);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заявка создана')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания заявки: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _projectField(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> projects,
  ) {
    if (projects.isEmpty) {
      return SizedBox(width: 260, child: _field(_projectController, 'Проект'));
    }
    final hasValue = projects.any((doc) => doc.id == _projectId);
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        value: hasValue ? _projectId : '',
        decoration: const InputDecoration(
          labelText: 'Проект',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Без проекта')),
          ...projects.map((doc) {
            final title = (doc.data()['title'] ?? 'Проект').toString();
            return DropdownMenuItem(
              value: doc.id,
              child: Text(title, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: (value) {
          final selectedId = value ?? '';
          final selected = projects.where((doc) => doc.id == selectedId);
          setState(() {
            _projectId = selectedId;
            _projectTitle = selected.isEmpty
                ? ''
                : (selected.first.data()['title'] ?? '').toString();
            _projectController.text = _projectTitle;
          });
        },
      ),
    );
  }

  Widget _branchField(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> branches,
  ) {
    if (branches.isEmpty) {
      return const SizedBox(
        width: 240,
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Филиал',
            hintText: 'Филиалы не созданы',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
    }
    final hasValue = branches.any((doc) => doc.id == _branchId);
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<String>(
        value: hasValue ? _branchId : '',
        decoration: const InputDecoration(
          labelText: 'Филиал',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Без филиала')),
          ...branches.map((doc) {
            final title = (doc.data()['name'] ?? 'Филиал').toString();
            return DropdownMenuItem(
              value: doc.id,
              child: Text(title, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: (value) {
          final selectedId = value ?? '';
          final selected = branches.where((doc) => doc.id == selectedId);
          setState(() {
            _branchId = selectedId;
            _branchTitle = selected.isEmpty
                ? ''
                : (selected.first.data()['name'] ?? '').toString();
          });
        },
      ),
    );
  }

  Widget _requestForm(
    List<String> categories,
    List<String> budgetArticles,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> projects,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> branches,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Новая заявка на деньги / финансирование',
            style: FlutterFlowTheme.of(context).titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(width: 160, child: _field(_dateController, 'Дата')),
              _projectField(projects),
              _branchField(branches),
              SizedBox(
                width: 220,
                child: _field(_departmentController, 'Подразделение'),
              ),
              SizedBox(
                  width: 320, child: _field(_attachmentController, 'Вложения')),
            ],
          ),
          const SizedBox(height: 12),
          ..._lines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final selectedCategory = categories.contains(line.category)
                ? line.category
                : categories.first;
            final selectedBudgetArticle =
                budgetArticles.contains(line.budgetArticle)
                    ? line.budgetArticle
                    : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Категория',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) => setState(
                          () => line.category = value ?? categories.first),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: line.amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Сумма',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      value: selectedBudgetArticle,
                      decoration: const InputDecoration(
                        labelText: 'Статья бюджета',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: budgetArticles
                          .map((article) => DropdownMenuItem(
                                value: article,
                                child: Text(article,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => line.budgetArticle = value ?? ''),
                    ),
                  ),
                  SizedBox(
                      width: 260,
                      child:
                          _field(line.commentController, 'Комментарий строки')),
                  IconButton(
                    tooltip: 'Удалить строку',
                    onPressed: _lines.length == 1
                        ? null
                        : () => setState(() {
                              _lines.removeAt(index).dispose();
                            }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _lines.add(_FundingLineDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Добавить строку расхода'),
          ),
          const SizedBox(height: 8),
          _field(_commentController, 'Комментарий к заявке'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _saveRequest(categories),
              icon: const Icon(Icons.send_rounded),
              label: Text(_saving ? 'Сохранение...' : 'Создать заявку'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestsList() {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      key: ValueKey('requests-$_refreshTick-$_companyId'),
      future: _loadRequests(),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? const [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Заявок пока нет'),
          );
        }
        final filteredDocs = _filteredRequests(docs);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _requestsRegistry(docs, filteredDocs),
            const SizedBox(height: 14),
            if (filteredDocs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('По выбранным фильтрам заявок нет'),
              ),
            ...filteredDocs.map((doc) {
              final data = doc.data();
              final amount = (data['amount'] as num?) ?? 0;
              final paid = (data['paid_amount'] as num?) ?? 0;
              final rest = amount - paid;
              final status = (data['status'] ?? 'Новая').toString();
              final statusCode = (data['status_code'] ?? 'new').toString();
              final statusColor = _statusColor(statusCode);
              final canResponsible =
                  PermissionsHelper.has('funding_requests.responsible_sign');
              final canApprove =
                  PermissionsHelper.has('funding_requests.approve');
              final canFinalApprove =
                  PermissionsHelper.has('funding_requests.final_approve');
              final dateText = (data['date_text'] ?? '').toString();
              final project = (data['project'] ?? '').toString();
              final branch =
                  (data['branch_name'] ?? data['branch'] ?? '').toString();
              final department = (data['department'] ?? '').toString();
              final categories = (data['categories'] is Iterable)
                  ? (data['categories'] as Iterable).join(', ')
                  : '';
              final comment = (data['comment'] ?? '').toString();
              final attachments = (data['attachments_text'] ?? '').toString();
              final finalApproval = data['final_approval'] is Map
                  ? Map<String, dynamic>.from(data['final_approval'] as Map)
                  : const <String, dynamic>{};
              final finalDecision =
                  (finalApproval['decision'] ?? finalApproval['name'] ?? '')
                      .toString();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatMoneyWithCurrency(amount,
                                  currencyCode: 'TJS'),
                              style: FlutterFlowTheme.of(context).titleMedium,
                            ),
                          ),
                          Chip(
                            label: Text(status),
                            backgroundColor:
                                statusColor.withValues(alpha: 0.12),
                            side: BorderSide(
                                color: statusColor.withValues(alpha: 0.45)),
                            labelStyle: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _infoText([
                        if (dateText.isNotEmpty) 'Дата: $dateText',
                        if (project.isNotEmpty) 'Проект: $project',
                        if (branch.isNotEmpty) 'Филиал: $branch',
                        if (department.isNotEmpty) 'Подразделение: $department',
                        if (categories.isNotEmpty) 'Категории: $categories',
                        'Оплачено: ${formatMoneyWithCurrency(paid, currencyCode: 'TJS')}',
                        'Остаток: ${formatMoneyWithCurrency(rest, currencyCode: 'TJS')}',
                      ]),
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _infoText(['Вложения: $attachments']),
                      ],
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Комментарий: $comment'),
                      ],
                      _requestLines(data['lines']),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _signatureStageChip(
                            title: 'Заявитель',
                            signature: data['applicant_signature'],
                          ),
                          _signatureStageChip(
                            title: 'Ответственный',
                            signature: data['responsible_signature'],
                          ),
                          _signatureStageChip(
                            title: 'Согласующий',
                            signature: data['approver_signature'],
                          ),
                          _signatureStageChip(
                            title: 'Финальное',
                            signature: finalApproval.isEmpty
                                ? null
                                : {'name': 'Давлатов С.Р.'},
                            approvedText: finalDecision.isEmpty
                                ? 'ожидает решения'
                                : finalDecision,
                            finalStage: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _exportRequest(doc),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Excel заявка'),
                          ),
                          OutlinedButton.icon(
                            onPressed: !canResponsible ||
                                    data['responsible_signature'] is Map
                                ? null
                                : () async {
                                    await doc.reference.update({
                                      'responsible_signature':
                                          _signature('Ответственное лицо'),
                                      'status': 'Подписал ответственный',
                                      'status_code': 'responsible_signed',
                                      'updated_at': Timestamp.now(),
                                    });
                                    await _refresh();
                                  },
                            icon: const Icon(Icons.draw_outlined),
                            label: const Text('Подписал ответственный'),
                          ),
                          OutlinedButton.icon(
                            onPressed: !canApprove ||
                                    data['responsible_signature'] is! Map ||
                                    data['approver_signature'] is Map
                                ? null
                                : () async {
                                    await doc.reference.update({
                                      'approver_signature':
                                          _signature('Согласовывающий'),
                                      'status': 'Согласовано',
                                      'status_code': 'approved_by_manager',
                                      'updated_at': Timestamp.now(),
                                    });
                                    await _refresh();
                                  },
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Подписал согласующий'),
                          ),
                          ElevatedButton.icon(
                            onPressed: !canFinalApprove ||
                                    data['approver_signature'] is! Map ||
                                    statusCode == 'to_pay'
                                ? null
                                : () async {
                                    await doc.reference.update({
                                      'final_approval': {
                                        'name': 'Давлатов С.Р.',
                                        'decision': 'Одобрено Давлатов С.Р.',
                                        'approved_at': Timestamp.now(),
                                      },
                                      'status': 'К оплате',
                                      'status_code': 'to_pay',
                                      'updated_at': Timestamp.now(),
                                    });
                                    await _refresh();
                                  },
                            icon: const Icon(Icons.payment_rounded),
                            label: const Text('Одобрено Давлатов С.Р.'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final canCreateFundingRequest =
        PermissionsHelper.has('funding_requests.create');
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      drawer: Drawer(elevation: 16, child: DrawersUsersWidget()),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (responsiveVisibility(
                context: context, phone: false, tablet: false))
              Container(
                width: FFAppState().userSidebarCollapsed ? 88 : 270,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  border:
                      Border.all(color: FlutterFlowTheme.of(context).alternate),
                ),
                child: DrawersUsersWidget(),
              ),
            Expanded(
              child: Column(
                children: [
                  HeaderWidget(
                    title: 'Заявки на деньги',
                    trailing: IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => scaffoldKey.currentState?.openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: FutureBuilder<
                          List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                        key: ValueKey('categories-$_refreshTick-$_companyId'),
                        future: _loadCustomCategories(),
                        builder: (context, categorySnap) {
                          final customDocs = categorySnap.data ?? const [];
                          final categories = _uniqueStrings([
                            ...defaultCategories,
                            ...customDocs
                                .map((doc) =>
                                    (doc.data()['title'] ?? '').toString())
                                .where((title) => title.isNotEmpty),
                          ]);
                          return FutureBuilder<List<StatRashodRecord>>(
                            key: ValueKey('budget-$_refreshTick-$_companyId'),
                            future: _loadBudgetArticles(),
                            builder: (context, budgetSnap) {
                              final budgetArticles = _uniqueStrings(
                                  (budgetSnap.data ??
                                          const <StatRashodRecord>[])
                                      .map((e) => e.title))
                                ..sort();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (canCreateFundingRequest) ...[
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _addCategory(customDocs.length),
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          label: Text(
                                              'Добавить категорию (${customDocs.length}/5)'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: _addProject,
                                          icon: const Icon(
                                              Icons.work_outline_rounded),
                                          label: const Text('Добавить проект'),
                                        ),
                                      ],
                                    ),
                                    FutureBuilder<
                                        List<
                                            QueryDocumentSnapshot<
                                                Map<String, dynamic>>>>(
                                      key: ValueKey(
                                          'projects-$_refreshTick-$_companyId'),
                                      future: _loadBudgetProjects(),
                                      builder: (context, projectSnap) =>
                                          FutureBuilder<
                                              List<
                                                  QueryDocumentSnapshot<
                                                      Map<String, dynamic>>>>(
                                        key: ValueKey(
                                            'branches-$_refreshTick-$_companyId'),
                                        future: _loadBranches(),
                                        builder: (context, branchSnap) =>
                                            _requestForm(
                                          categories,
                                          budgetArticles,
                                          projectSnap.data ?? const [],
                                          branchSnap.data ?? const [],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  Text('Заявки',
                                      style: FlutterFlowTheme.of(context)
                                          .titleMedium),
                                  const SizedBox(height: 8),
                                  _requestsList(),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
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
