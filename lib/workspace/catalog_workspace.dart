import 'company_access.dart';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import '../backend/rest/retriable_command.dart';
import 'commercial_repository.dart';

class CatalogWorkspace extends StatefulWidget {
  const CatalogWorkspace(
      {super.key,
      required this.api,
      required this.companyId,
      required this.mode});
  final BackendClient api;
  final String companyId, mode;
  @override
  State<CatalogWorkspace> createState() => _CatalogWorkspaceState();
}

class _CatalogWorkspaceState extends State<CatalogWorkspace> {
  late String kind = widget.mode == 'counterparties' ? 'clients' : 'services';
  final labels = {
    'clients': 'Клиенты',
    'suppliers': 'Поставщики',
    'services': 'Услуги',
    'nomenklatura': 'Товары',
    'warehouses': 'Склады'
  };
  List<ResourceDto> items = [];
  bool loading = true;
  String? error, cursor;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    setState(() => loading = true);
    try {
      final result = jsonObject(await widget.api.request('GET', [
        'v1',
        'companies',
        widget.companyId,
        'resources',
        kind
      ], query: {
        'limit': '50',
        if (more && cursor != null) 'after': cursor!
      }));
      if (!mounted) {
        return;
      }
      setState(() {
        final next =
            (result['items'] as List).map(ResourceDto.fromJson).toList();
        items = more ? [...items, ...next] : next;
        cursor = (result['items'] as List).length == 50 ? items.last.id : null;
        error = null;
      });
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> edit([ResourceDto? previous]) async {
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ResourceEditor(
            api: widget.api,
            companyId: widget.companyId,
            kind: kind,
            title: labels[kind]!,
            previous: previous));
    if (saved == true && mounted) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(33), children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 20,
            runSpacing: 16,
            children: [
              Text(
                  widget.mode == 'counterparties'
                      ? 'Контрагенты'
                      : 'Товары и услуги',
                  style: const TextStyle(
                      fontSize: 29, fontWeight: FontWeight.bold)),
              FilledButton.icon(
                  onPressed: loading||!hasCompanyPermission(context,'catalog.write') ? null : () => edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'))
            ]),
        const SizedBox(height: 24),
        Wrap(
            spacing: 12,
            runSpacing: 12,
            children: (widget.mode == 'counterparties'
                    ? ['clients', 'suppliers']
                    : ['services', 'nomenklatura', 'warehouses'])
                .map((key) => ChoiceChip(
                    label: Text(labels[key]!),
                    selected: kind == key,
                    onSelected: loading
                        ? null
                        : (_) {
                            setState(() {
                              kind = key;
                              items = [];
                              cursor = null;
                            });
                            load();
                          }))
                .toList()),
        const SizedBox(height: 24),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (items.isEmpty && !loading)
          const Padding(
              padding: EdgeInsets.all(28),
              child: Text('Записей пока нет. Добавьте первую запись.')),
        ...items.map((item) => Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                title: Text(item.data['name'] as String? ?? 'Без названия',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                subtitle: Text([
                  item.data['identifier'],
                  item.data['phone'],
                  item.data['email']
                ].whereType<String>().where((v) => v.isNotEmpty).join(' · ')),
                trailing: IconButton(
                    tooltip: hasCompanyPermission(context,'catalog.write')?'Редактировать запись':'Открыть запись',
                    onPressed: () => edit(item),
                    icon: const Icon(Icons.edit_outlined))))),
        if (cursor != null)
          TextButton(
              onPressed: loading ? null : () => load(more: true),
              child: const Text('Показать ещё')),
        TextButton.icon(
            onPressed: loading ? null : () => load(),
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'))
      ]);
}

class _ResourceEditor extends StatefulWidget {
  const _ResourceEditor(
      {required this.api,
      required this.companyId,
      required this.kind,
      required this.title,
      this.previous});
  final BackendClient api;
  final String companyId, kind, title;
  final ResourceDto? previous;
  @override
  State<_ResourceEditor> createState() => _ResourceEditorState();
}

class _ResourceEditorState extends State<_ResourceEditor> {
  late final data = <String, dynamic>{...?widget.previous?.data};
  bool busy = false, uncertain = false;
  String? error;
  String price = '0.00';
  RetriableCommand? pending;
  @override
  void initState() {
    super.initState();
    if (data['priceMinor'] is int) {
      price = ((data['priceMinor'] as int) / 100).toStringAsFixed(2);
    }
  }

  Widget field(String key, String label, {TextInputType? keyboard}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          initialValue: data[key] as String? ?? '',
          enabled: !busy && !uncertain && hasCompanyPermission(context,'catalog.write'),
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => data[key] = v.trim()));
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if ((data['name'] as String? ?? '').trim().isEmpty) {
        throw const FormatException('Введите название.');
      }
      if (['services', 'nomenklatura'].contains(widget.kind)) {
        data['priceMinor'] = parseMoney(price);
      }
      if (['clients', 'suppliers'].contains(widget.kind)) {
        final id = data['identifier'] as String? ?? '';
        if (id.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(id)) {
          throw const FormatException('БИН / ИИН должен содержать 12 цифр.');
        }
      }
      pending ??= RetriableCommand(widget.previous == null ? 'POST' : 'PUT', [
        'v1',
        'companies',
        widget.companyId,
        'resources',
        widget.kind,
        if (widget.previous != null) widget.previous!.id
      ], {
        'data': data,
        if (widget.previous != null) 'version': widget.previous!.version
      });
      await pending!.execute(widget.api);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() {
          uncertain = RetriableCommand.uncertain(e);
          if (!uncertain) {
            pending = null;
          }
          error = uncertain
              ? 'Результат сохранения неизвестен. Повторите сохранение.'
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

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.previous == null
              ? 'Добавить: ${widget.title}'
              : hasCompanyPermission(context,'catalog.write')?'Изменить запись':'Карточка записи'),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    if (busy) const LinearProgressIndicator(),
                    field('name', 'Название'),
                    if (['clients', 'suppliers'].contains(widget.kind)) ...[
                      field('identifier', 'БИН / ИИН',
                          keyboard: TextInputType.number),
                      field('phone', 'Телефон', keyboard: TextInputType.phone),
                      field('email', 'Электронная почта',
                          keyboard: TextInputType.emailAddress),
                      field('address', 'Адрес'),
                      field('iban', 'Банковский счёт IBAN'),
                      field('bic', 'БИК банка')
                    ],
                    if (['services', 'nomenklatura'].contains(widget.kind)) ...[
                      field('unit', 'Единица измерения'),
                      TextFormField(
                          initialValue: price,
                          enabled: !busy && !uncertain && hasCompanyPermission(context,'catalog.write'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Цена без НДС'),
                          onChanged: (v) => price = v)
                    ],
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(error!,
                              style: const TextStyle(color: Colors.red)))
                  ]))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: busy||!hasCompanyPermission(context,'catalog.write') ? null : save,
                child: Text(uncertain ? 'Повторить сохранение' : 'Сохранить'))
          ]);
}
