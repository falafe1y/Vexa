# Архитектура и план переезда

Решение — ADR-031 (слои) и ADR-032 (имена) в `docs/ADR.md`. Здесь — целевая схема и план по шагам с отметками.

Дата последнего обновления: 23.10.2026.

## Целевая схема

```
ui/              — QML и прослойка под экран (модели списков, форматирование)
   ↓
services/        — сценарии, транзакции БД, данные для графиков, уведомления
   ↓
core/
  model/         — сущности, деньги, валюты, расчёты, правила      (только Qt Core)
  db/            — подключение, migrations/, репозитории            (Qt Sql)
  api/           — ЦБ, MOEX, Bybit, Tron                            (Qt Network)
  system/        — файлы, content://, CSV/XLSX/PDF, хранилище ключей, события ОС
```

Правила зависимостей:
- слой видит только слои ниже;
- `core/model` ни от чего не зависит;
- `core/db`, `core/api`, `core/system` зависят от `core/model`, но не друг от друга;
- `services` обращается к `core/db` напрямую; интерфейсы — только для того, что подменяется в тестах (внешние API);
- каждая часть — отдельная статическая библиотека CMake: `core_model`, `core_db`, `core_api`, `core_system`, `services`. Так компилятор не даст `core/model` подключить SQL или сеть;
- библиотека-обёртка `core` (`INTERFACE`) подключает все части `core` разом — для приложения. Тесты линкуются точечно: тесты расчётов только с `core_model`.

Правила предметной области живут в `core/model`. `services` решает только порядок шагов.

## Правило для каждого шага

- После шага проект собирается, все тесты проходят.
- Шаг — отдельный коммит.
- Пути в разделах «Код.» `docs/ADR.md` обновляются в том же шаге.
- Сборка на слабой машине: `-j2`/`-j3`.

## Этап 0. Подготовка — сделано

- [x] 0.1 Коммит правки форматирования `persistence/FinanceRepository.h`.
- [x] 0.2 Удаление переводов (ADR-033), коммит `Remove translate`.

## Этап 1. `core/model`

- [x] 1.1–1.2 Библиотека `core` из файлов `core/`, зависит только от Qt Core. Приложение и тесты линкуются с ней, `Currency.cpp` компилируется один раз.
- [x] 1.3 Файлы `core/*` перенесены в `core/model/`, библиотека — `core_model`, добавлена обёртка `core`. Приложение и тесты контроллера линкуются с `core`, остальные тесты — с `core_model`.
- [ ] 1.4 Перенести чистые расчёты из `services/` в `core/model/`, по группам, каждая — отдельный коммит:
  - [x] 1.4.1 Деньги и валюты: `CurrencyConverter`, интерфейс `CurrencyRateProvider` — в `core/model/`, `TestCurrencyRateProvider` — в `tests/`.
  - [ ] 1.4.2 Операции и балансы: `BalanceCalculator`, `TransactionDateFilter`, `DateSliceCalculator`, `RecurringScheduleCalculator`, `DepositInterestCalculator`.
  - [ ] 1.4.3 Инвестиции: `InvestmentReturn`, `InvestmentValuation`, `InvestmentRiskCalculator`, `InvestmentBenchmark`, `InvestmentPerformanceCalculator`, `CryptoCostBasis`.
  - [ ] 1.4.4 Планирование: `FinancialGoalCalculator`, `FinancialTrajectoryCalculator`, `CapitalHistoryCalculator`.
- [ ] 1.5 Подпапки внутри `core/model/`: `money/`, `accounts/`, `transactions/`, `investments/`, `crypto/`, `planning/`.
- [ ] 1.6 Замер сборки «после»; проверить, что `core_model` линкуется только с Qt Core.

Не трогаем на этом этапе: банковский импорт (`BankCategoryMatcher`, `BankImportReview` завязаны на чтение файлов, распутываются в 2.4), парсеры ответов API (уходят в `core/api`), `QVariantMap` на входе и выходе `InvestmentPerformanceCalculator` (свои структуры — позже).

## Этап 2. `core/db`, `core/api`, `core/system`

- [ ] 2.1 Класс `Database` в `core/db/`: подключение, ключ, `lastError`, `transaction(fn)`. `FinanceRepository` пользуется им внутри, его API не меняется.
- [ ] 2.2 Миграции в `core/db/migrations/`.
- [ ] 2.3 Репозитории по одному, каждый — отдельный коммит, вызовы переключаются с `FinanceRepository` на новый репозиторий:
  - [ ] 2.3.1 `NotesRepository`
  - [ ] 2.3.2 `SettingsRepository`
  - [ ] 2.3.3 `BankImportRepository` — профили CSV, правила категорий и получателей, связи импорта
  - [ ] 2.3.4 `CryptoRepository` — кошельки, биржи, цены, себестоимость
  - [ ] 2.3.5 Бюджеты, цели, траектория, снимки капитала
  - [ ] 2.3.6 `ProjectRepository`
  - [ ] 2.3.7 `CategoryRepository`
  - [ ] 2.3.8 `RecurringTransactionRepository`
  - [ ] 2.3.9 `InvestmentRepository` — инструменты, позиции, котировки, операции
  - [ ] 2.3.10 `MarketHistoryRepository` — дневные оценки, история цен и курсов, бенчмарк
  - [ ] 2.3.11 `AccountRepository` — счета, настройки вкладов, ставки
  - [ ] 2.3.12 `TransactionRepository` — операции, переводы, сводка
- [ ] 2.4 Распутать банковский импорт: структуры и логика правил (`BankCategoryRule`, `BankRecipientRule`, сопоставление) — в `core/model`, загрузка словаря и чтение файлов — в `core/system`.
- [ ] 2.5 Провайдеры и парсеры ответов — в `core/api/`.
- [ ] 2.6 Файлы и форматы — в `core/system/`: `CsvCodec`, `XlsxReader`, `PdfStatementReader`, `ContentUriIo`. Разбор форматов отделить от доступа к файлам: `PdfStatementReader` делится на получение слов (`pdftotext`/PDFBox) и раскладку в строки (`parsePages`). Как понимать выписку по профилю банка (`BankCsvImporter`) — в `core/model`.
- [ ] 2.7 Бэкап, восстановление и очистка базы — `DatabaseMaintenance` в `core/db/`.
- [ ] 2.8 `FinanceRepository` опустел — удалить.

## Этап 3. `services`

- [ ] 3.1 Первые сценарии: `NotesService`, `SettingsService`.
- [ ] 3.2 По домену за шаг, в порядке этапа 2. Для каждого:
  - правила из `FinanceController` — в `core/model` (сущности и расчёты), не в `services`;
  - порядок шагов, транзакции и вызовы репозиториев — в сервис.
- [ ] 3.3 Уведомления об изменениях (`transactionsChanged`, `accountsChanged`, `ratesChanged`) испускают сервисы.
- [ ] 3.4 Данные для графиков и аналитики — в сервисах, обычными типами, без QML-специфики.

## Этап 4. UI

- [ ] 4.1 QML работает с объектами сервисов; модели списков и форматирование — тонкая прослойка в `ui/`. Переводим по экранам.
- [ ] 4.2 `QML_ELEMENT`/`QML_SINGLETON` вместо `setContextProperty`.
- [ ] 4.3 Большие списки — `QAbstractListModel` вместо `QVariantList`.
- [ ] 4.4 Расчёты из `ui/computer/dashboard/DashboardData.js` — в `core/model` или `services`.
- [ ] 4.5 `FinanceController` опустел — удалить.

## Этап 5. Имена (ADR-032)

- [ ] 5.1 Библиотеки без `vexa_`: `vexa_storage`, `vexa_access`, `vexa_sqlcipher`, `vexa_portable_backup`.
- [ ] 5.2 `migrateLedgerSchema` → `migrateTransactionSchema` (только функция, таблицы не меняются).
- [ ] 5.3 Имя приложения — из одной переменной CMake.

## Открытые вопросы

- Куда идут `storage/` и `security/`. Предложение, ждёт подтверждения: техника — в `core` (`CipherDriver`, `DatabaseEncryption`, `PortableBackup` — в `core/db`; хранилища паролей `PasswordStore`/`AndroidVault`, Argon2 из `PasswordLock`, `SystemLockMonitor`, работа с папкой автокопий — в `core/system`; правила автокопий и пауз после ошибок пароля — в `core/model`), оркестрация — в `services` (`DatabaseProtection` → `DatabaseProtectionService`, `AppAccess`). Решить до шага 2.7.
- Папка слоя сценариев: оставить существующую `services/` или переименовать в `service/`. Решить до этапа 3.
