#include "../core/model/DepositInterestCalculator.h"

#include <QtTest>

class DepositInterestCalculatorTest final : public QObject
{
    Q_OBJECT

private slots:
    void calculatesMonthlyCompoundInterest();
    void calculatesDailyInterest();
    void clampsMonthlyPayoutToMonthEnd();
    void ratesChangeInsideAPeriodDayByDay();
};

void DepositInterestCalculatorTest::calculatesMonthlyCompoundInterest()
{
    const qint64 first = DepositInterestCalculator::interestMinor(
        21'000'000, 1'300, DepositPayoutFrequency::Monthly);
    QCOMPARE(first, 227'500);

    const qint64 second = DepositInterestCalculator::interestMinor(
        21'000'000 + first, 1'300, DepositPayoutFrequency::Monthly);
    QCOMPARE(second, 229'965);
}

void DepositInterestCalculatorTest::calculatesDailyInterest()
{
    QCOMPARE(
        DepositInterestCalculator::interestMinor(
            21'000'000, 1'300, DepositPayoutFrequency::Daily),
        7'479);
}

void DepositInterestCalculatorTest::clampsMonthlyPayoutToMonthEnd()
{
    const DepositSettings settings(
        QStringLiteral("deposit"),
        1'300,
        DepositPayoutFrequency::Monthly,
        31,
        QDate(2026, 1, 31),
        QDate(2026, 1, 30));

    QCOMPARE(
        DepositInterestCalculator::occurrences(
            settings, QDate(2026, 1, 31), QDate(2026, 4, 30)),
        QVector<QDate>({
            QDate(2026, 1, 31),
            QDate(2026, 2, 28),
            QDate(2026, 3, 31),
            QDate(2026, 4, 30)}));
}

void DepositInterestCalculatorTest::ratesChangeInsideAPeriodDayByDay()
{
    // 13% from January 1, 6% from February 1; no steps means the fallback rate
    const QVector<DepositRateStep> steps{{QDate(2026, 1, 1), 1'300}, {QDate(2026, 2, 1), 600}};
    QCOMPARE(DepositInterestCalculator::rateOn(steps, 900, QDate(2025, 12, 31)), 1'300);
    QCOMPARE(DepositInterestCalculator::rateOn(steps, 900, QDate(2026, 2, 1)), 600);
    QCOMPARE(DepositInterestCalculator::rateOn({}, 900, QDate(2026, 2, 1)), 900);

    // 100 000 RUB at 13% for the 31 days of January: 110 411 kopecks, rounded once for the whole period
    QCOMPARE(DepositInterestCalculator::interestForPeriod(
                 10'000'000, steps, 900, QDate(2026, 1, 1), QDate(2026, 2, 1)),
             110'411);

    // From January 17 up to February 2 (not included): 15 days at 13%, then February 1 at 6%
    QCOMPARE(DepositInterestCalculator::interestForPeriod(
                 10'000'000, steps, 900, QDate(2026, 1, 17), QDate(2026, 2, 2)),
             55'068);
}

QTEST_MAIN(DepositInterestCalculatorTest)
#include "DepositInterestCalculatorTest.moc"
