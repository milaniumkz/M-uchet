import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend/rest/api_client.dart';

const helpGuides = <({String title, String summary, String section, List<String> steps})>[
  (
    title: 'Продать товары',
    summary: 'Резерв → отгрузка → оплата',
    section: 'goods',
    steps: [
      'Добавьте товары и склад, затем внесите поступление с количеством базовых единиц и себестоимостью.',
      'Создайте товарную продажу: укажите клиента, проект, дату, количество, цену без НДС и применимую ставку. Проверьте сумму перед сохранением.',
      'Зарезервируйте и отгрузите товар. Внесите оплату на денежный счёт; платёж до даты продажи станет авансом. Ошибки исправляйте в продаже или записи оплаты. Печатная накладная пока предназначена только для внутреннего учёта.',
    ],
  ),

  (
    title: 'Начать работу',
    summary: 'Компания, проекты и первые документы',
    section: 'projects',
    steps: [
      'Заполните реквизиты фирмы и выберите применимый налоговый режим в параметрах компании.',
      'Создайте свои проекты. Общие расходы фирмы оставляйте без проекта; сводка покажет их отдельно.',
      'Добавьте контрагентов, услуги, товары, склады и денежные счета. Операции вносите с фактической датой.',
    ],
  ),
  (
    title: 'Получить деньги',
    summary: 'Счёт → оплата → акт',
    section: 'sales',
    steps: [
      'Создайте счёт на оплату: выберите клиента, проект, услуги, количество и цену. Проверьте НДС и реквизиты, затем выставьте счёт.',
      'Внесите оплату на нужный денежный счёт. До проведения акта она учитывается как аванс.',
      'Создайте акт из счёта и проведите его после оказания услуг. Аванс зачтётся без повторного дохода. Исправляйте основание через кнопку «Изменить»; история сохранится.',
    ],
  ),
  (
    title: 'Оплатить покупку',
    summary: 'Документ поставщика → платёж',
    section: 'purchases',
    steps: [
      'Создайте поступление услуг с поставщиком и проектом. Проверьте содержание, дату, стоимость и основание НДС.',
      'Проведите документ и внесите оплату с нужного денежного счёта.',
      'Если оплата уже записана вручную, при загрузке выписки выберите «Уже учтённая операция». Сопоставление не создаст повторный расход.',
    ],
  ),
  (
    title: 'Подготовить отчёт',
    summary: 'Проверка остатков, периода и проектов',
    section: 'reports',
    steps: [
      'Проверьте даты и основания документов, оплаты, банковские выписки и остатки денежных счетов.',
      'Выберите период и проект в финансовых отчётах. Сравните прибыль проектов с общей сводкой фирмы и общими операциями.',
      'Откройте оборотную ведомость и перейдите от суммы к проводке и документу. CSV финансового отчёта не является налоговой декларацией. Официальные формы и подача пока не подключены.',
    ],
  ),
  (
    title: 'Закрыть или исправить смену',
    summary: 'Ожидаемый остаток и фактический пересчёт',
    section: 'cash',
    steps: [
      'Выберите денежный счёт в кассе и откройте смену.',
      'При закрытии введите фактическую сумму. Система сохранит ожидаемый остаток на момент закрытия и разницу.',
      'Для ошибки пересчёта нажмите «Исправить пересчёт» и укажите причину. Эта правка не создаёт автоматический приход или расход.',
    ],
  ),
  (
    title: 'Предоставить доступ',
    summary: 'Приглашения и права сотрудников',
    section: 'access',
    steps: [
      'Владелец открывает раздел «Доступ» и выбирает разрешения сотрудника.',
      'Создайте приглашение и передайте одноразовый код лично. Автоматическая рассылка email не подключена.',
      'Сотрудник принимает приглашение на экране входа. Права можно изменить или отозвать; повторное принятие старого кода их не восстановит.',
    ],
  ),
];

class HelpWorkspace extends StatefulWidget {
  const HelpWorkspace({
    super.key,
    required this.api,
    required this.companyName,
    required this.canOpen,
    required this.onOpen,
  });
  final BackendClient api;
  final String companyName;
  final bool Function(String) canOpen;
  final void Function(String) onOpen;
  @override
  State<HelpWorkspace> createState() => _HelpWorkspaceState();
}

class _HelpWorkspaceState extends State<HelpWorkspace> {
  String query = '', message = '';
  bool copying = false;
  Future<void> diagnostic() async {
    setState(() => copying = true);
    try {
      final health = jsonObject(
        await widget.api.request('GET', ['health'], authenticated: false),
      );
      await Clipboard.setData(
        ClipboardData(
          text:
              'М-учёт\nФирма: ${widget.companyName}\nПроверка сервера: ${health['status']}\nВерсия схемы: ${health['schemaVersion']}\nОпишите действие, дату операции и текст ошибки. Не прикладывайте пароль или код приглашения.',
        ),
      );
      if (mounted) {
        setState(
          () => message =
              'Сведения скопированы. Передайте их владельцу системы вместе с описанием проблемы.',
        );
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(() => message = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => copying = false);
      }
    }
  }

  Future<void> guide(int index) async {
    final item = helpGuides[index];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final step in item.steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text('${step.$1 + 1}. ${step.$2}'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть инструкцию'),
          ),
          if (widget.canOpen(item.section))
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onOpen(item.section);
              },
              child: const Text('Перейти к действиям'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final available = helpGuides.indexed
          .where(
            (g) => '${g.$2.title} ${g.$2.summary} ${g.$2.steps.join(' ')}'
                .toLowerCase()
                .contains(query.toLowerCase()),
          )
          .toList();
      final width = size.maxWidth - 64;
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const Text(
            'Поможем разобраться',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Короткие объяснения и пошаговые действия без сложных терминов.',
          ),
          const SizedBox(height: 30),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              labelText: 'Что хотите сделать?',
              hintText: 'Например: выставить счёт или загрузить выписку',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 32),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Инструкция не найдена. Попробуйте «счёт», «выписка», «проект» или «смена».',
              ),
            ),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: available
                .map(
                  (g) => SizedBox(
                    width: width > 720 ? (width - 20) / 2 : width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.$2.title,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(g.$2.summary),
                            const SizedBox(height: 22),
                            TextButton(
                              onPressed: () => guide(g.$1),
                              child: const Text('Открыть инструкцию →'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          Card(
            color: const Color(0xFFEFEEFE),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Нужна помощь владельца системы?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Скопируйте сведения о проверке сервера и добавьте описание проблемы. Пароли и коды приглашений передавать не нужно.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: copying ? null : diagnostic,
                    child: Text(
                      copying
                          ? 'Проверяем сервер…'
                          : 'Скопировать сведения для обращения',
                    ),
                  ),
                  if (message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(message),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
