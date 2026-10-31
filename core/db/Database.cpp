#include "Database.h"
#include "CipherDriver.h"

#include <QDir>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUuid>

Database::Database(const QString& path, const QByteArray& key)
    : access_{path, key}
    , connectionName_(QUuid::createUuid().toString(QUuid::WithoutBraces))
    , connection_(addCipherDatabase(connectionName_, key))
{
    const QString resolvedPath = path.isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            + QStringLiteral("/vexa.sqlite3")
        : path;
    const QString directory = QFileInfo(resolvedPath).absolutePath();

    if (!QDir().mkpath(directory)) {
        lastError_ = QStringLiteral("Cannot create application data directory");
        return;
    }

    access_.path = resolvedPath;
    connection_.setDatabaseName(resolvedPath);
    if (!connection_.open()) {
        lastError_ = connection_.lastError().text();
        return;
    }

    QSqlQuery pragma(connection_);
    if (!pragma.exec(QStringLiteral("PRAGMA foreign_keys = ON"))) {
        lastError_ = pragma.lastError().text();
        connection_.close();
    }
}

Database::~Database()
{
    connection_.close();
    connection_ = QSqlDatabase();
    QSqlDatabase::removeDatabase(connectionName_);
}

bool Database::isOpen() const { return connection_.isOpen(); }
void Database::close() { connection_.close(); }
QString Database::lastError() const { return lastError_; }
const DatabaseAccess& Database::access() const { return access_; }
QSqlDatabase& Database::connection() { return connection_; }

bool Database::transaction(const std::function<bool()>& fn)
{
    if (!connection_.transaction()) {
        lastError_ = connection_.lastError().text();
        return false;
    }
    if (!fn()) {
        connection_.rollback();
        return false;
    }
    if (!connection_.commit()) {
        lastError_ = connection_.lastError().text();
        connection_.rollback();
        return false;
    }
    lastError_.clear();
    return true;
}
