#include "Database.h"

#include <QSqlDatabase>
#include <QSqlError>
#include <QUuid>
#include <QSqlQuery>
#include <QVariant>

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

        createTables();

    } catch (...) {
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnectionName());
        throw;
    }
}

Database::~Database()
{
    QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnectionName());
}

void Database::createTables()
{
    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    const bool success = query.exec(QStringLiteral(R"(
        CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            type INTEGER NOT NULL CHECK (type IN (0, 1, 2)),
            currency_code TEXT NOT NULL,
            opening_balance_minor INTEGER NOT NULL CHECK (typeof(opening_balance_minor) = 'integer'),
            archived INTEGER NOT NULL CHECK (archived IN (0, 1))
        )
    )"));

    if (!success) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }
}

void Database::saveAccount(const core::model::Account& account)
{
    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    const bool prepared = query.prepare(QStringLiteral(R"(
        INSERT INTO accounts (
            id,
            name,
            type,
            currency_code,
            opening_balance_minor,
            archived
        )
        VALUES (
            :id,
            :name,
            :type,
            :currency_code,
            :opening_balance_minor,
            :archived
        )
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            type = excluded.type,
            currency_code = excluded.currency_code,
            opening_balance_minor = excluded.opening_balance_minor,
            archived = excluded.archived
    )"));

    if (!prepared) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    const auto currencyCode = account.currency().code();

    query.bindValue(
        QStringLiteral(":id"),
        account.id().toString(QUuid::WithoutBraces)
        );

    query.bindValue(
        QStringLiteral(":name"),
        account.name()
        );

    query.bindValue(
        QStringLiteral(":type"),
        static_cast<int>(account.type())
        );

    query.bindValue(
        QStringLiteral(":currency_code"),
        QString::fromLatin1(
            currencyCode.data(),
            static_cast<qsizetype>(currencyCode.size())
            )
        );

    query.bindValue(
        QStringLiteral(":opening_balance_minor"),
        account.openingBalance().minorUnits()
        );

    query.bindValue(
        QStringLiteral(":archived"),
        account.isArchived() ? 1 : 0
        );

    if (!query.exec()) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }
}

std::vector<core::model::Account> Database::loadAccounts() const
{
    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    const bool success = query.exec(QStringLiteral(R"(
        SELECT
            id,
            name,
            type,
            currency_code,
            opening_balance_minor,
            archived
        FROM accounts
        ORDER BY id
    )"));

    if (!success) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    std::vector<core::model::Account> accounts;

    while (query.next()) {
        const QUuid id{query.value(0).toString()};
        const QString name = query.value(1).toString();

        const auto type =
            static_cast<core::model::AccountType>(
                query.value(2).toInt()
                );

        const auto currencyCode =
            query.value(3).toString().toStdString();

        const auto currency =
            core::model::Currency::fromCode(currencyCode);

        bool amountValid = false;

        const qint64 openingBalanceMinor =
            query.value(4).toLongLong(&amountValid);

        if (!amountValid) {
            throw std::runtime_error(
                "Invalid account opening balance in database"
                );
        }

        const bool archived = query.value(5).toBool();

        accounts.emplace_back(
            id,
            name,
            type,
            core::model::Money::fromMinorUnits(
                openingBalanceMinor,
                currency
                ),
            archived
            );
    }

    if (query.lastError().isValid()) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    return accounts;
}

} // namespace core::db
