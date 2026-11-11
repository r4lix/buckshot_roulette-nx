#!/usr/bin/env python3
"""Build the Switch data pack from the user's own Steam copy.

Reads the PCK embedded in "Buckshot Roulette.exe" and writes a new PCK that contains every
original file plus:
  res://nx/SteamStub.gd     offline stand-in for the GodotSteam singleton
  res://override.cfg        registers the stub as autoload "Steam", selects the GLES3 renderer

  res://nx/*.gd              the port's scripts (menu, cursor, renderer workarounds)

usage: make_switch_pck.py "<...>/Buckshot Roulette.exe" out/buckshot_roulette.pck
"""
import glob, hashlib, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
# repo layout: tools/ next to patch/; release layout: patch/ next to this script
PATCH = next(p for p in (os.path.join(HERE, "patch"), os.path.join(HERE, "..", "patch")) if os.path.isdir(p))
STUB = os.path.join(PATCH, "steam_stub", "SteamStub.gd")

OVERRIDE = b"""[autoload]

Steam="*res://nx/SteamStub.gd"
NxCursor="*res://nx/NxCursor.gd"
NxDebug="*res://nx/NxDebug.gd"
NxMenu="*res://nx/NxMenu.gd"

[rendering]

scaling_3d/mode=0
scaling_3d/scale=0.7
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
lights_and_shadows/directional_shadow/size=2048
lights_and_shadows/positional_shadow/atlas_size=2048

[nx]

swap_interval=2

[display]

window/size/mode=3
"""


def read_pck(f):
    f.seek(0, 2)
    end = f.tell()
    f.seek(0)
    if f.read(4) == b"GDPC":
        start = 0
    else:
        f.seek(end - 12)
        size, magic = struct.unpack("<Q4s", f.read(12))
        if magic != b"GDPC":
            sys.exit("no PCK found")
        start = end - 12 - size
    f.seek(start + 4)
    ver, a, b, c = struct.unpack("<4I", f.read(16))
    flags, file_base = struct.unpack("<IQ", f.read(12))
    f.read(64)
    if flags & 1:
        sys.exit("encrypted PCK not supported")
    if flags & 2:
        file_base += start
    (count,) = struct.unpack("<I", f.read(4))
    entries = []
    for _ in range(count):
        (plen,) = struct.unpack("<I", f.read(4))
        path = f.read(plen).rstrip(b"\0").decode()
        off, sz = struct.unpack("<QQ", f.read(16))
        md5 = f.read(16)
        ef = struct.unpack("<I", f.read(4))[0]
        entries.append([path, file_base + off, sz, md5, ef])
    return (ver, a, b, c), entries


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    extra = {"res://nx/SteamStub.gd": open(STUB, "rb").read()}
    for p in sorted(glob.glob(os.path.join(PATCH, "nx", "*.gd"))):
        extra["res://nx/" + os.path.basename(p)] = open(p, "rb").read()
    extra["res://override.cfg"] = OVERRIDE

    with open(src, "rb") as f:
        version, entries = read_pck(f)
        if not any(e[0] == "res://scripts/MenuManager.gd" for e in entries):
            sys.exit("this does not look like Buckshot Roulette's game data")
        print("read %d files from %s" % (len(entries), src))
        entries = [e for e in entries if e[0] not in extra]
        new = [(p, d) for p, d in extra.items()]

        names = [e[0] for e in entries] + [p for p, _ in new]
        sizes = [e[2] for e in entries] + [len(d) for _, d in new]
        md5s = [e[3] for e in entries] + [hashlib.md5(d).digest() for _, d in new]

        # Header + directory size.
        dir_size = 4
        enc_names = []
        for n in names:
            b = n.encode()
            pad = (4 - len(b) % 4) % 4
            enc_names.append(b + b"\0" * pad)
            dir_size += 4 + len(enc_names[-1]) + 16 + 16 + 4
        header_size = 4 + 16 + 12 + 64
        file_base = header_size + dir_size
        file_base = (file_base + 15) & ~15

        offsets = []
        cur = 0
        for s in sizes:
            offsets.append(cur)
            cur += s
            cur = (cur + 15) & ~15

        with open(dst, "wb") as o:
            o.write(b"GDPC")
            o.write(struct.pack("<4I", 2, *version[1:]))
            o.write(struct.pack("<IQ", 0, file_base))
            o.write(b"\0" * 64)
            o.write(struct.pack("<I", len(names)))
            for i, n in enumerate(enc_names):
                o.write(struct.pack("<I", len(n)) + n)
                o.write(struct.pack("<QQ", offsets[i], sizes[i]))
                o.write(md5s[i])
                o.write(struct.pack("<I", 0))
            o.write(b"\0" * (file_base - o.tell()))
            for i, e in enumerate(entries):
                f.seek(e[1])
                left = e[2]
                while left:
                    b = f.read(min(left, 1 << 24))
                    o.write(b)
                    left -= len(b)
                o.write(b"\0" * ((16 - e[2] % 16) % 16))
            for p, d in new:
                o.write(d)
                o.write(b"\0" * ((16 - len(d) % 16) % 16))
    print("wrote %s (%d files)" % (dst, len(names)))


if __name__ == "__main__":
    main()
