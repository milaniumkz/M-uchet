import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/component/drawers_users/drawers_users_widget.dart';
import '/component/header/header_widget.dart';
import '/utils/user_access_context.dart';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'home_model.dart';
export 'home_model.dart';

class HomeWidget extends StatefulWidget {
  const HomeWidget({super.key});

  static String routeName = 'home';
  static String routePath = '/home';

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> with TickerProviderStateMixin {
  late HomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};
  String _dashboardPeriod = 'week';
  Future<_HomeDashboardData>? _dashboardFuture;
  String _dashboardFutureKey = '';

  String _effectiveCompanyId() {
    return UserAccessContext.fromData(currentUserDocument?.snapshotData)
        .selectedCompanyId;
  }

  List<String> _dashboardCompanyIds() {
    return UserAccessContext.fromData(currentUserDocument?.snapshotData)
        .queryCompanyIds();
  }

  String _todayLabel() {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _headerDateChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 16.0,
            color: FlutterFlowTheme.of(context).primary,
          ),
          const SizedBox(width: 8.0),
          Text(
            _todayLabel(),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
        ],
      ),
    );
  }

  DateTime _periodStart(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case 'today':
        return today;
      case 'twoWeeks':
        return today.subtract(const Duration(days: 13));
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'week':
      default:
        return today.subtract(const Duration(days: 6));
    }
  }

  DateTime? _asDate(dynamic value) {
    if (value is DateTime) return value;
    try {
      final dynamic raw = value;
      final converted = raw.toDate();
      if (converted is DateTime) return converted;
    } catch (_) {
      return DateTime.tryParse(value?.toString() ?? '');
    }
    return null;
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }

  String _money(double value) {
    final sign = value < 0 ? '-' : '';
    final raw = value.abs().toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final left = raw.length - i;
      buffer.write(raw[i]);
      if (left > 1 && left % 3 == 1) buffer.write(' ');
    }
    return '$sign$buffer';
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _queryCompanyDocs(
    String collectionName,
    List<String> companyIds,
  ) async {
    final ids = companyIds.map((e) => e.trim()).where((e) => e.isNotEmpty);
    final uniqueIds = ids.toSet().toList()..sort();
    if (uniqueIds.isEmpty) return const [];
    if (uniqueIds.length == 1) {
      final snap = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('idCompany', isEqualTo: uniqueIds.first)
          .get();
      return snap.docs;
    }

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var i = 0; i < uniqueIds.length; i += 10) {
      final chunk = uniqueIds.skip(i).take(10).toList();
      final snap = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('idCompany', whereIn: chunk)
          .get();
      docs.addAll(snap.docs);
    }
    return docs;
  }

  double _accountAmount(Map<String, dynamic> data) {
    for (final key in const [
      'summa_company',
      'summaCompany',
      'current_balance',
      'currentBalance',
      'summa',
      'opening_balance',
      'openingBalance',
    ]) {
      final amount = _num(data[key]);
      if (amount != 0) return amount;
    }
    return 0;
  }

  Future<_HomeDashboardData> _loadDashboard(
      List<String> companyIds, String period) async {
    if (companyIds.isEmpty) return _HomeDashboardData.empty();
    final start = _periodStart(period);

    final results = await Future.wait([
      _queryCompanyDocs('funding_requests', companyIds),
      _queryCompanyDocs('sheta', companyIds),
      _queryCompanyDocs('debt_register', companyIds),
    ]);

    final requests = results[0];
    final accounts = results[1];
    final debts = results[2];

    var requestsToday = 0;
    var requestsInPeriod = 0;
    var requestsOnApproval = 0;
    var requestsAmount = 0.0;
    var requestsApproved = 0.0;
    var requestsToPay = 0.0;
    var requestsPaid = 0.0;
    var requestsRemaining = 0.0;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    for (final doc in requests) {
      final data = doc.data();
      final created = _asDate(data['created_at'] ?? data['date']);
      final amount = _fundingRequestAmount(data);
      final status = (data['status'] ?? '').toString().toLowerCase();
      final paid = _num(data['paid_amount'] ??
          data['paidAmount'] ??
          data['total_paid'] ??
          data['totalPaid']);
      final remainingRaw =
          data['remaining_amount'] ?? data['remainingAmount'] ?? data['rest'];
      final remaining = remainingRaw == null
          ? (amount - paid).clamp(0.0, double.infinity)
          : _num(remainingRaw);
      final inPeriod = created == null || !created.isBefore(start);
      if (created != null && !created.isBefore(todayStart)) requestsToday++;
      if (!inPeriod) continue;
      requestsInPeriod++;
      requestsAmount += amount;
      requestsPaid += paid;
      requestsRemaining += remaining;
      if (status.contains('соглас') ||
          status.contains('ответствен') ||
          status.contains('pending') ||
          status.contains('approval') ||
          status.contains('на соглас')) {
        requestsOnApproval++;
      }
      if (status.contains('одоб') ||
          status.contains('к оплат') ||
          status.contains('approved') ||
          status.contains('to_pay') ||
          status.contains('частично') ||
          status.contains('оплач')) {
        requestsApproved += amount;
      }
      if (status.contains('к оплат')) {
        requestsToPay += remaining;
      }
    }

    var moneyTotal = 0.0;
    for (final doc in accounts) {
      final data = doc.data();
      moneyTotal += _accountAmount(data);
    }

    var obligations = 0.0;
    var receivables = 0.0;
    for (final doc in debts) {
      final data = doc.data();
      final type = (data['type'] ?? data['debt_type'] ?? '').toString();
      final amount = _num(data['remaining_amount'] ??
          data['outstanding_amount'] ??
          data['amount_remaining'] ??
          data['amount']);
      if (type.contains('receivable')) {
        receivables += amount;
      } else {
        obligations += amount;
      }
    }

    return _HomeDashboardData(
      requestsToday: requestsToday,
      requestsInPeriod: requestsInPeriod,
      requestsOnApproval: requestsOnApproval,
      requestsAmount: requestsAmount,
      requestsApproved: requestsApproved,
      requestsToPay: requestsToPay,
      requestsPaid: requestsPaid,
      requestsRemaining: requestsRemaining,
      moneyTotal: moneyTotal,
      obligations: obligations,
      receivables: receivables,
      periodStart: start,
    );
  }

  double _fundingRequestAmount(Map<String, dynamic> data) {
    final direct = _num(data['amount'] ??
        data['sum'] ??
        data['total'] ??
        data['total_amount'] ??
        data['totalAmount']);
    if (direct > 0) return direct;
    final rows = data['expense_rows'] ?? data['expenseRows'] ?? data['rows'];
    if (rows is Iterable) {
      var total = 0.0;
      for (final row in rows) {
        if (row is Map) {
          total += _num(row['amount'] ?? row['sum'] ?? row['total']);
        }
      }
      return total;
    }
    return 0.0;
  }

  Future<_HomeDashboardData> _dashboardFutureFor(List<String> companyIds) {
    final key = '${companyIds.join('|')}:$_dashboardPeriod';
    if (_dashboardFuture == null || _dashboardFutureKey != key) {
      _dashboardFutureKey = key;
      _dashboardFuture = _loadDashboard(companyIds, _dashboardPeriod);
    }
    return _dashboardFuture!;
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).labelSmall.override(
                          font: GoogleFonts.inter(fontSize: 11),
                          fontSize: 11,
                        )),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.interTight(
                              fontWeight: FontWeight.w700),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodFilter() {
    const items = {
      'today': 'Сегодня',
      'week': 'Неделя',
      'twoWeeks': '2 недели',
      'month': 'Месяц',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.entries.map((entry) {
        final selected = _dashboardPeriod == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: selected,
          visualDensity: VisualDensity.compact,
          labelStyle: FlutterFlowTheme.of(context).labelSmall,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => setState(() {
            _dashboardPeriod = entry.key;
            _dashboardFuture = null;
          }),
        );
      }).toList(),
    );
  }

  Widget _dashboard() {
    return FutureBuilder<_HomeDashboardData>(
      future: _dashboardFutureFor(_dashboardCompanyIds()),
      builder: (context, snapshot) {
        final data = snapshot.data ?? _HomeDashboardData.empty();
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final cards = [
          _metricCard('Заявок сегодня', data.requestsToday.toString(),
              Icons.today, const Color(0xFF2563EB)),
          _metricCard('На согласовании', data.requestsOnApproval.toString(),
              Icons.rule, const Color(0xFF7C3AED)),
          _metricCard('Сумма заявок', _money(data.requestsAmount),
              Icons.request_quote, const Color(0xFF0F766E)),
          _metricCard('Одобрено', _money(data.requestsApproved), Icons.verified,
              const Color(0xFF16A34A)),
          _metricCard('К оплате', _money(data.requestsToPay), Icons.payments,
              const Color(0xFFDC2626)),
          _metricCard('Оплачено', _money(data.requestsPaid), Icons.done_all,
              const Color(0xFF059669)),
          _metricCard('Остаток заявок', _money(data.requestsRemaining),
              Icons.pending_actions, const Color(0xFFEA580C)),
          _metricCard('Деньги на счетах', _money(data.moneyTotal),
              Icons.account_balance_wallet, const Color(0xFFB45309)),
          _metricCard('Обязательства', _money(data.obligations),
              Icons.assignment_late, const Color(0xFF9333EA)),
          _metricCard('Дебиторка', _money(data.receivables), Icons.receipt_long,
              const Color(0xFF0284C7)),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Общий дашборд',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.interTight(
                                fontWeight: FontWeight.w700),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  _periodFilter(),
                ],
              ),
              const SizedBox(height: 6),
              if (loading) const LinearProgressIndicator(minHeight: 2),
              SizedBox(height: loading ? 6 : 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 980
                        ? 5
                        : width >= 760
                            ? 4
                            : width >= 520
                                ? 3
                                : 2;
                    final rows = (cards.length / columns).ceil();
                    final tileWidth = (width - ((columns - 1) * 8)) / columns;
                    final tileHeight =
                        ((constraints.maxHeight - ((rows - 1) * 8)) / rows)
                            .clamp(58.0, 86.0);
                    return GridView.count(
                      crossAxisCount: columns,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: tileWidth / tileHeight,
                      children: cards,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final role =
          valueOrDefault<String>(currentUserDocument?.role, FFAppState().role)
              .trim()
              .toLowerCase();
      final contextData =
          UserAccessContext.fromData(currentUserDocument?.snapshotData);
      if (role == 'admin' || role == 'super_admin' || role == 'superadmin') {
        context.goNamed(
          HomeAdminWidget.routeName,
          extra: <String, dynamic>{
            kTransitionInfoKey: TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.scale,
              alignment: Alignment.bottomCenter,
            ),
          },
        );
      } else {
        final companyId = contextData.selectedCompanyId;
        if (companyId.isEmpty && role == 'owner') {
          return;
        } else if (companyId.isEmpty) {
          context.goNamed(LoginWidget.routeName);
        } else if (role != 'owner') {
          return;
        }
      }
    });

    animationsMap.addAll({
      'columnOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
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
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                      width: 1.0,
                    ),
                  ),
                  child: const DrawersUsersWidget(),
                ),
              Expanded(
                child: Align(
                  alignment: const AlignmentDirectional(0.0, -1.0),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      maxWidth: 1170.0,
                    ),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                    ),
                    child: Column(
                      children: [
                        if (responsiveVisibility(
                          context: context,
                          tabletLandscape: false,
                          desktop: false,
                        ))
                          Align(
                            alignment: AlignmentDirectional(-1.0, 0.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 12.0,
                                buttonSize: 44.0,
                                fillColor: FlutterFlowTheme.of(context).accent1,
                                icon: Icon(
                                  Icons.menu_rounded,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                                onPressed: () async {
                                  scaffoldKey.currentState?.openDrawer();
                                },
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12.0, 12.0, 12.0, 0.0),
                                child: HeaderWidget(
                                  title: 'Главная',
                                  trailing: _headerDateChip(),
                                ),
                              ),
                              Expanded(
                                child: _dashboard(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ).animateOnPageLoad(animationsMap['columnOnPageLoadAnimation']!),
        ),
      ),
    );
  }
}

class _HomeDashboardData {
  const _HomeDashboardData({
    required this.requestsToday,
    required this.requestsInPeriod,
    required this.requestsOnApproval,
    required this.requestsAmount,
    required this.requestsApproved,
    required this.requestsToPay,
    required this.requestsPaid,
    required this.requestsRemaining,
    required this.moneyTotal,
    required this.obligations,
    required this.receivables,
    required this.periodStart,
  });

  final int requestsToday;
  final int requestsInPeriod;
  final int requestsOnApproval;
  final double requestsAmount;
  final double requestsApproved;
  final double requestsToPay;
  final double requestsPaid;
  final double requestsRemaining;
  final double moneyTotal;
  final double obligations;
  final double receivables;
  final DateTime? periodStart;

  factory _HomeDashboardData.empty() {
    return const _HomeDashboardData(
      requestsToday: 0,
      requestsInPeriod: 0,
      requestsOnApproval: 0,
      requestsAmount: 0,
      requestsApproved: 0,
      requestsToPay: 0,
      requestsPaid: 0,
      requestsRemaining: 0,
      moneyTotal: 0,
      obligations: 0,
      receivables: 0,
      periodStart: null,
    );
  }
}
