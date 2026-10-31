#include "BankCsvImporter.h"
#include "XlsxReader.h"
#include "PdfStatementReader.h"
#include "../model/transactions/BankStatementParser.h"

#include <QFileInfo>
#include <QMutex>

CsvCodec::ReadResult BankCsvImporter::readTable(
    const QString& filePath,
    const BankCsvProfile& profile)
{
    if (filePath.endsWith(QStringLiteral(".pdf"), Qt::CaseInsensitive)) {
        // Keep one successfully decoded statement. Preview and import reuse it.
        // The cache is shared with background inspection and bounded to one file.
        static QMutex mutex;
        static QString cachedPath;
        static qint64 cachedSize = -1;
        static QDateTime cachedModified;
        static CsvCodec::ReadResult cachedTable;
        const QFileInfo before(filePath);
        const QString path = before.canonicalFilePath();
        {
            QMutexLocker lock(&mutex);
            if (!path.isEmpty() && path == cachedPath && before.size() == cachedSize &&
                before.lastModified() == cachedModified) return cachedTable;
        }
        const auto table = PdfStatementReader::read(filePath);
        const QFileInfo after(filePath);
        if (table.error.isEmpty() && !path.isEmpty() && before.size() == after.size() &&
            before.lastModified() == after.lastModified()) {
            QMutexLocker lock(&mutex);
            cachedPath = path; cachedSize = after.size(); cachedModified = after.lastModified();
            cachedTable = table;
        }
        return table;
    }
    if (filePath.endsWith(QStringLiteral(".xlsx"), Qt::CaseInsensitive)) {
        const auto xlsx = XlsxReader::readFirstSheet(filePath);
        return {xlsx.rows, xlsx.error, {}, QStringLiteral("XLSX")};
    }
    return CsvCodec::readFile(filePath, readOptions(profile));
}

CsvCodec::ReadOptions BankCsvImporter::readOptions(
    const BankCsvProfile& profile
    )
{
    CsvCodec::ReadOptions options;
    if (profile.delimiter == QStringLiteral("semicolon")) {
        options.delimiter = QLatin1Char(';');
    } else if (profile.delimiter == QStringLiteral("comma")) {
        options.delimiter = QLatin1Char(',');
    } else if (profile.delimiter == QStringLiteral("tab")) {
        options.delimiter = QLatin1Char('\t');
    }

    if (profile.encoding == QStringLiteral("utf8")) {
        options.encoding = CsvCodec::Encoding::Utf8;
    } else if (profile.encoding == QStringLiteral("windows1251")) {
        options.encoding = CsvCodec::Encoding::Windows1251;
    } else if (profile.encoding == QStringLiteral("utf16le")) {
        options.encoding = CsvCodec::Encoding::Utf16Le;
    } else if (profile.encoding == QStringLiteral("utf16be")) {
        options.encoding = CsvCodec::Encoding::Utf16Be;
    }
    return options;
}

BankCsvParseResult BankCsvImporter::parse(
    const QString& filePath,
    const BankCsvProfile& requestedProfile
    )
{
    BankCsvProfile profile = requestedProfile;
    if (filePath.endsWith(QStringLiteral(".pdf"), Qt::CaseInsensitive)) {
        profile.headerRow = 0;
        profile.dateColumn = 0; profile.amountColumn = 1;
        profile.descriptionColumn = 2; profile.idColumn = 3;
        profile.recipientColumn = -1; profile.recipientIdColumn = -1;
        profile.currencyColumn = 4; profile.directionColumn = -1;
        profile.categoryColumn = -1; profile.amountMode = QStringLiteral("signed");
        profile.dateFormat = QStringLiteral("auto"); profile.positiveMeansIncome = true;
    }
    BankCsvParseResult result;
    const CsvCodec::ReadResult csv = readTable(filePath, profile);
    result.delimiter = csv.delimiter;
    result.encoding = csv.encoding;
    if (!csv.error.isEmpty()) {
        result.errors.append(csv.error);
        return result;
    }
    BankCsvParseResult parsed = BankStatementParser::parse(csv.rows, profile);
    parsed.delimiter = csv.delimiter;
    parsed.encoding = csv.encoding;
    return parsed;
}
