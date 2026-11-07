#include "AccountService.h"

#include "Currency.h"
#include "Database.h"
#include "Ledger.h"
#include "Money.h"

namespace services {

QUuid AccountService::create(
    const QString& name,
    core::model::AccountType type,
    const QString& currencyCode,
    qint64 openingBalanceMinor,
    qint64 creditLimitMinor)
{
    const auto currency =
        core::model::Currency::fromCode(
            currencyCode.toStdString()
            );

    const core::model::Account account{
        QUuid::createUuid(),
        name,
        type,

        core::model::Money::fromMinorUnits(
            openingBalanceMinor,
            currency
            ),

        core::model::Money::fromMinorUnits(
            creditLimitMinor,
            currency
            )
    };

    auto candidate = ledger_;
    candidate.addAccount(account);

    database_.saveAccount(account);

    ledger_.swap(candidate);

    return account.id();
}

} // namespace services
