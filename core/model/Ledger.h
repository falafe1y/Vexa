#pragma once

#include "Account.h"
#include "Category.h"
#include "Operation.h"

#include <QHash>
#include <QUuid>

#include <vector>

namespace core::model {

// запрет на наследование
class Ledger final
{
public:
    [[nodiscard]] static Ledger fromStoredData(
                                            const std::vector<Account>& accounts,
                                            const std::vector<Category>& categories,
                                            const std::vector<Operation>& operations
                                            );
    void addAccount(const Account& account);
    void addCategory(const Category& category);
    void addOperation(const Operation& operation);

    [[nodiscard]] Money balance(const QUuid& accountId) const;
    [[nodiscard]] Money availableBalance(const QUuid& accountId) const;
    [[nodiscard]] Money debt(const QUuid& accountId) const;
    [[nodiscard]] Money totalBalance(Currency targetCurrency) const;

    [[nodiscard]] qint64 accountCount() const noexcept
    {
        return static_cast<qint64>(accounts_.size());
    }

    [[nodiscard]] qint64 categoryCount() const noexcept
    {
        return static_cast<qint64>(categories_.size());
    }

    [[nodiscard]] qint64 operationCount() const noexcept
    {
        return static_cast<qint64>(operations_.size());
    }

    [[nodiscard]] const Account& account(const QUuid& id) const
    {
        return requireAccount(id);
    }

    [[nodiscard]] const Category& category(const QUuid& id) const;

    [[nodiscard]] bool isAccountUsed(const QUuid& id) const;
    [[nodiscard]] bool isCategoryUsed(const QUuid& id) const;

    void archiveAccount(const QUuid& id);
    void archiveCategory(const QUuid& id);

    void removeAccount(const QUuid& id);
    void removeCategory(const QUuid& id);

    //
    void swap(Ledger& other) noexcept;

private:
    [[nodiscard]] const Account& requireAccount(const QUuid& accountId) const;

    void checkCategory(const QUuid& categoryId, CategoryType expectedType, bool allowArchived = false) const;
    void checkAccountChange(const QUuid& accountId, const Operation::Details& details) const;

    QHash<QUuid, Account> accounts_;
    QHash<QUuid, Category> categories_;
    std::vector<Operation> operations_;
};

} // namespace core::model