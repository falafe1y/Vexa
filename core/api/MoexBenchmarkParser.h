#pragma once
#include <QByteArray>
#include <QString>
#include <QVariant>

// Benchmarks of the Moscow Exchange (indices and funds) and reading their price history pages
QVariantList investmentBenchmarkIndices();
bool parseBenchmarkPage(const QByteArray& payload, const QVariantMap& descriptor,
                        QVariantList& rows, int& next, QString& error);
bool mergeBenchmarkRows(const QVariantList& rows, QVariantList& prices, QString& error);
