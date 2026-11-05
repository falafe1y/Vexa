#include "Money.h"

#include <limits>
#include <stdexcept>

namespace core::model {

Money Money::operator+(const Money& other) const
{
    requireSameCurrency(other);

    constexpr qint64 min = std::numeric_limits<qint64>::min();
    constexpr qint64 max = std::numeric_limits<qint64>::max();
    const qint64 right = other.minorUnits_;

    if ((right > 0 && minorUnits_ > max - right) ||
        (right < 0 && minorUnits_ < min - right)) {
        throw std::overflow_error("Money addition overflow");
    }

    return Money(minorUnits_ + right, currency_);
}

Money Money::operator-(const Money& other) const
{
    requireSameCurrency(other);

    constexpr qint64 min = std::numeric_limits<qint64>::min();
    constexpr qint64 max = std::numeric_limits<qint64>::max();
    const qint64 right = other.minorUnits_;

    if ((right > 0 && minorUnits_ < min + right) ||
        (right < 0 && minorUnits_ > max + right)) {
        throw std::overflow_error("Money subtraction overflow");
    }

    return Money(minorUnits_ - right, currency_);
}

void Money::requireSameCurrency(const Money& other) const
{
    if (currency_ != other.currency_) {
        throw std::invalid_argument("Money currencies must match");
    }
}

} // namespace core::model