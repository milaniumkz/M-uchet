# API v1

Все защищённые методы: `Authorization: Bearer <token>`. Даты — ISO-8601 UTC, идентификаторы — непрозрачные строки. Токены действуют 12 часов. Страница списков: `?limit=50&after=<последний id>`, максимум 200. Аудит использует числовой sequence вместо id. В некоторых списках последняя страница возвращает непустой cursor: отсутствие следующей страницы устанавливается пустым items.

## Сессии и компании

| Метод | Путь | Тело / результат |
|---|---|---|
| POST | `/v1/auth/register` | `{login,password,name}` → `{id,login,name}`; только при ALLOW_REGISTRATION=true |
| POST | `/v1/auth/login` | `{login,password}` → `{token,expiresAt,user}` |
| GET | `/v1/auth/me` | Пользователь и memberships, без password/hash |
| POST | `/v1/auth/logout` | Отзыв текущей сессии |
| POST | `/v1/auth/password` | `{oldPassword,password}`; отзывает все сессии |
| GET/POST | `/v1/companies` | Список своих компаний / `{name,currency:"KZT"}` → компания |
| GET | `/v1/companies/:companyId/members` | Только владелец |
| PUT | `/v1/companies/:companyId/members/:userId` | `{permissions:["catalog.read",…]}`; только владелец |
| DELETE | `/v1/companies/:companyId/members/:userId` | Удалить участника, кроме владельца |
| GET | `/v1/capabilities` | Реестр ресурсов и допустимых прав |

Саморегистрация игнорирует присланные поля role/permissions/companyId: права можно назначить только отдельной операцией владельца. Участник должен сначала получить собственный userId через регистрацию. Адресный поиск чужих пользователей не открыт.

Далее все пути относительно `/v1/companies/:companyId`.

## Справочники

`GET /resources/:kind`, `GET /resources/:kind/:id`, `POST /resources/:kind`, `PUT /resources/:kind/:id`.

POST: `{data:{name:"Товар"}}` → `{id,data,version:1,createdAt,updatedAt}`. PUT заменяет весь data и требует `{version:1,data:{name:"Новое имя"}}`; конфликт версии → 409. Область компании определяется URL и членством, не клиентским полем. Вместо удаления используйте бизнес-поле inactive; финансовые ссылки сохраняются.

Группы и списки — `src/resources.js`, динамически доступны в `/v1/capabilities`. Права `<group>.read` / `<group>.write`. Данные company_profile не дают права управлять членством.

## Склад, заказы и оплаты

Все POST-команды ниже требуют **уникальный `Idempotency-Key`** длиной до 128 символов. При сетевом повторе сохраняйте тот же ключ и точное тело. Проверка доступа выполняется и для повторного запроса.

1. Создайте записи `nomenklatura` и `warehouses`, получите их id.
2. `POST /inventory/receipts`:

```json
{"productId":"…","warehouseId":"…","quantity":10,"unitCost":15000,"scope":"ACCOUNTING"}
```

Право `inventory.receive`, результат — партия. Приход создаёт дебет inventory / кредит payables. `GET /inventory` — партии (право `inventory.read`). Все партии заказа должны иметь ровно его scope; BOTH не служит запасом для другого scope.

3. `POST /orders`:

```json
{"scope":"ACCOUNTING","items":[{"productId":"…","warehouseId":"…","quantity":4,"unitPrice":20000}]}
```

Право `orders.write`, результат `{id,status:"NEW",scope,items,total}`. Каталожные ссылки проверяются в своей компании. Цена пока задаётся уполномоченным оператором, налоговый/скидочный движок отсутствует. Одинаковый товар в одном складе повторять в заказе нельзя.

4. `POST /orders/:id/reserve` (`orders.fulfill`): NEW → RESERVED, FIFO, вся операция откатывается при нехватке любой позиции.
5. `POST /orders/:id/ship` (`orders.fulfill`): RESERVED → SHIPPED, списывает резерв и остаток, создаёт выручку/дебиторку и COGS/списание inventory; результат содержит revenue/cogs/grossProfit.
6. `POST /orders/:id/payments` (`payments.write`) с `{amount:80000}`: только SHIPPED, без переплаты. Результат `{id,orderId,amount,outstanding}`; полная оплата → CLOSED. Проводка: дебет cash / кредит receivables.
7. `POST /orders/:id/cancel` (`orders.write`): NEW/RESERVED → CANCELLED, освобождает резерв. Отгруженный заказ отменить таким способом нельзя.

`GET /orders`, `GET /orders/:id` — право `orders.read`. Все суммы в одной валюте компании. В текущем этапе оплата отражается на общем счёте cash; выбор банковского/кассового кошелька ещё не реализован.

## Учёт

`POST /accounting/journal` (`accounting.post`, Idempotency-Key):

```json
{"description":"Вклад собственника","scope":"ACCOUNTING","lines":[{"account":"cash","debit":100000},{"account":"capital","credit":100000}]}
```

В строке строго одна положительная сторона, дебет=кредит, минимум две строки, максимум 100. Журнал нельзя менять/удалять произвольным CRUD. Коды счетов — строки до 32 символов, единый отраслевой план счетов ещё не валидируется.

`GET /accounting/journal`, `GET /accounting/trial-balance?scope=ACCOUNTING` (`accounting.read`): список проводок / `{scope,accounts:[{account,debit,credit,balance}]}`. Для scope=BOTH отчёт показывает только записи BOTH; для ACCOUNTING/MANAGEMENT включает также BOTH. Ведомость пока за весь период, без отбора дат/подразделений.

## Файлы и аудит

`POST /files` (`files.write`) — multipart с одним полем файла, максимум 10 MiB. Результат `{id,size}`. `GET /files/:id` (`files.read`) — байты как attachment, не публичный URL. Оригинальное имя — только метаданные, путь выбирает сервер. Удаление и антивирусная обработка пока отсутствуют.

`GET /audit?after=0&limit=50` (`audit.read`) → `{items:[{sequence,company_id,actor_id,action,resource_id,created_at}]}`. Не включает пароли/токены. Это аудит прикладных изменений, не отдельная защищённая от администратора БД система журналирования.
