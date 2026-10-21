import 'company_access.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import 'commercial_repository.dart';
import 'commercial_editor.dart';
import 'commercial_detail.dart';

class CommercialWorkspace extends StatefulWidget {
  const CommercialWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.direction,
    required this.projects,
    required this.onChanged,
    this.projectId,
    this.from,
    this.to,
    this.initialScope = 'ACCOUNTING',
  });
  final BackendClient api;
  final String companyId, currency, direction;
  final String? projectId, from, to;
  final String initialScope;
  final List<Map<String, dynamic>> projects;
  final Future<void> Function() onChanged;
  @override
  State<CommercialWorkspace> createState() => _CommercialWorkspaceState();
}

class _CommercialWorkspaceState extends State<CommercialWorkspace> {
  late final repository = CommercialRepository(widget.api, widget.companyId);
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error, cursor, kind;
  String query = '';
  String documentStatus = '';
  late String scope = widget.initialScope;
  String? today;
  Map<String, dynamic>? summary;
  Timer? debounce;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    final version = ++generation;
    setState(() => loading = true);
    try {
      final result = await repository.list(
        direction: widget.direction,
        kind: kind,
        status: documentStatus.isEmpty ? null : documentStatus,
        scope: scope,
        projectId: widget.projectId,
        after: more ? cursor : null,
        query: query,
        from: widget.from,
        to: widget.to,
      );
      if (!mounted || version != generation) {
        return;
      }
      setState(() {
        final next = (result['items'] as List).map(jsonObject).toList();
        items = more ? [...items, ...next] : next;
        cursor = result['nextCursor'] as String?;
        today = result['businessDate'] as String?;
        summary = result['summary'] == null
            ? null
            : jsonObject(result['summary']);
        error = null;
      });
    } on BackendException catch (e) {
      if (mounted && version == generation) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted && version == generation) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> changed() async {
    if (mounted) {
      await load();
    }
    await widget.onChanged();
  }

  Future<void> open(Map<String, dynamic> doc) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommercialDetail(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        document: doc,
        projects: widget.projects,
        onChanged: changed,
      ),
    );
  }

  Future<void> create() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CommercialEditor(
        api: widget.api,
        companyId: widget.companyId,
        currency: widget.currency,
        projects: widget.projects,
        direction: widget.direction,
        today: today,
        initialScope: scope,
        projectId: widget.projectId,
      ),
    );
    if (result != null && mounted) {
      await changed();
      if (mounted) {
        await open(result);
      }
    }
  }

  String countText(num value, String one, String few, String many) {
    final n = value.toInt(), last = n % 10, rest = n % 100;
    return '$n ${rest >= 11 && rest <= 14
        ? many
        : last == 1
        ? one
        : last >= 2 && last <= 4
        ? few
        : many}';
  }

  Widget summaryCard(String label, String value, double available) => Container(
    width: available >= 900 ? (available - 52) / 3 : available,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE5E9F2)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEEFE),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.north_east,
                size: 20,
                color: Color(0xFF5654E8),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF626E84), fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF171B35),
          ),
        ),
      ],
    ),
  );
  Widget status(Map<String, dynamic> doc) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: doc['status'] == 'POSTED'
          ? const Color(0xFFE9F8F0)
          : const Color(0xFFEFEEFE),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      documentStatuses[doc['status']]!,
      style: const TextStyle(fontSize: 12),
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      padding: EdgeInsets.all(constraints.maxWidth < 600 ? 20 : 33),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 24,
          runSpacing: 20,
          children: [
            Text(
              widget.direction == 'sales' ? 'Документы продаж' : 'Покупки',
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
            ),
            FilledButton.icon(
              onPressed:
                  loading || !hasCompanyPermission(context, 'documents.write')
                  ? null
                  : create,
              icon: const Icon(Icons.add),
              label: const Text('Новый документ'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.direction == 'sales'
              ? 'Счета и акты услуг в одном месте.'
              : 'Поступления товаров и услуг, расчёты с поставщиками.',
          style: const TextStyle(color: Color(0xFF626E84)),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 280,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: scope,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'ACCOUNTING',
                    child: Text('Бухгалтерский учёт'),
                  ),
                  DropdownMenuItem(
                    value: 'MANAGEMENT',
                    child: Text('Управленческий учёт'),
                  ),
                ],
                onChanged: loading
                    ? null
                    : (value) {
                        setState(() => scope = value!);
                        load();
                      },
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (widget.direction == 'sales')
          Wrap(
            spacing: 12,
            children: [
              ChoiceChip(
                label: const Text('Все документы'),
                selected: kind == null,
                onSelected: loading
                    ? null
                    : (_) {
                        setState(() => kind = null);
                        load();
                      },
              ),
              ChoiceChip(
                label: const Text('Счета'),
                selected: kind == 'SALE_INVOICE',
                onSelected: loading
                    ? null
                    : (_) {
                        setState(() => kind = 'SALE_INVOICE');
                        load();
                      },
              ),
              ChoiceChip(
                label: const Text('Акты'),
                selected: kind == 'SALE_ACT',
                onSelected: loading
                    ? null
                    : (_) {
                        setState(() => kind = 'SALE_ACT');
                        load();
                      },
              ),
            ],
          ),
        if (widget.direction == 'purchases')
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final option in const {
                '': 'Все поступления',
                'PURCHASE_GOODS': 'Товары',
                'PURCHASE_ACT': 'Услуги',
              }.entries)
                ChoiceChip(
                  label: Text(option.value),
                  selected: (kind ?? '') == option.key,
                  onSelected: loading
                      ? null
                      : (_) {
                          setState(
                            () => kind = option.key.isEmpty ? null : option.key,
                          );
                          load();
                        },
                ),
            ],
          ),
        const SizedBox(height: 24),
        if (summary != null) ...[
          LayoutBuilder(
            builder: (context, size) => Wrap(
              spacing: 26,
              runSpacing: 16,
              children: [
                summaryCard(
                  'За выбранный период',
                  countText(
                    summary!['count'] as num,
                    'документ',
                    'документа',
                    'документов',
                  ),
                  size.maxWidth,
                ),
                summaryCard(
                  'Ожидают оплаты',
                  moneyText(summary!['outstanding'] as num, widget.currency),
                  size.maxWidth,
                ),
                summaryCard(
                  'Нужно завершить',
                  countText(
                    summary!['drafts'] as num,
                    'черновик',
                    'черновика',
                    'черновиков',
                  ),
                  size.maxWidth,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
        TextField(
          decoration: const InputDecoration(
            labelText: 'Поиск по номеру или контрагенту',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            query = value;
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 350), () => load());
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 280,
            child: DropdownButton<String>(
              key: const ValueKey('commercial-status-filter'),
              isExpanded: true,
              value: documentStatus,
              hint: const Text('Статус документа'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Все статусы')),
                for (final entry in documentStatuses.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() => documentStatus = value!);
                      load();
                    },
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (items.isEmpty && !loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Документов пока нет. Создайте первый документ.'),
          ),
        if (items.isNotEmpty && constraints.maxWidth >= 900)
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, tableBox) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tableBox.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('Документ')),
                      DataColumn(label: Text('Контрагент')),
                      DataColumn(label: Text('Дата')),
                      DataColumn(label: Text('Сумма')),
                      DataColumn(label: Text('Статус')),
                    ],
                    rows: items
                        .map(
                          (doc) => DataRow(
                            onSelectChanged: (_) => open(doc),
                            cells: [
                              DataCell(
                                Text(
                                  '${documentLabels[doc['kind']]}\n${doc['number']}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  jsonObject(
                                        jsonObject(doc['data'])['counterparty'],
                                      )['name']
                                      as String,
                                ),
                              ),
                              DataCell(Text(doc['business_date'] as String)),
                              DataCell(
                                Text(
                                  moneyText(
                                    jsonObject(doc['data'])['total'] as num,
                                    widget.currency,
                                  ),
                                ),
                              ),
                              DataCell(status(doc)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          )
        else
          ...items.map(
            (doc) => Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                onTap: () => open(doc),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${documentLabels[doc['kind']]} ${doc['number']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        jsonObject(
                              jsonObject(doc['data'])['counterparty'],
                            )['name']
                            as String,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        children: [
                          Text(
                            moneyText(
                              jsonObject(doc['data'])['total'] as num,
                              widget.currency,
                            ),
                          ),
                          status(doc),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(doc['business_date'] as String),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (cursor != null)
          TextButton(
            onPressed: loading ? null : () => load(more: true),
            child: const Text('Показать ещё'),
          ),
        TextButton.icon(
          onPressed: loading ? null : () => load(),
          icon: const Icon(Icons.refresh),
          label: const Text('Обновить'),
        ),
      ],
    ),
  );
}
