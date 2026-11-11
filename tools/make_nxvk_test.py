"""Build a tiny Godot 4.1 pack (nxvk smoke test) from tools/nxvk_test/.
usage: make_nxvk_test.py out/nxvk_test.pck"""
import hashlib, os, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "nxvk_test")

PROJECT = b"""config_version=5

[application]

config/name="nxvk_test"
run/main_scene="res://main.tscn"

[display]

window/size/viewport_width=960
window/size/viewport_height=540
window/stretch/mode="viewport"

[rendering]

renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
"""

SCENE = b"""[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
"""


def main():
    dst = sys.argv[1]
    files = {
        "res://project.godot": PROJECT,
        "res://main.tscn": SCENE,
        "res://main.gd": open(os.path.join(SRC, "main.gd"), "rb").read(),
    }
    names = list(files)
    enc = []
    dir_size = 4
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
    print("wrote", dst)


if __name__ == "__main__":
    main()
