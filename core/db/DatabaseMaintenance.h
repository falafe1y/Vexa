#pragma once
#include "Database.h"

#include <QSqlDatabase>
#include <QString>

#include <memory>

// Keeping the whole database: copies, restoring from a copy, clearing all user data,
// and checking that a copy has the schema of this version.
class DatabaseMaintenance
{
public:
    DatabaseMaintenance(Database& database, std::shared_ptr<DatabaseKeyStore> keyStore);

    static bool migrateBackup(const DatabaseAccess& access, const QString& workspace, QString& error);
    bool backupDatabase(const QString& destinationPath);
    // Replace all user data atomically; retain a backup of the previous state.
    bool restoreDatabase(const QString& sourcePath, qint64* restoredRecords = nullptr,
                         QString* previousBackupPath = nullptr);
    bool clearAllUserData();
    QString lastError() const;

private:
    void setLastError(const QString& error);

    Database& db_;
    QSqlDatabase& database_;
    std::shared_ptr<DatabaseKeyStore> keyStore_;
    QString lastError_;
};
