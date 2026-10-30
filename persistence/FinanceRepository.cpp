#include "FinanceRepository.h"
#include "storage/CipherDriver.h"
#include "../core/db/DatabaseSchema.h"

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

void FinanceRepository::setLastError(const QString& error) { lastError_ = error; }

