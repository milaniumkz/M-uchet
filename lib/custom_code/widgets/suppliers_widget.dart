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
import '/utils/country_profile.dart';
import '/utils/export_transactions.dart';
import '/utils/effective_company_support.dart';
import '/utils/domain_entry_adapters.dart';
import '/utils/service_supplier_support.dart';

import '/custom_code/widgets/editing_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuppliersWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final Function()? onExport;

  const SuppliersWidget({
    super.key,
    this.width,
    this.height,
    this.onExport,
  });

  @override
  _SuppliersWidgetState createState() => _SuppliersWidgetState();
}

class _SuppliersWidgetState extends State<SuppliersWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  final Map<String, Map<String, dynamic>> _itemDocs = {};
  List<SupplierEntryView> _items = [];
  List<SupplierEntryView> _filtered = [];
  bool _loading = false;
  String _currencyCode = 'KZT';

  String _statusFilter = 'all';
  String _categoryFilter = 'all';

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

  Color get _softText => _isDarkTheme
      ? Colors.white.withValues(alpha: 0.56)
      : const Color(0xFF6B7280);

  Color _textOn(Color color, {double darkAlpha = 0.92}) {
    return color.computeLuminance() > 0.6
        ? const Color(0xFF111827)
        : Colors.white.withValues(alpha: darkAlpha);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _items = [];
          _filtered = [];
          _itemDocs.clear();
        });
        return;
      }

      final effectiveCompanyId = _effectiveCompanyId(user);

      final snap = await _firestore
          .collection('suppliers')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .get();
      final profileSnap = await _firestore
          .collection('company_profile')
          .doc(effectiveCompanyId)
          .get();

      final docs = <String, Map<String, dynamic>>{};
      final list = snap.docs.map((d) {
        final raw = d.data();
        final data = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);
        final row = {'id': d.id, ...data};
        docs[d.id] = row;
        return SupplierEntryView.fromMap(row);
      }).toList();

      setState(() {
        final profileData = profileSnap.data() ?? const <String, dynamic>{};
        final countryProfile = countryProfileFromData(profileData);
        _currencyCode = companyCurrencyFromProfileData(
          profileData,
          fallback: countryProfile.baseCurrency,
        );
        _itemDocs
          ..clear()
          ..addAll(docs);
        _items = list;
        _filtered = List.from(list);
      });

      _applyFilters();
    } catch (e) {
      print('Error loading suppliers: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _effectiveCompanyId(User user) {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();

    List<SupplierEntryView> list = List.from(_items);

    if (_statusFilter != 'all') {
      list = list.where((i) => i.status == _statusFilter).toList();
    }
    if (_categoryFilter != 'all') {
      list = list.where((i) => i.category == _categoryFilter).toList();
    }

    if (q.isNotEmpty) {
      list = list.where((i) {
        final name = i.name.toLowerCase();
        final bin = i.bin.toLowerCase();
        final contact = i.contact.toLowerCase();
        return name.contains(q) || bin.contains(q) || contact.contains(q);
      }).toList();
    }

    setState(() => _filtered = list);
  }

  int get _total => _items.length;
  int get _active => _items.where((i) => i.isActive).length;
  double get _turnover => _items.fold(0, (s, i) => s + i.turnover);
  int get _orders => _items.fold(0, (s, i) => s + i.orders);

  String _money(double v) {
    return formatMoneyWithCurrency(v, currencyCode: _currencyCode);
  }

  Future<void> _exportSuppliers() async {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет данных для выгрузки')),
      );
      return;
    }
    final rows = <List<String>>[
      [
        'Название',
        'Полное название',
        'БИН/ИНН',
        'Категория',
        'Статус',
        'Контактное лицо',
        'Телефон',
        'Email',
        'Город',
        'Оборот',
        'Заказы',
        'Комментарий',
      ],
    ];
    for (final item in _filtered) {
      rows.add([
        item.name,
        item.legalName,
        item.bin,
        item.category,
        item.status,
        item.contact,
        item.phone,
        item.email,
        item.city,
        item.turnover.toStringAsFixed(2),
        item.orders.toString(),
        item.note,
      ]);
    }
    final now = DateTime.now();
    await exportTransactionsCsv(
      filename: 'suppliers_${now.year}-${now.month}-${now.day}.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionsHelper.has('suppliers.view')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: _pageBackground,
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
                    color: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_outlined,
                      color: Color(0xFF9E7B4F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Контрагенты',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Управление базой поставщиков',
                        style: TextStyle(
                          fontSize: 13,
                          color: _mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onExport ?? _exportSuppliers,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Экспорт в Excel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Добавить поставщика'),
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
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _statCard(
                    'Всего поставщиков', '$_total', const Color(0xFF1F2A37)),
                const SizedBox(width: 12),
                _statCard('Активных', '$_active',
                    FlutterFlowTheme.of(context).success),
                const SizedBox(width: 12),
                _statCard(
                    'Общий оборот', _money(_turnover), const Color(0xFFC8A06A)),
                const SizedBox(width: 12),
                _statCard('Всего заказов', '$_orders',
                    FlutterFlowTheme.of(context).primary),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search + filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _panelSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: _softText, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText:
                                  'Поиск по названию, БИН/ИНН, контакту...',
                              hintStyle: TextStyle(color: _softText),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdown(
                    value: _statusFilter,
                    items: ['all', 'Активный', 'Неактивный'],
                    onChanged: (v) {
                      setState(() => _statusFilter = v ?? 'all');
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdown(
                    value: _categoryFilter,
                    items: _distinctValues('category'),
                    onChanged: (v) {
                      setState(() => _categoryFilter = v ?? 'all');
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      return _supplierCard(_filtered[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _supplierCard(SupplierEntryView i) {
    final name = i.name.isEmpty ? 'Без названия' : i.name;
    final legal = i.legalName;
    final status = i.status;
    final category = i.category.isEmpty ? 'Продукты питания' : i.category;
    final bin = i.bin.isEmpty ? '000000000000' : i.bin;
    final rating = i.rating <= 0 ? 4.5 : i.rating;

    final contact = i.contact.isEmpty ? 'Не указан' : i.contact;
    final phone = i.phone.isEmpty ? 'Не указан' : i.phone;
    final email = i.email.isEmpty ? 'Не указан' : i.email;
    final city = i.city.isEmpty ? 'Город не указан' : i.city;

    final note = i.note;
    final raw = _itemDocs[i.id] ?? <String, dynamic>{'id': i.id};

    return LiveDiffHighlight(
      timestamp: i.updatedAt ?? i.createdAt,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panelSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _panelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                _chip(status,
                    color: status == 'Активный'
                        ? FlutterFlowTheme.of(context)
                            .success
                            .withValues(alpha: 0.14)
                        : FlutterFlowTheme.of(context)
                            .error
                            .withValues(alpha: 0.14)),
              ],
            ),
            if (legal.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(legal, style: TextStyle(color: _mutedText)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _pill(category),
                const SizedBox(width: 8),
                _pill('БИН/ИНН: $bin'),
                const SizedBox(width: 8),
                _stars(rating),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _info(Icons.person, contact)),
                Expanded(child: _info(Icons.phone, phone)),
                Expanded(child: _info(Icons.email_outlined, email)),
                Expanded(child: _info(Icons.location_on_outlined, city)),
              ],
            ),
            if (note.toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isDarkTheme
                      ? FlutterFlowTheme.of(context)
                          .warning
                          .withValues(alpha: 0.14)
                      : const Color(0xFFFEF9E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.article_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(note)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (EditingHelper.canEditExisting())
                    OutlinedButton.icon(
                      onPressed: () => _showAddDialog(existing: raw),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Редактировать'),
                    ),
                  const SizedBox(width: 8),
                  if (EditingHelper.canEditExisting())
                    OutlinedButton.icon(
                      onPressed: () => _delete(i.id),
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      label: const Text('Удалить',
                          style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: FlutterFlowTheme.of(context).secondaryText),
        Icon(icon, size: 16, color: _mutedText),
        const SizedBox(width: 6),
        Expanded(
            child:
                Text(text, style: TextStyle(fontSize: 12, color: _mutedText))),
      ],
    );
  }

  Widget _pill(String text) {
    final bg = FlutterFlowTheme.of(context).primaryBackground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textOn(bg),
          )),
    );
  }

  Widget _chip(String text, {Color? color}) {
    final bg = color ?? FlutterFlowTheme.of(context).primaryBackground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _textOn(bg),
          )),
    );
  }

  Widget _stars(double rating) {
    final full = rating.floor();
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < full ? Icons.star : Icons.star_border,
          size: 14,
          color: const Color(0xFFF59E0B),
        );
      }),
    );
  }

  Widget _statCard(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panelSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _panelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 12,
                  color: _mutedText,
                )),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _panelSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _panelBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _panelSurface,
          style: TextStyle(
            color: FlutterFlowTheme.of(context).primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          iconEnabledColor: _mutedText,
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      i,
                      style: TextStyle(
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<String> _distinctValues(String field) {
    final set = <String>{'all'};
    for (final i in _items) {
      final v = switch (field) {
        'category' => i.category,
        'status' => i.status,
        _ => '',
      };
      if (v.isNotEmpty) set.add(v);
    }
    return set.toList();
  }

  void _showAddDialog({Map<String, dynamic>? existing}) {
    if (existing != null && !EditingHelper.guardEdit(context)) return;
    showDialog(
      context: context,
      builder: (context) => AddSupplierDialog(
        onSaved: _load,
        existing: existing,
      ),
    );
  }

  Future<void> _delete(String id) async {
    if (!EditingHelper.guardEdit(context)) return;
    final user = _auth.currentUser;
    final effectiveCompanyId = user == null ? '' : _effectiveCompanyId(user);
    await _firestore.collection('suppliers').doc(id).delete();
    if (effectiveCompanyId.isNotEmpty) {
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('suppliers', effectiveCompanyId);
    } else {
      FirestoreQueryCache.instance.invalidateCollection('suppliers');
    }
    _load();
  }
}

class AddSupplierDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existing;

  const AddSupplierDialog({Key? key, required this.onSaved, this.existing})
      : super(key: key);

  @override
  _AddSupplierDialogState createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<AddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _name = TextEditingController();
  final _legalName = TextEditingController();
  final _bin = TextEditingController();
  final _category = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _note = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _name.text = ex['name'] ?? '';
      _legalName.text = ex['legal_name'] ?? '';
      _bin.text = ex['bin'] ?? '';
      _category.text = ex['category'] ?? '';
      _contact.text = ex['contact'] ?? '';
      _phone.text = ex['phone'] ?? '';
      _email.text = ex['email'] ?? '';
      _city.text = ex['city'] ?? '';
      _note.text = ex['note'] ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _legalName.dispose();
    _bin.dispose();
    _category.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _note.dispose();
    super.dispose();
  }

  String _effectiveCompanyId(User user) {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existing != null && !EditingHelper.guardEdit(context)) return;
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');
      final effectiveCompanyId = _effectiveCompanyId(user);

      final data = buildSupplierPayload(
        companyId: effectiveCompanyId,
        userId: user.uid,
        name: _name.text,
        legalName: _legalName.text,
        bin: _bin.text,
        category: _category.text,
        contact: _contact.text,
        phone: _phone.text,
        email: _email.text,
        city: _city.text,
        note: _note.text,
        isCreate: widget.existing == null,
      );

      if (widget.existing == null) {
        await _firestore.collection('suppliers').add(data);
      } else {
        await _firestore
            .collection('suppliers')
            .doc(widget.existing!['id'])
            .update(data);
      }

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('suppliers', effectiveCompanyId);
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      print('Error saving supplier: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
                    isEdit ? 'Редактировать поставщика' : 'Добавить поставщика',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _field(_name, 'Название', required: true),
                _field(_legalName, 'Полное название'),
                _field(_bin, 'БИН/ИНН'),
                _field(_category, 'Категория'),
                _field(_contact, 'Контактное лицо'),
                _field(_phone, 'Телефон'),
                _field(_email, 'Email'),
                _field(_city, 'Город'),
                _field(_note, 'Комментарий'),
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
                            : Text(isEdit ? 'Сохранить' : 'Добавить'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: (v) {
          if (required && (v == null || v.isEmpty)) return 'Обязательное поле';
          if (number &&
              v != null &&
              v.isNotEmpty &&
              double.tryParse(v) == null) {
            return 'Введите число';
          }
          return null;
        },
      ),
    );
  }
}

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
