import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import '/utils/audit_log_service.dart';
import '/utils/company_module_settings.dart';
import '/utils/country_profile.dart';
import '/utils/country_tax_profile.dart';
import '/utils/default_company_roles.dart';
import '/utils/industry_scenarios.dart';
import '/utils/kz_oced_seed.dart';
import '/user_design/user_design.dart';
import 'dart:math';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CompanySetupWidget extends StatefulWidget {
  const CompanySetupWidget({super.key});

  static String routeName = 'companySetup';
  static String routePath = '/companySetup';

  @override
  State<CompanySetupWidget> createState() => _CompanySetupWidgetState();
}

class _CompanySetupWidgetState extends State<CompanySetupWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _nameController = TextEditingController();
  final _binController = TextEditingController();
  final _addressController = TextEditingController();
  final _branchController = TextEditingController();
  final _departmentController = TextEditingController();
  FormListFieldController<String>? _ocedValueController;
  List<String>? _ocedValues;
  FormFieldController<String>? _otraslController;
  String? _otraslValue;
  FormFieldController<String>? _formaController;
  String? _formaValue;
  FormFieldController<String>? _nalogController;
  String? _nalogValue;
  FormFieldController<String>? _valutaController;
  String? _valutaValue;
  String _countryCode = 'KZ';
  String _companyColorValue = '#E0F2FE';
  String _businessType = 'construction';
  Map<String, bool> _companyModules = normalizeCompanyModules(null);
  bool _ndsPayer = false;
  bool _buhEnabled = false;
  final List<String> _companyBranches = [];
  final List<Map<String, String>> _companyDepartments = [];
  final Map<String, Offset> _companyLayout = {};
  Size _layoutSize = Size.zero;
  bool _layoutReady = false;

  CountryProfile get _selectedCountryProfile =>
      countryProfileForCode(_countryCode);

  String _defaultCurrencyTitle(
    List<ValutaRecord> items, {
    String? countryCode,
  }) {
    if (items.isEmpty) return '';
    final baseCurrency = countryProfileForCode(countryCode ?? _countryCode)
        .baseCurrency
        .toLowerCase();
    for (final item in items) {
      final title = item.title.trim().toLowerCase();
      final code = item.kod.trim().toLowerCase();
      if (title == baseCurrency || code == baseCurrency) {
        return item.title;
      }
    }
    for (final item in items) {
      final title = item.title.trim().toLowerCase();
      final code = item.kod.trim().toLowerCase();
      if (title.contains(baseCurrency) || code.contains(baseCurrency)) {
        return item.title;
      }
    }
    return items.first.title;
  }

  bool _recordMatchesCountry(dynamic record) {
    return _recordMatchesCountryCode(record, _countryCode);
  }

  bool _recordMatchesCountryCode(dynamic record, String countryCode) {
    final data = record.snapshotData is Map
        ? Map<String, dynamic>.from(record.snapshotData as Map)
        : const <String, dynamic>{};
    final profile = countryProfileFromData(data);
    final explicitCode =
        (data['country_code'] ?? data['countryCode'] ?? '').toString().trim();
    if (explicitCode.isEmpty && countryCode == 'KZ') return true;
    return profile.countryCode == countryCode;
  }

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

  Color _borderForCompanyColor(Color color, bool isActive) {
    if (isActive) return const Color(0xFF2563EB);
    return HSLColor.fromColor(color)
        .withLightness(
            (HSLColor.fromColor(color).lightness - 0.22).clamp(0.0, 1.0))
        .toColor();
  }

  String _currentCompanyId() {
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    if (active.isNotEmpty && active != '__all__') return active;
    final primary = (currentUserDocument?.idCompany ?? '').trim();
    if (primary.isNotEmpty && primary != '__all__') return primary;
    final ids = currentUserDocument?.companyIds ?? const [];
    for (final id in ids) {
      final value = id.toString().trim();
      if (value.isNotEmpty && value != '__all__') return value;
    }
    return '';
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

  Future<Map<String, Map<String, dynamic>>> _loadCompanyProfilesById(
    List<String> companyIds,
  ) async {
    final ids = companyIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != '__all__')
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};

    final profiles = <String, Map<String, dynamic>>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      final snap = await FirebaseFirestore.instance
          .collection('company_profile')
          .where('idCompany', whereIn: chunk)
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final companyId = (data['idCompany'] ?? doc.id).toString().trim();
        if (companyId.isNotEmpty) {
          profiles[companyId] = {'id': companyId, ...data};
        }
      }
    }
    return profiles;
  }

  Future<Map<String, Map<String, List<Map<String, String>>>>>
      _loadCompanyStructureById(List<String> companyIds) async {
    final ids = companyIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != '__all__')
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};

    final result = <String, Map<String, List<Map<String, String>>>>{};
    void addBranch(String companyId, String name) {
      final cleanCompanyId = companyId.trim();
      final cleanName = name.trim();
      if (cleanCompanyId.isEmpty || cleanName.isEmpty) return;
      final bucket = result.putIfAbsent(
        cleanCompanyId,
        () => {
          'branches': <Map<String, String>>[],
          'departments': <Map<String, String>>[],
        },
      );
      final branches = bucket['branches']!;
      final exists = branches.any(
        (item) => (item['name'] ?? '').toLowerCase() == cleanName.toLowerCase(),
      );
      if (!exists) branches.add({'name': cleanName});
    }

    void addDepartment(String companyId, String name, String branch) {
      final cleanCompanyId = companyId.trim();
      final cleanName = name.trim();
      final cleanBranch = branch.trim();
      if (cleanCompanyId.isEmpty || cleanName.isEmpty) return;
      final bucket = result.putIfAbsent(
        cleanCompanyId,
        () => {
          'branches': <Map<String, String>>[],
          'departments': <Map<String, String>>[],
        },
      );
      final departments = bucket['departments']!;
      final exists = departments.any(
        (item) =>
            (item['name'] ?? '').toLowerCase() == cleanName.toLowerCase() &&
            (item['branch'] ?? '').toLowerCase() == cleanBranch.toLowerCase(),
      );
      if (!exists) {
        departments.add({'name': cleanName, 'branch': cleanBranch});
      }
      if (cleanBranch.isNotEmpty) addBranch(cleanCompanyId, cleanBranch);
    }

    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      final branchesSnap = await FirebaseFirestore.instance
          .collection('company_branches')
          .where('idCompany', whereIn: chunk)
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in branchesSnap.docs) {
        final data = doc.data();
        if (data['active'] == false) continue;
        addBranch(
          (data['idCompany'] ?? data['company_id'] ?? '').toString(),
          (data['name'] ?? data['title'] ?? data['branch_name'] ?? '')
              .toString(),
        );
      }

      final departmentsSnap = await FirebaseFirestore.instance
          .collection('company_departments')
          .where('idCompany', whereIn: chunk)
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in departmentsSnap.docs) {
        final data = doc.data();
        if (data['active'] == false) continue;
        addDepartment(
          (data['idCompany'] ?? data['company_id'] ?? '').toString(),
          (data['name'] ?? data['title'] ?? data['department_name'] ?? '')
              .toString(),
          (data['branch'] ?? data['branch_name'] ?? '').toString(),
        );
      }
    }
    return result;
  }

  List<String> _myCompanyIds() {
    final ids = <String>{
      _currentCompanyId(),
      ...((currentUserDocument?.companyIds ?? const [])
          .map((id) => id.toString())),
    }
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != '__all__')
        .toSet()
        .toList()
      ..sort();
    return ids;
  }

  Future<List<Map<String, dynamic>>> _loadMyCompanies() async {
    final companyIds = _myCompanyIds();
    final companiesById = <String, Map<String, dynamic>>{};
    if (companyIds.isNotEmpty) {
      for (final companyId in companyIds) {
        final snap = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get(const GetOptions(source: Source.serverAndCache));
        if (snap.exists) {
          companiesById[companyId] = {
            'id': companyId,
            ...Map<String, dynamic>.from(snap.data() ?? const {}),
          };
        }
      }
    } else if (currentUserUid.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .where('members', arrayContains: currentUserUid)
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in snap.docs) {
        companiesById[doc.id] = {
          'id': doc.id,
          ...Map<String, dynamic>.from(doc.data()),
        };
      }
    }

    final loadedCompanyIds = companiesById.keys.toList();
    final profiles = await _loadCompanyProfilesById(loadedCompanyIds);
    final structures = await _loadCompanyStructureById(loadedCompanyIds);
    return companiesById.entries.map((entry) {
      final structure = structures[entry.key] ?? const {};
      final collectionBranches = (structure['branches'] ?? const [])
          .map((item) => item['name'] ?? '')
          .where((name) => name.trim().isNotEmpty)
          .toList();
      final merged = {
        ...entry.value,
        ...(profiles[entry.key] ?? const <String, dynamic>{}),
      };
      final branchNames = {
        ..._branchNamesFromData(merged),
        ...collectionBranches,
      }.toList();
      final departments = [
        ..._departmentsFromData(merged),
        ...(structure['departments'] ?? const <Map<String, String>>[]),
      ];
      return {
        ...merged,
        'branch_names': branchNames,
        'branches': branchNames
            .map((name) => {
                  'name': name,
                  'type': 'branch',
                  'active': true,
                })
            .toList(),
        'departments': departments,
        'department_names': departments
            .map((item) => item['name'] ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList(),
        'id': entry.key,
      };
    }).toList()
      ..sort((a, b) => _companyDisplayName(a)
          .toLowerCase()
          .compareTo(_companyDisplayName(b).toLowerCase()));
  }

  Future<String> _currentCompanyTitle() async {
    final companyId = _currentCompanyId();
    if (companyId.isEmpty) return 'Компания';
    final companySnap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    final companyData = companySnap.data() ?? const <String, dynamic>{};
    final profiles = await _loadCompanyProfilesById([companyId]);
    final merged = {
      'id': companyId,
      ...companyData,
      ...(profiles[companyId] ?? const <String, dynamic>{}),
    };
    return _companyDisplayName(merged);
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

  List<String> _branchNamesFromData(Map<String, dynamic> data) {
    final rawNames = data['branch_names'];
    if (rawNames is Iterable) {
      final names = rawNames
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
      if (names.isNotEmpty) return names;
    }
    final rawBranches = data['branches'];
    if (rawBranches is Iterable) {
      return rawBranches
          .map((item) {
            if (item is Map) {
              return (item['name'] ?? '').toString().trim();
            }
            return item.toString().trim();
          })
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }
    return const [];
  }

  List<Map<String, String>> _departmentsFromData(Map<String, dynamic> data) {
    final items = <Map<String, String>>[];
    final rawDepartments = data['departments'];
    if (rawDepartments is Iterable) {
      for (final item in rawDepartments) {
        if (item is Map) {
          final name = (item['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          items.add({
            'name': name,
            'branch': (item['branch'] ??
                    item['branch_name'] ??
                    item['branchName'] ??
                    '')
                .toString()
                .trim(),
          });
        } else {
          final name = item.toString().trim();
          if (name.isNotEmpty) items.add({'name': name, 'branch': ''});
        }
      }
    }
    final rawNames = data['department_names'];
    if (rawNames is Iterable) {
      for (final item in rawNames) {
        final name = item.toString().trim();
        if (name.isEmpty) continue;
        if (!items.any((department) =>
            department['name']!.toLowerCase() == name.toLowerCase())) {
          items.add({'name': name, 'branch': ''});
        }
      }
    }
    final seen = <String>{};
    return items.where((item) {
      final key =
          '${item['name']!.toLowerCase()}|${item['branch']!.toLowerCase()}';
      return seen.add(key);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(ensureKazakhstanOcedSeeded);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _binController.dispose();
    _addressController.dispose();
    _branchController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _readLayoutRaw() {
    final raw = currentUserDocument?.snapshotData['company_layout'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  Offset _clampOffset(Offset value, Size size, double nodeSize) {
    final maxX = (size.width - nodeSize).clamp(0.0, size.width);
    final maxY = (size.height - nodeSize).clamp(0.0, size.height);
    final dx = value.dx.clamp(0.0, maxX);
    final dy = value.dy.clamp(0.0, maxY);
    return Offset(dx, dy);
  }

  void _ensureLayout(Size size, List<String> ids) {
    if (size.isEmpty) return;
    final nodeSize = 120.0;
    final needsReset = !_layoutReady ||
        _layoutSize != size ||
        !_companyLayout.keys.toSet().containsAll(ids);
    if (!needsReset) {
      _layoutSize = size;
      return;
    }
    final raw = _readLayoutRaw();
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
          next[id] = _clampOffset(Offset(dx, dy), size, nodeSize);
          continue;
        }
      }
    }
    final missing = ids.where((id) => !next.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      final companyIds = missing
          .where((id) =>
              !id.startsWith('branch:') && !id.startsWith('department:'))
          .toList();
      final branchIds =
          missing.where((id) => id.startsWith('branch:')).toList();
      final departmentIds =
          missing.where((id) => id.startsWith('department:')).toList();
      final center = Offset(size.width / 2, size.height / 2);
      final radius =
          (size.shortestSide / 2 - nodeSize).clamp(60.0, size.shortestSide / 2);
      for (var i = 0; i < companyIds.length; i++) {
        final angle = (2 * 3.1415926 * i) / max(1, companyIds.length);
        final dx = center.dx + radius * cos(angle) - nodeSize / 2;
        final dy = center.dy + radius * sin(angle) - nodeSize / 2;
        next[companyIds[i]] = _clampOffset(Offset(dx, dy), size, nodeSize);
      }
      void placeRow(List<String> row, double y) {
        if (row.isEmpty) return;
        final gap = size.width / (row.length + 1);
        for (var i = 0; i < row.length; i++) {
          next[row[i]] = _clampOffset(
            Offset(gap * (i + 1) - nodeSize / 2, y),
            size,
            nodeSize,
          );
        }
      }

      placeRow(branchIds, 190);
      placeRow(departmentIds, 300);
    }
    final activeIds = ids.toSet();
    _companyLayout.removeWhere((key, value) => !activeIds.contains(key));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _layoutSize = size;
        _companyLayout.addAll(next);
        _layoutReady = true;
      });
    });
  }

  Future<void> _saveLayout() async {
    if (currentUserReference == null || _layoutSize.isEmpty) return;
    final data = <String, dynamic>{};
    _companyLayout.forEach((id, offset) {
      final nx = _layoutSize.width == 0 ? 0 : offset.dx / _layoutSize.width;
      final ny = _layoutSize.height == 0 ? 0 : offset.dy / _layoutSize.height;
      data[id] = {
        'x': nx.clamp(0.0, 1.0),
        'y': ny.clamp(0.0, 1.0),
      };
    });
    await currentUserReference!.update({'company_layout': data});
  }

  Future<void> _showCreateCompanyDialog() async {
    var dialogCountryCode = _countryCode;
    var dialogNdsPayer = _ndsPayer;
    var dialogBuhEnabled = _buhEnabled;
    _companyColorValue = '#E0F2FE';
    _businessType = 'construction';
    _companyModules = modulesForBusinessType(_businessType);
    _companyBranches.clear();
    _companyDepartments.clear();
    _branchController.clear();
    _departmentController.clear();
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) =>
              MediaQuery.removeViewInsets(
            removeBottom: true,
            context: dialogContext,
            child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: const Text('Создание компании'),
              content: SizedBox(
                width: min(
                  MediaQuery.sizeOf(dialogContext).width - 48,
                  1120.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: min(
                      MediaQuery.sizeOf(dialogContext).width - 48,
                      760.0,
                    ),
                    maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.78,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _buildCompanyForm(
                      dialogSetState: setDialogState,
                      countryCode: dialogCountryCode,
                      onCountryChanged: (value) {
                        setDialogState(() {
                          dialogCountryCode = value;
                          _countryCode = value;
                          _ocedValues = [];
                          _ocedValueController = null;
                          _otraslValue = null;
                          _otraslController = null;
                          _formaValue = null;
                          _formaController = null;
                          _nalogValue = null;
                          _nalogController = null;
                          _valutaValue = null;
                          _valutaController = null;
                        });
                      },
                      ndsPayerValue: dialogNdsPayer,
                      buhEnabledValue: dialogBuhEnabled,
                      onNdsPayerChanged: (value) {
                        dialogNdsPayer = value;
                        _ndsPayer = value;
                        setDialogState(() {});
                      },
                      onBuhEnabledChanged: (value) {
                        dialogBuhEnabled = value;
                        _buhEnabled = value;
                        setDialogState(() {});
                      },
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _countryCode = dialogCountryCode;
                    _ndsPayer = dialogNdsPayer;
                    _buhEnabled = dialogBuhEnabled;
                    await _createCompany(
                      countryCode: dialogCountryCode,
                      ndsPayer: dialogNdsPayer,
                      buhEnabled: dialogBuhEnabled,
                    );
                    if (mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Создать'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateCompanyDialogState(
    StateSetter? dialogSetState,
    VoidCallback update,
  ) {
    setState(update);
    dialogSetState?.call(() {});
  }

  Widget _buildCompanyForm({
    StateSetter? dialogSetState,
    String? countryCode,
    ValueChanged<String>? onCountryChanged,
    bool? ndsPayerValue,
    bool? buhEnabledValue,
    ValueChanged<bool>? onNdsPayerChanged,
    ValueChanged<bool>? onBuhEnabledChanged,
  }) {
    final activeCountryCode = countryCode ?? _countryCode;
    final profile = countryProfileForCode(activeCountryCode);
    bool matchesActiveCountry(dynamic record) =>
        _recordMatchesCountryCode(record, activeCountryCode);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18.0),
        TextField(
          controller: _nameController,
          textAlignVertical: TextAlignVertical.center,
          decoration: _companyInputDecoration('Название'),
        ),
        SizedBox(height: 12.0),
        DropdownButtonFormField<String>(
          key: ValueKey('company-country-$activeCountryCode'),
          initialValue: activeCountryCode,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Страна'),
          items: const [
            DropdownMenuItem(value: 'KZ', child: Text('Казахстан')),
            DropdownMenuItem(value: 'TJ', child: Text('Таджикистан')),
          ],
          onChanged: (val) {
            if (val == null) return;
            if (onCountryChanged != null) {
              onCountryChanged(val);
              return;
            }
            _updateCompanyDialogState(dialogSetState, () {
              _countryCode = val;
              _ocedValues = [];
              _ocedValueController = null;
              _otraslValue = null;
              _otraslController = null;
              _formaValue = null;
              _formaController = null;
              _nalogValue = null;
              _nalogController = null;
              _valutaValue = null;
              _valutaController = null;
            });
          },
        ),
        SizedBox(height: 12.0),
        _buildCompanyColorPicker(
          value: _companyColorValue,
          onChanged: (value) => _updateCompanyDialogState(
            dialogSetState,
            () => _companyColorValue = value,
          ),
        ),
        SizedBox(height: 12.0),
        _buildCompanyModulesEditor(dialogSetState: dialogSetState),
        SizedBox(height: 12.0),
        TextField(
          controller: _binController,
          decoration: _companyInputDecoration(profile.identifierLabel),
        ),
        SizedBox(height: 12.0),
        TextField(
          controller: _addressController,
          decoration: _companyInputDecoration('Адрес'),
        ),
        SizedBox(height: 12.0),
        _buildBranchesEditor(dialogSetState: dialogSetState),
        SizedBox(height: 12.0),
        AuthUserStreamWidget(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  return StreamBuilder<List<OcedRecord>>(
                    stream: queryOcedRecord(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: SizedBox(
                            width: 50.0,
                            height: 50.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                        );
                      }
                      final ocedList =
                          snapshot.data!.where(matchesActiveCountry).toList();
                      _ocedValueController ??=
                          FormListFieldController<String>(_ocedValues ?? []);
                      return FlutterFlowDropDown<String>(
                        multiSelectController: _ocedValueController!,
                        options: ocedList.map((e) => e.title).toList(),
                        width: double.infinity,
                        height: 49.0,
                        searchHintTextStyle:
                            FlutterFlowTheme.of(context).labelMedium,
                        searchTextStyle:
                            FlutterFlowTheme.of(context).bodyMedium,
                        textStyle: FlutterFlowTheme.of(context).bodyMedium,
                        hintText: profile.activityLabel,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          size: 24.0,
                        ),
                        fillColor:
                            FlutterFlowTheme.of(context).secondaryBackground,
                        elevation: 2.0,
                        borderColor: FlutterFlowTheme.of(context).primary,
                        borderWidth: 1.0,
                        borderRadius: 8.0,
                        margin: EdgeInsetsDirectional.fromSTEB(
                            12.0, 0.0, 12.0, 0.0),
                        hidesUnderline: true,
                        isOverButton: false,
                        isSearchable: true,
                        isMultiSelect: true,
                        onMultiSelectChanged: (val) =>
                            _updateCompanyDialogState(dialogSetState, () {
                          _ocedValues = val ?? [];
                          _ocedValueController?.value = _ocedValues;
                          _ocedValueController?.update();
                        }),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 12.0),
              StreamBuilder<List<OtrasliRecord>>(
                stream: queryOtrasliRecord(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ),
                    );
                  }
                  final list =
                      snapshot.data!.where(matchesActiveCountry).toList();
                  _otraslController ??=
                      FormFieldController<String>(_otraslValue);
                  return FlutterFlowDropDown<String>(
                    controller: _otraslController!,
                    options: list.map((e) => e.title).toList(),
                    onChanged: (val) =>
                        _updateCompanyDialogState(dialogSetState, () {
                      _otraslValue = val;
                      _otraslController?.value = val;
                    }),
                    width: double.infinity,
                    height: 49.0,
                    textStyle: FlutterFlowTheme.of(context).bodyMedium,
                    hintText: 'Отрасль',
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: FlutterFlowTheme.of(context).secondaryText,
                      size: 24.0,
                    ),
                    fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                    elevation: 2.0,
                    borderColor: FlutterFlowTheme.of(context).primary,
                    borderWidth: 1.0,
                    borderRadius: 8.0,
                    margin:
                        EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
                    hidesUnderline: true,
                    isOverButton: false,
                    isSearchable: true,
                    isMultiSelect: false,
                  );
                },
              ),
              SizedBox(height: 12.0),
              Builder(
                builder: (context) {
                  return StreamBuilder<List<FormaRecord>>(
                    stream: queryFormaRecord(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: SizedBox(
                            width: 50.0,
                            height: 50.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                        );
                      }
                      final list =
                          snapshot.data!.where(matchesActiveCountry).toList();
                      _formaController ??=
                          FormFieldController<String>(_formaValue);
                      return FlutterFlowDropDown<String>(
                        controller: _formaController!,
                        options: list.map((e) => e.title).toList(),
                        onChanged: (val) =>
                            _updateCompanyDialogState(dialogSetState, () {
                          _formaValue = val;
                          _formaController?.value = val;
                        }),
                        width: double.infinity,
                        height: 49.0,
                        textStyle: FlutterFlowTheme.of(context).bodyMedium,
                        hintText: 'Форма собственности',
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          size: 24.0,
                        ),
                        fillColor:
                            FlutterFlowTheme.of(context).secondaryBackground,
                        elevation: 2.0,
                        borderColor: FlutterFlowTheme.of(context).primary,
                        borderWidth: 1.0,
                        borderRadius: 8.0,
                        margin: EdgeInsetsDirectional.fromSTEB(
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
              SizedBox(height: 12.0),
              Builder(
                builder: (context) {
                  return StreamBuilder<List<NalogiRecord>>(
                    stream: queryNalogiRecord(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: SizedBox(
                            width: 50.0,
                            height: 50.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                        );
                      }
                      final list =
                          snapshot.data!.where(matchesActiveCountry).toList();
                      _nalogController ??=
                          FormFieldController<String>(_nalogValue);
                      return FlutterFlowDropDown<String>(
                        controller: _nalogController!,
                        options: list.map((e) => e.title).toList(),
                        onChanged: (val) =>
                            _updateCompanyDialogState(dialogSetState, () {
                          _nalogValue = val;
                          _nalogController?.value = val;
                        }),
                        width: double.infinity,
                        height: 49.0,
                        textStyle: FlutterFlowTheme.of(context).bodyMedium,
                        hintText: 'Налоговый режим',
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          size: 24.0,
                        ),
                        fillColor:
                            FlutterFlowTheme.of(context).secondaryBackground,
                        elevation: 2.0,
                        borderColor: FlutterFlowTheme.of(context).primary,
                        borderWidth: 1.0,
                        borderRadius: 8.0,
                        margin: EdgeInsetsDirectional.fromSTEB(
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
              SizedBox(height: 12.0),
              StreamBuilder<List<ValutaRecord>>(
                stream: queryValutaRecord(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ),
                    );
                  }
                  final list =
                      snapshot.data!.where(matchesActiveCountry).toList();
                  final defaultValuta = _defaultCurrencyTitle(list,
                      countryCode: activeCountryCode);
                  if ((_valutaValue ?? '').isEmpty &&
                      defaultValuta.isNotEmpty) {
                    _valutaValue = defaultValuta;
                  }
                  _valutaController ??=
                      FormFieldController<String>(_valutaValue);
                  return FlutterFlowDropDown<String>(
                    controller: _valutaController!,
                    options: list.map((e) => e.title).toList(),
                    onChanged: (val) =>
                        _updateCompanyDialogState(dialogSetState, () {
                      _valutaValue = val;
                      _valutaController?.value = val;
                    }),
                    width: double.infinity,
                    height: 49.0,
                    textStyle: FlutterFlowTheme.of(context).bodyMedium,
                    hintText: 'Валюта',
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: FlutterFlowTheme.of(context).secondaryText,
                      size: 24.0,
                    ),
                    fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                    elevation: 2.0,
                    borderColor: FlutterFlowTheme.of(context).primary,
                    borderWidth: 1.0,
                    borderRadius: 8.0,
                    margin:
                        EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
                    hidesUnderline: true,
                    isOverButton: false,
                    isSearchable: true,
                    isMultiSelect: false,
                  );
                },
              ),
              SizedBox(height: 12.0),
              _buildInstantToggle(
                title: 'Плательщик ${profile.vatLabel}',
                value: ndsPayerValue ?? _ndsPayer,
                onChanged: onNdsPayerChanged ??
                    (val) => _updateCompanyDialogState(
                          dialogSetState,
                          () => _ndsPayer = val,
                        ),
              ),
              const SizedBox(height: 8.0),
              _buildInstantToggle(
                title: 'Ведет бухгалтерский учет',
                value: buhEnabledValue ?? _buhEnabled,
                onChanged: onBuhEnabledChanged ??
                    (val) => _updateCompanyDialogState(
                          dialogSetState,
                          () => _buhEnabled = val,
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchesEditor({
    StateSetter? dialogSetState,
    List<String>? branches,
    List<Map<String, String>>? departments,
    TextEditingController? controller,
    TextEditingController? departmentController,
  }) {
    final branchItems = branches ?? _companyBranches;
    final departmentItems = departments ?? _companyDepartments;
    final branchInputController = controller ?? _branchController;
    final departmentInputController =
        departmentController ?? _departmentController;
    var selectedDepartmentBranch = '';

    void addBranch() {
      final name = branchInputController.text.trim();
      if (name.isEmpty) return;
      final exists =
          branchItems.any((item) => item.toLowerCase() == name.toLowerCase());
      if (exists) {
        branchInputController.clear();
        return;
      }
      _updateCompanyDialogState(dialogSetState, () {
        branchItems.add(name);
        branchInputController.clear();
      });
    }

    void addDepartment() {
      final name = departmentInputController.text.trim();
      if (name.isEmpty) return;
      final exists = departmentItems.any((item) =>
          (item['name'] ?? '').toLowerCase() == name.toLowerCase() &&
          (item['branch'] ?? '').toLowerCase() ==
              selectedDepartmentBranch.toLowerCase());
      if (exists) {
        departmentInputController.clear();
        return;
      }
      _updateCompanyDialogState(dialogSetState, () {
        departmentItems.add({
          'name': name,
          'branch': selectedDepartmentBranch,
        });
        departmentInputController.clear();
      });
    }

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
            'Филиалы',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: branchInputController,
                  decoration: _companyInputDecoration('Название филиала'),
                  onSubmitted: (_) => addBranch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Добавить филиал',
                onPressed: addBranch,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: FlutterFlowTheme.of(context).primary,
                ),
              ),
            ],
          ),
          if (branchItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: branchItems.map((branch) {
                return InputChip(
                  label: Text(branch),
                  onDeleted: () => _updateCompanyDialogState(
                    dialogSetState,
                    () => branchItems.remove(branch),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Подразделения',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setLocalState) => Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: departmentInputController,
                    decoration:
                        _companyInputDecoration('Название подразделения'),
                    onSubmitted: (_) => addDepartment(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedDepartmentBranch,
                    isExpanded: true,
                    decoration: _companyInputDecoration('Филиал'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Без филиала'),
                      ),
                      ...branchItems.map(
                        (branch) => DropdownMenuItem(
                          value: branch,
                          child: Text(
                            branch,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setLocalState(
                      () => selectedDepartmentBranch = value ?? '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Добавить подразделение',
                  onPressed: addDepartment,
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ],
            ),
          ),
          if (departmentItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: departmentItems.map((department) {
                final name = department['name'] ?? '';
                final branch = department['branch'] ?? '';
                return InputChip(
                  label: Text(
                    branch.isEmpty ? name : '$name · $branch',
                  ),
                  onDeleted: () => _updateCompanyDialogState(
                    dialogSetState,
                    () => departmentItems.remove(department),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyModulesEditor({
    StateSetter? dialogSetState,
    String? businessType,
    Map<String, bool>? modules,
    ValueChanged<String>? onBusinessTypeChanged,
    ValueChanged<Map<String, bool>>? onModulesChanged,
  }) {
    final currentBusinessType = businessType ?? _businessType;
    final currentModules = modules ?? _companyModules;

    void updateModules(Map<String, bool> next) {
      if (onModulesChanged != null) {
        onModulesChanged(next);
      } else {
        _updateCompanyDialogState(dialogSetState, () {
          _companyModules = next;
        });
      }
    }

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
            'Разделы компании',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: currentBusinessType,
            isExpanded: true,
            decoration: _companyInputDecoration('Тип бизнеса'),
            items: kBusinessTypeLabels.entries
                .map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final preset = modulesForBusinessType(value);
              if (onBusinessTypeChanged != null) {
                onBusinessTypeChanged(value);
                onModulesChanged?.call(preset);
              } else {
                _updateCompanyDialogState(dialogSetState, () {
                  _businessType = value;
                  _companyModules = preset;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCompanyModuleKeys.map((key) {
              final enabled = currentModules[key] != false;
              return FilterChip(
                selected: enabled,
                label: Text(kCompanyModuleLabels[key] ?? key),
                onSelected: (value) {
                  updateModules({
                    ...currentModules,
                    key: value,
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  InputDecoration _companyInputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      labelText: null,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      isDense: false,
      alignLabelWithHint: false,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: FlutterFlowTheme.of(context).primary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).primary,
          width: 1.5,
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
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  letterSpacing: 0.0,
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
                          : _borderForCompanyColor(color, false),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                      ),
                      color: value
                          ? activeColor
                          : FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
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
    final nameController = TextEditingController(text: _ownerDisplayName());
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

  Widget _buildOwnerNode() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showOwnerDialog,
      child: Stack(
        children: [
          Container(
            width: 108,
            height: 108,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF7E6),
              border: Border.all(color: const Color(0xFFF59E0B), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wb_sunny_outlined,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  _ownerDisplayName(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _ownerTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
            right: 2,
            top: 2,
            child: Tooltip(
              message: 'Редактировать собственника',
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: Color(0xFFF59E0B),
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
    required bool isActive,
    required String colorHex,
    VoidCallback? onEdit,
  }) {
    final cardColor = _companyColorFromHex(colorHex);
    final borderColor = _borderForCompanyColor(cardColor, isActive);
    return Stack(
      children: [
        Container(
          width: 120,
          height: 92,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isActive ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Активна',
                    style: TextStyle(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: Tooltip(
            message: 'Редактировать',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onEdit,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStructureNode({
    required String name,
    required String type,
  }) {
    final isBranch = type == 'branch';
    return Container(
      width: 120,
      height: 82,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: isBranch ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBranch ? const Color(0xFF60A5FA) : const Color(0xFF86EFAC),
          width: 1.4,
        ),
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
              Icon(
                isBranch
                    ? Icons.account_tree_outlined
                    : Icons.groups_2_outlined,
                size: 17,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isBranch ? 'Филиал' : 'Подразделение',
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
            name,
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

  Future<void> _createCompany({
    String? countryCode,
    bool? ndsPayer,
    bool? buhEnabled,
  }) async {
    final name = _nameController.text.trim();
    final bin = _binController.text.trim();
    final address = _addressController.text.trim();
    final countryProfile = countryProfileForCode(countryCode ?? _countryCode);
    if (name.isEmpty || bin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Заполните название и ${countryProfile.identifierLabel}.'),
        ),
      );
      return;
    }

    final uid = currentUserUid;
    if (uid.isEmpty) {
      return;
    }

    int? maxCompanies;
    final rawMax = currentUserDocument?.snapshotData['tariff_max_companies'];
    if (rawMax is num) {
      maxCompanies = rawMax.toInt();
    } else {
      final tariffId =
          currentUserDocument?.snapshotData['tariff_id']?.toString();
      if (tariffId != null && tariffId.isNotEmpty) {
        final tariffSnap = await FirebaseFirestore.instance
            .collection('tariffs')
            .doc(tariffId)
            .get();
        if (tariffSnap.exists) {
          final data = Map<String, dynamic>.from(tariffSnap.data() as Map);
          final maxRaw = data['max_companies'] ?? data['maxCompanies'];
          if (maxRaw is num) {
            maxCompanies = maxRaw.toInt();
          }
        }
      }
    }
    final currentCompanies = currentUserDocument?.companyIds.length ?? 0;
    if (maxCompanies != null && maxCompanies > 0) {
      if (currentCompanies >= maxCompanies) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Лимит компаний по тарифу: $maxCompanies. Обновите тариф.'),
          ),
        );
        return;
      }
    }

    final companyRef = FirebaseFirestore.instance.collection('companies').doc();
    final taxProfile =
        taxProfileForCountry(countryCode: countryProfile.countryCode);
    final resolvedNdsPayer = ndsPayer ?? _ndsPayer;
    final resolvedBuhEnabled = buhEnabled ?? _buhEnabled;
    final branchNames = _companyBranches
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final branches = branchNames
        .map((branchName) => {
              'name': branchName,
              'type': 'branch',
              'active': true,
            })
        .toList();
    final departments = _companyDepartments
        .map((item) => {
              'name': (item['name'] ?? '').trim(),
              'branch': (item['branch'] ?? '').trim(),
              'branch_name': (item['branch'] ?? '').trim(),
              'type': 'department',
              'active': true,
            })
        .where((item) => item['name'].toString().isNotEmpty)
        .toList();
    final departmentNames = departments
        .map((item) => item['name'].toString())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final industryScenario = industryScenarioForBusinessType(_businessType);
    final companyData = {
      'name': name,
      'bin': bin,
      'identifier': bin,
      'country_code': countryProfile.countryCode,
      'country': countryProfile.countryTitle,
      'base_currency': countryProfile.baseCurrency,
      'currency_symbol': countryProfile.currencySymbol,
      'address': address,
      'oced': _ocedValues ?? [],
      'otrasl': _otraslValue ?? '',
      'forma': _formaValue ?? '',
      'nalog': _nalogValue ?? '',
      'valuta': _valutaValue ?? '',
      'company_color': _companyColorValue,
      'companyColor': _companyColorValue,
      'business_type': _businessType,
      'businessType': _businessType,
      ...industryScenario,
      'company_modules': _companyModules,
      'enabled_modules': _companyModules,
      'branches': branches,
      'branch_names': branchNames,
      'departments': departments,
      'department_names': departmentNames,
      'ndsPayer': resolvedNdsPayer,
      'nds_payer': resolvedNdsPayer,
      'nds_rate': taxProfile.vatRatePercent,
      'kpn_rate': taxProfile.profitTaxRatePercent,
      'tax_profile_version': taxProfile.version,
      'buh_enabled': resolvedBuhEnabled,
      'buhEnabled': resolvedBuhEnabled,
      'buh': resolvedBuhEnabled,
      'ownerId': uid,
      'members': [uid],
      kUserDesignTemplateField: kUserDesignReference,
      kUserDesignConfigField: defaultCustomUserDesignConfig(),
      'data_locked': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await companyRef.set(companyData);
    await AuditLogService.logAction(
      companyId: companyRef.id,
      action: 'create',
      entity: 'company',
      entityId: companyRef.id,
      entityTitle: name,
      after: companyData,
      details: const {'message': 'Создана компания'},
    );

    await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(companyRef.id)
        .set({
      'idCompany': companyRef.id,
      'user_id': uid,
      'name': name,
      'bin': bin,
      'identifier': bin,
      'country_code': countryProfile.countryCode,
      'country': countryProfile.countryTitle,
      'base_currency': countryProfile.baseCurrency,
      'currency_symbol': countryProfile.currencySymbol,
      'address': address,
      'oced': _ocedValues ?? [],
      'otrasl': _otraslValue ?? '',
      'forma': _formaValue ?? '',
      'nalog': _nalogValue ?? '',
      'valuta': _valutaValue ?? '',
      'company_color': _companyColorValue,
      'companyColor': _companyColorValue,
      'business_type': _businessType,
      'businessType': _businessType,
      ...industryScenario,
      'company_modules': _companyModules,
      'enabled_modules': _companyModules,
      'branches': branches,
      'branch_names': branchNames,
      'departments': departments,
      'department_names': departmentNames,
      'ndsPayer': resolvedNdsPayer,
      'nds_payer': resolvedNdsPayer,
      'buh_enabled': resolvedBuhEnabled,
      'buhEnabled': resolvedBuhEnabled,
      'buh': resolvedBuhEnabled,
      'nds_rate': taxProfile.vatRatePercent,
      'kpn_rate': taxProfile.profitTaxRatePercent,
      'tax_profile_version': taxProfile.version,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final branchName in branchNames) {
      await FirebaseFirestore.instance.collection('company_branches').add({
        'idCompany': companyRef.id,
        'company_id': companyRef.id,
        'user_id': uid,
        'name': branchName,
        'type': 'branch',
        'active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    for (final department in departments) {
      await FirebaseFirestore.instance.collection('company_departments').add({
        'idCompany': companyRef.id,
        'company_id': companyRef.id,
        'user_id': uid,
        'name': department['name'],
        'branch': department['branch'],
        'branch_name': department['branch_name'],
        'type': 'department',
        'active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await currentUserReference?.update({
      'idCompany': companyRef.id,
      'activeCompanyId': companyRef.id,
      'companyIds': FieldValue.arrayUnion([companyRef.id]),
      'company_modules': _companyModules,
      'enabled_modules': _companyModules,
      'business_type': _businessType,
      'role': 'owner',
    });

    await ensureDefaultCompanyRoles(
      firestore: FirebaseFirestore.instance,
      companyId: companyRef.id,
      userId: uid,
    );

    await UshetRecord.collection.doc().set(createUshetRecordData(
          doxodUp: 0.0,
          doxodBu: 0.0,
          rashodUp: 0.0,
          rashodBu: 0.0,
          nds: 0.0,
          ndsPay: 0.0,
          kpn: 0.0,
          idCompany: companyRef.id,
          pribilUp: 0.0,
          pribilBu: 0.0,
          balanceUp: 0.0,
          balanceBu: 0.0,
          kpnPay: 0.0,
        ));

    if (mounted) {
      context.goNamed(HomeWidget.routeName);
    }
  }

  Future<void> _setActiveCompany(String companyId) async {
    if (currentUserReference == null) return;
    await currentUserReference!.update({
      'idCompany': companyId,
      'activeCompanyId': companyId,
      'companyScope': 'single',
      'companyIds': FieldValue.arrayUnion([companyId]),
    });
  }

  Future<void> _openEditDialog(String id, Map<String, dynamic> data) async {
    final profileSnap = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(id)
        .get(const GetOptions(source: Source.serverAndCache));
    final profileData = profileSnap.data() ?? const <String, dynamic>{};
    final editData = {
      ...data,
      ...profileData,
    };
    final nameController = TextEditingController(
        text: _companyDisplayName(editData, fallback: ''));
    final binController =
        TextEditingController(text: (editData['bin'] ?? '').toString());
    final addressController =
        TextEditingController(text: (editData['address'] ?? '').toString());
    var ocedValues = _stringList(editData['oced']);
    var otraslValue = (editData['otrasl'] ?? '').toString().trim();
    var formaValue = (editData['forma'] ?? '').toString().trim();
    var nalogValue = (editData['nalog'] ?? '').toString().trim();
    var valutaValue = (editData['valuta'] ?? '').toString().trim();
    var companyColorValue = _companyColorHex(editData);
    var businessType = (editData['business_type'] ??
            editData['businessType'] ??
            'construction')
        .toString()
        .trim();
    if (!kBusinessTypeLabels.containsKey(businessType)) {
      businessType = 'construction';
    }
    var companyModules = normalizeCompanyModules(
      editData['company_modules'] ?? editData['enabled_modules'],
    );
    var editCountryCode = countryProfileFromData(editData).countryCode;
    final branchController = TextEditingController();
    final departmentController = TextEditingController();
    final branchNames = _branchNamesFromData(editData);
    final departments = _departmentsFromData(editData);
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
    bool matchesEditCountry(dynamic record) {
      final data = record.snapshotData is Map
          ? Map<String, dynamic>.from(record.snapshotData as Map)
          : const <String, dynamic>{};
      final explicitCode =
          (data['country_code'] ?? data['countryCode'] ?? '').toString().trim();
      if (explicitCode.isEmpty && editCountryCode == 'KZ') return true;
      return countryProfileFromData(data).countryCode == editCountryCode;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final editProfile = countryProfileForCode(editCountryCode);
            return AlertDialog(
              title: const Text('Редактировать компанию'),
              content: SizedBox(
                width: min(MediaQuery.sizeOf(context).width - 48, 1120.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: _companyInputDecoration('Название'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: editCountryCode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Страна'),
                        items: const [
                          DropdownMenuItem(
                              value: 'KZ', child: Text('Казахстан')),
                          DropdownMenuItem(
                              value: 'TJ', child: Text('Таджикистан')),
                        ],
                        onChanged: saving
                            ? null
                            : (val) => setDialogState(() {
                                  editCountryCode = val ?? 'KZ';
                                  ocedValues = [];
                                  ocedController.value = ocedValues;
                                  ocedController.update();
                                  otraslValue = '';
                                  otraslController.value = null;
                                  formaValue = '';
                                  formaController.value = null;
                                  nalogValue = '';
                                  nalogController.value = null;
                                  valutaValue = '';
                                  valutaController.value = null;
                                }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: binController,
                        decoration: _companyInputDecoration(
                            editProfile.identifierLabel),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: addressController,
                        decoration: _companyInputDecoration('Адрес'),
                      ),
                      const SizedBox(height: 8),
                      _buildBranchesEditor(
                        dialogSetState: setDialogState,
                        branches: branchNames,
                        departments: departments,
                        controller: branchController,
                        departmentController: departmentController,
                      ),
                      const SizedBox(height: 8),
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
                                          child: CircularProgressIndicator());
                                    }
                                    final list = snapshot.data!
                                        .where(matchesEditCountry)
                                        .toList();
                                    final options =
                                        list.map((e) => e.title).toList();
                                    final extra = ocedValues
                                        .where((e) => !options.contains(e));
                                    return FlutterFlowDropDown<String>(
                                      multiSelectController: ocedController,
                                      options: [...options, ...extra],
                                      width: double.infinity,
                                      height: 49.0,
                                      searchHintTextStyle:
                                          FlutterFlowTheme.of(context)
                                              .labelMedium,
                                      searchTextStyle:
                                          FlutterFlowTheme.of(context)
                                              .bodyMedium,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium,
                                      hintText: editProfile.activityLabel,
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
                                                ocedController.value =
                                                    ocedValues;
                                                ocedController.update();
                                              }),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<List<OtrasliRecord>>(
                              stream: queryOtrasliRecord(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                final options = snapshot.data!
                                    .where(matchesEditCountry)
                                    .map((e) => e.title)
                                    .toList();
                                return FlutterFlowDropDown<String>(
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
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                return StreamBuilder<List<FormaRecord>>(
                                  stream: queryFormaRecord(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    final options = snapshot.data!
                                        .where(matchesEditCountry)
                                        .map((e) => e.title)
                                        .toList();
                                    return FlutterFlowDropDown<String>(
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
                                      textStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium,
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
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                return StreamBuilder<List<NalogiRecord>>(
                                  stream: queryNalogiRecord(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    final options = snapshot.data!
                                        .where(matchesEditCountry)
                                        .map((e) => e.title)
                                        .toList();
                                    return FlutterFlowDropDown<String>(
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
                                      textStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium,
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
                            const SizedBox(height: 8),
                            StreamBuilder<List<ValutaRecord>>(
                              stream: queryValutaRecord(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                final list = snapshot.data!
                                    .where(matchesEditCountry)
                                    .toList();
                                final options =
                                    list.map((e) => e.title).toList();
                                if (valutaValue.isEmpty) {
                                  valutaValue = _defaultCurrencyTitle(list);
                                  valutaController.value = valutaValue;
                                }
                                return FlutterFlowDropDown<String>(
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
                      const SizedBox(height: 8),
                      _buildInstantToggle(
                        title: 'Плательщик НДС',
                        value: nds,
                        enabled: !saving,
                        onChanged: (val) => setDialogState(() => nds = val),
                      ),
                      const SizedBox(height: 8),
                      _buildCompanyColorPicker(
                        value: companyColorValue,
                        enabled: !saving,
                        onChanged: (value) => setDialogState(
                          () => companyColorValue = value,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCompanyModulesEditor(
                        dialogSetState: setDialogState,
                        businessType: businessType,
                        modules: companyModules,
                        onBusinessTypeChanged: (value) =>
                            setDialogState(() => businessType = value),
                        onModulesChanged: (value) =>
                            setDialogState(() => companyModules = value),
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
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final bin = binController.text.trim();
                          if (name.isEmpty || bin.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Заполните название и ${editProfile.identifierLabel}.',
                                ),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          final taxProfile = taxProfileForCountry(
                            countryCode: editCountryCode,
                          );
                          final cleanBranchNames = branchNames
                              .map((item) => item.trim())
                              .where((item) => item.isNotEmpty)
                              .toSet()
                              .toList();
                          final branches = cleanBranchNames
                              .map((branchName) => {
                                    'name': branchName,
                                    'type': 'branch',
                                    'active': true,
                                  })
                              .toList();
                          final cleanDepartments = departments
                              .map((item) => {
                                    'name': (item['name'] ?? '').trim(),
                                    'branch': (item['branch'] ?? '').trim(),
                                    'branch_name':
                                        (item['branch'] ?? '').trim(),
                                    'type': 'department',
                                    'active': true,
                                  })
                              .where((item) =>
                                  item['name'].toString().trim().isNotEmpty)
                              .toList();
                          final departmentNames = cleanDepartments
                              .map((item) => item['name'].toString().trim())
                              .where((item) => item.isNotEmpty)
                              .toSet()
                              .toList();
                          final update = {
                            'name': name,
                            'bin': bin,
                            'identifier': bin,
                            'country_code': editProfile.countryCode,
                            'country': editProfile.countryTitle,
                            'base_currency': editProfile.baseCurrency,
                            'currency_symbol': editProfile.currencySymbol,
                            'address': addressController.text.trim(),
                            'oced': ocedValues,
                            'otrasl': otraslValue,
                            'forma': formaValue,
                            'nalog': nalogValue,
                            'valuta': valutaValue,
                            'company_color': companyColorValue,
                            'companyColor': companyColorValue,
                            'business_type': businessType,
                            'businessType': businessType,
                            ...industryScenarioForBusinessType(businessType),
                            'company_modules': companyModules,
                            'enabled_modules': companyModules,
                            'branches': branches,
                            'branch_names': cleanBranchNames,
                            'departments': cleanDepartments,
                            'department_names': departmentNames,
                            'ndsPayer': nds,
                            'nds_payer': nds,
                            'nds_rate': taxProfile.vatRatePercent,
                            'kpn_rate': taxProfile.profitTaxRatePercent,
                            'tax_profile_version': taxProfile.version,
                            'buh_enabled': buhEnabled,
                            'buhEnabled': buhEnabled,
                            'buh': buhEnabled,
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          try {
                            await FirebaseFirestore.instance
                                .collection('companies')
                                .doc(id)
                                .set(update, SetOptions(merge: true));
                            await FirebaseFirestore.instance
                                .collection('company_profile')
                                .doc(id)
                                .set({
                              'idCompany': id,
                              'user_id': currentUserUid,
                              ...update,
                              'updated_at': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                            final existingBranches = await FirebaseFirestore
                                .instance
                                .collection('company_branches')
                                .where('idCompany', isEqualTo: id)
                                .get();
                            final existingDepartments = await FirebaseFirestore
                                .instance
                                .collection('company_departments')
                                .where('idCompany', isEqualTo: id)
                                .get();
                            final batch = FirebaseFirestore.instance.batch();
                            for (final doc in existingBranches.docs) {
                              batch.delete(doc.reference);
                            }
                            for (final doc in existingDepartments.docs) {
                              batch.delete(doc.reference);
                            }
                            for (final branchName in cleanBranchNames) {
                              final ref = FirebaseFirestore.instance
                                  .collection('company_branches')
                                  .doc();
                              batch.set(ref, {
                                'idCompany': id,
                                'company_id': id,
                                'user_id': currentUserUid,
                                'name': branchName,
                                'type': 'branch',
                                'active': true,
                                'created_at': FieldValue.serverTimestamp(),
                                'updated_at': FieldValue.serverTimestamp(),
                              });
                            }
                            for (final department in cleanDepartments) {
                              final ref = FirebaseFirestore.instance
                                  .collection('company_departments')
                                  .doc();
                              batch.set(ref, {
                                'idCompany': id,
                                'company_id': id,
                                'user_id': currentUserUid,
                                'name': department['name'],
                                'branch': department['branch'],
                                'branch_name': department['branch_name'],
                                'type': 'department',
                                'active': true,
                                'created_at': FieldValue.serverTimestamp(),
                                'updated_at': FieldValue.serverTimestamp(),
                              });
                            }
                            await batch.commit();
                            if (id == _currentCompanyId()) {
                              await currentUserReference?.update({
                                'name_Company': name,
                                'company_modules': companyModules,
                                'enabled_modules': companyModules,
                                'business_type': businessType,
                              });
                            }
                            await AuditLogService.logAction(
                              companyId: id,
                              action: 'update',
                              entity: 'company',
                              entityId: id,
                              entityTitle: name,
                              before: data,
                              after: update,
                              details: const {
                                'message': 'Изменены данные компании',
                              },
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Компания обновлена'),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
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
            );
          },
        );
      },
    );
    if (mounted) {
      setState(() {});
    }
    nameController.dispose();
    binController.dispose();
    addressController.dispose();
    branchController.dispose();
    departmentController.dispose();
  }

  Widget _buildCompaniesGraph(List<Map<String, dynamic>> companies) {
    final activeId = _currentCompanyId();
    final structureNodes = <Map<String, String>>[];
    for (final company in companies) {
      final companyId = (company['id'] ?? '').toString();
      if (companyId.isEmpty) continue;
      final branches = _branchNamesFromData(company).toSet().toList();
      structureNodes.addAll(
        branches.map((name) => {
              'id': 'branch:$companyId:$name',
              'type': 'branch',
              'name': name,
              'parent_id': companyId,
            }),
      );
      structureNodes.addAll(
        _departmentsFromData(company).map((department) {
          final name = (department['name'] ?? '').trim();
          final branch = (department['branch'] ?? '').trim();
          return {
            'id': 'department:$companyId:$name:$branch',
            'type': 'department',
            'name': name,
            'parent_id':
                branch.isEmpty ? companyId : 'branch:$companyId:$branch',
          };
        }),
      );
    }
    structureNodes.removeWhere((node) => (node['name'] ?? '').trim().isEmpty);
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasHeight = 390.0;
        final size = Size(constraints.maxWidth, canvasHeight);
        final companyIds = companies
            .map((company) => (company['id'] ?? '').toString())
            .toList();
        final structureIds = structureNodes
            .map((node) => (node['id'] ?? '').toString())
            .toList();
        _ensureLayout(size, [...companyIds, ...structureIds]);
        final ownerCenter = Offset(size.width / 2, size.height / 2);
        final nodeSize = 120.0;
        final nodeCentersById = <String, Offset>{};
        for (final id in [...companyIds, ...structureIds]) {
          final pos = _companyLayout[id] ?? const Offset(0, 0);
          nodeCentersById[id] = Offset(pos.dx + nodeSize / 2, pos.dy + 46);
        }
        final ownerEdges = companies.map((company) {
          final id = (company['id'] ?? '').toString();
          return MapEntry(ownerCenter, nodeCentersById[id] ?? ownerCenter);
        }).toList();
        final structureEdges = structureNodes
            .map((node) {
              final id = (node['id'] ?? '').toString();
              final parentId = (node['parent_id'] ?? '').toString();
              final from = nodeCentersById[parentId];
              final to = nodeCentersById[id];
              if (from == null || to == null) return null;
              return MapEntry(from, to);
            })
            .whereType<MapEntry<Offset, Offset>>()
            .toList();
        return SizedBox(
          height: canvasHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CompanyGraphPainter(
                    edges: [...ownerEdges, ...structureEdges],
                  ),
                ),
              ),
              Positioned(
                left: ownerCenter.dx - 54,
                top: ownerCenter.dy - 54,
                child: _buildOwnerNode(),
              ),
              ...companies.map((company) {
                final id = (company['id'] ?? '').toString();
                final name = _companyDisplayName(company, fallback: id);
                final isActive = id == activeId;
                final pos = _companyLayout[id] ?? const Offset(0, 0);
                return Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final current = _companyLayout[id] ?? pos;
                        _companyLayout[id] = _clampOffset(
                          current + details.delta,
                          size,
                          nodeSize,
                        );
                      });
                    },
                    onPanEnd: (_) => _saveLayout(),
                    onTap: () async {
                      if (!isActive) {
                        await _setActiveCompany(id);
                      }
                    },
                    onLongPress: () => _openEditDialog(id, company),
                    child: _buildCompanyNode(
                      name: name,
                      isActive: isActive,
                      colorHex: _companyColorHex(company),
                      onEdit: () => _openEditDialog(id, company),
                    ),
                  ),
                );
              }).toList(),
              ...structureNodes.map((node) {
                final id = (node['id'] ?? '').toString();
                final pos = _companyLayout[id] ?? const Offset(0, 0);
                return Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final current = _companyLayout[id] ?? pos;
                        _companyLayout[id] = _clampOffset(
                          current + details.delta,
                          size,
                          nodeSize,
                        );
                      });
                    },
                    onPanEnd: (_) => _saveLayout(),
                    child: _buildStructureNode(
                      name: (node['name'] ?? '').toString(),
                      type: (node['type'] ?? '').toString(),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        drawer: Drawer(
          elevation: 16.0,
          child: DrawersUsersWidget(),
        ),
        body: SafeArea(
          top: true,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (responsiveVisibility(
                context: context,
                phone: false,
                tablet: false,
              ))
                Container(
                  width: FFAppState().userSidebarCollapsed ? 88.0 : 270.0,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    border: Border.all(color: Color(0xFFE5E7EB)),
                  ),
                  child: DrawersUsersWidget(),
                ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional(0.0, -1.0),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxWidth: 1170.0),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Row(
                            children: [
                              if (responsiveVisibility(
                                context: context,
                                tabletLandscape: false,
                                desktop: false,
                              ))
                                Padding(
                                  padding: EdgeInsets.all(5.0),
                                  child: FlutterFlowIconButton(
                                    borderRadius: 8.0,
                                    buttonSize: 40.0,
                                    fillColor:
                                        FlutterFlowTheme.of(context).primary,
                                    icon: Icon(
                                      Icons.menu,
                                      color: FlutterFlowTheme.of(context).info,
                                      size: 24.0,
                                    ),
                                    onPressed: () async {
                                      scaffoldKey.currentState!.openDrawer();
                                    },
                                  ),
                                ),
                              Expanded(
                                child: FutureBuilder<String>(
                                  future: _currentCompanyTitle(),
                                  builder: (context, snapshot) {
                                    return HeaderWidget(
                                      title: snapshot.data ?? 'Компания',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding:
                                EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 24.0),
                            child: Container(
                              padding: EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AuthUserStreamWidget(
                                    builder: (context) {
                                      final companyId = _currentCompanyId();
                                      if (companyId.isEmpty) {
                                        return SizedBox.shrink();
                                      }
                                      return Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(12.0),
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate,
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
                                                    'ID компании',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  SizedBox(height: 4.0),
                                                  Text(
                                                    companyId,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall,
                                                  ),
                                                  SizedBox(height: 4.0),
                                                  Text(
                                                    'Передайте этот ID сотруднику для регистрации.',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.copy,
                                                size: 18.0,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                              ),
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: companyId,
                                                  ),
                                                );
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'ID компании скопирован'),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 16.0),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Мои компании',
                                          style: FlutterFlowTheme.of(context)
                                              .titleMedium
                                              .override(
                                                font: GoogleFonts.interTight(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      FFButtonWidget(
                                        onPressed: _showCreateCompanyDialog,
                                        text: 'Добавить компанию',
                                        icon: Icon(
                                          Icons.add,
                                          size: 16,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                        ),
                                        options: FFButtonOptions(
                                          height: 36.0,
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  14.0, 0.0, 14.0, 0.0),
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          textStyle: FlutterFlowTheme.of(
                                                  context)
                                              .labelMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                              ),
                                          elevation: 0.0,
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.0),
                                  FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _loadMyCompanies(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: SizedBox(
                                            width: 36.0,
                                            height: 36.0,
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      final companies =
                                          snapshot.data ?? const [];
                                      if (companies.isEmpty) {
                                        return Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            border: Border.all(
                                                color: Color(0xFFE5E7EB)),
                                          ),
                                          child: Text(
                                            'Компаний пока нет. Создайте первую компанию ниже.',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall,
                                          ),
                                        );
                                      }
                                      return _buildCompaniesGraph(
                                        companies,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyGraphPainter extends CustomPainter {
  final List<MapEntry<Offset, Offset>> edges;

  _CompanyGraphPainter({
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
  bool shouldRepaint(covariant _CompanyGraphPainter oldDelegate) {
    return oldDelegate.edges != edges;
  }
}
