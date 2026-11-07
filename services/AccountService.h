#pragma once

#include "Account.h"

#include <QString>
#include <QUuid>
#include <QtTypes>

namespace core::db {
class Database;
}

namespace core::model {
class Ledger;
}

namespace services {

class AccountService final
{
public:
    AccountService(
        core::db::Database& database,
        core::model::Ledger& ledger)
        : database_(database),
          ledger_(ledger)
    {
    }

    [[nodiscard]] QUuid create(
        const QString& name,
        core::model::AccountType type,
        const QString& currencyCode,
        qint64 openingBalanceMinor
    );

private:
    core::db::Database& database_;
    core::model::Ledger& ledger_;
};

} // namespace services
