#pragma once

#include "Category.h"

#include <QString>
#include <QUuid>

namespace core::db {
class Database;
}

namespace core::model {
class Ledger;
}

namespace services {

class CategoryService final
{
public:
    CategoryService(
        core::db::Database& database,
        core::model::Ledger& ledger)
        : database_(database),
          ledger_(ledger)
    {
    }

    [[nodiscard]] QUuid create(
        const QString& name,
        core::model::CategoryType type
    );

private:
    core::db::Database& database_;
    core::model::Ledger& ledger_;
};

} // namespace services
