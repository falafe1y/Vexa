#pragma once

#include "../core/model/Money.h"
#include "../core/model/Transaction.h"
#include "../core/model/CurrencyConverter.h"

#include <QVector>

class BalanceCalculator
{
public:
    explicit BalanceCalculator(
        const CurrencyConverter& currencyConverter
        );

    Money calculate(
        const QVector<Transaction>& transactions,
        Currency targetCurrency
        ) const;

private:
    const CurrencyConverter& currencyConverter_;
};