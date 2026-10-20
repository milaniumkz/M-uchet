import '/admin/component/drawers/drawers_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'support_admin_model.dart';
import '/admin/component/admin_content_frame.dart';
import '/admin/component/admin_responsive_row.dart';
import '/admin/component/admin_card.dart';
import '/admin/component/admin_table_scroll.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'support_admin_model.dart';

class SupportAdminWidget extends StatefulWidget {
  const SupportAdminWidget({super.key});

  static String routeName = 'supportAdmin';
  static String routePath = '/supportAdmin';

  @override
  State<SupportAdminWidget> createState() => _SupportAdminWidgetState();
}

class _SupportAdminWidgetState extends State<SupportAdminWidget> {
  late SupportAdminModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _statusFilter = 'all';
  String _search = '';

  String _activeCompanyId() {
    final active =
        (currentUserDocument?.snapshotData['activeCompanyId'] ?? '')
            .toString()
            .trim();
    if (active.isNotEmpty) return active;
    return valueOrDefault<String>(currentUserDocument?.idCompany, '').trim();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SupportAdminModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _model.dispose();

    super.dispose();
  }

  Future<void> _openTicketDialog({Map<String, dynamic>? existing}) async {
    if (existing != null) {
      _subjectController.text = (existing['subject'] ?? '').toString();
      _messageController.text = (existing['message'] ?? '').toString();
    } else {
      _subjectController.clear();
      _messageController.clear();
    }
    String status = (existing?['status'] ?? 'open').toString();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Новый тикет' : 'Редактировать тикет'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Тема'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Сообщение'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Открыт')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('В работе')),
                    DropdownMenuItem(value: 'closed', child: Text('Закрыт')),
                  ],
                  onChanged: (val) {
                    if (val != null) status = val;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final subject = _subjectController.text.trim();
                if (subject.isEmpty) return;
                final companyId = _activeCompanyId();
                if (companyId.isEmpty) return;
                final data = <String, dynamic>{
                  'subject': subject,
                  'message': _messageController.text.trim(),
                  'status': status,
                  'updated_at': FieldValue.serverTimestamp(),
                };
                final ref = FirebaseFirestore.instance.collection('support_tickets');
                if (existing == null) {
                  await ref.add({
                    ...data,
                    'idCompany': companyId,
                    'created_at': FieldValue.serverTimestamp(),
                    'created_by': currentUserUid,
                  });
                } else {
                  await ref.doc(existing['id']).update(data);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  Widget _statusChip(String label, String value, int count) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
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
            child: DrawersWidget(),
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
                    color: Color(0xFF111D31),
                    borderRadius: BorderRadius.circular(0.0),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1.0,
                    ),
                  ),
                  child: wrapWithModel(
                    model: _model.drawersModel1,
                    updateCallback: () => safeSetState(() {}),
                    child: DrawersWidget(),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional(0.0, -1.0),
                  child: AdminContentFrame(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
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
                                          'boa1g06q' /* Поддержка */,
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
                                  padding: EdgeInsetsDirectional.fromSTEB(
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
                                          padding: EdgeInsets.all(2.0),
                                          child: AuthUserStreamWidget(
                                            builder: (context) => ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              child: CachedNetworkImage(
                                                fadeInDuration:
                                                    Duration(milliseconds: 500),
                                                fadeOutDuration:
                                                    Duration(milliseconds: 500),
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
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 0.0, 0.0),
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
                                        padding: EdgeInsets.all(5.0),
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
                          AdminCard(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('support_tickets')
                                  .orderBy('created_at', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return const Text(
                                      'Ошибка загрузки обращений');
                                }
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                final activeCompanyId = _activeCompanyId();
                                final docs = snapshot.data!.docs.map((d) {
                                  final raw = d.data();
                                  final data = raw is Map<String, dynamic>
                                      ? raw
                                      : Map<String, dynamic>.from(raw as Map);
                                  return {'id': d.id, ...data};
                                }).where((d) {
                                  if (activeCompanyId.isEmpty) return false;
                                  return (d['idCompany'] ?? '').toString() ==
                                      activeCompanyId;
                                }).toList();
                                final openCount = docs
                                    .where((d) => d['status'] == 'open')
                                    .length;
                                final inProgressCount = docs
                                    .where((d) => d['status'] == 'in_progress')
                                    .length;
                                final closedCount = docs
                                    .where((d) => d['status'] == 'closed')
                                    .length;
                                var filtered = docs;
                                if (_statusFilter != 'all') {
                                  filtered = filtered
                                      .where((d) =>
                                          (d['status'] ?? '').toString() ==
                                          _statusFilter)
                                      .toList();
                                }
                                if (_search.trim().isNotEmpty) {
                                  final q = _search.trim().toLowerCase();
                                  filtered = filtered.where((d) {
                                    final subject =
                                        (d['subject'] ?? '').toString();
                                    final message =
                                        (d['message'] ?? '').toString();
                                    return subject.toLowerCase().contains(q) ||
                                        message.toLowerCase().contains(q);
                                  }).toList();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AdminResponsiveRow(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Очередь поддержки',
                                          style: FlutterFlowTheme.of(context)
                                              .titleMedium,
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _openTicketDialog(),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Новый тикет'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _statusChip('Все', 'all', docs.length),
                                        _statusChip(
                                            'Открытые', 'open', openCount),
                                        _statusChip('В работе', 'in_progress',
                                            inProgressCount),
                                        _statusChip(
                                            'Закрытые', 'closed', closedCount),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      decoration: const InputDecoration(
                                        labelText: 'Поиск по теме или тексту',
                                      ),
                                      onChanged: (val) =>
                                          setState(() => _search = val),
                                    ),
                                    const SizedBox(height: 16),
                                    if (filtered.isEmpty)
                                      Text(
                                        'Тикеты не найдены',
                                        style: TextStyle(
                                            color: Colors.grey[600]),
                                      )
                                    else
                                      AdminTableScroll(
                                        child: Column(
                                          children: filtered.map((ticket) {
                                            final subject =
                                                (ticket['subject'] ?? '')
                                                    .toString();
                                            final status =
                                                (ticket['status'] ?? '')
                                                    .toString();
                                            final createdAt =
                                                ticket['created_at'] is Timestamp
                                                    ? (ticket['created_at']
                                                            as Timestamp)
                                                        .toDate()
                                                    : null;
                                            final dateLabel = createdAt == null
                                                ? '-'
                                                : dateTimeFormat(
                                                    'dd.MM.yyyy',
                                                    createdAt,
                                                    locale: FFLocalizations.of(
                                                            context)
                                                        .languageCode,
                                                  );
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 8),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFE5E7EB)),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          subject.isEmpty
                                                              ? 'Без темы'
                                                              : subject,
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          'Статус: $status',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[600]),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(dateLabel),
                                                  const SizedBox(width: 12),
                                                  TextButton(
                                                    onPressed: () =>
                                                        _openTicketDialog(
                                                            existing: ticket),
                                                    child:
                                                        const Text('Открыть'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ].addToEnd(SizedBox(height: 24.0)),
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
