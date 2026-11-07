#pragma once

#include "Account.h"
#include "Category.h"
#include "Operation.h"

#include <QString>
#include <vector>

namespace core::db {

class Database final
{
public:
    explicit Database(const QString& filePath);
    ~Database();

    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;

    void saveAccount(const core::model::Account& account);
    void saveCategory(const core::model::Category& category);
    void saveOperation(const core::model::Operation& operation);

    [[nodiscard]]
    std::vector<core::model::Account> loadAccounts() const;

    [[nodiscard]]
    std::vector<core::model::Category> loadCategories() const;

    [[nodiscard]]
    std::vector<core::model::Operation> loadOperations() const;

    void removeAccount(const QUuid& id);
    void removeCategory(const QUuid& id);
    void removeOperation(const QUuid& id);

private:
    void createTables();
};

} // namespace core::db
