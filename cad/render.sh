#!/bin/bash
# Render every printable part to out/stl + out/png, assembly views to out/png,
# and the 1:1 drilling template to out/drill_template.svg.
# Usage: ./render.sh            everything
#        ./render.sh wheel      one part (or "assembly")
set -euo pipefail
cd "$(dirname "$0")"

OPENSCAD="${OPENSCAD:-$HOME/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD}"
[ -x "$OPENSCAD" ] || OPENSCAD="$(command -v openscad)"
PARTS=(saddle motor_cradle wheel caster_mount caster_fork caster_wheel caster_bushing skid l298n_mount lm2596_mount cam_cradle bank_strap can_tab)
COMMON=(--backend=manifold --colorscheme=Tomorrow)
IMG=(--imgsize=1200,900)
mkdir -p out/stl out/png

render_part() {
    local p=$1
    "$OPENSCAD" -q "${COMMON[@]}" -D "part=\"$p\"" -o "out/stl/$p.stl" robot.scad
    "$OPENSCAD" -q "${COMMON[@]}" "${IMG[@]}" -D "part=\"$p\"" --render --autocenter --viewall \
        --camera=0,0,0,55,0,25,0 -o "out/png/$p.png" robot.scad
    echo "  $p"
}

render_assembly() {
    # gimbal camera: translate x,y,z, rotate x,y,z, distance (viewall refits it)
    # "under" views hide the can so you can see the electronics
    local views=("iso:0,0,0,65,0,35,0" "under:0,0,0,125,0,35,0" "under_flat:0,0,0,180,0,0,0" "side:0,0,0,90,0,90,0" "front:0,0,0,90,0,0,0")
    for v in "${views[@]}"; do
        # the can is a preview-only ghost, so views with it use preview mode
        local mode=(-D show_can=true); [[ $v == under* ]] && mode=(-D show_can=false --render)
        "$OPENSCAD" -q "${COMMON[@]}" "${IMG[@]}" -D 'part="assembly"' "${mode[@]}" --autocenter --viewall \
            --camera="${v#*:}" -o "out/png/assembly_${v%%:*}.png" robot.scad
        echo "  assembly_${v%%:*}"
    done
}

render_sheet() {
    "$OPENSCAD" -q "${COMMON[@]}" --imgsize=1600,1200 -D 'part="parts_sheet"' --autocenter --viewall \
        --camera=0,0,0,40,0,0,0 -o out/png/parts_sheet.png robot.scad
    echo "  parts_sheet"
}

if [ $# -gt 0 ]; then
    case $1 in
        assembly) render_assembly ;;
        parts_sheet) render_sheet ;;
        *) render_part "$1" ;;
    esac
    exit
fi

echo "parts:"
for p in "${PARTS[@]}"; do render_part "$p"; done
render_sheet
echo "assembly:"
render_assembly
"$OPENSCAD" -q -D 'part="drill_template"' -o out/drill_template.svg robot.scad
"$OPENSCAD" -q "${COMMON[@]}" "${IMG[@]}" -D 'part="drill_template"' --autocenter --viewall --camera=0,0,0,0,0,0,0 --projection=o -o out/png/drill_template.png robot.scad
echo "  drill_template.svg"
