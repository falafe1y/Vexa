#pragma once

#include "Money.h"

namespace core::model {

class ExchangeRate final
{
public:
    [[nodiscard]] static ExchangeRate fixed(Currency from, Currency to);

    [[nodiscard]] Money convert(Money amount) const;

    [[nodiscard]] qint64 numerator() const noexcept
    {
        return numerator_;
    }

    [[nodiscard]] qint64 denominator() const noexcept
    {
        return denominator_;
    }

private:
    ExchangeRate(Currency from,
                 Currency to,
                 qint64 numerator,
                 qint64 denominator) noexcept
        : from_(from),
        to_(to),
        numerator_(numerator),
        denominator_(denominator)
    {
    }

    Currency from_;
    Currency to_;
    qint64 numerator_;      // числитель
    qint64 denominator_;    // знаменатель
};

} // namespace core::model