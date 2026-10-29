#include "../interface/FinanceController.h"
#include "../core/db/SettingsRepository.h"
#include <QTemporaryDir>
#include <QStandardPaths>
#include <QtTest>

namespace {
QVariantMap accountNamed(FinanceController& controller, const QString& name)
{
    for (const QVariant& value : controller.accounts()) {
        if (value.toMap().value(QStringLiteral("rawName")).toString() == name) {
            return value.toMap();
        }
    }
    return {};
}

// The trajectory's current capital, in kopecks
qint64 currentMinor(FinanceController& controller)
{
    return controller.financialTrajectory().value(QStringLiteral("currentMinor")).toLongLong();
}

QVariantMap selection(bool allSources, const QStringList& sourceIds)
{
    return {{QStringLiteral("allSources"), allSources}, {QStringLiteral("sourceIds"), sourceIds}};
}

void prepareRates(const QString& path)
{
    FinanceRepository r(path);
    QVERIFY(SettingsRepository(r.database()).saveAutomaticCurrencyRates(false));
    QVERIFY(SettingsRepository(r.database()).saveManualCurrencyRates(1, 100, 120));
}
} // namespace

class TrajectoryControllerTest : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() { QStandardPaths::setTestModeEnabled(true); }

    void defaultsAreTheBasicMode()
    {
        QTemporaryDir dir;
        const auto path = dir.filePath("data.db");
        prepareRates(path);
        FinanceController c(nullptr, path);
        const QVariantMap trajectory = c.financialTrajectory();
        // Inflation 6 % plus 3 points, income +10 %, expenses +5 %
        QCOMPARE(trajectory.value(QStringLiteral("annualReturnPercent")).toDouble(), 9.0);
        QCOMPARE(trajectory.value(QStringLiteral("incomeChangePercent")).toDouble(), 10.0);
        QCOMPARE(trajectory.value(QStringLiteral("expenseChangePercent")).toDouble(), 5.0);
        QVERIFY(trajectory.value(QStringLiteral("allSources")).toBool());
    }

    void expenseHistoryLeavesTransfersOut()
    {
        QTemporaryDir dir;
        const auto path = dir.filePath("data.db");
        prepareRates(path);
        FinanceController c(nullptr, path);
        QVERIFY(c.addAccount("Наличка", "cash", "RUB", 600000, 0));
        QVERIFY(c.addAccount("Копилка", "cash", "RUB", 0, 0));
        const QString cash = accountNamed(c, "Наличка").value("id").toString();
        const QString piggy = accountNamed(c, "Копилка").value("id").toString();
        QVERIFY(c.addExpense(100000, QStringLiteral("Покупка"), QStringLiteral("other_expense"),
                             QStringLiteral("RUB"), cash, QDateTime::currentDateTime()));
        QVERIFY(c.addTransfer(500000, QStringLiteral("Копилка"), cash, piggy, QDateTime::currentDateTime()));

        const QVariantList history = c.expenseHistoryByMonthRub();
        QVERIFY(!history.isEmpty());
        // The current month holds only the purchase: the transfer to the other account is not spending
        QCOMPARE(history.last().toMap().value(QStringLiteral("totalMinor")).toLongLong(), qint64(100000));
    }

    void trajectoryCountsOnlyTheChosenSources()
    {
        QTemporaryDir dir;
        const auto path = dir.filePath("data.db");
        prepareRates(path);
        QString cash;
        {
            FinanceController c(nullptr, path);
            QVERIFY(c.addAccount("Наличка", "cash", "RUB", 600000, 0));
            QVERIFY(c.addAccount("Копилка", "cash", "RUB", 300000, 0));
            cash = accountNamed(c, "Наличка").value("id").toString();
            QCOMPARE(currentMinor(c), qint64(900000));

            QVERIFY(c.saveFinancialTrajectorySettings(selection(false, {"account:" + cash})).value("ok").toBool());
            QCOMPARE(currentMinor(c), qint64(600000));
        }
        {
            // The choice is kept after a restart
            FinanceController again(nullptr, path);
            QCOMPARE(currentMinor(again), qint64(600000));
            QVERIFY(!again.financialTrajectory().value(QStringLiteral("allSources")).toBool());
        }
    }

    void trajectoryRejectsAnEmptyOrUnknownSelection()
    {
        QTemporaryDir dir;
        const auto path = dir.filePath("data.db");
        prepareRates(path);
        FinanceController c(nullptr, path);
        QVERIFY(c.addAccount("Наличка", "cash", "RUB", 600000, 0));
        QVERIFY(!c.saveFinancialTrajectorySettings(selection(false, {})).value("ok").toBool());
        QVERIFY(!c.saveFinancialTrajectorySettings(selection(false, {"account:missing"})).value("ok").toBool());

        // Both answers keep the previous choice: every source counts
        QCOMPARE(currentMinor(c), qint64(600000));
        QVERIFY(c.financialTrajectory().value(QStringLiteral("allSources")).toBool());
    }

    void trajectoryHistoryFollowsTheChosenSources()
    {
        QTemporaryDir dir;
        const auto path = dir.filePath("data.db");
        prepareRates(path);
        FinanceController c(nullptr, path);
        QVERIFY(c.addAccount("Наличка", "cash", "RUB", 600000, 0));
        QVERIFY(c.addAccount("Копилка", "cash", "RUB", 300000, 0));
        const QString cash = accountNamed(c, "Наличка").value("id").toString();

        QVariantList history = c.financialTrajectory().value(QStringLiteral("history")).toList();
        QVERIFY(!history.isEmpty());
        QCOMPARE(history.last().toMap().value(QStringLiteral("valueMinor")).toLongLong(), qint64(900000));

        QVERIFY(c.saveFinancialTrajectorySettings(selection(false, {"account:" + cash})).value("ok").toBool());
        history = c.financialTrajectory().value(QStringLiteral("history")).toList();
        QVERIFY(!history.isEmpty());
        QCOMPARE(history.last().toMap().value(QStringLiteral("valueMinor")).toLongLong(), qint64(600000));
    }

    void forecastHasACompoundLine()
    {
        QTemporaryDir dir;
        const auto path = dir.filePath("data.db");
        prepareRates(path);
        FinanceController c(nullptr, path);
        QVERIFY(c.addAccount("Наличка", "cash", "RUB", 600000, 0));
        const QVariantList forecast = c.financialTrajectory().value(QStringLiteral("forecast")).toList();
        QVERIFY(forecast.size() > 1);
        QVERIFY(forecast.last().toMap().contains(QStringLiteral("compoundMinor")));
        // No savings and no investments: cash does not earn the return, so the line stays at today's capital
        QCOMPARE(forecast.last().toMap().value(QStringLiteral("compoundMinor")).toLongLong(), qint64(600000));
    }
};

QTEST_GUILESS_MAIN(TrajectoryControllerTest)
#include "TrajectoryControllerTest.moc"
