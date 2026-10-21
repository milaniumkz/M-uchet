.PHONY: bootstrap up down migrate seed-dev test test-e2e lint lint-server build-web build-android backup-test verify-no-firebase audit verify
bootstrap:
	node scripts/bootstrap.mjs
	cd server && npm ci --cache ../.runtime/npm-cache --no-fund
bootstrap-flutter:
	./scripts/setup_flutter.sh
up:
	docker compose up -d --wait db
	$(MAKE) migrate
	node --env-file=.env scripts/control.mjs up
down:
	node --env-file=.env scripts/control.mjs down
migrate:
	cd server && node --env-file=../.env src/migrate.js
seed-dev:
	cd server && node --env-file=../.env src/seed.js
test:
	cd server && APP_ENV=test node --env-file=../.env --test test/api.test.js test/bank-csv.test.js test/payroll-calculation.test.js test/profit.test.js test/debt-migration.test.js test/settlement-planner.test.js test/purchase-stock.test.js
test-e2e:
	cd server && APP_ENV=test node --env-file=../.env --test test/http.test.js
test-client-e2e:
	cd server && APP_ENV=test node --env-file=../.env scripts/client-e2e.mjs
lint-server:
	node scripts/lint.mjs
lint: lint-server
	./scripts/flutter.sh analyze
build-web:
	./scripts/flutter.sh build web --release --no-wasm-dry-run
build-android:
	./scripts/flutter.sh build apk --debug
backup-test:
	cd server && APP_ENV=test node --env-file=../.env --test test/backup.test.js
verify-no-firebase:
	python scripts/verify_no_firebase.py
audit:
	python scripts/audit_screens.py
verify: lint test test-e2e backup-test verify-no-firebase build-web build-android

build-workspace-web:
	./scripts/flutter.sh build web --release --no-wasm-dry-run --target lib/main_server.dart
build-workspace-android:
	./scripts/flutter.sh build apk --debug --target lib/main_server.dart

build-container:
	node scripts/build_container.mjs $(or $(MUCHET_IMAGE),muchet:local-check)
test-container:
	node deploy/check-container.mjs $(or $(MUCHET_IMAGE),muchet:local-check)

.PHONY: build-container test-container
