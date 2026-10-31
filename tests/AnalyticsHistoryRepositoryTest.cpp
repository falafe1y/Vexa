#include "../persistence/FinanceRepository.h"
#include "../core/db/DatabaseMaintenance.h"
#include "../core/db/TransactionRepository.h"
#include "../core/db/AccountRepository.h"
#include "../core/db/AnalyticsRepository.h"
#include "../core/db/CryptoRepository.h"
#include "../core/db/InvestmentRepository.h"
#include "../core/db/CipherDriver.h"
#include "../core/db/PortableBackup.h"
#include <QTemporaryDir>
#include <QSqlQuery>
#include <QSqlError>
#include <QTimeZone>
#include <QtTest>
#include <limits>

class AnalyticsHistoryRepositoryTest : public QObject {
    Q_OBJECT
private:
    static Account broker(){return {"broker","Брокер",AssetType::Investment,AccountType::Brokerage,Currency::RUB,1'000'000};}
    static InvestmentInstrument stock(){return {"stock","TEST","","Акция",InvestmentInstrumentType::Stock,Currency::RUB};}
    static InvestmentPosition position(qint64 quantity=3'000'000){return {"position","broker","stock",quantity,100'000'000};}
    static InvestmentOperation operation(const QString& id,const QString& kind,qint64 cash,qint64 delta){
        InvestmentOperation op{id,"broker","position","stock",kind,cash,delta,QDateTime::currentDateTimeUtc(),""};op.feeMinor=0;op.taxMinor=0;return op;
    }
    static DailyValuationBatch batch(const QDateTime& at=QDateTime::currentDateTimeUtc()){
        DailyValuationBatch b;b.observedAtUtc=at;b.date=at.toLocalTime().date();
        AssetDailyValuation a;a.sourceId="cash:fiat";a.accountId="fiat";a.currency="USD";a.valueMinor=12345;
        a.valuedAtUtc=at;a.source="ledger";b.assets.append(a);
        a.kind=AssetDailyValuation::Crypto;a.sourceId="wallet:crypto";a.accountId="crypto";a.instrumentId="BTC";
        a.valueMinor={};a.quantityAtomic=100000000;a.source="unavailable";a.issues="missing_price";b.assets.append(a);
        a.kind=AssetDailyValuation::Investment;a.sourceId="position:p";a.accountId="broker";a.instrumentId="stock";
        a.currency="RUB";a.valueMinor=9'007'199'254'741'009LL;a.priceMicros=110'000'000;a.quantityAtomic=3'000'000;
        a.costBasisMinor=9'007'199'254'740'993LL;a.source="market";a.issues="";b.assets.append(a);
        b.rates.append({"USD","manual",b.date,at,100'000'000});return b;
    }
    static bool raw(const QString& path,const QStringList& statements){
        const auto connection=QUuid::createUuid().toString();bool ok=true;
        {auto db=addCipherDatabase(connection);db.setDatabaseName(path);ok=db.open();
         if(ok){QSqlQuery q(db);for(const auto& sql:statements)if(!q.exec(sql)){qWarning()<<q.lastError();ok=false;break;}}}
        QSqlDatabase::removeDatabase(connection);return ok;
    }
private slots:
    void averagePriceSuppliesInitialCostAndSalesUseIt(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
        QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},false));
        QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(30000));
        QVERIFY(InvestmentRepository(r.database()).loadInvestmentOperations().isEmpty());
        const auto prior=InvestmentRepository(r.database()).loadInvestmentPositions().at(0);
        QVERIFY(InvestmentRepository(r.database()).bookInvestmentOperation(operation("sale","sell",15000,-1'000'000),prior,position(2'000'000),false));
        const auto row=InvestmentRepository(r.database()).loadPositionHistory("position").last().toMap();
        QCOMPARE(row.value("released_cost_minor").toLongLong(),qint64(10000));
        QCOMPARE(row.value("realized_net_minor").toLongLong(),qint64(5000));
        QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(20000));
    }
    void explicitCostsAndNetPurchasesOverrideAverage(){
        QTemporaryDir dir;const auto path=dir.filePath("data.db");
        {FinanceRepository r(path);QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
         QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},false,{},30001));
         QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(30001));
         QVERIFY(InvestmentRepository(r.database()).updateInvestmentPosition(position()));
         QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(30001));
         QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},true,{},0));
         QVERIFY(!InvestmentRepository(r.database()).investmentCostBasis("position").isNull());
         QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(0));
         QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},true,{},std::nullopt,true));
         QVERIFY(InvestmentRepository(r.database()).investmentCostBasis("position").isNull());}
        FinanceRepository r(path);QVERIFY(InvestmentRepository(r.database()).investmentCostBasis("position").isNull());
        QVERIFY(InvestmentRepository(r.database()).updateInvestmentPosition(position()));QVERIFY(InvestmentRepository(r.database()).investmentCostBasis("position").isNull());
    }
    void ambiguousAveragePricesStayUnknown(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
        const auto check=[&](const QString& id,InvestmentInstrumentType type,Currency currency,InvestmentTerms terms,qint64 average){
            const InvestmentInstrument instrument(id,id,"",id,type,currency,"","",terms);
            const InvestmentPosition p(id,"broker",id,1'000'000,average);
            return InvestmentRepository(r.database()).saveInvestmentBundle(instrument,p,{},false) && InvestmentRepository(r.database()).investmentCostBasis(id).isNull();
        };
        QVERIFY(check("zero",InvestmentInstrumentType::Stock,Currency::RUB,{},0));
        QVERIFY(check("foreign",InvestmentInstrumentType::Stock,Currency::USD,{},100'000'000));
        InvestmentTerms t;t.currencyCode="USD";
        QVERIFY(check("foreign-terms",InvestmentInstrumentType::Stock,Currency::RUB,t,100'000'000));
        QVERIFY(check("bond",InvestmentInstrumentType::Bond,Currency::RUB,{},100'000'000));
        QVERIFY(check("future",InvestmentInstrumentType::Future,Currency::RUB,{},100'000'000));
        QVERIFY(check("option",InvestmentInstrumentType::Option,Currency::RUB,{},100'000'000));
        t={};t.multiplierMicros=10'000'000;
        QVERIFY(check("multiplier",InvestmentInstrumentType::Stock,Currency::RUB,t,100'000'000));
    }
    void averageCostRoundsOnceAndHandlesLargeIntegers(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
        QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),{"position","broker","stock",1'005'000,1'000'000},{},false));
        QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(101));
        const qint64 price=9'007'199'254'740'993LL;
        QVERIFY(InvestmentRepository(r.database()).updateInvestmentPosition({"position","broker","stock",1'000'000,price}));
        QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),(price+5000)/10000);
        QVERIFY(InvestmentRepository(r.database()).updateInvestmentPosition({"position","broker","stock",std::numeric_limits<qint64>::max(),std::numeric_limits<qint64>::max()}));
        QVERIFY(InvestmentRepository(r.database()).investmentCostBasis("position").isNull());
    }
    void previousInitialStatesAreRepairedOnceWithoutRewritingSnapshots(){
        QTemporaryDir dir;const auto path=dir.filePath("data.db");
        {FinanceRepository r(path);QVERIFY(AccountRepository(r.database()).insertAccount(broker()));QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},false));
         auto b=batch();b.assets.last().sourceId="position:position";b.assets.last().costBasisMinor.reset();b.assets.last().issues="cost_unknown";
         QVERIFY(AnalyticsRepository(r.database()).saveDailyValuations(b));}
        QVERIFY(raw(path,{"UPDATE investment_position_history SET cost_basis_minor=NULL,issues='cost_unknown'"}));
        {FinanceRepository r(path);QVERIFY2(r.isOpen(),qPrintable(r.lastError()));
         QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(30000));
         const auto history=InvestmentRepository(r.database()).loadPositionHistory("position");QCOMPARE(history.size(),2);
         QVERIFY(history.first().toMap().value("cost_basis_minor").isNull());
         QCOMPARE(history.last().toMap().value("event").toString(),QString("correction"));
         QVERIFY(InvestmentRepository(r.database()).loadInvestmentOperations().isEmpty());
         QVERIFY(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Investment).first().toMap().value("cost_basis_minor").isNull());}
        FinanceRepository r(path);QCOMPARE(InvestmentRepository(r.database()).loadPositionHistory("position").size(),2);
    }
    void dailySnapshotsAreSeparateNativeAndAtomic(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(r.isOpen());auto b=batch();
        QVERIFY2(AnalyticsRepository(r.database()).saveDailyValuations(b),qPrintable(r.lastError()));
        QCOMPARE(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Fiat).at(0).toMap().value("currency").toString(),QString("USD"));
        QVERIFY(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Crypto).at(0).toMap().value("value_minor").isNull());
        QCOMPARE(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Investment).at(0).toMap().value("value_minor").toLongLong(),9'007'199'254'741'009LL);
        auto bad=b;bad.assets[0].valueMinor=0;bad.assets.append(bad.assets[0]);
        QVERIFY(!AnalyticsRepository(r.database()).saveDailyValuations(bad));
        QCOMPARE(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Fiat).at(0).toMap().value("value_minor").toLongLong(),qint64(12345));
        b.assets[0].valueMinor=500;QVERIFY(AnalyticsRepository(r.database()).saveDailyValuations(b));QCOMPARE(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Fiat).size(),1);
        auto older=b;older.observedAtUtc=older.observedAtUtc.addMSecs(-1);older.assets[0].valueMinor=1;
        QVERIFY(AnalyticsRepository(r.database()).saveDailyValuations(older));QCOMPARE(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Fiat).at(0).toMap().value("value_minor").toLongLong(),qint64(500));
        auto yesterday=batch(b.observedAtUtc.addDays(-1));QVERIFY(AnalyticsRepository(r.database()).saveDailyValuations(yesterday));
        QCOMPARE(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Fiat).size(),2);
        QCOMPARE(AnalyticsRepository(r.database()).loadFxHistory("USD").size(),2);
        QCOMPARE(AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Fiat,b.date,b.date).size(),1);
    }
    void partialSalesAllocateAllCostAndNeverDoubleCharge(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
        auto opening=operation("opening","buy",-10001,3'000'000);opening.feeMinor=1;
        QVERIFY2(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},false,opening),qPrintable(r.lastError()));
        QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(10001));
        auto prior=InvestmentRepository(r.database()).loadInvestmentPositions().at(0);auto next=position(2'000'000);
        auto sell=operation("sell-1","sell",4000,-1'000'000);sell.feeMinor=100;
        QVERIFY2(InvestmentRepository(r.database()).bookInvestmentOperation(sell,prior,next,false),qPrintable(r.lastError()));
        auto history=InvestmentRepository(r.database()).loadPositionHistory("position");QCOMPARE(history.size(),2);
        QCOMPARE(history.last().toMap().value("released_cost_minor").toLongLong(),qint64(3333));
        QCOMPARE(history.last().toMap().value("realized_net_minor").toLongLong(),qint64(667));
        QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(6668));
        prior=InvestmentRepository(r.database()).loadInvestmentPositions().at(0);sell=operation("sell-2","sell",9000,-2'000'000);
        QVERIFY(InvestmentRepository(r.database()).bookInvestmentOperation(sell,prior,prior,true));
        history=InvestmentRepository(r.database()).loadPositionHistory("position");QCOMPARE(history.last().toMap().value("released_cost_minor").toLongLong(),qint64(6668));
        QCOMPARE(history.last().toMap().value("realized_net_minor").toLongLong(),qint64(2332));
        QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(0));QVERIFY(InvestmentRepository(r.database()).loadInvestmentPositions().isEmpty());
        qint64 cash=broker().initialBalanceMinor();for(const auto& op:InvestmentRepository(r.database()).loadInvestmentOperations())cash+=op.cashDeltaMinor;
        QCOMPARE(cash,qint64(1'002'999));
        QCOMPARE(InvestmentRepository(r.database()).loadInvestmentOperations().at(0).taxMinor.value_or(-1),qint64(0));
    }
    void missingCostIsNotInventedAndCorrectionsAreRecorded(){
        QTemporaryDir dir;const auto path=dir.filePath("data.db");
        {FinanceRepository r(path);QVERIFY(AccountRepository(r.database()).insertAccount(broker()));InvestmentPosition unknown("position","broker","stock",3'000'000,0);QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),unknown,{},false));
         QVERIFY(InvestmentRepository(r.database()).investmentCostBasis("position").isNull());auto old=InvestmentRepository(r.database()).loadInvestmentPositions().at(0);
         QVERIFY(InvestmentRepository(r.database()).bookInvestmentOperation(operation("sale","sell",5000,-1'000'000),old,position(2'000'000),false));
         QVERIFY(InvestmentRepository(r.database()).loadPositionHistory("position").last().toMap().value("realized_net_minor").isNull());
         QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(2'000'000),{},true,{},9000));
         QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(9000));
         QVERIFY(InvestmentRepository(r.database()).updateInvestmentPosition(position(1'000'000)));QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(10000));
         QVERIFY(InvestmentRepository(r.database()).deleteInvestmentPosition("position"));QVERIFY(InvestmentRepository(r.database()).loadInvestmentPositions().isEmpty());}
        FinanceRepository reopened(path);const auto history=InvestmentRepository(reopened.database()).loadPositionHistory("position");
        QCOMPARE(history.size(),5);QCOMPARE(history.last().toMap().value("event").toString(),QString("delete"));
    }
    void historyFailureRollsBackPositionAndOperation(){
        QTemporaryDir dir;const auto path=dir.filePath("data.db");FinanceRepository r(path);QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
        QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},false,operation("buy","buy",-10000,3'000'000)));
        QVERIFY(raw(path,{"CREATE TRIGGER fail_history BEFORE INSERT ON investment_position_history BEGIN SELECT RAISE(ABORT,'history failure'); END"}));
        const auto old=InvestmentRepository(r.database()).loadInvestmentPositions().at(0);
        QVERIFY(!InvestmentRepository(r.database()).bookInvestmentOperation(operation("sell","sell",5000,-1'000'000),old,position(2'000'000),false));
        QCOMPARE(InvestmentRepository(r.database()).loadInvestmentPositions().at(0).quantityMicros(),qint64(3'000'000));
        QCOMPARE(InvestmentRepository(r.database()).loadInvestmentOperations().size(),1);QCOMPARE(InvestmentRepository(r.database()).loadPositionHistory("position").size(),1);
        QVERIFY(!InvestmentRepository(r.database()).deleteInvestmentPosition("position"));QCOMPARE(InvestmentRepository(r.database()).loadInvestmentPositions().size(),1);
    }
    void priceHistorySurvivesNewPricesAndMigration(){
        QTemporaryDir dir;const auto path=dir.filePath("data.db");const auto now=QDateTime::currentDateTimeUtc();
        {FinanceRepository r(path);QVERIFY(AccountRepository(r.database()).insertAccount(broker()));QVERIFY(InvestmentRepository(r.database()).insertInvestmentInstrument(stock()));
         QVERIFY(InvestmentRepository(r.database()).saveInvestmentQuote({"stock",100'000'000,now.addDays(-1)}));QVERIFY(InvestmentRepository(r.database()).saveInvestmentQuote({"stock",110'000'000,now}));
         QVERIFY(CryptoRepository(r.database()).saveCryptoPrice("BTC",1'000'000,now.addDays(-1)));QVERIFY(CryptoRepository(r.database()).saveCryptoPrice("BTC",2'000'000,now));}
        FinanceRepository r(path);QCOMPARE(InvestmentRepository(r.database()).loadInvestmentQuotes().at(0).priceMicros(),qint64(110'000'000));
        // Failed publication of a quote must not create a history point.
        QVERIFY(!InvestmentRepository(r.database()).saveInvestmentQuote({"missing",123,now}));
        const auto connection=QUuid::createUuid().toString();
        {auto db=addCipherDatabase(connection);db.setDatabaseName(path);QVERIFY(db.open());QSqlQuery q(db);
         QVERIFY(q.exec("SELECT count(*),min(price_micros),max(price_micros) FROM investment_price_history"));QVERIFY(q.next());
         QCOMPARE(q.value(0).toInt(),2);QCOMPARE(q.value(1).toLongLong(),qint64(100'000'000));QCOMPARE(q.value(2).toLongLong(),qint64(110'000'000));
         QVERIFY(q.exec("SELECT count(*) FROM crypto_price_history"));QVERIFY(q.next());QCOMPARE(q.value(0).toInt(),2);}
        QSqlDatabase::removeDatabase(connection);
    }
    void oldSchemaPreservesUnknownChargesAndInitialState(){
        QTemporaryDir dir;const auto path=dir.filePath("data.db");
        {FinanceRepository r(path);QVERIFY(AccountRepository(r.database()).insertAccount(broker()));QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},false,operation("old","buy",-10000,3'000'000)));}
        QVERIFY(raw(path,{"PRAGMA foreign_keys=OFF","DROP TRIGGER history_transactions_insert","DROP TRIGGER history_transactions_update","DROP TRIGGER history_transactions_delete","DROP TRIGGER history_account_basis","DROP TABLE investment_position_history", "DROP TABLE fiat_daily_snapshots",
            "DROP TABLE crypto_daily_snapshots","DROP TABLE investment_daily_snapshots","DROP TABLE daily_valuation_runs",
            "DROP TABLE fx_rate_history","DROP TABLE crypto_price_history","DROP TABLE investment_price_history",
            "CREATE TABLE investment_operations(id TEXT PRIMARY KEY,account_id TEXT NOT NULL REFERENCES accounts(id),position_id TEXT REFERENCES investment_positions(id) ON DELETE SET NULL,instrument_id TEXT NOT NULL REFERENCES investment_instruments(id),kind TEXT NOT NULL CHECK(kind IN ('buy','sell','coupon','dividend','amortization','fee','margin','expiry')),cash_delta_minor INTEGER NOT NULL,quantity_delta_micros INTEGER NOT NULL DEFAULT 0,occurred_at INTEGER NOT NULL,description TEXT NOT NULL DEFAULT '')","INSERT INTO investment_operations SELECT id,account_id,position_id,instrument_id,kind,CASE WHEN type=0 THEN amount_minor ELSE -amount_minor END,quantity_micros,occurred_at,description FROM transactions WHERE kind IN ('buy','sell','coupon','dividend','amortization','fee','margin','expiry')","DELETE FROM transactions WHERE kind IN ('buy','sell','coupon','dividend','amortization','fee','margin','expiry')","CREATE TABLE transactions_old(id TEXT PRIMARY KEY,account_id TEXT NOT NULL REFERENCES accounts(id),category_id TEXT NOT NULL REFERENCES categories(id),type INTEGER NOT NULL CHECK(type IN (0,1)),amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),occurred_at INTEGER NOT NULL,description TEXT NOT NULL DEFAULT '',recipient_json TEXT NOT NULL DEFAULT '{}',project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,created_at INTEGER NOT NULL)","INSERT INTO transactions_old SELECT id,account_id,category_id,type,amount_minor,occurred_at,description,recipient_json,project_id,created_at FROM transactions","DROP TABLE transactions","ALTER TABLE transactions_old RENAME TO transactions"}));
        {FinanceRepository r(path);QVERIFY2(r.isOpen(),qPrintable(r.lastError()));QCOMPARE(InvestmentRepository(r.database()).loadInvestmentOperations().size(),1);
         QVERIFY(!InvestmentRepository(r.database()).loadInvestmentOperations().at(0).feeMinor);QVERIFY(!InvestmentRepository(r.database()).loadInvestmentOperations().at(0).taxMinor);
         QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(30000));QCOMPARE(InvestmentRepository(r.database()).loadPositionHistory("position").size(),1);}
        FinanceRepository r(path);QCOMPARE(InvestmentRepository(r.database()).loadPositionHistory("position").size(),1);QCOMPARE(InvestmentRepository(r.database()).loadInvestmentPositions().at(0).quantityMicros(),qint64(3'000'000));
    }
    void amortizationReleasesProportionalCost(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
        InvestmentTerms t;t.pricing="bond";t.currencyCode="RUB";t.faceValueMicros=1'000'000'000;t.accruedInterestMicros=0;
        const InvestmentInstrument bond("stock","BOND","","Облигация",InvestmentInstrumentType::Bond,Currency::RUB,"MOEX","TQCB",t);
        const auto at=QDateTime::currentDateTimeUtc();QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(bond,position(),InvestmentQuote("stock",100'000'000,at,t),false,{},270000));
        const auto old=InvestmentRepository(r.database()).loadInvestmentPositions().at(0);t.faceValueMicros=800'000'000;
        QVERIFY2(InvestmentRepository(r.database()).bookInvestmentOperation(operation("amortization","amortization",60000,0),old,old,false,InvestmentQuote("stock",100'000'000,at,t)),qPrintable(r.lastError()));
        const auto row=InvestmentRepository(r.database()).loadPositionHistory("position").last().toMap();QCOMPARE(row.value("released_cost_minor").toLongLong(),qint64(54000));
        QCOMPARE(row.value("realized_net_minor").toLongLong(),qint64(6000));QCOMPARE(InvestmentRepository(r.database()).investmentCostBasis("position").toLongLong(),qint64(216000));
    }
    void largeCostsAndFractionalSalesRemainExact(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
        const qint64 cost=9'007'199'254'740'993LL;
        QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(7'000'000),{},false,{},cost));
        const auto old=InvestmentRepository(r.database()).loadInvestmentPositions().at(0);auto sell=operation("sell","sell",10000,-1'000'000);
        QVERIFY(InvestmentRepository(r.database()).bookInvestmentOperation(sell,old,position(6'000'000),false));
        const auto row=InvestmentRepository(r.database()).loadPositionHistory("position").last().toMap();QCOMPARE(row.value("released_cost_minor").toLongLong(),cost/7);
        QCOMPARE(row.value("cost_basis_minor").toLongLong(),cost-cost/7);
        QCOMPARE(row.value("before_cost_minor").toLongLong(),cost);
    }
    void backdatedLedgerChangesMarkAffectedSnapshots(){
        QTemporaryDir dir;const auto path=dir.filePath("data.db");FinanceRepository r(path);
        QVERIFY(AccountRepository(r.database()).insertAccount({"fiat","Счёт",AssetType::Fiat,AccountType::DebitCard,Currency::USD,12345}));
        QVERIFY(AnalyticsRepository(r.database()).saveDailyValuations(batch(QDateTime::currentDateTimeUtc().addDays(-1))));
        QVERIFY(raw(path,{"INSERT INTO transactions(id,account_id,category_id,type,amount_minor,occurred_at,created_at,kind) SELECT 'backdated','fiat',id,0,100,1,1,'income' FROM categories WHERE type=0 LIMIT 1"}));
        const auto row=AnalyticsRepository(r.database()).loadDailyValuations(AssetDailyValuation::Fiat).at(0).toMap();
        QVERIFY(row.value("issues").toString().contains("history_changed"));QCOMPARE(row.value("value_minor").toLongLong(),qint64(12345));
    }
    void batchDeletionAndAccountArchivePreserveClosedHistory(){
        QTemporaryDir dir;FinanceRepository r(dir.filePath("data.db"));QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
        QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},false,{},10000));
        QVERIFY(TransactionRepository(r.database()).deleteHistoryRows({QVariantMap{{"type","investment_position"},{"id","position"}}}));
        auto history=InvestmentRepository(r.database()).loadPositionHistory("position");QCOMPARE(history.last().toMap().value("quantity_micros").toLongLong(),qint64(0));
        QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),{"second","broker","stock",3'000'000,100'000'000},{},false,{},10000));
        QVERIFY(AccountRepository(r.database()).deleteAccount("broker"));history=InvestmentRepository(r.database()).loadPositionHistory("second");
        QCOMPARE(history.last().toMap().value("event").toString(),QString("archive"));
        QCOMPARE(history.last().toMap().value("quantity_micros").toLongLong(),qint64(0));
        QCOMPARE(history.last().toMap().value("cost_basis_minor").toLongLong(),qint64(0));
    }
    void backupsAndResetIncludeTheNewHistory(){
        QTemporaryDir dir;const auto copy=dir.filePath("copy.sqlite3");
        {FinanceRepository r(dir.filePath("source.db"));QVERIFY(AccountRepository(r.database()).insertAccount(broker()));
         auto op=operation("buy","buy",-10001,3'000'000);op.feeMinor=1;
         QVERIFY(InvestmentRepository(r.database()).saveInvestmentBundle(stock(),position(),{},false,op));QVERIFY(AnalyticsRepository(r.database()).saveDailyValuations(batch()));QVERIFY(DatabaseMaintenance(r.database(), r.keyStore()).backupDatabase(copy));}
        FinanceRepository target(dir.filePath("target.db"));QVERIFY2(DatabaseMaintenance(target.database(), target.keyStore()).restoreDatabase(copy),qPrintable(target.lastError()));
        QCOMPARE(InvestmentRepository(target.database()).loadPositionHistory("position").size(),1);QCOMPARE(InvestmentRepository(target.database()).investmentCostBasis("position").toLongLong(),qint64(10001));
        QCOMPARE(AnalyticsRepository(target.database()).loadDailyValuations(AssetDailyValuation::Crypto).size(),1);QVERIFY(DatabaseMaintenance(target.database(), target.keyStore()).restoreDatabase(copy));
        QVERIFY(DatabaseMaintenance(target.database(), target.keyStore()).clearAllUserData());QVERIFY(InvestmentRepository(target.database()).loadPositionHistory("position").isEmpty());QVERIFY(AnalyticsRepository(target.database()).loadDailyValuations(AssetDailyValuation::Fiat).isEmpty());
    }
};
QTEST_GUILESS_MAIN(AnalyticsHistoryRepositoryTest)
#include "AnalyticsHistoryRepositoryTest.moc"
