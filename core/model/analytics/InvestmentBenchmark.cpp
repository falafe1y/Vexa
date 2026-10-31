#include "InvestmentBenchmark.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QMap>
#include <cmath>
#include <limits>
#include <optional>

QVariantMap compareInvestmentBenchmark(const QVariantList& portfolio,const QVariantList& prices,const QVariantList& rates,const QString& currency) {
    QVariantMap out{{"available",false},{"points",QVariantList()}};
    const auto fail=[&](const QString& reason){out["reason"]=reason;return out;};
    if(portfolio.size()<2)return fail(QStringLiteral("Нужны две завершённые дневные оценки портфеля и непрерывная история между ними."));
    QMap<QDate,QVariantMap> quotes;for(const auto& p:prices){const auto r=p.toMap();const auto d=QDate::fromString(r.value("price_date").toString(),Qt::ISODate);if(d.isValid())quotes[d]=r;}
    QMap<QString,QMap<QDate,QPair<qint64,qint64>>> rateTable;
    for(const auto& v:rates){const auto r=v.toMap();const auto date=QDate::fromString(r.value("rate_date").toString(),Qt::ISODate);
        if(!date.isValid() || r.value("source")=="estimated")continue;
        auto& entries=rateTable[r.value("currency").toString()];const auto observed=r.value("observed_at").toLongLong();
        if(!entries.contains(date) || observed>entries.value(date).second)entries[date]={r.value("rub_per_unit_micros").toLongLong(),observed};
    }
    const auto fx=[&](const QString& code,const QDate& date)->std::optional<long double>{
        if(code=="RUB")return 1'000'000.0L;
        const auto entries=rateTable.value(code);auto it=entries.upperBound(date);
        if(it==entries.begin())return {};--it;
        return it->first>0?std::optional<long double>(it->first):std::nullopt;
    };
    QVariantList points;std::optional<long double> base;QDate previous;int maximumQuoteAge=0;
    for(const auto& v:portfolio){const auto p=v.toMap();const auto date=QDate::fromString(p.value("date").toString(),Qt::ISODate);
        bool valid=false;const auto own=p.value("percent").toDouble(&valid);
        if(!date.isValid() || !valid || !std::isfinite(own) || (previous.isValid() && previous.daysTo(date)!=1))return fail(QStringLiteral("Дневная история портфеля неполна."));
        auto q=quotes.upperBound(date);if(q==quotes.begin())return fail(QStringLiteral("Нет цены ориентира на начало периода."));--q;
        maximumQuoteAge=qMax(maximumQuoteAge,int(q.key().daysTo(date)));
        if(q->value("price_micros").isNull() || !q->value("issues").toString().isEmpty())return fail(QStringLiteral("Для части периода цена или валюта ориентира неизвестна."));
        const auto code=q->value("currency").toString();const auto price=q->value("price_micros").toLongLong();if(price<=0)return fail(QStringLiteral("Некорректная цена ориентира."));
        long double converted=price;
        if(code!=currency){const auto from=fx(code,date),to=fx(currency,date);if(!from || !to)return fail(QStringLiteral("Для сравнения не найден исторический валютный курс."));converted*=*from / *to;}
        if(!std::isfinite(converted) || converted<=0)return fail(QStringLiteral("Цена после пересчёта выходит за допустимый диапазон."));
        if(!base)base=converted;const long double benchmark=(converted/ *base-1)*100;
        if(!std::isfinite(benchmark) || !std::isfinite(double(benchmark)))return fail(QStringLiteral("Доходность ориентира выходит за допустимый диапазон."));
        points.append(QVariantMap{{"date",date.toString(Qt::ISODate)},{"portfolio",own},{"benchmark",double(benchmark)},{"quoteDate",q.key().toString(Qt::ISODate)}});previous=date;
    }
    const auto first=points.first().toMap(),last=points.last().toMap();out["available"]=true;out["points"]=points;out["maximumQuoteAgeDays"]=maximumQuoteAge;
    out["from"]=first.value("date");out["to"]=last.value("date");out["portfolioPercent"]=last.value("portfolio");out["benchmarkPercent"]=last.value("benchmark");out["differencePoints"]=last.value("portfolio").toDouble()-last.value("benchmark").toDouble();return out;
}
