#pragma once

#include "Money.h"

#include <QString>
#include <QUuid>

namespace core::model {

enum class AccountType
{
    Cash,
    DebitCard,
    CreditCard
};

// запрет на наследование
class Account final
{
public:
    Account(QUuid id,
            const QString& name,
            AccountType type,
            Money openingBalance,
            bool archived = false);

    [[nodiscard]] QUuid id() const noexcept
    {
        return id_;
    }

    [[nodiscard]] const QString& name() const noexcept
    {
        return name_;
    }

    [[nodiscard]] AccountType type() const noexcept
    {
        return type_;
    }

    [[nodiscard]] Money openingBalance() const noexcept
    {
        return openingBalance_;
    }

    [[nodiscard]] Currency currency() const noexcept
    {
        return openingBalance_.currency();
    }

    [[nodiscard]] bool isArchived() const noexcept
    {
        return archived_;
    }

    // счет удален, но для корректности истории он по сути просто скрывается
    void archive() noexcept
    {
        archived_ = true;
    }

private:
    QUuid id_;
    QString name_;
    AccountType type_;
    Money openingBalance_;
    bool archived_;
};

} // namespace core::model