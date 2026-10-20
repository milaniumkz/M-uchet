class PermissionDefinition {
  const PermissionDefinition({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;
}

class PermissionGroupDefinition {
  const PermissionGroupDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.permissions,
  });

  final String id;
  final String title;
  final String description;
  final List<PermissionDefinition> permissions;
}

class PermissionSectionDefinition {
  const PermissionSectionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.groups,
  });

  final String id;
  final String title;
  final String description;
  final List<PermissionGroupDefinition> groups;
}

const List<PermissionSectionDefinition> kPermissionSections =
    <PermissionSectionDefinition>[
  PermissionSectionDefinition(
    id: 'money',
    title: 'Деньги компании',
    description:
        'Разделы из блока денег компании: счета, учет, транзакции и бюджеты.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'scheta',
        title: 'Счета',
        description: 'Основной экран счетов и действия по ним.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'scheta.manage',
            label: 'Раздел "Счета"',
            description:
                'Открытие страницы счетов и управление списком счетов.',
          ),
          PermissionDefinition(
            key: 'scheta.view',
            label: 'Просмотр счетов',
            description: 'Системный флаг просмотра раздела счетов.',
          ),
          PermissionDefinition(
            key: 'scheta.add',
            label: 'Кнопка "Добавить счет"',
            description: 'Создание новых счетов.',
          ),
          PermissionDefinition(
            key: 'scheta.edit',
            label: 'Кнопка "Редактировать счет"',
            description: 'Изменение данных существующего счета.',
          ),
          PermissionDefinition(
            key: 'scheta.deactivate',
            label: 'Кнопка "Отключить счет"',
            description: 'Деактивация счетов без удаления.',
          ),
          PermissionDefinition(
            key: 'scheta.delete',
            label: 'Кнопка "Удалить счет"',
            description: 'Удаление счетов.',
          ),
          PermissionDefinition(
            key: 'scheta.withdrawal',
            label: 'Кнопка "Изъятие"',
            description: 'Операции изъятия средств.',
          ),
        ],
      ),
      PermissionGroupDefinition(
        id: 'scheta_blocks',
        title: 'Счета: блоки на странице',
        description: 'Какие блоки показывать внутри страницы счетов.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'scheta.blocks.total',
            label: 'Блок "Итого"',
            description: 'Общий сводный блок по счетам.',
          ),
          PermissionDefinition(
            key: 'scheta.blocks.bank',
            label: 'Блок "Банковские счета"',
            description: 'Разворачиваемый блок банковских счетов.',
          ),
          PermissionDefinition(
            key: 'scheta.blocks.cash',
            label: 'Блок "Наличные"',
            description: 'Разворачиваемый блок наличных денег.',
          ),
          PermissionDefinition(
            key: 'scheta.blocks.owner',
            label: 'Блок "Средства владельца"',
            description: 'Разворачиваемый блок средств владельца.',
          ),
          PermissionDefinition(
            key: 'scheta.blocks.list',
            label: 'Блок "Список счетов"',
            description: 'Таблица или список счетов.',
          ),
          PermissionDefinition(
            key: 'scheta.blocks.transactions',
            label: 'Блок "Транзакции"',
            description: 'Показ связанных транзакций на странице счетов.',
          ),
          PermissionDefinition(
            key: 'scheta.blocks.filters',
            label: 'Блок "Фильтры"',
            description: 'Фильтры и быстрый поиск по счетам.',
          ),
        ],
      ),
      PermissionGroupDefinition(
        id: 'uchet',
        title: 'Финансовый учет компании',
        description: 'Экран учета и его блоки.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'uchet.view',
            label: 'Раздел "Финансовый учет компании"',
            description: 'Открытие страницы учета компании.',
          ),
          PermissionDefinition(
            key: 'uchet.blocks.summary',
            label: 'Блок "Сводка"',
            description: 'Итоговая сводка по учету.',
          ),
          PermissionDefinition(
            key: 'uchet.blocks.compare',
            label: 'Блок "Сравнение"',
            description: 'Сравнительные показатели на странице учета.',
          ),
          PermissionDefinition(
            key: 'uchet.blocks.chart',
            label: 'Блок "График"',
            description: 'Графики и диаграммы учета.',
          ),
          PermissionDefinition(
            key: 'uchet.blocks.insights',
            label: 'Блок "Выводы"',
            description: 'Подсказки и выводы по финансовому учету.',
          ),
        ],
      ),
      PermissionGroupDefinition(
        id: 'transactions',
        title: 'Транзакции',
        description: 'Журнал транзакций и действия с ними.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'tranzaction.view',
            label: 'Раздел "Транзакции"',
            description: 'Открытие списка и журнала транзакций.',
          ),
          PermissionDefinition(
            key: 'tranzaction.add',
            label: 'Кнопка "Добавить транзакцию"',
            description: 'Создание новых транзакций.',
          ),
          PermissionDefinition(
            key: 'tranzaction.edit',
            label: 'Кнопка "Редактировать транзакцию"',
            description: 'Изменение транзакций.',
          ),
          PermissionDefinition(
            key: 'tranzaction.delete',
            label: 'Кнопка "Удалить транзакцию"',
            description: 'Удаление транзакций.',
          ),
          PermissionDefinition(
            key: 'tranzaction.filter',
            label: 'Фильтры транзакций',
            description: 'Использование фильтров и отбора.',
          ),
          PermissionDefinition(
            key: 'tranzaction.export',
            label: 'Кнопка "Экспорт"',
            description: 'Экспорт транзакций из журнала.',
          ),
        ],
      ),
      PermissionGroupDefinition(
        id: 'money',
        title: 'Обязательства и бюджет',
        description: 'Разделы финансовых обязательств и категорий расходов.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'money.obligations',
            label: 'Раздел "Обязательства"',
            description: 'Доступ к обязательствам компании.',
          ),
          PermissionDefinition(
            key: 'money.expense_categories',
            label: 'Раздел "Бюджет / Категории расходов"',
            description: 'Категории расходов и бюджет компании.',
          ),
          PermissionDefinition(
            key: 'money.view',
            label: 'Системный флаг раздела "Деньги"',
            description: 'Технический флаг видимости раздела денег.',
          ),
          PermissionDefinition(
            key: 'money.company',
            label: 'Раздел "Деньги компании"',
            description: 'Просмотр агрегированного блока денег компании.',
          ),
          PermissionDefinition(
            key: 'money.company_expenses',
            label: 'Раздел "Расходы компании"',
            description: 'Просмотр расходов компании.',
          ),
        ],
      ),
      PermissionGroupDefinition(
        id: 'funding_requests',
        title: 'Заявки на деньги',
        description:
            'Подача, согласование, утверждение и оплата заявок на финансирование.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'funding_requests.view',
            label: 'Раздел "Заявки на деньги"',
            description:
                'Пользователь может открыть раздел и видеть реестр заявок.',
          ),
          PermissionDefinition(
            key: 'funding_requests.create',
            label: 'Подающий заявку',
            description:
                'Пользователь может создавать и подавать заявки на деньги.',
          ),
          PermissionDefinition(
            key: 'funding_requests.responsible_sign',
            label: 'Ответственный по заявке',
            description:
                'Пользователь может подписывать заявку как ответственное лицо.',
          ),
          PermissionDefinition(
            key: 'funding_requests.approve',
            label: 'Согласующий заявку',
            description: 'Пользователь может согласовывать заявки на деньги.',
          ),
          PermissionDefinition(
            key: 'funding_requests.final_approve',
            label: 'Утверждающий заявку',
            description:
                'Пользователь может финально утверждать заявку: "Одобрено Давлатов С.Р.".',
          ),
          PermissionDefinition(
            key: 'funding_requests.pay',
            label: 'Оплата заявки',
            description:
                'Пользователь может создавать платеж по заявке со статусом "К оплате".',
          ),
        ],
      ),
    ],
  ),
  PermissionSectionDefinition(
    id: 'goods',
    title: 'Товары и склад',
    description: 'Складские разделы, номенклатура, услуги и контрагенты.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'warehouse',
        title: 'Склады',
        description: 'Складская структура и перемещения.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'warehouse.view',
            label: 'Раздел "Склады"',
            description: 'Открытие страницы складов.',
          ),
          PermissionDefinition(
            key: 'warehouse.add',
            label: 'Кнопка "Добавить склад"',
            description: 'Создание новых складов.',
          ),
          PermissionDefinition(
            key: 'warehouse.move',
            label: 'Кнопка "Перемещение"',
            description: 'Оформление перемещений между складами.',
          ),
          PermissionDefinition(
            key: 'warehouse.blocks.list',
            label: 'Блок "Список складов"',
            description: 'Список или дерево складов.',
          ),
          PermissionDefinition(
            key: 'warehouse.blocks.movements',
            label: 'Блок "Перемещения"',
            description: 'Журнал перемещений внутри страницы складов.',
          ),
          PermissionDefinition(
            key: 'warehouse.blocks.totals',
            label: 'Блок "Итоги"',
            description: 'Сводные остатки по складам.',
          ),
        ],
      ),
      PermissionGroupDefinition(
        id: 'nomenclature',
        title: 'Товары / номенклатура',
        description: 'Карточки товаров, список и фильтры.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'nomenclature.view',
            label: 'Раздел "Номенклатура"',
            description: 'Открытие списка товаров.',
          ),
          PermissionDefinition(
            key: 'nomenclature.add',
            label: 'Кнопка "Добавить товар"',
            description: 'Создание товара.',
          ),
          PermissionDefinition(
            key: 'nomenclature.edit',
            label: 'Кнопка "Редактировать товар"',
            description: 'Изменение карточки товара.',
          ),
          PermissionDefinition(
            key: 'nomenclature.delete',
            label: 'Кнопка "Удалить товар"',
            description: 'Удаление товара.',
          ),
          PermissionDefinition(
            key: 'nomenclature.blocks.list',
            label: 'Блок "Список товаров"',
            description: 'Показ списка товаров.',
          ),
          PermissionDefinition(
            key: 'nomenclature.blocks.filters',
            label: 'Блок "Фильтры"',
            description: 'Фильтры номенклатуры.',
          ),
        ],
      ),
      PermissionGroupDefinition(
        id: 'services',
        title: 'Услуги и контрагенты',
        description: 'Услуги, поставщики и контрагенты.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'services.view',
            label: 'Раздел "Услуги"',
            description: 'Открытие списка услуг.',
          ),
          PermissionDefinition(
            key: 'services.add',
            label: 'Кнопка "Добавить услугу"',
            description: 'Создание услуги.',
          ),
          PermissionDefinition(
            key: 'services.edit',
            label: 'Кнопка "Редактировать услугу"',
            description: 'Изменение услуги.',
          ),
          PermissionDefinition(
            key: 'services.delete',
            label: 'Кнопка "Удалить услугу"',
            description: 'Удаление услуги.',
          ),
          PermissionDefinition(
            key: 'suppliers.view',
            label: 'Раздел "Контрагенты"',
            description: 'Открытие списка контрагентов.',
          ),
          PermissionDefinition(
            key: 'suppliers.add',
            label: 'Кнопка "Добавить контрагента"',
            description: 'Создание контрагента.',
          ),
          PermissionDefinition(
            key: 'suppliers.edit',
            label: 'Кнопка "Редактировать контрагента"',
            description: 'Изменение контрагента.',
          ),
          PermissionDefinition(
            key: 'suppliers.delete',
            label: 'Кнопка "Удалить контрагента"',
            description: 'Удаление контрагента.',
          ),
        ],
      ),
    ],
  ),
  PermissionSectionDefinition(
    id: 'sales',
    title: 'Продажи',
    description: 'Магазины, клиенты, касса, контроль продаж и показатели.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'sales_core',
        title: 'Основные разделы продаж',
        description: 'Видимость и ключевые разделы продаж.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'sales.view',
            label: 'Раздел "Продажи"',
            description: 'Общий доступ к страницам продаж.',
          ),
          PermissionDefinition(
            key: 'sales.shops',
            label: 'Раздел "Магазины"',
            description: 'Список магазинов.',
          ),
          PermissionDefinition(
            key: 'sales.cashiers',
            label: 'Раздел "Кассиры"',
            description: 'Список кассиров.',
          ),
          PermissionDefinition(
            key: 'sales.clients',
            label: 'Раздел "Клиенты"',
            description: 'Список клиентов.',
          ),
          PermissionDefinition(
            key: 'sales.controls',
            label: 'Раздел "Контроль продаж"',
            description: 'Панель контроля продаж.',
          ),
          PermissionDefinition(
            key: 'sales.cash',
            label: 'Раздел "Режим кассы"',
            description: 'Рабочий экран кассы.',
          ),
          PermissionDefinition(
            key: 'sales.reports',
            label: 'Раздел "Отчеты кассиров"',
            description: 'Отчеты и статистика кассиров.',
          ),
        ],
      ),
      PermissionGroupDefinition(
        id: 'sales_actions',
        title: 'Кнопки и функции продаж',
        description: 'Функции, которые можно отдельно включать или скрывать.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'sales.add',
            label: 'Кнопка "Добавить" в продажах',
            description: 'Создание сущностей внутри раздела продаж.',
          ),
          PermissionDefinition(
            key: 'sales.edit',
            label: 'Кнопка "Редактировать" в продажах',
            description: 'Редактирование данных внутри продаж.',
          ),
          PermissionDefinition(
            key: 'sales.delete',
            label: 'Кнопка "Удалить" в продажах',
            description: 'Удаление данных внутри продаж.',
          ),
          PermissionDefinition(
            key: 'sales.income',
            label: 'Раздел "Доходы"',
            description: 'Экран доходов продаж.',
          ),
          PermissionDefinition(
            key: 'sales.expenses',
            label: 'Раздел "Расходы"',
            description: 'Экран расходов продаж.',
          ),
          PermissionDefinition(
            key: 'sales.profit.shop',
            label: 'Раздел "Прибыль магазинов"',
            description: 'Прибыль по магазинам.',
          ),
          PermissionDefinition(
            key: 'sales.profit.cashier',
            label: 'Раздел "Прибыль кассиров"',
            description: 'Прибыль по кассирам.',
          ),
          PermissionDefinition(
            key: 'sales.abc',
            label: 'Раздел "ABC анализ продаж"',
            description: 'ABC-анализ внутри продаж.',
          ),
        ],
      ),
    ],
  ),
  PermissionSectionDefinition(
    id: 'analytics',
    title: 'Аналитика',
    description: 'Аналитические экраны и специальные отчеты.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'analytics',
        title: 'Отчеты и аналитика',
        description: 'Видимость аналитических разделов.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'analytics.view',
            label: 'Системный флаг раздела "Аналитика"',
            description: 'Технический флаг доступа к аналитике.',
          ),
          PermissionDefinition(
            key: 'analytics.sales',
            label: 'Отчет продаж',
            description: 'Аналитический отчет по продажам.',
          ),
          PermissionDefinition(
            key: 'analytics.fin',
            label: 'Финансовый отчет',
            description: 'Финансовая аналитика компании.',
          ),
          PermissionDefinition(
            key: 'analytics.margin',
            label: 'Маржа',
            description: 'Маржинальность и анализ прибыли.',
          ),
          PermissionDefinition(
            key: 'analytics.invest',
            label: 'Инвест-отчет',
            description: 'Отчет по инвестициям.',
          ),
          PermissionDefinition(
            key: 'analytics.models',
            label: 'Финансовые модели',
            description: 'Финансовые модели и сценарии.',
          ),
          PermissionDefinition(
            key: 'analytics.abc',
            label: 'ABC анализ',
            description: 'ABC анализ в блоке аналитики.',
          ),
          PermissionDefinition(
            key: 'analytics.portfolio',
            label: 'Портфель продуктов',
            description: 'Анализ товарного портфеля.',
          ),
        ],
      ),
    ],
  ),
  PermissionSectionDefinition(
    id: 'audit',
    title: 'Аудит 1С',
    description: 'Аудит бухгалтерского учета, риски и KPI по ошибкам.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'audit_1c',
        title: 'Модуль аудита',
        description: 'Доступ к экрану аудита и результатам проверок.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'audit.view',
            label: 'Раздел "Аудит бухгалтерского учета"',
            description: 'Открытие модуля аудита 1С и просмотр результатов.',
          ),
        ],
      ),
    ],
  ),
  PermissionSectionDefinition(
    id: 'company',
    title: 'Компания',
    description: 'Оргструктура, HR и управление сотрудниками.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'company',
        title: 'Структура и сотрудники',
        description: 'Разделы управления компанией.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'company.org',
            label: 'Раздел "Оргструктура"',
            description: 'Структура бизнеса и оргструктура компании.',
          ),
          PermissionDefinition(
            key: 'company.hr',
            label: 'Раздел "HR контроль"',
            description: 'Работа с сотрудниками и HR-процессами.',
          ),
          PermissionDefinition(
            key: 'company.users',
            label: 'Управление пользователями компании',
            description: 'Права на раздел пользователей компании.',
          ),
          PermissionDefinition(
            key: 'company.roles',
            label: 'Управление ролями компании',
            description: 'Права на раздел ролей компании.',
          ),
        ],
      ),
    ],
  ),
  PermissionSectionDefinition(
    id: 'security',
    title: 'Безопасность',
    description: 'Блокировки, восстановление и удаление данных.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'security',
        title: 'Разделы безопасности',
        description: 'Настройки и опасные действия безопасности.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'security.view',
            label: 'Системный флаг раздела "Безопасность"',
            description: 'Технический флаг раздела безопасности.',
          ),
          PermissionDefinition(
            key: 'security.block',
            label: 'Раздел "Блокировки"',
            description: 'Управление блокировками и доступом.',
          ),
          PermissionDefinition(
            key: 'security.restore',
            label: 'Раздел "Восстановление"',
            description: 'Восстановление данных.',
          ),
          PermissionDefinition(
            key: 'security.delete',
            label: 'Раздел "Удаление данных"',
            description: 'Удаление данных и опасные операции.',
          ),
        ],
      ),
    ],
  ),
  PermissionSectionDefinition(
    id: 'personal',
    title: 'Личные деньги',
    description: 'Личные деньги пользователя и его личные расходы.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'personal_money',
        title: 'Личный финансовый блок',
        description: 'Личные разделы пользователя.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'money.my',
            label: 'Раздел "Мои деньги"',
            description: 'Личные деньги пользователя.',
          ),
          PermissionDefinition(
            key: 'money.my_expenses',
            label: 'Раздел "Мои расходы"',
            description: 'Личные расходы пользователя.',
          ),
        ],
      ),
    ],
  ),
  PermissionSectionDefinition(
    id: 'settings',
    title: 'Настройки',
    description: 'Справочники, реквизиты, калькулятор и роли.',
    groups: <PermissionGroupDefinition>[
      PermissionGroupDefinition(
        id: 'settings',
        title: 'Разделы настроек',
        description: 'Страницы и функции блока настроек.',
        permissions: <PermissionDefinition>[
          PermissionDefinition(
            key: 'settings.view',
            label: 'Системный флаг раздела "Настройки"',
            description: 'Технический флаг блока настроек.',
          ),
          PermissionDefinition(
            key: 'settings.currency',
            label: 'Раздел "Валюта"',
            description: 'Настройка валют.',
          ),
          PermissionDefinition(
            key: 'settings.taxes',
            label: 'Раздел "Налоги"',
            description: 'Настройка налогов.',
          ),
          PermissionDefinition(
            key: 'settings.calculator',
            label: 'Раздел "Калькулятор"',
            description: 'Встроенный калькулятор.',
          ),
          PermissionDefinition(
            key: 'settings.rekviziti',
            label: 'Раздел "Реквизиты"',
            description: 'Реквизиты компании.',
          ),
          PermissionDefinition(
            key: 'settings.roles',
            label: 'Раздел "Роли и доступы"',
            description: 'Настройка ролей и прав пользователей.',
          ),
          PermissionDefinition(
            key: 'settings.users',
            label: 'Управление пользователями',
            description: 'Настройка пользователей в разделе ролей.',
          ),
          PermissionDefinition(
            key: 'settings.tariffs',
            label: 'Управление тарифами',
            description: 'Настройка тарифов и ограничений.',
          ),
        ],
      ),
    ],
  ),
];

final Map<String, PermissionDefinition> kPermissionByKey =
    <String, PermissionDefinition>{
  for (final section in kPermissionSections)
    for (final group in section.groups)
      for (final permission in group.permissions) permission.key: permission,
};

String permissionLabel(String key) {
  final definition = kPermissionByKey[key];
  if (definition != null) return definition.label;
  return key;
}

String permissionDescription(String key) {
  final definition = kPermissionByKey[key];
  if (definition != null) return definition.description;
  return 'Неизвестное право: $key';
}
