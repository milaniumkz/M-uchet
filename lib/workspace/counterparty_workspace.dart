import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import 'commercial_repository.dart';
import 'commercial_detail.dart';

class CounterpartyWorkspace extends StatefulWidget {
  const CounterpartyWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.kind,
    required this.party,
    required this.currency,
    required this.projects,
    required this.onChanged,
  });
  final BackendClient api;
  final String companyId, kind, currency;
  final ResourceDto party;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  @override
  State<CounterpartyWorkspace> createState() => _CounterpartyWorkspaceState();
}

class _CounterpartyWorkspaceState extends State<CounterpartyWorkspace> {
  String? projectId, error, statementCursor, documentCursor;
  String scope = 'ACCOUNTING';
  DateTimeRange? period;
  bool busy = false;
  List<Map<String, dynamic>> accounts = [], movements = [], documents = [];
  int documentCount = 0;
  CommercialRepository get repo =>
      CommercialRepository(widget.api, widget.companyId);
  String date(DateTime value) => value.toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({
    bool moreMovements = false,
    bool moreDocuments = false,
  }) async {
    setState(() => busy = true);
    try {
      final statement = jsonObject(
        await widget.api.request(
          'GET',
          [
            'v1',
            'companies',
            widget.companyId,
            'counterparties',
            widget.kind,
            widget.party.id,
            'service-statement',
          ],
          query: {
            'limit': '50',
            'scope': scope,
            if (projectId != null) 'projectId': projectId!,
            if (period != null) 'from': date(period!.start),
            if (period != null) 'to': date(period!.end),
            if (moreMovements && statementCursor != null)
              'after': statementCursor!,
          },
        ),
      );
      final docs = await repo.list(
        direction: widget.kind == 'clients' ? 'sales' : 'purchases',
        counterpartyId: widget.party.id,
        scope: scope,
        projectId: projectId,
        from: period == null ? null : date(period!.start),
        to: period == null ? null : date(period!.end),
        after: moreDocuments ? documentCursor : null,
      );
      if (mounted) {
        setState(() {
          accounts = (statement['accounts'] as List).map(jsonObject).toList();
          final rows = (statement['items'] as List).map(jsonObject).toList(),
              nextDocs = (docs['items'] as List).map(jsonObject).toList();
          if (!moreDocuments) {
            movements = moreMovements ? [...movements, ...rows] : rows;
            statementCursor = statement['nextCursor'] as String?;
          }
          if (!moreMovements) {
            documents = moreDocuments ? [...documents, ...nextDocs] : nextDocs;
            documentCursor = docs['nextCursor'] as String?;
          }
          documentCount = jsonObject(docs['summary'])['count'] as int;
          error = null;
        });
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> pickPeriod() async {
    final chosen = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: period,
      helpText: 'Период расчётов',
    );
    if (chosen != null && mounted) {
      setState(() => period = chosen);
      await load();
    }
  }

  Future<void> openDocument(String id) async {
    try {
      final doc = await repo.get(id);
      if (!mounted) {
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CommercialDetail(
            api: widget.api,
            companyId: widget.companyId,
            currency: widget.currency,
            document: doc,
            projects: widget.projects,
            onChanged: widget.onChanged,
          ),
        ),
      );
      if (mounted) {
        await load();
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    }
  }

  String label(String key) =>
      const {
        'receivables': 'Долг покупателя',
        'customer_advances': 'Авансы покупателя',
        'payables': 'Долг поставщику',
        'supplier_advances': 'Авансы поставщику',
      }[key] ??
      key;
  num natural(Map<String, dynamic> account, String field) =>
      ['payables', 'customer_advances'].contains(account['account'])
      ? -(account[field] as num)
      : account[field] as num;
  String projectName(String? id) => id == null
      ? 'Общие операции фирмы'
      : widget.projects.where((p) => p['id'] == id).firstOrNull?['name']
                as String? ??
            'Проект';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.party.data['name'] as String? ?? 'Контрагент'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.kind == 'clients' ? 'Клиент' : 'Поставщик',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        SelectableText(
          [
            widget.party.data['identifier'],
            widget.party.data['phone'],
            widget.party.data['email'],
            widget.party.data['address'],
          ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
        ),
        const SizedBox(height: 24),
        const Text(
          'Расчёты по услугам',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Счета и акты услуг, оплаты и авансы. Начальные долги, товары и приобретение основных средств в эту сводку не входят. Изменения исходных документов пересчитывают расчёты.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: projectId ?? 'all',
                decoration: const InputDecoration(labelText: 'Проект'),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('Все проекты'),
                  ),
                  const DropdownMenuItem(
                    value: 'unassigned',
                    child: Text('Общие операции фирмы'),
                  ),
                  ...widget.projects.map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['name'] as String),
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        setState(() => projectId = v == 'all' ? null : v);
                        load();
                      },
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'ACCOUNTING',
                  label: Text('Бухгалтерский'),
                ),
                ButtonSegment(
                  value: 'MANAGEMENT',
                  label: Text('Управленческий'),
                ),
              ],
              selected: {scope},
              onSelectionChanged: busy
                  ? null
                  : (v) {
                      setState(() => scope = v.single);
                      load();
                    },
            ),
            OutlinedButton(
              onPressed: busy ? null : pickPeriod,
              child: Text(
                period == null
                    ? 'За всё время'
                    : '${date(period!.start)} — ${date(period!.end)}',
              ),
            ),
            if (period != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        setState(() => period = null);
                        load();
                      },
                child: const Text('Сбросить период'),
              ),
            IconButton(
              tooltip: 'Обновить расчёты',
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: accounts
              .map(
                (a) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: 270,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label(a['account'] as String)),
                          const SizedBox(height: 12),
                          Text(
                            moneyText(natural(a, 'closing'), widget.currency),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'На начало: ${moneyText(natural(a, 'opening'), widget.currency)}',
                          ),
                          Text(
                            'Дебет за период: ${moneyText(a['debit'] as num, widget.currency)}',
                          ),
                          Text(
                            'Кредит за период: ${moneyText(a['credit'] as num, widget.currency)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        const Text(
          'Движения и основания',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (movements.isEmpty && !busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Движений за выбранный период нет.'),
          ),
        ...movements.map(
          (m) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['description'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${m['business_date']} · ${projectName(m['project_id'] as String?)}',
                  ),
                  const SizedBox(height: 8),
                  ...(m['lines'] as List)
                      .map(jsonObject)
                      .map(
                        (l) => Text(
                          '${label(l['account'] as String)} · Дт ${moneyText(l['debit'] as num, widget.currency)} · Кт ${moneyText(l['credit'] as num, widget.currency)}',
                        ),
                      ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => openDocument(m['document_id'] as String),
                    child: const Text('Открыть документ-основание'),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (statementCursor != null)
          TextButton(
            onPressed: busy ? null : () => load(moreMovements: true),
            child: const Text('Ещё движения'),
          ),
        const SizedBox(height: 28),
        Text(
          'Документы · $documentCount',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Text('Документы за выбранный период, проект и вид учёта.'),
        ...documents.map(
          (d) => Card(
            child: ListTile(
              title: Text('${documentLabels[d['kind']]} № ${d['number']}'),
              subtitle: Text(
                '${d['business_date']} · ${documentStatuses[d['status']]} · ${moneyText(jsonObject(d['data'])['total'] as num, widget.currency)}',
              ),
              onTap: busy ? null : () => openDocument(d['id'] as String),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
        if (documentCursor != null)
          TextButton(
            onPressed: busy ? null : () => load(moreDocuments: true),
            child: const Text('Ещё документы'),
          ),
      ],
    ),
  );
}
