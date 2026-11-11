#!/usr/bin/env python3
"""Extract a Godot 4.x PCK, standalone or embedded in an exported executable.

usage: pck_extract.py <game.exe|game.pck> <out_dir> [--list] [--raw-pck out.pck]
"""
import os, struct, sys

PACK_DIR_ENCRYPTED = 1
PACK_REL_FILEBASE = 2


def find_pck(f):
    f.seek(0, 2)
    end = f.tell()
    f.seek(0)
    if f.read(4) == b"GDPC":
        return 0, end
    f.seek(end - 12)
    size, magic = struct.unpack("<Q4s", f.read(12))
    if magic != b"GDPC":
        sys.exit("no embedded PCK found")
    start = end - 12 - size
    f.seek(start)
    if f.read(4) != b"GDPC":
        sys.exit("bad PCK header at %d" % start)
    return start, size


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        sys.exit(__doc__)
    src, out = a[0], a[1]
    only_list = "--list" in a
    raw = a[a.index("--raw-pck") + 1] if "--raw-pck" in a else None
    with open(src, "rb") as f:
        start, size = find_pck(f)
        f.seek(start + 4)
        ver, vmaj, vmin, vpat = struct.unpack("<4I", f.read(16))
        flags = 0
        file_base = 0
        if ver >= 2:
            flags, file_base = struct.unpack("<IQ", f.read(12))
        f.read(16 * 4)
        print("PCK v%d engine %d.%d.%d flags=%#x base=%d at %d size %d" %
              (ver, vmaj, vmin, vpat, flags, file_base, start, size))
        if flags & PACK_DIR_ENCRYPTED:
            sys.exit("directory is encrypted; key needed")
        if ver >= 2 and flags & PACK_REL_FILEBASE:
            file_base += start
        elif ver >= 2:
            file_base += 0
        (count,) = struct.unpack("<I", f.read(4))
        entries = []
        for _ in range(count):
            (plen,) = struct.unpack("<I", f.read(4))
            path = f.read(plen).rstrip(b"\0").decode("utf-8")
            off, sz = struct.unpack("<QQ", f.read(16))
            f.read(16)  # md5
            eflags = struct.unpack("<I", f.read(4))[0] if ver >= 2 else 0
            entries.append((path, off, sz, eflags))
        if raw:
            f.seek(start)
            with open(raw, "wb") as o:
                left = size
                while left:
                    b = f.read(min(left, 1 << 24))
                    o.write(b)
                    left -= len(b)
            print("wrote raw pck", raw)
        enc = 0
        total = 0
        for path, off, sz, eflags in entries:
            total += sz
            if eflags & 1:
                enc += 1
            if only_list:
                print("%10d %s%s" % (sz, path, " [enc]" if eflags & 1 else ""))
                continue
            rel = path[6:] if path.startswith("res://") else path
            dst = os.path.join(out, *rel.split("/"))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            f.seek(file_base + off)
            with open(dst, "wb") as o:
                left = sz
                while left:
                    b = f.read(min(left, 1 << 24))
                    o.write(b)
                    left -= len(b)
        print("%d files, %d bytes, %d encrypted" % (count, total, enc))


if __name__ == "__main__":
    main()
