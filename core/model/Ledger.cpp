#include "Ledger.h"
#include "ExchangeRate.h"

#include <stdexcept>
#include <variant>
#include <map>
#include <string_view>
#include <QSet>

namespace core::model {

namespace {

// проверка корректности операции
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

Ledger Ledger::fromStoredData(
    const std::vector<Account>& accounts,
    const std::vector<Category>& categories,
    const std::vector<Operation>& operations)
{
    Ledger ledger;

    for (const auto& account : accounts) {
        ledger.addAccount(account);
    }

    for (const auto& category : categories) {
        ledger.addCategory(category);
    }

    const auto checkAccountCurrency = [&ledger](
                                          const QUuid& accountId,
                                          Money amount)
    {
        // проверка на существование указанного счета
        const auto& account = ledger.requireAccount(accountId);

        // проверка валюты
        if (account.currency() != amount.currency()) {
            throw std::invalid_argument(
                "Operation currency does not match the account"
                );
        }
    };

    // запоминаем уже встреченные операции по их ID
    QSet<QUuid> operationIds;

    for (const auto& operation : operations) {
        if (operationIds.contains(operation.id())) {
            throw std::invalid_argument(
                "Operation ID already exists"
                );
        }

        operationIds.insert(operation.id());

        const auto& details = operation.details();

        if (const auto* income =
            std::get_if<Operation::Income>(&details)) {

            ledger.checkCategory(
                income->categoryId,
                CategoryType::Income,
                true
                );

            checkAccountCurrency(
                income->accountId,
                income->amount
                );

        } else if (const auto* expense =
                   std::get_if<Operation::Expense>(&details)) {

            ledger.checkCategory(
                expense->categoryId,
                CategoryType::Expense,
                true
                );

            checkAccountCurrency(
                expense->accountId,
                expense->amount
                );

        } else {
            const auto& transfer =
                std::get<Operation::Transfer>(details);

            checkAccountCurrency(
                transfer.fromAccountId,
                transfer.sentAmount
                );

            checkAccountCurrency(
                transfer.toAccountId,
                transfer.receivedAmount
                );
        }
    }

    // сохранение проверенного журнала
    ledger.operations_ = operations;

    // проверка, что история позволяет рассчитать остатки
    // без ошибок валют и переполнения
    for (const auto& account : std::as_const(ledger.accounts_)) {
        (void)ledger.balance(account.id());
    }

    return ledger;
}

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

Money Ledger::debt(const QUuid& accountId) const
{
    const auto current = balance(accountId);
    const auto zero = Money::fromMinorUnits(0, current.currency());

    if (current.minorUnits() < 0) {
        return zero - current;
    }

    return zero;
}

Money Ledger::totalBalance(Currency targetCurrency) const
{
    std::map<std::string_view, Money> subtotals;

    for (const auto& account : accounts_) {
        const auto current = balance(account.id());
        const auto [position, inserted] =
            subtotals.try_emplace(current.currency().code(), current);

        if (!inserted) {
            position->second = position->second + current;
        }
    }

    auto total = Money::fromMinorUnits(0, targetCurrency);

    for (const auto& entry : subtotals) {
        const Money& subtotal = entry.second;
        const auto rate = ExchangeRate::fixed(subtotal.currency(), targetCurrency);
        total = total + rate.convert(subtotal);
    }

    return total;
}

const Category& Ledger::category(const QUuid& id) const
{
    const auto position = categories_.constFind(id);

    if (position == categories_.constEnd()) {
        throw std::invalid_argument(
            "Category does not exist in the ledger"
            );
    }

    return position.value();
}

void Ledger::swap(Ledger& other) noexcept
{
    accounts_.swap(other.accounts_);
    categories_.swap(other.categories_);
    operations_.swap(other.operations_);
}

const Account& Ledger::requireAccount(const QUuid& accountId) const
{
    const auto account = accounts_.constFind(accountId);

    if (account == accounts_.constEnd()) {
        throw std::invalid_argument("Account does not exist in the ledger");
    }

    return account.value();
}

void Ledger::checkCategory(const QUuid& categoryId, CategoryType expectedType, bool allowArchived) const
{
    const auto position = categories_.constFind(categoryId);

    if (position == categories_.constEnd()) {
        throw std::invalid_argument(
            "Category does not exist in the ledger"
            );
    }

    const auto& category = position.value();

    if (category.type() != expectedType) {
        throw std::invalid_argument(
            "Category type does not match the operation"
            );
    }

    if (!allowArchived && category.isArchived()) {
        throw std::invalid_argument("Category is archived");
    }
}

void Ledger::checkAccountChange(const QUuid& accountId, const Operation::Details& details) const
{
    if (requireAccount(accountId).isArchived()) {
        throw std::invalid_argument("Account is archived");
    }

    // проверка валюты и переполнения средствами Money.
    (void)applyToBalance(balance(accountId), accountId, details);
}

} // namespace core::model