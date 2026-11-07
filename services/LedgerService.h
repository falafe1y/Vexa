#pragma once

#include <QObject>
#include <QString>
#include <QThread>
#include <QtTypes>

#include <memory>

namespace services {

class LedgerService final : public QObject
{
    Q_OBJECT

public:
    explicit LedgerService(QObject* parent = nullptr);
    ~LedgerService() override;

    void open(const QString& filePath);

    void requestTotalBalance(const QString& currencyCode);

signals:
    void loaded(
        qint64 accountCount,
        qint64 categoryCount,
        qint64 operationCount
        );

    void totalBalanceReady(
        qint64 totalMinor,
        const QString& currencyCode
        );

    void failed(const QString& message);

private:
    struct State;

    QThread databaseThread_;
    QObject* worker_ = nullptr;

    std::unique_ptr<State> state_;
};

} // namespace services