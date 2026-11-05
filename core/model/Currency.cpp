#include "Currency.h"

#include <stdexcept>
#include <string>

namespace core::model {

// string_view позвоялет прочитать
// строку без копирования ее символов
Currency Currency::fromCode(std::string_view code)
{
    // код валюты : кол-во знаков после запятой
    // к примеру, 12095 RUB = 120,95 руб
    static constexpr Currency supportedCurrencies[] = {
        {"RUB", 2},
        {"USD", 2},
        {"EUR", 2},
        {"CNY", 2},
        };

    for (const Currency& currency : supportedCurrencies) {
        if (currency.code() == code) {
            return currency;
        }
    }

    throw std::invalid_argument("Unsupported currency code: " + std::string(code));
}

} // namespace core::model