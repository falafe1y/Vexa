#pragma once

#include "../core/model/Money.h"
#include "CurrencyRateProvider.h"

class CurrencyConverter
{
public:
    explicit CurrencyConverter(
        const CurrencyRateProvider& rateProvider
        );

    Money convert(
        const Money& money,
        Currency targetCurrency
        ) const;

private:
    const CurrencyRateProvider& rateProvider_;
};