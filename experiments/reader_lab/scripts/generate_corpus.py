#!/usr/bin/env python3
"""Generate the Reader Lab EPUB corpus.

Every file is original synthetic text written for this benchmark and released
as CC0-1.0. No Project Gutenberg or commercial book is bundled. The script is
deterministic: the same invocation always writes the same bytes.
"""

from __future__ import annotations

import hashlib
import json
import struct
import zipfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "test_books"
LICENSE = "CC0-1.0"
SOURCE = "experiments/reader_lab/scripts/generate_corpus.py"

WORDS = (
    "anchor page margin column glyph margin line reader chapter passage "
    "paper lamp quiet street river window garden letter clock shadow "
    "bridge market harbor lantern orchard winter summer ink paper "
    "notebook compass lantern meadow railway station lantern folio"
).split()


def paragraph(seed: int, count: int) -> str:
    out = []
    state = seed & 0xFFFFFFFF
    for _ in range(count):
        state = (1664525 * state + 1013904223) & 0xFFFFFFFF
        out.append(WORDS[state % len(WORDS)])
    text = " ".join(out)
    return text[0].upper() + text[1:] + "."


def png_rgb(width: int, height: int, rgb: bytes) -> bytes:
    if len(rgb) != 3:
        raise ValueError("rgb must be 3 bytes")

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = b"".join(b"\x00" + rgb * width for _ in range(height))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def xhtml(title: str, body: str, lang: str = "en") -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops" '
        f'lang="{lang}" xml:lang="{lang}">\n'
        "<head>\n"
        '  <meta charset="utf-8"/>\n'
        f"  <title>{title}</title>\n"
        '  <link rel="stylesheet" type="text/css" href="style.css"/>\n'
        "</head>\n"
        f"<body>\n{body}\n</body>\n</html>\n"
    )


def container_xml() -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
        "  <rootfiles>\n"
        '    <rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/>\n'
        "  </rootfiles>\n"
        "</container>\n"
    )


def style_css(extra: str = "") -> str:
    return (
        "body { font-family: serif; line-height: 1.5; margin: 1em; }\n"
        "h1 { font-size: 1.4em; }\n"
        "p { margin: 0 0 0.8em 0; }\n"
        "table { border-collapse: collapse; }\n"
        "td, th { border: 1px solid #444; padding: 0.3em; }\n"
        ".secret { display: none; }\n"
        ".dropcap::first-letter { font-weight: 700; font-size: 2em; }\n"
        + extra
    )


def nav_xhtml(title: str, items: list[tuple[str, str]]) -> str:
    links = "\n".join(
        f'        <li><a href="{href}">{label}</a></li>' for href, label in items
    )
    return xhtml(
        "Contents",
        "<nav epub:type=\"toc\" id=\"toc\">\n"
        f"  <h1>Contents</h1>\n  <ol>\n{links}\n  </ol>\n</nav>\n"
        "<nav epub:type=\"landmarks\" hidden=\"hidden\">\n"
        "  <ol>\n"
        '    <li><a epub:type="bodymatter" href="chapter-001.xhtml">Start</a></li>\n'
        "  </ol>\n</nav>\n",
    )


def opf(
    book_id: str,
    title: str,
    chapters: list[tuple[str, str]],
    extras: list[tuple[str, str, str]],
) -> str:
    manifest = [
        '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
        '    <item id="style" href="style.css" media-type="text/css"/>',
    ]
    spine = []
    for index, (filename, _label) in enumerate(chapters, start=1):
        item_id = f"c{index:03d}"
        manifest.append(
            f'    <item id="{item_id}" href="{filename}" media-type="application/xhtml+xml"/>'
        )
        spine.append(f'    <itemref idref="{item_id}"/>')
    for item_id, href, media in extras:
        manifest.append(
            f'    <item id="{item_id}" href="{href}" media-type="{media}"/>'
        )
    manifest_xml = "\n".join(manifest)
    spine_xml = "\n".join(spine)
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
        'unique-identifier="bookid" xml:lang="en">\n'
        "  <metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n"
        f"    <dc:identifier id=\"bookid\">{book_id}</dc:identifier>\n"
        f"    <dc:title>{title}</dc:title>\n"
        "    <dc:language>en</dc:language>\n"
        "    <dc:creator>Mia Legilo Reader Lab</dc:creator>\n"
        "    <dc:rights>CC0-1.0</dc:rights>\n"
        '    <meta property="dcterms:modified">2026-11-10T00:00:00Z</meta>\n'
        "  </metadata>\n"
        f"  <manifest>\n{manifest_xml}\n  </manifest>\n"
        f'  <spine>\n{spine_xml}\n  </spine>\n'
        "</package>\n"
    )


def write_epub(path: Path, files: dict[str, bytes]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w") as archive:
        info = zipfile.ZipInfo("mimetype")
        info.compress_type = zipfile.ZIP_STORED
        archive.writestr(info, "application/epub+zip")
        for name in sorted(files):
            archive.writestr(name, files[name], compress_type=zipfile.ZIP_DEFLATED)


def chapter_body(
    book_code: str,
    index: int,
    title: str,
    paragraphs: list[str],
    extra: str = "",
    semantic: str = "chapter",
) -> str:
    anchor = f"ANCHOR-{book_code}-CH-{index:02d}"
    body_paragraphs = "\n".join(f"  <p>{p}</p>" for p in paragraphs)
    return (
        f'  <section epub:type="{semantic}" id="ch{index:02d}">\n'
        f"  <h1>{title}</h1>\n"
        f'  <p id="anchor">{anchor}</p>\n'
        f"{body_paragraphs}\n"
        f"{extra}"
        "  </section>"
    )


def build_book(
    filename: str,
    book_id: str,
    book_code: str,
    title: str,
    chapter_count: int,
    words_per_paragraph: int,
    paragraphs_per_chapter: int,
    notable: str,
    extra_for_chapter=None,
    extras: list[tuple[str, str, str]] | None = None,
    extra_files: dict[str, bytes] | None = None,
    css_extra: str = "",
    semantic_for=None,
) -> dict:
    chapters = []
    files: dict[str, bytes] = {}
    nav_items = []
    for index in range(1, chapter_count + 1):
        label = f"Chapter {index}"
        href = f"chapter-{index:03d}.xhtml"
        paragraphs = [
            paragraph(index * 1000 + n, words_per_paragraph)
            for n in range(paragraphs_per_chapter)
        ]
        extra = extra_for_chapter(index) if extra_for_chapter else ""
        semantic = semantic_for(index) if semantic_for else "chapter"
        files[f"OEBPS/{href}"] = xhtml(
            label,
            chapter_body(book_code, index, label, paragraphs, extra, semantic),
        ).encode()
        chapters.append((href, label))
        nav_items.append((href, label))
    files["OEBPS/nav.xhtml"] = nav_xhtml(title, nav_items).encode()
    files["OEBPS/style.css"] = style_css(css_extra).encode()
    files["OEBPS/content.opf"] = opf(book_id, title, chapters, extras or []).encode()
    files["META-INF/container.xml"] = container_xml().encode()
    if extra_files:
        files.update(extra_files)
    path = OUT / filename
    write_epub(path, files)
    data = path.read_bytes()
    return {
        "id": book_code,
        "filename": filename,
        "title": title,
        "source": SOURCE,
        "license": LICENSE,
        "sha256": hashlib.sha256(data).hexdigest(),
        "sizeBytes": len(data),
        "epubVersion": "3.0",
        "spineItemCount": chapter_count,
        "notable": notable,
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    image = png_rgb(32, 24, b"\x20\x20\x20")
    books = [
        build_book(
            "EPUB-001-simple.epub",
            "urn:reader-lab:epub-001",
            "EPUB-001",
            "Simple Text",
            3,
            40,
            2,
            "Short text-only EPUB 3. Three spine items, no images or tables.",
        ),
        build_book(
            "EPUB-002-novel.epub",
            "urn:reader-lab:epub-002",
            "EPUB-002",
            "Medium Novel",
            18,
            70,
            6,
            "Medium novel shape: 18 spine items with several paragraphs each.",
        ),
        build_book(
            "EPUB-003-many-spines.epub",
            "urn:reader-lab:epub-003",
            "EPUB-003",
            "Many Spine Items",
            120,
            90,
            8,
            "120 spine items and longer chapters. Used for load, memory and boundary frequency.",
        ),
        build_book(
            "EPUB-004-css.epub",
            "urn:reader-lab:epub-004",
            "EPUB-004",
            "Complex CSS",
            4,
            50,
            3,
            "Publisher CSS includes a hidden paragraph, a drop cap, and text-align. "
            "The hidden sentence is HIDDEN-EPUB-004-SHOULD-NOT-APPEAR.",
            extra_for_chapter=lambda index: (
                '  <p class="dropcap">Drop cap paragraph for chapter '
                f"{index}.</p>\n"
                '  <p style="text-align: center">CENTERED-EPUB-004</p>\n'
                '  <p class="secret">HIDDEN-EPUB-004-SHOULD-NOT-APPEAR</p>\n'
                if index == 1
                else ""
            ),
            css_extra="p.dropcap { text-indent: 0; }\n",
        ),
        build_book(
            "EPUB-005-mixed.epub",
            "urn:reader-lab:epub-005",
            "EPUB-005",
            "Images Tables Footnotes",
            5,
            40,
            2,
            "Contains one PNG, an HTML table, and an EPUB 3 footnote.",
            extra_for_chapter=lambda index: (
                '  <p><img src="images/plate.png" alt="Grey test plate"/></p>\n'
                "  <table>\n    <tr><th>Name</th><th>Value</th></tr>\n"
                "    <tr><td>TABLE-CELL-EPUB-005</td><td>1</td></tr>\n"
                "  </table>\n"
                '  <p>See note <a epub:type="noteref" href="chapter-002.xhtml#note1">1</a>.</p>\n'
                if index == 1
                else (
                    '  <aside epub:type="footnote" id="note1"><p>FOOTNOTE-EPUB-005</p></aside>\n'
                    if index == 2
                    else ""
                )
            ),
            extras=[("plate", "images/plate.png", "image/png")],
            extra_files={"OEBPS/images/plate.png": image},
        ),
        build_book(
            "EPUB-006-long-chapters.epub",
            "urn:reader-lab:epub-006",
            "EPUB-006",
            "Long Chapters",
            2,
            80,
            40,
            "Two long spine items, to stress per-chapter layout cost.",
        ),
        build_book(
            "EPUB-007-short-chapters.epub",
            "urn:reader-lab:epub-007",
            "EPUB-007",
            "Short Chapters",
            36,
            25,
            2,
            "36 very short spine items. Boundary crossing is frequent.",
        ),
        build_book(
            "EPUB-008-epub3-nav.epub",
            "urn:reader-lab:epub-008",
            "EPUB-008",
            "EPUB 3 Semantics",
            6,
            45,
            3,
            "EPUB 3 package with a nav document, landmarks, and epub:type on sections.",
            semantic_for=lambda index: "bodymatter chapter" if index > 1 else "frontmatter",
        ),
    ]
    manifest = {
        "generator": SOURCE,
        "license": LICENSE,
        "note": "Original synthetic books. No third-party book text is included.",
        "books": books,
    }
    (OUT / "corpus_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    for book in books:
        print(f"{book['filename']} spines={book['spineItemCount']} bytes={book['sizeBytes']}")


if __name__ == "__main__":
    main()
