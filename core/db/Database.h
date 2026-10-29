#pragma once
#include "storage/DatabaseEncryption.h"

#include <QSqlDatabase>

#include <functional>

// One SQLCipher connection to the application database.
class Database
{
public:
    // An empty path opens the default database in the application data folder.
    explicit Database(const QString& path = {}, const QByteArray& key = {});
    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;
    ~Database();

    bool isOpen() const;
    void close();

    // Why the database could not be opened, or why the last transaction failed
    QString lastError() const;

    // The resolved file path and the key the connection was opened with
    const DatabaseAccess& access() const;
    QSqlDatabase& connection();

    // Runs fn in one transaction: commits when fn returns true, otherwise rolls back
    bool transaction(const std::function<bool()>& fn);

private:
    DatabaseAccess access_;
    QString connectionName_;
    QSqlDatabase connection_;
    QString lastError_;
};
