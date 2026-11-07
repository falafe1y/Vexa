#include "ArchiveService.h"

#include "Database.h"
#include "Ledger.h"

namespace services {

ArchiveService::Result ArchiveService::removeAccount(
    const QUuid& id)
{
    const bool used = ledger_.isAccountUsed(id);

    auto candidate = ledger_;

    if (used) {
        candidate.archiveAccount(id);

        database_.saveAccount(
            candidate.account(id)
        );
    } else {
        candidate.removeAccount(id);

        database_.removeAccount(id);
    }

    ledger_.swap(candidate);

    return used ? Result::Archived : Result::Deleted;
}

ArchiveService::Result ArchiveService::removeCategory(
    const QUuid& id)
{
    const bool used = ledger_.isCategoryUsed(id);

    auto candidate = ledger_;

    if (used) {
        candidate.archiveCategory(id);

        database_.saveCategory(
            candidate.category(id)
        );
    } else {
        candidate.removeCategory(id);

        database_.removeCategory(id);
    }

    ledger_.swap(candidate);

    return used ? Result::Archived : Result::Deleted;
}

} // namespace services
