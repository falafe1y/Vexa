#include "Ledger.h"
#include "ExchangeRate.h"

#include <stdexcept>
#include <variant>
#include <map>
#include <string_view>
#include <QSet>
#include <algorithm>
#include <utility>

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

// Валидация не изменяет журнал. После успешной записи в БД сервис
// вызывает apply*Update в том же рабочем потоке.
void Ledger::validateAccountUpdate(const Account& replacement) const
{
    const auto& original = requireAccount(replacement.id());
    if (original.isArchived() || replacement.isArchived() != original.isArchived()) {
        throw std::invalid_argument("Archived records cannot be edited");
    }

    if (replacement.currency() != original.currency() && isAccountUsed(replacement.id())) {
        throw std::invalid_argument("Cannot change currency of an account used in operations");
    }

    // Проверяем расчёт баланса с новым начальным остатком, не меняя счёт.
    auto current = replacement.openingBalance();
    for (const auto& operation : operations_) {
        current = applyToBalance(current, replacement.id(), operation.details());
    }
}

void Ledger::applyAccountUpdate(const Account& replacement)
{
    // Наличие ID и корректность данных уже проверены до записи в БД.
    auto position = accounts_.find(replacement.id());
    Q_ASSERT(position != accounts_.end());
    position.value() = replacement;
}

void Ledger::validateCategoryUpdate(const Category& replacement) const
{
    const auto& original = category(replacement.id());
    if (original.isArchived() || replacement.isArchived() != original.isArchived()) {
        throw std::invalid_argument("Archived records cannot be edited");
    }
    if (original.type() != replacement.type() && isCategoryUsed(replacement.id())) {
        throw std::invalid_argument("Cannot change type of a category used in operations");
    }
}

void Ledger::applyCategoryUpdate(const Category& replacement)
{
    auto position = categories_.find(replacement.id());
    Q_ASSERT(position != categories_.end());
    position.value() = replacement;
}

void Ledger::validateOperationUpdate(const Operation& replacement) const
{
    const auto position = std::find_if(operations_.cbegin(), operations_.cend(),
        [&](const Operation& item) { return item.id() == replacement.id(); });
    if (position == operations_.cend()) {
        throw std::invalid_argument("Operation not found");
    }

    const auto checkCurrency = [this](const QUuid& id, Money amount) {
        if (requireAccount(id).currency() != amount.currency()) {
            throw std::invalid_argument("Operation currency does not match the account");
        }
    };

    // Ссылки и валюты нового варианта должны оставаться допустимыми.
    const auto& details = replacement.details();
    if (const auto* income = std::get_if<Operation::Income>(&details)) {
        checkCategory(income->categoryId, CategoryType::Income, true);
        checkCurrency(income->accountId, income->amount);
    } else if (const auto* expense = std::get_if<Operation::Expense>(&details)) {
        checkCategory(expense->categoryId, CategoryType::Expense, true);
        checkCurrency(expense->accountId, expense->amount);
    } else {
        const auto& transfer = std::get<Operation::Transfer>(details);
        checkCurrency(transfer.fromAccountId, transfer.sentAmount);
        checkCurrency(transfer.toAccountId, transfer.receivedAmount);
    }

    // Пересчитываем только затронутые счета: исходные и новые ссылки.
    QSet<QUuid> affectedAccounts;
    const auto collectAccounts = [&affectedAccounts](const Operation::Details& entry) {
        if (const auto* income = std::get_if<Operation::Income>(&entry)) {
            affectedAccounts.insert(income->accountId);
        } else if (const auto* expense = std::get_if<Operation::Expense>(&entry)) {
            affectedAccounts.insert(expense->accountId);
        } else {
            const auto& transfer = std::get<Operation::Transfer>(entry);
            affectedAccounts.insert(transfer.fromAccountId);
            affectedAccounts.insert(transfer.toAccountId);
        }
    };
    collectAccounts(position->details());
    collectAccounts(replacement.details());

    // Подменяем операцию только при расчёте; сам журнал не меняем.
    for (const auto& accountId : affectedAccounts) {
        auto current = requireAccount(accountId).openingBalance();
        for (const auto& operation : operations_) {
            const auto& entry = operation.id() == replacement.id()
                ? replacement : operation;
            current = applyToBalance(current, accountId, entry.details());
        }
    }
}

void Ledger::applyOperationUpdate(const Operation& replacement)
{
    auto position = std::find_if(operations_.begin(), operations_.end(),
        [&](const Operation& item) { return item.id() == replacement.id(); });
    Q_ASSERT(position != operations_.end());
    *position = replacement;
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

std::vector<Account> Ledger::accounts() const
{
    std::vector<Account> result;

    result.reserve(
        static_cast<std::size_t>(accounts_.size())
        );

    for (const auto& account : accounts_) {
        result.push_back(account);
    }

    return result;
}

std::vector<Category> Ledger::categories() const
{
    std::vector<Category> result;

    result.reserve(
        static_cast<std::size_t>(categories_.size())
        );

    for (const auto& category : categories_) {
        result.push_back(category);
    }

    return result;
}

Money Ledger::balance(const QUuid& accountId) const
{
    Money current = requireAccount(accountId).openingBalance();

    for (const auto& operation : operations_) {
        current = applyToBalance(current, accountId, operation.details());
    }

    return current;
}

Money Ledger::availableBalance(
    const QUuid& accountId) const
{
    const auto& account = requireAccount(accountId);
    const auto current = balance(accountId);

    if (account.type() == AccountType::CreditCard) {
        return account.creditLimit() + current;
    }

    return current;
}

Money Ledger::debt(const QUuid& accountId) const
{
    const auto& account = requireAccount(accountId);

    const auto zero = Money::fromMinorUnits(
        0,
        account.currency()
        );

    if (account.type() != AccountType::CreditCard) {
        return zero;
    }

    const auto current = balance(accountId);

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

bool Ledger::isAccountUsed(const QUuid& id) const
{
    // Проверяем, что счет существует.
    (void)account(id);

    for (const auto& operation : operations_) {
        const auto& details = operation.details();

        if (const auto* income =
            std::get_if<Operation::Income>(&details)) {
            if (income->accountId == id) {
                return true;
            }
        } else if (const auto* expense =
                   std::get_if<Operation::Expense>(&details)) {
            if (expense->accountId == id) {
                return true;
            }
        } else {
            const auto& transfer =
                std::get<Operation::Transfer>(details);

            if (transfer.fromAccountId == id ||
                transfer.toAccountId == id) {
                return true;
            }
        }
    }

    return false;
}

bool Ledger::isCategoryUsed(const QUuid& id) const
{
    // Проверяем, что категория существует.
    (void)category(id);

    for (const auto& operation : operations_) {
        const auto& details = operation.details();

        if (const auto* income =
            std::get_if<Operation::Income>(&details)) {
            if (income->categoryId == id) {
                return true;
            }
        } else if (const auto* expense =
                   std::get_if<Operation::Expense>(&details)) {
            if (expense->categoryId == id) {
                return true;
            }
        }
    }

    return false;
}

void Ledger::archiveAccount(const QUuid& id)
{
    auto position = accounts_.find(id);

    if (position == accounts_.end()) {
        throw std::invalid_argument(
            "Account does not exist in the ledger"
            );
    }

    position.value().archive();
}

void Ledger::archiveCategory(const QUuid& id)
{
    auto position = categories_.find(id);

    if (position == categories_.end()) {
        throw std::invalid_argument(
            "Category does not exist in the ledger"
            );
    }

    position.value().archive();
}

void Ledger::removeAccount(const QUuid& id)
{
    if (isAccountUsed(id)) {
        throw std::invalid_argument(
            "Used account must be archived"
            );
    }

    accounts_.remove(id);
}

void Ledger::removeCategory(const QUuid& id)
{
    if (isCategoryUsed(id)) {
        throw std::invalid_argument(
            "Used category must be archived"
            );
    }

    categories_.remove(id);
}

void Ledger::removeOperation(const QUuid& id)
{
    auto candidate = *this;

    const auto position = std::find_if(
        candidate.operations_.begin(),
        candidate.operations_.end(),
        [id](const Operation& operation) {
            return operation.id() == id;
        }
        );

    if (position == candidate.operations_.end()) {
        throw std::invalid_argument(
            "Operation does not exist in the ledger"
            );
    }

    candidate.operations_.erase(position);

    // Проверяем оставшуюся историю до изменения рабочего журнала
    for (const auto& account :
         std::as_const(candidate.accounts_)) {
        (void)candidate.balance(account.id());
    }

    swap(candidate);
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