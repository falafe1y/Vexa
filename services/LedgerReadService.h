#pragma once

#include "ReadData.h"

namespace core::model {
class Ledger;
}

namespace services {

class LedgerReadService final
{
public:
    explicit LedgerReadService(
        const core::model::Ledger& ledger)
        : ledger_(ledger)
    {
    }

    [[nodiscard]]
    AccountList accounts() const;

    [[nodiscard]]
    CategoryList categories() const;

private:
    const core::model::Ledger& ledger_;
};

} // namespace services
