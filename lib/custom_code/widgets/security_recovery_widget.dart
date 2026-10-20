// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class SecurityRecoveryWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SecurityRecoveryWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<SecurityRecoveryWidget> createState() => _SecurityRecoveryWidgetState();
}

class _SecurityRecoveryWidgetState extends State<SecurityRecoveryWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _contact = TextEditingController();
  final _details = TextEditingController();
  bool _loading = false;
  bool _sending = false;
  String _companyId = '';
  String _message = '';
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _adminRequests = [];
  String _adminStatus = 'all';
  String _adminSort = 'new';
  String _adminSearch = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _contact.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
      final effectiveCompanyId =
          rawCompanyId.isNotEmpty ? rawCompanyId : user.uid;
      _companyId = effectiveCompanyId;

      final snap = await _firestore
          .collection('data_restore_requests')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .limit(10)
          .getCached();

      List<Map<String, dynamic>> adminRows = [];
      if (_isAdmin) {
        final adminSnap = await _firestore
            .collection('data_restore_requests')
            .where('idCompany', isEqualTo: effectiveCompanyId)
            .orderBy('created_at', descending: true)
            .limit(50)
            .getCached();
        adminRows = adminSnap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
      }

      setState(() {
        _requests = snap.docs.map((d) {
          final raw = d.data();
          final data = raw is Map<String, dynamic>
              ? raw
              : Map<String, dynamic>.from(raw as Map);
          return {'id': d.id, ...data};
        }).toList();
        _adminRequests = adminRows;
      });
    } catch (e) {
      print('Error loading restore requests: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  bool get _hasActiveRequest {
    return _requests.any((r) {
      final status = (r['status'] ?? 'pending').toString();
      return status == 'pending' || status == 'in_progress';
    });
  }

  bool get _isAdmin => FFAppState().role == 'admin';

  List<Map<String, dynamic>> get _adminFiltered {
    var rows = _adminRequests.where((r) {
      if (_adminStatus == 'all') return true;
      return (r['status'] ?? 'pending').toString() == _adminStatus;
    }).toList();

    if (_adminSearch.trim().isNotEmpty) {
      final q = _adminSearch.trim().toLowerCase();
      rows = rows.where((r) {
        final details = (r['details'] ?? '').toString().toLowerCase();
        final contact = (r['contact'] ?? '').toString().toLowerCase();
        final user = (r['user_id'] ?? '').toString().toLowerCase();
        return details.contains(q) || contact.contains(q) || user.contains(q);
      }).toList();
    }

    rows.sort((a, b) {
      final aDate = a['created_at'];
      final bDate = b['created_at'];
      final aTs = aDate is Timestamp ? aDate.toDate() : DateTime(1970);
      final bTs = bDate is Timestamp ? bDate.toDate() : DateTime(1970);
      if (_adminSort == 'old') {
        return aTs.compareTo(bTs);
      }
      return bTs.compareTo(aTs);
    });
    return rows;
  }

  int get _adminPendingCount {
    return _adminRequests
        .where((r) =>
            (r['status'] ?? 'pending').toString() == 'pending' ||
            (r['status'] ?? 'pending').toString() == 'in_progress')
        .length;
  }

  Future<void> _sendRequest() async {
    if (_contact.text.trim().isEmpty || _details.text.trim().isEmpty) {
      setState(() => _message = 'Заполните контакт и описание проблемы');
      return;
    }
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final ref = await _firestore.collection('data_restore_requests').add({
        'contact': _contact.text.trim(),
        'details': _details.text.trim(),
        'status': 'pending',
        'idCompany': _companyId,
        'user_id': user.uid,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('admin_notifications').add({
        'type': 'restore_request',
        'title': 'Новый запрос на восстановление',
        'message': _details.text.trim(),
        'request_id': ref.id,
        'idCompany': _companyId,
        'user_id': user.uid,
        'status': 'unread',
        'created_at': FieldValue.serverTimestamp(),
      });
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('data_restore_requests', _companyId);
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('admin_notifications', _companyId);
      _contact.clear();
      _details.clear();
      setState(() => _message = 'Запрос на восстановление отправлен');
      await _loadData();
    } catch (e) {
      setState(() => _message = 'Не удалось отправить запрос');
    } finally {
      setState(() => _sending = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return FlutterFlowTheme.of(context).success;
      case 'rejected':
        return FlutterFlowTheme.of(context).error;
      case 'in_progress':
        return FlutterFlowTheme.of(context).primary;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _showAdminUpdateDialog(Map<String, dynamic> request) async {
    String status = (request['status'] ?? 'pending').toString();
    final commentCtrl = TextEditingController(
        text: (request['admin_comment'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Обработать запрос'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(
                labelText: 'Статус',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Ожидает')),
                DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                DropdownMenuItem(value: 'completed', child: Text('Завершен')),
                DropdownMenuItem(value: 'rejected', child: Text('Отклонен')),
              ],
              onChanged: (value) => status = value ?? 'pending',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Комментарий администратора',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null) return;
              await _firestore
                  .collection('data_restore_requests')
                  .doc(request['id'])
                  .update({
                'status': status,
                'admin_comment': commentCtrl.text.trim(),
                'admin_id': user.uid,
                'admin_name':
                    (currentUserDocument?.displayName ?? user.email ?? '')
                        .toString(),
                'updated_at': FieldValue.serverTimestamp(),
              });
              FirestoreQueryCache.instance.invalidateCompanyCollection(
                  'data_restore_requests', _companyId);
              if (mounted) Navigator.of(context).pop();
              await _loadData();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showAdminDetailsDialog(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final createdAt = request['created_at'];
    final updatedAt = request['updated_at'];
    final created = createdAt is Timestamp
        ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate())
        : '—';
    final updated = updatedAt is Timestamp
        ? DateFormat('dd.MM.yyyy HH:mm').format(updatedAt.toDate())
        : '—';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Детали запроса'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Статус', status.replaceAll('_', ' ')),
              _detailRow('Контакт', (request['contact'] ?? '—').toString()),
              _detailRow(
                  'Пользователь', (request['user_id'] ?? '—').toString()),
              _detailRow('Создан', created),
              _detailRow('Обновлен', updated),
              const SizedBox(height: 8),
              const Text('Описание',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text((request['details'] ?? '—').toString()),
              const SizedBox(height: 12),
              const Text('Комментарий администратора',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text((request['admin_comment'] ?? '—').toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: FlutterFlowTheme.of(context).secondaryText)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('security.restore')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final contentWidth = maxWidth > 1360 ? 1360.0 : maxWidth;
          final isNarrow = maxWidth < 900;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.lock_reset_outlined,
                            color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Восстановление доступа',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Опишите проблему и оставьте контакт. Запрос уйдет администратору и в службу поддержки.',
                    style: TextStyle(
                        color: FlutterFlowTheme.of(context).secondaryText),
                  ),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(_message,
                          style: TextStyle(color: Color(0xFF1D4ED8))),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Новый запрос',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contact,
                          decoration: const InputDecoration(
                            labelText: 'Контакт (email или телефон)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _details,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Описание проблемы',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _hasActiveRequest
                                    ? 'У вас уже есть активный запрос'
                                    : 'Обычно ответ в течение 24 часов',
                                style: TextStyle(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _hasActiveRequest || _sending
                                  ? null
                                  : _sendRequest,
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Отправить'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    FlutterFlowTheme.of(context).primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'История запросов',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else if (_requests.isEmpty)
                          Text('Запросов пока нет',
                              style: TextStyle(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText))
                        else
                          Column(
                            children: _requests.map((req) {
                              final status =
                                  (req['status'] ?? 'pending').toString();
                              final createdAt = req['created_at'];
                              final date = createdAt is Timestamp
                                  ? DateFormat('dd.MM.yyyy HH:mm')
                                      .format(createdAt.toDate())
                                  : '—';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (req['details'] ?? 'Без описания')
                                                .toString(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(date,
                                              style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status.replaceAll('_', ' '),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Админ панель: все запросы',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Активные: $_adminPendingCount',
                                  style: const TextStyle(
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: isNarrow ? contentWidth : 420,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Поиск (контакт, текст, пользователь)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _adminSearch = v),
                                ),
                              ),
                              SizedBox(
                                width: 170,
                                child: DropdownButtonFormField<String>(
                                  value: _adminStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Статус',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'all', child: Text('Все')),
                                    DropdownMenuItem(
                                        value: 'pending',
                                        child: Text('Ожидает')),
                                    DropdownMenuItem(
                                        value: 'in_progress',
                                        child: Text('В работе')),
                                    DropdownMenuItem(
                                        value: 'completed',
                                        child: Text('Завершен')),
                                    DropdownMenuItem(
                                        value: 'rejected',
                                        child: Text('Отклонен')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _adminStatus = v ?? 'all'),
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: DropdownButtonFormField<String>(
                                  value: _adminSort,
                                  decoration: const InputDecoration(
                                    labelText: 'Сортировка',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'new', child: Text('Новые')),
                                    DropdownMenuItem(
                                        value: 'old', child: Text('Старые')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _adminSort = v ?? 'new'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_loading)
                            const Center(child: CircularProgressIndicator())
                          else if (_adminFiltered.isEmpty)
                            Text('Запросов нет',
                                style: TextStyle(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText))
                          else
                            Column(
                              children: _adminFiltered.map((req) {
                                final status =
                                    (req['status'] ?? 'pending').toString();
                                final createdAt = req['created_at'];
                                final date = createdAt is Timestamp
                                    ? DateFormat('dd.MM.yyyy HH:mm')
                                        .format(createdAt.toDate())
                                    : '—';
                                final user = (req['user_id'] ?? '').toString();
                                final contact =
                                    (req['contact'] ?? '').toString();
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (req['details'] ?? 'Без описания')
                                                  .toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _statusColor(status)
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              status.replaceAll('_', ' '),
                                              style: TextStyle(
                                                color: _statusColor(status),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (contact.isNotEmpty)
                                        Text('Контакт: $contact',
                                            style: TextStyle(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText)),
                                      Text('Пользователь: $user',
                                          style: TextStyle(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText)),
                                      Text(date,
                                          style: TextStyle(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                _showAdminDetailsDialog(req),
                                            child: const Text('Подробнее'),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _showAdminUpdateDialog(req),
                                            icon: const Icon(Icons.edit,
                                                size: 16),
                                            label: const Text('Обработать'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
