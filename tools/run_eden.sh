#!/bin/bash
# Build NRO, copy to Eden's virtual SD, run for N seconds, print the log.
set -e
R=/c/Users/Admin/Documents/buckshot_roulette-nx
E=/c/Users/Admin/Downloads/Eden-Windows-v0.2.0-amd64-clang-pgo
SD=/c/Users/Admin/AppData/Roaming/eden/sdmc/switch/buckshot_roulette
T=/c/devkitPro/tools/bin
mkdir -p $SD $R/out
$T/elf2nro.exe $R/godot/bin/godot.switch.template_release.arm64.elf $R/out/buckshot_roulette.nro --nacp=$R/out/br.nacp >/dev/null
cp $R/out/buckshot_roulette.nro $SD/
cp $R/out/buckshot_roulette.nro $R/out/sd/switch/buckshot_roulette/
[ -f $SD/buckshot_roulette.pck ] || cp $R/out/buckshot_roulette.pck $SD/
rm -f $SD/godot_log.txt
taskkill //F //IM eden.exe >/dev/null 2>&1 || true
(cd $E && ./eden.exe -g "$(cygpath -w $SD/buckshot_roulette.nro)" >/dev/null 2>&1 &)
sleep ${1:-40}
[ -n "$SHOT" ] && powershell -c "Add-Type -A System.Drawing,System.Windows.Forms; \$b=[Windows.Forms.Screen]::PrimaryScreen.Bounds; \$i=New-Object Drawing.Bitmap \$b.Width,\$b.Height; [Drawing.Graphics]::FromImage(\$i).CopyFromScreen(0,0,0,0,\$i.Size); \$i.Save('$SHOT')"
cat $SD/godot_log.txt 2>/dev/null | tail -${2:-60}
[ -n "$KEEP" ] || taskkill //F //IM eden.exe >/dev/null 2>&1 || true
