#include "FinancialTrajectoryCalculator.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace
{
qint64 roundedMinor(const long double value)
{
    if (value >= std::numeric_limits<qint64>::max())
        return std::numeric_limits<qint64>::max();
    if (value <= std::numeric_limits<qint64>::min())
        return std::numeric_limits<qint64>::min();
    return static_cast<qint64>(std::llround(value));
}
}
QVector<FinancialTrajectoryPoint> FinancialTrajectoryCalculator::calculate(
    const FinancialTrajectoryInput& input)
{
    const auto& settings = input.settings;
    const int horizon = std::clamp(settings.horizonMonths, 1, 600);
    const long double monthlyReturn =
        std::pow(1.0L + std::max(-99.0, settings.annualReturnPercent) / 100.0L,
                 1.0L / 12.0L) - 1.0L;
    const long double monthlyInflation =
        std::pow(1.0L + std::max(-99.0, settings.annualInflationPercent) / 100.0L,
                 1.0L / 12.0L);
    const long double income = input.averageIncomeMinor *
        (1.0L + settings.incomeChangePercent / 100.0L);
    long double expense = input.averageExpenseMinor *
        (1.0L + settings.expenseChangePercent / 100.0L);
    long double capital = input.currentCapitalMinor;
    long double invested = std::max<qint64>(0, input.investmentCapitalMinor);
    // Compound line: the investments and every month's savings earn the return, cash does not (as in the forecast line)
    long double compoundInvested = invested;
    long double compoundCash = static_cast<long double>(input.currentCapitalMinor) - invested;

    QVector<FinancialTrajectoryPoint> result;
    result.reserve(horizon + 1);
    result.append({input.currentDate, input.currentCapitalMinor,
                   input.currentCapitalMinor, input.currentCapitalMinor});
    long double accumulatedInflation = 1.0L;
    for (int month = 1; month <= horizon; ++month) {
        const long double investmentGain = invested * monthlyReturn;
        invested += investmentGain;
        const long double saving = income - expense;
        capital += saving + investmentGain;
        compoundInvested = compoundInvested * (1.0L + monthlyReturn) + saving;
        if (settings.purchaseMinor > 0 && settings.purchaseMonth == month) {
            capital -= settings.purchaseMinor;
            compoundCash -= settings.purchaseMinor;
        }
        accumulatedInflation *= monthlyInflation;
        result.append({input.currentDate.addMonths(month), roundedMinor(capital),
                       roundedMinor(capital / accumulatedInflation),
                       roundedMinor(compoundInvested + compoundCash)});
        expense *= monthlyInflation;
    }
    return result;
}
