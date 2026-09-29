---
name: pdf-form-pl
description: Fill, merge and OCR Polish PDF paperwork — bank and leasing applications, urząd forms, scanned attachments — without losing ą/ę/ó/ś/ż. Use when Greg says "wypełnij formularz", "uzupełnij PDF", "wniosek leasingowy/kredytowy", "scal skany", "zrób OCR", or attaches a fillable PDF from a bank, dealer or urząd. Wraps the generic pdf skill with the tool checks and font fallback that Polish forms need.
---

# pdf-form-pl

The generic `pdf` skill covers the mechanics; this one adds what a Polish
bank/leasing form needed on 2026-09-29 and cost ~40 turns to discover.

## 0. Tool check first (one call)

```bash
for t in qpdf ocrmypdf tesseract mutool; do command -v $t >/dev/null && echo "ok  $t" || echo "MISSING $t"; done
python3 -c 'import fitz, pypdf; print("ok  pymupdf pypdf")' 2>&1 | tail -1
tesseract --list-langs 2>/dev/null | grep -q pol && echo "ok  tesseract pol" || echo "MISSING tesseract-lang (pol)"
```

Missing → `brew install qpdf ocrmypdf tesseract-lang` and `pip3 install pymupdf pypdf` **before** touching the form, not mid-task. `reportlab` is not installed and is not needed; PyMuPDF (`fitz`) does the overlay.

## 1. Filling fields

- Try `pypdf` field fill first (`PdfWriter.update_page_form_field_values`). **Check the output for Polish glyphs**: forms built with Helvetica drop ą/ę/ó/ś/ż silently.
- If glyphs are missing, overlay text with PyMuPDF using a font that has them:
  `page.insert_text((x, y), text, fontname="Arial", fontfile="/System/Library/Fonts/Supplemental/Arial.ttf", fontsize=9)`. Flatten afterwards (`doc.save(out, garbage=3, deflate=True)`).
- The bundled `fill_fillable_fields.py` from the `pdf` skill crashed with `IndexError` on a form with radio groups; go to PyMuPDF straight away when a form has radios.
- **Password-protected PDF** (`Incorrect password`): ask Greg for the password in one line. A retry never helps.

## 2. Verify once, not three times

Render every page to PNG once (`mutool draw -r 110 -o /tmp/p%d.png out.pdf`), read the PNGs once, fix, re-render only the pages you changed. Re-reading the same PNGs to "double check" burned the most turns.

## 3. Scans and OCR

- Merge scans: `qpdf --empty --pages a.pdf b.pdf -- merged.pdf`.
- OCR in Polish: `ocrmypdf -l pol --skip-text in.pdf out.pdf` (`--force-ocr` only for image-only pages). `-l pol+eng` for mixed documents.
- Photos from the phone: convert with `sips -s format pdf` or PyMuPDF; `magick` is not installed.

## 4. What goes where

Documents and scans live in Google Drive (`My Drive/faktury`, `My Drive/Dom/Kredyt`, `My Drive/Dom/Skaner`). Never write PESEL, ID numbers or account numbers into memory, bazgroly or the transcript beyond what the form itself needs; keep them in the PDF only.
