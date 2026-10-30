# Архитектура и план переезда

Решение — ADR-031 (слои) и ADR-032 (имена) в `docs/ADR.md`. Здесь — целевая схема и план по шагам с отметками.

Дата последнего обновления: 30.10.2026.

## Целевая схема

```
ui/              — QML и прослойка под экран (модели списков, форматирование)
   ↓
services/        — сценарии, транзакции БД, данные для графиков, уведомления
   ↓
core/
  model/         — сущности, деньги, валюты, расчёты, правила      (только Qt Core)
  db/            — подключение, схема и миграции, репозитории       (Qt Sql)
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
- [x] 1.4 Перенести чистые расчёты из `services/` в `core/model/`, по группам, каждая — отдельный коммит:
  - [x] 1.4.1 Деньги и валюты: `CurrencyConverter`, интерфейс `CurrencyRateProvider` — в `core/model/`, `TestCurrencyRateProvider` — в `tests/`.
  - [x] 1.4.2 Операции и балансы: `BalanceCalculator`, `TransactionDateFilter`, `DateSliceCalculator`, `RecurringScheduleCalculator`, `DepositInterestCalculator`.
  - [x] 1.4.3 Инвестиции: `InvestmentReturn`, `InvestmentValuation`, `InvestmentRiskCalculator`, `InvestmentPerformanceCalculator`, `CryptoCostBasis`. `InvestmentBenchmark` не перенесён: в нём вместе расчёт и разбор ответов Мосбиржи, делится в 2.5.
  - [x] 1.4.4 Планирование: `FinancialGoalCalculator`, `FinancialTrajectoryCalculator`, `CapitalHistoryCalculator`.
- [x] 1.5 Подпапки внутри `core/model/`. Библиотека остаётся одна — `core_model`. Группировка по смыслу (на какой вопрос о деньгах отвечает), а не по экранам. Раскладка согласована 24.10.2026:
  - `money/` — сколько и в какой валюте: `Money`, `Currency`, `CurrencyConverter`, `CurrencyRateProvider`;
  - `accounts/` — что лежит на счетах: `Account`, `Asset`, `BalanceCalculator`, `DepositSettings`, `DepositInterestCalculator`;
  - `transactions/` — движения денег: `Transaction`, `TransactionRecipient`, `Category`, `RecurringTransaction`, `RecurringScheduleCalculator`, `TransactionDateFilter`, `DateSliceCalculator`;
  - `investments/` — чем владею и сколько стоит: `InvestmentInstrument`, `InvestmentMarketInstrument`, `InvestmentTerms`, `InvestmentPosition`, `InvestmentQuote`, `InvestmentOperation`, `InvestmentValuation`;
  - `crypto/` — монеты и их себестоимость: `CryptoWallet`, `CryptoTransaction`, `CryptoCostBasis`;
  - `planning/` — что задумано: `Budget`, `Project`, `FinancialGoal`, `FinancialGoalCalculator`;
  - `analytics/` — как идут дела с капиталом и вложениями: `AnalyticsHistory`, `InvestmentPerformanceCalculator`, `InvestmentRiskCalculator`, `InvestmentReturn`, `CapitalHistoryCalculator`, `FinancialTrajectory`, `FinancialTrajectoryCalculator`.
  - Include'ы относительные: внутри подпапки `"Money.h"`, между подпапками `"../money/Money.h"`, снаружи `"../core/model/money/Money.h"`.
- [x] 1.6 Замер и проверка (26.10.2026):
  - Полная сборка с тестами: 741 компиляция до этапа 1 (коммит `b6e5115`) → 567 после (−174, −23 %). Файлы проекта: 542 компиляции 101 уникального файла → 368. `Currency.cpp` раньше компилировался 25 раз, теперь один. Оставшиеся повторы — `FinanceRepository.cpp` и `FinanceRepositoryHistory.cpp` (по 18 раз) и файлы `services/` (по 12–13 раз); уйдут на этапе 2, когда станут библиотеками.
  - `core_model` линкуется только с Qt Core и получает только пути заголовков Qt Core. В исходниках модели нет подключений SQL, сети, файлов, QML и GUI.
  - Дыра в проверке компилятором: `#include <QSqlQuery>` в модели не соберётся, но `#include <QtSql/QSqlQuery>` соберётся — системный Qt кладёт `/usr/include/qt6` в пути заголовков. Классы ввода-вывода из Qt Core (`QFile`, `QDir`, `QProcess`, `QStandardPaths`) компилятор тоже не остановит. Закрыто шагом 1.7.

- [x] 1.7 Тест-сторож `CoreModelIncludesTest` (`cmake/CheckCoreModelIncludes.cmake`, запускается `ctest` без сборки). Падает, если в `core/model` есть:
  - заголовки других модулей Qt через префикс (`<QtSql/…>`, `<QtNetwork/…>`, `<QtGui/…>`, `<QtQml/…>`, `<QtQuick…/…>` и др.);
  - классы базы, сети, UI, файлов, процессов, таймеров и потоков, в том числе из Qt Core (`QSql…`, `QNetwork…`, `QFile`, `QDir`, `QProcess`, `QStandardPaths`, `QSettings`, `QTimer`, `QThread`, `QFuture`, `QCoreApplication` и др.), в любом написании: `<QFile>`, `<QtCore/QFile>`, `<qfile.h>`;
  - локальные заголовки вне `core/model` (`"../../../services/…"`).

Не трогаем на этом этапе: банковский импорт (`BankCategoryMatcher`, `BankImportReview` завязаны на чтение файлов, распутываются в 2.4), парсеры ответов API (уходят в `core/api`), `QVariantMap` на входе и выходе `InvestmentPerformanceCalculator` (свои структуры — позже).

## Этап 2. `core/db`, `core/api`, `core/system`

- [x] 2.1 Класс `Database` в `core/db/` (библиотека `core_db`, входит в обёртку `core`): путь по умолчанию, папка данных, SQLCipher с ключом, `PRAGMA foreign_keys`, закрытие соединения, `lastError`, `transaction(fn)`. `FinanceRepository` держит `Database`, поле `database_` — ссылка на его соединение; API `FinanceRepository` не изменился. Тест `DatabaseTest`.
- [x] 2.2 Схема базы — класс `DatabaseSchema` в `core/db/`: создание таблиц новой базы (`initializeSchema`), 8 миграций старой базы до текущей схемы (`migrate*`, вместе — `prepare()`) и начальные данные (`seedDefaults`), около 1 260 строк, тела без изменений. В `FinanceRepository` остались `migrateBackup` (проверка схемы копии, уйдёт в 2.7) и `migrateAnalyticsHistorySchema`: она достраивает историю позиций через `appendPositionState` репозитория, переедет вместе с ним в 2.3.9/2.3.10. Неиспользуемый `migrations/20261006_bank_category_rules.sql` пока не тронут — ждёт решения.
- [ ] 2.3 Репозитории по одному, каждый — отдельный коммит, вызовы переключаются с `FinanceRepository` на новый репозиторий:
  - [x] 2.3.1 `NotesRepository` — `load`/`save` заметок; `FinanceController` держит его рядом с `FinanceRepository` и получает соединение через временный `FinanceRepository::database()`
  - [x] 2.3.2 `SettingsRepository` — валюта приложения и аналитики, выбранный раздел, автоматические и ручные курсы (13 методов). Настройки крипты, бенчмарка и доходности в таблице `settings` пока у `FinanceRepository`, уйдут в свои репозитории
  - [x] 2.3.3 `BankImportRepository` — профили CSV, правила категорий и получателей, связи импорта (8 методов). Перед этим типы правил `BankCategoryRule` и `BankRecipientRule` вынесены в `core/model/transactions/` (часть 2.4), и `persistence/FinanceRepository.h` больше не подключает `services/`. Запись правил вместе с операциями при импорте (`insertTransactions`) пока у `FinanceRepository`, уйдёт в 2.3.12
  - [x] 2.3.4 `CryptoRepository` — кошельки, биржи, сделки, снимки, цены, себестоимость, состояние обновлений в `settings` (24 метода; `saveCryptoPrice` добавлен в 2.3.9)
  - [x] 2.3.5 `PlanningRepository` — бюджеты и финансовые цели (папка модели `planning/`, 9 методов). `currencyFromCode` перенесён в `core/model/money/Currency`: им пользуются оба репозитория. Траектория и снимки капитала — в 2.3.10 (решено 30.10.2026)
  - [x] 2.3.6 `ProjectRepository` — проекты: список, добавление, изменение, архив (4 метода)
  - [x] 2.3.7 `CategoryRepository` — категории: список, архивные, добавление, переименование, архив (5 методов). `archiveCategory` одной транзакцией отвязывает и регулярные операции (`recurring_transactions`); на этапе 3 эту связку возьмёт сервис
  - [x] 2.3.8 `RecurringTransactionRepository` — расписания регулярных операций: список, добавление, изменение, удаление (4 метода). `materializeRecurringOccurrences` (создание наступивших операций) пока у `FinanceRepository`: пишет операции через общий код записи, уйдёт в 2.3.12
  - [x] 2.3.9 `InvestmentRepository` — инструменты, позиции, котировки, операции, комиссии и история позиций (состояния и себестоимость; пишется в тех же транзакциях), 21 метод. Решено 30.10.2026: история позиций — здесь, а не в `AnalyticsRepository`. Общие помощники в `core/db`: `SqlRow` (`rowMap`), `PositionHistory` (запрос состояния позиции, средняя стоимость приобретения), `PriceHistory` (запись истории цен; через него и `saveCryptoPrice` переехал в `CryptoRepository`). `HistorySavepoint` перенесён из `persistence/` в `core/db/`. Удаление счёта и миграция истории вызывают `appendPositionState` через `InvestmentRepository` на том же соединении
  - [ ] 2.3.10 `AnalyticsRepository` — дневные оценки, история цен (чтение) и курсов, бенчмарк, настройки траектории, снимки капитала (папка модели `analytics/`; бывший `MarketHistoryRepository`, переименован 30.10.2026)
  - [ ] 2.3.11 `AccountRepository` — счета, настройки вкладов, ставки
  - [ ] 2.3.12 `TransactionRepository` — операции, переводы, сводка
- [ ] 2.4 Распутать банковский импорт: структуры (сделано в 2.3.3) и логика правил (`BankCategoryRule`, `BankRecipientRule`, сопоставление) — в `core/model`, загрузка словаря и чтение файлов — в `core/system`.
- [ ] 2.5 Провайдеры и парсеры ответов — в `core/api/`. `services/InvestmentBenchmark` разделить: `parseBenchmarkPage`, `mergeBenchmarkRows` и список индексов `investmentBenchmarkIndices` — в `core/api` (Мосбиржа), `compareInvestmentBenchmark` — в `core/model/analytics/`.
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
