#pragma once

#include "ReadData.h"

namespace core::model {
class Ledger;
class Operation;
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

    [[nodiscard]] OperationPage operations(
        qint64 offset,
        qint64 limit
        ) const;

private:
    const core::model::Ledger& ledger_;

    [[nodiscard]] OperationData makeOperationData(
        const core::model::Operation& operation
        ) const;
};

} // namespace services
