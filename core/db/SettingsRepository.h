#pragma once
#include "Database.h"
#include "../model/money/Currency.h"

#include <QString>

// User settings stored as key and value rows of the settings table:
// currencies, the selected section, automatic or manual currency rates.
class SettingsRepository
{
public:
    explicit SettingsRepository(Database& database);

    QString loadAppCurrency() const;
    bool saveAppCurrency(const QString& currency);
    QString loadAnalyticsCurrency() const;
    bool saveAnalyticsCurrency(const QString& currency);
    QString loadSelectedAsset() const;
    bool saveSelectedAsset(const QString& asset);
    bool loadAutomaticCurrencyRates() const;
    double loadManualRubToRubRate() const;
    double loadManualUsdToRubRate() const;
    double loadManualEurToRubRate() const;
    double loadManualCnyToRubRate() const;
    bool saveAutomaticCurrencyRates(bool enabled);
    bool saveManualCurrencyRates(
        double rublesPerRub,
        double rublesPerUsd,
        double rublesPerEur,
        double rublesPerCny = kDefaultCnyToRubRate
        );
    QString lastError() const;

private:
    void setLastError(const QString& error);

    QSqlDatabase& database_;
    QString lastError_;
};
