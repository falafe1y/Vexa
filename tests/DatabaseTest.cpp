#include "../core/db/Database.h"

#include <QtTest>
#include <QSqlQuery>
#include <QTemporaryDir>

class DatabaseTest final : public QObject
{
    Q_OBJECT

private slots:
    void opensFileAndEnablesForeignKeys();
    void reportsFolderThatCannotBeCreated();
    void commitsTransaction();
    void rollsBackTransaction();
};

namespace
{
int count(QSqlDatabase& connection)
{
    QSqlQuery query(connection);
    return query.exec(QStringLiteral("SELECT COUNT(*) FROM sample")) && query.next()
        ? query.value(0).toInt() : -1;
}
}

void DatabaseTest::opensFileAndEnablesForeignKeys()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("nested/data.sqlite3"));

    Database database(path);
    QVERIFY2(database.isOpen(), qPrintable(database.lastError()));
    QCOMPARE(database.access().path, path);
    QVERIFY(QFileInfo::exists(path));

    QSqlQuery pragma(database.connection());
    QVERIFY(pragma.exec(QStringLiteral("PRAGMA foreign_keys")) && pragma.next());
    QCOMPARE(pragma.value(0).toInt(), 1);
}

void DatabaseTest::reportsFolderThatCannotBeCreated()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    QFile blocker(directory.filePath(QStringLiteral("file")));
    QVERIFY(blocker.open(QIODevice::WriteOnly));
    blocker.close();

    Database database(directory.filePath(QStringLiteral("file/data.sqlite3")));
    QVERIFY(!database.isOpen());
    QVERIFY(!database.lastError().isEmpty());
}

void DatabaseTest::commitsTransaction()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    Database database(directory.filePath(QStringLiteral("data.sqlite3")));
    QVERIFY2(database.isOpen(), qPrintable(database.lastError()));
    QSqlQuery query(database.connection());
    QVERIFY(query.exec(QStringLiteral("CREATE TABLE sample(id INTEGER PRIMARY KEY)")));

    QVERIFY(database.transaction([&] {
        return query.exec(QStringLiteral("INSERT INTO sample VALUES(1)"))
            && query.exec(QStringLiteral("INSERT INTO sample VALUES(2)"));
    }));
    QCOMPARE(count(database.connection()), 2);
}

void DatabaseTest::rollsBackTransaction()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    Database database(directory.filePath(QStringLiteral("data.sqlite3")));
    QVERIFY2(database.isOpen(), qPrintable(database.lastError()));
    QSqlQuery query(database.connection());
    QVERIFY(query.exec(QStringLiteral("CREATE TABLE sample(id INTEGER PRIMARY KEY)")));

    // The second insert breaks the primary key, so the first one must not stay either
    QVERIFY(!database.transaction([&] {
        return query.exec(QStringLiteral("INSERT INTO sample VALUES(1)"))
            && query.exec(QStringLiteral("INSERT INTO sample VALUES(1)"));
    }));
    QCOMPARE(count(database.connection()), 0);
}

QTEST_GUILESS_MAIN(DatabaseTest)
#include "DatabaseTest.moc"
