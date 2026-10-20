# Независимый M-учёт API: текущий проверенный этап

Node.js **24.x**, Fastify 5 (модульный JavaScript), **PostgreSQL 17**. SQLite больше не используется. Требования пользователя: [полное задание](../docs/requirements/2026-10-20.md). Это техническое ядро, **не завершённая бухгалтерская система Казахстана**. Новый Flutter REST workspace подключён, исходные экраны ещё переносятся; юридические расчёты и официальные формы не утверждены.

## Запуск из корня репозитория

```bash
make bootstrap
make up
make seed-dev
make test
make test-e2e
make backup-test
```

`make bootstrap` сохраняет существующий .env либо создаёт приватные настройки с новым случайным паролем локальной БД; устанавливает зависимости по lockfile. `make up` запускает настоящий PostgreSQL в Docker Compose, применяет SQL-миграции и поднимает API на 127.0.0.1:8080. Данные PostgreSQL хранятся в именованном Docker volume, файлы — в DATA_DIR. `make down` останавливает только API, запущенный task runner, и сохраняет данные. Команды не вызывают docker compose down -v и не удаляют пользовательские данные.

`make seed-dev` работает только при APP_ENV=development; создаёт явно синтетического владельца и компанию. Случайный тестовый пароль сохраняется с правами 0600 в игнорируемом `.runtime/synthetic-login.json`, не выводится в консоль и не попадает в Git. Повторный seed сохраняет существующие реквизиты. Это не production bootstrap. Публичная регистрация по умолчанию выключена.

`GET /health` проверяет запрос БД и возвращает status=ok/schemaVersion=6. `GET /openapi.json` описывает зарегистрированные маршруты; экспорт: `cd server && npm run openapi`. Схемы тел OpenAPI пока неполны; детальное описание исходного API: [docs/API.md](docs/API.md), расширения перечислены ниже. Не генерируйте production-клиент из неполных схем.

## Реальные возможности

- Авторизация с scrypt, bearer-сессии на 12 часов, хеш токена в БД, отзыв сессии и всех сессий при смене пароля. Членство и явные права на каждую организацию. Владелец одной организации не получает доступ к другой.
- JSON-справочники по allowlist с optimistic locking; приватные файлы до 10 MiB. Финансовые регистры и security-коллекции не открываются произвольным CRUD.
- FIFO-партии, приход, резерв, отмена, отгрузка, себестоимость, оплаты заказов; перемещения и списания свободного остатка. Отрицательные складские остатки запрещены.
- Кошельки: начальный капитал, доход/расход, переводы, история; входящие/исходящие долги, частичные погашения и история. Кассовые смены с фиксацией пересчёта. Это внутренний учёт, не фискальная ККМ.
- Журнал двойной записи, точные NUMERIC-строки в PostgreSQL, deferred-проверка баланса на уровне БД, редактирование проведённых записей с историей версий и связанное сторно ручной записи. Сторно складских и денежных операций отдельными бизнес-командами ещё не реализовано.
- Контуры ACCOUNTING/MANAGEMENT/BOTH, оборотная ведомость, внутренний P&L с датами. Отметки закрытия/открытия периода; по последнему указанию владельца они не блокируют редактирование. Бизнес-дата по часовому поясу компании (по умолчанию Asia/Almaty), хранится отдельно от UTC timestamp.
- Идемпотентность финансовых команд, блокировка строки компании в PostgreSQL, атомарные проводки/остатки/аудит/сохранение ответа. Проверка конкурентных запросов из двух API instances.
- Очередь внутренних команд устройств LOCK/UNLOCK/SYNC и подтверждение оператором. Это не подключение к реальному устройству: device authentication и агент ещё нужны.

Деньги в API — **целые minor units**, в БД — NUMERIC(20,0), суммы строк журнала — отдельные NUMERIC-поля. 100 = 1.00 KZT. Количество — целые базовые единицы товара. Дробные единицы требуют явного масштаба и клиентского преобразования, которые ещё не реализованы. Лимит отдельных величин 10^12, проверяются safe integer и переполнения. Код счетов пока внутренний, а не утверждённый типовой план счетов Казахстана.

## Дополнительные маршруты

Префикс `/v1/companies/:companyId`. Изменяющие бизнес-команды требуют Idempotency-Key.

| Метод / путь | Тело | Право |
|---|---|---|
| POST /wallets | name, scope | wallets.write |
| GET /wallets; GET /wallets/:id/entries | limit, after | wallets.read |
| POST /wallets/:id/transactions | type=CAPITAL/INCOME/EXPENSE, amount, description | wallets.transact |
| POST /wallet-transfers | sourceWalletId, targetWalletId, amount | wallets.transact |
| POST /inventory/movements | productId, sourceWarehouseId, targetWarehouseId, quantity, scope | inventory.move |
| POST /inventory/writeoffs | productId, warehouseId, quantity, reason, scope | inventory.writeoff |
| GET /inventory/movements | limit, after | inventory.read |
| POST /debts | type=AR/AP, counterpartyId, amount, scope, dueDate? | debts.write |
| GET /debts; GET /debts/:id/payments | limit, after | debts.read |
| POST /debts/:id/settlements | walletId, amount | debts.settle |
| POST /shifts | walletId | shifts.write |
| POST /shifts/:id/close | countedAmount | shifts.write |
| GET /shifts | limit, after | shifts.read |
| POST /devices/:id/commands | command=LOCK/UNLOCK/SYNC | devices.command |
| GET /devices/:id/commands | limit, after | devices.read |
| POST /devices/:id/commands/:commandId/acknowledge | status=SUCCEEDED/FAILED | devices.command |
| POST /accounting/journal/:id/reverse | reason | accounting.post |
| POST /periods/:month/close; /reopen | reason | periods.close / periods.reopen |
| GET /reports/profit-loss | scope, from, to (YYYY-MM-DD) | reports.read |

Долги отдельного реестра создаются как начальная задолженность через opening_balances; они не дублируют долги заказов. До единого реестра документов нельзя вводить одну задолженность одновременно через оба маршрута. Оплаты заказов пока используют общий счёт cash, не выбранный кошелёк. Наличие кадрового JSON-справочника не означает реализации зарплатного расчёта.

## Проверки и восстановление

`make test` проверяет 26 серверных сценариев на PostgreSQL, `make test-e2e` — реальный HTTP с перезапуском, `make backup-test` — реальный pg_dump/pg_restore в отдельную временную БД и восстановление приватного файла. Тесты используют отдельные случайные test_* схемы и синтетические данные. Backup-test ограничен локальным Compose PostgreSQL. API health не заменяет эти проверки.

`cd server && npm run backup` создаёт закрытый development pg_dump в .runtime/backups. Файлы uploads копируются отдельно при остановленном API. Backup-test проверяет именно такую согласованную остановленную копию, не заявляет online-consistency двух независимых хранилищ. Для production нужны отдельное расписание, шифрование, удалённое хранение, политика сроков хранения и повторный restore-test на целевом сервере.

`make lint-server` проверяет синтаксис Node. Общий `make lint` дополнительно требует Flutter analyze. `make verify-no-firebase` намеренно завершается с ошибкой, пока старые активные зависимости остаются. `make verify` запускает обязательные проверки и не считается успешным при недоступном Flutter.

## Ограничения и следующий шаг

Доступ к источникам восстановлен: 12 официальных текстов получены, исследование редакций и применимости продолжается. Flutter 3.35.6/Dart 3.9.2 установлен, 312 исходных тестов и web release build прошли. Дополнительно прошли 4 теста нового REST-клиента и один настоящий Dart→HTTP→PostgreSQL сценарий. Android-сборка выполняется после установки полного JDK; успешного результата пока нет. Анализатор: 0 ошибок, 840 warnings и 2152 info в исходном проекте. [Карта экранов](../docs/architecture/screen-map.md) и [checkpoint](../docs/CHECKPOINT.md) фиксируют незавершённый объём. Не включать старые Firebase auth/bootstrap как обходной путь.

Нет проверенных налоговых/зарплатных формул, официальных XML/XSD, ЭСФ/СНТ/ККМ, полной первички и нумерации, ОС/НМА, валютных переоценок, возвратов, partial shipments и всех пользовательских отчётов. Bearer-сессии ещё требуют замены web-механизма на защищённые cookie/CSRF и ротации refresh для мобильного контура. Отсутствие этих критических возможностей запрещает объявлять весь проект готовым или разворачивать его в production.

## Редактирование

Последнее указание владельца и реализация: [изменение требований](../docs/requirements/2026-10-20-editing.md). `PUT /wallets/:id` принимает name/balance, `PUT /accounting/journal/:id` — description/lines/scope/businessDate/reason, `PUT /orders/:id` — items/scope/businessDate. Все эти команды требуют Idempotency-Key. Права: wallets.write (и wallets.transact для баланса), accounting.edit и orders.edit соответственно. История: GET /accounting/journal/:id/history и GET /orders/:id/history. CLOSED не блокирует редактирование. Необходимые остатки и баланс проводок всё равно проверяются.


## Динамические проекты

Все маршруты ниже внутри `/v1/companies/:companyId`; права и компания проверяются сервером.

- `GET /projects`, `POST /projects {name,description?}` — projects.read / projects.write.
- `PUT /projects/:id {version,name?,description?,archived?}` — версия обязательна, история сохраняется; projects.write.
- `GET /reports/projects?projectId=...&from=YYYY-MM-DD&to=YYYY-MM-DD&scope=ACCOUNTING` — reports.read. Без projectId все проекты плюс общие операции; `unassigned` означает общие операции. `total` всегда общий итог фирмы за выбранный период/контур, `items` учитывает фильтр проекта.
- `projectId` (или null для общих операций) поддерживается в создании/правке сделок, ручных проводках и денежных доходах/расходах. Отгрузка, себестоимость и оплата наследуют проект сделки. Перенос оплаченной сделки пересчитывает обе аналитики, сохраняя итог фирмы.
- Налоговый контур фирмы общий. Автоматического распределения общих расходов нет. Архивирование не удаляет проводки и не запрещает исправление прежних операций.

Новый интерфейс запускается как основной main.dart или явно: `scripts/flutter.sh run --target lib/main_server.dart --dart-define=API_ORIGIN=http://127.0.0.1:8080` (для отдельного web dev origin задайте точный CORS_ORIGIN на API). Предпочтительно собрать `make build-workspace-web` и обслуживать web через WEB_ROOT на самом API: same-origin и локальный CanvasKit, без внешнего CDN. Полная миграция всех функций не завершена.
