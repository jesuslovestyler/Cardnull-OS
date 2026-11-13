#!/usr/bin/env python3
"""Build the Bible text files Cardnull OS carries (milestone 34).

The text is the Douay-Rheims Bible, Challoner revision,
American Edition 1899 — public domain — in the very form
Tyler's Catholic Bible app carries it (as published by
eBible.org, engDRA): three JavaScript data files holding
one array of books per testament, each book a name and a
list of chapters, each chapter its verses one to a line.

This tool is the authoring road, run once (and again only
if the text is ever re-taken): it reads those data files,
sets the books in the Catholic order — the deuterocanon in
its traditional places (Tobias and Judith after 2 Esdras,
Wisdom and Ecclesiasticus after the Canticle, Baruch after
Lamentations, the Machabees closing the Old Testament) —
and writes plain-text group files under disc/bible/, no
group over the bundle's per-file bound, whole books only,
plus an index naming every book's place. The build then
stages the group files at the disc's root and the bundle
manifest carries them, so the Bible rides in memory like
every system file.

Each book's text stands so:

    Genesis

    Chapter 1

    1 In the beginning God created heaven, and earth.
    2 ...

with a blank line between chapters. In the Psalms the
chapter lines are "Psalm N" — the Douay-Rheims' own
numbering, the Vulgate's, which the source data keeps.

The one character the screen cannot draw, the right
single quotation mark, is set down as a plain apostrophe;
every other byte of the source is already printable
ASCII or a line feed, and the tool refuses to write a
file that holds anything else.

    build-bible-text.py <assets-dir> <out-dir>

<assets-dir> holds ot.js, nt.js, deut.js from the
Catholic Bible app. The tool proves its work as it goes:
73 books, the chapter counts the source declares, and
the verses a reader will look for first, letter for
letter.
"""

import json
import os
import sys

GROUP_MAX = 950_000

ORDER = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
    "Josue", "Judges", "Ruth", "1 Kings", "2 Kings", "3 Kings",
    "4 Kings", "1 Paralipomenon", "2 Paralipomenon", "1 Esdras",
    "2 Esdras", "Tobias", "Judith", "Esther", "Job", "Psalms",
    "Proverbs", "Ecclesiastes", "Canticle of Canticles",
    "Wisdom", "Ecclesiasticus", "Isaias", "Jeremias",
    "Lamentations", "Baruch", "Ezechiel", "Daniel", "Osee",
    "Joel", "Amos", "Abdias", "Jonas", "Micheas", "Nahum",
    "Habacuc", "Sophonias", "Aggeus", "Zacharias", "Malachias",
    "1 Machabees", "2 Machabees",
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
    "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1 Thessalonians",
    "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus",
    "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
    "1 John", "2 John", "3 John", "Jude", "Apocalypse",
]

# Chapter verse-count witnesses: (book, chapter index, count).
WITNESSES = [
    ("Genesis", 0, 31), ("Genesis", 1, 25), ("John", 0, 51),
    ("John", 2, 36), ("Matthew", 0, 25), ("Psalms", 117, 176),
    ("Apocalypse", 21, 21),
]


def load_books(path):
    src = open(path, encoding="utf-8").read()
    start = src.index("[")
    books, _ = json.JSONDecoder().raw_decode(src[start:])
    return books


def book_text(name, chapters):
    lines = [name, ""]
    for i, chapter in enumerate(chapters):
        if name == "Psalms":
            lines.append(f"Psalm {i + 1}")
        else:
            lines.append(f"Chapter {i + 1}")
        lines.append("")
        verses = [v.strip() for v in chapter.split("\n")]
        verses = [v for v in verses if v]
        for n, verse in enumerate(verses):
            lines.append(f"{n + 1} {verse}")
        lines.append("")
    text = "\n".join(lines)
    return text.replace("\u2019", "'")


def main():
    assets, out_dir = sys.argv[1], sys.argv[2]
    by_name = {}
    for fname in ("ot.js", "deut.js", "nt.js"):
        for book in load_books(os.path.join(assets, fname)):
            assert book["n"] not in by_name, book["n"]
            by_name[book["n"]] = book["c"]
    assert len(by_name) == 73, len(by_name)
    assert set(by_name) == set(ORDER), (
        set(by_name) ^ set(ORDER))

    for name, ch_idx, count in WITNESSES:
        verses = [v for v in by_name[name][ch_idx].split("\n")
                  if v.strip()]
        assert len(verses) == count, (name, ch_idx, len(verses))

    os.makedirs(out_dir, exist_ok=True)
    groups = []          # (filename, bytes)
    index = []           # (groupfile, offset, length, name)
    cur = bytearray()
    cur_name = None

    def flush():
        nonlocal cur, cur_name
        if cur_name is None:
            return
        path = os.path.join(out_dir, cur_name)
        with open(path, "wb") as f:
            f.write(cur)
        groups.append((cur_name, len(cur)))
        cur = bytearray()
        cur_name = None

    for name in ORDER:
        data = book_text(name, by_name[name]).encode("ascii")
        if cur_name is not None and len(cur) + len(data) \
                > GROUP_MAX:
            flush()
        if cur_name is None:
            cur_name = f"BIBLE-{len(groups) + 1}.TXT"
        index.append((cur_name, len(cur), len(data), name))
        cur += data
    flush()

    idx = ["CARDNULL BIBLE 1", f"books: {len(index)}",
           "The Douay-Rheims Bible (Challoner, 1899)"]
    for group, offset, length, name in index:
        idx.append(f"{group} {offset} {length} {name}")
    idx_bytes = ("\n".join(idx) + "\n").encode("ascii")
    with open(os.path.join(out_dir, "BIBLE-IDX.TXT"), "wb") as f:
        f.write(idx_bytes)

    total = sum(n for _, n in groups)
    print(f"books: {len(index)}, groups: {len(groups)}, "
          f"text bytes: {total}, index bytes: {len(idx_bytes)}")
    for group, n in groups:
        print(f"  {group}: {n} bytes")
    # The verses a reader looks for first, letter for letter.
    joined = b"".join(
        open(os.path.join(out_dir, g), "rb").read()
        for g, _ in groups).decode("ascii")
    for needle in (
        "1 In the beginning God created heaven, and earth.",
        "1 In the beginning was the Word, and the Word was "
        "with God, and the Word was God.",
        "16 For God so loved the world, as to give his only "
        "begotten Son; that whosoever believeth in him, may "
        "not perish, but may have life everlasting.",
        "1 A psalm for David. The Lord ruleth me: and I "
        "shall want nothing.",
    ):
        assert needle in joined, needle
        print("verified:", needle[:60] + "...")
    print("Bible text built.")


if __name__ == "__main__":
    main()
