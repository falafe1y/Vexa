#pragma once
#include <QVariant>
#include <QDate>

// Compares the return of the portfolio with an index or a fund over the same days
QVariantMap compareInvestmentBenchmark(const QVariantList& portfolio, const QVariantList& prices,
                                      const QVariantList& rates, const QString& currency);
