---
name: pdf-form-pl
description: Fill, merge and OCR Polish PDF paperwork (bank and leasing applications, urząd forms, scans) without losing ą/ę/ó/ś/ż. Use on "wypełnij formularz", "uzupełnij PDF", "wniosek leasingowy/kredytowy", "scal skany", "zrób OCR", or a fillable PDF from a bank, dealer or urząd. Wraps the generic pdf skill with tool checks and a font fallback.
---

# pdf-form-pl

The generic `pdf` skill covers mechanics; this adds what a Polish form cost ~40 turns to learn (2026-09-29).

## 0. Tool check first (one call)

```bash
for t in qpdf ocrmypdf tesseract mutool; do command -v $t >/dev/null && echo "ok  $t" || echo "MISSING $t"; done
python3 -c 'import fitz, pypdf; print("ok  pymupdf pypdf")' 2>&1 | tail -1
tesseract --list-langs 2>/dev/null | grep -q pol && echo "ok  tesseract pol" || echo "MISSING tesseract-lang (pol)"
```

Missing → `brew install qpdf ocrmypdf tesseract-lang`, `pip3 install pymupdf pypdf` before touching the form. No `reportlab` needed.

## 1. Fill

- `pypdf` field fill first (`PdfWriter.update_page_form_field_values`), then **check the Polish glyphs**: Helvetica forms drop them silently.
- Missing glyphs, or any radio groups (the `pdf` skill's `fill_fillable_fields.py` crashes with `IndexError`) → PyMuPDF overlay: `page.insert_text((x, y), text, fontname="Arial", fontfile="/System/Library/Fonts/Supplemental/Arial.ttf", fontsize=9)`, save with `garbage=3, deflate=True`.
- `Incorrect password` → ask Greg for it in one line; retries never help.

## 2. Verify once

`mutool draw -r 110 -o <scratch>/p%d.png out.pdf`, read each PNG once, fix, re-render only changed pages.

## 3. Scans and OCR

- Merge: `qpdf --empty --pages a.pdf b.pdf -- merged.pdf`.
- OCR: `ocrmypdf -l pol --skip-text in.pdf out.pdf` (`--force-ocr` for image-only, `-l pol+eng` mixed).
- Phone photos: `sips -s format pdf` or PyMuPDF (`magick` isn't installed).

## 4. Where it goes

Drive (`My Drive/faktury`, `Dom/Kredyt`, `Dom/Skaner`) per `pii-documents-on-drive.md`. PESEL, ID and account numbers live in the PDF only: never in memory, bazgroly or the transcript beyond what the form needs.
