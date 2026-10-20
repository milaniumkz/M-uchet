# UchetSD

Flutter/FlutterFlow приложение учета компаний с Firebase Hosting, Firestore, Storage и Cloud Functions.

## Структура

- `lib/` — приложение Flutter, экраны, сервисы и кастомные виджеты.
- `firebase/` — Firebase Hosting, Firestore rules/indexes, Storage rules, Cloud Functions.
- `firebase/functions/` — backend функции Node.js 20.
- `test/`, `integration_test/` — проверки.
- `android/`, `ios/`, `macos/`, `web/` — платформенные проекты.

## Локальный запуск

Требования:

- Flutter `3.35.6`
- Dart `3.9.2`
- Node.js `20`
- Firebase CLI

Команды:

```bash
flutter pub get
flutter test
flutter build web --release --no-wasm-dry-run
```

Cloud Functions:

```bash
cd firebase/functions
npm ci
npm run lint
```

Локальные переменные описаны в `.env.example`. Реальные `.env`, service account JSON, ключи подписи и приватные сертификаты не коммитить.

## Firebase

Production проект: `uchet-9a732`.

Основные URL:

- Приложение: https://uchet-9a732.web.app
- Админский hosting site: https://uchet-admin-9a732.web.app

Ручной deploy с локальной машины:

```bash
flutter build web --release --no-wasm-dry-run
rm -rf firebase/build/web
mkdir -p firebase/build
cp -R build/web firebase/build/web
firebase deploy --only hosting --config firebase/firebase.json --project uchet-9a732
```

Полный deploy Firebase:

```bash
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes,storage --config firebase/firebase.json --project uchet-9a732
```

## GitHub Actions

Подготовлены workflow:

- `CI` — запускается на pull request и push в `main`: Flutter tests/build и Functions lint.
- `Deploy Firebase` — после push в `main` деплоит hosting, также доступен ручной запуск с выбором target.
- `Firebase Ops` — ручные операции: статус проекта, список hosting channels, последние Functions logs.

Для deploy нужен GitHub secret:

- `FIREBASE_SERVICE_ACCOUNT_UCHET_9A732` — JSON service account с минимальными правами на Firebase Hosting/Functions/Firestore rules/indexes/Storage deploy.

Production deploy защищен через GitHub Environment `production`. Включите required reviewers в настройках репозитория, если нужно ручное подтверждение.

## Codex Cloud

1. Откройте GitHub репозиторий проекта в Codex Cloud.
2. Используйте ветки для задач, не работайте напрямую в `main`.
3. Для обычной разработки используйте тестовый Firebase проект или отдельную тестовую конфигурацию, не production данные клиентов.
4. После pull request проверьте GitHub Actions.
5. После merge в `main` deploy запускается автоматически; ручной deploy доступен в Actions -> `Deploy Firebase`.

## Данные и резервные копии

Рабочие данные находятся в Firebase Firestore и Storage проекта `uchet-9a732`; они не хранятся в Git.

Перед изменениями правил, функций или миграций базы:

```bash
firebase firestore:export gs://<backup-bucket>/<date-prefix> --project uchet-9a732
```

Пользовательские файлы Storage сохраняются отдельно в Firebase Storage. Не удаляйте buckets и production коллекции без отдельного согласования.

## Откат

- Hosting: Firebase Console -> Hosting -> нужный site -> Release history -> Roll back.
- GitHub: Actions -> `Deploy Firebase` -> ручной запуск для проверенного коммита/ветки.
- Functions: деплоить предыдущий совместимый коммит. Старую базу поверх новых пользовательских данных автоматически не восстанавливать.

## Синхронизация локальной копии

```bash
git fetch origin
git checkout main
git pull --ff-only
```
