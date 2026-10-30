#pragma once

#include "Database.h"

#include <QSqlDatabase>
#include <QString>

// The database schema: creates the tables of a new database and migrates an old one
// to the current schema, then adds the built-in rows.
// Errors are written to the string given to the constructor.
class DatabaseSchema
{
public:
    DatabaseSchema(Database& database, QString& lastError);

    // Creates what is missing and migrates an old database; stops at the first failure
    bool prepare();
    // Adds the built-in rows and settings a database must have
    bool seedDefaults();
    // Daily snapshots, price and position history; also run on its own when an old backup is restored
    bool migrateAnalyticsHistorySchema();

private:
    bool initializeSchema();
    bool migrateLegacySchema();
    bool migrateInvestmentSchema();
    bool migrateBankImportSchema();
    bool migrateLedgerSchema();
    bool migrateTaxKind();
    bool migrateCurrencySchema();
    bool migrateCreditDebtFlag();
    void setLastError(const QString& error);

    Database& db_;
    QSqlDatabase& database_;
    QString& lastError_;
};
