import '/admin/component/drawers/drawers_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'company_admin_model.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/admin_responsive_row.dart';
import '/admin/component/admin_card.dart';
import '/admin/component/admin_table_scroll.dart';
import '/admin/design_admin/user_design_admin_panel.dart';
import '/admin/design_admin/scheta_page_admin_panel.dart';
import '/utils/admin_company_support.dart';
import '/utils/audit_log_service.dart';
import '/utils/default_company_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/user_design/user_design.dart';
export 'company_admin_model.dart';

class CompanyAdminWidget extends StatefulWidget {
  const CompanyAdminWidget({super.key});

  static String routeName = 'companyAdmin';
  static String routePath = '/companyAdmin';

  @override
  State<CompanyAdminWidget> createState() => _CompanyAdminWidgetState();
}

class _CompanyAdminWidgetState extends State<CompanyAdminWidget> {
  late CompanyAdminModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _nameController = TextEditingController();
  final _binController = TextEditingController();
  final _addressController = TextEditingController();
  final _ownerController = TextEditingController();
  final _ocedController = TextEditingController();
  final _otraslController = TextEditingController();
  final _formaController = TextEditingController();
  final _nalogController = TextEditingController();
  final _valutaController = TextEditingController();
  bool _ndsPayer = false;
  bool _buhEnabled = false;
  bool _isActive = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CompanyAdminModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _binController.dispose();
    _addressController.dispose();
    _ownerController.dispose();
    _ocedController.dispose();
    _otraslController.dispose();
    _formaController.dispose();
    _nalogController.dispose();
    _valutaController.dispose();
    _model.dispose();

    super.dispose();
  }

  bool _isValidCompanyId(String value) {
    return isValidAdminCompanyId(value);
  }

  String _companyIdFromData(
    String docId,
    Map<String, dynamic> data, {
    bool allowDocId = false,
  }) {
    return companyAdminIdFromData(docId, data, allowDocId: allowDocId);
  }

  String _companySignature(Map<String, dynamic> data) {
    final name = companyAdminDisplayName(data).toLowerCase();
    final bin =
        firstCompanyAdminText(data, ['bin', 'BIN', 'iin']).toLowerCase();
    final owner =
        firstCompanyAdminText(data, ['ownerId', 'user_id']).toLowerCase();
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
    if (raw.isEmpty) return [];
    return raw
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _applyCompanyFieldAliases(Map<String, dynamic> data) {
    final name = firstCompanyAdminText(
      data,
      ['name', 'nameCompany', 'name_Company', 'company_name'],
    );
    if (name.isNotEmpty) {
      data['name'] = name;
      data['nameCompany'] = name;
      data['name_Company'] = name;
      data['company_name'] = name;
    }

    final bin = firstCompanyAdminText(data, ['bin', 'BIN', 'iin']);
    if (bin.isNotEmpty) {
      data['bin'] = bin;
      data['BIN'] = bin;
    }

    final address = firstCompanyAdminText(data, ['address', 'adres']);
    if (address.isNotEmpty) {
      data['address'] = address;
      data['adres'] = address;
    }

    final oced = data['oced'] ?? data['oked'] ?? data['OKED'];
    if (oced != null) {
      final normalized = _stringList(oced);
      data['oced'] = normalized;
      data['oked'] = normalized;
      data['OKED'] = normalized;
    }

    final industry = firstCompanyAdminText(data, ['otrasl', 'business_type']);
    if (industry.isNotEmpty) {
      data['otrasl'] = industry;
      data['business_type'] = industry;
    }

    final legalForm = firstCompanyAdminText(data, ['forma', 'legal_form']);
    if (legalForm.isNotEmpty) {
      data['forma'] = legalForm;
      data['legal_form'] = legalForm;
    }

    final taxRegime = firstCompanyAdminText(data, ['nalog', 'tax_regime']);
    if (taxRegime.isNotEmpty) {
      data['nalog'] = taxRegime;
      data['tax_regime'] = taxRegime;
    }

    final currency = firstCompanyAdminText(data, ['valuta', 'currency']);
    if (currency.isNotEmpty) {
      data['valuta'] = currency;
      data['currency'] = currency;
    }
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<Map<String, dynamic>> _fullCompanyData(
    Map<String, dynamic> company,
  ) async {
    final id = (company['id'] ?? '').toString().trim();
    if (id.isEmpty) return company;
    final companySnap =
        await FirebaseFirestore.instance.collection('companies').doc(id).get();
    final profileSnap = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(id)
        .get();
    return {
      ...company,
      if (profileSnap.exists) ...(profileSnap.data() ?? {}),
      if (companySnap.exists) ...(companySnap.data() ?? {}),
      'id': id,
    };
  }

  Future<void> _openCompanyDialog({Map<String, dynamic>? existing}) async {
    final editData = existing == null ? null : await _fullCompanyData(existing);
    if (editData != null) {
      _nameController.text = firstCompanyAdminText(
        editData,
        ['nameCompany', 'name_Company', 'company_name', 'name'],
      );
      if (_nameController.text.trim().toLowerCase() == 'компания') {
        _nameController.text = companyAdminDisplayName(editData);
      }
      _binController.text =
          firstCompanyAdminText(editData, ['bin', 'BIN', 'iin']);
      _addressController.text =
          firstCompanyAdminText(editData, ['address', 'adres']);
      _ownerController.text =
          firstCompanyAdminText(editData, ['ownerId', 'user_id']);
      _ocedController.text =
          _stringList(editData['oced'] ?? editData['oked'] ?? editData['OKED'])
              .join(', ');
      _otraslController.text =
          firstCompanyAdminText(editData, ['otrasl', 'business_type']);
      _formaController.text =
          firstCompanyAdminText(editData, ['forma', 'legal_form']);
      _nalogController.text =
          firstCompanyAdminText(editData, ['nalog', 'tax_regime']);
      _valutaController.text =
          firstCompanyAdminText(editData, ['valuta', 'currency']);
      _ndsPayer = editData['ndsPayer'] == true || editData['nds_payer'] == true;
      _buhEnabled = editData['buh_enabled'] == true ||
          editData['buhEnabled'] == true ||
          editData['buh'] == true;
      _isActive = editData['isActive'] != false;
    } else {
      _nameController.clear();
      _binController.clear();
      _addressController.clear();
      _ownerController.clear();
      _ocedController.clear();
      _otraslController.clear();
      _formaController.clear();
      _nalogController.clear();
      _valutaController.clear();
      _ndsPayer = false;
      _buhEnabled = false;
      _isActive = true;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
                existing == null ? 'Новая компания' : 'Редактировать компанию'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _binController,
                      decoration: const InputDecoration(labelText: 'БИН/ИНН'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Адрес'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ownerController,
                      decoration: const InputDecoration(labelText: 'Owner UID'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ocedController,
                      decoration: const InputDecoration(
                        labelText: 'ОКЭД',
                        helperText: 'Несколько ОКЭД через запятую',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otraslController,
                      decoration: const InputDecoration(labelText: 'Отрасль'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _formaController,
                      decoration: const InputDecoration(
                          labelText: 'Форма собственности'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nalogController,
                      decoration:
                          const InputDecoration(labelText: 'Налоговый режим'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _valutaController,
                      decoration: const InputDecoration(labelText: 'Валюта'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _ndsPayer,
                      onChanged: (val) => setDialogState(() => _ndsPayer = val),
                      title: const Text('Плательщик НДС'),
                    ),
                    SwitchListTile(
                      value: _buhEnabled,
                      onChanged: (val) =>
                          setDialogState(() => _buhEnabled = val),
                      title: const Text('Ведет бухгалтерский учет'),
                    ),
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (val) => setDialogState(() => _isActive = val),
                      title: const Text('Активна'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  final data = <String, dynamic>{
                    'name': name,
                    'bin': _binController.text.trim(),
                    'address': _addressController.text.trim(),
                    'ownerId': _ownerController.text.trim(),
                    'oced': _stringList(_ocedController.text),
                    'otrasl': _otraslController.text.trim(),
                    'forma': _formaController.text.trim(),
                    'nalog': _nalogController.text.trim(),
                    'valuta': _valutaController.text.trim(),
                    'ndsPayer': _ndsPayer,
                    'nds_payer': _ndsPayer,
                    'buh_enabled': _buhEnabled,
                    'buhEnabled': _buhEnabled,
                    'buh': _buhEnabled,
                    'isActive': _isActive,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'updated_at': FieldValue.serverTimestamp(),
                  };
                  _applyCompanyFieldAliases(data);
                  final ref =
                      FirebaseFirestore.instance.collection('companies');
                  if (existing == null) {
                    final doc = ref.doc();
                    final ownerId = _ownerController.text.trim();
                    await doc.set({
                      ...data,
                      'members': ownerId.isNotEmpty ? [ownerId] : [],
                      kUserDesignTemplateField: kUserDesignReference,
                      kUserDesignConfigField: defaultCustomUserDesignConfig(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    await FirebaseFirestore.instance
                        .collection('company_profile')
                        .doc(doc.id)
                        .set({
                      'idCompany': doc.id,
                      'user_id': ownerId.isNotEmpty ? ownerId : currentUserUid,
                      ...data,
                      'created_at': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    await ensureDefaultCompanyRoles(
                      firestore: FirebaseFirestore.instance,
                      companyId: doc.id,
                      userId: ownerId.isNotEmpty ? ownerId : currentUserUid,
                    );
                    await AuditLogService.logAction(
                      companyId: doc.id,
                      action: 'create',
                      entity: 'company',
                      entityId: doc.id,
                      entityTitle: name,
                      after: {
                        ...data,
                        'members': ownerId.isNotEmpty ? [ownerId] : [],
                      },
                      details: const {'message': 'Создана компания'},
                    );
                  } else {
                    final companyId = existing['id'].toString();
                    await ref.doc(companyId).set(data, SetOptions(merge: true));
                    await FirebaseFirestore.instance
                        .collection('company_profile')
                        .doc(companyId)
                        .set({
                      'idCompany': companyId,
                      'user_id': _ownerController.text.trim().isNotEmpty
                          ? _ownerController.text.trim()
                          : currentUserUid,
                      ...data,
                    }, SetOptions(merge: true));
                    await AuditLogService.logAction(
                      companyId: companyId,
                      action: 'update',
                      entity: 'company',
                      entityId: companyId,
                      entityTitle: name,
                      before: editData,
                      after: data,
                      details: const {'message': 'Изменена компания'},
                    );
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAuditSyncDialog(Map<String, dynamic> company) async {
    final companyId = (company['id'] ?? '').toString().trim();
    final companyName = (company['name'] ?? '').toString().trim();
    if (companyId.isEmpty) return;

    final urlController = TextEditingController();
    final tokenController = TextEditingController();
    var autoEnabled = false;
    var intervalMinutes = 1440;
    var loading = true;
    var saving = false;
    var statusText = '';
    DateTime? lastSyncAt;

    Future<void> loadSettings(StateSetter setModalState) async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('audit_1c_sync_settings')
            .doc('${companyId}_xml')
            .get();
        if (!doc.exists) {
          setModalState(() => loading = false);
          return;
        }
        final data = doc.data() ?? const <String, dynamic>{};
        setModalState(() {
          urlController.text = (data['xml_url'] ?? '').toString();
          tokenController.text = (data['xml_token'] ?? '').toString();
          autoEnabled = data['auto_enabled'] == true;
          final interval = (data['interval_minutes'] as num?)?.toInt() ?? 1440;
          if (interval <= 1440) {
            intervalMinutes = 1440;
          } else if (interval <= 10080) {
            intervalMinutes = 10080;
          } else {
            intervalMinutes = 43200;
          }
          statusText = (data['last_status_text'] ?? '').toString().trim();
          lastSyncAt = (data['last_sync_at'] as Timestamp?)?.toDate();
          loading = false;
        });
      } catch (_) {
        setModalState(() => loading = false);
      }
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted && loading) {
                  loadSettings(setModalState);
                }
              });
            }
            return AlertDialog(
              title: Text(
                companyName.isEmpty
                    ? 'Синхронизация аудита'
                    : 'Синхронизация аудита: $companyName',
              ),
              content: SizedBox(
                width: 560,
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: urlController,
                              decoration: const InputDecoration(
                                labelText: 'URL XML отчета 1С 8.3',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: tokenController,
                              decoration: const InputDecoration(
                                labelText: 'Токен (опционально)',
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              initialValue: intervalMinutes,
                              decoration: const InputDecoration(
                                labelText: 'Интервал автосинхронизации',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1440,
                                  child: Text('Раз в день'),
                                ),
                                DropdownMenuItem(
                                  value: 10080,
                                  child: Text('Раз в неделю'),
                                ),
                                DropdownMenuItem(
                                  value: 43200,
                                  child: Text('Раз в месяц'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setModalState(() => intervalMinutes = v);
                              },
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              value: autoEnabled,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setModalState(() => autoEnabled = val);
                              },
                              title: const Text('Автосинхронизация'),
                            ),
                            if (lastSyncAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Последняя синхронизация: ${dateTimeFormat('dd/MM/yyyy HH:mm', lastSyncAt, locale: FFLocalizations.of(context).languageCode)}',
                                style: FlutterFlowTheme.of(context).bodySmall,
                              ),
                            ],
                            if (statusText.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Статус: $statusText',
                                style: FlutterFlowTheme.of(context).bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: (saving || loading)
                      ? null
                      : () async {
                          final url = urlController.text.trim();
                          if (url.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Укажите URL XML отчета 1С 8.3'),
                              ),
                            );
                            return;
                          }
                          setModalState(() => saving = true);
                          try {
                            await FirebaseFirestore.instance
                                .collection('audit_1c_sync_settings')
                                .doc('${companyId}_xml')
                                .set({
                              'idCompany': companyId,
                              'updated_by': currentUserUid,
                              'type': 'xml_1c_83',
                              'xml_url': url,
                              'xml_token': tokenController.text.trim(),
                              'auto_enabled': autoEnabled,
                              'interval_minutes': intervalMinutes,
                              'updated_at': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Настройки синхронизации аудита сохранены',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ошибка сохранения: $e'),
                              ),
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setModalState(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    urlController.dispose();
    tokenController.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return dateTimeFormat('dd/MM/yyyy', date,
        locale: FFLocalizations.of(context).languageCode);
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return dateTimeFormat('dd/MM/yyyy HH:mm:ss', date,
        locale: FFLocalizations.of(context).languageCode);
  }

  String _auditValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) return _formatDateTime(value.toDate());
    if (value is DateTime) return _formatDateTime(value);
    if (value is DocumentReference) return value.path;
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${_auditValue(entry.value)}')
          .join('\n');
    }
    if (value is Iterable) return value.map(_auditValue).join(', ');
    return value.toString();
  }

  Future<void> _openCompanyAuditDialog(Map<String, dynamic> company) async {
    final companyId = (company['id'] ?? '').toString().trim();
    final companyName = (company['name'] ?? '').toString().trim();
    if (companyId.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        const dialogBg = Color(0xFF0F172A);
        const borderColor = Color(0xFF334155);
        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderColor),
          ),
          child: SizedBox(
            width: 1100,
            height: 720,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'История действий: $companyName',
                          style:
                              FlutterFlowTheme.of(context).titleLarge.override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Показываются последние 500 действий по компании.',
                    style: FlutterFlowTheme.of(context).bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('activity_log')
                          .where('idCompany', isEqualTo: companyId)
                          .orderBy('created_at', descending: true)
                          .limit(500)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Ошибка загрузки: ${snapshot.error}');
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snapshot.data!.docs.toList();
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('История пока пустая'),
                          );
                        }
                        return AdminTableScroll(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Дата и время')),
                              DataColumn(label: Text('Пользователь')),
                              DataColumn(label: Text('Действие')),
                              DataColumn(label: Text('Объект')),
                              DataColumn(label: Text('Название')),
                              DataColumn(label: Text('Детали')),
                            ],
                            rows: docs.map((doc) {
                              final data =
                                  Map<String, dynamic>.from(doc.data() as Map);
                              final createdAt =
                                  (data['created_at'] as Timestamp?)?.toDate();
                              final details = {
                                if ((data['details'] as Map?)?.isNotEmpty ??
                                    false)
                                  'details': data['details'],
                                if ((data['diff'] as Map?)?.isNotEmpty ?? false)
                                  'diff': data['diff'],
                                if ((data['before'] as Map?)?.isNotEmpty ??
                                    false)
                                  'before': data['before'],
                                if ((data['after'] as Map?)?.isNotEmpty ??
                                    false)
                                  'after': data['after'],
                              };
                              return DataRow(
                                cells: [
                                  DataCell(Text(_formatDateTime(createdAt))),
                                  DataCell(Text(() {
                                    final actor = [
                                      (data['user_name'] ?? '').toString(),
                                      (data['user_phone'] ?? '').toString(),
                                      (data['user_id'] ?? '').toString(),
                                    ]
                                        .where((part) => part.trim().isNotEmpty)
                                        .join('\n');
                                    return actor.isEmpty ? 'Не указан' : actor;
                                  }())),
                                  DataCell(
                                      Text((data['action'] ?? '').toString())),
                                  DataCell(
                                      Text((data['entity'] ?? '').toString())),
                                  DataCell(Text(
                                      (data['entity_title'] ?? '').toString())),
                                  DataCell(
                                    SizedBox(
                                      width: 420,
                                      child: Text(
                                        _auditValue(details),
                                        maxLines: 12,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _companyDesignLabel(Map<String, dynamic> company) {
    final template = normalizeUserDesignTemplate(
      company[kUserDesignTemplateField],
    );
    return template == kUserDesignReference ? 'Дизайн 2' : 'Дизайн 1';
  }

  Future<void> _openCompanyDesignDialog(Map<String, dynamic> company) async {
    final companyId = (company['id'] ?? '').toString().trim();
    final companyName = (company['name'] ?? '').toString().trim();
    if (companyId.isEmpty) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            companyName.isEmpty
                ? 'Дизайн компании'
                : 'Дизайн компании: $companyName',
          ),
          content: SizedBox(
            width: 960,
            child: SingleChildScrollView(
              child: UserDesignAdminPanel(companyId: companyId),
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

  Future<void> _openSchetaPageEditorDialog(Map<String, dynamic> company) async {
    final companyId = (company['id'] ?? '').toString().trim();
    final companyName = (company['name'] ?? '').toString().trim();
    if (companyId.isEmpty) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            companyName.isEmpty
                ? 'Редактор страницы "Счета"'
                : 'Счета: $companyName',
          ),
          content: SizedBox(
            width: 980,
            child: SingleChildScrollView(
              child: SchetaPageAdminPanel(companyId: companyId),
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

  @override
  Widget build(BuildContext context) {
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
          child: wrapWithModel(
            model: _model.drawersModel2,
            updateCallback: () => safeSetState(() {}),
            child: const DrawersWidget(),
          ),
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
                  width: 270.0,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111D31),
                    borderRadius: BorderRadius.circular(0.0),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1.0,
                    ),
                  ),
                  child: wrapWithModel(
                    model: _model.drawersModel1,
                    updateCallback: () => safeSetState(() {}),
                    child: const DrawersWidget(),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: const AlignmentDirectional(0.0, -1.0),
                  child: AdminContentFrame(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 16.0, 16.0, 0.0),
                            child: AdminResponsiveRow(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          '3adu4af3' /* Компании */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .headlineMedium
                                            .override(
                                              font: GoogleFonts.interTight(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .headlineMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .headlineMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      16.0, 12.0, 16.0, 12.0),
                                  child: AdminResponsiveRow(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        width: 50.0,
                                        height: 50.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .accent1,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            width: 2.0,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: AuthUserStreamWidget(
                                            builder: (context) => ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              child: CachedNetworkImage(
                                                fadeInDuration: const Duration(
                                                    milliseconds: 500),
                                                fadeOutDuration: const Duration(
                                                    milliseconds: 500),
                                                imageUrl: currentUserPhoto,
                                                width: 44.0,
                                                height: 44.0,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(12.0, 0.0, 0.0, 0.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            AuthUserStreamWidget(
                                              builder: (context) => Text(
                                                currentUserDisplayName,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyLarge
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                              ),
                                            ),
                                            Text(
                                              currentUserUid,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (responsiveVisibility(
                                  context: context,
                                  tabletLandscape: false,
                                  desktop: false,
                                ))
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(5.0),
                                        child: FlutterFlowIconButton(
                                          borderRadius: 8.0,
                                          buttonSize: 36.0,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          icon: Icon(
                                            Icons.menu,
                                            color: FlutterFlowTheme.of(context)
                                                .info,
                                            size: 24.0,
                                          ),
                                          onPressed: () async {
                                            scaffoldKey.currentState!
                                                .openDrawer();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 8.0, 16.0, 0.0),
                            child: AdminResponsiveRow(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Поиск по названию/БИН/ИНН',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) =>
                                        setState(() => _search = val.trim()),
                                  ),
                                ),
                                FFButtonWidget(
                                  onPressed: () => _openCompanyDialog(),
                                  text: 'Добавить компанию',
                                  options: FFButtonOptions(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    color: FlutterFlowTheme.of(context).primary,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdminCard(
                            child: UserDesignAdminPanel(
                              companyId: resolveCurrentCompanyId(),
                              compact: true,
                            ),
                          ),
                          AdminCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Список компаний',
                                  style: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        font: GoogleFonts.interTight(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        letterSpacing: 0.0,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('companies')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Text(
                                          'Ошибка загрузки компаний');
                                    }
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    return StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('company_profile')
                                          .snapshots(),
                                      builder: (context, profileSnapshot) {
                                        final profiles =
                                            <String, Map<String, dynamic>>{};
                                        if (profileSnapshot.hasError) {
                                          return Text(
                                            'Компании загружены, но нет доступа к реквизитам: ${profileSnapshot.error}',
                                          );
                                        }
                                        if (!profileSnapshot.hasData) {
                                          return const Center(
                                              child:
                                                  CircularProgressIndicator());
                                        }
                                        for (final doc in profileSnapshot
                                                .data?.docs ??
                                            const <QueryDocumentSnapshot>[]) {
                                          final profileData =
                                              Map<String, dynamic>.from(
                                            (doc.data() as Map?) ?? const {},
                                          );
                                          final profileCompanyId =
                                              _companyIdFromData(
                                            doc.id,
                                            profileData,
                                            allowDocId: true,
                                          );
                                          if (_isValidCompanyId(doc.id)) {
                                            profiles[doc.id] = profileData;
                                          }
                                          if (_isValidCompanyId(
                                              profileCompanyId)) {
                                            profiles[profileCompanyId] = {
                                              ...profileData,
                                              'idCompany': profileCompanyId,
                                            };
                                          }
                                        }
                                        final companyIds = snapshot.data!.docs
                                            .map((doc) => doc.id)
                                            .toSet();
                                        final companySignatures = <String>{};
                                        final rows =
                                            snapshot.data!.docs.map((doc) {
                                          final companyData =
                                              Map<String, dynamic>.from(
                                            (doc.data() as Map?) ?? const {},
                                          );
                                          final data = {
                                            ...?profiles[doc.id],
                                            ...companyData,
                                          };
                                          companySignatures
                                              .add(_companySignature(data));
                                          return {
                                            'id': doc.id,
                                            'name':
                                                companyAdminDisplayName(data),
                                            'bin': firstCompanyAdminText(
                                                data, ['bin', 'BIN', 'iin']),
                                            'ownerId': firstCompanyAdminText(
                                                data, ['ownerId', 'user_id']),
                                            'members': (companyData['members']
                                                    as List<dynamic>?)
                                                ?.length
                                                .toString(),
                                            'valuta': firstCompanyAdminText(
                                                data, ['valuta', 'currency']),
                                            'oced': _stringList(data['oced'] ??
                                                    data['oked'] ??
                                                    data['OKED'])
                                                .join(', '),
                                            'otrasl': firstCompanyAdminText(
                                                data,
                                                ['otrasl', 'business_type']),
                                            'forma': firstCompanyAdminText(
                                                data, ['forma', 'legal_form']),
                                            'nalog': firstCompanyAdminText(
                                                data, ['nalog', 'tax_regime']),
                                            'ndsPayer':
                                                data['ndsPayer'] == true ||
                                                    data['nds_payer'] == true,
                                            'buh_enabled':
                                                data['buh_enabled'] == true ||
                                                    data['buhEnabled'] ==
                                                        true ||
                                                    data['buh'] == true,
                                            'isActive':
                                                data['isActive'] != false,
                                            'createdAt': _dateFrom(
                                              data['createdAt'] ??
                                                  data['created_at'],
                                            ),
                                            'address': (data['address'] ?? '')
                                                .toString(),
                                            'source': 'companies',
                                            kUserDesignTemplateField:
                                                data[kUserDesignTemplateField],
                                          };
                                        }).toList();
                                        final addedProfileIds = <String>{};
                                        for (final entry in profiles.entries) {
                                          if (companyIds.contains(entry.key) ||
                                              addedProfileIds
                                                  .contains(entry.key)) {
                                            continue;
                                          }
                                          final data = entry.value;
                                          if (companySignatures.contains(
                                              _companySignature(data))) {
                                            continue;
                                          }
                                          final profileCompanyId =
                                              (data['idCompany'] ?? entry.key)
                                                  .toString()
                                                  .trim();
                                          if (!_isValidCompanyId(
                                                  profileCompanyId) ||
                                              companyIds
                                                  .contains(profileCompanyId) ||
                                              addedProfileIds
                                                  .contains(profileCompanyId)) {
                                            continue;
                                          }
                                          addedProfileIds.add(profileCompanyId);
                                          rows.add({
                                            'id': profileCompanyId,
                                            'name':
                                                companyAdminDisplayName(data),
                                            'bin': firstCompanyAdminText(
                                                data, ['bin', 'BIN', 'iin']),
                                            'ownerId': firstCompanyAdminText(
                                                data, ['ownerId', 'user_id']),
                                            'members': '0',
                                            'valuta': firstCompanyAdminText(
                                                data, ['valuta', 'currency']),
                                            'oced': _stringList(data['oced'] ??
                                                    data['oked'] ??
                                                    data['OKED'])
                                                .join(', '),
                                            'otrasl': firstCompanyAdminText(
                                                data,
                                                ['otrasl', 'business_type']),
                                            'forma': firstCompanyAdminText(
                                                data, ['forma', 'legal_form']),
                                            'nalog': firstCompanyAdminText(
                                                data, ['nalog', 'tax_regime']),
                                            'ndsPayer':
                                                data['ndsPayer'] == true ||
                                                    data['nds_payer'] == true,
                                            'buh_enabled':
                                                data['buh_enabled'] == true ||
                                                    data['buhEnabled'] ==
                                                        true ||
                                                    data['buh'] == true,
                                            'isActive':
                                                data['isActive'] != false,
                                            'createdAt': _dateFrom(
                                              data['createdAt'] ??
                                                  data['created_at'],
                                            ),
                                            'address': (data['address'] ?? '')
                                                .toString(),
                                            'source': 'company_profile',
                                            kUserDesignTemplateField:
                                                data[kUserDesignTemplateField],
                                          });
                                        }
                                        final filteredRows = rows.where((row) {
                                          if (_search.isEmpty) return true;
                                          final q = _search.toLowerCase();
                                          return [
                                            row['id'],
                                            row['name'],
                                            row['bin'],
                                            row['oced'],
                                            row['otrasl'],
                                            row['forma'],
                                            row['nalog'],
                                            row['valuta'],
                                            row['ownerId'],
                                            row['address'],
                                          ].any((value) => value
                                              .toString()
                                              .toLowerCase()
                                              .contains(q));
                                        }).toList()
                                          ..sort((a, b) {
                                            final aDate =
                                                a['createdAt'] as DateTime?;
                                            final bDate =
                                                b['createdAt'] as DateTime?;
                                            if (aDate != null &&
                                                bDate != null) {
                                              return bDate.compareTo(aDate);
                                            }
                                            return a['name']
                                                .toString()
                                                .compareTo(
                                                    b['name'].toString());
                                          });
                                        if (filteredRows.isEmpty) {
                                          return const Text(
                                              'Компании не найдены');
                                        }
                                        return AdminTableScroll(
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(
                                                  label: Text('Название')),
                                              DataColumn(
                                                  label: Text('Редактировать')),
                                              DataColumn(
                                                  label: Text('Источник')),
                                              DataColumn(label: Text('БИН/ИНН')),
                                              DataColumn(label: Text('ОКЭД')),
                                              DataColumn(
                                                  label: Text('Отрасль')),
                                              DataColumn(label: Text('Форма')),
                                              DataColumn(label: Text('Налог')),
                                              DataColumn(label: Text('Дизайн')),
                                              DataColumn(
                                                  label: Text('Владелец')),
                                              DataColumn(
                                                  label: Text('Участники')),
                                              DataColumn(label: Text('Валюта')),
                                              DataColumn(label: Text('НДС')),
                                              DataColumn(
                                                  label: Text('Бухучет')),
                                              DataColumn(label: Text('Статус')),
                                              DataColumn(
                                                  label: Text('Создана')),
                                              DataColumn(
                                                  label: Text('Действия')),
                                            ],
                                            rows: filteredRows.map((row) {
                                              return DataRow(cells: [
                                                DataCell(Text(
                                                    row['name'].toString())),
                                                DataCell(
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      size: 18,
                                                    ),
                                                    tooltip:
                                                        'Редактировать компанию',
                                                    onPressed: () =>
                                                        _openCompanyDialog(
                                                            existing: row),
                                                  ),
                                                ),
                                                DataCell(Text(
                                                  row['source'] ==
                                                          'company_profile'
                                                      ? 'Профиль без компании'
                                                      : 'Компания',
                                                )),
                                                DataCell(Text(
                                                    row['bin'].toString())),
                                                DataCell(Text(
                                                    row['oced'].toString())),
                                                DataCell(Text(
                                                    row['otrasl'].toString())),
                                                DataCell(Text(
                                                    row['forma'].toString())),
                                                DataCell(Text(
                                                    row['nalog'].toString())),
                                                DataCell(
                                                  Text(
                                                      _companyDesignLabel(row)),
                                                ),
                                                DataCell(Text(
                                                    row['ownerId'].toString())),
                                                DataCell(Text(
                                                  ((row['members'] is List)
                                                          ? (row['members']
                                                                  as List)
                                                              .length
                                                          : (row['members'] ??
                                                              0))
                                                      .toString(),
                                                )),
                                                DataCell(Text(
                                                    row['valuta'].toString())),
                                                DataCell(Text(
                                                    row['ndsPayer'] == true
                                                        ? 'Да'
                                                        : 'Нет')),
                                                DataCell(Text(
                                                    row['buh_enabled'] == true
                                                        ? 'Да'
                                                        : 'Нет')),
                                                DataCell(Text(
                                                    row['isActive'] == true
                                                        ? 'Активна'
                                                        : 'Отключена')),
                                                DataCell(Text(_formatDate(
                                                    row['createdAt']
                                                        as DateTime?))),
                                                DataCell(
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .palette_outlined,
                                                          size: 18,
                                                        ),
                                                        tooltip:
                                                            'Назначить дизайн компании',
                                                        onPressed: () =>
                                                            _openCompanyDesignDialog(
                                                                row),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .dashboard_customize_outlined,
                                                          size: 18,
                                                        ),
                                                        tooltip:
                                                            'Редактор страницы "Счета"',
                                                        onPressed: () =>
                                                            _openSchetaPageEditorDialog(
                                                                row),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .sync_alt_rounded,
                                                          size: 18,
                                                        ),
                                                        tooltip:
                                                            'Синхронизация аудита',
                                                        onPressed: () =>
                                                            _openAuditSyncDialog(
                                                                row),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.history,
                                                          size: 18,
                                                        ),
                                                        tooltip:
                                                            'История действий',
                                                        onPressed: () =>
                                                            _openCompanyAuditDialog(
                                                                row),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.edit,
                                                            size: 18),
                                                        onPressed: () =>
                                                            _openCompanyDialog(
                                                                existing: row),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(
                                                          row['isActive'] ==
                                                                  true
                                                              ? Icons
                                                                  .pause_circle
                                                              : Icons
                                                                  .play_circle,
                                                          size: 18,
                                                        ),
                                                        onPressed: () async {
                                                          final nextActive =
                                                              !(row['isActive']
                                                                  as bool);
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                  'companies')
                                                              .doc(row['id']
                                                                  .toString())
                                                              .update({
                                                            'isActive':
                                                                nextActive,
                                                            'updatedAt': FieldValue
                                                                .serverTimestamp(),
                                                          });
                                                          await AuditLogService
                                                              .logAction(
                                                            companyId: row['id']
                                                                .toString(),
                                                            action: nextActive
                                                                ? 'activate'
                                                                : 'deactivate',
                                                            entity: 'company',
                                                            entityId: row['id']
                                                                .toString(),
                                                            entityTitle:
                                                                row['name']
                                                                    .toString(),
                                                            before: row,
                                                            after: {
                                                              'isActive':
                                                                  nextActive,
                                                            },
                                                            details: const {
                                                              'message':
                                                                  'Изменен статус компании',
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ]);
                                            }).toList(),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ].addToEnd(const SizedBox(height: 24.0)),
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
