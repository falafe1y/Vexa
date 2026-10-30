#pragma once

#include <QByteArray>
#include <QRegularExpression>
#include <QString>
#include <QStringList>
#include <QVector>

// The built-in list of known recipients (shops, services) with their aliases and usual
// categories, used to recognize the recipient of a bank statement row.
class BankRecipientDictionary
{
public:
    struct Entry {
        QString id, name, parent;
        QStringList aliases, categories;
        QVector<QRegularExpression> expressions;
        bool contextual = false;
    };

    // Reads the JSON of the dictionary; an empty or broken one gives an empty dictionary
    static BankRecipientDictionary fromJson(const QByteArray& bytes);

    const QVector<Entry>& entries() const { return entries_; }
    int size() const { return entries_.size(); }

private:
    QVector<Entry> entries_;
};
