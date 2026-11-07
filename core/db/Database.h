#pragma once

#include "Account.h"

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
    [[nodiscard]] std::vector<core::model::Account> loadAccounts() const;

private:
    void createTables();
};

} // namespace core::db
