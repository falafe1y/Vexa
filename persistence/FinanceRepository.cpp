#include "FinanceRepository.h"
#include "../core/db/HistorySavepoint.h"
#include "storage/CipherDriver.h"
#include "../core/db/DatabaseSchema.h"
#include "../core/db/InvestmentRepository.h"
#include "../core/db/PriceHistory.h"

#include "../core/model/money/Currency.h"

#include <QDir>
#include <QMap>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFileInfo>
#include <QFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QSaveFile>
#include <QStringList>
#include <QTimeZone>
#include <QUuid>

#include <cmath>

namespace
{
constexpr int currencyIndex(const Currency currency)
{
    return static_cast<int>(currency);
}

AssetType assetTypeFromInt(const int value)
{
    if (value == 1) {
        return AssetType::Crypto;
    }
    if (value == 2) {
        return AssetType::Investment;
    }
    return AssetType::Fiat;
}

bool isTransferCategory(const QString& categoryId)
{
    return categoryId == QStringLiteral("transfer-in") ||
           categoryId == QStringLiteral("transfer-out");
}

bool ensureTransferCategories(QSqlDatabase& database, QString& error)
{
    struct TransferCategory
    {
        const char* id;
        int type;
    };
    const TransferCategory categories[] = {
        {"transfer-in", 0},
        {"transfer-out", 1}};

    QSqlQuery query(database);
    query.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO categories(id,name,type,is_system,created_at) "
        "VALUES (?, 'Перевод', ?, 1, ?)"));
    const qint64 now = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    for (const TransferCategory& category : categories) {
        query.bindValue(0, QString::fromLatin1(category.id));
        query.bindValue(1, category.type);
        query.bindValue(2, now);
        if (!query.exec()) {
            error = query.lastError().text();
            return false;
        }
    }
    return true;
}

struct TransferComponentIds
{
    QString outgoing;
    QString incoming;
    bool valid = false;
};

TransferComponentIds transferComponentIds(
    const QString& id,
    const QString& categoryId
    )
{
    QString transferId;
    if (categoryId == QStringLiteral("transfer-out") &&
        id.endsWith(QStringLiteral("-out"))) {
        transferId = id.left(id.size() - 4);
    } else if (categoryId == QStringLiteral("transfer-in") &&
               id.endsWith(QStringLiteral("-in"))) {
        transferId = id.left(id.size() - 3);
    }

    if (transferId.isEmpty()) {
        return {};
    }

    return {
        transferId + QStringLiteral("-out"),
        transferId + QStringLiteral("-in"),
        true
    };
}

// Kind of a money row: a transfer leg, or plain income or expense. Investment kinds never come through here.
QString fiatKindFor(const QString& categoryId, const int type)
{
    if (categoryId == QStringLiteral("transfer-in") || categoryId == QStringLiteral("transfer-out")) {
        return QStringLiteral("transfer");
    }
    return type == 0 ? QStringLiteral("income") : QStringLiteral("expense");
}

void prepareTransactionInsert(QSqlQuery& query)
{
    query.prepare(QStringLiteral(
        "INSERT INTO transactions(id, account_id, category_id, type, "
        "amount_minor, occurred_at, description, project_id, created_at, recipient_json, "
        "kind, operation_id, quantity_micros) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)"));
}

bool insertTransactionRow(
    QSqlQuery& query,
    const Transaction& transaction,
    const qint64 createdAt
    )
{
    query.bindValue(0, transaction.id());
    query.bindValue(1, transaction.accountId());
    query.bindValue(2, transaction.categoryId());
    query.bindValue(3, transaction.type() == TransactionType::Income ? 0 : 1);
    query.bindValue(4, transaction.money().minorUnits());
    query.bindValue(5, transaction.date().toMSecsSinceEpoch());
    query.bindValue(6, transaction.description().isNull() ? QStringLiteral("") : transaction.description());
    if (transaction.projectId().isEmpty()) {
        query.bindValue(7, QVariant());
    } else {
        query.bindValue(7, transaction.projectId());
    }
    query.bindValue(8, createdAt);
    query.bindValue(9, transaction.recipient().serialize());
    query.bindValue(10, fiatKindFor(transaction.categoryId(), transaction.type() == TransactionType::Income ? 0 : 1));
    // Both legs of a transfer share the identifier without the "-out" / "-in" suffix.
    const auto components = transferComponentIds(transaction.id(), transaction.categoryId());
    query.bindValue(11, components.valid ? QVariant(components.outgoing.left(components.outgoing.size() - 4)) : QVariant());
    return query.exec();
}

// Replacement deletes/reinserts rows; retain bank statement identities across edits.
QMap<QString, bool> bankLinksForOperation(QSqlDatabase& database, const QString& id, QString& error)
{
    QMap<QString, bool> links;
    QSqlQuery lookup(database);
    lookup.prepare(QStringLiteral("SELECT category_id,type FROM transactions WHERE id=?"));
    lookup.addBindValue(id);
    if (!lookup.exec() || !lookup.next()) {
        error = QStringLiteral("Transaction was not found"); return links;
    }
    const auto category = lookup.value(0).toString();
    const bool income = lookup.value(1).toInt() == 0;
    const auto components = transferComponentIds(id, category);
    lookup.finish();
    lookup.prepare(QStringLiteral("SELECT l.row_key,t.type FROM bank_import_links l "
        "JOIN transactions t ON t.id=l.transaction_id WHERE t.id=? OR t.id=? OR t.id=?"));
    lookup.addBindValue(id);
    lookup.addBindValue(components.valid ? components.outgoing : id);
    lookup.addBindValue(components.valid ? components.incoming : id);
    if (!lookup.exec()) { error = lookup.lastError().text(); return links; }
    while (lookup.next()) links.insert(lookup.value(0).toString(), lookup.value(1).toInt() == 0);
    if (lookup.lastError().isValid()) error = lookup.lastError().text();
    if (id.startsWith("bankcsv-") && !isTransferCategory(category)) links.insert(id, income);
    return links;
}

bool restoreBankLinks(QSqlDatabase& database, const QMap<QString, bool>& links,
    const QString& outgoingId, const QString& incomingId, QString& error)
{
    QSqlQuery query(database);
    query.prepare(QStringLiteral("INSERT INTO bank_import_links(row_key,transaction_id) VALUES(?,?)"));
    for (auto it = links.cbegin(); it != links.cend(); ++it) {
        query.bindValue(0, it.key()); query.bindValue(1, it.value() ? incomingId : outgoingId);
        if (!query.exec()) { error = query.lastError().text(); return false; }
    }
    return true;
}

bool deleteOperationRows(
    QSqlDatabase& database,
    const QString& id,
    QString& error
    )
{
    QSqlQuery lookup(database);
    lookup.prepare(QStringLiteral(
        "SELECT category_id FROM transactions WHERE id = ?"));
    lookup.addBindValue(id);
    if (!lookup.exec()) {
        error = lookup.lastError().text();
        return false;
    }
    if (!lookup.next()) {
        error = QStringLiteral("Transaction was not found");
        return false;
    }

    const QString categoryId = lookup.value(0).toString();
    lookup.finish();
    const TransferComponentIds componentIds = transferComponentIds(id, categoryId);

    QSqlQuery deletion(database);
    if (isTransferCategory(categoryId) && componentIds.valid) {
        deletion.prepare(QStringLiteral(
            "DELETE FROM transactions "
            "WHERE (id = ? AND category_id = 'transfer-out') "
            "   OR (id = ? AND category_id = 'transfer-in')"));
        deletion.addBindValue(componentIds.outgoing);
        deletion.addBindValue(componentIds.incoming);
    } else {
        deletion.prepare(QStringLiteral(
            "DELETE FROM transactions WHERE id = ? AND kind IN ('income','expense','transfer')"));
        deletion.addBindValue(id);
    }

    if (!deletion.exec() || deletion.numRowsAffected() < 1) {
        error = deletion.lastError().isValid()
            ? deletion.lastError().text()
            : QStringLiteral("Transaction was not found");
        return false;
    }
    return true;
}
}

FinanceRepository::FinanceRepository(const QString& databasePath, const QByteArray& databaseKey,
                                     std::shared_ptr<DatabaseKeyStore> keyStore)
    : keyStore_(keyStore ? std::move(keyStore) : nativeDatabaseKeyStore())
    , db_(databasePath, databaseKey)
    , database_(db_.connection())
{
    if (!db_.isOpen()) {
        setLastError(db_.lastError());
        return;
    }

    DatabaseSchema schema(db_, lastError_);
    if (!schema.prepare() || !schema.seedDefaults()) {
        db_.close();
    }
}

bool FinanceRepository::migrateBackup(const DatabaseAccess& access, const QString& workspace, QString& error)
{
    // Both files belong to the private encrypted import workspace.
    FinanceRepository candidate(access.path, access.key);
    FinanceRepository reference(QDir(workspace).filePath("reference.db"), access.key);
    if (!candidate.isOpen() || !reference.isOpen()) {
        error = QStringLiteral("Структура копии не поддерживается этой версией Vexa."); return false;
    }
    // Compared by meaning, not by the text of each CREATE statement: a database upgraded with ALTER TABLE keeps
    // the text of its first CREATE, so the same columns can be written differently.
    const auto schema = [](QSqlDatabase db, QStringList& rows) {
        QSqlQuery objects(db);
        if (!objects.exec("SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT GLOB 'sqlite_*' "
                          "AND name != 'vexa_portable_backup' AND sql IS NOT NULL ORDER BY type,name")) return false;
        while (objects.next()) {
            const QString type = objects.value(0).toString(), name = objects.value(1).toString();
            if (type != QStringLiteral("table")) {
                rows.append(type + '|' + name + '|' + objects.value(2).toString() + '|' + objects.value(3).toString().simplified());
                continue;
            }
            QStringList parts;
            QSqlQuery columns(db);
            if (!columns.exec(QStringLiteral("PRAGMA table_info(\"%1\")").arg(name))) return false;
            while (columns.next()) {
                parts.append(QStringLiteral("column|%1|%2|%3|%4|%5")
                             .arg(columns.value(1).toString(), columns.value(2).toString().toUpper(),
                                  columns.value(3).toString(), columns.value(4).toString(), columns.value(5).toString()));
            }
            QSqlQuery keys(db);
            if (!keys.exec(QStringLiteral("PRAGMA foreign_key_list(\"%1\")").arg(name))) return false;
            while (keys.next()) {
                parts.append(QStringLiteral("key|%1|%2|%3|%4|%5|%6")
                             .arg(keys.value(2).toString(), keys.value(3).toString(), keys.value(4).toString(),
                                  keys.value(5).toString(), keys.value(6).toString(), keys.value(7).toString()));
            }
            parts.sort();
            rows.append(QStringLiteral("table|%1|%2").arg(name, parts.join(QLatin1Char('\n'))));
        }
        return !objects.lastError().isValid();
    };
    QStringList actual, expected;
    if (!schema(candidate.database_, actual) || !schema(reference.database_, expected) || actual != expected) {
        error = QStringLiteral("Структура копии отличается от поддерживаемой базы Vexa."); return false;
    }
    QSqlQuery check(candidate.database_);
    if (!check.exec("PRAGMA foreign_key_check") || check.next() || check.lastError().isValid()) {
        error = QStringLiteral("В копии нарушены связи между записями."); return false;
    }
    check.finish();
    if (!check.exec("INSERT OR IGNORE INTO notes(id,text) VALUES(1,'')")) {
        error = check.lastError().text(); return false;
    }
    return true;
}

FinanceRepository::~FinanceRepository() = default;

bool FinanceRepository::isOpen() const { return database_.isOpen(); }
QString FinanceRepository::lastError() const { return lastError_; }
QString FinanceRepository::databasePath() const { return database_.databaseName(); }
Database& FinanceRepository::database() { return db_; }

bool FinanceRepository::backupDatabase(const QString& destinationPath)
{
    const QString path = QDir::cleanPath(QFileInfo(destinationPath).absoluteFilePath());
    if (!database_.isOpen() || destinationPath.trimmed().isEmpty()) {
        setLastError(QStringLiteral("Не выбрано место для резервной копии"));
        return false;
    }
    const QString sourcePath = QDir::cleanPath(
        QFileInfo(database_.databaseName()).absoluteFilePath());
#ifdef Q_OS_WIN
    const Qt::CaseSensitivity pathSensitivity = Qt::CaseInsensitive;
#else
    const Qt::CaseSensitivity pathSensitivity = Qt::CaseSensitive;
#endif
    if (path.compare(sourcePath, pathSensitivity) == 0) {
        setLastError(QStringLiteral("Нельзя сохранить копию поверх рабочей базы"));
        return false;
    }
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) {
        setLastError(QStringLiteral("Не удалось создать папку для копии"));
        return false;
    }

    QString error;
    if (!DatabaseEncryption::snapshot(db_.access(), path, error)) {
        setLastError(error);
        return false;
    }
    setLastError({});
    return true;
}

bool FinanceRepository::restoreDatabase(const QString& sourcePath,
                                        qint64* restoredRecords,
                                        QString* previousBackupPath)
{
    if (restoredRecords) *restoredRecords = 0;
    if (previousBackupPath) previousBackupPath->clear();
    const QFileInfo file(sourcePath);
    if (!isOpen() || sourcePath.trimmed().isEmpty() || !file.isFile()) {
        setLastError(QStringLiteral("Выберите существующий файл резервной копии"));
        return false;
    }
    if (file.canonicalFilePath() == QFileInfo(database_.databaseName()).canonicalFilePath()) {
        setLastError(QStringLiteral("Выберите резервную копию, а не рабочую базу"));
        return false;
    }

    if (QFileInfo(sourcePath + QStringLiteral("-wal")).size() > 0) {
        setLastError(QStringLiteral("Копия содержит отдельный журнал WAL. Нужен самостоятельный файл резервной копии."));
        return false;
    }
    const auto sourceAccess = DatabaseEncryption::openSnapshot(sourcePath, *keyStore_);
    if (!sourceAccess.ok) { setLastError(sourceAccess.error); return false; }
    QString integrityError;
    if (!DatabaseEncryption::validate(sourceAccess.access, integrityError)) {
        setLastError(integrityError); return false;
    }
    const QString connection = QUuid::createUuid().toString(QUuid::WithoutBraces);
    bool restored = false;
    qint64 inserted = 0;
    QString safetyCopy;
    {
        QSqlDatabase source = addCipherDatabase(connection, sourceAccess.access.key);
        source.setDatabaseName(file.absoluteFilePath());
        source.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        // All source queries and database handles are destroyed before removing the connection.
        restored = [&]() -> bool {
            const auto fail = [this](const QString& message) {
                setLastError(message);
                return false;
            };
            if (!source.open()) return fail(QStringLiteral("Не удалось открыть копию: ") + source.lastError().text());
            if (!source.transaction()) return fail(source.lastError().text());
            QSqlQuery check(source);
            if (!check.exec(QStringLiteral("PRAGMA quick_check")) || !check.next()
                || check.value(0).toString() != QStringLiteral("ok")) {
                return fail(QStringLiteral("Файл повреждён или не является базой SQLite"));
            }
            check.finish();
            if (!check.exec(QStringLiteral("PRAGMA foreign_key_check")) || check.next()) {
                return fail(QStringLiteral("В копии нарушены связи между записями"));
            }
            check.finish();
            const QStringList tables{
                QStringLiteral("benchmark_daily_prices"), QStringLiteral("benchmark_history_ranges"),
                QStringLiteral("accounts"), QStringLiteral("categories"), QStringLiteral("projects"),
                QStringLiteral("budgets"), QStringLiteral("financial_goals"),
                QStringLiteral("investment_instruments"), QStringLiteral("crypto_wallets"),
                QStringLiteral("transactions"), QStringLiteral("deposit_settings"),
                QStringLiteral("recurring_transactions"), QStringLiteral("budget_accounts"),
                QStringLiteral("budget_category_limits"), QStringLiteral("budget_months"),
                QStringLiteral("deposit_interest_occurrences"), QStringLiteral("recurring_transaction_occurrences"),
                QStringLiteral("crypto_transactions"), QStringLiteral("crypto_wallet_names"),
                QStringLiteral("crypto_exchanges"), QStringLiteral("crypto_prices"),
                QStringLiteral("investment_positions"), QStringLiteral("investment_quotes"),
                QStringLiteral("capital_snapshots"), QStringLiteral("bank_csv_profiles"),
                QStringLiteral("bank_category_rules"), QStringLiteral("bank_recipient_rules"),
                QStringLiteral("bank_import_links"), QStringLiteral("settings"),
                QStringLiteral("notes"), QStringLiteral("fiat_daily_snapshots"),
                QStringLiteral("crypto_daily_snapshots"), QStringLiteral("investment_daily_snapshots"),
                QStringLiteral("daily_valuation_runs"), QStringLiteral("crypto_price_history"),
                QStringLiteral("investment_price_history"), QStringLiteral("fx_rate_history"),
                QStringLiteral("investment_position_history")};
            QSet<QString> sourceTables;
            if (!check.exec(QStringLiteral("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"))) {
                return fail(check.lastError().text());
            }
            while (check.next()) {
                const QString table = check.value(0).toString();
                if (!tables.contains(table)) {
                    return fail(QStringLiteral("Структура копии не поддерживается этой версией программы"));
                }
                sourceTables.insert(table);
            }
            check.finish();
            for (const auto& required : {QStringLiteral("accounts"), QStringLiteral("categories"), QStringLiteral("transactions"), QStringLiteral("settings")}) {
                if (!sourceTables.contains(required)) return fail(QStringLiteral("Файл не является резервной копией Vexa"));
            }
            safetyCopy = QFileInfo(database_.databaseName()).absolutePath()
                + QStringLiteral("/before-restore-")
                + QUuid::createUuid().toString(QUuid::WithoutBraces)
                + QStringLiteral(".sqlite3");
            if (!backupDatabase(safetyCopy)) return fail(lastError_);
            if (!database_.transaction()) return fail(database_.lastError().text());
            const auto rollback = [&](const QString& error) {
                database_.rollback();
                return fail(QStringLiteral("Восстановление отменено, текущие данные сохранены: ") + error);
            };
            QSqlQuery pragma(database_);
            if (!pragma.exec(QStringLiteral("PRAGMA defer_foreign_keys = ON"))) return rollback(pragma.lastError().text());
            // Children are cleared before parents. The transaction also restores deletions.
            for (auto table = tables.crbegin(); table != tables.crend(); ++table) {
                if (!pragma.exec(QStringLiteral("DELETE FROM \"%1\"").arg(*table)))
                    return rollback(pragma.lastError().text());
            }
            for (const QString& table : tables) {
                if (!sourceTables.contains(table)) continue; // Older copies may lack newer features.
                QSqlQuery targetInfo(database_), sourceInfo(source);
                const QString infoSql = QStringLiteral("PRAGMA table_info(\"%1\")").arg(table);
                if (!targetInfo.exec(infoSql) || !sourceInfo.exec(infoSql)) return rollback(QStringLiteral("Не удалось прочитать структуру копии"));
                QSet<QString> targetColumns;
                QMap<int, QString> targetKeys, sourceKeys;
                QSet<QString> requiredColumns;
                while (targetInfo.next()) {
                    const QString column = targetInfo.value(1).toString();
                    targetColumns.insert(column);
                    if (targetInfo.value(5).toInt() > 0) targetKeys.insert(targetInfo.value(5).toInt(), column);
                    if (targetInfo.value(3).toBool() && targetInfo.value(4).isNull()) requiredColumns.insert(column);
                }
                QStringList columns, placeholders;
                while (sourceInfo.next()) {
                    const QString column = sourceInfo.value(1).toString();
                    if (!targetColumns.contains(column)) return rollback(QStringLiteral("Несовместимая структура таблицы %1").arg(table));
                    if (sourceInfo.value(5).toInt() > 0) sourceKeys.insert(sourceInfo.value(5).toInt(), column);
                    requiredColumns.remove(column);
                    QString quoted = column;
                    quoted.replace(QLatin1Char('"'), QStringLiteral("\"\""));
                    columns.append(QLatin1Char('"') + quoted + QLatin1Char('"'));
                    placeholders.append(QStringLiteral("?"));
                }
                if (!requiredColumns.isEmpty() || targetKeys.isEmpty() || targetKeys != sourceKeys) {
                    return rollback(QStringLiteral("Несовместимая структура таблицы %1").arg(table));
                }
                targetInfo.finish(); sourceInfo.finish();
                QStringList keys;
                for (const QString& key : targetKeys) keys.append(QStringLiteral("\"%1\"").arg(key));
                QSqlQuery rows(source), insert(database_);
                rows.setForwardOnly(true);
                if (!rows.exec(QStringLiteral("SELECT %1 FROM \"%2\"").arg(columns.join(','), table))
                    || !insert.prepare(QStringLiteral("INSERT INTO \"%1\" (%2) VALUES (%3)")
                        .arg(table, columns.join(','), placeholders.join(',')))) {
                    return rollback(QStringLiteral("Не удалось прочитать таблицу %1").arg(table));
                }
                while (rows.next()) {
                    for (qsizetype i = 0; i < columns.size(); ++i) insert.bindValue(i, rows.value(i));
                    for (const QString& key : keys) {
                        if (rows.value(columns.indexOf(key)).isNull()) return rollback(QStringLiteral("Пустой идентификатор в таблице %1").arg(table));
                    }
                    if (!insert.exec()) return rollback(QStringLiteral("Конфликт данных в таблице %1: %2").arg(table, insert.lastError().text()));
                    ++inserted;
                }
                if (rows.lastError().isValid()) return rollback(rows.lastError().text());
            }
            // Old copies have no notes. Record an empty document so notes.txt cannot
            // be imported again on a later startup after restoring such a copy.
            if (!pragma.exec(QStringLiteral("INSERT OR IGNORE INTO notes(id,text) VALUES(1,'')")))
                return rollback(pragma.lastError().text());
            if (!pragma.exec(QStringLiteral("INSERT OR IGNORE INTO settings(key,value) VALUES"
                    "('accounts_initialized','1'),('categories_initialized','1')")))
                return rollback(pragma.lastError().text());
            if (!pragma.exec(QStringLiteral("PRAGMA foreign_key_check")) || pragma.next())
                return rollback(QStringLiteral("В копии нарушены связи между записями"));
            pragma.finish();
            if (!sourceTables.contains(QStringLiteral("investment_position_history")) && !DatabaseSchema(db_, lastError_).migrateAnalyticsHistorySchema())
                return rollback(lastError_);
            if (!database_.commit()) return rollback(database_.lastError().text());
            return true;
        }();
        source.close();
    }
    QSqlDatabase::removeDatabase(connection);
    if (restored) {
        if (restoredRecords) *restoredRecords = inserted;
        if (previousBackupPath) *previousBackupPath = safetyCopy;
        setLastError({});
    } else if (!safetyCopy.isEmpty()) {
        QFile::remove(safetyCopy);
    }
    return restored;
}

bool FinanceRepository::clearAllUserData()
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }
    const QStringList statements{
        QStringLiteral("DELETE FROM benchmark_daily_prices"),
        QStringLiteral("DELETE FROM benchmark_history_ranges"),
        QStringLiteral("DELETE FROM fiat_daily_snapshots"),
        QStringLiteral("DELETE FROM crypto_daily_snapshots"),
        QStringLiteral("DELETE FROM investment_daily_snapshots"),
        QStringLiteral("DELETE FROM daily_valuation_runs"),
        QStringLiteral("DELETE FROM crypto_price_history"),
        QStringLiteral("DELETE FROM investment_price_history"),
        QStringLiteral("DELETE FROM fx_rate_history"),
        QStringLiteral("DELETE FROM investment_position_history"),
        QStringLiteral("DELETE FROM recurring_transaction_occurrences"),
        QStringLiteral("DELETE FROM deposit_interest_occurrences"),
        QStringLiteral("DELETE FROM crypto_exchanges"),
        QStringLiteral("DELETE FROM crypto_wallet_names"),
        QStringLiteral("DELETE FROM crypto_transactions"),
        QStringLiteral("DELETE FROM investment_quotes"),
        QStringLiteral("DELETE FROM investment_positions"),
        QStringLiteral("DELETE FROM budget_accounts"),
        QStringLiteral("DELETE FROM budget_category_limits"),
        QStringLiteral("DELETE FROM budget_months"),
        QStringLiteral("DELETE FROM bank_import_links"),
        QStringLiteral("DELETE FROM transactions"),
        QStringLiteral("DELETE FROM deposit_settings"),
        QStringLiteral("DELETE FROM recurring_transactions"),
        QStringLiteral("DELETE FROM budgets"),
        QStringLiteral("DELETE FROM financial_goals"),
        QStringLiteral("DELETE FROM capital_snapshots"),
        QStringLiteral("DELETE FROM bank_csv_profiles"),
        QStringLiteral("DELETE FROM bank_recipient_rules"),
        QStringLiteral("DELETE FROM bank_category_rules"),
        QStringLiteral("DELETE FROM crypto_wallets"),
        QStringLiteral("DELETE FROM crypto_prices"),
        QStringLiteral("DELETE FROM investment_instruments"),
        QStringLiteral("DELETE FROM projects"),
        QStringLiteral("DELETE FROM accounts"),
        QStringLiteral("DELETE FROM categories"),
        QStringLiteral("DELETE FROM settings"),
        QStringLiteral("DELETE FROM notes")};
    QSqlQuery query(database_);
    for (const QString& statement : statements) {
        if (!query.exec(statement)) {
            setLastError(query.lastError().text());
            database_.rollback();
            return false;
        }
    }
    const QStringList defaults{
        QStringLiteral("INSERT INTO notes(id,text) VALUES(1,'')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('app_currency','RUB')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('analytics_currency','USD')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('selected_asset','fiat')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('automatic_currency_rates','1')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('manual_rub_to_rub_rate','1')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('manual_usd_to_rub_rate','90.909090909')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('manual_eur_to_rub_rate','106.363636364')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('accounts_initialized','1')"),
        QStringLiteral("INSERT INTO settings(key,value) VALUES('categories_initialized','1')")};
    for (const QString& statement : defaults) {
        if (!query.exec(statement)) {
            setLastError(query.lastError().text());
            database_.rollback();
            return false;
        }
    }
    if (!database_.commit()) {
        setLastError(database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

QVector<Transaction> FinanceRepository::loadTransactions()
{
    QVector<Transaction> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT t.id, t.account_id, t.category_id, t.amount_minor, "
            "t.type, t.occurred_at, t.description, a.currency, t.project_id, t.recipient_json "
            "FROM transactions t JOIN accounts a ON a.id = t.account_id "
            "WHERE t.kind IN ('income','expense','transfer') "
            "ORDER BY t.occurred_at DESC, t.created_at DESC"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(Transaction(
            query.value(0).toString(), query.value(1).toString(),
            query.value(2).toString(),
            Money(query.value(3).toLongLong(),
                  currencyFromCode(query.value(7).toString())),
            query.value(4).toInt() == 0
                ? TransactionType::Income : TransactionType::Expense,
            QDateTime::fromMSecsSinceEpoch(
                query.value(5).toLongLong(), QTimeZone::UTC),
            query.value(6).toString(),
            query.value(8).toString(), TransactionRecipient::deserialize(query.value(9).toString())));
    }
    return result;
}

QVector<DepositSettings> FinanceRepository::loadDepositSettings()
{
    QVector<DepositSettings> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT d.account_id, d.annual_rate_bps, d.payout_frequency, "
            "       d.payout_day, d.starts_on, d.generated_through "
            "FROM deposit_settings d "
            "JOIN accounts a ON a.id = d.account_id "
            "WHERE a.is_archived = 0 AND a.account_type = 7 "
            "ORDER BY a.created_at, d.account_id"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(DepositSettings(
            query.value(0).toString(),
            query.value(1).toInt(),
            query.value(2).toInt() == 1
                ? DepositPayoutFrequency::Daily
                : DepositPayoutFrequency::Monthly,
            query.value(3).toInt(),
            QDate::fromString(query.value(4).toString(), Qt::ISODate),
            QDate::fromString(query.value(5).toString(), Qt::ISODate)));
    }
    return result;
}

QVector<Account> FinanceRepository::loadAccounts()
{
    QVector<Account> result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT id, name, asset_type, account_type, currency, "
            "       initial_balance_minor, credit_limit_minor, counts_debt "
            "FROM accounts WHERE is_archived = 0 "
            "ORDER BY asset_type, created_at, name COLLATE NOCASE"))) {
        setLastError(query.lastError().text());
        return result;
    }

    while (query.next()) {
        result.append(Account(
            query.value(0).toString(),
            query.value(1).toString(),
            assetTypeFromInt(query.value(2).toInt()),
            static_cast<AccountType>(query.value(3).toInt()),
            currencyFromCode(query.value(4).toString()),
            query.value(5).toLongLong(),
            query.value(6).toLongLong(),
            query.value(7).toInt() != 0));
    }
    return result;
}

FinanceRepository::Summary FinanceRepository::loadSummary()
{
    Summary summary;

    QSqlQuery accounts(database_);
    if (!accounts.exec(QStringLiteral(
            "SELECT a.currency, "
            "       SUM(a.initial_balance_minor + COALESCE(t.net_amount, 0)) "
            "FROM accounts a "
            "LEFT JOIN ("
            "    SELECT account_id, "
            "           SUM(CASE "
            "                   WHEN type = 0 THEN amount_minor "
            "                   WHEN type = 1 THEN -amount_minor "
            "               END) AS net_amount "
            "    FROM transactions "
            "    GROUP BY account_id"
            ") t ON t.account_id = a.id "
            "WHERE a.is_archived = 0 "
            "GROUP BY a.currency"))) {
        setLastError(accounts.lastError().text());
        return summary;
    }

    while (accounts.next()) {
        const Currency currency = currencyFromCode(accounts.value(0).toString());
        summary.balance[currencyIndex(currency)] = accounts.value(1).toLongLong();
    }

    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT t.type, a.currency, SUM(t.amount_minor), t.category_id "
            "FROM transactions t JOIN accounts a ON a.id = t.account_id "
            "WHERE a.is_archived = 0 AND t.kind IN ('income','expense','coupon','dividend','fee','tax') "
            "GROUP BY t.type, a.currency, t.category_id"))) {
        setLastError(query.lastError().text());
        return summary;
    }

    while (query.next()) {
        const QString categoryId = query.value(3).toString();
        if (categoryId == QStringLiteral("transfer-in") ||
            categoryId == QStringLiteral("transfer-out")) {
            continue;
        }
        const int type = query.value(0).toInt();
        const Currency currency = currencyFromCode(query.value(1).toString());
        auto& values = type == 0 ? summary.income : summary.expense;
        const qint64 amount = query.value(2).toLongLong();
        values[currencyIndex(currency)] += amount;
    }
    return summary;
}

bool FinanceRepository::insertTransaction(const Transaction& transaction)
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (isTransferCategory(transaction.categoryId()) &&
        !ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }

    QSqlQuery query(database_);
    prepareTransactionInsert(query);

    if (!insertTransactionRow(
            query,
            transaction,
            QDateTime::currentDateTimeUtc().toMSecsSinceEpoch()) ||
        !database_.commit()) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::insertTransfer(
    const Transaction& outgoing,
    const Transaction& incoming
    )
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (!ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }

    QSqlQuery query(database_);
    prepareTransactionInsert(query);
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();

    if (!insertTransactionRow(query, outgoing, createdAt) ||
        !insertTransactionRow(query, incoming, createdAt) ||
        !database_.commit()) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::insertTransactions(
    const QVector<Transaction>& transactions,
    const QVector<BankCategoryRule>& rules,
    const QVector<BankRecipientRule>& recipientRules,
    const QMap<QString, QString>& bankLinks,
    const QSet<QString>& replacedBankTransactions
    )
{
    if (transactions.isEmpty() && rules.isEmpty() && recipientRules.isEmpty() && bankLinks.isEmpty()
        && replacedBankTransactions.isEmpty()) {
        return true;
    }
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    bool containsTransfer = false;
    for (const Transaction& transaction : transactions) {
        if (isTransferCategory(transaction.categoryId())) {
            containsTransfer = true;
            break;
        }
    }
    QString error;
    if (containsTransfer && !ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }

    QSqlQuery remove(database_);
    remove.prepare(QStringLiteral("DELETE FROM transactions WHERE id=? AND id LIKE 'bankcsv-%' "
        "AND category_id NOT IN ('transfer-in','transfer-out') AND COALESCE(project_id,'')=''"));
    for (const auto& id : replacedBankTransactions) {
        if (!bankLinks.contains(id)) {
            setLastError(QStringLiteral("Не сохранена связь заменяемой банковской операции"));
            database_.rollback(); return false;
        }
        remove.bindValue(0, id);
        if (!remove.exec() || remove.numRowsAffected() != 1) {
            setLastError(QStringLiteral("Банковская операция для объединения изменилась"));
            database_.rollback(); return false;
        }
    }
    QSqlQuery query(database_);
    prepareTransactionInsert(query);
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    for (const Transaction& transaction : transactions) {
        if (!insertTransactionRow(query, transaction, createdAt)) {
            setLastError(query.lastError().text());
            database_.rollback();
            return false;
        }
    }
    // Transactions and remembered choices are committed together.
    QSqlQuery ruleQuery(database_);
    ruleQuery.prepare(QStringLiteral(
        "INSERT INTO bank_category_rules(pattern,match_mode,type,category_id,match_field) "
        "SELECT ?,?,?,id,? FROM categories WHERE id=? AND type=? AND is_archived=0 "
        "AND id NOT IN ('transfer-in','transfer-out') "
        "ON CONFLICT(pattern,match_mode,type) DO UPDATE SET category_id=excluded.category_id,match_field=excluded.match_field"));
    for (const auto& rule : rules) {
        const QString pattern = rule.pattern.trimmed();
        if (pattern.isEmpty() || (rule.matchMode != QStringLiteral("exact") &&
            rule.matchMode != QStringLiteral("contains"))) {
            setLastError(QStringLiteral("Некорректное правило категорий"));
            database_.rollback(); return false;
        }
        const int type = rule.type == CategoryType::Income ? 0 : 1;
        ruleQuery.bindValue(0, pattern); ruleQuery.bindValue(1, rule.matchMode);
        ruleQuery.bindValue(2, type); ruleQuery.bindValue(3, rule.field);
        ruleQuery.bindValue(4, rule.categoryId); ruleQuery.bindValue(5, type);
        if (!ruleQuery.exec() || ruleQuery.numRowsAffected() != 1) {
            setLastError(ruleQuery.lastError().isValid() ? ruleQuery.lastError().text()
                         : QStringLiteral("Категория правила недоступна"));
            database_.rollback(); return false;
        }
    }
    QSqlQuery recipientQuery(database_);
    recipientQuery.prepare(QStringLiteral(
        "INSERT INTO bank_recipient_rules(pattern,match_field,match_mode,type,recipient_name) VALUES(?,?,?,?,?) "
        "ON CONFLICT(pattern,match_field,match_mode,type) DO UPDATE SET recipient_name=excluded.recipient_name"));
    for (const auto& rule : recipientRules) {
        const auto pattern = rule.pattern.trimmed();
        const auto name = rule.name.trimmed();
        if (pattern.isEmpty() || pattern.size() > 240 || name.isEmpty() || name.size() > 160 ||
            (rule.field == "recipient_id" && rule.matchMode != "exact")) {
            setLastError(QStringLiteral("Некорректное правило получателя"));
            database_.rollback();
            return false;
        }
        recipientQuery.bindValue(0, pattern);
        recipientQuery.bindValue(1, rule.field);
        recipientQuery.bindValue(2, rule.matchMode);
        recipientQuery.bindValue(3, rule.type == CategoryType::Income ? 0 : 1);
        recipientQuery.bindValue(4, name);
        if (!recipientQuery.exec()) {
            setLastError(recipientQuery.lastError().text());
            database_.rollback();
            return false;
        }
        recipientQuery.finish();
    }

    QSqlQuery link(database_);
    link.prepare(QStringLiteral("INSERT INTO bank_import_links(row_key,transaction_id) "
        "SELECT ?,id FROM transactions WHERE id=? AND category_id IN ('transfer-in','transfer-out')"));
    for (auto it = bankLinks.cbegin(); it != bankLinks.cend(); ++it) {
        link.bindValue(0, it.key()); link.bindValue(1, it.value());
        if (!link.exec() || link.numRowsAffected() != 1) {
            setLastError(link.lastError().isValid() ? link.lastError().text()
                : QStringLiteral("Не найдена сторона перевода для банковской операции"));
            database_.rollback(); return false;
        }
    }
    if (!database_.commit()) {
        setLastError(database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::updateTransaction(const Transaction& transaction)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE transactions "
        "SET account_id = ?, category_id = ?, type = ?, amount_minor = ?, "
        "    occurred_at = ?, description = ?, project_id = ?, recipient_json = ?, kind = ? "
        "WHERE id = ? AND kind IN ('income','expense','transfer')"));
    query.addBindValue(transaction.accountId());
    query.addBindValue(transaction.categoryId());
    query.addBindValue(transaction.type() == TransactionType::Income ? 0 : 1);
    query.addBindValue(transaction.money().minorUnits());
    query.addBindValue(transaction.date().toMSecsSinceEpoch());
    query.addBindValue(transaction.description().isNull() ? QStringLiteral("") : transaction.description());
    if (transaction.projectId().isEmpty()) {
        query.addBindValue(QVariant());
    } else {
        query.addBindValue(transaction.projectId());
    }
    query.addBindValue(transaction.recipient().serialize());
    query.addBindValue(fiatKindFor(transaction.categoryId(), transaction.type() == TransactionType::Income ? 0 : 1));
    query.addBindValue(transaction.id());

    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral("Transaction was not found"));
        return false;
    }
    return true;
}

bool FinanceRepository::replaceTransaction(
    const QString& currentId,
    const Transaction& replacement
    )
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (isTransferCategory(replacement.categoryId()) &&
        !ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }
    const auto bankLinks = bankLinksForOperation(database_, currentId, error);
    if (!error.isEmpty()) { setLastError(error); database_.rollback(); return false; }
    QSqlQuery insertion(database_);
    prepareTransactionInsert(insertion);
    const bool succeeded =
        deleteOperationRows(database_, currentId, error) &&
        insertTransactionRow(
            insertion,
            replacement,
            QDateTime::currentDateTimeUtc().toMSecsSinceEpoch()) &&
        restoreBankLinks(database_, bankLinks, replacement.id(), replacement.id(), error);

    if (!succeeded || !database_.commit()) {
        if (error.isEmpty()) {
            error = insertion.lastError().isValid()
                ? insertion.lastError().text()
                : database_.lastError().text();
        }
        setLastError(error);
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::replaceTransactionWithTransfer(
    const QString& currentId,
    const Transaction& outgoing,
    const Transaction& incoming
    )
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (!ensureTransferCategories(database_, error)) {
        setLastError(error);
        database_.rollback();
        return false;
    }
    const auto bankLinks = bankLinksForOperation(database_, currentId, error);
    if (!error.isEmpty()) { setLastError(error); database_.rollback(); return false; }
    QSqlQuery insertion(database_);
    prepareTransactionInsert(insertion);
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    const bool succeeded =
        deleteOperationRows(database_, currentId, error) &&
        insertTransactionRow(insertion, outgoing, createdAt) &&
        insertTransactionRow(insertion, incoming, createdAt) &&
        restoreBankLinks(database_, bankLinks, outgoing.id(), incoming.id(), error);

    if (!succeeded || !database_.commit()) {
        if (error.isEmpty()) {
            error = insertion.lastError().isValid()
                ? insertion.lastError().text()
                : database_.lastError().text();
        }
        setLastError(error);
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::deleteTransaction(const QString& id)
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QString error;
    if (!deleteOperationRows(database_, id, error) || !database_.commit()) {
        setLastError(error.isEmpty() ? database_.lastError().text() : error);
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::deleteHistoryRows(const QVariantList& rows)
{
    if (rows.isEmpty() || !database_.transaction()) {
        setLastError(QStringLiteral("No selection or database transaction unavailable"));
        return false;
    }
    QSet<QString> removedTransactions;
    QSet<QString> processed;
    QString error;
    const auto fail = [&](const QString& message) {
        setLastError(message);
        database_.rollback();
        return false;
    };
    for (const QVariant& value : rows) {
        const QVariantMap row = value.toMap();
        if (row.value(QStringLiteral("investmentTransfer")).toBool())
            return fail(QStringLiteral("Инвестиционная операция связана с количеством позиции; удаление отдельно от позиции не поддерживается"));
        const QString id = row.value(QStringLiteral("id")).toString();
        const QString type = row.value(QStringLiteral("type")).toString();
        const QString cryptoId = row.value(QStringLiteral("transactionId")).toString();
        const QString walletId = row.value(QStringLiteral("walletId")).toString();
        if (row.value("isExchange").toBool()) {
            const QString accountId = row.value("walletId").toString();
            const QString transactionId = row.value("transactionId").toString();
            QSqlQuery lookup(database_);
            lookup.prepare(QStringLiteral("SELECT history_json FROM crypto_exchanges WHERE id = ? AND is_archived = 0"));
            lookup.addBindValue(accountId);
            if (!lookup.exec() || !lookup.next()) return fail(QStringLiteral("Exchange account not found"));
            QVariantList history;
            for (const auto& value : QJsonDocument::fromJson(lookup.value(0).toByteArray()).array().toVariantList())
                if (value.toMap().value("transactionId").toString() != transactionId) history.append(value);
            lookup.finish();
            QSqlQuery update(database_);
            update.prepare(QStringLiteral("UPDATE crypto_exchanges SET history_json = ? WHERE id = ?"));
            update.addBindValue(QString::fromUtf8(QJsonDocument(QJsonArray::fromVariantList(history)).toJson(QJsonDocument::Compact)));
            update.addBindValue(accountId);
            if (!update.exec()) return fail(update.lastError().text());
        } else if (!cryptoId.isEmpty()) {
            if (walletId.isEmpty()) return fail(QStringLiteral("Missing crypto wallet"));
            const QString key = QStringLiteral("crypto:") + walletId + ':' + cryptoId;
            if (processed.contains(key)) continue;
            processed.insert(key);
            QSqlQuery query(database_);
            query.prepare(QStringLiteral("DELETE FROM crypto_transactions WHERE wallet_id = ? AND transaction_id = ?"));
            query.addBindValue(walletId);
            query.addBindValue(cryptoId);
            if (!query.exec() || query.numRowsAffected() != 1)
                return fail(query.lastError().isValid() ? query.lastError().text() : QStringLiteral("Crypto operation not found"));
        } else if (type == QStringLiteral("investment_position")) {
            if (id.isEmpty()) return fail(QStringLiteral("Missing investment position"));
            const QString key = QStringLiteral("investment:") + id;
            if (processed.contains(key)) continue;
            processed.insert(key);
            InvestmentRepository investments(db_);
            if (!investments.deleteInvestmentPosition(id)) return fail(investments.lastError());
        } else if (type == QStringLiteral("investment_cash")) {
            return fail(QStringLiteral("Инвестиционная операция связана с количеством позиции; удаление отдельно от позиции не поддерживается"));
        } else {
            if (id.isEmpty()) return fail(QStringLiteral("Missing operation"));
            if (removedTransactions.contains(id)) continue;
            QSqlQuery lookup(database_);
            lookup.prepare(QStringLiteral("SELECT category_id FROM transactions WHERE id = ?"));
            lookup.addBindValue(id);
            if (!lookup.exec() || !lookup.next()) return fail(QStringLiteral("Operation not found"));
            const auto pair = transferComponentIds(id, lookup.value(0).toString());
            lookup.finish();
            if (!deleteOperationRows(database_, id, error)) return fail(error);
            removedTransactions.insert(id);
            if (pair.valid) {
                removedTransactions.insert(pair.outgoing);
                removedTransactions.insert(pair.incoming);
            }
        }
    }
    if (!database_.commit()) return fail(database_.lastError().text());
    return true;
}

bool FinanceRepository::materializeRecurringOccurrences(
    const QString& recurringId,
    const QVector<RecurringOccurrence>& occurrences,
    const QDate& generatedThrough,
    int* insertedCount
    )
{
    if (recurringId.isEmpty() || !generatedThrough.isValid()) {
        setLastError(QStringLiteral("Invalid recurring materialization range"));
        return false;
    }
    if (insertedCount) {
        *insertedCount = 0;
    }
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QSqlQuery occurrenceLookup(database_);
    occurrenceLookup.prepare(QStringLiteral(
        "SELECT 1 FROM recurring_transaction_occurrences "
        "WHERE recurring_id = ? AND occurrence_date = ?"));
    QSqlQuery transactionInsert(database_);
    prepareTransactionInsert(transactionInsert);
    QSqlQuery occurrenceInsert(database_);
    occurrenceInsert.prepare(QStringLiteral(
        "INSERT INTO recurring_transaction_occurrences("
        "recurring_id, occurrence_date, transaction_id) "
        "VALUES (?, ?, ?)"));
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    int inserted = 0;

    for (const RecurringOccurrence& occurrence : occurrences) {
        const QString date = occurrence.date.toString(Qt::ISODate);
        occurrenceLookup.bindValue(0, recurringId);
        occurrenceLookup.bindValue(1, date);
        if (!occurrenceLookup.exec()) {
            setLastError(occurrenceLookup.lastError().text());
            database_.rollback();
            return false;
        }
        const bool alreadyCreated = occurrenceLookup.next();
        occurrenceLookup.finish();
        if (alreadyCreated) {
            continue;
        }

        if (!insertTransactionRow(
                transactionInsert, occurrence.transaction, createdAt)) {
            setLastError(transactionInsert.lastError().text());
            database_.rollback();
            return false;
        }
        occurrenceInsert.bindValue(0, recurringId);
        occurrenceInsert.bindValue(1, date);
        occurrenceInsert.bindValue(2, occurrence.transaction.id());
        if (!occurrenceInsert.exec()) {
            setLastError(occurrenceInsert.lastError().text());
            database_.rollback();
            return false;
        }
        ++inserted;
    }

    QSqlQuery progress(database_);
    progress.prepare(QStringLiteral(
        "UPDATE recurring_transactions SET generated_through = CASE "
        "WHEN generated_through < ? THEN ? ELSE generated_through END, "
        "updated_at = ? WHERE id = ?"));
    const QString through = generatedThrough.toString(Qt::ISODate);
    progress.addBindValue(through);
    progress.addBindValue(through);
    progress.addBindValue(createdAt);
    progress.addBindValue(recurringId);
    if (!progress.exec() || progress.numRowsAffected() != 1 ||
        !database_.commit()) {
        setLastError(progress.lastError().isValid()
                         ? progress.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    if (insertedCount) {
        *insertedCount = inserted;
    }
    return true;
}

namespace
{
bool upsertDepositSettings(
    QSqlDatabase& database,
    const DepositSettings& settings,
    QString& error
    )
{
    QSqlQuery query(database);
    query.prepare(QStringLiteral(
        "INSERT INTO deposit_settings("
        "account_id, annual_rate_bps, payout_frequency, payout_day, "
        "starts_on, generated_through, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(account_id) DO UPDATE SET "
        "annual_rate_bps = excluded.annual_rate_bps, "
        "payout_frequency = excluded.payout_frequency, "
        "payout_day = excluded.payout_day, "
        "starts_on = excluded.starts_on, "
        "generated_through = excluded.generated_through, "
        "updated_at = excluded.updated_at"));
    query.addBindValue(settings.accountId());
    query.addBindValue(settings.annualRateBasisPoints());
    query.addBindValue(
        settings.payoutFrequency() == DepositPayoutFrequency::Daily ? 1 : 0);
    query.addBindValue(settings.payoutDay());
    query.addBindValue(settings.startsOn().toString(Qt::ISODate));
    query.addBindValue(settings.generatedThrough().toString(Qt::ISODate));
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    if (!query.exec()) {
        error = query.lastError().text();
        return false;
    }
    return true;
}
}

bool FinanceRepository::insertAccount(const Account& account)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "INSERT INTO accounts(id, name, asset_type, account_type, currency, "
        "initial_balance_minor, credit_limit_minor, counts_debt, is_archived, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)"));
    query.addBindValue(account.id());
    query.addBindValue(account.name());
    query.addBindValue(static_cast<int>(account.assetType()));
    query.addBindValue(static_cast<int>(account.type()));
    query.addBindValue(currencyCode(account.currency()));
    query.addBindValue(account.initialBalanceMinor());
    query.addBindValue(account.creditLimitMinor());
    query.addBindValue(account.countsDebt() ? 1 : 0);
    query.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());

    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

bool FinanceRepository::insertDepositAccount(
    const Account& account,
    const DepositSettings& settings
    )
{
    if (account.type() != AccountType::Deposit ||
        account.id() != settings.accountId() ||
        !database_.transaction()) {
        setLastError(database_.lastError().isValid()
            ? database_.lastError().text()
            : QStringLiteral("Invalid deposit account"));
        return false;
    }

    QString error;
    if (!insertAccount(account) ||
        !upsertDepositSettings(database_, settings, error) ||
        !database_.commit()) {
        if (!error.isEmpty()) {
            setLastError(error);
        } else if (database_.lastError().isValid()) {
            setLastError(database_.lastError().text());
        }
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::updateAccount(const Account& account)
{
    QSqlQuery query(database_);
    query.prepare(QStringLiteral(
        "UPDATE accounts "
        "SET name = ?, asset_type = ?, account_type = ?, currency = ?, "
        "    initial_balance_minor = ?, credit_limit_minor = ?, counts_debt = ? "
        "WHERE id = ? AND is_archived = 0 "
        "  AND (currency = ? OR NOT EXISTS ("
        "      SELECT 1 FROM transactions WHERE account_id = ?"
        "  )) AND (currency = ? OR NOT EXISTS (SELECT 1 FROM transactions WHERE account_id = ? AND kind IN ('buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry'))) "
        "AND (account_type = ? OR NOT EXISTS (SELECT 1 FROM transactions WHERE account_id = ? AND kind IN ('buy','sell','coupon','dividend','amortization','fee','tax','margin','expiry')))"));
    query.addBindValue(account.name());
    query.addBindValue(static_cast<int>(account.assetType()));
    query.addBindValue(static_cast<int>(account.type()));
    query.addBindValue(currencyCode(account.currency()));
    query.addBindValue(account.initialBalanceMinor());
    query.addBindValue(account.creditLimitMinor());
    query.addBindValue(account.countsDebt() ? 1 : 0);
    query.addBindValue(account.id());
    query.addBindValue(currencyCode(account.currency()));
    query.addBindValue(account.id());

    query.addBindValue(currencyCode(account.currency()));
    query.addBindValue(account.id());
    query.addBindValue(static_cast<int>(account.type()));
    query.addBindValue(account.id());
    if (!query.exec() || query.numRowsAffected() != 1) {
        setLastError(query.lastError().isValid()
                         ? query.lastError().text()
                         : QStringLiteral(
                               "Account was not found or its currency cannot be changed"));
        return false;
    }
    return true;
}

bool FinanceRepository::updateAccountAndDeposit(
    const Account& account,
    const std::optional<DepositSettings>& settings
    )
{
    if ((account.type() == AccountType::Deposit) != settings.has_value() ||
        (settings && settings->accountId() != account.id()) ||
        !database_.transaction()) {
        setLastError(database_.lastError().isValid()
            ? database_.lastError().text()
            : QStringLiteral("Invalid deposit settings"));
        return false;
    }

    QString error;
    bool settingsSaved = false;
    if (settings) {
        settingsSaved = upsertDepositSettings(database_, *settings, error);
    } else {
        QSqlQuery deletion(database_);
        deletion.prepare(QStringLiteral(
            "DELETE FROM deposit_settings WHERE account_id = ?"));
        deletion.addBindValue(account.id());
        settingsSaved = deletion.exec();
        if (!settingsSaved) {
            error = deletion.lastError().text();
        }
    }

    if (!updateAccount(account) || !settingsSaved || !database_.commit()) {
        if (!error.isEmpty()) {
            setLastError(error);
        } else if (database_.lastError().isValid()) {
            setLastError(database_.lastError().text());
        }
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::deleteAccount(const QString& id)
{
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    QSqlQuery recurring(database_);
    recurring.prepare(QStringLiteral(
        "DELETE FROM recurring_transactions WHERE account_id = ?"));
    recurring.addBindValue(id);
    if (!recurring.exec()) {
        setLastError(recurring.lastError().text());
        database_.rollback();
        return false;
    }

    QSqlQuery deposit(database_);
    deposit.prepare(QStringLiteral(
        "DELETE FROM deposit_settings WHERE account_id = ?"));
    deposit.addBindValue(id);
    if (!deposit.exec()) {
        setLastError(deposit.lastError().text());
        database_.rollback();
        return false;
    }

    QSqlQuery lookup(database_);
    lookup.prepare(QStringLiteral(
        "SELECT id FROM transactions WHERE account_id = ?"));
    lookup.addBindValue(id);
    if (!lookup.exec()) {
        setLastError(lookup.lastError().text());
        database_.rollback();
        return false;
    }

    QStringList transactionIds;
    while (lookup.next()) {
        transactionIds.append(lookup.value(0).toString());
    }
    lookup.finish();

    QString error;
    QSqlQuery existence(database_);
    existence.prepare(QStringLiteral(
        "SELECT 1 FROM transactions WHERE id = ?"));
    for (const QString& transactionId : transactionIds) {
        existence.bindValue(0, transactionId);
        if (!existence.exec()) {
            setLastError(existence.lastError().text());
            database_.rollback();
            return false;
        }
        const bool stillExists = existence.next();
        existence.finish();
        if (!stillExists) {
            continue;
        }
        if (!deleteOperationRows(database_, transactionId, error)) {
            setLastError(error);
            database_.rollback();
            return false;
        }
    }

    QStringList positionIds;
    QSqlQuery positionLookup(database_);positionLookup.prepare("SELECT id FROM investment_positions WHERE account_id=? AND is_archived=0");positionLookup.addBindValue(id);
    if(!positionLookup.exec()){setLastError(positionLookup.lastError().text());database_.rollback();return false;}
    while(positionLookup.next())positionIds.append(positionLookup.value(0).toString());positionLookup.finish();

    QSqlQuery positions(database_);
    positions.prepare(QStringLiteral(
        "UPDATE investment_positions "
        "SET is_archived = 1, updated_at = ? "
        "WHERE account_id = ? AND is_archived = 0"));
    positions.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
    positions.addBindValue(id);
    if (!positions.exec()) {
        setLastError(positions.lastError().text());
        database_.rollback();
        return false;
    }

    InvestmentRepository investments(db_);
    for(const auto& positionId:positionIds)if(!investments.appendPositionState(positionId,"archive")){setLastError(investments.lastError());database_.rollback();return false;}

    QSqlQuery account(database_);
    account.prepare(QStringLiteral(
        "UPDATE accounts SET is_archived = 1 "
        "WHERE id = ? AND is_archived = 0"));
    account.addBindValue(id);
    if (!account.exec() || account.numRowsAffected() != 1 ||
        !database_.commit()) {
        setLastError(account.lastError().isValid()
                         ? account.lastError().text()
                         : database_.lastError().text());
        database_.rollback();
        return false;
    }
    return true;
}

bool FinanceRepository::materializeDepositInterest(
    const DepositSettings& settings,
    const QVector<DepositInterestOccurrence>& occurrences,
    const QDate& generatedThrough,
    int* insertedCount
    )
{
    if (settings.accountId().isEmpty() || !generatedThrough.isValid()) {
        setLastError(QStringLiteral("Invalid deposit materialization range"));
        return false;
    }
    if (insertedCount) {
        *insertedCount = 0;
    }
    if (!database_.transaction()) {
        setLastError(database_.lastError().text());
        return false;
    }

    // Older or cleared databases may not contain this built-in category.
    // Create it atomically with the interest; preserve an existing user's category.
    if (!occurrences.isEmpty()) {
        QSqlQuery category(database_);
        category.prepare(QStringLiteral(
            "INSERT OR IGNORE INTO categories(id,name,type,is_system,created_at) "
            "VALUES ('deposit_interest', 'Проценты по вкладу', 0, 1, ?)"));
        category.addBindValue(QDateTime::currentDateTimeUtc().toMSecsSinceEpoch());
        if (!category.exec()) {
            setLastError(category.lastError().text());
            database_.rollback();
            return false;
        }
    }

    QSqlQuery occurrenceLookup(database_);
    occurrenceLookup.prepare(QStringLiteral(
        "SELECT 1 FROM deposit_interest_occurrences "
        "WHERE account_id = ? AND occurrence_date = ?"));
    QSqlQuery transactionInsert(database_);
    prepareTransactionInsert(transactionInsert);
    QSqlQuery occurrenceInsert(database_);
    occurrenceInsert.prepare(QStringLiteral(
        "INSERT INTO deposit_interest_occurrences("
        "account_id, occurrence_date, transaction_id) VALUES (?, ?, ?)"));
    const qint64 createdAt = QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
    int inserted = 0;

    for (const DepositInterestOccurrence& occurrence : occurrences) {
        const QString date = occurrence.date.toString(Qt::ISODate);
        occurrenceLookup.bindValue(0, settings.accountId());
        occurrenceLookup.bindValue(1, date);
        if (!occurrenceLookup.exec()) {
            setLastError(occurrenceLookup.lastError().text());
            database_.rollback();
            return false;
        }
        const bool alreadyCreated = occurrenceLookup.next();
        occurrenceLookup.finish();
        if (alreadyCreated) {
            continue;
        }

        if (!insertTransactionRow(
                transactionInsert, occurrence.transaction, createdAt)) {
            setLastError(transactionInsert.lastError().text());
            database_.rollback();
            return false;
        }
        occurrenceInsert.bindValue(0, settings.accountId());
        occurrenceInsert.bindValue(1, date);
        occurrenceInsert.bindValue(2, occurrence.transaction.id());
        if (!occurrenceInsert.exec()) {
            setLastError(occurrenceInsert.lastError().text());
            database_.rollback();
            return false;
        }
        ++inserted;
    }

    QSqlQuery progress(database_);
    progress.prepare(QStringLiteral(
        "UPDATE deposit_settings SET generated_through = CASE "
        "WHEN generated_through < ? THEN ? ELSE generated_through END, "
        "updated_at = ? WHERE account_id = ?"));
    const QString through = generatedThrough.toString(Qt::ISODate);
    progress.addBindValue(through);
    progress.addBindValue(through);
    progress.addBindValue(createdAt);
    progress.addBindValue(settings.accountId());
    if (!progress.exec() || progress.numRowsAffected() != 1 ||
        !database_.commit()) {
        setLastError(progress.lastError().isValid()
            ? progress.lastError().text()
            : database_.lastError().text());
        database_.rollback();
        return false;
    }
    if (insertedCount) {
        *insertedCount = inserted;
    }
    return true;
}

QVariantMap FinanceRepository::loadDepositRateSteps() const
{
    static const QString prefix = QStringLiteral("deposit_rate_steps:");
    QVariantMap result;
    QSqlQuery query(database_);
    if (!query.exec(QStringLiteral(
            "SELECT key, value FROM settings WHERE key LIKE 'deposit_rate_steps:%'"))) {
        return result;
    }
    while (query.next()) {
        const QString accountId = query.value(0).toString().mid(prefix.size());
        result.insert(accountId, QJsonDocument::fromJson(query.value(1).toByteArray()).array().toVariantList());
    }
    return result;
}

bool FinanceRepository::saveDepositRateSteps(const QString& accountId, const QVariantList& steps)
{
    const QString key = QStringLiteral("deposit_rate_steps:") + accountId;
    QSqlQuery query(database_);
    if (steps.isEmpty()) {
        query.prepare(QStringLiteral("DELETE FROM settings WHERE key = ?"));
        query.addBindValue(key);
    } else {
        query.prepare(QStringLiteral(
            "INSERT INTO settings(key, value) VALUES(?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
        query.addBindValue(key);
        query.addBindValue(QString::fromUtf8(QJsonDocument(QJsonArray::fromVariantList(steps))
                                                 .toJson(QJsonDocument::Compact)));
    }
    if (!query.exec()) {
        setLastError(query.lastError().text());
        return false;
    }
    return true;
}

void FinanceRepository::setLastError(const QString& error) { lastError_ = error; }

