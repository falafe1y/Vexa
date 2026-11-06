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
    void addAccount(const Account& account);
    void addCategory(const Category& category);
    void addOperation(const Operation& operation);

    [[nodiscard]] Money balance(const QUuid& accountId) const;

private:
    [[nodiscard]] const Account& requireAccount(const QUuid& accountId) const;

    void checkCategory(const QUuid& categoryId, CategoryType expectedType);
    void checkAccountChange(const QUuid& accountId, const Operation::Details& details) const;

    QHash<QUuid, Account> accounts_;
    QHash<QUuid, Category> categories_;
    std::vector<Operation> operations_;
};

} // namespace core::model