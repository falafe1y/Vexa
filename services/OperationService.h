#pragma once

#include <QDate>
#include <QUuid>
#include <QtTypes>

namespace core::db {
class Database;
}

namespace core::model {
class Ledger;
class Operation;
}

namespace services {

class OperationService final
{
public:
    OperationService(
        core::db::Database& database,
        core::model::Ledger& ledger)
        : database_(database),
          ledger_(ledger)
    {
    }

    [[nodiscard]] QUuid income(
        const QUuid& accountId,
        const QUuid& categoryId,
        qint64 amountMinor,
        QDate date
    );

    [[nodiscard]] QUuid expense(
        const QUuid& accountId,
        const QUuid& categoryId,
        qint64 amountMinor,
        QDate date
    );

    [[nodiscard]] QUuid transfer(
        const QUuid& fromAccountId,
        const QUuid& toAccountId,
        qint64 sentAmountMinor,
        QDate date
    );

private:
    [[nodiscard]] QUuid save(const core::model::Operation& operation);

    core::db::Database& database_;
    core::model::Ledger& ledger_;
};

} // namespace services
