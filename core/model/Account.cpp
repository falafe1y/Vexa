#include "Account.h"

#include <stdexcept>

namespace core::model {

Account::Account(
    QUuid id,
    const QString& name,
    AccountType type,
    Money openingBalance,
    bool archived)
    : Account(
          id,
          name,
          type,
          openingBalance,
          Money::fromMinorUnits(0, openingBalance.currency()),
          archived
          )
{
}

Account::Account(
    QUuid id,
    const QString& name,
    AccountType type,
    Money openingBalance,
    Money creditLimit,
    bool archived)
    : id_(id),
    name_(name.trimmed()),
    type_(type),
    openingBalance_(openingBalance),
    creditLimit_(creditLimit),
    archived_(archived)
{
    if (id_.isNull()) {
        throw std::invalid_argument(
            "Account ID must not be null"
            );
    }

    if (name_.isEmpty()) {
        throw std::invalid_argument(
            "Account name must not be empty"
            );
    }

    switch (type_) {
    case AccountType::Cash:
    case AccountType::DebitCard:
    case AccountType::CreditCard:
        break;

    default:
        throw std::invalid_argument(
            "Unsupported account type"
            );
    }

    if (creditLimit_.currency() != currency()) {
        throw std::invalid_argument(
            "Credit limit currency must match account currency"
            );
    }

    if (creditLimit_.minorUnits() < 0) {
        throw std::invalid_argument(
            "Credit limit must not be negative"
            );
    }

    if (type_ != AccountType::CreditCard &&
        creditLimit_.minorUnits() != 0) {
        throw std::invalid_argument(
            "Only credit cards can have a nonzero credit limit"
            );
    }
}

} // namespace core::model