import 'dart:async';
import 'package:flutter/material.dart';
import '../backend/rest/api_client.dart';

const searchKindLabels = {
  'PROJECT': 'Проект',
  'DEBT': 'Начальный долг',
  'STOCK_COUNT': 'Инвентаризация',
  'SALE_INVOICE': 'Счёт на оплату',
  'SALE_ACT': 'Акт реализации',
  'PURCHASE_ACT': 'Поступление услуг',
  'PURCHASE_RETURN': 'Возврат поставщику',
  'PURCHASE_GOODS': 'Поступление товаров',
  'GOODS': 'Товарная продажа',
  'clients': 'Клиент',
  'suppliers': 'Поставщик',
  'services': 'Услуга',
  'nomenklatura': 'Товар',
  'warehouses': 'Склад',
  'EMPLOYEE': 'Сотрудник',
  'ASSET': 'Основное средство',
};

class CompanySearchDialog extends StatefulWidget {
  const CompanySearchDialog({
    super.key,
    required this.api,
    required this.companyId,
  });
  final BackendClient api;
  final String companyId;
  @override
  State<CompanySearchDialog> createState() => _CompanySearchDialogState();
}

class _CompanySearchDialogState extends State<CompanySearchDialog> {
  final query = TextEditingController();
  Timer? debounce;
  int generation = 0;
  bool busy = false, hasMore = false, searched = false;
  String? error;
  List<Map<String, dynamic>> items = [];
  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  void changed(String value) {
    debounce?.cancel();
    generation++;
    setState(() {
      error = null;
      items = [];
      searched = false;
      busy = value.trim().length >= 2;
      hasMore = false;
    });
    if (value.trim().length >= 2) {
      final current = generation;
      debounce = Timer(
        const Duration(milliseconds: 350),
        () => search(current, value.trim()),
      );
    }
  }

  Future<void> search(int current, String value) async {
    try {
      final result = jsonObject(
        await widget.api.request(
          'GET',
          ['v1', 'companies', widget.companyId, 'search'],
          query: {'q': value, 'limit': '20'},
        ),
      );
      if (mounted && current == generation) {
        setState(() {
          items = (result['items'] as List).map(jsonObject).toList();
          hasMore = result['hasMore'] == true;
          searched = true;
        });
      }
    } on BackendException catch (e) {
      if (mounted && current == generation) {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted && current == generation) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Поиск по фирме'),
    content: SizedBox(
      width: 760,
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: query,
            autofocus: true,
            maxLength: 160,
            onChanged: changed,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              changed(value);
              debounce?.cancel();
              if (value.trim().length >= 2) {
                search(generation, value.trim());
              }
            },
            decoration: InputDecoration(
              labelText: 'Документы, люди и товары',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить поиск',
                      onPressed: () {
                        query.clear();
                        changed('');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const Text(
            'Вся фирма, независимо от выбранного проекта. Показываются только доступные вам записи.',
          ),
          const SizedBox(height: 12),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (!busy && query.text.trim().length < 2)
            const Text('Введите не меньше двух символов.'),
          if (!busy && searched && items.isEmpty)
            const Text('Ничего не найдено.'),
          if (hasMore)
            const Text(
              'Показаны первые20 результатов. Уточните название или номер.',
            ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item['title'] as String),
                  subtitle: Text(
                    '${searchKindLabels[item['kind']] ?? item['kind']} · ${item['detail'] ?? ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
    ],
  );
}
