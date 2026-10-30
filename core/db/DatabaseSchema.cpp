#include "DatabaseSchema.h"
#include "../model/accounts/Account.h"
#include "HistorySavepoint.h"
#include "InvestmentRepository.h"
#include "PositionHistory.h"
#include "SnapshotTables.h"
#include "SqlRow.h"

#include <QDateTime>
#include <QList>
#include <QPair>
#include <QRegularExpression>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QVector>

#include <array>

DatabaseSchema::DatabaseSchema(Database& database, QString& lastError)
    : db_(database)
    , database_(database.connection())
    , lastError_(lastError)
{
}

bool DatabaseSchema::prepare()
{
    return initializeSchema() && migrateLegacySchema() && migrateInvestmentSchema()
        && migrateBankImportSchema() && migrateLedgerSchema() && migrateTaxKind()
        && migrateCurrencySchema() && migrateCreditDebtFlag() && migrateAnalyticsHistorySchema();
}

void DatabaseSchema::setLastError(const QString& error) { lastError_ = error; }

bool DatabaseSchema::initializeSchema()
{
    const QStringList statements{
        // Additive, idempotent migration: existing operations are untouched.
        QStringLiteral("CREATE TABLE IF NOT EXISTS notes ("
                       "id INTEGER PRIMARY KEY CHECK(id=1), text TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS bank_import_links (row_key TEXT PRIMARY KEY, "
                       "transaction_id TEXT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS bank_category_rules ("
                       "pattern TEXT NOT NULL CHECK(length(trim(pattern)) > 0), "
                       "match_mode TEXT NOT NULL CHECK(match_mode IN ('exact','contains')), "
                       "type INTEGER NOT NULL CHECK(type IN (0,1)), "
                       "category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE, "
                       "match_field TEXT NOT NULL DEFAULT 'legacy' CHECK(match_field IN ('legacy','recipient','description')), "
                       "PRIMARY KEY(pattern,match_mode,type))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS bank_recipient_rules (pattern TEXT NOT NULL CHECK(length(trim(pattern)) BETWEEN 1 AND 240), "
                       "match_field TEXT NOT NULL CHECK(match_field IN ('description','bank_recipient','recipient_id','recipient')), "
                       "match_mode TEXT NOT NULL CHECK(match_mode IN ('exact','contains')), type INTEGER NOT NULL CHECK(type IN (0,1)), "
                       "recipient_name TEXT NOT NULL CHECK(length(trim(recipient_name)) BETWEEN 1 AND 160), "
                       "PRIMARY KEY(pattern,match_field,match_mode,type))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS capital_snapshots ("
                       "snapshot_date TEXT PRIMARY KEY CHECK(length(snapshot_date) = 10), "
                       "currency TEXT NOT NULL CHECK(currency IN ('RUB','USD','EUR','CNY')), "
                       "total_minor INTEGER NOT NULL, updated_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS financial_goals ("
                       "id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 80), "
                       "currency TEXT NOT NULL CHECK(currency IN ('RUB','USD','EUR','CNY')), "
                       "target_minor INTEGER NOT NULL CHECK(target_minor > 0), "
                       "deadline TEXT, all_sources INTEGER NOT NULL CHECK(all_sources IN (0,1)), "
                       "source_ids TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS accounts ("
                       "id TEXT PRIMARY KEY, name TEXT NOT NULL, "
                       "asset_type INTEGER NOT NULL CHECK(asset_type IN (0,1,2)), "
                       "account_type INTEGER NOT NULL CHECK(account_type IN (0,1,2,4,5,6,7)), "
                       "currency TEXT NOT NULL CHECK(currency IN ('RUB','USD','EUR','CNY')), "
                       "initial_balance_minor INTEGER NOT NULL DEFAULT 0, "
                       "credit_limit_minor INTEGER NOT NULL DEFAULT 0 "
                       "CHECK(credit_limit_minor >= 0), "
                       "is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)), "
                       "created_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS categories ("
                       "id TEXT PRIMARY KEY, name TEXT NOT NULL, "
                       "type INTEGER NOT NULL CHECK(type IN (0,1)), "
                       "is_system INTEGER NOT NULL DEFAULT 0 CHECK(is_system IN (0,1)), "
                       "is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)), "
                       "created_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS projects ("
                       "id TEXT PRIMARY KEY, "
                       "name TEXT NOT NULL CHECK(length(trim(name)) > 0), "
                       "is_archived INTEGER NOT NULL DEFAULT 0 "
                       "CHECK(is_archived IN (0,1)), "
                       "created_at INTEGER NOT NULL, "
                       "updated_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS budgets ("
                       "id TEXT PRIMARY KEY, "
                       "name TEXT NOT NULL CHECK(length(trim(name)) > 0), "
                       "currency TEXT NOT NULL CHECK(currency IN ('RUB','USD','EUR','CNY')), "
                       "default_limit_minor INTEGER NOT NULL CHECK(default_limit_minor > 0), "
                       "all_accounts INTEGER NOT NULL CHECK(all_accounts IN (0,1)), "
                       "all_categories INTEGER NOT NULL CHECK(all_categories IN (0,1)), "
                       "starts_on TEXT NOT NULL CHECK(length(starts_on) = 10), "
                       "is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)), "
                       "created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS budget_accounts ("
                       "budget_id TEXT NOT NULL REFERENCES budgets(id) ON DELETE CASCADE, "
                       "account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, "
                       "PRIMARY KEY(budget_id, account_id))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS budget_category_limits ("
                       "budget_id TEXT NOT NULL REFERENCES budgets(id) ON DELETE CASCADE, "
                       "category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE, "
                       "limit_minor INTEGER NOT NULL DEFAULT 0 CHECK(limit_minor >= 0), "
                       "PRIMARY KEY(budget_id, category_id))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS budget_months ("
                       "budget_id TEXT NOT NULL REFERENCES budgets(id) ON DELETE CASCADE, "
                       "month TEXT NOT NULL CHECK(length(month) = 10), "
                       "limit_minor INTEGER NOT NULL CHECK(limit_minor > 0), "
                       "PRIMARY KEY(budget_id, month))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS transactions ("
                       "id TEXT PRIMARY KEY, "
                       "account_id TEXT NOT NULL REFERENCES accounts(id), "
                       "category_id TEXT REFERENCES categories(id), "
                       "type INTEGER NOT NULL CHECK(type IN (0,1)), "
                       "amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0), "
                       "occurred_at INTEGER NOT NULL, description TEXT NOT NULL DEFAULT '', "
                       "recipient_json TEXT NOT NULL DEFAULT '{}', "
                       "project_id TEXT REFERENCES projects(id) ON DELETE SET NULL, "
                       "created_at INTEGER NOT NULL, "
                       "kind TEXT NOT NULL CHECK(kind IN ('income','expense','transfer','buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry')), "
                       "operation_id TEXT, "
                       "position_id TEXT REFERENCES investment_positions(id) ON DELETE SET NULL, "
                       "instrument_id TEXT REFERENCES investment_instruments(id), "
                       "quantity_micros INTEGER NOT NULL DEFAULT 0, "
                       "price_micros INTEGER, trade_currency TEXT, fee_minor INTEGER, tax_minor INTEGER)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS deposit_settings ("
                       "account_id TEXT PRIMARY KEY "
                       "REFERENCES accounts(id) ON DELETE CASCADE, "
                       "annual_rate_bps INTEGER NOT NULL "
                       "CHECK(annual_rate_bps BETWEEN 1 AND 100000), "
                       "payout_frequency INTEGER NOT NULL "
                       "CHECK(payout_frequency IN (0,1)), "
                       "payout_day INTEGER NOT NULL CHECK(payout_day BETWEEN 0 AND 31), "
                       "starts_on TEXT NOT NULL CHECK(length(starts_on) = 10), "
                       "generated_through TEXT NOT NULL "
                       "CHECK(length(generated_through) = 10), "
                       "updated_at INTEGER NOT NULL, "
                       "CHECK((payout_frequency = 0 AND payout_day BETWEEN 1 AND 31) OR "
                       "      (payout_frequency = 1 AND payout_day = 0)))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS deposit_interest_occurrences ("
                       "account_id TEXT NOT NULL "
                       "REFERENCES deposit_settings(account_id) ON DELETE CASCADE, "
                       "occurrence_date TEXT NOT NULL CHECK(length(occurrence_date) = 10), "
                       "transaction_id TEXT NOT NULL UNIQUE "
                       "REFERENCES transactions(id) ON DELETE CASCADE, "
                       "PRIMARY KEY(account_id, occurrence_date))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS settings ("
                       "key TEXT PRIMARY KEY, value TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS bank_csv_profiles ("
                       "id TEXT PRIMARY KEY, "
                       "name TEXT NOT NULL CHECK(length(trim(name)) > 0), "
                       "configuration_json TEXT NOT NULL, "
                       "created_at INTEGER NOT NULL, "
                       "updated_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS recurring_transactions ("
                       "id TEXT PRIMARY KEY, "
                       "name TEXT NOT NULL CHECK(length(trim(name)) > 0), "
                       "account_id TEXT NOT NULL REFERENCES accounts(id), "
                       "category_id TEXT NOT NULL REFERENCES categories(id), "
                       "type INTEGER NOT NULL CHECK(type IN (0,1)), "
                       "amount_minor INTEGER NOT NULL CHECK(amount_minor > 0), "
                       "amount_currency TEXT NOT NULL "
                       "CHECK(amount_currency IN ('RUB','USD','EUR','CNY')), "
                       "recurrence_type INTEGER NOT NULL "
                       "CHECK(recurrence_type IN (0,1,2,3)), "
                       "weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7), "
                       "day_of_month INTEGER NOT NULL "
                       "CHECK(day_of_month BETWEEN 1 AND 31), "
                       "week_of_month INTEGER NOT NULL "
                       "CHECK(week_of_month BETWEEN 1 AND 5), "
                       "starts_on TEXT NOT NULL CHECK(length(starts_on) = 10), "
                       "generated_through TEXT NOT NULL "
                       "CHECK(length(generated_through) = 10), "
                       "created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS "
                       "recurring_transaction_occurrences ("
                       "recurring_id TEXT NOT NULL "
                       "REFERENCES recurring_transactions(id) ON DELETE CASCADE, "
                       "occurrence_date TEXT NOT NULL, "
                       "transaction_id TEXT NOT NULL UNIQUE "
                       "REFERENCES transactions(id) ON DELETE CASCADE, "
                       "PRIMARY KEY(recurring_id, occurrence_date))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS crypto_wallet_names (id TEXT PRIMARY KEY, name TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS crypto_exchanges (id TEXT PRIMARY KEY, name TEXT NOT NULL, "
                       "holdings_json TEXT NOT NULL DEFAULT '[]', history_json TEXT NOT NULL DEFAULT '[]', "
                       "fetched_at INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS crypto_wallets ("
                       "id TEXT PRIMARY KEY, address TEXT NOT NULL, "
                       "network TEXT NOT NULL, symbol TEXT NOT NULL, "
                       "decimals INTEGER NOT NULL, "
                       "balance_atomic INTEGER NOT NULL DEFAULT 0 "
                       "CHECK(balance_atomic >= 0), "
                       "balance_fetched_at INTEGER, "
                       "history_fetched_at INTEGER, "
                       "is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)), "
                       "created_at INTEGER NOT NULL, "
                       "CHECK((network = 'TRON' AND symbol = 'USDT' AND decimals = 6) OR "
                       "      (network = 'BITCOIN' AND symbol = 'BTC' AND decimals = 8) OR "
                       "      (network = 'ETHEREUM' AND symbol = 'ETH' AND decimals = 8)))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS crypto_prices ("
                       "symbol TEXT PRIMARY KEY "
                       "CHECK(symbol IN ('USDT','BTC','ETH')), "
                       "price_usd_micros INTEGER NOT NULL CHECK(price_usd_micros > 0), "
                       "fetched_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS crypto_transactions ("
                       "wallet_id TEXT NOT NULL REFERENCES crypto_wallets(id), "
                       "transaction_id TEXT NOT NULL, "
                       "from_address TEXT NOT NULL, "
                       "to_address TEXT NOT NULL, "
                       "amount_atomic INTEGER NOT NULL CHECK(amount_atomic > 0), "
                       "occurred_at INTEGER NOT NULL, "
                       "PRIMARY KEY(wallet_id, transaction_id))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS investment_instruments ("
                       "id TEXT PRIMARY KEY, "
                       "symbol TEXT NOT NULL CHECK(length(trim(symbol)) > 0), "
                       "isin TEXT NOT NULL DEFAULT '', "
                       "name TEXT NOT NULL CHECK(length(trim(name)) > 0), "
                       "type INTEGER NOT NULL CHECK(type BETWEEN 0 AND 10), "
                       "currency TEXT NOT NULL CHECK(currency IN ('RUB','USD','EUR','CNY')), "
                       "market_code TEXT NOT NULL DEFAULT '', "
                       "primary_board_id TEXT NOT NULL DEFAULT '', "
                       "terms_json TEXT NOT NULL DEFAULT '{}', "
                       "is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)), "
                       "created_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS investment_positions ("
                       "id TEXT PRIMARY KEY, "
                       "account_id TEXT NOT NULL REFERENCES accounts(id), "
                       "instrument_id TEXT NOT NULL REFERENCES investment_instruments(id), "
                       "quantity_micros INTEGER NOT NULL CHECK(quantity_micros > 0), "
                       "average_price_micros INTEGER NOT NULL "
                       "CHECK(average_price_micros >= 0), "
                       "settings_json TEXT NOT NULL DEFAULT '{}', "
                       "is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)), "
                       "created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS investment_quotes ("
                       "instrument_id TEXT PRIMARY KEY "
                       "REFERENCES investment_instruments(id), "
                       "price_micros INTEGER NOT NULL, "
                       "terms_json TEXT NOT NULL DEFAULT '{}', "
                       "quoted_at INTEGER NOT NULL)"),
        QStringLiteral("CREATE UNIQUE INDEX IF NOT EXISTS "
                       "idx_crypto_wallets_active_address "
                       "ON crypto_wallets(network, address) "
                       "WHERE is_archived = 0"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at "
                       "ON transactions(occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_account_date "
                       "ON transactions(account_id, occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_category "
                       "ON transactions(category_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_deposit_occurrences_transaction "
                       "ON deposit_interest_occurrences(transaction_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_budget_accounts_account "
                       "ON budget_accounts(account_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_budget_categories_category "
                       "ON budget_category_limits(category_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS "
                       "idx_recurring_transactions_account "
                       "ON recurring_transactions(account_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS "
                       "idx_recurring_transactions_category "
                       "ON recurring_transactions(category_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS "
                       "idx_crypto_transactions_wallet_date "
                       "ON crypto_transactions(wallet_id, occurred_at DESC)"),
        QStringLiteral("CREATE UNIQUE INDEX IF NOT EXISTS "
                       "idx_investment_positions_active_account_instrument "
                       "ON investment_positions(account_id, instrument_id) "
                       "WHERE is_archived = 0"),
        QStringLiteral("CREATE UNIQUE INDEX IF NOT EXISTS "
                       "idx_investment_instruments_active_isin "
                       "ON investment_instruments(isin) "
                       "WHERE is_archived = 0 AND isin <> ''"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS "
                       "idx_investment_positions_instrument "
                       "ON investment_positions(instrument_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS "
                       "idx_investment_positions_account "
                       "ON investment_positions(account_id)")
    };

    for (const QString& statement : statements) {
        QSqlQuery query(database_);
        if (!query.exec(statement)) {
            setLastError(query.lastError().text());
            return false;
        }
    }
    return true;
}

bool DatabaseSchema::migrateLegacySchema()
{
    QSqlQuery columns(database_);
    if (!columns.exec(QStringLiteral("PRAGMA table_info(accounts)"))) {
        setLastError(columns.lastError().text());
        return false;
    }

    bool hasLegacyGroupType = false;
    bool hasAssetType = false;
    bool hasCreditLimit = false;
    while (columns.next()) {
        const QString name = columns.value(1).toString();
        hasLegacyGroupType = hasLegacyGroupType ||
            name == QStringLiteral("group_type");
        hasAssetType = hasAssetType ||
            name == QStringLiteral("asset_type");
        hasCreditLimit = hasCreditLimit ||
            name == QStringLiteral("credit_limit_minor");
    }
    columns.finish();

    QSqlQuery transactionColumns(database_);
    if (!transactionColumns.exec(QStringLiteral(
            "PRAGMA table_info(transactions)"))) {
        setLastError(transactionColumns.lastError().text());
        return false;
    }
    bool hasTransactionProjectId = false;
    while (transactionColumns.next()) {
        hasTransactionProjectId = hasTransactionProjectId ||
            transactionColumns.value(1).toString() ==
                QStringLiteral("project_id");
    }
    transactionColumns.finish();

    QSqlQuery projectColumns(database_);
    if (!projectColumns.exec(QStringLiteral("PRAGMA table_info(projects)"))) {
        setLastError(projectColumns.lastError().text());
        return false;
    }
    bool hasProjectArchived = false;
    bool hasProjectCreatedAt = false;
    bool hasProjectUpdatedAt = false;
    while (projectColumns.next()) {
        const QString name = projectColumns.value(1).toString();
        hasProjectArchived = hasProjectArchived ||
            name == QStringLiteral("is_archived");
        hasProjectCreatedAt = hasProjectCreatedAt ||
            name == QStringLiteral("created_at");
        hasProjectUpdatedAt = hasProjectUpdatedAt ||
            name == QStringLiteral("updated_at");
    }
    projectColumns.finish();

    QSqlQuery cryptoColumns(database_);
    if (!cryptoColumns.exec(QStringLiteral(
            "PRAGMA table_info(crypto_wallets)"))) {
        setLastError(cryptoColumns.lastError().text());
        return false;
    }
    bool hasCryptoHistoryFetchedAt = false;
    bool hasCryptoDecimals = false;
    while (cryptoColumns.next()) {
        hasCryptoHistoryFetchedAt = hasCryptoHistoryFetchedAt ||
            cryptoColumns.value(1).toString() ==
                QStringLiteral("history_fetched_at");
        hasCryptoDecimals = hasCryptoDecimals ||
            cryptoColumns.value(1).toString() == QStringLiteral("decimals");
    }
    cryptoColumns.finish();

    QSqlQuery investmentColumns(database_);
    if (!investmentColumns.exec(QStringLiteral(
            "PRAGMA table_info(investment_instruments)"))) {
        setLastError(investmentColumns.lastError().text());
        return false;
    }
    bool hasInvestmentMarketCode = false;
    bool hasInvestmentPrimaryBoardId = false;
    while (investmentColumns.next()) {
        const QString name = investmentColumns.value(1).toString();
        hasInvestmentMarketCode = hasInvestmentMarketCode ||
            name == QStringLiteral("market_code");
        hasInvestmentPrimaryBoardId = hasInvestmentPrimaryBoardId ||
            name == QStringLiteral("primary_board_id");
    }
    investmentColumns.finish();

    QSqlQuery accountSchema(database_);
    if (!accountSchema.exec(QStringLiteral(
            "SELECT sql FROM sqlite_master "
            "WHERE type = 'table' AND name = 'accounts'")) ||
        !accountSchema.next()) {
        setLastError(accountSchema.lastError().isValid()
            ? accountSchema.lastError().text()
            : QStringLiteral("Accounts table schema was not found"));
        return false;
    }
    const QString accountTableSql = accountSchema.value(0).toString();
    accountSchema.finish();
    const bool needsAccountTypeMigration =
        !accountTableSql.contains(QStringLiteral(",5,6,7")) ||
        accountTableSql.contains(QStringLiteral(",2,3,4"));

    QSqlQuery recurringSchema(database_);
    if (!recurringSchema.exec(QStringLiteral(
            "SELECT sql FROM sqlite_master "
            "WHERE type = 'table' AND name = 'recurring_transactions'")) ||
        !recurringSchema.next()) {
        setLastError(recurringSchema.lastError().isValid()
            ? recurringSchema.lastError().text()
            : QStringLiteral("Recurring transactions table schema was not found"));
        return false;
    }
    const QString recurringTableSql = recurringSchema.value(0).toString();
    recurringSchema.finish();
    const bool needsRecurringTypeExpansion =
        !recurringTableSql.contains(QStringLiteral("0,1,2,3"));

    QSqlQuery recurringColumns(database_);
    if (!recurringColumns.exec(QStringLiteral(
            "PRAGMA table_info(recurring_transactions)"))) {
        setLastError(recurringColumns.lastError().text());
        return false;
    }
    bool hasRecurringAmountCurrency = false;
    while (recurringColumns.next()) {
        hasRecurringAmountCurrency = hasRecurringAmountCurrency ||
            recurringColumns.value(1).toString() ==
                QStringLiteral("amount_currency");
    }
    recurringColumns.finish();

    const bool needsAssetTypeRename = hasLegacyGroupType && !hasAssetType;
    if (!needsAssetTypeRename && hasCreditLimit &&
        hasCryptoHistoryFetchedAt && hasCryptoDecimals &&
        hasInvestmentMarketCode && hasInvestmentPrimaryBoardId &&
        !needsAccountTypeMigration && !needsRecurringTypeExpansion &&
        hasRecurringAmountCurrency && hasTransactionProjectId &&
        hasProjectArchived && hasProjectCreatedAt && hasProjectUpdatedAt) {
        QSqlQuery projectIndex(database_);
        if (!projectIndex.exec(QStringLiteral(
                "CREATE INDEX IF NOT EXISTS idx_transactions_project_date "
                "ON transactions(project_id, occurred_at DESC)"))) {
            setLastError(projectIndex.lastError().text());
            return false;
        }
        return true;
    }
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QSqlQuery migration(database_);
    if (!hasProjectArchived &&
        !migration.exec(QStringLiteral(
            "ALTER TABLE projects ADD COLUMN is_archived INTEGER NOT NULL "
            "DEFAULT 0 CHECK(is_archived IN (0,1))"))) {
        setLastError(migration.lastError().text());
        database_.rollback();
        return false;
    }
    if (!hasProjectCreatedAt &&
        !migration.exec(QStringLiteral(
            "ALTER TABLE projects ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0"))) {
        setLastError(migration.lastError().text());
        database_.rollback();
        return false;
    }
    if (!hasProjectUpdatedAt &&
        !migration.exec(QStringLiteral(
            "ALTER TABLE projects ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0"))) {
        setLastError(migration.lastError().text());
        database_.rollback();
        return false;
    }
    if (!hasInvestmentMarketCode &&
        !migration.exec(QStringLiteral(
            "ALTER TABLE investment_instruments ADD COLUMN "
            "market_code TEXT NOT NULL DEFAULT ''"))) {
        setLastError(migration.lastError().text());
        database_.rollback();
        return false;
    }
    if (!hasInvestmentPrimaryBoardId &&
        !migration.exec(QStringLiteral(
            "ALTER TABLE investment_instruments ADD COLUMN "
            "primary_board_id TEXT NOT NULL DEFAULT ''"))) {
        setLastError(migration.lastError().text());
        database_.rollback();
        return false;
    }
    if (needsAssetTypeRename &&
        !migration.exec(QStringLiteral(
            "ALTER TABLE accounts RENAME COLUMN group_type TO asset_type"))) {
        setLastError(migration.lastError().text());
        database_.rollback();
        return false;
    }

    if (!hasTransactionProjectId &&
        !migration.exec(QStringLiteral(
            "ALTER TABLE transactions ADD COLUMN "
            "project_id TEXT REFERENCES projects(id) ON DELETE SET NULL"))) {
        setLastError(migration.lastError().text());
        database_.rollback();
        return false;
    }

    if (!hasCreditLimit) {
        if (!migration.exec(QStringLiteral(
                "ALTER TABLE accounts ADD COLUMN "
                "credit_limit_minor INTEGER NOT NULL DEFAULT 0 "
                "CHECK(credit_limit_minor >= 0)"))) {
            setLastError(migration.lastError().text());
            database_.rollback();
            return false;
        }

        // Before credit cards had their own semantics, a positive initial
        // balance was commonly used as the available credit. Preserve that
        // intent by turning it into a limit instead of counting bank money as
        // the user's asset.
        if (!migration.exec(QStringLiteral(
                "UPDATE accounts "
                "SET credit_limit_minor = initial_balance_minor, "
                "    initial_balance_minor = 0 "
                "WHERE account_type = %1 AND initial_balance_minor > 0")
                .arg(static_cast<int>(AccountType::CreditCard)))) {
            setLastError(migration.lastError().text());
            database_.rollback();
            return false;
        }
    }

    if (!hasCryptoHistoryFetchedAt &&
        !migration.exec(QStringLiteral(
            "ALTER TABLE crypto_wallets ADD COLUMN "
            "history_fetched_at INTEGER"))) {
        setLastError(migration.lastError().text());
        database_.rollback();
        return false;
    }

    if (!hasCryptoDecimals) {
        const QStringList cryptoMigrationStatements{
            QStringLiteral(
                "CREATE TABLE crypto_wallets_v2 ("
                "id TEXT PRIMARY KEY, address TEXT NOT NULL, "
                "network TEXT NOT NULL, symbol TEXT NOT NULL, "
                "decimals INTEGER NOT NULL, "
                "balance_atomic INTEGER NOT NULL DEFAULT 0 CHECK(balance_atomic >= 0), "
                "balance_fetched_at INTEGER, history_fetched_at INTEGER, "
                "is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)), "
                "created_at INTEGER NOT NULL, "
                "CHECK((network = 'TRON' AND symbol = 'USDT' AND decimals = 6) OR "
                "      (network = 'BITCOIN' AND symbol = 'BTC' AND decimals = 8) OR "
                "      (network = 'ETHEREUM' AND symbol = 'ETH' AND decimals = 8)))"),
            QStringLiteral(
                "INSERT INTO crypto_wallets_v2("
                "id,address,network,symbol,decimals,balance_atomic,"
                "balance_fetched_at,history_fetched_at,is_archived,created_at) "
                "SELECT id,address,network,symbol,6,balance_atomic,"
                "balance_fetched_at,history_fetched_at,is_archived,created_at "
                "FROM crypto_wallets"),
            QStringLiteral(
                "CREATE TABLE crypto_transactions_v2 ("
                "wallet_id TEXT NOT NULL REFERENCES crypto_wallets_v2(id), "
                "transaction_id TEXT NOT NULL, from_address TEXT NOT NULL, "
                "to_address TEXT NOT NULL, amount_atomic INTEGER NOT NULL "
                "CHECK(amount_atomic > 0), occurred_at INTEGER NOT NULL, "
                "PRIMARY KEY(wallet_id, transaction_id))"),
            QStringLiteral(
                "INSERT INTO crypto_transactions_v2 "
                "SELECT * FROM crypto_transactions"),
            QStringLiteral(
                "CREATE TABLE crypto_prices_v2 ("
                "symbol TEXT PRIMARY KEY CHECK(symbol IN ('USDT','BTC','ETH')), "
                "price_usd_micros INTEGER NOT NULL CHECK(price_usd_micros > 0), "
                "fetched_at INTEGER NOT NULL)"),
            QStringLiteral(
                "INSERT INTO crypto_prices_v2 SELECT * FROM crypto_prices"),
            QStringLiteral("DROP TABLE crypto_transactions"),
            QStringLiteral("DROP TABLE crypto_wallets"),
            QStringLiteral("DROP TABLE crypto_prices"),
            QStringLiteral("ALTER TABLE crypto_wallets_v2 RENAME TO crypto_wallets"),
            QStringLiteral("ALTER TABLE crypto_prices_v2 RENAME TO crypto_prices"),
            QStringLiteral("ALTER TABLE crypto_transactions_v2 RENAME TO crypto_transactions"),
            QStringLiteral(
                "CREATE UNIQUE INDEX idx_crypto_wallets_active_address "
                "ON crypto_wallets(network, address) WHERE is_archived = 0"),
            QStringLiteral(
                "CREATE INDEX idx_crypto_transactions_wallet_date "
                "ON crypto_transactions(wallet_id, occurred_at DESC)")};
        for (const QString& statement : cryptoMigrationStatements) {
            if (!migration.exec(statement)) {
                setLastError(migration.lastError().text());
                database_.rollback();
                return false;
            }
        }
    }

    if (!database_.commit()) {
        setLastError(database_.lastError().text());
        database_.rollback();
        return false;
    }

    if (needsAccountTypeMigration) {
        QSqlQuery foreignKeys(database_);
        if (!foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = OFF"))) {
            setLastError(foreignKeys.lastError().text());
            return false;
        }
        if (!database_.transaction()) {
            setLastError(database_.lastError().text());
            foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
            return false;
        }

        const QStringList accountMigrationStatements{
            QStringLiteral(
                "CREATE TABLE accounts_v2 ("
                "id TEXT PRIMARY KEY, name TEXT NOT NULL, "
                "asset_type INTEGER NOT NULL CHECK(asset_type IN (0,1,2)), "
                "account_type INTEGER NOT NULL "
                "CHECK(account_type IN (0,1,2,4,5,6,7)), "
                "currency TEXT NOT NULL CHECK(currency IN ('RUB','USD','EUR','CNY')), "
                "initial_balance_minor INTEGER NOT NULL DEFAULT 0, "
                "credit_limit_minor INTEGER NOT NULL DEFAULT 0 "
                "CHECK(credit_limit_minor >= 0), "
                "is_archived INTEGER NOT NULL DEFAULT 0 "
                "CHECK(is_archived IN (0,1)), created_at INTEGER NOT NULL)"),
            QStringLiteral(
                "INSERT INTO accounts_v2("
                "id,name,asset_type,account_type,currency,"
                "initial_balance_minor,credit_limit_minor,is_archived,created_at) "
                "SELECT id,name,asset_type,"
                "CASE WHEN account_type = 3 THEN 4 ELSE account_type END,"
                "currency,"
                "initial_balance_minor,credit_limit_minor,is_archived,created_at "
                "FROM accounts"),
            QStringLiteral("DROP TABLE accounts"),
            QStringLiteral("ALTER TABLE accounts_v2 RENAME TO accounts")};

        QSqlQuery accountMigration(database_);
        for (const QString& statement : accountMigrationStatements) {
            if (!accountMigration.exec(statement)) {
                setLastError(accountMigration.lastError().text());
                database_.rollback();
                foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
                return false;
            }
        }
        if (!database_.commit()) {
            setLastError(database_.lastError().text());
            database_.rollback();
            foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
            return false;
        }
        if (!foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"))) {
            setLastError(foreignKeys.lastError().text());
            return false;
        }

        QSqlQuery foreignKeyCheck(database_);
        if (!foreignKeyCheck.exec(QStringLiteral("PRAGMA foreign_key_check"))) {
            setLastError(foreignKeyCheck.lastError().text());
            return false;
        }
        if (foreignKeyCheck.next()) {
            setLastError(QStringLiteral(
                "Foreign key violation after accounts migration"));
            return false;
        }
    }

    if (needsRecurringTypeExpansion) {
        QSqlQuery foreignKeys(database_);
        if (!foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = OFF"))) {
            setLastError(foreignKeys.lastError().text());
            return false;
        }
        if (!database_.transaction()) {
            setLastError(database_.lastError().text());
            foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
            return false;
        }

        const QStringList recurringMigrationStatements{
            QStringLiteral(
                "CREATE TABLE recurring_transactions_v2 ("
                "id TEXT PRIMARY KEY, "
                "name TEXT NOT NULL CHECK(length(trim(name)) > 0), "
                "account_id TEXT NOT NULL REFERENCES accounts(id), "
                "category_id TEXT NOT NULL REFERENCES categories(id), "
                "type INTEGER NOT NULL CHECK(type IN (0,1)), "
                "amount_minor INTEGER NOT NULL CHECK(amount_minor > 0), "
                "recurrence_type INTEGER NOT NULL "
                "CHECK(recurrence_type IN (0,1,2,3)), "
                "weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7), "
                "day_of_month INTEGER NOT NULL "
                "CHECK(day_of_month BETWEEN 1 AND 31), "
                "week_of_month INTEGER NOT NULL "
                "CHECK(week_of_month BETWEEN 1 AND 5), "
                "starts_on TEXT NOT NULL CHECK(length(starts_on) = 10), "
                "generated_through TEXT NOT NULL "
                "CHECK(length(generated_through) = 10), "
                "created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)"),
            QStringLiteral(
                "INSERT INTO recurring_transactions_v2 "
                "SELECT * FROM recurring_transactions"),
            QStringLiteral("DROP TABLE recurring_transactions"),
            QStringLiteral(
                "ALTER TABLE recurring_transactions_v2 "
                "RENAME TO recurring_transactions"),
            QStringLiteral(
                "CREATE INDEX idx_recurring_transactions_account "
                "ON recurring_transactions(account_id)"),
            QStringLiteral(
                "CREATE INDEX idx_recurring_transactions_category "
                "ON recurring_transactions(category_id)")};

        QSqlQuery recurringMigration(database_);
        for (const QString& statement : recurringMigrationStatements) {
            if (!recurringMigration.exec(statement)) {
                setLastError(recurringMigration.lastError().text());
                database_.rollback();
                foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
                return false;
            }
        }
        if (!database_.commit()) {
            setLastError(database_.lastError().text());
            database_.rollback();
            foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
            return false;
        }
        if (!foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"))) {
            setLastError(foreignKeys.lastError().text());
            return false;
        }

        QSqlQuery foreignKeyCheck(database_);
        if (!foreignKeyCheck.exec(QStringLiteral("PRAGMA foreign_key_check"))) {
            setLastError(foreignKeyCheck.lastError().text());
            return false;
        }
        if (foreignKeyCheck.next()) {
            setLastError(QStringLiteral(
                "Foreign key violation after recurring transactions migration"));
            return false;
        }
    }

    if (!hasRecurringAmountCurrency) {
        if (!database_.transaction()) {
            setLastError(database_.lastError().text());
            return false;
        }
        QSqlQuery recurringCurrencyMigration(database_);
        const QStringList statements{
            QStringLiteral(
                "ALTER TABLE recurring_transactions ADD COLUMN "
                "amount_currency TEXT NOT NULL DEFAULT 'RUB' "
                "CHECK(amount_currency IN ('RUB','USD','EUR','CNY'))"),
            QStringLiteral(
                "UPDATE recurring_transactions "
                "SET amount_currency = COALESCE(("
                "SELECT currency FROM accounts "
                "WHERE accounts.id = recurring_transactions.account_id"
                "), 'RUB')")};
        for (const QString& statement : statements) {
            if (!recurringCurrencyMigration.exec(statement)) {
                setLastError(recurringCurrencyMigration.lastError().text());
                database_.rollback();
                return false;
            }
        }
        if (!database_.commit()) {
            setLastError(database_.lastError().text());
            database_.rollback();
            return false;
        }
    }

    QSqlQuery projectIndex(database_);
    if (!projectIndex.exec(QStringLiteral(
            "CREATE INDEX IF NOT EXISTS idx_transactions_project_date "
            "ON transactions(project_id, occurred_at DESC)"))) {
        setLastError(projectIndex.lastError().text());
        return false;
    }
    return true;
}

bool DatabaseSchema::seedDefaults()
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    const qint64 now = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    QSqlQuery seededAccounts(database_);
    seededAccounts.prepare(QStringLiteral(
        "SELECT value FROM settings WHERE key='accounts_initialized'"));
    if (!seededAccounts.exec()) {
        setLastError(seededAccounts.lastError().text());
        database_.rollback();
        return false;
    }
    const bool shouldSeedAccounts = !seededAccounts.next();
    QSqlQuery seededCategories(database_);
    seededCategories.prepare(QStringLiteral(
        "SELECT value FROM settings WHERE key='categories_initialized'"));
    if (!seededCategories.exec()) {
        setLastError(seededCategories.lastError().text());
        database_.rollback();
        return false;
    }
    const bool shouldSeedCategories = !seededCategories.next();
    QSqlQuery account(database_);
    account.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO accounts(id,name,asset_type,account_type,currency,created_at) "
        "VALUES (?, ?, 0, 4, ?, ?)"));
    const std::array<QString, 3> currencies{
        QStringLiteral("RUB"), QStringLiteral("USD"), QStringLiteral("EUR")};
    if (shouldSeedAccounts) {
        for (const QString& currency : currencies) {
            account.bindValue(0, QStringLiteral("household-") + currency.toLower());
            account.bindValue(1, QStringLiteral("Основной ") + currency);
            account.bindValue(2, currency);
            account.bindValue(3, now);
            if (!account.exec()) {
                setLastError(account.lastError().text());
                database_.rollback();
                return false;
            }
        }
    }

    struct Seed { QString id; QString name; int type; };
    const Seed seeds[] = {
        {QStringLiteral("salary"), QStringLiteral("Зарплата"), 0},
        {QStringLiteral("freelance"), QStringLiteral("Фриланс"), 0},
        {QStringLiteral("gift"), QStringLiteral("Подарок"), 0},
        {QStringLiteral("investment"), QStringLiteral("Инвестиции"), 0},
        {QStringLiteral("deposit_interest"), QStringLiteral("Проценты по вкладу"), 0},
        {QStringLiteral("other_income"), QStringLiteral("Другой доход"), 0},
        {QStringLiteral("groceries"), QStringLiteral("Продукты"), 1},
        {QStringLiteral("transport"), QStringLiteral("Транспорт"), 1},
        {QStringLiteral("housing"), QStringLiteral("Жилье"), 1},
        {QStringLiteral("health"), QStringLiteral("Здоровье"), 1},
        {QStringLiteral("entertainment"), QStringLiteral("Развлечения"), 1},
        {QStringLiteral("shopping"), QStringLiteral("Покупки"), 1},
        {QStringLiteral("other_expense"), QStringLiteral("Другое"), 1},
        {QStringLiteral("bank_fee"), QStringLiteral("Комиссия банка"), 1},
        {QStringLiteral("transfer-in"), QStringLiteral("Перевод"), 0},
        {QStringLiteral("transfer-out"), QStringLiteral("Перевод"), 1}};
    QSqlQuery category(database_);
    category.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO categories(id,name,type,is_system,created_at) "
        "VALUES (?, ?, ?, 1, ?)"));
    if (shouldSeedCategories) {
        for (const Seed& seed : seeds) {
            category.bindValue(0, seed.id);
            category.bindValue(1, seed.name);
            category.bindValue(2, seed.type);
            category.bindValue(3, now);
            if (!category.exec()) {
                setLastError(category.lastError().text());
                database_.rollback();
                return false;
            }
        }
    }

    // The bank's commission on a deposit is a built-in expense category. A database that already has categories but was
    // created before this one gets it on open; an emptied database stays empty.
    QSqlQuery bankFee(database_);
    bankFee.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO categories(id,name,type,is_system,created_at) "
        "SELECT 'bank_fee', 'Комиссия банка', 1, 1, ? WHERE EXISTS (SELECT 1 FROM categories)"));
    bankFee.addBindValue(now);
    if (!bankFee.exec()) {
        setLastError(bankFee.lastError().text());
        database_.rollback();
        return false;
    }

    QSqlQuery setting(database_);
    if (!setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) VALUES('app_currency','RUB')")) ||
        !setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) "
            "VALUES('analytics_currency','USD')")) ||
        !setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) VALUES('selected_asset','fiat')")) ||
        !setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) "
            "VALUES('automatic_currency_rates','1')")) ||
        !setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) "
            "VALUES('manual_rub_to_rub_rate','1')")) ||
        !setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) "
            "VALUES('manual_usd_to_rub_rate','90.909090909')")) ||
        !setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) "
            "VALUES('manual_eur_to_rub_rate','106.363636364')")) ||
        !setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) "
            "VALUES('accounts_initialized','1')")) ||
        !setting.exec(QStringLiteral(
            "INSERT OR IGNORE INTO settings(key,value) "
            "VALUES('categories_initialized','1')")) ||
        !database_.commit()) {
        setLastError(setting.lastError().isValid()
                         ? setting.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool DatabaseSchema::migrateCurrencySchema()
{
    struct Migration { QString name, definition; };
    QVector<Migration> migrations;
    const QRegularExpression oldCurrencies(QStringLiteral(
        "(\\b(?:amount_)?currency\\s+IN\\s*\\(\\s*)'RUB'\\s*,\\s*'USD'\\s*,\\s*'EUR'(\\s*\\))"),
        QRegularExpression::CaseInsensitiveOption);
    QSqlQuery tables(database_);
    if (!tables.exec(QStringLiteral("SELECT name,sql FROM sqlite_master WHERE type='table' AND sql IS NOT NULL"))) {
        setLastError(tables.lastError().text());
        return false;
    }
    while (tables.next()) {
        QString sql = tables.value(1).toString();
        if (!oldCurrencies.match(sql).hasMatch()) continue;
        sql.replace(oldCurrencies, QStringLiteral("\\1'RUB','USD','EUR','CNY'\\2"));
        migrations.append({tables.value(0).toString(), sql.mid(sql.indexOf(QLatin1Char('(')))});
    }
    tables.finish();
    if (migrations.isEmpty()) return true;

    const auto quoted = [](QString name) {
        name.replace(QLatin1Char('"'), QStringLiteral("\"\""));
        return QLatin1Char('"') + name + QLatin1Char('"');
    };
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral("PRAGMA foreign_keys = OFF"))) {
        setLastError(query.lastError().text());
        return false;
    }
    const auto fail = [&](const QString& error) {
        database_.rollback();
        query.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
        setLastError(error);
        return false;
    };
    if (!database_.transaction()) return fail(database_.lastError().text());
    for (const auto& table : migrations) {
        QStringList objects, columns;
        QSqlQuery schema(database_);
        schema.prepare(QStringLiteral("SELECT sql FROM sqlite_master WHERE tbl_name=? AND type IN ('index','trigger') AND sql IS NOT NULL"));
        schema.addBindValue(table.name);
        if (!schema.exec()) return fail(schema.lastError().text());
        while (schema.next()) objects.append(schema.value(0).toString());
        schema.finish();
        if (!schema.exec(QStringLiteral("PRAGMA table_info(%1)").arg(quoted(table.name))))
            return fail(schema.lastError().text());
        while (schema.next()) columns.append(quoted(schema.value(1).toString()));
        schema.finish();
        const QString temporary = quoted(table.name + QStringLiteral("_cny_v1"));
        const QString original = quoted(table.name);
        const QString fields = columns.join(QLatin1Char(','));
        // Keep the original table names in foreign-key references and preserve
        // every column, index and trigger. All rebuilt tables commit together.
        const QStringList statements{
            QStringLiteral("CREATE TABLE %1 %2").arg(temporary, table.definition),
            QStringLiteral("INSERT INTO %1(%2) SELECT %2 FROM %3").arg(temporary, fields, original),
            QStringLiteral("DROP TABLE %1").arg(original),
            QStringLiteral("ALTER TABLE %1 RENAME TO %2").arg(temporary, original)};
        for (const auto& sql : statements)
            if (!query.exec(sql)) return fail(query.lastError().text());
        for (const auto& sql : objects)
            if (!query.exec(sql)) return fail(query.lastError().text());
    }
    if (!query.exec(QStringLiteral("PRAGMA foreign_key_check"))) return fail(query.lastError().text());
    if (query.next()) return fail(QStringLiteral("Нарушены связи после добавления валюты CNY"));
    query.finish();
    if (!database_.commit()) return fail(database_.lastError().text());
    if (!query.exec(QStringLiteral("PRAGMA foreign_keys = ON"))) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool DatabaseSchema::migrateCreditDebtFlag()
{
    QSqlQuery columns(database_);
    if (!columns.exec(QStringLiteral("PRAGMA table_info(accounts)"))) {
        setLastError(columns.lastError().text());
        return false;
    }
    bool present = false;
    while (columns.next()) {
        present = present || columns.value(1).toString() == QStringLiteral("counts_debt");
    }
    columns.finish();
    if (present) {
        return true;
    }
    QSqlQuery alter(database_);
    if (!alter.exec(QStringLiteral(
            "ALTER TABLE accounts ADD COLUMN counts_debt INTEGER NOT NULL DEFAULT 1 "
            "CHECK(counts_debt IN (0,1))"))) {
        setLastError(alter.lastError().text());
        return false;
    }
    return true;
}

bool DatabaseSchema::migrateInvestmentSchema()
{
    QSqlQuery query(database_);
    const auto hasColumn = [&](const QString& table, const QString& name) {
        QSqlQuery columns(database_); columns.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table));
        while (columns.next()) if (columns.value(1).toString() == name) return true;
        return false;
    };
    const bool instrumentTerms = hasColumn("investment_instruments", "terms_json");
    const bool positionSettings = hasColumn("investment_positions", "settings_json");
    const bool quoteTerms = hasColumn("investment_quotes", "terms_json");
    if (instrumentTerms && positionSettings && quoteTerms) return true;
    // Rebuild rather than editing sqlite_master. Foreign keys must be disabled
    // before the transaction; child tables keep references to the original name.
    if (!query.exec("PRAGMA foreign_keys = OFF") || !database_.transaction()) return false;
    const auto fail = [&](const QString& error) {
        database_.rollback(); query.exec("PRAGMA foreign_keys = ON"); setLastError(error); return false;
    };
    if (!instrumentTerms) {
        const QStringList statements{
            "CREATE TABLE investment_instruments_v2 (id TEXT PRIMARY KEY, symbol TEXT NOT NULL CHECK(length(trim(symbol)) > 0), "
            "isin TEXT NOT NULL DEFAULT '', name TEXT NOT NULL CHECK(length(trim(name)) > 0), "
            "type INTEGER NOT NULL CHECK(type BETWEEN 0 AND 10), currency TEXT NOT NULL CHECK(currency IN ('RUB','USD','EUR','CNY')), "
            "market_code TEXT NOT NULL DEFAULT '', primary_board_id TEXT NOT NULL DEFAULT '', terms_json TEXT NOT NULL DEFAULT '{}', "
            "is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)), created_at INTEGER NOT NULL)",
            "INSERT INTO investment_instruments_v2(id,symbol,isin,name,type,currency,market_code,primary_board_id,is_archived,created_at) "
            "SELECT id,symbol,isin,name,type,currency,market_code,primary_board_id,is_archived,created_at FROM investment_instruments",
            "DROP TABLE investment_instruments",
            "ALTER TABLE investment_instruments_v2 RENAME TO investment_instruments",
            "CREATE UNIQUE INDEX idx_investment_instruments_active_isin ON investment_instruments(isin) WHERE is_archived=0 AND isin<>''"};
        for (const auto& sql : statements) if (!query.exec(sql)) return fail(query.lastError().text());
    }
    if (!positionSettings && !query.exec("ALTER TABLE investment_positions ADD COLUMN settings_json TEXT NOT NULL DEFAULT '{}'")) return fail(query.lastError().text());
    if (!quoteTerms) {
        const QStringList statements{
            "CREATE TABLE investment_quotes_v2 (instrument_id TEXT PRIMARY KEY REFERENCES investment_instruments(id), "
            "price_micros INTEGER NOT NULL, quoted_at INTEGER NOT NULL, terms_json TEXT NOT NULL DEFAULT '{}')",
            "INSERT INTO investment_quotes_v2(instrument_id,price_micros,quoted_at) SELECT instrument_id,price_micros,quoted_at FROM investment_quotes",
            "DROP TABLE investment_quotes", "ALTER TABLE investment_quotes_v2 RENAME TO investment_quotes"};
        for (const auto& sql : statements) if (!query.exec(sql)) return fail(query.lastError().text());
    }
    if (!query.exec("PRAGMA foreign_key_check")) return fail(query.lastError().text());
    if (query.next()) return fail(QStringLiteral("Нарушены связи после обновления инвестиций"));
    query.finish();
    if (!database_.commit()) return fail(database_.lastError().text());
    if (!query.exec("PRAGMA foreign_keys = ON")) { setLastError(query.lastError().text()); return false; }
    return true;
}

bool DatabaseSchema::migrateLedgerSchema()
{
    // One journal: every money or position movement is a row of transactions. Investment operations move there one
    // row each, and transfer legs keep the identifier of their pair in operation_id.
    const auto hasTable = [this](const QString& table) {
        QSqlQuery query(database_);
        query.prepare(QStringLiteral("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?"));
        query.addBindValue(table);
        return query.exec() && query.next();
    };
    const auto hasColumn = [this](const QString& table, const QString& name) {
        QSqlQuery columns(database_);
        columns.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table));
        while (columns.next()) {
            if (columns.value(1).toString() == name) {
                return true;
            }
        }
        return false;
    };
    const bool rebuildJournal = !hasColumn(QStringLiteral("transactions"), QStringLiteral("kind"));
    const bool mergeInvestments = hasTable(QStringLiteral("investment_operations"));
    if (rebuildJournal || mergeInvestments) {
        // Foreign keys stay off while tables are rebuilt; child tables keep referring to the name "transactions".
        QSqlQuery query(database_);
        if (!query.exec(QStringLiteral("PRAGMA foreign_keys = OFF")) || !database_.transaction()) {
            setLastError(query.lastError().isValid() ? query.lastError().text() : database_.lastError().text());
            return false;
        }
        const QString target = rebuildJournal ? QStringLiteral("transactions_journal") : QStringLiteral("transactions");
        QStringList steps;
        if (rebuildJournal) {
            steps << QStringLiteral(
                "CREATE TABLE transactions_journal ("
                "id TEXT PRIMARY KEY, "
                "account_id TEXT NOT NULL REFERENCES accounts(id), "
                "category_id TEXT REFERENCES categories(id), "
                "type INTEGER NOT NULL CHECK(type IN (0,1)), "
                "amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0), "
                "occurred_at INTEGER NOT NULL, description TEXT NOT NULL DEFAULT '', "
                "recipient_json TEXT NOT NULL DEFAULT '{}', "
                "project_id TEXT REFERENCES projects(id) ON DELETE SET NULL, "
                "created_at INTEGER NOT NULL, "
                "kind TEXT NOT NULL CHECK(kind IN ('income','expense','transfer','buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry')), "
                "operation_id TEXT, "
                "position_id TEXT REFERENCES investment_positions(id) ON DELETE SET NULL, "
                "instrument_id TEXT REFERENCES investment_instruments(id), "
                "quantity_micros INTEGER NOT NULL DEFAULT 0, "
                "price_micros INTEGER, trade_currency TEXT, fee_minor INTEGER, tax_minor INTEGER)");
            steps << QStringLiteral(
                "INSERT INTO transactions_journal(id, account_id, category_id, type, amount_minor, occurred_at, description, "
                "recipient_json, project_id, created_at, kind, operation_id, quantity_micros) "
                "SELECT id, account_id, category_id, type, amount_minor, occurred_at, description, recipient_json, project_id, "
                "created_at, "
                "CASE WHEN category_id IN ('transfer-in','transfer-out') THEN 'transfer' WHEN type = 0 THEN 'income' ELSE 'expense' END, "
                "CASE WHEN category_id = 'transfer-out' AND id LIKE '%-out' THEN substr(id, 1, length(id) - 4) "
                "WHEN category_id = 'transfer-in' AND id LIKE '%-in' THEN substr(id, 1, length(id) - 3) END, 0 "
                "FROM transactions");
        }
        if (mergeInvestments) {
            // Databases from before the analytics history have no charge or trade columns yet.
            const QList<QPair<QString, QString>> columns{
                {QStringLiteral("fee_minor"), QStringLiteral("INTEGER CHECK(fee_minor>=0)")},
                {QStringLiteral("tax_minor"), QStringLiteral("INTEGER CHECK(tax_minor>=0)")},
                {QStringLiteral("trade_price_micros"), QStringLiteral("INTEGER")},
                {QStringLiteral("trade_currency"), QStringLiteral("TEXT")}};
            for (const auto& column : columns) {
                if (!hasColumn(QStringLiteral("investment_operations"), column.first)) {
                    steps << QStringLiteral("ALTER TABLE investment_operations ADD COLUMN %1 %2").arg(column.first, column.second);
                }
            }
            steps << QStringLiteral(
                "INSERT INTO %1(id, account_id, category_id, type, amount_minor, occurred_at, description, recipient_json, "
                "project_id, created_at, kind, position_id, instrument_id, quantity_micros, price_micros, trade_currency, "
                "fee_minor, tax_minor) "
                "SELECT id, account_id, NULL, CASE WHEN cash_delta_minor >= 0 THEN 0 ELSE 1 END, ABS(cash_delta_minor), "
                "occurred_at, description, '{}', NULL, occurred_at, kind, position_id, instrument_id, quantity_delta_micros, "
                "trade_price_micros, trade_currency, fee_minor, tax_minor FROM investment_operations").arg(target);
            steps << QStringLiteral("DROP TABLE investment_operations");
        }
        if (rebuildJournal) {
            steps << QStringLiteral("DROP TABLE transactions");
            steps << QStringLiteral("ALTER TABLE transactions_journal RENAME TO transactions");
        }
        const auto abort = [&](const QString& error) {
            database_.rollback();
            query.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
            setLastError(error);
            return false;
        };
        for (const auto& step : steps) {
            if (!query.exec(step)) {
                return abort(query.lastError().text());
            }
        }
        if (!query.exec(QStringLiteral("PRAGMA foreign_key_check")) || query.next()) {
            return abort(QStringLiteral("Миграция журнала нарушила связи между таблицами"));
        }
        if (!database_.commit()) {
            return abort(database_.lastError().text());
        }
        query.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
    }
    QSqlQuery indexes(database_);
    const QStringList statements{
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_kind ON transactions(kind, occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_position ON transactions(position_id, occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at ON transactions(occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_account_date ON transactions(account_id, occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_project_date ON transactions(project_id, occurred_at DESC)")};
    for (const auto& statement : statements) {
        if (!indexes.exec(statement)) {
            setLastError(indexes.lastError().text());
            return false;
        }
    }
    return true;
}

bool DatabaseSchema::migrateTaxKind()
{
    // Commission and tax of a sale are rows of their own, so the journal must accept the kind "tax".
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'transactions'")) || !query.next()) {
        setLastError(query.lastError().isValid() ? query.lastError().text() : QStringLiteral("Журнал движений не найден"));
        return false;
    }
    if (query.value(0).toString().contains(QStringLiteral("'tax'"))) {
        return true;
    }
    if (!query.exec(QStringLiteral("PRAGMA foreign_keys = OFF")) || !database_.transaction()) {
        setLastError(query.lastError().isValid() ? query.lastError().text() : database_.lastError().text());
        return false;
    }
    const auto abort = [&](const QString& error) {
        database_.rollback();
        query.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
        setLastError(error);
        return false;
    };
    const QStringList steps{
        QStringLiteral("CREATE TABLE transactions_kinds ("
                       "id TEXT PRIMARY KEY, "
                       "account_id TEXT NOT NULL REFERENCES accounts(id), "
                       "category_id TEXT REFERENCES categories(id), "
                       "type INTEGER NOT NULL CHECK(type IN (0,1)), "
                       "amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0), "
                       "occurred_at INTEGER NOT NULL, description TEXT NOT NULL DEFAULT '', "
                       "recipient_json TEXT NOT NULL DEFAULT '{}', "
                       "project_id TEXT REFERENCES projects(id) ON DELETE SET NULL, "
                       "created_at INTEGER NOT NULL, "
                       "kind TEXT NOT NULL CHECK(kind IN ('income','expense','transfer','buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry')), "
                       "operation_id TEXT, "
                       "position_id TEXT REFERENCES investment_positions(id) ON DELETE SET NULL, "
                       "instrument_id TEXT REFERENCES investment_instruments(id), "
                       "quantity_micros INTEGER NOT NULL DEFAULT 0, "
                       "price_micros INTEGER, trade_currency TEXT, fee_minor INTEGER, tax_minor INTEGER)"),
        QStringLiteral("INSERT INTO transactions_kinds(id, account_id, category_id, type, amount_minor, occurred_at, description, "
                       "recipient_json, project_id, created_at, kind, operation_id, position_id, instrument_id, quantity_micros, "
                       "price_micros, trade_currency, fee_minor, tax_minor) "
                       "SELECT id, account_id, category_id, type, amount_minor, occurred_at, description, recipient_json, project_id, "
                       "created_at, kind, operation_id, position_id, instrument_id, quantity_micros, price_micros, trade_currency, "
                       "fee_minor, tax_minor FROM transactions"),
        QStringLiteral("DROP TABLE transactions"),
        QStringLiteral("ALTER TABLE transactions_kinds RENAME TO transactions")};
    for (const auto& step : steps) {
        if (!query.exec(step)) {
            return abort(query.lastError().text());
        }
    }
    if (!query.exec(QStringLiteral("PRAGMA foreign_key_check")) || query.next()) {
        return abort(QStringLiteral("Миграция видов операций нарушила связи между таблицами"));
    }
    if (!database_.commit()) {
        return abort(database_.lastError().text());
    }
    query.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
    QSqlQuery indexes(database_);
    const QStringList statements{
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_kind ON transactions(kind, occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_position ON transactions(position_id, occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at ON transactions(occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_account_date ON transactions(account_id, occurred_at DESC)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_transactions_project_date ON transactions(project_id, occurred_at DESC)")};
    for (const auto& statement : statements) {
        if (!indexes.exec(statement)) {
            setLastError(indexes.lastError().text());
            return false;
        }
    }
    return true;
}

bool DatabaseSchema::migrateBankImportSchema()
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }
    const auto ensure = [&](const QString& table, const QString& column, const QString& definition) {
        QSqlQuery query(database_);
        if (!query.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table))) {
            setLastError(query.lastError().text());
            return false;
        }
        while (query.next())
            if (query.value(1).toString() == column) return true;
        query.finish();
        if (!query.exec(QStringLiteral("ALTER TABLE %1 ADD COLUMN %2 %3").arg(table, column, definition))) {
            setLastError(query.lastError().text());
            return false;
        }
        return true;
    };
    if (!ensure("transactions", "recipient_json", "TEXT NOT NULL DEFAULT '{}'") ||
        !ensure("bank_category_rules", "match_field",
            "TEXT NOT NULL DEFAULT 'legacy' CHECK(match_field IN ('legacy','recipient','description'))")) {
        database_.rollback();
        return false;
    }
    if (!database_.commit()) {
        setLastError(database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool DatabaseSchema::migrateAnalyticsHistorySchema() {
    InvestmentRepository investments(db_);
    HistorySavepoint atomic(database_);
    if(!atomic.active()){setLastError(database_.lastError().text());return false;}
    QSqlQuery q(database_);
    const auto exec=[&](const QString& sql){if(q.exec(sql))return true;setLastError(q.lastError().text());return false;};
    const auto ensure=[&](const QString& column,const QString& definition){
        if(!exec("PRAGMA table_info(transactions)"))return false;
        while(q.next())if(q.value(1).toString()==column){q.finish();return true;}
        q.finish();return exec("ALTER TABLE transactions ADD COLUMN "+column+" "+definition);
    };
    if(!ensure("fee_minor","INTEGER CHECK(fee_minor>=0)")
       || !ensure("tax_minor","INTEGER CHECK(tax_minor>=0)")
       || !ensure("trade_currency","TEXT"))return false;
    const QString definition=
        "(snapshot_date TEXT NOT NULL CHECK(length(snapshot_date)=10),source_id TEXT NOT NULL,"
        "account_id TEXT NOT NULL,instrument_id TEXT NOT NULL DEFAULT '',currency TEXT NOT NULL,"
        "value_minor INTEGER,quantity_atomic INTEGER,quantity_decimals INTEGER NOT NULL CHECK(quantity_decimals BETWEEN 0 AND 18),"
        "price_micros INTEGER,cost_basis_minor INTEGER CHECK(cost_basis_minor>=0),valued_at INTEGER,"
        "observed_at INTEGER NOT NULL,source TEXT NOT NULL,issues TEXT NOT NULL DEFAULT '',details_json TEXT NOT NULL DEFAULT '{}',"
        "PRIMARY KEY(snapshot_date,source_id))";
    for(auto kind:{AssetDailyValuation::Fiat,AssetDailyValuation::Crypto,AssetDailyValuation::Investment}) {
        const auto table=snapshotTable(kind);
        if(!exec("CREATE TABLE IF NOT EXISTS "+table+definition)
           || !exec("CREATE INDEX IF NOT EXISTS idx_"+table+"_account_date ON "+table+"(account_id,snapshot_date)"))return false;
    }
    const QStringList statements{
        "CREATE TABLE IF NOT EXISTS daily_valuation_runs(snapshot_date TEXT PRIMARY KEY,observed_at INTEGER NOT NULL)",
        "CREATE TABLE IF NOT EXISTS crypto_price_history(asset_id TEXT NOT NULL,quoted_at INTEGER NOT NULL,"
        "source TEXT NOT NULL,price_micros INTEGER NOT NULL,currency TEXT NOT NULL,observed_at INTEGER NOT NULL,terms_json TEXT NOT NULL DEFAULT '{}',"
        "PRIMARY KEY(asset_id,quoted_at,source))",
        "CREATE TABLE IF NOT EXISTS investment_price_history(asset_id TEXT NOT NULL,quoted_at INTEGER NOT NULL,"
        "source TEXT NOT NULL,price_micros INTEGER NOT NULL,currency TEXT NOT NULL,observed_at INTEGER NOT NULL,terms_json TEXT NOT NULL DEFAULT '{}',"
        "PRIMARY KEY(asset_id,quoted_at,source))",
        "CREATE TABLE IF NOT EXISTS fx_rate_history(currency TEXT NOT NULL,rate_date TEXT NOT NULL,source TEXT NOT NULL,"
        "rub_per_unit_micros INTEGER NOT NULL CHECK(rub_per_unit_micros>0),observed_at INTEGER NOT NULL,"
        "PRIMARY KEY(currency,rate_date,source))",
        "CREATE TABLE IF NOT EXISTS investment_position_history(sequence INTEGER PRIMARY KEY,position_id TEXT NOT NULL,"
        "account_id TEXT NOT NULL,instrument_id TEXT NOT NULL,currency TEXT NOT NULL,event TEXT NOT NULL,"
        "operation_id TEXT,occurred_at INTEGER NOT NULL,recorded_at INTEGER NOT NULL,quantity_micros INTEGER NOT NULL,"
        "before_quantity_micros INTEGER,cost_basis_minor INTEGER CHECK(cost_basis_minor>=0),before_cost_minor INTEGER,"
        "released_cost_minor INTEGER,realized_net_minor INTEGER,state_json TEXT NOT NULL,issues TEXT NOT NULL DEFAULT '')",
        "CREATE INDEX IF NOT EXISTS idx_position_history_position ON investment_position_history(position_id,sequence)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_position_history_operation ON investment_position_history(operation_id) WHERE operation_id IS NOT NULL"
    };
    for(const auto& sql:statements)if(!exec(sql))return false;
    for(const auto& action:{QStringLiteral("INSERT"),QStringLiteral("UPDATE"),QStringLiteral("DELETE")}) {
        QString predicate;
        if(action!="DELETE")predicate="(account_id=NEW.account_id AND snapshot_date>=date(NEW.occurred_at/1000,'unixepoch','localtime'))";
        if(action!="INSERT")predicate+=(predicate.isEmpty()?QString():QStringLiteral(" OR "))+"(account_id=OLD.account_id AND snapshot_date>=date(OLD.occurred_at/1000,'unixepoch','localtime'))";
        QString body;
        for(auto kind:{AssetDailyValuation::Fiat,AssetDailyValuation::Crypto,AssetDailyValuation::Investment}) {
            const auto table=snapshotTable(kind);
            body+="UPDATE "+table+" SET issues=CASE WHEN instr(issues,'history_changed')>0 THEN issues ELSE issues||';history_changed' END WHERE "+predicate+";";
        }
        if(!exec("CREATE TRIGGER IF NOT EXISTS history_transactions_"+action.toLower()+" AFTER "+action+" ON transactions BEGIN "+body+" END"))return false;
    }
    QString body;
    for(auto kind:{AssetDailyValuation::Fiat,AssetDailyValuation::Crypto,AssetDailyValuation::Investment})
        body+="UPDATE "+snapshotTable(kind)+" SET issues=CASE WHEN instr(issues,'history_changed')>0 THEN issues ELSE issues||';history_changed' END WHERE account_id=NEW.id;";
    if(!exec("CREATE TRIGGER IF NOT EXISTS history_account_basis AFTER UPDATE OF initial_balance_minor,currency ON accounts "
             "WHEN OLD.initial_balance_minor<>NEW.initial_balance_minor OR OLD.currency<>NEW.currency BEGIN "+body+" END"))return false;
    // Baselines record the observed state, without creating past purchase operations.
    QStringList positions;
    if(!exec("SELECT id FROM investment_positions WHERE NOT EXISTS (SELECT 1 FROM investment_position_history h WHERE h.position_id=investment_positions.id)"))return false;
    while(q.next())positions.append(q.value(0).toString());q.finish();
    for(const auto& id:positions)if(!investments.appendPositionState(id,"baseline")){setLastError(investments.lastError());return false;}
    // Repair the initial states recorded before average prices were used for
    // acquisition cost. Append a correction; do not rewrite historical sales,
    // explicit cost corrections or previously captured daily valuations.
    positions.clear();
    if(!exec(positionStateQuery+" WHERE p.is_archived=0 AND EXISTS (SELECT 1 FROM investment_position_history h "
        "WHERE h.position_id=p.id AND h.sequence=(SELECT max(sequence) FROM investment_position_history WHERE position_id=p.id) "
        "AND h.event IN ('opening','baseline') AND h.cost_basis_minor IS NULL) "
        "AND NOT EXISTS (SELECT 1 FROM transactions o WHERE o.position_id=p.id)"))return false;
    while(q.next())if(!averageAcquisitionCost(rowMap(q)).isNull())positions.append(q.value("id").toString());q.finish();
    for(const auto& id:positions)if(!investments.appendPositionState(id,"correction")){setLastError(investments.lastError());return false;}
    const qint64 now=QDateTime::currentMSecsSinceEpoch();
    q.prepare("INSERT OR IGNORE INTO crypto_price_history(asset_id,quoted_at,source,price_micros,currency,observed_at) "
              "SELECT symbol,fetched_at,'legacy',price_usd_micros,'USD',? FROM crypto_prices c WHERE NOT EXISTS (SELECT 1 FROM crypto_price_history h WHERE h.asset_id=c.symbol)");q.addBindValue(now);
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    q.prepare("INSERT OR IGNORE INTO investment_price_history(asset_id,quoted_at,source,price_micros,currency,observed_at,terms_json) "
              "SELECT q.instrument_id,q.quoted_at,'legacy',q.price_micros,i.currency,?,q.terms_json FROM investment_quotes q JOIN investment_instruments i ON i.id=q.instrument_id WHERE NOT EXISTS (SELECT 1 FROM investment_price_history h WHERE h.asset_id=q.instrument_id)");q.addBindValue(now);
    if(!q.exec()){setLastError(q.lastError().text());return false;}
    if(!exec("CREATE TABLE IF NOT EXISTS benchmark_daily_prices(benchmark_key TEXT NOT NULL,price_date TEXT NOT NULL,price_micros INTEGER CHECK(price_micros>0),currency TEXT NOT NULL,issues TEXT NOT NULL,observed_at INTEGER NOT NULL,PRIMARY KEY(benchmark_key,price_date))")
        || !exec("CREATE TABLE IF NOT EXISTS benchmark_history_ranges(benchmark_key TEXT NOT NULL,from_date TEXT NOT NULL,to_date TEXT NOT NULL,observed_at INTEGER NOT NULL,PRIMARY KEY(benchmark_key,from_date,to_date))"))return false;
    return atomic.commit();
}
