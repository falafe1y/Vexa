#include "Operation.h"

#include <stdexcept>
#include <utility>

namespace core::model {

namespace {

void validateEntry(const Account& account,
                   const Category& category,
                   const Money& amount,
                   CategoryType expectedCategoryType)
{
    if (account.isArchived()) {
        throw std::invalid_argument("Account is archived");
    }

    if (category.isArchived()) {
        throw std::invalid_argument("Category is archived");
    }

    if (category.type() != expectedCategoryType) {
        throw std::invalid_argument("Category type does not match the operation");
    }

    if (amount.minorUnits() <= 0) {
        throw std::invalid_argument("Operation amount must be positive");
    }

    if (amount.currency() != account.currency()) {
        throw std::invalid_argument("Operation currency must match the account currency");
    }
}

} // namespace

Operation::Operation(
    QUuid id,
    QDate date,
    Details details)
    : id_(id),
    date_(date),
    details_(std::move(details))
{
    if (id_.isNull()) {
        throw std::invalid_argument(
            "Operation ID must not be null"
            );
    }

    if (!date_.isValid()) {
        throw std::invalid_argument(
            "Operation date must be valid"
            );
    }

    const auto validateEntry = [](
                                   const QUuid& accountId,
                                   const QUuid& categoryId,
                                   Money amount)
    {
        if (accountId.isNull() || categoryId.isNull()) {
            throw std::invalid_argument(
                "Operation account and category IDs must not be null"
                );
        }

        if (amount.minorUnits() <= 0) {
            throw std::invalid_argument(
                "Operation amount must be positive"
                );
        }
    };

    if (const auto* income = std::get_if<Income>(&details_)) {
        validateEntry(
            income->accountId,
            income->categoryId,
            income->amount
            );
    } else if (const auto* expense =
               std::get_if<Expense>(&details_)) {
        validateEntry(
            expense->accountId,
            expense->categoryId,
            expense->amount
            );
    } else {
        const auto& transfer = std::get<Transfer>(details_);

        if (transfer.fromAccountId.isNull() ||
            transfer.toAccountId.isNull()) {
            throw std::invalid_argument(
                "Transfer account IDs must not be null"
                );
        }

        if (transfer.fromAccountId == transfer.toAccountId) {
            throw std::invalid_argument(
                "Transfer accounts must be different"
                );
        }

        if (transfer.sentAmount.minorUnits() <= 0 ||
            transfer.receivedAmount.minorUnits() <= 0) {
            throw std::invalid_argument(
                "Transfer amounts must be positive"
                );
        }

        if (transfer.rate.convert(transfer.sentAmount) !=
            transfer.receivedAmount) {
            throw std::invalid_argument(
                "Transfer amounts do not match the exchange rate"
                );
        }
    }
}

Operation Operation::income(QUuid id,
                            QDate date,
                            const Account& account,
                            const Category& category,
                            Money amount)
{
    validateEntry(account, category, amount, CategoryType::Income);

    return Operation{id, date, Income{account.id(), category.id(), amount}};
}

Operation Operation::expense(QUuid id,
                             QDate date,
                             const Account& account,
                             const Category& category,
                             Money amount)
{
    validateEntry(account, category, amount, CategoryType::Expense);

    return Operation{id, date, Expense{account.id(), category.id(), amount}};
}

Operation Operation::transfer(QUuid id,
                              QDate date,
                              const Account& from,
                              const Account& to,
                              Money amount)
{
    if (from.id() == to.id()) {
        throw std::invalid_argument("Transfer requires two different accounts");
    }

    if (from.isArchived() || to.isArchived()) {
        throw std::invalid_argument("Transfer accounts must be active");
    }

    if (amount.minorUnits() <= 0) {
        throw std::invalid_argument("Transfer amount must be positive");
    }

    if (amount.currency() != from.currency()) {
        throw std::invalid_argument("Transfer amount must match the source currency");
    }

    const auto rate = ExchangeRate::fixed(from.currency(), to.currency());
    const auto receivedAmount = rate.convert(amount);

    if (receivedAmount.minorUnits() == 0) {
        throw std::invalid_argument("Transfer amount rounds to zero");
    }

    return Operation{
        id,
        date,
        Transfer{from.id(), to.id(), amount, receivedAmount, rate}
    };
}

} // namespace core::model