#include "Database.h"

#include <QSqlDatabase>
#include <QSqlError>
#include <QUuid>

#include <stdexcept>

namespace core::db {

Database::Database(const QString& filePath)
{
    if (filePath.isEmpty()) {
        throw std::invalid_argument("Database path must not be empty");
    }

    try {
        auto connection = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"));

        connection.setDatabaseName(filePath);

        if (!connection.open()) {
            throw std::runtime_error(
                connection.lastError().text().toStdString()
            );
        }
    } catch (...) {
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnectionName());
        throw;
    }
}

Database::~Database()
{
    QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnectionName());
}

} // namespace core::db
