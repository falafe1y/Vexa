#pragma once

#include "../core/DepositSettings.h"

#include <QDate>
#include <QVector>
#include <QtGlobal>

// One step of the rate history of a deposit: the annual rate (in basis points) from a day on, until the next step.
// Steps are sorted by their day.
struct DepositRateStep
{
    QDate from;
    int annualRateBasisPoints = 0;
};

class DepositInterestCalculator
{
public:
    static qint64 interestMinor(
        qint64 balanceMinor,
        int annualRateBasisPoints,
        DepositPayoutFrequency frequency
        );

    // The rate in force on a day: the last step starting on or before it, the first step before any step starts,
    // and the fallback rate when there are no steps.
    static int rateOn(
        const QVector<DepositRateStep>& steps,
        int fallbackBasisPoints,
        const QDate& day
        );

    // Interest for the days [from, through): every day earns balance × the rate of that day, divided by 365.
    // The days are summed before rounding, so the result does not depend on how the period is split.
    static qint64 interestForPeriod(
        qint64 balanceMinor,
        const QVector<DepositRateStep>& steps,
        int fallbackBasisPoints,
        const QDate& from,
        const QDate& through
        );

    static QDate firstPayoutAfter(
        const QDate& configuredOn,
        DepositPayoutFrequency frequency,
        int payoutDay
        );

    static QVector<QDate> occurrences(
        const DepositSettings& settings,
        const QDate& from,
        const QDate& through
        );

private:
    static QDate monthlyPayout(int year, int month, int payoutDay);
    static QDate nextMonthlyPayoutAfter(const QDate& date, int payoutDay);
};
