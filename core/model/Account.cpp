#include "Account.h"

#include <stdexcept>

namespace core::model {

Account::Account(QUuid id,
                 const QString& name,
                 AccountType type,
                 Money openingBalance,
                 bool archived)
    : id_(id),
    name_(name.trimmed()),
    type_(type),
    openingBalance_(openingBalance),
    archived_(archived)
{
    if (id_.isNull()) {
        throw std::invalid_argument("Account ID must not be null");
    }

    if (name_.isEmpty()) {
        throw std::invalid_argument("Account name must not be empty");
    }

    switch (type_) {
    case AccountType::Cash:
    case AccountType::DebitCard:
    case AccountType::CreditCard:
        break;
    default:
        throw std::invalid_argument("Unsupported account type");
    }
}

} // namespace core::model