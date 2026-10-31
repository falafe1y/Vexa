#pragma once
#include "Database.h"

#include <QByteArray>
#include <QSqlDatabase>
#include <QString>

// The application database, opened and brought to the current schema: tables created or migrated,
// built-in rows added. The repositories work with its connection.
class PreparedDatabase
{
public:
    // An empty path opens the default database in the application data folder
    explicit PreparedDatabase(const QString& path = {}, const QByteArray& key = {});

    PreparedDatabase(const PreparedDatabase&) = delete;
    PreparedDatabase& operator=(const PreparedDatabase&) = delete;

    bool isOpen() const;
    QString lastError() const;
    QString databasePath() const;
    Database& database();

private:
    Database db_;
    QSqlDatabase& database_; // the connection of db_
    QString lastError_;
};
