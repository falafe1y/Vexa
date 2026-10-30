#pragma once
#include "Database.h"
#include "../model/analytics/AnalyticsHistory.h"
#include "../model/analytics/FinancialTrajectory.h"
#include <QDate>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

// What analytics keeps: daily valuations of assets, price and currency rate history,
// accounts for the return calculation, return and benchmark settings, benchmark prices,
// capital snapshots and the settings of the capital trajectory.
class AnalyticsRepository
{
public:
    explicit AnalyticsRepository(Database& database);

    bool saveDailyValuations(const DailyValuationBatch& batch);
    QVariantList loadDailyValuations(AssetDailyValuation::Kind kind, const QDate& from = {}, const QDate& to = {});
    QVariantList loadPriceHistory(AssetDailyValuation::Kind kind, const QString& assetId);
    QVariantList loadFxHistory(const QString& currency);
    bool saveHistoricalFxRates(const QVector<HistoricalFxRate>& rates);
    QVariantList loadPerformanceAccounts();
    QVariantMap loadAccountCreationDates();
    QString loadPerformanceInflation() const;
    bool savePerformanceInflation(const QString& value);
    QVariantMap loadPerformanceDeposit() const;
    bool savePerformanceDeposit(const QVariantMap& value);
    QVariantMap loadBenchmarkSelection() const;
    bool saveBenchmarkSelection(const QVariantMap& descriptor);
    QVariantList loadBenchmarkPrices(const QString& key);
    bool benchmarkHistoryCovered(const QString& key,const QDate& from,const QDate& to);
    bool saveBenchmarkHistory(const QVariantMap& descriptor,const QVariantList& prices,const QDate& from,const QDate& to);
    QVector<CapitalSnapshot> loadCapitalSnapshots();
    bool saveCapitalSnapshot(const CapitalSnapshot& snapshot);
    FinancialTrajectorySettings loadFinancialTrajectorySettings() const;
    bool saveFinancialTrajectorySettings(
        const FinancialTrajectorySettings& settings);
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
