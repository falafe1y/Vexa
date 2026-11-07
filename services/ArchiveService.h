#pragma once

#include <QUuid>

namespace core::db {
class Database;
}

namespace core::model {
class Ledger;
}

namespace services {

class ArchiveService final
{
public:
    enum class Result
    {
        Archived,
        Deleted
    };

    ArchiveService(
        core::db::Database& database,
        core::model::Ledger& ledger)
        : database_(database),
          ledger_(ledger)
    {
    }

    [[nodiscard]]
    Result removeAccount(const QUuid& id);

    [[nodiscard]]
    Result removeCategory(const QUuid& id);

private:
    core::db::Database& database_;
    core::model::Ledger& ledger_;
};

} // namespace services
