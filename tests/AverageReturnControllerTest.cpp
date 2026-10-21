#include "../interface/FinanceController.h"
#include <QTemporaryDir>
#include <QStandardPaths>
#include <QtTest>

class AverageReturnControllerTest : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() { QStandardPaths::setTestModeEnabled(true); }

    void instrumentsAreListedWithTheirReasonsAndSelectionChangesTheGroups()
    {
        QTemporaryDir dir;
        const auto path = dir.filePath("data.db");
        {
            FinanceRepository r(path);
            QVERIFY(r.saveAutomaticCurrencyRates(false));
            QVERIFY(r.saveManualCurrencyRates(1, 100, 120));
            QVERIFY(r.insertAccount({"broker", "Брокер", AssetType::Investment, AccountType::Brokerage, Currency::RUB, 1000000}));
            QVERIFY(r.insertAccount({"deposit", "Вклад", AssetType::Investment, AccountType::Deposit, Currency::RUB, 200000}));
        }
        FinanceController c(nullptr, path);
        c.setSelectedAsset("investment");
        const auto bought = c.saveInvestmentPosition({{"accountId", "broker"}, {"searchIndex", -2}, {"instrumentType", 0},
            {"name", QStringLiteral("Акция")}, {"symbol", QStringLiteral("SHARE")}, {"quantity", "2"}, {"averagePrice", "100"},
            {"manualValuation", true}, {"manualValue", "250"}, {"purchase", true}, {"cashAmount", "-200"}});
        QVERIFY2(bought.value("ok").toBool(), qPrintable(bought.value("error").toString()));

        // Neither has an annual rate yet, and each says why: the deposit has no rate in its settings,
        // the position was bought today and has no history of 30 days
        const QVariantList items = c.averageReturnItems();
        QCOMPARE(int(items.size()), 2);
        for (const QVariant& value : items) {
            const QVariantMap row = value.toMap();
            QVERIFY(row.value("annualPercent").isNull());
            const QString expected = row.value("id").toString().startsWith(QStringLiteral("deposit:"))
                ? QStringLiteral("ставки")
                : QStringLiteral("30 дней");
            QVERIFY(row.value("reason").toString().contains(expected));
        }
        QVERIFY(c.averageReturnSummary().value("merged").toBool());

        // Leaving the deposit out makes two separate groups; the investments group keeps the position only
        c.setAverageReturnSelection(QStringList{"deposit:deposit"}, false);
        const QVariantMap split = c.averageReturnSummary();
        QVERIFY(!split.value("merged").toBool());
        const QVariantList groups = split.value("groups").toList();
        QCOMPARE(int(groups.size()), 2);
        QCOMPARE(groups.first().toMap().value("shown").toInt(), 1);
        QCOMPARE(groups.first().toMap().value("valueMinor").toLongLong(), qint64(25000));
        QCOMPARE(groups.last().toMap().value("shown").toInt(), 0);
    }
};

QTEST_GUILESS_MAIN(AverageReturnControllerTest)
#include "AverageReturnControllerTest.moc"
