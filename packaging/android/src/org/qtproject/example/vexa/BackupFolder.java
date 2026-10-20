package org.qtproject.example.vexa;

import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;

// Files of automatic backups in a folder the user chose with the system picker (a document tree).
// The tree stays readable and writable across restarts after takePermission().
public final class BackupFolder {
    private BackupFolder() {}

    // Creates an empty document named `name` in the tree and returns its URI
    public static String create(Context context, String treeUri, String name) throws Exception {
        Uri tree = Uri.parse(treeUri);
        Uri parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree));
        Uri created = DocumentsContract.createDocument(context.getContentResolver(), parent, "application/octet-stream", name);
        if (created == null) {
            throw new IllegalStateException("The folder did not create the backup file");
        }
        return created.toString();
    }

    // Returns "name<TAB>uri" for every document directly in the tree, one per line
    public static String list(Context context, String treeUri) {
        Uri tree = Uri.parse(treeUri);
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree));
        StringBuilder out = new StringBuilder();
        String[] columns = {DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME};
        try (Cursor cursor = context.getContentResolver().query(children, columns, null, null, null)) {
            while (cursor != null && cursor.moveToNext()) {
                String documentId = cursor.getString(0);
                String name = cursor.getString(1);
                Uri document = DocumentsContract.buildDocumentUriUsingTree(tree, documentId);
                out.append(name).append('\t').append(document.toString()).append('\n');
            }
        }
        return out.toString();
    }

    public static boolean delete(Context context, String documentUri) throws Exception {
        return DocumentsContract.deleteDocument(context.getContentResolver(), Uri.parse(documentUri));
    }

    // Keeps the grant for the tree after the process restarts
    public static boolean takePermission(Context context, String treeUri) {
        context.getContentResolver().takePersistableUriPermission(
                Uri.parse(treeUri),
                Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        return true;
    }
}
