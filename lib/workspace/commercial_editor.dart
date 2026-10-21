import 'company_access.dart';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';

class CommercialEditor extends StatefulWidget {
  const CommercialEditor({
    super.key,
    required this.api,
    required this.companyId,
    required this.currency,
    required this.projects,
    required this.direction,
    this.projectId,
    this.document,
    this.today,
    this.initialScope = 'ACCOUNTING',
  });
  final BackendClient api;
  final String companyId, currency, direction;
  final String? projectId, today;
  final String initialScope;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? document;
  @override
  State<CommercialEditor> createState() => _CommercialEditorState();
}

class _ServiceInput {
  _ServiceInput({
    this.description = '',
    this.unit = 'услуга',
    this.quantity = '1',
    this.price = '0.00',
  });
  final key = UniqueKey();
  String description, unit, quantity, price;
  Map<String, dynamic> toJson() => {
    'description': description.trim(),
    'unit': unit.trim(),
    'quantity': quantity.trim().replaceAll(',', '.'),
    'unitPrice': parseMoney(price),
  };
}

class _CommercialEditorState extends State<CommercialEditor> {
  late final repository = CommercialRepository(widget.api, widget.companyId);
  final lines = <_ServiceInput>[];
  List<ResourceDto> parties = [], services = [];
  Map<String, dynamic>? preview;
  String? counterpartyId, projectId, error;
  late String kind, date, scope;
  String note = '', vatReason = '', externalNumber = '';
  int vat = 0;
  bool loading = true, busy = false, uncertain = false, refreshDetails = false;
  String vatTreatment = 'IN_COST';
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    final doc = widget.document,
        data = doc == null ? null : jsonObject(doc['data']);
    scope = doc?['scope'] as String? ?? widget.initialScope;
    kind =
        doc?['kind'] as String? ??
        (widget.direction == 'purchases' ? 'PURCHASE_ACT' : 'SALE_INVOICE');
    date =
        doc?['business_date'] as String? ??
        widget.today ??
        DateTime.now().toIso8601String().substring(0, 10);
    projectId = doc == null
        ? (widget.projectId == 'unassigned' ? null : widget.projectId)
        : doc['project_id'] as String?;
    if (data != null) {
      counterpartyId = data['counterpartyId'] as String;
      vat = data['vatBasisPoints'] as int;
      vatTreatment = data['vatTreatment'] as String;
      note = data['note'] as String;
      vatReason = data['vatReason'] as String;
      externalNumber = data['externalNumber'] as String;
      for (final raw in data['items'] as List) {
        final l = jsonObject(raw);
        lines.add(
          _ServiceInput(
            description: l['description'] as String,
            unit: l['unit'] as String,
            quantity: l['quantity'] as String,
            price: ((l['unitPrice'] as num) / 100).toStringAsFixed(2),
          ),
        );
      }
    } else {
      lines.add(_ServiceInput());
    }
    load();
  }

  Future<void> load() async {
    try {
      final catalog = CatalogRepository(widget.api, widget.companyId);
      final results = await Future.wait([
        catalog.listAll(
          widget.direction == 'purchases' ? 'suppliers' : 'clients',
        ),
        catalog.listAll('services'),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        parties = results[0];
        services = results[1];
        loading = false;
      });
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  Map<String, dynamic> payload() {
    if (counterpartyId == null) {
      throw const FormatException('Выберите контрагента.');
    }
    return {
      'kind': kind,
      'counterpartyId': counterpartyId,
      'businessDate': date,
      'projectId': projectId,
      'scope': scope,
      'vatBasisPoints': vat,
      'vatReason': vatReason,
      'vatTreatment': vatTreatment,
      'note': note,
      'externalNumber': externalNumber,
      'items': lines.map((l) => l.toJson()).toList(),
      if (widget.document != null) 'version': widget.document!['version'],
      if (widget.document != null) 'documentId': widget.document!['id'],
      if (refreshDetails) 'refreshIssuer': true,
      if (refreshDetails) 'refreshCounterparty': true,
    };
  }

  Future<void> calculate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await repository.preview(payload());
      if (mounted) {
        setState(() => preview = jsonObject(result['data']));
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      pending ??= repository.save(
        payload(),
        id: widget.document?['id'] as String?,
      );
      final result = await pending!.execute(widget.api);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          uncertain = RetriableCommand.uncertain(e);
          if (!uncertain) {
            pending = null;
          }
          error = uncertain
              ? 'Результат сохранения неизвестен. Повторите сохранение: повторный документ не создастся.'
              : e.message;
        });
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(date),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (value != null) {
      setState(() => date = value.toIso8601String().substring(0, 10));
    }
  }

  Widget field(
    String label,
    String value,
    void Function(String) update, {
    TextInputType? keyboard,
    int? maxLines = 1,
  }) => TextFormField(
    initialValue: value,
    enabled: !busy && !uncertain,
    keyboardType: keyboard,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label),
    onChanged: (v) {
      update(v);
      preview = null;
    },
  );
  Widget lineEditor(_ServiceInput line, int index) => Container(
    key: line.key,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE5E9F2)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Позиция ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (lines.length > 1)
              IconButton(
                tooltip: 'Удалить позицию',
                onPressed: busy || uncertain
                    ? null
                    : () => setState(() => lines.remove(line)),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        field(
          'Наименование услуги',
          line.description,
          (v) => line.description = v,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 120,
              child: field(
                'Количество',
                line.quantity,
                (v) => line.quantity = v,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            SizedBox(
              width: 120,
              child: field('Единица', line.unit, (v) => line.unit = v),
            ),
            SizedBox(
              width: 210,
              child: field(
                'Цена без НДС, ${widget.currency}',
                line.price,
                (v) => line.price = v,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final enabled = !busy && !uncertain,
        old = widget.document == null
            ? null
            : jsonObject(widget.document!['data']);
    final values = [...parties];
    if (counterpartyId != null &&
        !values.any((p) => p.id == counterpartyId) &&
        old != null) {
      values.add(
        ResourceDto(counterpartyId!, jsonObject(old['counterparty']), 1),
      );
    }
    return PopScope(
      canPop: pending == null,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1149, maxHeight: 880),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.document == null
                            ? 'Новый документ'
                            : 'Изменить ${widget.document!['number']}',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      tooltip: 'Закрыть',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (loading || busy) const LinearProgressIndicator(),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.document == null &&
                            widget.direction == 'sales')
                          DropdownButtonFormField<String>(
                            initialValue: kind,
                            decoration: const InputDecoration(
                              labelText: 'Тип документа',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'SALE_INVOICE',
                                child: Text('Счёт на оплату'),
                              ),
                              DropdownMenuItem(
                                value: 'SALE_ACT',
                                child: Text('Акт оказанных услуг'),
                              ),
                            ],
                            onChanged: enabled
                                ? (v) => setState(() => kind = v!)
                                : null,
                          )
                        else
                          Text(
                            documentLabels[kind]!,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: counterpartyId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: widget.direction == 'purchases'
                                ? 'Поставщик'
                                : 'Клиент',
                          ),
                          items: values
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    p.data['name'] as String? ?? p.id,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: enabled
                              ? (v) => setState(() => counterpartyId = v)
                              : null,
                        ),
                        if (parties.isEmpty && !loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Сначала добавьте контрагента в разделе «Контрагенты».',
                            ),
                          ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            SizedBox(
                              width: 280,
                              child: DropdownButtonFormField<String>(
                                initialValue: projectId ?? 'unassigned',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Проект',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'unassigned',
                                    child: Text('Общие операции фирмы'),
                                  ),
                                  ...projectChoices(
                                    widget.projects,
                                    projectId,
                                  ).map(
                                    (p) => DropdownMenuItem(
                                      value: p['id'] as String,
                                      child: Text(p['name'] as String),
                                    ),
                                  ),
                                ],
                                onChanged: enabled
                                    ? (v) => setState(
                                        () => projectId = v == 'unassigned'
                                            ? null
                                            : v,
                                      )
                                    : null,
                              ),
                            ),
                            SizedBox(
                              width: 240,
                              child: TextFormField(
                                key: ValueKey(date),
                                initialValue: date,
                                readOnly: true,
                                onTap: enabled ? chooseDate : null,
                                decoration: const InputDecoration(
                                  labelText: 'Дата документа',
                                  suffixIcon: Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: scope,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Вид учёта',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ACCOUNTING',
                              child: Text('Бухгалтерский учёт'),
                            ),
                            DropdownMenuItem(
                              value: 'MANAGEMENT',
                              child: Text('Управленческий учёт'),
                            ),
                            DropdownMenuItem(
                              value: 'BOTH',
                              child: Text('Оба вида учёта'),
                            ),
                          ],
                          onChanged: enabled
                              ? (v) => setState(() {
                                  scope = v!;
                                  preview = null;
                                })
                              : null,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Товары и услуги',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'В этом документе — услуги. Складские остатки не изменяются.',
                        ),
                        const SizedBox(height: 16),
                        ...lines.asMap().entries.map(
                          (e) => lineEditor(e.value, e.key),
                        ),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            TextButton.icon(
                              onPressed: enabled
                                  ? () => setState(
                                      () => lines.add(_ServiceInput()),
                                    )
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить позицию'),
                            ),
                            if (services.isNotEmpty)
                              PopupMenuButton<ResourceDto>(
                                tooltip: 'Выбрать услугу из справочника',
                                enabled: enabled,
                                itemBuilder: (context) => services
                                    .map(
                                      (s) => PopupMenuItem(
                                        value: s,
                                        child: Text(
                                          s.data['name'] as String? ?? s.id,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onSelected: (s) => setState(
                                  () => lines.add(
                                    _ServiceInput(
                                      description:
                                          s.data['name'] as String? ?? '',
                                      unit:
                                          s.data['unit'] as String? ?? 'услуга',
                                      price:
                                          ((s.data['priceMinor'] as num? ?? 0) /
                                                  100)
                                              .toStringAsFixed(2),
                                    ),
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Из справочника услуг'),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<int>(
                          initialValue: vat,
                          decoration: const InputDecoration(
                            labelText: 'НДС по документу',
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Без НДС')),
                            DropdownMenuItem(
                              value: 1600,
                              child: Text('16% — основная ставка 2026'),
                            ),
                          ],
                          onChanged: enabled
                              ? (v) => setState(() => vat = v!)
                              : null,
                        ),
                        if (vat == 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: field(
                              'Основание без НДС (если применимо)',
                              vatReason,
                              (v) => vatReason = v,
                            ),
                          ),
                        if (widget.direction == 'purchases' && vat > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: DropdownButtonFormField<String>(
                              initialValue: vatTreatment,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Учёт входящего НДС',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'IN_COST',
                                  child: Text('Включить в стоимость'),
                                ),
                                DropdownMenuItem(
                                  value: 'PENDING',
                                  child: Text(
                                    'НДС к проверке, без заявления вычета',
                                  ),
                                ),
                              ],
                              onChanged: enabled
                                  ? (v) => setState(() => vatTreatment = v!)
                                  : null,
                            ),
                          ),
                        const SizedBox(height: 20),
                        field(
                          'Номер документа контрагента',
                          externalNumber,
                          (v) => externalNumber = v,
                        ),
                        const SizedBox(height: 20),
                        field(
                          'Комментарий',
                          note,
                          (v) => note = v,
                          maxLines: 3,
                        ),
                        if (widget.document != null)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Обновить реквизиты из справочников',
                            ),
                            subtitle: const Text(
                              'Без этого сохраняется снимок реквизитов исходного документа',
                            ),
                            value: refreshDetails,
                            onChanged: enabled
                                ? (v) => setState(() => refreshDetails = v!)
                                : null,
                          ),
                        if (preview != null)
                          Container(
                            margin: const EdgeInsets.only(top: 20),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFEEFE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Итого к оплате: ${moneyText(preview!['total'] as num, widget.currency)}',
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Без НДС: ${moneyText(preview!['net'] as num, widget.currency)} · НДС: ${moneyText(preview!['vat'] as num, widget.currency)}',
                                ),
                              ],
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: enabled ? calculate : null,
                      child: const Text('Рассчитать итог'),
                    ),
                    FilledButton(
                      onPressed: busy || loading ? null : save,
                      child: Text(
                        uncertain
                            ? 'Повторить сохранение'
                            : widget.document == null
                            ? 'Сохранить черновик'
                            : 'Сохранить изменения',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
