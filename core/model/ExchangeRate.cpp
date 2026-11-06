#include "ExchangeRate.h"

#include <QtNumeric>

#include <numeric>
#include <stdexcept>
#include <string_view>

namespace core::model {

namespace {

qint64 unitPriceInRubKopecks(Currency currency)
{
    struct Quote
    {
        std::string_view code;
        qint64 kopecks;
    };

    static constexpr Quote quotes[] = {
                                        {"RUB", 100},
                                        {"USD", 9000},
                                        {"EUR", 10000},
                                        {"CNY", 1200},
                                        };

    for (const auto& quote : quotes) {
        if (quote.code == currency.code()) {
            return quote.kopecks;
        }
    }

    throw std::invalid_argument("No fixed exchange rate for this currency");
}

qint64 minorUnitsPerUnit(Currency currency)
{
    qint64 units = 1;

    for (int i = 0; i < currency.decimalPlaces(); ++i) {
        units *= 10;
    }

    return units;
}

} // namespace

ExchangeRate ExchangeRate::fixed(Currency from, Currency to)
{
    if (from == to) {
        return ExchangeRate{from, to, 1, 1};
    }

    const qint64 numerator = unitPriceInRubKopecks(from) * minorUnitsPerUnit(to);
    const qint64 denominator = unitPriceInRubKopecks(to) * minorUnitsPerUnit(from);
    const qint64 divisor = std::gcd(numerator, denominator);

    return ExchangeRate{from, to, numerator / divisor, denominator / divisor};
}

Money ExchangeRate::convert(Money amount) const
{
    if (amount.currency() != from_) {
        throw std::invalid_argument("Amount currency must match the exchange rate");
    }

    const qint64 units = amount.minorUnits();
    qint64 whole = 0;
    qint64 scaledRemainder = 0;

    if (qMulOverflow(units / denominator_, numerator_, &whole) ||
        qMulOverflow(units % denominator_, numerator_, &scaledRemainder)) {
        throw std::overflow_error("Currency conversion overflow");
    }

    qint64 fractional = scaledRemainder / denominator_;
    const qint64 remainder = scaledRemainder % denominator_;
    const qint64 roundingThreshold = denominator_ / 2 + denominator_ % 2;

    if (remainder >= roundingThreshold) {
        ++fractional;
    } else if (remainder <= -roundingThreshold) {
        --fractional;
    }

    return Money::fromMinorUnits(whole, to_)
           + Money::fromMinorUnits(fractional, to_);
}

} // namespace core::model