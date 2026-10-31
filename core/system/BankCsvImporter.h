#pragma once

#include "CsvCodec.h"
#include "../model/transactions/BankCsvProfile.h"

#include <QString>

// Reads a bank statement file (CSV, XLSX or PDF by its suffix) into a table and hands the rows
// to BankStatementParser.
class BankCsvImporter final
{
public:
    static CsvCodec::ReadOptions readOptions(const BankCsvProfile& profile);
    static CsvCodec::ReadResult readTable(
        const QString& filePath,
        const BankCsvProfile& profile
        );
    static BankCsvParseResult parse(
        const QString& filePath,
        const BankCsvProfile& profile
        );
};
