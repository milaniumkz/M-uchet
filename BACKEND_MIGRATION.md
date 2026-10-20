# Подключение отдельного backend

## Текущее состояние

Копия содержит frontend и предметную логику. Старые серверные функции, инфраструктура и подключения исключены. Она не реализует новый backend и не готова к production.

`lib/backend/firebase/firebase_config.dart` сохраняет совместимый `initFirebase()`, но сразу выдаёт явную ошибку без инициализации Firebase. `TokenCall.call()` в `lib/backend/api_requests/api_calls.dart` также блокируется до любого HTTP-запроса. Native Firebase service-config файлы и Android Google Services Gradle step удалены.

## Основные точки миграции

1. Данные: `lib/backend/schema/` и `lib/backend/backend.dart` описывают текущие сущности и запросы. Сохраните предметные поля, но замените Firestore DocumentReference/Query/Timestamp и streams на DTO, API-клиент и выбранный механизм обновлений.
2. Авторизация: `lib/auth/firebase_auth/`, `auth_util.dart`, `firebase_user_provider.dart` и `TokenCall.call()` требуют нового протокола login/register/session/roles. Не включайте старые Firebase методы как временную production-заглушку.
3. Хранилище: `lib/backend/firebase_storage/` и upload helpers нужно связать с новым API загрузки и правилами доступа.
4. Cloud Functions и Firebase-зависимости встречаются непосредственно в виджетах/сервисах. Их нужно перенести за интерфейсы и заменить вызовами своего backend. Замены одного startup-файла недостаточно.
5. Навигация и роли: `lib/flutter_flow/nav/nav.dart`, `lib/main.dart`, `lib/utils/` используют контекст пользователя/компании. Сопоставьте его с новой серверной моделью прав.
6. Тесты: сохранённые unit/widget/integration тесты являются материалом для адаптации. Некоторые используют Firebase mocks. Добавьте тесты нового API, изоляции компаний, ролей, повторных запросов и ошибок сети до снятия блокировки запуска.

## Что не перенесено

Прежние Cloud Functions, Firestore/Storage rules и indexes, administrative/bootstrap/migration scripts, production hosting/deployment config и workflows. Если для нового сервера понадобится восстановить бизнес-правило из старой серверной реализации, анализировать его следует отдельно без копирования старых подключений и данных.

Новые URL, схемы авторизации, секреты, база данных и deployment не настроены. Репозиторий не получает persistent credentials или доступ к прежней инфраструктуре. Техническое имя Dart-пакета пока прежнее, чтобы не сломать существующие импорты.

## До запуска

Реализуйте контракты и репозитории данных, замените Firebase-зависимости, удалите ненужные SDK, обновите native settings, настройте новую конфигурацию вне Git, затем замените блокирующие заглушки. Проверьте lint, unit/widget/integration tests и целевые сборки. Не включайте GitHub Actions/деплой до отдельной настройки нового проекта.
