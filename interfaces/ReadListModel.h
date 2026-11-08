#pragma once

#include <QAbstractListModel>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

namespace interfaces {

class ReadListModel final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit ReadListModel(const QStringList& roles, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] int count() const noexcept;
    Q_INVOKABLE QVariantMap row(int index) const;

    void setRows(const QVariantList& rows);
    void appendRows(const QVariantList& rows);

signals:
    void countChanged();

private:
    QHash<int, QByteArray> roles_;
    QList<QVariantMap> rows_;
};

} // namespace interfaces
