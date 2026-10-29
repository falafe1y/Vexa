#pragma once

#include <QString>

enum class Currency {
    RUB,
    USD,
    EUR,
    CNY
};

inline constexpr int kCurrencyCount = 4;
inline constexpr double kDefaultCnyToRubRate = 12.5;

QString currencyCode(Currency currency);
// Unknown codes are treated as rubles
Currency currencyFromCode(const QString& code);
QString currencySymbol(Currency currency);
int currencyFractionDigits(Currency currency);