#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QScopedValueRollback>
#include <QTextBlock>
#include <QTextBlockFormat>
#include <QTextCursor>
#include <QTextDocument>

// Plain-text notes keep their existing storage format. Only the document's
// paragraph geometry is changed, because TextEdit has no line-height property.
class NotebookLayout : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void attach(QQuickTextDocument* wrapper)
    {
        QTextDocument* document = wrapper ? wrapper->textDocument() : nullptr;
        if (document_ == document) { format(); return; }
        if (document_) disconnect(document_, nullptr, this, nullptr);
        document_ = document;
        if (document_) {
            connect(document_, &QTextDocument::contentsChanged, this, &NotebookLayout::format);
            format();
        }
    }
private:
    void format()
    {
        if (!document_ || formatting_) return;
        QScopedValueRollback<bool> guard(formatting_, true);
        for (QTextBlock block = document_->begin(); block.isValid(); block = block.next()) {
            const auto current = block.blockFormat();
            if (current.lineHeightType() == QTextBlockFormat::FixedHeight && current.lineHeight() == 32) continue;
            QTextCursor cursor(block);
            cursor.joinPreviousEditBlock();
            QTextBlockFormat style;
            style.setLineHeight(32, QTextBlockFormat::FixedHeight);
            cursor.mergeBlockFormat(style);
            cursor.endEditBlock();
        }
    }
    QPointer<QTextDocument> document_;
    bool formatting_ = false;
};
