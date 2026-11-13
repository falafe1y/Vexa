#pragma once

#include "Account.h"
#include "Category.h"
#include "Money.h"
#include "ExchangeRate.h"

#include <QDate>
#include <QString>
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

    Operation(QUuid id, QDate date, Details details, QString description = {});

    [[nodiscard]] static Operation fromStoredData(QUuid id, QDate date, Details details);

    [[nodiscard]] static Operation income(QUuid id,
                                          QDate date,
                                          const Account& account,
                                          const Category& category,
                                          Money amount,
                                          QString description = {});

    [[nodiscard]] static Operation expense(QUuid id,
                                           QDate date,
                                           const Account& account,
                                           const Category& category,
                                           Money amount,
                                           QString description = {});

    [[nodiscard]] static Operation transfer(QUuid id,
                                            QDate date,
                                            const Account& from,
                                            const Account& to,
                                            Money amount,
                                            QString description = {});

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

    [[nodiscard]] const QString& description() const noexcept
    {
        return description_;
    }

private:
    QUuid id_;
    QDate date_;
    Details details_;
    QString description_;
};

} // namespace core::model