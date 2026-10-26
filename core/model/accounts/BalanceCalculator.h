#pragma once

#include "../money/Money.h"
#include "../transactions/Transaction.h"
#include "../money/CurrencyConverter.h"

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