#include "CategoryService.h"

#include "Database.h"
#include "Ledger.h"

namespace services {

QUuid CategoryService::create(
    const QString& name,
    core::model::CategoryType type)
{
    const core::model::Category category{
        QUuid::createUuid(),
        name,
        type
    };

    auto candidate = ledger_;
    candidate.addCategory(category);

    database_.saveCategory(category);

    ledger_.swap(candidate);

    return category.id();
}

} // namespace services
