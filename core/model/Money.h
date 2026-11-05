#pragma once

#include "Currency.h"

#include <QtTypes>
#include <concepts>

namespace core::model {

class Money final
{
public:
    [[nodiscard]] static constexpr Money fromMinorUnits(qint64 amount, Currency currency) noexcept
    {
        return Money(amount, currency);
    }

    static Money fromMinorUnits(std::floating_point auto, Currency) = delete;

    [[nodiscard]] constexpr qint64 minorUnits() const noexcept
    {
        return minorUnits_;
    }

    [[nodiscard]] constexpr Currency currency() const noexcept
    {
        return currency_;
    }

    constexpr bool operator==(const Money&) const noexcept = default;

    [[nodiscard]] Money operator+(const Money& other) const;
    [[nodiscard]] Money operator-(const Money& other) const;

private:
    constexpr Money(qint64 minorUnits, Currency currency) noexcept
        : minorUnits_(minorUnits), currency_(currency)
    {
    }

    void requireSameCurrency(const Money& other) const;

    qint64 minorUnits_;
    Currency currency_;
};

} // namespace core::model