// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '/company/company_setup/company_setup_widget.dart';
import '/setting/rekviziti/rekviziti_widget.dart';
import '/setting/roli/roli_widget.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/default_company_roles.dart';
import '/utils/effective_company_support.dart';
import '/utils/country_profile.dart';
import '/utils/onboarding_progress.dart';
import '/utils/role_assignment_support.dart';

class CompanyOrgStructureWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final int? initialViewTab;
  final bool lockViewTab;

  const CompanyOrgStructureWidget({
    Key? key,
    this.width,
    this.height,
    this.initialViewTab,
    this.lockViewTab = false,
  }) : super(key: key);

  @override
  State<CompanyOrgStructureWidget> createState() =>
      _CompanyOrgStructureWidgetState();
}

class _CompanyOrgStructureWidgetState extends State<CompanyOrgStructureWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _companies = [];
  String? _selectedCompanyId;
  int _viewTab = 0;
  final Map<String, Offset> _companyLayouts = {};
  Size _companyCanvasSize = Size.zero;
  bool _companyLayoutReady = false;
  final Map<String, List<Map<String, dynamic>>> _employeesByCompany = {};
  final Map<String, List<Map<String, dynamic>>> _usersByCompany = {};
  final Map<String, List<Map<String, dynamic>>> _rolesByCompany = {};
  final Map<String, List<Map<String, dynamic>>> _positionsByCompany = {};
  final Set<String> _expandedPositionKeys = <String>{};
  final Map<String, Map<String, Offset>> _employeeLayouts = {};
  final Map<String, Size> _canvasSizes = {};
  StreamSubscription<UsersRecord?>? _userDocSubscription;
  int _loadSequence = 0;
  static const double _nodeSize = 120.0;
  static const List<String> _companyColorPalette = [
    '#E0F2FE',
    '#DCFCE7',
    '#FEF3C7',
    '#FCE7F3',
    '#EDE9FE',
    '#FFE4E6',
    '#CCFBF1',
    '#F3F4F6',
  ];

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  Color get _panelSurface => _isDarkTheme
      ? Color.alphaBlend(
          Colors.white.withValues(alpha: 0.03),
          FlutterFlowTheme.of(context).secondaryBackground,
        )
      : FlutterFlowTheme.of(context).secondaryBackground;

  Color get _panelBorder => _isDarkTheme
      ? FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.42)
      : FlutterFlowTheme.of(context).alternate;

  Color get _mutedText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.72)
      : FlutterFlowTheme.of(context).secondaryText;

  Color get _softText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.58)
      : const Color(0xFF6B7280);

  Color _companyColorFromHex(String? hex) {
    final value = (hex ?? '').trim().replaceAll('#', '');
    if (value.length == 6) {
      final parsed = int.tryParse(value, radix: 16);
      if (parsed != null) return Color(0xFF000000 | parsed);
    }
    return const Color(0xFFE0F2FE);
  }

  String _companyColorHex(Map<String, dynamic> data) {
    final value =
        (data['company_color'] ?? data['companyColor'] ?? '').toString().trim();
    return value.isEmpty ? '#E0F2FE' : value;
  }

  Color _companyBorderColor(Color color, bool isActive) {
    if (isActive) return FlutterFlowTheme.of(context).primary;
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialViewTab ?? 0;
    _viewTab = initial.clamp(0, 1);
    _loadData();
    _userDocSubscription = authenticatedUserStream.listen((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CompanyOrgStructureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialViewTab != oldWidget.initialViewTab &&
        widget.lockViewTab) {
      final initial = widget.initialViewTab ?? 0;
      _viewTab = initial.clamp(0, 1);
    }
  }

  bool _looksLikeRole(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    if (type == 'position') return false;
    if (type == 'role') return true;
    if (data['permissions'] is List) return true;
    if (data['allowed_company_ids'] is List) return true;
    return false;
  }

  String _roleNameKey(Map<String, dynamic> data) {
    final name = (data['name_key'] ?? data['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return 'id:${(data['id'] ?? '').toString().trim()}';
    }
    return name.toLowerCase();
  }

  String _companyDisplayName(Map<String, dynamic> data,
      {String fallback = ''}) {
    const fields = [
      'name',
      'nameCompany',
      'name_Company',
      'company_name',
      'title',
      'companyTitle',
    ];
    for (final field in fields) {
      final value = (data[field] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'компания') {
        return value;
      }
    }
    final fallbackValue = fallback.trim();
    return fallbackValue.isEmpty ? 'Компания' : fallbackValue;
  }

  List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final single = value?.toString().trim() ?? '';
    return single.isEmpty ? <String>[] : <String>[single];
  }

  bool _hasCompanyFieldValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  Map<String, dynamic> _mergeCompanyEditData(
    Map<String, dynamic> company,
    Map<String, dynamic> profile,
  ) {
    final merged = Map<String, dynamic>.from(company);
    profile.forEach((key, value) {
      if (_hasCompanyFieldValue(value)) {
        merged[key] = value;
      }
    });
    return merged;
  }

  Future<String> _dictionaryTitle(dynamic value) async {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is DocumentReference) {
      final snap =
          await value.get(const GetOptions(source: Source.serverAndCache));
      final data = snap.data();
      if (data is Map<String, dynamic>) {
        return _dictionaryTitleFromMap(data);
      }
      if (data is Map) {
        return _dictionaryTitleFromMap(Map<String, dynamic>.from(data));
      }
      return '';
    }
    if (value is Map<String, dynamic>) {
      return _dictionaryTitleFromMap(value);
    }
    if (value is Map) {
      return _dictionaryTitleFromMap(Map<String, dynamic>.from(value));
    }
    return value.toString().trim();
  }

  String _dictionaryTitleFromMap(Map<String, dynamic> data) {
    const fields = ['title', 'name', 'label', 'value'];
    for (final field in fields) {
      final value = (data[field] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<List<String>> _dictionaryTitleList(dynamic value) async {
    if (value is Iterable) {
      final titles = <String>[];
      for (final item in value) {
        final title = await _dictionaryTitle(item);
        if (title.isNotEmpty && !titles.contains(title)) {
          titles.add(title);
        }
      }
      return titles;
    }
    final title = await _dictionaryTitle(value);
    return title.isEmpty ? <String>[] : <String>[title];
  }

  String _defaultCurrencyTitle(
    List<ValutaRecord> items, {
    String countryCode = 'KZ',
  }) {
    if (items.isEmpty) return '';
    final baseCurrency = countryProfileForCode(countryCode).baseCurrency;
    for (final item in items) {
      final code = normalizeCurrencyCode(item.kod);
      final title = item.title.trim().toLowerCase();
      if (code == baseCurrency || title == baseCurrency.toLowerCase()) {
        return item.title;
      }
    }
    for (final item in items) {
      final title = item.title.trim().toLowerCase();
      if (countryCode == 'KZ' &&
          (title.contains('тенге') || title.contains('kzt'))) {
        return item.title;
      }
      if (countryCode == 'TJ' &&
          (title.contains('сомони') || title.contains('tjs'))) {
        return item.title;
      }
    }
    return items.first.title;
  }

  bool _dictionaryMatchesCountry(Map<String, dynamic> data, String code) {
    final explicit =
        (data['country_code'] ?? data['countryCode'] ?? '').toString().trim();
    if (explicit.isEmpty && code == 'KZ') return true;
    return countryProfileFromData(data).countryCode == code;
  }

  int _roleScore(Map<String, dynamic> data) {
    final permissionsRaw = data['permissions'];
    final permissionsCount = permissionsRaw is List
        ? permissionsRaw.where((e) => e != null).length
        : 0;
    final hasDescription =
        (data['description'] ?? '').toString().trim().isNotEmpty ? 1 : 0;
    return permissionsCount * 10 + hasDescription;
  }

  List<Map<String, dynamic>> _dedupeRoles(Iterable<Map<String, dynamic>> rows) {
    final byName = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      if (!_looksLikeRole(row)) continue;
      final key = _roleNameKey(row);
      final current = byName[key];
      if (current == null || _roleScore(row) > _roleScore(current)) {
        byName[key] = row;
      }
    }
    final list = byName.values.toList()
      ..sort((a, b) =>
          (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return list;
  }

  bool _looksLikePosition(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    return type == 'position';
  }

  Map<String, dynamic> _readCompanyLayoutRaw() {
    final raw = currentUserDocument?.snapshotData['company_layout'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  Offset _clampCompanyOffset(Offset value, Size size, double nodeSize) {
    final maxX = (size.width - nodeSize).clamp(0.0, size.width);
    final maxY = (size.height - nodeSize).clamp(0.0, size.height);
    final dx = value.dx.clamp(0.0, maxX);
    final dy = value.dy.clamp(0.0, maxY);
    return Offset(dx, dy);
  }

  void _ensureCompanyLayout(Size size, List<Map<String, dynamic>> nodes) {
    if (size.isEmpty || nodes.isEmpty) return;
    final nodeSize = 120.0;
    final ids = nodes.map((node) => (node['id'] ?? '').toString()).toList();
    final needsReset = !_companyLayoutReady ||
        _companyCanvasSize != size ||
        !_companyLayouts.keys.toSet().containsAll(ids);
    if (!needsReset) {
      _companyCanvasSize = size;
      return;
    }
    final raw = _readCompanyLayoutRaw();
    final next = <String, Offset>{};
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final rawPos = raw[id];
      if (rawPos is Map) {
        final x = (rawPos['x'] as num?)?.toDouble();
        final y = (rawPos['y'] as num?)?.toDouble();
        if (x != null && y != null) {
          final dx = x * size.width;
          final dy = y * size.height;
          next[id] = _clampCompanyOffset(Offset(dx, dy), size, nodeSize);
          continue;
        }
      }
    }
    final missing = ids.where((id) => !next.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      final missingNodes = nodes
          .where((node) => missing.contains((node['id'] ?? '').toString()))
          .toList();
      final branches = missingNodes
          .where((node) => (node['type'] ?? '').toString() == 'branch')
          .toList();
      final departments = missingNodes
          .where((node) => (node['type'] ?? '').toString() == 'department')
          .toList();
      final companies = missingNodes
          .where((node) => (node['type'] ?? '').toString() == 'company')
          .toList();
      for (var i = 0; i < companies.length; i++) {
        final id = (companies[i]['id'] ?? '').toString();
        final dx = size.width / 2 - nodeSize / 2 + (i * 18);
        next[id] = _clampCompanyOffset(Offset(dx, 28), size, nodeSize);
      }
      void placeRow(List<Map<String, dynamic>> row, double y) {
        if (row.isEmpty) return;
        final gap = size.width / (row.length + 1);
        for (var i = 0; i < row.length; i++) {
          final id = (row[i]['id'] ?? '').toString();
          final dx = gap * (i + 1) - nodeSize / 2;
          next[id] = _clampCompanyOffset(Offset(dx, y), size, nodeSize);
        }
      }

      placeRow(branches, 170);
      placeRow(departments, 300);
      final others = missingNodes
          .where((node) => !next.containsKey((node['id'] ?? '').toString()))
          .toList();
      placeRow(others, 250);
    }
    final activeIds = ids.toSet();
    _companyLayouts.removeWhere((key, value) => !activeIds.contains(key));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _companyCanvasSize = size;
        _companyLayouts.addAll(next);
        _companyLayoutReady = true;
      });
    });
  }

  List<Map<String, dynamic>> _businessStructureNodes(
    Map<String, dynamic> company,
  ) {
    final companyId = (company['id'] ?? '').toString();
    final nodes = <Map<String, dynamic>>[
      {
        'id': 'company:$companyId',
        'type': 'company',
        'name': _companyDisplayName(company),
        'company_id': companyId,
        'color': _companyColorHex(company),
      }
    ];
    final branches = <String>{};
    final rawBranchNames = company['branch_names'];
    if (rawBranchNames is Iterable) {
      for (final item in rawBranchNames) {
        final name = item.toString().trim();
        if (name.isNotEmpty) branches.add(name);
      }
    }
    final rawBranches = company['branches'];
    if (rawBranches is Iterable) {
      for (final item in rawBranches) {
        final name = item is Map
            ? (item['name'] ?? '').toString().trim()
            : item.toString().trim();
        if (name.isNotEmpty) branches.add(name);
      }
    }
    for (final name in branches) {
      nodes.add({
        'id': 'branch:$companyId:$name',
        'type': 'branch',
        'name': name,
        'parent_id': 'company:$companyId',
      });
    }
    final rawDepartments = company['departments'];
    if (rawDepartments is Iterable) {
      for (final item in rawDepartments) {
        if (item is! Map) continue;
        final name = (item['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final branch =
            (item['branch'] ?? item['branch_name'] ?? '').toString().trim();
        nodes.add({
          'id': 'department:$companyId:$name:$branch',
          'type': 'department',
          'name': name,
          'parent_id': branch.isEmpty
              ? 'company:$companyId'
              : 'branch:$companyId:$branch',
          'branch': branch,
        });
      }
    }
    return nodes;
  }

  Future<void> _saveCompanyLayout() async {
    if (currentUserReference == null || _companyCanvasSize.isEmpty) return;
    final data = <String, dynamic>{};
    _companyLayouts.forEach((id, offset) {
      final nx = _companyCanvasSize.width == 0
          ? 0
          : offset.dx / _companyCanvasSize.width;
      final ny = _companyCanvasSize.height == 0
          ? 0
          : offset.dy / _companyCanvasSize.height;
      data[id] = {
        'x': nx.clamp(0.0, 1.0),
        'y': ny.clamp(0.0, 1.0),
      };
    });
    await currentUserReference!.update({'company_layout': data});
  }

  Future<void> _setActiveCompany(String companyId) async {
    if (currentUserReference == null) return;
    await currentUserReference!.update({
      'idCompany': companyId,
      'activeCompanyId': companyId,
      'companyScope': 'single',
      'companyIds': FieldValue.arrayUnion([companyId]),
    });
    OnboardingProgress.invalidate(authUid: currentUserUid);
  }

  Future<void> _copyCompanyId(String companyId) async {
    final id = companyId.trim();
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID компании скопирован')),
    );
  }

  String _ownerDisplayName() {
    final data = currentUserDocument?.snapshotData ?? const {};
    final displayName = (data['owner_display_name'] ?? currentUserDisplayName)
        .toString()
        .trim();
    if (displayName.isNotEmpty) return displayName;
    final phone = currentPhoneNumber.trim();
    if (phone.isNotEmpty) return phone;
    final email = currentUserEmail.trim();
    if (email.isNotEmpty) return email;
    return 'Собственник';
  }

  String _ownerTitle() {
    final data = currentUserDocument?.snapshotData ?? const {};
    final title = (data['owner_title'] ?? '').toString().trim();
    return title.isEmpty ? 'Собственник' : title;
  }

  Future<void> _showOwnerDialog() async {
    if (currentUserReference == null) return;
    final nameController = TextEditingController(
      text: _ownerDisplayName(),
    );
    final titleController = TextEditingController(text: _ownerTitle());
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Собственник'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Имя / наименование владельца',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Роль / подпись',
                  border: OutlineInputBorder(),
                ),
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
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (saved != true) return;
      final name = nameController.text.trim();
      final title = titleController.text.trim();
      if (name.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите имя собственника')),
        );
        return;
      }
      await currentUserReference!.update({
        'display_name': name,
        'owner_display_name': name,
        'owner_title': title.isEmpty ? 'Собственник' : title,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Собственник обновлен')),
      );
      setState(() {});
    } finally {
      nameController.dispose();
      titleController.dispose();
    }
  }

  Widget _buildInstantToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final activeColor = FlutterFlowTheme.of(context).primary;
    final backgroundColor = value
        ? activeColor.withValues(alpha: 0.10)
        : FlutterFlowTheme.of(context).secondaryBackground;
    final borderColor = value
        ? activeColor
        : FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.8);
    return InkWell(
      borderRadius: BorderRadius.circular(12.0),
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 8.0, 8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: borderColor,
            width: value ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: value
                      ? activeColor
                      : FlutterFlowTheme.of(context).primaryText,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 46,
              height: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: value
                    ? activeColor
                    : FlutterFlowTheme.of(context)
                        .alternate
                        .withValues(alpha: 0.9),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled
                        ? Colors.white
                        : FlutterFlowTheme.of(context).secondaryText,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                        color: Colors.black.withValues(alpha: 0.20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyColorPicker({
    required String value,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlutterFlowTheme.of(context).primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Цвет блока компании',
            style: TextStyle(
              color: FlutterFlowTheme.of(context).primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _companyColorPalette.map((hex) {
              final selected = hex.toLowerCase() == value.toLowerCase();
              final color = _companyColorFromHex(hex);
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: enabled ? () => onChanged(hex) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? FlutterFlowTheme.of(context).primary
                          : _companyBorderColor(color, false),
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: FlutterFlowTheme.of(context).primaryText,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompanyEditDialog(Map<String, dynamic> company) async {
    final companyId = (company['id'] ?? '').toString().trim();
    if (companyId.isEmpty) return;
    final profileSnap = await _firestore
        .collection('company_profile')
        .doc(companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    final profileData = profileSnap.data() ?? const <String, dynamic>{};
    final editData = _mergeCompanyEditData(company, profileData);
    final editCountryCode = countryProfileFromData(editData).countryCode;
    final editCountryProfile = countryProfileForCode(editCountryCode);
    final nameController = TextEditingController(
      text: _companyDisplayName(editData, fallback: ''),
    );
    final binController =
        TextEditingController(text: (editData['bin'] ?? '').toString());
    final addressController =
        TextEditingController(text: (editData['address'] ?? '').toString());
    var ocedValues = await _dictionaryTitleList(editData['oced']);
    if (ocedValues.isEmpty) {
      ocedValues = _stringList(editData['oced']);
    }
    var otraslValue = await _dictionaryTitle(editData['otrasl']);
    var formaValue = await _dictionaryTitle(editData['forma']);
    var nalogValue = await _dictionaryTitle(editData['nalog']);
    var valutaValue = await _dictionaryTitle(editData['valuta']);
    var companyColorValue = _companyColorHex(editData);
    final ocedController = FormListFieldController<String>(ocedValues);
    final otraslController =
        FormFieldController<String>(otraslValue.isEmpty ? null : otraslValue);
    final formaController =
        FormFieldController<String>(formaValue.isEmpty ? null : formaValue);
    final nalogController =
        FormFieldController<String>(nalogValue.isEmpty ? null : nalogValue);
    final valutaController =
        FormFieldController<String>(valutaValue.isEmpty ? null : valutaValue);
    bool nds = editData['ndsPayer'] == true || editData['nds_payer'] == true;
    bool buhEnabled = editData['buh_enabled'] == true ||
        editData['buhEnabled'] == true ||
        editData['buh'] == true;
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Редактировать компанию'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Название',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildCompanyColorPicker(
                      value: companyColorValue,
                      enabled: !saving,
                      onChanged: (value) => setDialogState(
                        () => companyColorValue = value,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: binController,
                      decoration: const InputDecoration(
                        hintText: 'БИН/ИНН',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        hintText: 'Адрес',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AuthUserStreamWidget(
                      builder: (context) => Column(
                        children: [
                          Builder(
                            builder: (context) {
                              return StreamBuilder<List<OcedRecord>>(
                                stream: queryOcedRecord(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final options = snapshot.data!
                                      .where(
                                          (record) => _dictionaryMatchesCountry(
                                                record.snapshotData,
                                                editCountryCode,
                                              ))
                                      .map((record) => record.title)
                                      .toList();
                                  final extra = ocedValues
                                      .where(
                                          (value) => !options.contains(value))
                                      .toList();
                                  return FlutterFlowDropDown<String>(
                                    key: ValueKey(
                                      'company-edit-oced-${ocedValues.join('|')}',
                                    ),
                                    multiSelectController: ocedController,
                                    options: [...options, ...extra],
                                    width: double.infinity,
                                    height: 49.0,
                                    searchHintTextStyle:
                                        FlutterFlowTheme.of(context)
                                            .labelMedium,
                                    searchTextStyle:
                                        FlutterFlowTheme.of(context).bodyMedium,
                                    textStyle:
                                        FlutterFlowTheme.of(context).bodyMedium,
                                    hintText: 'ОКЭД',
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 24.0,
                                    ),
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    elevation: 2.0,
                                    borderColor:
                                        FlutterFlowTheme.of(context).primary,
                                    borderWidth: 1.0,
                                    borderRadius: 8.0,
                                    margin:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                    hidesUnderline: true,
                                    isOverButton: false,
                                    isSearchable: true,
                                    isMultiSelect: true,
                                    onMultiSelectChanged: saving
                                        ? null
                                        : (val) => setDialogState(() {
                                              ocedValues = val ?? [];
                                              ocedController.value = ocedValues;
                                              ocedController.update();
                                            }),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          StreamBuilder<List<OtrasliRecord>>(
                            stream: queryOtrasliRecord(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final options = snapshot.data!
                                  .where((record) => _dictionaryMatchesCountry(
                                        record.snapshotData,
                                        editCountryCode,
                                      ))
                                  .map((record) => record.title)
                                  .toList();
                              return FlutterFlowDropDown<String>(
                                key: ValueKey(
                                  'company-edit-otrasl-$otraslValue',
                                ),
                                controller: otraslController,
                                options: [
                                  ...options,
                                  if (otraslValue.isNotEmpty &&
                                      !options.contains(otraslValue))
                                    otraslValue,
                                ],
                                onChanged: saving
                                    ? null
                                    : (val) => setDialogState(() {
                                          otraslValue = val ?? '';
                                          otraslController.value = val;
                                        }),
                                width: double.infinity,
                                height: 49.0,
                                textStyle:
                                    FlutterFlowTheme.of(context).bodyMedium,
                                hintText: 'Отрасль',
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  size: 24.0,
                                ),
                                fillColor: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                elevation: 2.0,
                                borderColor:
                                    FlutterFlowTheme.of(context).primary,
                                borderWidth: 1.0,
                                borderRadius: 8.0,
                                margin: const EdgeInsetsDirectional.fromSTEB(
                                    12.0, 0.0, 12.0, 0.0),
                                hidesUnderline: true,
                                isOverButton: false,
                                isSearchable: true,
                                isMultiSelect: false,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              return StreamBuilder<List<FormaRecord>>(
                                stream: queryFormaRecord(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final options = snapshot.data!
                                      .where(
                                          (record) => _dictionaryMatchesCountry(
                                                record.snapshotData,
                                                editCountryCode,
                                              ))
                                      .map((record) => record.title)
                                      .toList();
                                  return FlutterFlowDropDown<String>(
                                    key: ValueKey(
                                      'company-edit-forma-$formaValue',
                                    ),
                                    controller: formaController,
                                    options: [
                                      ...options,
                                      if (formaValue.isNotEmpty &&
                                          !options.contains(formaValue))
                                        formaValue,
                                    ],
                                    onChanged: saving
                                        ? null
                                        : (val) => setDialogState(() {
                                              formaValue = val ?? '';
                                              formaController.value = val;
                                            }),
                                    width: double.infinity,
                                    height: 49.0,
                                    textStyle:
                                        FlutterFlowTheme.of(context).bodyMedium,
                                    hintText: 'Форма собственности',
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 24.0,
                                    ),
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    elevation: 2.0,
                                    borderColor:
                                        FlutterFlowTheme.of(context).primary,
                                    borderWidth: 1.0,
                                    borderRadius: 8.0,
                                    margin:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                    hidesUnderline: true,
                                    isOverButton: false,
                                    isSearchable: true,
                                    isMultiSelect: false,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              return StreamBuilder<List<NalogiRecord>>(
                                stream: queryNalogiRecord(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final options = snapshot.data!
                                      .where(
                                          (record) => _dictionaryMatchesCountry(
                                                record.snapshotData,
                                                editCountryCode,
                                              ))
                                      .map((record) => record.title)
                                      .toList();
                                  return FlutterFlowDropDown<String>(
                                    key: ValueKey(
                                      'company-edit-nalog-$nalogValue',
                                    ),
                                    controller: nalogController,
                                    options: [
                                      ...options,
                                      if (nalogValue.isNotEmpty &&
                                          !options.contains(nalogValue))
                                        nalogValue,
                                    ],
                                    onChanged: saving
                                        ? null
                                        : (val) => setDialogState(() {
                                              nalogValue = val ?? '';
                                              nalogController.value = val;
                                            }),
                                    width: double.infinity,
                                    height: 49.0,
                                    textStyle:
                                        FlutterFlowTheme.of(context).bodyMedium,
                                    hintText: 'Налоговый режим',
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 24.0,
                                    ),
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    elevation: 2.0,
                                    borderColor:
                                        FlutterFlowTheme.of(context).primary,
                                    borderWidth: 1.0,
                                    borderRadius: 8.0,
                                    margin:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                    hidesUnderline: true,
                                    isOverButton: false,
                                    isSearchable: true,
                                    isMultiSelect: false,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          StreamBuilder<List<ValutaRecord>>(
                            stream: queryValutaRecord(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final list = snapshot.data!
                                  .where((record) => _dictionaryMatchesCountry(
                                        record.snapshotData,
                                        editCountryCode,
                                      ))
                                  .toList();
                              final options =
                                  list.map((record) => record.title).toList();
                              if (valutaValue.isEmpty) {
                                final preferred =
                                    editCountryProfile.baseCurrency;
                                final match = list.where((record) {
                                  final code =
                                      normalizeCurrencyCode(record.kod);
                                  return code == preferred;
                                }).toList();
                                valutaValue = match.isNotEmpty
                                    ? match.first.title
                                    : _defaultCurrencyTitle(
                                        list,
                                        countryCode: editCountryCode,
                                      );
                                valutaController.value = valutaValue;
                              }
                              return FlutterFlowDropDown<String>(
                                key: ValueKey(
                                  'company-edit-valuta-$valutaValue',
                                ),
                                controller: valutaController,
                                options: [
                                  ...options,
                                  if (valutaValue.isNotEmpty &&
                                      !options.contains(valutaValue))
                                    valutaValue,
                                ],
                                onChanged: saving
                                    ? null
                                    : (val) => setDialogState(() {
                                          valutaValue = val ?? '';
                                          valutaController.value = val;
                                        }),
                                width: double.infinity,
                                height: 49.0,
                                textStyle:
                                    FlutterFlowTheme.of(context).bodyMedium,
                                hintText: 'Валюта',
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  size: 24.0,
                                ),
                                fillColor: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                elevation: 2.0,
                                borderColor:
                                    FlutterFlowTheme.of(context).primary,
                                borderWidth: 1.0,
                                borderRadius: 8.0,
                                margin: const EdgeInsetsDirectional.fromSTEB(
                                    12.0, 0.0, 12.0, 0.0),
                                hidesUnderline: true,
                                isOverButton: false,
                                isSearchable: true,
                                isMultiSelect: false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInstantToggle(
                      title: 'Плательщик НДС',
                      value: nds,
                      enabled: !saving,
                      onChanged: (val) => setDialogState(() => nds = val),
                    ),
                    const SizedBox(height: 8),
                    _buildInstantToggle(
                      title: 'Ведет бухгалтерский учет',
                      value: buhEnabled,
                      enabled: !saving,
                      onChanged: (val) =>
                          setDialogState(() => buhEnabled = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final bin = binController.text.trim();
                        if (name.isEmpty || bin.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Заполните название и БИН/ИНН'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        final update = {
                          'name': name,
                          'bin': bin,
                          'address': addressController.text.trim(),
                          'country_code': editCountryProfile.countryCode,
                          'countryCode': editCountryProfile.countryCode,
                          'base_currency': editCountryProfile.baseCurrency,
                          'baseCurrency': editCountryProfile.baseCurrency,
                          'company_currency': editCountryProfile.baseCurrency,
                          'companyCurrency': editCountryProfile.baseCurrency,
                          'currency_symbol': editCountryProfile.currencySymbol,
                          'currencySymbol': editCountryProfile.currencySymbol,
                          'oced': ocedValues,
                          'otrasl': otraslValue,
                          'forma': formaValue,
                          'nalog': nalogValue,
                          'valuta': valutaValue,
                          'company_color': companyColorValue,
                          'companyColor': companyColorValue,
                          'ndsPayer': nds,
                          'nds_payer': nds,
                          'buh_enabled': buhEnabled,
                          'buhEnabled': buhEnabled,
                          'buh': buhEnabled,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        try {
                          await _firestore
                              .collection('companies')
                              .doc(companyId)
                              .set(update, SetOptions(merge: true));
                          await _firestore
                              .collection('company_profile')
                              .doc(companyId)
                              .set({
                            'idCompany': companyId,
                            'user_id': currentUserUid,
                            ...update,
                            'updated_at': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                          if (companyId == _preferredCompanyId(_companies)) {
                            await currentUserReference?.update({
                              'name_Company': name,
                            });
                          }
                          await _loadData();
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Компания обновлена'),
                            ),
                          );
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Не удалось сохранить компанию: $e'),
                            ),
                          );
                        }
                      },
                child: Text(saving ? 'Сохранение...' : 'Сохранить'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
      binController.dispose();
      addressController.dispose();
    }
  }

  String _preferredCompanyId(List<Map<String, dynamic>> companies) {
    final active =
        (currentUserDocument?.activeCompanyId ?? '').toString().trim();
    if (active.isNotEmpty &&
        companies
            .any((company) => (company['id'] ?? '').toString() == active)) {
      return active;
    }
    final primary = (currentUserDocument?.idCompany ?? '').toString().trim();
    if (primary.isNotEmpty &&
        companies
            .any((company) => (company['id'] ?? '').toString() == primary)) {
      return primary;
    }
    return (companies.first['id'] ?? '').toString();
  }

  Set<String> _seedCompanyIdsForUser(String uid) {
    final ids = <String>{
      (currentUserDocument?.idCompany ?? '').toString().trim(),
      (currentUserDocument?.activeCompanyId ?? '').toString().trim(),
      ...((currentUserDocument?.companyIds ?? const <String>[])
          .whereType<String>()
          .map((e) => e.trim())),
    };
    if (uid.trim().isNotEmpty) {
      ids.add(uid.trim());
    }
    ids.removeWhere((id) => id.isEmpty || id == '__all__');
    return ids;
  }

  List<Map<String, dynamic>> _quickCompaniesFromUser(User user) {
    final snapshot = currentUserDocument?.snapshotData ?? const {};
    final explicitIds = <String>{
      (snapshot['idCompany'] ?? '').toString().trim(),
      (snapshot['activeCompanyId'] ?? '').toString().trim(),
      ...((snapshot['companyIds'] as List?) ?? const [])
          .map((e) => e.toString().trim()),
    }..removeWhere((id) => id.isEmpty || id == '__all__');
    final ids = explicitIds.isEmpty && user.uid.trim().isNotEmpty
        ? <String>{user.uid.trim()}
        : explicitIds;
    return ids.map((id) {
      return <String, dynamic>{
        'id': id,
        'ownerId': user.uid,
        'members': [user.uid],
        'name': _companyDisplayName(Map<String, dynamic>.from(snapshot),
            fallback: id),
        'nameCompany': snapshot['nameCompany'],
        'company_name': snapshot['company_name'],
      };
    }).toList()
      ..sort((a, b) => _companyDisplayName(a,
              fallback: (a['id'] ?? '').toString())
          .compareTo(
              _companyDisplayName(b, fallback: (b['id'] ?? '').toString())));
  }

  Future<List<Map<String, dynamic>>> _loadCompaniesForUser(User user) async {
    final merged = <String, Map<String, dynamic>>{};

    final membersSnap = await _firestore
        .collection('companies')
        .where('members', arrayContains: user.uid)
        .get(const GetOptions(source: Source.serverAndCache));
    for (final doc in membersSnap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      merged[doc.id] = {'id': doc.id, ...data};
    }

    final ownerSnap = await _firestore
        .collection('companies')
        .where('ownerId', isEqualTo: user.uid)
        .get(const GetOptions(source: Source.serverAndCache));
    for (final doc in ownerSnap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      merged[doc.id] = {'id': doc.id, ...data};
    }

    final seededIds = _seedCompanyIdsForUser(user.uid);
    final missingIds = seededIds.difference(merged.keys.toSet());
    for (final chunk
        in splitCompanyIdsForWhereIn(missingIds.toList()..sort())) {
      final snap = await _firestore
          .collection('companies')
          .where(FieldPath.documentId, whereIn: chunk)
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        merged[doc.id] = {'id': doc.id, ...data};
      }
    }

    for (final chunk
        in splitCompanyIdsForWhereIn(merged.keys.toList()..sort())) {
      final snap = await _firestore
          .collection('company_profile')
          .where('idCompany', whereIn: chunk)
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final companyId = (data['idCompany'] ?? '').toString().trim();
        if (companyId.isEmpty || !merged.containsKey(companyId)) continue;
        final current = merged[companyId]!;
        final currentName = _companyDisplayName(current, fallback: '');
        final profileName = _companyDisplayName(data, fallback: '');
        if ((currentName == 'Компания' || currentName.isEmpty) &&
            profileName.isNotEmpty &&
            profileName != 'Компания') {
          current['name'] = profileName;
        }
        for (final field in ['bin', 'address', 'phone', 'email']) {
          final value = (data[field] ?? '').toString().trim();
          if (value.isNotEmpty &&
              (current[field] ?? '').toString().trim().isEmpty) {
            current[field] = value;
          }
        }
      }
    }

    final companies = merged.values.toList()
      ..sort((a, b) => _companyDisplayName(a,
              fallback: (a['id'] ?? '').toString())
          .compareTo(
              _companyDisplayName(b, fallback: (b['id'] ?? '').toString())));
    return companies;
  }

  Future<void> _loadData() async {
    final loadId = ++_loadSequence;
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted || loadId != _loadSequence) return;
        setState(() {
          _companies = [];
          _employeesByCompany.clear();
          _usersByCompany.clear();
          _rolesByCompany.clear();
          _positionsByCompany.clear();
          _loading = false;
        });
        return;
      }
      final quickCompanies = _quickCompaniesFromUser(user);
      if (quickCompanies.isNotEmpty && mounted) {
        if (loadId != _loadSequence) return;
        setState(() {
          _companies = quickCompanies;
          _selectedCompanyId = _preferredCompanyId(quickCompanies);
          _loading = false;
        });
      }
      final companies = await _loadCompaniesForUser(user);
      if (!mounted || loadId != _loadSequence) return;
      setState(() {
        _companies = companies;
        _selectedCompanyId = companies.isEmpty
            ? null
            : ((_selectedCompanyId != null &&
                    companies.any((company) =>
                        (company['id'] ?? '').toString() == _selectedCompanyId))
                ? _selectedCompanyId
                : _preferredCompanyId(companies));
        _employeesByCompany.clear();
        _usersByCompany.clear();
        _rolesByCompany.clear();
        _positionsByCompany.clear();
        _loading = false;
      });

      final Map<String, List<Map<String, dynamic>>> employeesMap = {};
      final Map<String, List<Map<String, dynamic>>> usersMap = {};
      final Map<String, List<Map<String, dynamic>>> rolesMap = {};
      final Map<String, List<Map<String, dynamic>>> positionsMap = {};
      for (final company in companies) {
        final companyId = (company['id'] ?? '').toString();
        if (companyId.isEmpty) continue;
        final ownerId = (company['ownerId'] ?? '').toString().trim();
        final employeesSnap = await _firestore
            .collection('employees')
            .where('idCompany', isEqualTo: companyId)
            .get(const GetOptions(source: Source.serverAndCache));
        final companyEmployees = employeesSnap.docs.map((doc) {
          final raw = doc.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': doc.id, ...data};
        }).toList();

        final usersByPrimarySnap = await _firestore
            .collection('users')
            .where('idCompany', isEqualTo: companyId)
            .get(const GetOptions(source: Source.serverAndCache));
        final usersByMembershipSnap = await _firestore
            .collection('users')
            .where('companyIds', arrayContains: companyId)
            .get(const GetOptions(source: Source.serverAndCache));
        final mergedUsers = <String, Map<String, dynamic>>{};
        for (final doc in [
          ...usersByPrimarySnap.docs,
          ...usersByMembershipSnap.docs,
        ]) {
          final raw = doc.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          mergedUsers[doc.id] = {'id': doc.id, ...data};
        }
        final companyUsers = mergedUsers.values.toList();
        usersMap[companyId] = companyUsers;

        final rolesSnap = await _firestore
            .collection('roles')
            .where('idCompany', isEqualTo: companyId)
            .get(const GetOptions(source: Source.serverAndCache));
        final roleDocs = rolesSnap.docs.map((doc) {
          final raw = doc.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': doc.id, ...data};
        }).toList();
        final roles = _dedupeRoles(roleDocs);
        final positions = _sortPositions(roleDocs.where(_looksLikePosition));
        rolesMap[companyId] = roles;
        positionsMap[companyId] = positions;

        final employeeUserKeys = <String>{};
        for (final employee in companyEmployees) {
          final userId =
              (employee['user_id'] ?? employee['uid'] ?? '').toString().trim();
          final phone = (employee['phone'] ?? '').toString().trim();
          if (userId.isNotEmpty) employeeUserKeys.add('uid:$userId');
          if (phone.isNotEmpty) employeeUserKeys.add('phone:$phone');
        }
        final positionsByRoleId = <String, Map<String, dynamic>>{};
        for (final row in roleDocs.where(_looksLikePosition)) {
          final roleId = (row['role_id'] ?? '').toString().trim();
          if (roleId.isNotEmpty)
            positionsByRoleId.putIfAbsent(roleId, () => row);
        }

        for (final userRow in companyUsers) {
          final userId =
              (userRow['id'] ?? userRow['uid'] ?? '').toString().trim();
          final phone = (userRow['phone_number'] ??
                  userRow['phoneNumber'] ??
                  userRow['phone'] ??
                  '')
              .toString()
              .trim();
          final hasEmployee = (userId.isNotEmpty &&
                  employeeUserKeys.contains('uid:$userId')) ||
              (phone.isNotEmpty && employeeUserKeys.contains('phone:$phone'));
          if (hasEmployee) continue;
          final userRoleId = (userRow['role_id'] ?? '').toString().trim();
          final linkedPosition = positionsByRoleId[userRoleId];
          final linkedPositionId =
              (linkedPosition?['id'] ?? userRow['position_id'] ?? '')
                  .toString()
                  .trim();
          final linkedPositionName =
              (linkedPosition?['name'] ?? userRow['position'] ?? '')
                  .toString()
                  .trim();
          companyEmployees.add({
            'id': 'user_$userId',
            'user_id': userId,
            'uid': userId,
            'idCompany': companyId,
            'name': (userRow['display_name'] ??
                    userRow['displayName'] ??
                    userRow['name'] ??
                    userRow['phone_number'] ??
                    'Сотрудник')
                .toString(),
            'phone': phone,
            'position': (linkedPositionName.isNotEmpty
                    ? linkedPositionName
                    : userRow['position'] ??
                        userRow['role_name'] ??
                        userRow['role'] ??
                        '')
                .toString(),
            'position_id': linkedPositionId,
            'position_name': linkedPositionName,
            'role_id': userRoleId,
            'role_name':
                (userRow['role_name'] ?? userRow['role'] ?? '').toString(),
            'department': (userRow['department'] ?? '').toString(),
            'active': userRow['bloc'] != true,
            'from_user_account': true,
          });
        }
        employeesMap[companyId] = companyEmployees;
      }

      if (!mounted || loadId != _loadSequence) return;
      setState(() {
        _employeesByCompany
          ..clear()
          ..addAll(employeesMap);
        _usersByCompany
          ..clear()
          ..addAll(usersMap);
        _rolesByCompany
          ..clear()
          ..addAll(rolesMap);
        _positionsByCompany
          ..clear()
          ..addAll(positionsMap);
      });
    } catch (e) {
      print('Error loading org structure: $e');
    } finally {
      if (mounted && loadId == _loadSequence && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, dynamic> _readOrgLayoutRaw() {
    final raw = currentUserDocument?.snapshotData['org_employee_layout'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  void _ensureEmployeeLayout(
    String companyId,
    Size size,
    List<Map<String, dynamic>> employees,
  ) {
    if (companyId.isEmpty || size.isEmpty) return;
    final ids = employees
        .map((e) => (e['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final needsReset = _canvasSizes[companyId] != size ||
        !_employeeLayouts.containsKey(companyId) ||
        !_employeeLayouts[companyId]!.keys.toSet().containsAll(ids);
    if (!needsReset) return;

    final raw = _readOrgLayoutRaw();
    final companyRaw = raw[companyId];
    final next = <String, Offset?>{};
    for (final id in ids) {
      if (companyRaw is Map) {
        final position = companyRaw[id];
        if (position is Map) {
          final x = (position['x'] as num?)?.toDouble();
          final y = (position['y'] as num?)?.toDouble();
          if (x != null && y != null) {
            next[id] = _clampEmployeeOffset(
              Offset(x * size.width, y * size.height),
              size,
            );
            continue;
          }
        }
      }
      next[id] = null;
    }

    final missing = next.entries
        .where((entry) => entry.value == null)
        .map((entry) => entry.key)
        .toList();
    if (missing.isNotEmpty) {
      final missing = ids.where((id) => next[id] == null).toList();
      final center = Offset(size.width / 2, size.height / 2);
      final radius =
          (min(size.shortestSide / 2 - _nodeSize, size.shortestSide / 2))
              .clamp(60.0, size.shortestSide / 2);
      for (var i = 0; i < missing.length; i++) {
        final angle = (2 * pi * i) / missing.length;
        final dx = center.dx + radius * cos(angle) - _nodeSize / 2;
        final dy = center.dy + radius * sin(angle) - _nodeSize / 2;
        next[missing[i]] = _clampEmployeeOffset(Offset(dx, dy), size);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _canvasSizes[companyId] = size;
        final filtered = <String, Offset>{};
        next.forEach((key, value) {
          if (value != null) {
            filtered[key] = value;
          }
        });
        _employeeLayouts[companyId] = filtered;
      });
    });
  }

  Offset _clampEmployeeOffset(Offset offset, Size size) {
    final dx = offset.dx.clamp(0.0, size.width - _nodeSize);
    final dy = offset.dy.clamp(0.0, size.height - _nodeSize);
    return Offset(dx.isNaN ? 0 : dx, dy.isNaN ? 0 : dy);
  }

  Future<void> _saveOrgLayout(String companyId) async {
    if (currentUserReference == null) return;
    final size = _canvasSizes[companyId];
    if (size == null || size.isEmpty) return;
    final layout = _employeeLayouts[companyId];
    if (layout == null || layout.isEmpty) return;

    final raw = _readOrgLayoutRaw();
    final next = Map<String, dynamic>.from(raw);
    final normalized = <String, dynamic>{};
    layout.forEach((id, offset) {
      final nx = size.width == 0 ? 0 : offset.dx / size.width;
      final ny = size.height == 0 ? 0 : offset.dy / size.height;
      normalized[id] = {
        'x': nx.clamp(0.0, 1.0),
        'y': ny.clamp(0.0, 1.0),
      };
    });
    next[companyId] = normalized;
    await currentUserReference!.update({'org_employee_layout': next});
  }

  String _positionRoleLabel(Map<String, dynamic> row) {
    final roleName = (row['role_name'] ?? '').toString().trim();
    if (roleName.isNotEmpty) return roleName;
    final linkedRole = (row['linked_role_name'] ?? '').toString().trim();
    if (linkedRole.isNotEmpty) return linkedRole;
    return 'Без роли';
  }

  int _positionFallbackRank(Map<String, dynamic> row) {
    final text = '${row['name'] ?? ''} ${row['role_name'] ?? ''}'.toLowerCase();
    if (text.contains('директор') ||
        text.contains('ceo') ||
        text.contains('owner') ||
        text.contains('руковод')) {
      return 0;
    }
    if (text.contains('зам') || text.contains('управ')) return 10;
    if (text.contains('бухгалтер') || text.contains('account')) return 20;
    if (text.contains('кассир') || text.contains('продав')) return 30;
    return 50;
  }

  int _positionOrder(Map<String, dynamic> row, int fallback) {
    final raw = row['sort_order'] ?? row['sortOrder'];
    if (raw is num) return raw.toInt();
    return fallback;
  }

  List<Map<String, dynamic>> _sortPositions(
    Iterable<Map<String, dynamic>> source,
  ) {
    final items = source.map((row) => Map<String, dynamic>.from(row)).toList();
    final indexById = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final id = (items[i]['id'] ?? '').toString();
      if (id.isNotEmpty) indexById[id] = i;
    }
    final children = <String, List<Map<String, dynamic>>>{};
    final roots = <Map<String, dynamic>>[];
    for (final item in items) {
      final parentId = (item['parent_position_id'] ??
              item['parentPositionId'] ??
              item['reports_to_position_id'] ??
              '')
          .toString()
          .trim();
      if (parentId.isNotEmpty && indexById.containsKey(parentId)) {
        children.putIfAbsent(parentId, () => []).add(item);
      } else {
        roots.add(item);
      }
    }

    int comparePosition(Map<String, dynamic> a, Map<String, dynamic> b) {
      final ai = indexById[(a['id'] ?? '').toString()] ?? 0;
      final bi = indexById[(b['id'] ?? '').toString()] ?? 0;
      final orderCompare =
          _positionOrder(a, ai).compareTo(_positionOrder(b, bi));
      if (orderCompare != 0) return orderCompare;
      final rankCompare =
          _positionFallbackRank(a).compareTo(_positionFallbackRank(b));
      if (rankCompare != 0) return rankCompare;
      return (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString());
    }

    roots.sort(comparePosition);
    for (final list in children.values) {
      list.sort(comparePosition);
    }

    final sorted = <Map<String, dynamic>>[];
    void visit(Map<String, dynamic> item, int depth) {
      sorted.add({...item, '_hierarchy_depth': depth});
      final id = (item['id'] ?? '').toString();
      for (final child in children[id] ?? const <Map<String, dynamic>>[]) {
        visit(child, depth + 1);
      }
    }

    for (final root in roots) {
      visit(root, 0);
    }
    return sorted;
  }

  Future<void> _showPositionDialog({
    required String companyId,
    required List<Map<String, dynamic>> roles,
    List<Map<String, dynamic>> positions = const [],
    Map<String, dynamic>? existing,
  }) async {
    final nameController = TextEditingController(
      text: (existing?['name'] ?? '').toString(),
    );
    String? selectedRoleId = (existing?['role_id'] ?? '').toString().trim();
    if (selectedRoleId.isEmpty) {
      selectedRoleId = (existing?['linked_role_id'] ?? '').toString().trim();
    }
    if (selectedRoleId.isEmpty && roles.isNotEmpty) {
      selectedRoleId = (roles.first['id'] ?? '').toString();
    }
    String? selectedParentId = (existing?['parent_position_id'] ??
            existing?['parentPositionId'] ??
            existing?['reports_to_position_id'] ??
            '')
        .toString()
        .trim();
    if (selectedParentId.isEmpty) selectedParentId = null;
    final currentPositionId = (existing?['id'] ?? '').toString().trim();
    final parentOptions = positions
        .where((position) =>
            (position['id'] ?? '').toString().trim().isNotEmpty &&
            (position['id'] ?? '').toString().trim() != currentPositionId)
        .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null
                ? 'Новая должность'
                : 'Редактировать должность'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название должности',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: (selectedRoleId?.isEmpty ?? true)
                        ? null
                        : selectedRoleId,
                    decoration: const InputDecoration(
                      labelText: 'Роль для должности',
                    ),
                    items: roles
                        .map(
                          (role) => DropdownMenuItem<String>(
                            value: (role['id'] ?? '').toString(),
                            child: Text(
                                (role['name'] ?? 'Без названия').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRoleId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedParentId,
                    decoration: const InputDecoration(
                      labelText: 'Вышестоящая должность',
                      helperText:
                          'Оставьте пустым для верхнего уровня структуры.',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Нет, верхний уровень'),
                      ),
                      ...parentOptions.map(
                        (position) {
                          final id = (position['id'] ?? '').toString();
                          final depth =
                              (position['_hierarchy_depth'] as num?)?.toInt() ??
                                  0;
                          final prefix = depth <= 0
                              ? ''
                              : '${List.filled(depth, '  ').join()}↳ ';
                          final name =
                              (position['name'] ?? 'Должность').toString();
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text('$prefix$name'),
                          );
                        },
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedParentId =
                            (value == null || value.isEmpty) ? null : value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название должности')),
      );
      return;
    }
    final selectedRole = roles.firstWhere(
      (role) => (role['id'] ?? '').toString() == selectedRoleId,
      orElse: () => {},
    );
    if (selectedRole.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите роль для должности')),
      );
      return;
    }

    final roleId = (selectedRole['id'] ?? '').toString();
    final roleName = (selectedRole['name'] ?? '').toString();
    final parentPosition = selectedParentId == null
        ? null
        : parentOptions.firstWhere(
            (position) => (position['id'] ?? '').toString() == selectedParentId,
            orElse: () => {},
          );
    final existingIndex = existing == null
        ? positions.length
        : positions.indexWhere(
            (position) =>
                (position['id'] ?? '').toString() ==
                (existing['id'] ?? '').toString(),
          );
    final roleSnapshot = buildPositionSnapshot(
      roleData: {
        ...selectedRole,
        'id': roleId,
        'name': roleName,
      },
      fallbackCompanyId: companyId,
    );

    final payload = <String, dynamic>{
      'type': 'position',
      'idCompany': companyId,
      'name': name,
      ...roleSnapshot,
      'parent_position_id': selectedParentId,
      'parent_position_name':
          parentPosition == null ? null : parentPosition['name'],
      'sort_order': existing == null
          ? positions.length
          : (existing['sort_order'] ?? existingIndex),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (existing == null) {
      payload['created_at'] = FieldValue.serverTimestamp();
      payload['user_id'] = _auth.currentUser?.uid;
      await _firestore.collection('roles').add(payload);
    } else {
      await _firestore
          .collection('roles')
          .doc(existing['id']?.toString())
          .update(payload);
    }
    await _loadData();
    await _syncOnboardingPositionsStep(companyId);
  }

  Future<void> _deletePosition(String? positionId) async {
    final id = (positionId ?? '').trim();
    if (id.isEmpty) return;
    final companyId = (_selectedCompanyId ?? '').trim();
    await _firestore.collection('roles').doc(id).delete();
    await _loadData();
    if (companyId.isNotEmpty) {
      await _syncOnboardingPositionsStep(companyId);
    }
  }

  Future<void> _syncOnboardingPositionsStep(String companyId) async {
    if (currentUserReference == null) return;
    final trimmedCompanyId = companyId.trim();
    if (trimmedCompanyId.isEmpty) return;
    final userData = Map<String, dynamic>.from(
        currentUserDocument?.snapshotData ?? const {});
    userData['idCompany'] = trimmedCompanyId;
    userData['activeCompanyId'] = trimmedCompanyId;
    userData['companyScope'] = 'single';
    final companyIds =
        List<String>.from((userData['companyIds'] as List?) ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e != '__all__')
            .toSet()
            .toList();
    if (!companyIds.contains(trimmedCompanyId)) {
      companyIds.add(trimmedCompanyId);
    }
    userData['companyIds'] = companyIds;
    await currentUserReference!.update({
      'idCompany': trimmedCompanyId,
      'activeCompanyId': trimmedCompanyId,
      'companyScope': 'single',
      'companyIds': companyIds,
    });
    OnboardingProgress.invalidate(authUid: currentUserUid);
    await OnboardingProgress.loadAndSync(
      db: _firestore,
      authUid: currentUserUid,
      userData: userData,
      userRef: currentUserReference,
    );
  }

  List<Map<String, dynamic>> _employeesForPosition(
    List<Map<String, dynamic>> employees,
    Map<String, dynamic> position,
  ) {
    final positionId = (position['id'] ?? '').toString().trim();
    final positionName =
        (position['name'] ?? '').toString().trim().toLowerCase();
    final roleId = (position['role_id'] ?? '').toString().trim();
    final roleName =
        (position['role_name'] ?? '').toString().trim().toLowerCase();
    return employees.where((employee) {
      final employeePositionId =
          (employee['position_id'] ?? '').toString().trim();
      final employeeRoleId = (employee['role_id'] ?? '').toString().trim();
      final employeePosition =
          (employee['position'] ?? '').toString().trim().toLowerCase();
      final employeeRole = (employee['role'] ?? employee['role_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (positionId.isNotEmpty && employeePositionId == positionId)
        return true;
      if (roleId.isNotEmpty && employeeRoleId == roleId) return true;
      if (positionName.isNotEmpty && employeePosition == positionName)
        return true;
      if (positionName.isNotEmpty && employeeRole == positionName) return true;
      if (roleName.isNotEmpty && employeeRole == roleName) return true;
      return false;
    }).toList();
  }

  String _employeeIdentityKey(Map<String, dynamic> employee) {
    final userId =
        (employee['user_id'] ?? employee['uid'] ?? '').toString().trim();
    if (userId.isNotEmpty) return 'uid:$userId';
    final phone = (employee['phone'] ?? '').toString().trim();
    if (phone.isNotEmpty) return 'phone:$phone';
    return 'id:${(employee['id'] ?? '').toString().trim()}';
  }

  Future<void> _assignExistingEmployeeToPosition(
    String companyId,
    Map<String, dynamic> position,
    Map<String, dynamic> employee,
  ) async {
    final rolePatch = buildEmployeeRoleAssignmentPatch(
      positionData: position,
      fallbackCompanyId: companyId,
    );
    final linkedUser = _linkedUserForEmployee(companyId, employee);
    final userId = (linkedUser?['id'] ??
            linkedUser?['uid'] ??
            employee['user_id'] ??
            employee['uid'] ??
            '')
        .toString()
        .trim();
    final phone = _employeePhone(companyId, employee);
    final name = (employee['name'] ??
            linkedUser?['display_name'] ??
            linkedUser?['name'] ??
            linkedUser?['phone_number'] ??
            'Сотрудник')
        .toString()
        .trim();
    final department = (employee['department'] ?? '').toString().trim();
    final payload = <String, dynamic>{
      'idCompany': companyId,
      'name': name,
      'phone': phone,
      'department': department,
      ...rolePatch,
      'user_id': userId.isNotEmpty ? userId : phone,
      'updated_at': FieldValue.serverTimestamp(),
    };

    final employeeId = (employee['id'] ?? '').toString().trim();
    final hasRealEmployeeDoc =
        employeeId.isNotEmpty && !employeeId.startsWith('user_');
    if (hasRealEmployeeDoc) {
      await _firestore
          .collection('employees')
          .doc(employeeId)
          .set(payload, SetOptions(merge: true));
    } else {
      QuerySnapshot<Map<String, dynamic>> existing;
      if (userId.isNotEmpty) {
        existing = await _firestore
            .collection('employees')
            .where('idCompany', isEqualTo: companyId)
            .where('user_id', isEqualTo: userId)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));
      } else {
        existing = await _firestore
            .collection('employees')
            .where('idCompany', isEqualTo: companyId)
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));
      }
      if (existing.docs.isEmpty) {
        payload['created_at'] = FieldValue.serverTimestamp();
        await _firestore.collection('employees').add(payload);
      } else {
        await existing.docs.first.reference
            .set(payload, SetOptions(merge: true));
      }
    }

    if (userId.isNotEmpty) {
      await _firestore.collection('users').doc(userId).set({
        ...buildUserRoleAssignmentPatch(
          roleData: {
            'id': (position['role_id'] ?? '').toString().trim(),
            'name': (position['role_name'] ?? position['name'] ?? '')
                .toString()
                .trim(),
            'permissions': position['role_permissions'],
            'allowed_company_ids': position['role_allowed_company_ids'],
          },
          fallbackCompanyId: companyId,
        ),
        'position': (position['name'] ?? '').toString().trim(),
        'position_id': (position['id'] ?? '').toString().trim(),
        'position_name': (position['name'] ?? '').toString().trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    FirestoreQueryCache.instance.invalidateCompanyCollection(
      'employees',
      companyId,
    );
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      'users',
      companyId,
    );
    await _loadData();
  }

  Map<String, dynamic>? _linkedUserForEmployee(
    String companyId,
    Map<String, dynamic> employee,
  ) {
    final users = _usersByCompany[companyId] ?? const <Map<String, dynamic>>[];
    final employeeUserId = (employee['user_id'] ?? '').toString().trim();
    final employeePhone = (employee['phone'] ?? '').toString().trim();
    if (employeeUserId.isNotEmpty) {
      for (final user in users) {
        final userId = (user['id'] ?? user['uid'] ?? '').toString().trim();
        if (userId == employeeUserId) {
          return user;
        }
      }
    }
    if (employeePhone.isNotEmpty) {
      for (final user in users) {
        final phone = (user['phone_number'] ?? '').toString().trim();
        if (phone == employeePhone) {
          return user;
        }
      }
    }
    return null;
  }

  String _employeePhone(String companyId, Map<String, dynamic> employee) {
    final directPhone = (employee['phone'] ?? '').toString().trim();
    if (directPhone.isNotEmpty) return directPhone;
    final linkedUser = _linkedUserForEmployee(companyId, employee);
    return (linkedUser?['phone_number'] ?? '').toString().trim();
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _jsonString(dynamic jsonBody, String path) {
    final value = getJsonField(jsonBody, path);
    final text = value?.toString().trim() ?? '';
    return text == 'null' ? '' : text;
  }

  Future<Map<String, dynamic>?> _findUserByPhone(
    String phone, {
    String? companyId,
  }) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;
    final digits = _digitsOnly(trimmed);
    if (companyId != null && companyId.trim().isNotEmpty) {
      final users =
          _usersByCompany[companyId.trim()] ?? const <Map<String, dynamic>>[];
      for (final user in users) {
        final rawPhone =
            (user['phone_number'] ?? user['phoneNumber'] ?? user['phone'] ?? '')
                .toString()
                .trim();
        if (rawPhone == trimmed ||
            (digits.isNotEmpty && _digitsOnly(rawPhone) == digits)) {
          return user;
        }
      }
    }
    final candidates = <String>{trimmed};
    if (digits.isNotEmpty) {
      candidates.add(digits);
      candidates.add('+$digits');
    }
    const fields = ['phone_number', 'phoneNumber', 'phone'];
    for (final field in fields) {
      for (final candidate in candidates) {
        final snap = await _firestore
            .collection('users')
            .where(field, isEqualTo: candidate)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));
        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          return {'id': doc.id, ...doc.data()};
        }
      }
    }
    return null;
  }

  Future<void> _showEmployeeDialog({
    required String companyId,
    required Map<String, dynamic> position,
    Map<String, dynamic>? employee,
  }) async {
    final nameController = TextEditingController(
      text: (employee?['name'] ?? '').toString(),
    );
    final deptController = TextEditingController(
      text: (employee?['department'] ?? '').toString(),
    );
    final phoneController = TextEditingController(
      text: (employee?['phone'] ?? '').toString(),
    );
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                employee == null
                    ? 'Добавить пользователя'
                    : 'Редактировать пользователя',
              ),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'ФИО'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Введите ФИО'
                                : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: (position['name'] ?? '').toString(),
                        readOnly: true,
                        decoration:
                            const InputDecoration(labelText: 'Должность'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Номер телефона для входа',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Введите номер телефона'
                                : null,
                      ),
                      if (employee == null) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Временный пароль',
                            helperText:
                                'Сотрудник сменит пароль при первом входе.',
                          ),
                          validator: (value) => (value ?? '').trim().length < 6
                              ? 'Минимум 6 символов'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: deptController,
                        decoration: const InputDecoration(labelText: 'Отдел'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() => saving = true);
                          Navigator.pop(dialogContext, true);
                        },
                  child: Text(saving ? 'Сохранение...' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) {
      passwordController.dispose();
      return;
    }

    final rolePatch = buildEmployeeRoleAssignmentPatch(
      positionData: position,
      fallbackCompanyId: companyId,
    );
    final phone = phoneController.text.trim();
    final name = nameController.text.trim();
    final department = deptController.text.trim();
    String linkedUserId =
        (employee?['user_id'] ?? employee?['uid'] ?? '').toString().trim();
    bool linkedExistingAccount = false;

    if (employee == null) {
      final response = await TokenCall.call(
        phone: phone,
        password: passwordController.text.trim(),
        mode: 'signup',
        role: 'emp',
        companyId: companyId,
        displayName: name,
        roleId: (position['role_id'] ?? '').toString().trim(),
        roleName:
            (position['role_name'] ?? position['name'] ?? '').toString().trim(),
        rolePermissions: normalizePermissionList(position['role_permissions']),
        roleAllowedCompanyIds: normalizeRoleCompanyIds(
          position['role_allowed_company_ids'],
          fallbackCompanyId: companyId,
        ),
        position: (position['name'] ?? '').toString().trim(),
        department: department,
        forcePasswordChange: true,
      );
      final body = response.jsonBody;
      final error = getJsonField(body, r'''$.error''').toString();
      if (!response.succeeded) {
        if (error == 'account_already_exists') {
          final existingUser = await _findUserByPhone(
            phone,
            companyId: companyId,
          );
          if (existingUser != null) {
            linkedUserId = (existingUser['id'] ?? existingUser['uid'] ?? '')
                .toString()
                .trim();
            linkedExistingAccount = true;
          } else {
            linkedUserId = phone;
            linkedExistingAccount = true;
          }
        } else {
          final message = switch (error) {
            'company_id_is_required' => 'Компания не выбрана',
            'phone_is_required' => 'Введите номер телефона',
            _ => 'Не удалось зарегистрировать сотрудника',
          };
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
          passwordController.dispose();
          return;
        }
      } else {
        linkedUserId = _jsonString(body, r'''$.uid''');
        linkedUserId = linkedUserId.isNotEmpty
            ? linkedUserId
            : _jsonString(body, r'''$.user.uid''');
        linkedUserId = linkedUserId.isNotEmpty
            ? linkedUserId
            : _jsonString(body, r'''$.userId''');
      }
    }
    passwordController.dispose();

    final payload = <String, dynamic>{
      'idCompany': companyId,
      'name': name,
      'phone': phone,
      'department': department,
      ...rolePatch,
      'updated_at': FieldValue.serverTimestamp(),
    };
    final userId = linkedUserId.isNotEmpty ? linkedUserId : phone;
    if (userId.isNotEmpty) {
      payload['user_id'] = userId;
    }
    payload['position'] = (position['name'] ?? '').toString().trim();
    payload['position_id'] = (position['id'] ?? '').toString().trim();
    payload['position_name'] = (position['name'] ?? '').toString().trim();
    if (employee == null) {
      var existing = await _firestore
          .collection('employees')
          .where('idCompany', isEqualTo: companyId)
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (existing.docs.isEmpty && phone.isNotEmpty) {
        existing = await _firestore
            .collection('employees')
            .where('idCompany', isEqualTo: companyId)
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));
      }
      if (existing.docs.isEmpty) {
        payload['created_at'] = FieldValue.serverTimestamp();
        await _firestore.collection('employees').add(payload);
      } else {
        await existing.docs.first.reference
            .set(payload, SetOptions(merge: true));
      }
    } else {
      await _firestore
          .collection('employees')
          .doc((employee['id'] ?? '').toString())
          .update(payload);
    }
    if (userId.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.set(
        {
          ...buildUserRoleAssignmentPatch(
            roleData: {
              'id': (position['role_id'] ?? '').toString().trim(),
              'name': (position['role_name'] ?? '').toString().trim(),
              'permissions': position['role_permissions'],
              'allowed_company_ids': position['role_allowed_company_ids'],
            },
            fallbackCompanyId: companyId,
          ),
          'display_name': name,
          'name': name,
          'phone_number': phone,
          'position': (position['name'] ?? '').toString().trim(),
          'position_id': (position['id'] ?? '').toString().trim(),
          'position_name': (position['name'] ?? '').toString().trim(),
          'force_password_change': employee == null && !linkedExistingAccount
              ? true
              : FieldValue.delete(),
          'password_change_required': employee == null && !linkedExistingAccount
              ? true
              : FieldValue.delete(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      'employees',
      companyId,
    );
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      'users',
      companyId,
    );
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          employee == null
              ? 'Сотрудник зарегистрирован. Передайте ему номер и временный пароль.'
              : 'Сотрудник обновлен',
        ),
      ),
    );
  }

  Future<void> _deleteEmployee(
      String companyId, Map<String, dynamic> employee) async {
    final id = (employee['id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Удалить пользователя?'),
            content: Text(
              'Удалить "${(employee['name'] ?? 'Пользователь').toString()}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final linkedUser = _linkedUserForEmployee(companyId, employee);
    await _firestore.collection('employees').doc(id).delete();
    if (linkedUser != null) {
      final userId =
          (linkedUser['id'] ?? linkedUser['uid'] ?? '').toString().trim();
      if (userId.isNotEmpty) {
        await _firestore.collection('users').doc(userId).set({
          'bloc': true,
          'idCompany': '',
          'activeCompanyId': '',
          'companyIds': <String>[],
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _firestore.collection('companies').doc(companyId).set({
          'members': FieldValue.arrayRemove([userId]),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      'employees',
      companyId,
    );
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      'users',
      companyId,
    );
    FirestoreQueryCache.instance.invalidateCompanyCollection(
      'companies',
      companyId,
    );
    await _loadData();
  }

  Widget _buildPositionsBlock(
    String companyId,
    List<Map<String, dynamic>> roles,
    List<Map<String, dynamic>> positions,
    List<Map<String, dynamic>> employees,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Должности компании',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton.icon(
                onPressed: roles.isEmpty
                    ? null
                    : () => _showPositionDialog(
                          companyId: companyId,
                          roles: roles,
                          positions: positions,
                        ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить'),
              ),
            ],
          ),
          if (roles.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Роли для компании еще не настроены администратором.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          const SizedBox(height: 10),
          if (positions.isEmpty)
            Text(
              'Должности не созданы',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).secondaryText),
            )
          else
            Column(
              children: positions.map((position) {
                final name = (position['name'] ?? '').toString().trim();
                final roleName = _positionRoleLabel(position);
                final positionId = (position['id'] ?? '').toString().trim();
                final positionKey = '$companyId::$positionId';
                final isExpanded = _expandedPositionKeys.contains(positionKey);
                final positionEmployees =
                    _employeesForPosition(employees, position);
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedPositionKeys.remove(positionKey);
                            } else {
                              _expandedPositionKeys.add(positionKey);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name.isEmpty ? '-' : name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  roleName,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                              Text(
                                '${positionEmployees.length} чел.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: const Color(0xFF6B7280),
                              ),
                              IconButton(
                                onPressed: () => _showPositionDialog(
                                  companyId: companyId,
                                  roles: roles,
                                  positions: positions,
                                  existing: position,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                              ),
                              IconButton(
                                onPressed: () => _deletePosition(
                                  position['id']?.toString(),
                                ),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: FlutterFlowTheme.of(context).alternate),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Пользователи в должности',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showEmployeeDialog(
                                      companyId: companyId,
                                      position: position,
                                    ),
                                    icon: const Icon(Icons.person_add_alt_1,
                                        size: 16),
                                    label: Text('Добавить'),
                                  ),
                                ],
                              ),
                              if (positionEmployees.isEmpty)
                                Text(
                                  'Пользователи не назначены',
                                  style: TextStyle(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText),
                                )
                              else
                                ...positionEmployees.map((employee) {
                                  final employeeName = (employee['name'] ?? '')
                                      .toString()
                                      .trim();
                                  final employeePosition =
                                      (employee['position'] ??
                                              position['name'] ??
                                              '')
                                          .toString()
                                          .trim();
                                  final phone =
                                      _employeePhone(companyId, employee);
                                  final dept = (employee['department'] ?? '')
                                      .toString()
                                      .trim();
                                  return Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate
                                                .withValues(alpha: 0.5)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                employeeName.isEmpty
                                                    ? 'Без имени'
                                                    : employeeName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (employeePosition.isNotEmpty)
                                                Text(
                                                  employeePosition,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              if (phone.isNotEmpty)
                                                Text(
                                                  phone,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                )
                                              else if (dept.isNotEmpty)
                                                Text(
                                                  dept,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _showEmployeeDialog(
                                            companyId: companyId,
                                            position: position,
                                            employee: employee,
                                          ),
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18),
                                        ),
                                        IconButton(
                                          onPressed: () => _deleteEmployee(
                                              companyId, employee),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNoCompaniesGuide() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Сначала нужно заполнить компанию',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Чтобы заполнить структуру бизнеса и оргструктуру, сначала создайте или заполните компанию, а затем вернитесь в этот раздел.',
              style: TextStyle(
                fontSize: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Что сделать:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('1. Откройте раздел "Данные компании".'),
            const Text(
                '2. Заполните название, ОКЭД, налоговый режим и реквизиты.'),
            const Text(
                '3. Вернитесь сюда, чтобы добавить должности и сотрудников.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      context.pushNamed(CompanySetupWidget.routeName),
                  icon: const Icon(Icons.apartment_outlined, size: 18),
                  label: const Text('Заполнить компанию'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.pushNamed(RekvizitiWidget.routeName),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Реквизиты'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgGuideCard(
    String companyId,
    List<Map<String, dynamic>> roles,
    List<Map<String, dynamic>> positions,
    List<Map<String, dynamic>> employees,
  ) {
    final hasRoles = roles.isNotEmpty;
    final hasPositions = positions.isNotEmpty;
    final hasEmployees = employees.isNotEmpty;
    String title;
    String description;
    List<String> steps;
    Widget? action;

    if (!hasRoles) {
      title = 'Сначала подтяните роли компании';
      description =
          'Без ролей нельзя создать должности. Обычно роли уже есть в системе, после этого можно создавать должности внутри компании.';
      steps = const [
        '1. Откройте раздел "Роли".',
        '2. Проверьте, что для компании появились системные роли.',
        '3. Вернитесь сюда и нажмите "Добавить" в блоке должностей.',
      ];
      action = OutlinedButton.icon(
        onPressed: () => context.pushNamed(RoliWidget.routeName),
        icon: const Icon(Icons.security_outlined, size: 18),
        label: const Text('Открыть роли'),
      );
    } else if (!hasPositions) {
      title = 'Следующий шаг: создайте должность';
      description =
          'Сейчас компания уже выбрана. Для заполнения оргструктуры сначала нужно создать хотя бы одну должность, например "Бухгалтер" или "Кассир".';
      steps = const [
        '1. Нажмите "Добавить" в блоке "Должности компании".',
        '2. Выберите роль из общего справочника.',
        '3. Сохраните должность, после этого этап будет считаться выполненным.',
      ];
      action = ElevatedButton.icon(
        onPressed: () => _showPositionDialog(
          companyId: companyId,
          roles: roles,
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Добавить должность'),
      );
    } else if (!hasEmployees) {
      title = 'Теперь добавьте сотрудника в должность';
      description =
          'Должности уже созданы. Чтобы заполнить оргструктуру до конца, назначьте пользователей или сотрудников в созданные должности.';
      steps = const [
        '1. Раскройте нужную должность ниже.',
        '2. Нажмите "Добавить" в блоке пользователей должности.',
        '3. Укажите имя, телефон и отдел сотрудника.',
      ];
      action = null;
    } else {
      title = 'Оргструктура заполняется здесь';
      description =
          'Ниже можно редактировать должности, назначать сотрудников и выстраивать структуру компании.';
      steps = const [
        '1. Меняйте должности через блок "Должности компании".',
        '2. Назначайте сотрудников в нужные должности.',
        '3. При необходимости двигайте карточки сотрудников на схеме.',
      ];
      action = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(step),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyContent(
    Map<String, dynamic> company,
    List<Map<String, dynamic>> employees,
    List<Map<String, dynamic>> roles,
    List<Map<String, dynamic>> positions,
  ) {
    final companyId = (company['id'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOrgGuideCard(companyId, roles, positions, employees),
        _buildPositionsBlock(companyId, roles, positions, employees),
        const SizedBox(height: 12),
        if (employees.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Сотрудники не найдены',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).secondaryText),
            ),
          )
        else ...[
          _buildEmployeeCanvas(companyId, employees),
          const SizedBox(height: 12),
          _buildEmployeeList(employees),
        ],
      ],
    );
  }

  Widget _buildEmployeeCanvas(
    String companyId,
    List<Map<String, dynamic>> employees,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasHeight = 260.0;
        final canvasSize = Size(constraints.maxWidth, canvasHeight);
        _ensureEmployeeLayout(companyId, canvasSize, employees);
        final layout = _employeeLayouts[companyId] ?? {};
        return Container(
          height: canvasHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FlutterFlowTheme.of(context).alternate),
          ),
          child: Stack(
            children: employees.map((employee) {
              final id = (employee['id'] ?? '').toString();
              final offset = layout[id] ?? Offset.zero;
              return Positioned(
                left: offset.dx,
                top: offset.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final current =
                          _employeeLayouts[companyId]?[id] ?? offset;
                      _employeeLayouts[companyId]?[id] = _clampEmployeeOffset(
                        current + details.delta,
                        canvasSize,
                      );
                    });
                  },
                  onPanEnd: (_) => _saveOrgLayout(companyId),
                  child: _employeeNode(employee),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _employeeNode(Map<String, dynamic> employee) {
    final name = (employee['name'] ?? 'Сотрудник').toString();
    final position = (employee['position'] ??
            employee['role_name'] ??
            employee['role'] ??
            '')
        .toString();
    final department = (employee['department'] ?? '').toString();
    final active = (employee['active'] ?? true) == true;
    return Container(
      width: _nodeSize,
      height: _nodeSize - 10,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? FlutterFlowTheme.of(context).primary
              : FlutterFlowTheme.of(context).alternate,
          width: active ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            position.isEmpty ? 'Должность неизвестна' : position,
            style: TextStyle(
              fontSize: 11,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.drag_indicator,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  department,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList(List<Map<String, dynamic>> employees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Список сотрудников',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: employees.map((employee) {
            final name = (employee['name'] ?? 'Сотрудник').toString();
            final role = (employee['position'] ??
                    employee['role_name'] ??
                    employee['role'] ??
                    '')
                .toString();
            final dept = (employee['department'] ?? '').toString();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: FlutterFlowTheme.of(context)
                          .alternate
                          .withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      name,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      role.isEmpty ? '-' : role,
                      style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      dept.isEmpty ? '-' : dept,
                      style: TextStyle(
                          color: FlutterFlowTheme.of(context).secondaryText),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOwnerNode() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showOwnerDialog,
      child: Stack(
        children: [
          Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  FlutterFlowTheme.of(context).warning.withValues(alpha: 0.14),
              border: Border.all(color: const Color(0xFFF59E0B), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wb_sunny_outlined,
                    color: Color(0xFFF59E0B), size: 22),
                const SizedBox(height: 4),
                Text(
                  _ownerDisplayName(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                ),
                Text(
                  _ownerTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Изм.',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w700,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Tooltip(
              message: 'Редактировать собственника',
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _panelSurface,
                  border: Border.all(color: _panelBorder),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFFF59E0B),
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyNode({
    required String name,
    required String companyId,
    required bool isActive,
    required String colorHex,
    required VoidCallback onCopy,
    required VoidCallback onEdit,
  }) {
    final cardColor = _companyColorFromHex(colorHex);
    return Container(
      width: 120,
      height: 92,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _companyBorderColor(cardColor, isActive),
          width: isActive ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_outlined,
                  size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isActive ? 'Активная компания' : 'Компания',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(3.0),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ID: $companyId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: _mutedText,
                  ),
                ),
              ),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStructureNode(Map<String, dynamic> node, bool isActiveCompany) {
    final type = (node['type'] ?? '').toString();
    if (type == 'company') {
      return _buildCompanyNode(
        name: (node['name'] ?? '').toString(),
        companyId: (node['company_id'] ?? '').toString(),
        isActive: isActiveCompany,
        colorHex: (node['color'] ?? '').toString(),
        onCopy: () => _copyCompanyId((node['company_id'] ?? '').toString()),
        onEdit: () {
          final companyId = (node['company_id'] ?? '').toString();
          final company = _companies.firstWhere(
            (item) => (item['id'] ?? '').toString() == companyId,
            orElse: () => {},
          );
          if (company.isNotEmpty) _showCompanyEditDialog(company);
        },
      );
    }
    final isBranch = type == 'branch';
    final color = isBranch ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4);
    final borderColor =
        isBranch ? const Color(0xFF60A5FA) : const Color(0xFF86EFAC);
    final icon =
        isBranch ? Icons.account_tree_outlined : Icons.groups_2_outlined;
    final title = isBranch ? 'Филиал' : 'Подразделение';
    return Container(
      width: 120,
      height: 82,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.drag_indicator, size: 15, color: Colors.grey[500]),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            (node['name'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessStructureTab() {
    if (_companies.isEmpty) {
      return Center(
        child: Text(
          'У вас ещё нет компаний',
          style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText),
        ),
      );
    }
    final activeId = ((currentUserDocument?.activeCompanyId ?? '')
            .toString()
            .trim()
            .isNotEmpty)
        ? (currentUserDocument?.activeCompanyId ?? '').toString().trim()
        : _preferredCompanyId(_companies);
    final activeCompany = _companies.firstWhere(
      (company) => (company['id'] ?? '').toString() == activeId,
      orElse: () => _companies.first,
    );
    final activeCompanyName = _companyDisplayName(activeCompany);
    final structureNodes = _businessStructureNodes(activeCompany);
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasHeight = 430.0;
        final size = Size(constraints.maxWidth, canvasHeight);
        _ensureCompanyLayout(size, structureNodes);
        const nodeSize = 120.0;
        final nodeCenterById = <String, Offset>{};
        for (final node in structureNodes) {
          final id = (node['id'] ?? '').toString();
          final pos = _companyLayouts[id] ?? const Offset(0, 0);
          nodeCenterById[id] = Offset(pos.dx + nodeSize / 2, pos.dy + 42);
        }
        final edges = <MapEntry<Offset, Offset>>[];
        for (final node in structureNodes) {
          final id = (node['id'] ?? '').toString();
          final parentId = (node['parent_id'] ?? '').toString();
          final from = nodeCenterById[parentId];
          final to = nodeCenterById[id];
          if (from != null && to != null) edges.add(MapEntry(from, to));
        }
        return SizedBox(
          height: canvasHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BusinessGraphPainter(
                    edges: edges,
                  ),
                ),
              ),
              ...structureNodes.map((node) {
                final id = (node['id'] ?? '').toString();
                final type = (node['type'] ?? '').toString();
                final pos = _companyLayouts[id] ?? const Offset(0, 0);
                return Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final current = _companyLayouts[id] ?? pos;
                        _companyLayouts[id] = _clampCompanyOffset(
                          current + details.delta,
                          size,
                          nodeSize,
                        );
                      });
                    },
                    onPanEnd: (_) => _saveCompanyLayout(),
                    onTap: type == 'company'
                        ? () => _setActiveCompany(
                              (node['company_id'] ?? '').toString(),
                            )
                        : null,
                    child: _buildStructureNode(
                      node,
                      (node['company_id'] ?? '').toString() == activeId,
                    ),
                  ),
                );
              }).toList(),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _panelSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _panelBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeCompanyName.isEmpty
                                  ? 'Активная компания'
                                  : activeCompanyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                            Text(
                              'ID: $activeId',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: _mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Копировать ID компании',
                        onPressed: () => _copyCompanyId(activeId),
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!(PermissionsHelper.has('company.org') ||
        PermissionsHelper.has('company.hr'))) {
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
                    color: FlutterFlowTheme.of(context).accent1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_tree_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Оргструктура',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _viewTab == 0
                            ? 'Структура бизнеса: схема компаний'
                            : 'Оргструктура сотрудников выбранной компании',
                        style: TextStyle(
                          fontSize: 13,
                          color: _mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: widget.lockViewTab
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _panelSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _viewTab = 0),
                            style: TextButton.styleFrom(
                              backgroundColor: _viewTab == 0
                                  ? FlutterFlowTheme.of(context).primary
                                  : Colors.transparent,
                              foregroundColor: _viewTab == 0
                                  ? Colors.white
                                  : FlutterFlowTheme.of(context).primaryText,
                            ),
                            child: const Text('Структура бизнеса'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _viewTab = 1),
                            style: TextButton.styleFrom(
                              backgroundColor: _viewTab == 1
                                  ? FlutterFlowTheme.of(context).primary
                                  : Colors.transparent,
                              foregroundColor: _viewTab == 1
                                  ? Colors.white
                                  : FlutterFlowTheme.of(context).primaryText,
                            ),
                            child: const Text('Орг структура компании'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (!widget.lockViewTab) ...[
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _companies.isEmpty
                    ? Center(
                        child: _buildNoCompaniesGuide(),
                      )
                    : (_viewTab == 0)
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: _buildBusinessStructureTab(),
                          )
                        : Builder(
                            builder: (context) {
                              final selectedId =
                                  (_selectedCompanyId ?? '').toString().trim();
                              final selectedCompany = _companies.firstWhere(
                                (company) =>
                                    (company['id'] ?? '').toString() ==
                                    selectedId,
                                orElse: () => _companies.first,
                              );
                              final companyId =
                                  (selectedCompany['id'] ?? '').toString();
                              final employees =
                                  _employeesByCompany[companyId] ?? [];
                              final roles = _rolesByCompany[companyId] ?? [];
                              final positions =
                                  _positionsByCompany[companyId] ?? [];
                              final companyName =
                                  _companyDisplayName(selectedCompany);

                              return ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                children: [
                                  if (_companies.length > 1)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.apartment_outlined,
                                              color: Color(0xFF2563EB)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: DropdownButton<String>(
                                              value: companyId,
                                              isExpanded: true,
                                              underline:
                                                  const SizedBox.shrink(),
                                              items: _companies.map((company) {
                                                final id = (company['id'] ?? '')
                                                    .toString();
                                                final name =
                                                    _companyDisplayName(
                                                  company,
                                                  fallback: id,
                                                );
                                                return DropdownMenuItem<String>(
                                                  value: id,
                                                  child: Text(name),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                if (value == null) return;
                                                setState(() {
                                                  _selectedCompanyId = value;
                                                });
                                                _setActiveCompany(value);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Text(
                                        companyName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.apartment_outlined,
                                          size: 18,
                                          color: Color(0xFF2563EB),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                companyName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                ),
                                              ),
                                              Text(
                                                'ID: $companyId',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _mutedText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Копировать ID',
                                          onPressed: () =>
                                              _copyCompanyId(companyId),
                                          icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 18,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCompanyContent(
                                    selectedCompany,
                                    employees,
                                    roles,
                                    positions,
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
}

class _BusinessGraphPainter extends CustomPainter {
  final List<MapEntry<Offset, Offset>> edges;

  _BusinessGraphPainter({
    required this.edges,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.2;
    for (final edge in edges) {
      canvas.drawLine(edge.key, edge.value, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BusinessGraphPainter oldDelegate) {
    return oldDelegate.edges != edges;
  }
}
