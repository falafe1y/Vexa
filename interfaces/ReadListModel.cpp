#include "ReadListModel.h"

#include <QSet>

namespace interfaces {

ReadListModel::ReadListModel(const QStringList& roles, QObject* parent)
    : QAbstractListModel(parent)
{
    int role = Qt::UserRole + 1;
    for (const auto& name : roles) {
        roles_.insert(role++, name.toUtf8());
    }
}

int ReadListModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : count();
}

QVariant ReadListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.model() != this || index.column() != 0
        || index.row() < 0 || index.row() >= count()) {
        return {};
    }

    const auto name = roles_.constFind(role);
    if (name == roles_.cend()) {
        return {};
    }

    return rows_.at(index.row()).value(QString::fromUtf8(name.value()));
}

QHash<int, QByteArray> ReadListModel::roleNames() const
{
    return roles_;
}

int ReadListModel::count() const noexcept
{
    return static_cast<int>(rows_.size());
}

QVariantMap ReadListModel::row(int index) const
{
    if (index < 0 || index >= count()) {
        return {};
    }
    return rows_.at(index);
}

void ReadListModel::setRows(const QVariantList& rows)
{
    QList<QVariantMap> next;
    next.reserve(rows.size());

    QSet<QString> ids;
    for (const auto& value : rows) {
        auto item = value.toMap();
        ids.insert(item.value(QStringLiteral("id")).toString());
        next.push_back(item);
    }

    const int previousCount = count();

    for (int i = count() - 1; i >= 0; --i) {
        if (!ids.contains(rows_.at(i).value(QStringLiteral("id")).toString())) {
            beginRemoveRows({}, i, i);
            rows_.removeAt(i);
            endRemoveRows();
        }
    }

    for (int i = 0; i < static_cast<int>(next.size()); ++i) {
        const auto& item = next.at(i);
        const auto id = item.value(QStringLiteral("id")).toString();

        int position = i;
        while (position < count()
               && rows_.at(position).value(QStringLiteral("id")).toString() != id) {
            ++position;
        }

        if (position == count()) {
            beginInsertRows({}, i, i);
            rows_.insert(i, item);
            endInsertRows();
        } else {
            if (position != i) {
                beginMoveRows({}, position, position, {}, i);
                rows_.move(position, i);
                endMoveRows();
            }

            if (rows_.at(i) != item) {
                rows_[i] = item;
                emit dataChanged(index(i, 0), index(i, 0));
            }
        }
    }

    if (previousCount != count()) {
        emit countChanged();
    }
}

void ReadListModel::appendRows(const QVariantList& rows)
{
    if (rows.isEmpty()) {
        return;
    }

    QList<QVariantMap> prepared;
    prepared.reserve(rows.size());
    for (const auto& item : rows) {
        prepared.push_back(item.toMap());
    }

    const int first = count();
    const int last = first + static_cast<int>(prepared.size()) - 1;

    beginInsertRows({}, first, last);
    rows_.append(prepared);
    endInsertRows();

    emit countChanged();
}

} // namespace interfaces
