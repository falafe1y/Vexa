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

QUuid CategoryService::update(const QUuid& id, const QString& name,
    core::model::CategoryType type)
{
    const auto& old = ledger_.category(id);
    const core::model::Category updated{id, name, type, old.isArchived()};
    ledger_.validateCategoryUpdate(updated);
    database_.saveCategory(updated);
    ledger_.applyCategoryUpdate(updated);
    return id;
}

} // namespace services
