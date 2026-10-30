#include "PositionHistory.h"
#include "../model/investments/InvestmentInstrument.h"
#include "../model/investments/InvestmentPosition.h"
#include "../model/investments/InvestmentTerms.h"

#include <limits>

QVariant averageAcquisitionCost(const QVariantMap& row) {
    const int type=row.value("type").toInt();
    if(type==int(InvestmentInstrumentType::Bond) || type==int(InvestmentInstrumentType::Future)
       || type==int(InvestmentInstrumentType::Option) || type==int(InvestmentInstrumentType::Other))return {};
    const auto settings=InvestmentPositionSettings::deserialize(row.value("settings_json").toString());
    const auto terms=InvestmentTerms::deserialize(row.value("terms_json").toString());
    const auto currency=terms.currencyCode.isEmpty()?row.value("instrument_currency").toString():terms.currencyCode;
    const qint64 qty=row.value("quantity_micros").toLongLong(),price=row.value("average_price_micros").toLongLong();
    if(settings.direction!=1 || qty<=0 || price<=0 || currency!=row.value("currency").toString()
       || (terms.pricing!="unit" && terms.pricing!="manual") || terms.multiplierMicros!=1'000'000)return {};
    const __int128_t minor=(__int128_t(qty)*price+5'000'000'000LL)/10'000'000'000LL;
    if(minor>std::numeric_limits<qint64>::max())return {};
    return QVariant(static_cast<qint64>(minor));
}
