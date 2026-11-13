#include "Database.h"

#include "Currency.h"
#include "ExchangeRate.h"
#include "Money.h"

#include <QDate>
#include <QMetaType>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

#include <stdexcept>
#include <variant>

namespace core::db {

namespace {

void executeSql(const QString& sql)
{
    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    if (!query.exec(sql)) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }
}

QString toCurrencyCode(core::model::Currency currency)
{
    const auto code = currency.code();

    return QString::fromLatin1(
        code.data(),
        static_cast<qsizetype>(code.size())
        );
}

qint64 readInteger(
    const QSqlQuery& query,
    const QString& columnName)
{
    bool valid = false;

    const qint64 value =
        query.value(columnName).toLongLong(&valid);

    if (!valid) {
        throw std::runtime_error(
            "Invalid integer in column: "
            + columnName.toStdString()
            );
    }

    return value;
}

core::model::Money readMoney(
    const QSqlQuery& query,
    const QString& amountColumn,
    const QString& currencyColumn)
{
    const auto code =
        query.value(currencyColumn).toString().toStdString();

    return core::model::Money::fromMinorUnits(
        readInteger(query, amountColumn),
        core::model::Currency::fromCode(code)
        );
}

void deleteById(const QString& sql, const QUuid& id)
{
    if (id.isNull()) {
        throw std::invalid_argument(
            "ID must not be null"
            );
    }

    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    if (!query.prepare(sql)) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    query.bindValue(
        QStringLiteral(":id"),
        id.toString(QUuid::WithoutBraces)
        );

    if (!query.exec()) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }
}

} // namespace

Database::Database(const QString& filePath)
{
    if (filePath.isEmpty()) {
        throw std::invalid_argument(
            "Database path must not be empty"
            );
    }

    if (QSqlDatabase::contains()) {
        throw std::logic_error(
            "Database connection already exists"
            );
    }

    try {
        auto connection =
            QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"));

        connection.setDatabaseName(filePath);

        if (!connection.open()) {
            throw std::runtime_error(
                connection.lastError().text().toStdString()
                );
        }

        executeSql(QStringLiteral("PRAGMA foreign_keys = ON"));

        createTables();
    } catch (...) {
        QSqlDatabase::removeDatabase(
            QSqlDatabase::defaultConnectionName()
            );

        throw;
    }
}

Database::~Database()
{
    QSqlDatabase::removeDatabase(
        QSqlDatabase::defaultConnectionName()
        );
}

void Database::createTables()
{
    executeSql(QStringLiteral(R"(
        CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            type INTEGER NOT NULL CHECK (type IN (0, 1, 2)),
            currency_code TEXT NOT NULL,

            opening_balance_minor INTEGER NOT NULL
                CHECK (
                    typeof(opening_balance_minor) = 'integer'
                ),

            credit_limit_minor INTEGER NOT NULL DEFAULT 0
                CHECK (
                    typeof(credit_limit_minor) = 'integer'
                    AND credit_limit_minor >= 0
                    AND (type = 2 OR credit_limit_minor = 0)
                ),

            archived INTEGER NOT NULL
                CHECK (archived IN (0, 1))
        )
    )"));

    executeSql(QStringLiteral(R"(
        CREATE TABLE IF NOT EXISTS categories (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            type INTEGER NOT NULL CHECK (type IN (0, 1)),
            archived INTEGER NOT NULL CHECK (archived IN (0, 1))
        )
    )"));

    executeSql(QStringLiteral(R"(
        CREATE TABLE IF NOT EXISTS operations (
            sequence INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            date TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',

            type INTEGER NOT NULL CHECK (type IN (0, 1, 2)),

            account_id TEXT NOT NULL REFERENCES accounts(id),
            category_id TEXT REFERENCES categories(id),

            amount_minor INTEGER NOT NULL
                CHECK (
                    typeof(amount_minor) = 'integer'
                    AND amount_minor > 0
                ),

            currency_code TEXT NOT NULL,

            to_account_id TEXT REFERENCES accounts(id),
            received_amount_minor INTEGER,
            received_currency_code TEXT,
            rate_numerator INTEGER,
            rate_denominator INTEGER,

            CHECK (
                (
                    type IN (0, 1)
                    AND category_id IS NOT NULL
                    AND to_account_id IS NULL
                    AND received_amount_minor IS NULL
                    AND received_currency_code IS NULL
                    AND rate_numerator IS NULL
                    AND rate_denominator IS NULL
                )
                OR
                (
                    type = 2
                    AND category_id IS NULL
                    AND to_account_id IS NOT NULL
                    AND to_account_id <> account_id

                    AND typeof(received_amount_minor) = 'integer'
                    AND received_amount_minor > 0

                    AND received_currency_code IS NOT NULL

                    AND typeof(rate_numerator) = 'integer'
                    AND rate_numerator > 0

                    AND typeof(rate_denominator) = 'integer'
                    AND rate_denominator > 0
                )
            )
        )
    )"));

    // Проверка и изменение схемы выполняются под одной блокировкой записи.
    executeSql(QStringLiteral("BEGIN IMMEDIATE"));
    try {
        QSqlQuery columns{QSqlDatabase::database()};
        if (!columns.exec(QStringLiteral("PRAGMA table_info(operations)"))) {
            throw std::runtime_error(columns.lastError().text().toStdString());
        }

        bool hasDescription = false;
        while (columns.next()) {
            if (columns.value(1).toString() == QStringLiteral("description")) {
                hasDescription = true;
                break;
            }
        }
        if (columns.lastError().isValid()) {
            throw std::runtime_error(columns.lastError().text().toStdString());
        }
        columns.finish();

        if (!hasDescription) {
            executeSql(QStringLiteral(
                "ALTER TABLE operations ADD COLUMN description TEXT NOT NULL DEFAULT ''"));
        }
        executeSql(QStringLiteral("COMMIT"));
    } catch (...) {
        QSqlDatabase::database().rollback();
        throw;
    }
}

void Database::saveAccount(
    const core::model::Account& account)
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
            credit_limit_minor,
            archived
        )
        VALUES (
            :id,
            :name,
            :type,
            :currency_code,
            :opening_balance_minor,
            :credit_limit_minor,
            :archived
        )
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            type = excluded.type,
            currency_code = excluded.currency_code,
            opening_balance_minor = excluded.opening_balance_minor,
            credit_limit_minor = excluded.credit_limit_minor,
            archived = excluded.archived
    )"));

    if (!prepared) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

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
        toCurrencyCode(account.currency())
        );

    query.bindValue(
        QStringLiteral(":opening_balance_minor"),
        account.openingBalance().minorUnits()
        );

    query.bindValue(
        QStringLiteral(":credit_limit_minor"),
        account.creditLimit().minorUnits()
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

void Database::saveCategory(
    const core::model::Category& category)
{
    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    const bool prepared = query.prepare(QStringLiteral(R"(
        INSERT INTO categories (
            id,
            name,
            type,
            archived
        )
        VALUES (
            :id,
            :name,
            :type,
            :archived
        )
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            type = excluded.type,
            archived = excluded.archived
    )"));

    if (!prepared) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    query.bindValue(
        QStringLiteral(":id"),
        category.id().toString(QUuid::WithoutBraces)
        );

    query.bindValue(
        QStringLiteral(":name"),
        category.name()
        );

    query.bindValue(
        QStringLiteral(":type"),
        static_cast<int>(category.type())
        );

    query.bindValue(
        QStringLiteral(":archived"),
        category.isArchived() ? 1 : 0
        );

    if (!query.exec()) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }
}

void Database::saveOperation(
    const core::model::Operation& operation)
{
    using core::model::Money;
    using core::model::Operation;

    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    const bool prepared = query.prepare(QStringLiteral(R"(
        INSERT INTO operations (
            id,
            date,
            description,
            type,
            account_id,
            category_id,
            amount_minor,
            currency_code,
            to_account_id,
            received_amount_minor,
            received_currency_code,
            rate_numerator,
            rate_denominator
        )
        VALUES (
            :id,
            :date,
            COALESCE(:description, ''),
            :type,
            :account_id,
            :category_id,
            :amount_minor,
            :currency_code,
            :to_account_id,
            :received_amount_minor,
            :received_currency_code,
            :rate_numerator,
            :rate_denominator
        )
        ON CONFLICT(id) DO UPDATE SET
            date = excluded.date,
            description = excluded.description,
            type = excluded.type,
            account_id = excluded.account_id,
            category_id = excluded.category_id,
            amount_minor = excluded.amount_minor,
            currency_code = excluded.currency_code,
            to_account_id = excluded.to_account_id,
            received_amount_minor = excluded.received_amount_minor,
            received_currency_code = excluded.received_currency_code,
            rate_numerator = excluded.rate_numerator,
            rate_denominator = excluded.rate_denominator
    )"));

    if (!prepared) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    query.bindValue(
        QStringLiteral(":id"),
        operation.id().toString(QUuid::WithoutBraces)
        );

    query.bindValue(
        QStringLiteral(":date"),
        operation.date().toString(Qt::ISODate)
        );

    query.bindValue(QStringLiteral(":description"), operation.description());

    const QVariant nullText{
        QMetaType::fromType<QString>()
    };

    const QVariant nullInteger{
        QMetaType::fromType<qint64>()
    };

    query.bindValue(
        QStringLiteral(":category_id"),
        nullText
        );

    query.bindValue(
        QStringLiteral(":to_account_id"),
        nullText
        );

    query.bindValue(
        QStringLiteral(":received_amount_minor"),
        nullInteger
        );

    query.bindValue(
        QStringLiteral(":received_currency_code"),
        nullText
        );

    query.bindValue(
        QStringLiteral(":rate_numerator"),
        nullInteger
        );

    query.bindValue(
        QStringLiteral(":rate_denominator"),
        nullInteger
        );

    const auto bindAccountAndAmount = [&query](
                                          const QUuid& accountId,
                                          Money amount)
    {
        query.bindValue(
            QStringLiteral(":account_id"),
            accountId.toString(QUuid::WithoutBraces)
            );

        query.bindValue(
            QStringLiteral(":amount_minor"),
            amount.minorUnits()
            );

        query.bindValue(
            QStringLiteral(":currency_code"),
            toCurrencyCode(amount.currency())
            );
    };

    const auto& details = operation.details();

    if (const auto* income =
        std::get_if<Operation::Income>(&details)) {

        query.bindValue(QStringLiteral(":type"), 0);

        bindAccountAndAmount(
            income->accountId,
            income->amount
            );

        query.bindValue(
            QStringLiteral(":category_id"),
            income->categoryId.toString(QUuid::WithoutBraces)
            );

    } else if (const auto* expense =
               std::get_if<Operation::Expense>(&details)) {

        query.bindValue(QStringLiteral(":type"), 1);

        bindAccountAndAmount(
            expense->accountId,
            expense->amount
            );

        query.bindValue(
            QStringLiteral(":category_id"),
            expense->categoryId.toString(QUuid::WithoutBraces)
            );

    } else {
        const auto& transfer =
            std::get<Operation::Transfer>(details);

        query.bindValue(QStringLiteral(":type"), 2);

        bindAccountAndAmount(
            transfer.fromAccountId,
            transfer.sentAmount
            );

        query.bindValue(
            QStringLiteral(":to_account_id"),
            transfer.toAccountId.toString(QUuid::WithoutBraces)
            );

        query.bindValue(
            QStringLiteral(":received_amount_minor"),
            transfer.receivedAmount.minorUnits()
            );

        query.bindValue(
            QStringLiteral(":received_currency_code"),
            toCurrencyCode(transfer.receivedAmount.currency())
            );

        query.bindValue(
            QStringLiteral(":rate_numerator"),
            transfer.rate.numerator()
            );

        query.bindValue(
            QStringLiteral(":rate_denominator"),
            transfer.rate.denominator()
            );
    }

    if (!query.exec()) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }
}

std::vector<core::model::Account>
Database::loadAccounts() const
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
            credit_limit_minor,
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
        const qint64 type = readInteger(
            query,
            QStringLiteral("type")
            );

        if (type < 0 || type > 2) {
            throw std::runtime_error(
                "Unknown account type in database"
                );
        }

        accounts.emplace_back(
            QUuid{
                query.value(QStringLiteral("id")).toString()
            },

            query.value(QStringLiteral("name")).toString(),

            static_cast<core::model::AccountType>(type),

            readMoney(
                query,
                QStringLiteral("opening_balance_minor"),
                QStringLiteral("currency_code")
                ),

            readMoney(
                query,
                QStringLiteral("credit_limit_minor"),
                QStringLiteral("currency_code")
                ),

            query.value(QStringLiteral("archived")).toBool()
            );
    }

    if (query.lastError().isValid()) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    return accounts;
}

std::vector<core::model::Category>
Database::loadCategories() const
{
    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    const bool success = query.exec(QStringLiteral(R"(
        SELECT
            id,
            name,
            type,
            archived
        FROM categories
        ORDER BY id
    )"));

    if (!success) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    std::vector<core::model::Category> categories;

    while (query.next()) {
        const qint64 type = readInteger(
            query,
            QStringLiteral("type")
            );

        if (type < 0 || type > 1) {
            throw std::runtime_error(
                "Unknown category type in database"
                );
        }

        categories.emplace_back(
            QUuid{
                query.value(QStringLiteral("id")).toString()
            },

            query.value(QStringLiteral("name")).toString(),

            static_cast<core::model::CategoryType>(type),

            query.value(QStringLiteral("archived")).toBool()
            );
    }

    if (query.lastError().isValid()) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    return categories;
}

std::vector<core::model::Operation>
Database::loadOperations() const
{
    using core::model::ExchangeRate;
    using core::model::Operation;

    auto connection = QSqlDatabase::database();
    QSqlQuery query{connection};

    const bool success = query.exec(QStringLiteral(R"(
        SELECT
            id,
            date,
            description,
            type,
            account_id,
            category_id,
            amount_minor,
            currency_code,
            to_account_id,
            received_amount_minor,
            received_currency_code,
            rate_numerator,
            rate_denominator
        FROM operations
        ORDER BY sequence
    )"));

    if (!success) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    std::vector<Operation> operations;

    while (query.next()) {
        const QUuid id{
            query.value(QStringLiteral("id")).toString()
        };

        const QDate date = QDate::fromString(
            query.value(QStringLiteral("date")).toString(),
            Qt::ISODate
            );

        const qint64 type = readInteger(
            query,
            QStringLiteral("type")
            );

        const QUuid accountId{
            query.value(QStringLiteral("account_id")).toString()
        };

        const auto amount = readMoney(
            query,
            QStringLiteral("amount_minor"),
            QStringLiteral("currency_code")
            );

        const auto description = query.value(QStringLiteral("description")).toString();

        switch (type) {
        case 0: {
            const QUuid categoryId{
                query.value(QStringLiteral("category_id")).toString()
            };

            operations.push_back(Operation(
                id,
                date,
                Operation::Income{
                    accountId,
                    categoryId,
                    amount
                },
                description
                ));

            break;
        }

        case 1: {
            const QUuid categoryId{
                query.value(QStringLiteral("category_id")).toString()
            };

            operations.push_back(Operation(
                id,
                date,
                Operation::Expense{
                    accountId,
                    categoryId,
                    amount
                },
                description
                ));

            break;
        }

        case 2: {
            const QUuid toAccountId{
                query.value(QStringLiteral("to_account_id"))
                .toString()
            };

            const auto receivedAmount = readMoney(
                query,
                QStringLiteral("received_amount_minor"),
                QStringLiteral("received_currency_code")
                );

            const auto rate = ExchangeRate::customRatio(
                amount.currency(),
                receivedAmount.currency(),

                readInteger(
                    query,
                    QStringLiteral("rate_numerator")
                    ),

                readInteger(
                    query,
                    QStringLiteral("rate_denominator")
                    )
                );

            operations.push_back(Operation(
                id,
                date,
                Operation::Transfer{
                    accountId,
                    toAccountId,
                    amount,
                    receivedAmount,
                    rate
                },
                description
                ));

            break;
        }

        default:
            throw std::runtime_error(
                "Unknown operation type in database"
                );
        }
    }

    if (query.lastError().isValid()) {
        throw std::runtime_error(
            query.lastError().text().toStdString()
            );
    }

    return operations;
}

void Database::removeAccount(const QUuid& id)
{
    deleteById(
        QStringLiteral("DELETE FROM accounts WHERE id = :id"),
        id
        );
}

void Database::removeCategory(const QUuid& id)
{
    deleteById(
        QStringLiteral("DELETE FROM categories WHERE id = :id"),
        id
        );
}

void Database::removeOperation(const QUuid& id)
{
    deleteById(
        QStringLiteral("DELETE FROM operations WHERE id = :id"),
        id
        );
}

} // namespace core::db