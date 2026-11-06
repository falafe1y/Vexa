#include "Ledger.h"

#include <stdexcept>
#include <variant>

namespace core::model {

namespace {

Money applyToBalance(Money current,
                     const QUuid& accountId,
                     const Operation::Details& details)
{
    if (const auto* income = std::get_if<Operation::Income>(&details)) {
        return income->accountId == accountId ? current + income->amount : current;
    }

    if (const auto* expense = std::get_if<Operation::Expense>(&details)) {
        return expense->accountId == accountId ? current - expense->amount : current;
    }

    const auto& transfer = std::get<Operation::Transfer>(details);

    if (transfer.fromAccountId == accountId) {
        return current - transfer.sentAmount;
    }

    if (transfer.toAccountId == accountId) {
        return current + transfer.receivedAmount;
    }

    return current;
}

} // namespace

void Ledger::addAccount(const Account& account)
{
    if (accounts_.contains(account.id())) {
        throw std::invalid_argument("Account ID already exists");
    }

    accounts_.insert(account.id(), account);
}

void Ledger::addCategory(const Category& category)
{
    if (categories_.contains(category.id())) {
        throw std::invalid_argument("Category ID already exists");
    }

    categories_.insert(category.id(), category);
}

void Ledger::addOperation(const Operation& operation)
{
    for (const auto& existing : operations_) {
        if (existing.id() == operation.id()) {
            throw std::invalid_argument("Operation ID already exists");
        }
    }

    const auto& details = operation.details();

    if (const auto* income = std::get_if<Operation::Income>(&details)) {
        checkCategory(income->categoryId, CategoryType::Income);
        checkAccountChange(income->accountId, details);
    } else if (const auto* expense = std::get_if<Operation::Expense>(&details)) {
        checkCategory(expense->categoryId, CategoryType::Expense);
        checkAccountChange(expense->accountId, details);
    } else {
        const auto& transfer = std::get<Operation::Transfer>(details);
        checkAccountChange(transfer.fromAccountId, details);
        checkAccountChange(transfer.toAccountId, details);
    }

    operations_.push_back(operation);
}

Money Ledger::balance(const QUuid& accountId) const
{
    Money current = requireAccount(accountId).openingBalance();

    for (const auto& operation : operations_) {
        current = applyToBalance(current, accountId, operation.details());
    }

    return current;
}

const Account& Ledger::requireAccount(const QUuid& accountId) const
{
    const auto account = accounts_.constFind(accountId);

    if (account == accounts_.constEnd()) {
        throw std::invalid_argument("Account does not exist in the ledger");
    }

    return account.value();
}

void Ledger::checkCategory(const QUuid& categoryId, CategoryType expectedType)
{
    const auto category = categories_.constFind(categoryId);

    if (category == categories_.constEnd()) {
        throw std::invalid_argument("Category does not exist in the ledger");
    }

    if (category.value().isArchived() || category.value().type() != expectedType) {
        throw std::invalid_argument("Operation requires an active category of the correct type");
    }
}

void Ledger::checkAccountChange(const QUuid& accountId,
                                const Operation::Details& details) const
{
    if (requireAccount(accountId).isArchived()) {
        throw std::invalid_argument("Account is archived");
    }

    // Проверяем валюту и переполнение средствами Money.
    (void)applyToBalance(balance(accountId), accountId, details);
}

} // namespace core::model