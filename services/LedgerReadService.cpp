#include "LedgerReadService.h"

#include "Ledger.h"
#include "Operation.h"

#include <algorithm>
#include <numeric>
#include <stdexcept>
#include <variant>
#include <vector>

namespace services {

namespace {

QString toCurrencyCode(core::model::Currency currency)
{
    const auto code = currency.code();

    return QString::fromLatin1(
        code.data(),
        static_cast<qsizetype>(code.size())
        );
}

} // namespace

AccountList LedgerReadService::accounts() const
{
    AccountList result;
    const auto accounts = ledger_.accounts();

    result.reserve(accounts.size());

    for (const auto& account : accounts) {
        if (account.isArchived()) {
            continue;
        }

        AccountData data;

        data.id = account.id();
        data.name = account.name();
        data.type = account.type();

        data.currencyCode = toCurrencyCode(account.currency());
        data.decimalPlaces = account.currency().decimalPlaces();

        data.openingBalanceMinor = account.openingBalance().minorUnits();
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

            return left.id.toString(QUuid::WithoutBraces)
                   < right.id.toString(QUuid::WithoutBraces);
        }
        );

    return result;
}

CategoryList LedgerReadService::categories() const
{
    CategoryList result;
    const auto categories = ledger_.categories();

    result.reserve(categories.size());

    for (const auto& category : categories) {
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

            return left.id.toString(QUuid::WithoutBraces)
                   < right.id.toString(QUuid::WithoutBraces);
        }
        );

    return result;
}

OperationData LedgerReadService::makeOperationData(
    const core::model::Operation& operation) const
{
    using core::model::Money;
    using core::model::Operation;

    OperationData data;

    data.id = operation.id();
    data.date = operation.date();

    const auto fillAccountAndAmount =
        [this, &data](const QUuid& accountId, Money amount) {
            const auto& account = ledger_.account(accountId);

            data.accountId = account.id();
            data.accountName = account.name();

            data.amountMinor = amount.minorUnits();
            data.currencyCode = toCurrencyCode(amount.currency());

            data.decimalPlaces =
                amount.currency().decimalPlaces();
        };

    const auto& details = operation.details();

    if (const auto* income = std::get_if<Operation::Income>(&details)) {
        data.type = OperationType::Income;

        fillAccountAndAmount(income->accountId, income->amount);

        const auto& category = ledger_.category(income->categoryId);

        data.categoryId = category.id();
        data.categoryName = category.name();
    } else if (
        const auto* expense = std::get_if<Operation::Expense>(&details)
        ) {
        data.type = OperationType::Expense;

        fillAccountAndAmount(expense->accountId, expense->amount);

        const auto& category = ledger_.category(expense->categoryId);

        data.categoryId = category.id();
        data.categoryName = category.name();
    } else {
        const auto& transfer = std::get<Operation::Transfer>(details);

        data.type = OperationType::Transfer;

        fillAccountAndAmount(
            transfer.fromAccountId,
            transfer.sentAmount
            );

        const auto& receiver = ledger_.account(transfer.toAccountId);

        data.toAccountId = receiver.id();
        data.toAccountName = receiver.name();

        data.receivedAmountMinor =
            transfer.receivedAmount.minorUnits();

        data.receivedCurrencyCode =
            toCurrencyCode(transfer.receivedAmount.currency());

        data.receivedDecimalPlaces =
            transfer.receivedAmount.currency().decimalPlaces();
    }

    return data;
}

OperationPage LedgerReadService::operations(
    qint64 offset,
    qint64 limit) const
{
    if (offset < 0) {
        throw std::invalid_argument(
            "History offset must not be negative"
            );
    }

    if (limit <= 0) {
        throw std::invalid_argument(
            "History limit must be positive"
            );
    }

    OperationPage page;

    page.limit = limit;
    page.totalCount = ledger_.operationCount();
    page.offset = std::min(offset, page.totalCount);
    page.nextOffset = page.offset;

    if (page.offset == page.totalCount) {
        return page;
    }

    // Сортируем позиции операций, сохраняя порядок самого журнала.
    std::vector<std::size_t> indices(
        static_cast<std::size_t>(page.totalCount)
        );

    std::iota(
        indices.begin(),
        indices.end(),
        std::size_t{0}
        );

    std::sort(
        indices.begin(),
        indices.end(),
        [this](std::size_t leftIndex, std::size_t rightIndex) {
            const auto& left = ledger_.operationAt(leftIndex);
            const auto& right = ledger_.operationAt(rightIndex);

            if (left.date() != right.date()) {
                return left.date() > right.date();
            }

            // При одинаковой дате сначала показываем
            // операцию, добавленную в журнал позднее.
            return leftIndex > rightIndex;
        }
        );

    const qint64 count = std::min(
        limit,
        page.totalCount - page.offset
        );

    page.items.reserve(static_cast<std::size_t>(count));

    for (qint64 i = 0; i < count; ++i) {
        const auto position =
            static_cast<std::size_t>(page.offset + i);

        const auto operationIndex = indices[position];

        page.items.push_back(
            makeOperationData(ledger_.operationAt(operationIndex))
            );
    }

    page.nextOffset = page.offset + count;
    page.hasMore = page.nextOffset < page.totalCount;

    return page;
}

} // namespace services