#pragma once

#include "Account.h"
#include "Category.h"
#include "Money.h"
#include "ExchangeRate.h"

#include <QDate>
#include <QUuid>

#include <variant>

namespace core::model {

class Operation final
{
public:
    struct Income
    {
        QUuid accountId;
        QUuid categoryId;
        Money amount;
    };

    struct Expense
    {
        QUuid accountId;
        QUuid categoryId;
        Money amount;
    };

    struct Transfer
    {
        QUuid fromAccountId;
        QUuid toAccountId;
        Money sentAmount;
        Money receivedAmount;
        ExchangeRate rate;
    };

    using Details = std::variant<Income, Expense, Transfer>;

    [[nodiscard]] static Operation income(QUuid id,
                                          QDate date,
                                          const Account& account,
                                          const Category& category,
                                          Money amount);

    [[nodiscard]] static Operation expense(QUuid id,
                                           QDate date,
                                           const Account& account,
                                           const Category& category,
                                           Money amount);

    [[nodiscard]] static Operation transfer(QUuid id,
                                            QDate date,
                                            const Account& from,
                                            const Account& to,
                                            Money amount);

    [[nodiscard]] QUuid id() const noexcept
    {
        return id_;
    }

    [[nodiscard]] QDate date() const noexcept
    {
        return date_;
    }

    [[nodiscard]] const Details& details() const noexcept
    {
        return details_;
    }

private:
    Operation(QUuid id, QDate date, Details details);

    QUuid id_;
    QDate date_;
    Details details_;
};

} // namespace core::model