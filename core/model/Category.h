#pragma once

#include <QString>
#include <QUuid>

namespace core::model {

enum class CategoryType
{
    Income,
    Expense
};

// запрет на наследование
class Category final
{
public:
    Category(QUuid id,
             const QString& name,
             CategoryType type,
             bool archived = false);

    [[nodiscard]] QUuid id() const noexcept
    {
        return id_;
    }

    [[nodiscard]] const QString& name() const noexcept
    {
        return name_;
    }

    [[nodiscard]] CategoryType type() const noexcept
    {
        return type_;
    }

    [[nodiscard]] bool isArchived() const noexcept
    {
        return archived_;
    }

    // категория удалена, но для корректности истории она по сути просто скрывается
    void archive() noexcept
    {
        archived_ = true;
    }

private:
    QUuid id_;
    QString name_;
    CategoryType type_;
    bool archived_;
};

} // namespace core::model