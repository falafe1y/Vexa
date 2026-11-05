#pragma once

#include <string_view>

namespace core::model {

class Currency final
{
public:
    //nodiscard просит компилятор предупредить,
    // если результат операции проигнорирован
    [[nodiscard]] static Currency fromCode(std::string_view code);

    [[nodiscard]] constexpr std::string_view code() const noexcept
    {
        return code_;
    }

    [[nodiscard]] constexpr int decimalPlaces() const noexcept
    {
        return decimalPlaces_;
    }

    constexpr bool operator==(const Currency&) const noexcept = default;

private:
    // конструктор приватный, т.к. если бы он был публичным
    // из любой части кода можно было бы написать Currency cur("RUB", 2),
    // но можно написать и Currency cur("RUB", 0).
    // Неявно вызывается через вызов статических методов Currency rub = Currency::fromCode("RUB");
    constexpr Currency(std::string_view code, int decimalPlaces) noexcept
        : code_(code), decimalPlaces_(decimalPlaces)
    {
    }

    std::string_view code_;

    // знаки после запятой в конкретной валюте
    // 12095RUB = 120,95 руб, т.е. decimalPlaces_ = 2
    int decimalPlaces_;
};

} // namespace core::model