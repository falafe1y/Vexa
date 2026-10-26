#include "../core/model/analytics/FinancialTrajectoryCalculator.h"

#include <cmath>
#include <cstdlib>
#include <QtTest>

class FinancialTrajectoryCalculatorTest : public QObject
{
    Q_OBJECT
private slots:
    void addsMonthlyCashFlow();
    void appliesReturnInflationAndPurchase();
    void addsCompoundInterestOnSavings();
    void cashDoesNotEarnTheCompoundReturn();
};

void FinancialTrajectoryCalculatorTest::addsMonthlyCashFlow()
{
    FinancialTrajectoryInput input;
    input.currentDate = QDate(2026, 9, 22);
    input.currentCapitalMinor = 1'000'000;
    input.averageIncomeMinor = 200'000;
    input.averageExpenseMinor = 150'000;
    input.settings.horizonMonths = 6;
    input.settings.annualReturnPercent = 0;
    input.settings.annualInflationPercent = 0;
    input.settings.incomeChangePercent = 0;
    input.settings.expenseChangePercent = 0;
    const auto points = FinancialTrajectoryCalculator::calculate(input);
    QCOMPARE(points.size(), 7);
    QCOMPARE(points.last().nominalMinor, 1'300'000);
    QCOMPARE(points.last().realMinor, 1'300'000);
    QCOMPARE(points.last().date, QDate(2027, 3, 22));
}

void FinancialTrajectoryCalculatorTest::appliesReturnInflationAndPurchase()
{
    FinancialTrajectoryInput input;
    input.currentDate = QDate(2026, 1, 31);
    input.currentCapitalMinor = 2'000'000;
    input.investmentCapitalMinor = 1'000'000;
    input.settings.horizonMonths = 12;
    input.settings.annualReturnPercent = 12;
    input.settings.annualInflationPercent = 10;
    input.settings.purchaseMinor = 500'000;
    input.settings.purchaseMonth = 3;
    const auto points = FinancialTrajectoryCalculator::calculate(input);
    QVERIFY(points.at(1).nominalMinor > input.currentCapitalMinor);
    QVERIFY(points.at(3).nominalMinor < points.at(2).nominalMinor);
    QVERIFY(points.last().realMinor < points.last().nominalMinor);
    QCOMPARE(points.last().date, QDate(2027, 1, 31));
}

void FinancialTrajectoryCalculatorTest::addsCompoundInterestOnSavings()
{
    FinancialTrajectoryInput input;
    input.currentDate = QDate(2026, 1, 31);
    input.currentCapitalMinor = 1'000'000;
    input.investmentCapitalMinor = 1'000'000;
    input.averageIncomeMinor = 50'000;
    input.settings.incomeChangePercent = 0;
    input.settings.expenseChangePercent = 0;
    input.settings.horizonMonths = 12;
    input.settings.annualReturnPercent = 12;
    input.settings.annualInflationPercent = 0;
    const auto points = FinancialTrajectoryCalculator::calculate(input);
    // The investments and every month's saving earn 12 % a year, compounded monthly
    const long double monthly = std::pow(1.12L, 1.0L / 12.0L);
    long double expected = 1'000'000;
    for (int month = 0; month < 12; ++month)
        expected = expected * monthly + 50'000;
    QCOMPARE(points.first().compoundMinor, qint64(1'000'000));
    QVERIFY(std::llabs(points.last().compoundMinor - std::llround(expected)) <= 2);
    // The nominal line adds the savings without interest, so the compound line is higher
    QVERIFY(points.last().compoundMinor > points.last().nominalMinor);
}

void FinancialTrajectoryCalculatorTest::cashDoesNotEarnTheCompoundReturn()
{
    FinancialTrajectoryInput input;
    input.currentDate = QDate(2026, 1, 31);
    input.currentCapitalMinor = 1'000'000;
    input.settings.horizonMonths = 12;
    input.settings.annualReturnPercent = 12;
    input.settings.annualInflationPercent = 0;
    const auto points = FinancialTrajectoryCalculator::calculate(input);
    QCOMPARE(points.last().compoundMinor, qint64(1'000'000));
}

QTEST_APPLESS_MAIN(FinancialTrajectoryCalculatorTest)
#include "FinancialTrajectoryCalculatorTest.moc"
