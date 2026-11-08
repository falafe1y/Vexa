#include "LedgerReadService.h"

#include "Ledger.h"

#include <algorithm>

namespace services {

AccountList LedgerReadService::accounts() const
{
    const auto source = ledger_.accounts();

    AccountList result;
    result.reserve(source.size());

    for (const auto& account : source) {
        if (account.isArchived()) {
            continue;
        }

        const auto currency = account.currency();
        const auto code = currency.code();

        AccountData data;

        data.id = account.id();
        data.name = account.name();
        data.type = account.type();

        data.currencyCode = QString::fromLatin1(
            code.data(),
            static_cast<qsizetype>(code.size())
        );

        data.decimalPlaces = currency.decimalPlaces();

        data.balanceMinor =
            ledger_.balance(account.id()).minorUnits();

        data.creditLimitMinor =
            account.creditLimit().minorUnits();

        data.debtMinor =
            ledger_.debt(account.id()).minorUnits();

        data.availableBalanceMinor =
            ledger_.availableBalance(account.id()).minorUnits();

        result.push_back(data);
    }

    std::sort(
        result.begin(),
        result.end(),
        [](const AccountData& left, const AccountData& right) {
            const int comparison = QString::compare(
                left.name,
                right.name,
                Qt::CaseInsensitive
            );

            if (comparison != 0) {
                return comparison < 0;
            }

            return left.id.toString(QUuid::WithoutBraces) <
                   right.id.toString(QUuid::WithoutBraces);
        }
    );

    return result;
}

CategoryList LedgerReadService::categories() const
{
    const auto source = ledger_.categories();

    CategoryList result;
    result.reserve(source.size());

    for (const auto& category : source) {
        if (category.isArchived()) {
            continue;
        }

        CategoryData data;

        data.id = category.id();
        data.name = category.name();
        data.type = category.type();

        result.push_back(data);
    }

    std::sort(
        result.begin(),
        result.end(),
        [](const CategoryData& left, const CategoryData& right) {
            const int comparison = QString::compare(
                left.name,
                right.name,
                Qt::CaseInsensitive
            );

            if (comparison != 0) {
                return comparison < 0;
            }

            return left.id.toString(QUuid::WithoutBraces) <
                   right.id.toString(QUuid::WithoutBraces);
        }
    );

    return result;
}

} // namespace services
