# Library Import, Storage and Download Policy

**Scope:** Phase 3, iteration 1 — `LIB-002` (import) and `NET-001` (partial downloads).
**Status:** Implemented 2026-11-15; device-verified on emulator-5554.
**Code:** `lib/library/`, UI wiring in `lib/main.dart`.

## Storage layout

Imported and downloaded EPUBs live under the app documents directory, never in
shared storage:

```
<app documents>/library/
  books/<sha256>.epub       immutable, content-addressed source bytes
  covers/<sha256>.<ext>     extracted cover art
  downloads/<name>.epub     staging for URL imports (removed after import)
  .tmp/<sha256>.epub.part   in-flight promotion
```

- File names are the SHA-256 of the bytes, so identical content always maps to
  the same path.
- Promotion writes to `.tmp/` on the same filesystem, flushes, then renames.
  A crash leaves at most a staging file; it never produces a partial asset at
  the final path.
- Covers are best-effort. A missing or unsupported cover does not block the
  import.

## Validation

`EpubInspector` validates before anything is copied:

| Check | Rejection |
|---|---|
| ZIP decodes with CRC verification | `notAZipArchive` |
| Archive ≤ 512 MB; ≤ 20,000 entries; ≤ 2 GB declared uncompressed | `archiveTooLarge` |
| No absolute or `..` entry names | `unsafeEntryName` |
| `mimetype` entry equals `application/epub+zip` | `missingMimetype`, `wrongMimetype` |
| `META-INF/container.xml` parsed and rootfile resolved | `missingContainer` |
| Package document exists, is valid XML and ≤ 4 MB | `missingPackageDocument`, `packageDocumentTooLarge` |
| `META-INF/encryption.xml` only uses font obfuscation | `drmProtected` |
| Spine has at least one `itemref` | `emptySpine` |

Only the container, package document and cover are decompressed, each under an
individual size cap. The archive is never extracted to disk.

## Metadata

- Title, creators, description, identifier and language come from Dublin Core.
- Series:
  - EPUB 3: `meta[property="belongs-to-collection"]` plus
    `meta[property="group-position"]` (refined by `refines`).
  - EPUB 2: `meta[name="calibre:series"]` and `meta[name="calibre:series_index"]`.
- Cover:
  1. manifest item with `properties="cover-image"`,
  2. EPUB 2 `<meta name="cover" content="id"/>`,
  3. manifest item with id `cover`.
- Missing titles fall back to the file name with separators normalised.

## Duplicate policy

Local identity is the **SHA-256 fingerprint of the source bytes**.

- Re-importing identical bytes returns the existing book (`ImportOutcome.duplicate`).
  No second file and no second row are created.
- Importing different bytes always creates a distinct book, even when title,
  author and series are identical. Titles are display data, never identity.
- If the database row exists but its asset is missing, re-importing the same
  bytes repairs the file in place and increments `localAssetRevision`; the book
  id is unchanged.

## Downloads (`NET-001`, partial)

`ResumableDownloader` uses `dio` with:

- `Range: bytes=<received>-` plus `If-Range` (ETag/Last-Modified) for resume;
- restart when the server replies `200` or `416` instead of `206`;
- a 1 GB hard cap on downloaded bytes;
- mandatory size check before promotion;
- optional SHA-256 verification supplied by the caller;
- cancellation that raises `DownloadCancelledException` and **keeps** the
  `.part`/`.meta` pair for a later resume;
- `ENOSPC` mapped to `StoragePressureException` with partial data removed.

The downloaded file is validated by the same EPUB importer, then the staging
copy is deleted. Downloaded EPUBs are stored like any other import and are
never evicted by cache policies.

### Not yet implemented

- Durable, bounded download queue and restart recovery (`DATA-002` journal).
- Remote checksum/ETag persistence in the database.
- Background download while the app is not foregrounded.

## Device evidence

Emulator-5554, debug APK built from this tree:

- On first launch the app adopted `count-of-monte-cristo.epub` from the
  development shelf and displayed **The Count of Monte Cristo — Alexandre Dumas**.
- A second file pushed to the shelf was adopted on the next refresh and the
  shelf showed **Pride and Prejudice — Jane Austen**.
- Opening the adopted book rendered through the loopback renderer:
  `HOST_BRIDGE {"type":"book","payload":{"title":"Pride and Prejudice","sections":18}}`
  followed by `page` and `ready` events.
- Re-importing the same files reported duplicates instead of adding rows.

## UI

- App bar **+** → system document picker (SAF via `file_selector`), filtered to
  `application/epub+zip`.
- **Add from URL** → validated resumable download with progress and cancel.
- Shelf reads from the Drift database; cover thumbnails are shown when present.
- Files dropped into `Android/data/dev.knatz.mia_legilo/files/books` are adopted
  on refresh. This is a development convenience, not the production path.

## Known limits

- The picker is wired through the official `file_selector` SAF plugin, but the
  interactive picker flow has not been automated on device. The import path
  behind it is the same one exercised by shelf adoption.
- Shelf adoption re-hashes every file on refresh; large development shelves
  will be slow until the `DATA-002` journal records path + size + mtime.
- Reading position is not yet persisted per book (`LIB-008`).

