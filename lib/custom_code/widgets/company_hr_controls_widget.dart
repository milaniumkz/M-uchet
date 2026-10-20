// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/role_assignment_support.dart';

class CompanyHrControlsWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const CompanyHrControlsWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<CompanyHrControlsWidget> createState() =>
      _CompanyHrControlsWidgetState();
}

class _CompanyHrControlsWidgetState extends State<CompanyHrControlsWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _staffSchedule = [];
  List<Map<String, dynamic>> _roles = [];
  List<String> _branchOptions = [];
  List<String> _departmentOptions = [];

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDarkTheme ? const Color(0xFF111722) : const Color(0xFFF7F8FA);
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
  Color get _tabUnselected => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.68)
      : const Color(0xFF6B7280);

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
          _employees = [];
          _staffSchedule = [];
          _roles = [];
          _branchOptions = [];
          _departmentOptions = [];
        });
        return;
      }
      final effectiveCompanyId = _effectiveCompanyId(user);

      final employeesSnap = await _firestore
          .collection('employees')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final rolesSnap = await _firestore
          .collection('roles')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final scheduleSnap = await _firestore
          .collection('staff_schedule')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .getCached();
      final companySnap = await _firestore
          .collection('companies')
          .doc(effectiveCompanyId)
          .get();
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      final employees = employeesSnap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return {'id': d.id, ...data};
      }).toList();

      final staff = scheduleSnap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        return {'id': d.id, ...data};
      }).toList()
        ..sort((a, b) {
          final ad = _extractDate(a['opened_at']);
          final bd = _extractDate(b['opened_at']);
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });

      setState(() {
        _employees = employees;
        _staffSchedule = staff;
        final companyData = companySnap.data() ?? const <String, dynamic>{};
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        _branchOptions = _extractBranchOptions(companyData, profileData);
        _departmentOptions =
            _extractDepartmentOptions(companyData, profileData);
        _roles = rolesSnap.docs.map<Map<String, dynamic>>((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).where((role) {
          final type = (role['type'] ?? '').toString().trim();
          final name = (role['name'] ?? '').toString().trim();
          return name.isNotEmpty && type != 'position';
        }).toList()
          ..sort((a, b) => (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString()));
      });
    } catch (e) {
      print('Error loading HR data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> _extractBranchOptions(
    Map<String, dynamic> companyData,
    Map<String, dynamic> profileData,
  ) {
    final result = <String>{};
    void add(dynamic value) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) result.add(text);
    }

    for (final source in [companyData, profileData]) {
      final names = source['branch_names'];
      if (names is List) {
        for (final item in names) add(item);
      }
      final branches = source['branches'];
      if (branches is List) {
        for (final item in branches) {
          if (item is Map) {
            add(item['name'] ?? item['title'] ?? item['branch_name']);
          } else {
            add(item);
          }
        }
      }
    }
    return result.toList()..sort();
  }

  List<String> _extractDepartmentOptions(
    Map<String, dynamic> companyData,
    Map<String, dynamic> profileData,
  ) {
    final result = <String>{};
    void add(dynamic value) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) result.add(text);
    }

    for (final source in [companyData, profileData]) {
      final names = source['department_names'];
      if (names is List) {
        for (final item in names) add(item);
      }
      final departments = source['departments'];
      if (departments is List) {
        for (final item in departments) {
          if (item is Map) {
            add(item['name'] ?? item['title'] ?? item['department_name']);
          } else {
            add(item);
          }
        }
      }
    }
    return result.toList()..sort();
  }

  Map<String, dynamic> _fundingRoleFlags(List<String> permissions) {
    final set = permissions.toSet();
    return {
      'can_submit_funding_request': set.contains('funding_requests.create'),
      'can_responsible_sign_funding_request':
          set.contains('funding_requests.responsible_sign'),
      'can_approve_funding_request': set.contains('funding_requests.approve'),
      'can_final_approve_funding_request':
          set.contains('funding_requests.final_approve'),
      'can_pay_funding_request': set.contains('funding_requests.pay'),
      'can_edit_money_data': set.contains('scheta.edit') ||
          set.contains('tranzaction.edit') ||
          set.contains('money.company_expenses'),
      'can_delete_money_data':
          set.contains('scheta.delete') || set.contains('tranzaction.delete'),
    };
  }

  String _effectiveCompanyId(User user) {
    final raw = (currentUserDocument?.idCompany ?? '').trim();
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    final companyIds = (currentUserDocument?.companyIds ?? const <String>[])
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (raw == '__all__') {
      if (active.isNotEmpty) return active;
      if (companyIds.isNotEmpty) return companyIds.first;
      return user.uid;
    }
    if (raw.isNotEmpty) return raw;
    if (active.isNotEmpty) return active;
    if (companyIds.isNotEmpty) return companyIds.first;
    return user.uid;
  }

  DateTime? _extractDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  String _dateText(dynamic raw) {
    final dt = _extractDate(raw);
    if (dt == null) return '-';
    return dateTimeFormat('dd.MM.yyyy HH:mm', dt,
        locale: FFLocalizations.of(context).languageCode);
  }

  String _durationText(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Map<String, dynamic>? _geo(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  double? _geoLat(Map<String, dynamic>? geo) {
    if (geo == null) return null;
    final v = geo['lat'];
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString());
  }

  double? _geoLng(Map<String, dynamic>? geo) {
    if (geo == null) return null;
    final v = geo['lng'];
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString());
  }

  List<_StaffRow> get _staffRows {
    final byEmployee = <String, _StaffRow>{};
    for (final e in _employees) {
      final name = (e['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      byEmployee[name.toLowerCase()] = _StaffRow(
        name: name,
        role: (e['role'] ?? '').toString().trim(),
        department: (e['department'] ?? '').toString().trim(),
        schedule: (e['work_schedule'] ?? e['schedule'] ?? '').toString().trim(),
      );
    }

    for (final s in _staffSchedule) {
      final employeeName =
          (s['cashier_name'] ?? s['employee_name'] ?? '').toString().trim();
      if (employeeName.isEmpty) continue;
      final key = employeeName.toLowerCase();
      final row = byEmployee.putIfAbsent(
        key,
        () => _StaffRow(name: employeeName),
      );
      row.shifts += 1;
      row.workedMinutes += _toInt(s['worked_minutes']);
      final openedAt = _extractDate(s['opened_at']);
      if (openedAt != null &&
          (row.lastOpenedAt == null || openedAt.isAfter(row.lastOpenedAt!))) {
        row.lastOpenedAt = openedAt;
        row.lastOpenedGeo = _geo(s['opened_geo']);
      }
      final closedAt = _extractDate(s['closed_at']);
      if (closedAt != null &&
          (row.lastClosedAt == null || closedAt.isAfter(row.lastClosedAt!))) {
        row.lastClosedAt = closedAt;
        row.lastClosedGeo = _geo(s['closed_geo']);
      }
    }

    final rows = byEmployee.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('company.hr')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: _pageBackground,
      child: DefaultTabController(
        length: 2,
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
                    child: const Icon(Icons.badge_outlined,
                        color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HR контроль',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Сотрудники, смены, выходы и местоположение (OSM)',
                          style: TextStyle(
                            fontSize: 13,
                            color: _mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddEmployeeDialog,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Добавить сотрудника'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: _tabUnselected,
                indicatorColor: const Color(0xFF2563EB),
                dividerColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: 'Сотрудники'),
                  Tab(text: 'Штатное расписание'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _employeesTab(),
                        _staffScheduleTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeesTab() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сотрудники',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _tableHeader(),
          const Divider(height: 1),
          Expanded(
            child: _employees.isEmpty
                ? Center(
                    child: Text(
                      'Сотрудники не найдены',
                      style: TextStyle(color: _mutedText),
                    ),
                  )
                : ListView.builder(
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      return _tableRow(_employees[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _staffScheduleTab() {
    final rows = _staffRows;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Штатное расписание (выбранная компания)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              _HeaderCell('Сотрудник', flex: 3),
              _HeaderCell('Должность', flex: 2),
              _HeaderCell('График', flex: 2),
              _HeaderCell('Выход', flex: 2),
              _HeaderCell('Уход', flex: 2),
              _HeaderCell('Отработано', flex: 1),
              _HeaderCell('Смен', flex: 1),
              _HeaderCell('Гео (OSM)', flex: 2),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'По выбранной компании нет данных штатного расписания',
                      style: TextStyle(color: _mutedText),
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) => _staffRow(rows[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _staffRow(_StaffRow row) {
    final openGeo = row.lastOpenedGeo;
    final closeGeo = row.lastClosedGeo;
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
          _Cell(row.name, flex: 3, bold: true),
          _Cell(row.role.isEmpty ? '-' : row.role, flex: 2),
          _Cell(row.schedule.isEmpty ? '-' : row.schedule, flex: 2),
          _Cell(row.lastOpenedAt == null ? '-' : _dateText(row.lastOpenedAt),
              flex: 2),
          _Cell(row.lastClosedAt == null ? '-' : _dateText(row.lastClosedAt),
              flex: 2),
          _Cell(_durationText(row.workedMinutes), flex: 1),
          _Cell(row.shifts.toString(), flex: 1),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: _hasCoords(openGeo)
                      ? () => _showOsmMapDialog(
                            title: 'Открытие смены: ${row.name}',
                            geo: openGeo!,
                          )
                      : null,
                  child: const Text('Выход'),
                ),
                OutlinedButton(
                  onPressed: _hasCoords(closeGeo)
                      ? () => _showOsmMapDialog(
                            title: 'Закрытие смены: ${row.name}',
                            geo: closeGeo!,
                          )
                      : null,
                  child: const Text('Уход'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasCoords(Map<String, dynamic>? geo) {
    final lat = _geoLat(geo);
    final lng = _geoLng(geo);
    return lat != null && lng != null;
  }

  Future<void> _showOsmMapDialog({
    required String title,
    required Map<String, dynamic> geo,
  }) async {
    final lat = _geoLat(geo);
    final lng = _geoLng(geo);
    if (lat == null || lng == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 760,
            height: 460,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: latlng.LatLng(lat, lng),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.muchet',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: latlng.LatLng(lat, lng),
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Widget _tableHeader() {
    return Row(
      children: const [
        _HeaderCell('Сотрудник', flex: 3),
        _HeaderCell('Должность', flex: 2),
        _HeaderCell('Отдел', flex: 2),
        _HeaderCell('Филиал', flex: 2),
      ],
    );
  }

  Future<void> _showAddEmployeeDialog() async {
    final nameController = TextEditingController();
    final deptController = TextEditingController();
    final branchController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedRoleId =
        _roles.isNotEmpty ? (_roles.first['id'] ?? '').toString() : null;
    String? selectedBranch =
        _branchOptions.isNotEmpty ? _branchOptions.first : null;
    String? selectedDepartment =
        _departmentOptions.isNotEmpty ? _departmentOptions.first : null;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('Добавить сотрудника'),
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Введите ФИО'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    if (_roles.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedRoleId,
                        decoration: const InputDecoration(labelText: 'Роль'),
                        items: _roles
                            .map((role) => DropdownMenuItem<String>(
                                  value: (role['id'] ?? '').toString(),
                                  child:
                                      Text((role['name'] ?? 'Роль').toString()),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setLocalState(() => selectedRoleId = v),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Выберите роль'
                            : null,
                      )
                    else
                      const Text(
                        'Роли не настроены. Сначала создайте роли компании.',
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Номер телефона для входа',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Введите номер телефона'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Временный пароль',
                        helperText: 'Сотрудник сменит пароль при первом входе.',
                      ),
                      validator: (v) => (v ?? '').trim().length < 6
                          ? 'Минимум 6 символов'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    if (_departmentOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedDepartment,
                        decoration:
                            const InputDecoration(labelText: 'Подразделение'),
                        items: _departmentOptions
                            .map((name) => DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setLocalState(() {
                            selectedDepartment = value;
                            deptController.text = value ?? '';
                          });
                        },
                      )
                    else
                      TextFormField(
                        controller: deptController,
                        decoration:
                            const InputDecoration(labelText: 'Подразделение'),
                      ),
                    const SizedBox(height: 10),
                    if (_branchOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedBranch,
                        decoration:
                            const InputDecoration(labelText: 'Филиал / объект'),
                        items: _branchOptions
                            .map((name) => DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setLocalState(() {
                            selectedBranch = value;
                            branchController.text = value ?? '';
                          });
                        },
                      )
                    else
                      TextFormField(
                        controller: branchController,
                        decoration:
                            const InputDecoration(labelText: 'Филиал / объект'),
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
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false))
                          return;
                        final user = _auth.currentUser;
                        if (user == null) return;
                        final companyId = _effectiveCompanyId(user);
                        final role = _roles.firstWhere(
                          (item) =>
                              (item['id'] ?? '').toString() == selectedRoleId,
                          orElse: () => <String, dynamic>{},
                        );
                        if (role.isEmpty) return;
                        final rolePermissions =
                            normalizePermissionList(role['permissions']);
                        final allowedCompanyIds = normalizeRoleCompanyIds(
                          role['allowed_company_ids'],
                          fallbackCompanyId: companyId,
                        );
                        final department =
                            (selectedDepartment ?? deptController.text).trim();
                        final branch =
                            (selectedBranch ?? branchController.text).trim();
                        setLocalState(() => saving = true);
                        final response = await TokenCall.call(
                          phone: phoneController.text.trim(),
                          password: passwordController.text.trim(),
                          mode: 'signup',
                          role: 'emp',
                          companyId: companyId,
                          displayName: nameController.text.trim(),
                          roleId: (role['id'] ?? '').toString(),
                          roleName: (role['name'] ?? '').toString(),
                          rolePermissions: rolePermissions,
                          roleAllowedCompanyIds: allowedCompanyIds,
                          position: (role['name'] ?? '').toString(),
                          department: department,
                          forcePasswordChange: true,
                        );
                        if (!response.succeeded) {
                          if (dialogContext.mounted) {
                            setLocalState(() => saving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Не удалось зарегистрировать сотрудника'),
                              ),
                            );
                          }
                          return;
                        }
                        final employeePayload = {
                          'idCompany': companyId,
                          'user_id': phoneController.text.trim(),
                          'name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'role': (role['name'] ?? '').toString(),
                          'role_id': (role['id'] ?? '').toString(),
                          'role_name': (role['name'] ?? '').toString(),
                          'role_permissions': rolePermissions,
                          'role_allowed_company_ids': allowedCompanyIds,
                          ..._fundingRoleFlags(rolePermissions),
                          'department': department,
                          'department_name': department,
                          'branch': branch,
                          'branch_name': branch,
                          'company_id': companyId,
                          'company_ids': allowedCompanyIds,
                          'updated_at': FieldValue.serverTimestamp(),
                        };
                        final existingEmployee = await _firestore
                            .collection('employees')
                            .where('idCompany', isEqualTo: companyId)
                            .where('user_id',
                                isEqualTo: phoneController.text.trim())
                            .limit(1)
                            .get(const GetOptions(
                                source: Source.serverAndCache));
                        if (existingEmployee.docs.isEmpty) {
                          await _firestore.collection('employees').add({
                            ...employeePayload,
                            'created_at': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await existingEmployee.docs.first.reference
                              .set(employeePayload, SetOptions(merge: true));
                        }
                        FirestoreQueryCache.instance
                            .invalidateCompanyCollection(
                                'employees', companyId);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      },
                child: Text(saving ? 'Сохранение...' : 'Сохранить'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    deptController.dispose();
    branchController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    if (created == true) {
      await _loadData();
    }
  }

  Widget _tableRow(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final role = (item['role'] ?? '').toString();
    final dept = (item['department'] ?? '').toString();
    final branch =
        (item['branch_name'] ?? item['branch'] ?? '').toString().trim();
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
          _Cell(name.isEmpty ? '-' : name, flex: 3, bold: true),
          _Cell(role.isEmpty ? '-' : role, flex: 2),
          _Cell(dept.isEmpty ? '-' : dept, flex: 2),
          _Cell(branch.isEmpty ? '-' : branch, flex: 2),
        ],
      ),
    );
  }
}

class _StaffRow {
  final String name;
  final String role;
  final String department;
  final String schedule;

  int shifts = 0;
  int workedMinutes = 0;
  DateTime? lastOpenedAt;
  DateTime? lastClosedAt;
  Map<String, dynamic>? lastOpenedGeo;
  Map<String, dynamic>? lastClosedGeo;

  _StaffRow({
    required this.name,
    this.role = '',
    this.department = '',
    this.schedule = '',
  });
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
            fontSize: 12,
            color: FlutterFlowTheme.of(context).secondaryText,
          )),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;

  const _Cell(this.text, {required this.flex, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: FlutterFlowTheme.of(context).primaryText,
        ),
      ),
    );
  }
}
