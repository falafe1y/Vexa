#include "Category.h"

#include <stdexcept>

namespace core::model {

Category::Category(QUuid id,
                   const QString& name,
                   CategoryType type,
                   bool archived)
    : id_(id),
    name_(name.trimmed()),
    type_(type),
    archived_(archived)
{
    if (id_.isNull()) {
        throw std::invalid_argument("Category ID must not be null");
    }

    if (name_.isEmpty()) {
        throw std::invalid_argument("Category name must not be empty");
    }

    if (type_ != CategoryType::Income && type_ != CategoryType::Expense) {
        throw std::invalid_argument("Unsupported category type");
    }
}

} // namespace core::model