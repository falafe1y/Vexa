#pragma once

#include "Currency.h"

#include <QDate>
#include <QStringList>
#include <QtGlobal>
#include <QVector>

struct CapitalSnapshot
{
    QDate date;
    Currency currency = Currency::RUB;
    qint64 totalMinor = 0;
};

struct FinancialTrajectorySettings
{
    int analysisMonths = 6;
    int horizonMonths = 12;
    // The default is the basic mode: the return is 3 points above inflation (6 %), income +10 %, expenses +5 %
    double annualReturnPercent = 9.0;
    double annualInflationPercent = 6.0;
    double incomeChangePercent = 10.0;
    double expenseChangePercent = 5.0;
    qint64 purchaseMinor = 0;
    int purchaseMonth = 0;
    // The sources the trajectory counts: every current one, or only the chosen ids ("account:", "wallet:", "exchange:")
    bool allSources = true;
    QStringList sourceIds;
};

struct FinancialTrajectoryInput
{
    qint64 currentCapitalMinor = 0;
    qint64 investmentCapitalMinor = 0;
    qint64 averageIncomeMinor = 0;
    qint64 averageExpenseMinor = 0;
    FinancialTrajectorySettings settings;
    QDate currentDate;
};

struct FinancialTrajectoryPoint
{
    QDate date;
    qint64 nominalMinor = 0;
    qint64 realMinor = 0;
    // Compound line: the savings are invested every month and earn the return too
    qint64 compoundMinor = 0;
};
