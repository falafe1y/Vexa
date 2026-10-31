#include "../persistence/FinanceRepository.h"
#include "../core/db/DatabaseMaintenance.h"
#include "../core/db/AnalyticsRepository.h"
#include "../core/model/analytics/InvestmentBenchmark.h"
#include "../core/api/MoexBenchmarkParser.h"
#include <QTemporaryDir>
#include <QtTest>

class InvestmentBenchmarkRepositoryTest : public QObject {
    Q_OBJECT
private slots:
    void cacheSelectionBackupAndClear(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(r.isOpen());
        auto descriptor=investmentBenchmarkIndices().first().toMap();
        const QDate from(2025,1,1),to(2025,1,5);const QVariantList prices{
            QVariantMap{{"price_date","2025-01-02"},{"price_micros",123456789012345LL},{"currency","RUB"},{"issues",""}},
            QVariantMap{{"price_date","2025-01-03"},{"price_micros",QVariant()},{"currency","RUB"},{"issues","missing_close"}}};
        QVERIFY(AnalyticsRepository(r.database()).saveBenchmarkHistory(descriptor,prices,from,to));QCOMPARE(AnalyticsRepository(r.database()).loadBenchmarkSelection().value("key"),descriptor.value("key"));
        QVERIFY(AnalyticsRepository(r.database()).benchmarkHistoryCovered("index:IMOEX",from,to));QVERIFY(!AnalyticsRepository(r.database()).benchmarkHistoryCovered("index:IMOEX",from,to.addDays(1)));
        const auto saved=AnalyticsRepository(r.database()).loadBenchmarkPrices("index:IMOEX");QCOMPARE(saved.size(),2);QCOMPARE(saved.first().toMap().value("price_micros").toLongLong(),123456789012345LL);QVERIFY(saved.last().toMap().value("price_micros").isNull());
        const auto backup=dir.filePath("saved.db");QVERIFY(DatabaseMaintenance(r.database(), r.keyStore()).backupDatabase(backup));QVERIFY(DatabaseMaintenance(r.database(), r.keyStore()).clearAllUserData());QVERIFY(AnalyticsRepository(r.database()).loadBenchmarkPrices("index:IMOEX").isEmpty());QVERIFY(AnalyticsRepository(r.database()).loadBenchmarkSelection().isEmpty());
        QVERIFY(DatabaseMaintenance(r.database(), r.keyStore()).restoreDatabase(backup));QCOMPARE(AnalyticsRepository(r.database()).loadBenchmarkPrices("index:IMOEX").size(),2);QVERIFY(AnalyticsRepository(r.database()).benchmarkHistoryCovered("index:IMOEX",from,to));QCOMPARE(AnalyticsRepository(r.database()).loadBenchmarkSelection().value("key"),descriptor.value("key"));
    }
    void nativeParserRowsCanBeStored(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));const auto descriptor=investmentBenchmarkIndices().first().toMap();
        QVariantList raw,prices;QString error;int next;
        const QByteArray payload=R"({"history":{"columns":["BOARDID","TRADEDATE","CLOSE","CURRENCYID"],"data":[["SNDX","2025-01-01",100,"RUB"]]},"history.cursor":{"columns":["INDEX","TOTAL","PAGESIZE"],"data":[[0,1,100]]}})";
        QVERIFY(parseBenchmarkPage(payload,descriptor,raw,next,error));QVERIFY(mergeBenchmarkRows(raw,prices,error));
        QVERIFY2(AnalyticsRepository(r.database()).saveBenchmarkHistory(descriptor,prices,QDate(2025,1,1),QDate(2025,1,1)),qPrintable(r.lastError()));
        QCOMPARE(AnalyticsRepository(r.database()).loadBenchmarkPrices("index:IMOEX").first().toMap().value("price_micros").toLongLong(),100000000LL);
    }
    void failedHistoryWriteKeepsPreviousCache(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));auto descriptor=investmentBenchmarkIndices().first().toMap();
        const QDate date(2025,1,1);const QVariantMap price{{"price_date","2025-01-01"},{"price_micros",100000000},{"currency","RUB"},{"issues",""}};
        QVERIFY(AnalyticsRepository(r.database()).saveBenchmarkHistory(descriptor,{price},date,date));QVERIFY(!AnalyticsRepository(r.database()).saveBenchmarkHistory(descriptor,{price,price},date,date));
        QCOMPARE(AnalyticsRepository(r.database()).loadBenchmarkPrices("index:IMOEX").size(),1);QCOMPARE(AnalyticsRepository(r.database()).loadBenchmarkPrices("index:IMOEX").first().toMap().value("price_micros").toLongLong(),100000000LL);
        auto out=price;out["price_date"]="2026-01-01";QVERIFY(!AnalyticsRepository(r.database()).saveBenchmarkHistory(descriptor,{out},date,date));QCOMPARE(AnalyticsRepository(r.database()).loadBenchmarkPrices("index:IMOEX").size(),1);
    }
};
QTEST_GUILESS_MAIN(InvestmentBenchmarkRepositoryTest)
#include "InvestmentBenchmarkRepositoryTest.moc"
