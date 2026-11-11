"""Build out/nx_patch.pck: just the port's scripts (patch/nx/*.gd as res://nx/*.gd).
The Switch engine loads sdmc:/switch/buckshot_roulette/nx_patch.pck after the main pack and lets it replace files,
so script changes need only this small upload. Project settings (override.cfg, autoload list) still come from the main pack.
usage: make_nx_patch.py [out/nx_patch.pck]"""
import glob, hashlib, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    dst = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "out", "nx_patch.pck")
    files = {}
    for p in sorted(glob.glob(os.path.join(HERE, "..", "patch", "nx", "*.gd"))):
        files["res://nx/" + os.path.basename(p)] = open(p, "rb").read()
    names = list(files)
    enc, dir_size = [], 4
    for n in names:
        b = n.encode()
        b += b"\0" * ((4 - len(b) % 4) % 4)
        enc.append(b)
        dir_size += 4 + len(b) + 16 + 16 + 4
    file_base = (4 + 16 + 12 + 64 + dir_size + 15) & ~15
    offs, cur = [], 0
    for n in names:
        offs.append(cur)
        cur = (cur + len(files[n]) + 15) & ~15
    with open(dst, "wb") as o:
        o.write(b"GDPC" + struct.pack("<4I", 2, 4, 1, 1) + struct.pack("<IQ", 0, file_base) + b"\0" * 64)
        o.write(struct.pack("<I", len(names)))
        for i, n in enumerate(names):
            d = files[n]
            o.write(struct.pack("<I", len(enc[i])) + enc[i] + struct.pack("<QQ", offs[i], len(d)) + hashlib.md5(d).digest() + struct.pack("<I", 0))
        o.write(b"\0" * (file_base - o.tell()))
        for n in names:
            d = files[n]
            o.write(d + b"\0" * ((16 - len(d) % 16) % 16))
    print("wrote %s (%s)" % (dst, ", ".join(names)))


if __name__ == "__main__":
    main()
