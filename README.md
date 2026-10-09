# ICON Billing Studio — Flutter (Android)

Native, offline-first port of the [web prototype](../ICON%20Billing%20Studio).
Built with Flutter 3.47 / Dart 3.13, Isar, and the `pdf` package. No WebView —
every screen, template and document is a real Flutter widget.

## What is where

```
lib/
  main.dart              App bootstrap, theme engine, StoreBinder
  router.dart            go_router routes + bottom navigation shell
  models/models.dart     Isar collections: Client, Service, Invoice,
                         LineItem, Business, AppSettings, PdfDocument
  core/
    constants.dart       statuses, accents, the ten-template registry
    seed.dart            first-launch demo data
    database.dart        Isar open + atomic CRUD
    store.dart           single source of truth; stats, filters, vault
    settings.dart        persisted theme/accent/template preferences
    theme.dart           light + dark themes, accent engine
    format.dart          money/date/number helpers (locale-stable)
  ui/kit.dart            pills, avatars, empty states, rows, toast
  views/
    dashboard_screen.dart     stats, six-month chart, quick actions
    invoices_screen.dart      history: search, status filter, sort
    editor_screen.dart        full invoice editor with live totals
    clients_screen.dart       client CRUD with delete guards
    services_screen.dart      product/service CRUD
    templates_screen.dart     ten-template gallery
    documents_screen.dart     the PDF vault (on-device index)
    document_viewer_screen.dart  in-app viewer + share/save/print
    settings_screen.dart      business profile, appearance, data
  pdf/
    invoice_pdf.dart     A4 PDF painter for all ten templates
```

## The ten templates

`minimal`, `executive`, `modern`, `classic`, `creative`, `corporate`,
`elegant`, `compact`, `bold`, `professional` — each a distinct painter in
`pdf/invoice_pdf.dart`, mirroring the prototype's `js/templates/render.js`.

## PDF pipeline

1. `Store.generatePdfFor(invoice)` renders bytes via `buildInvoicePdf`.
2. The file is written to `<app documents>/pdfs/` and indexed in Isar.
3. `DocumentsScreen` lists the vault; `DocumentViewerScreen` shows it with
   Share (system sheet), Save to Device (system file picker, scoped storage)
   and Print (Android print framework) actions.

## Getting it to build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Isar *.g.dart
flutter run                                               # debug
flutter build apk --release                               # APK
```

APK output:
`build/app/outputs/flutter-apk/app-release.apk`

## Tests

```bash
flutter test
```

17 tests cover the seed data, the totals arithmetic, all ten PDF templates
across every seed invoice, long names/notes, empty invoices, and 120-line-item
pagination.

## Bugs the tests caught

| Bug | Cause | Fix |
|---|---|---|
| Every total was 100x too small | `round2()` divided by 100 instead of rounding to 2dp | `((v + 1e-9) * 100).roundToDouble() / 100` |
| `minimal` template crashed | `pw.Spacer()` in a column under `MultiPage` (unbounded height) | `pw.SizedBox(height: 24)` |
| All templates failed on unicode | Helvetica has no unicode support; em-dash/arrow/middot in painters | ASCII-only painter strings |
| Table rows overflowed | `letterSpacing` is unsupported in `pdf`'s `TextStyle` | removed |
| 25+ line items blew past 20 pages | one unbreakable `Table` inside a `Column` | chunked into 18-row pages |

## Notes

- Money is formatted `en-US` so a document prints identically on any device.
- The web prototype at `../ICON Billing Studio` is untouched and still
  serves at `http://localhost:8765`.
