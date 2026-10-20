package org.qtproject.example.vexa;

import android.content.Context;

import com.tom_roush.pdfbox.android.PDFBoxResourceLoader;
import com.tom_roush.pdfbox.pdmodel.PDDocument;
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle;
import com.tom_roush.pdfbox.text.PDFTextStripper;
import com.tom_roush.pdfbox.text.TextPosition;

import java.io.File;
import java.io.IOException;

// Reads the text layer of a PDF with positions, in the same shape as pdftotext -bbox-layout:
//   "P<TAB>width<TAB>height" starts a page (points, origin top left);
//   "W<TAB>x<TAB>y<TAB>width<TAB>height<TAB>text" is one word.
// Words break at whitespace and at horizontal gaps, as in a layout tool. Used only on Android.
public final class PdfWords {
    private PdfWords() {}

    public static String extract(Context context, String path) throws IOException {
        PDFBoxResourceLoader.init(context.getApplicationContext());
        StringBuilder out = new StringBuilder();
        PDDocument document = PDDocument.load(new File(path));
        try {
            int pages = document.getNumberOfPages();
            for (int index = 1; index <= pages; index++) {
                PDRectangle box = document.getPage(index - 1).getMediaBox();
                out.append("P\t").append(box.getWidth()).append('\t').append(box.getHeight()).append('\n');
                WordCollector collector = new WordCollector(out);
                collector.setStartPage(index);
                collector.setEndPage(index);
                collector.getText(document);
                collector.flush();
            }
        } finally {
            document.close();
        }
        return out.toString();
    }

    private static final class WordCollector extends PDFTextStripper {
        private final StringBuilder out;
        private final StringBuilder word = new StringBuilder();
        private boolean open;
        private float left, top, right, bottom, previousRight;

        WordCollector(StringBuilder out) throws IOException {
            super();
            this.out = out;
            setSortByPosition(true);
        }

        @Override
        protected void processTextPosition(TextPosition text) {
            String unicode = text.getUnicode();
            if (unicode == null || unicode.isEmpty()) {
                return;
            }
            float x = text.getXDirAdj();
            float y = text.getYDirAdj();
            float width = text.getWidthDirAdj();
            float height = text.getHeightDir();
            if (isSeparator(unicode)) {
                flush();
                previousRight = x + width;
                return;
            }
            if (open) {
                boolean newLine = Math.abs(y - top) > height * 0.5f;
                boolean gap = x - previousRight > Math.max(1f, 0.2f * height);
                if (newLine || gap) {
                    flush();
                }
            }
            if (!open) {
                left = x;
                top = y;
                right = x + width;
                bottom = y + height;
                open = true;
            } else {
                left = Math.min(left, x);
                top = Math.min(top, y);
                right = Math.max(right, x + width);
                bottom = Math.max(bottom, y + height);
            }
            previousRight = x + width;
            word.append(unicode);
        }

        void flush() {
            if (open && word.length() > 0) {
                String text = word.toString().replace('\t', ' ').replace('\n', ' ').replace('\r', ' ');
                out.append("W\t").append(left).append('\t').append(top).append('\t')
                        .append(right - left).append('\t').append(bottom - top).append('\t')
                        .append(text).append('\n');
            }
            word.setLength(0);
            open = false;
        }

        // Non-breaking spaces stay inside a word, because statement amounts may contain them.
        private static boolean isSeparator(String unicode) {
            for (int i = 0; i < unicode.length(); i++) {
                char c = unicode.charAt(i);
                if (c == ' ' || c == ' ') {
                    return false;
                }
                if (!Character.isWhitespace(c)) {
                    return false;
                }
            }
            return true;
        }
    }
}
