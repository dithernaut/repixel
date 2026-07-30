#!/usr/bin/env bash
#   test/run.sh              run every check, write test/gallery.png, clean up
#   test/run.sh --keep       also leave the built output in test/work/
#   test/run.sh --regen      rebuild the committed fixtures, then run
#
# Fixtures stay committed because regeneration can vary by ImageMagick version.

set -uo pipefail
cd "$(dirname "$0")"

REPIXEL="$PWD/../repixel"
THEMES="$PWD/themes.test.conf"
FIX="$PWD/fixtures"
GALLERY="$PWD/gallery.png"
KEEP=0; REGEN=0
for a in "$@"; do
  case "$a" in
    --keep)  KEEP=1;;
    --regen) REGEN=1;;
    *) echo "usage: run.sh [--keep] [--regen]" >&2; exit 2;;
  esac
done

FONT=""
for f in /System/Library/Fonts/Supplemental/Arial.ttf \
         /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf \
         /usr/share/fonts/TTF/DejaVuSans.ttf; do
  [[ -f "$f" ]] && { FONT="$f"; break; }
done

if (( KEEP )); then WORK="$PWD/work"; rm -rf "$WORK"; mkdir -p "$WORK"
else WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT; fi

PASS=0; FAIL=0
if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'
else G=""; R=""; D=""; N=""; fi

ok()  { printf '  %sok%s   %s\n' "$G" "$N" "$1"; PASS=$((PASS+1)); }
no()  { printf '  %sFAIL%s %s\n' "$R" "$N" "$1"
        [[ -n "${2:-}" ]] && printf '%s       %s%s\n' "$D" "$2" "$N"
        FAIL=$((FAIL+1)); return 0; }
check() { [[ "$2" == "$3" ]] && ok "$1" || no "$1" "expected [$2] got [$3]"; }
section() { printf '\n%s\n' "$1"; }

colors_of() {
  magick "$1" -alpha off -depth 8 -unique-colors txt: 2>/dev/null \
    | grep -oiE '#[0-9A-F]{6}' | tr '[:lower:]' '[:upper:]' | tr -d '#' \
    | sort -u | paste -sd, -
}
dims_of() { magick identify -format '%wx%h' "$1[0]"; }
has()     { [[ -e "$1" ]] && echo yes || echo no; }
hasglob() { compgen -G "$1" >/dev/null 2>&1 && echo yes || echo no; }

all_from_set() {
  local list="$1"; shift
  local c w res=yes found
  for c in ${list//,/ }; do
    found=no
    for w in "$@"; do [[ "$c" == "$w" ]] && found=yes; done
    [[ "$found" == no ]] && res=no
  done
  echo "$res"
}

make_flat() {
  local out="$1"; shift
  local -a args=(); local c
  for c in "$@"; do args+=(-size 8x8 "xc:#$c"); done
  magick "${args[@]}" +append -alpha off -colorspace sRGB -type TrueColor "$out"
}

section "fixtures"
if (( REGEN )) || [[ ! -d "$FIX" ]]; then
  rm -rf "$FIX"; mkdir -p "$FIX"
  make_flat "$FIX/still2.png" 000000 FFFFFF
  make_flat "$FIX/still4.png" 000000 555555 AAAAAA FFFFFF
  make_flat "$FIX/still6.png" 000000 333333 666666 999999 CCCCCC FFFFFF
  magick -size 400x400 xc:'#000000' -alpha off -colorspace sRGB -type TrueColor \
    "$FIX/big.png"
  magick "$FIX/big.png" -fill '#FFFFFF' -draw 'rectangle 0,0 199,199' "$FIX/big.png"
  magick -size 64x256 gradient:'#000000-#FFFFFF' -alpha off -colorspace sRGB \
    -type TrueColor "$FIX/many.png"
  for i in 1 2 3 4; do make_flat "$FIX/f_$i.png" 000000 555555 AAAAAA FFFFFF; done
  ffmpeg -nostdin -v error -y -framerate 12 -i "$FIX/f_%d.png" \
    -plays 0 -pix_fmt rgba -f apng "$FIX/anim.png"
  rm -f "$FIX"/f_?.png
  echo "  regenerated — commit test/fixtures/ if this was intentional"
fi

cat > "$THEMES" <<'EOF'
mono = 000000, 555555, AAAAAA, FFFFFF
grayscale = 000000, FFFFFF
duo = 112233, EEDDCC
six = 000000, 202020, 404040, 808080, C0C0C0, FFFFFF
warm = 171F41, 2F7077, FB6C76, FEEDE3
EOF
echo "  $(ls "$FIX" | wc -l | tr -d ' ') fixtures, $(du -sh "$FIX" | cut -f1) total"

run() { "$REPIXEL" --themes "$THEMES" "$@" 2>&1; }

section "fitting (the palette/shade count mismatch)"

O="$WORK/o1"; run "$FIX/still4.png" -p mono -o "$O" --formats apng >/dev/null
check "equal counts -> palette verbatim, bit-exact" \
  "000000,555555,AAAAAA,FFFFFF" "$(colors_of "$O/still4/mono/still4_mono_1x.png")"

O="$WORK/o2"; run "$FIX/still2.png" -p mono -o "$O" --formats apng >/dev/null
check "palette larger (4->2) -> darkest AND lightest, not two darks" \
  "000000,FFFFFF" "$(colors_of "$O/still2/mono/still2_mono_1x.png")"

O="$WORK/o3"; run "$FIX/still6.png" -p mono -o "$O" --formats apng >/dev/null
GOT="$(colors_of "$O/still6/mono/still6_mono_1x.png")"
check "palette smaller (4->6) -> 6 distinct colors" \
  "6" "$(echo "$GOT" | tr ',' '\n' | wc -l | tr -d ' ')"
MISSING=""
for c in 000000 555555 AAAAAA FFFFFF; do
  [[ ",$GOT," == *",$c,"* ]] || MISSING="$MISSING $c"
done
check "palette smaller -> every palette color still present" "" "$MISSING"

O="$WORK/o4"; run "$FIX/still6.png" -p duo -o "$O" --formats apng >/dev/null
GOT="$(colors_of "$O/still6/duo/still6_duo_1x.png")"
check "2-color palette on 6 shades -> endpoints exact" \
  "yes" "$([[ ",$GOT," == *",112233,"* && ",$GOT," == *",EEDDCC,"* ]] && echo yes || echo no)"
check "2-color palette on 6 shades -> 6 distinct colors" \
  "6" "$(echo "$GOT" | tr ',' '\n' | wc -l | tr -d ' ')"

O="$WORK/o5"; OUT="$(run "$FIX/still6.png" -p mono -o "$O" --fit exact --formats apng)"
check "--fit exact skips on mismatch" \
  "yes" "$([[ "$OUT" == *"skip"*"fit exact"* ]] && echo yes || echo no)"
check "--fit exact writes nothing" "no" "$(has "$O/still6/mono")"

O="$WORK/o6"; run "$FIX/still6.png" -p mono -o "$O" --fit nearest --formats apng >/dev/null
check "--fit nearest never invents a color" "yes" \
  "$(all_from_set "$(colors_of "$O/still6/mono/still6_mono_1x.png")" \
       000000 555555 AAAAAA FFFFFF)"

O="$WORK/o7"; run "$FIX/still2.png" -p six -o "$O" --formats apng >/dev/null
check "6-color palette on 2 shades -> real palette entries only" \
  "000000,FFFFFF" "$(colors_of "$O/still2/six/still2_six_1x.png")"

section "--mix (blend space)"

O="$WORK/x1"; run "$FIX/still4.png" -p grayscale -o "$O" --mix srgb --formats apng >/dev/null
check "grayscale + --mix srgb reproduces mono exactly" \
  "000000,555555,AAAAAA,FFFFFF" "$(colors_of "$O/still4/grayscale/still4_grayscale_1x.png")"

O="$WORK/x2"; run "$FIX/still4.png" -p mono -o "$O" --formats apng >/dev/null
check "...and matches the real mono theme" \
  "$(colors_of "$O/still4/mono/still4_mono_1x.png")" \
  "$(colors_of "$WORK/x1/still4/grayscale/still4_grayscale_1x.png")"

O="$WORK/x3"; run "$FIX/still4.png" -p grayscale -o "$O" --formats apng >/dev/null
check "oklab (default) is perceptually even, not hex-even" \
  "000000,363636,949494,FFFFFF" "$(colors_of "$O/still4/grayscale/still4_grayscale_1x.png")"

O="$WORK/x4"; run "$FIX/still4.png" -p grayscale -o "$O" --mix linear --formats apng >/dev/null
check "linear light mixing gives brighter midtones" \
  "000000,9C9C9C,D5D5D5,FFFFFF" "$(colors_of "$O/still4/grayscale/still4_grayscale_1x.png")"

O="$WORK/x5"; run "$FIX/still4.png" -p grayscale -o "$O" --mix oklch --formats apng >/dev/null
check "oklch == oklab on an achromatic palette" \
  "000000,363636,949494,FFFFFF" "$(colors_of "$O/still4/grayscale/still4_grayscale_1x.png")"

O="$WORK/x6"; run "$FIX/still4.png" -p warm -o "$O" --mix linear --formats apng >/dev/null
check "--mix is inert when counts are equal" \
  "171F41,2F7077,FB6C76,FEEDE3" "$(colors_of "$O/still4/warm/still4_warm_1x.png")"

O="$WORK/x7"; run "$FIX/still2.png" -p warm -o "$O" --mix linear --formats apng >/dev/null
check "--mix is inert when the palette is larger" \
  "171F41,FEEDE3" "$(colors_of "$O/still2/warm/still2_warm_1x.png")"

run "$FIX/still4.png" -p mono -o "$WORK/x" --mix hsv >/dev/null 2>&1
check "unknown --mix is rejected" "1" "$?"

section "palette optional"

O="$WORK/o0"; run "$FIX/still4.png" -o "$O" --formats apng >/dev/null
check "no -p preserves source colors" \
  "000000,555555,AAAAAA,FFFFFF" "$(colors_of "$O/still4/original/still4_original_1x.png")"
check "no -p still builds scaled output" "512x128" \
  "$(dims_of "$O/still4/original/still4_original_16x.png")"

O="$WORK/o0many"; run "$FIX/many.png" -o "$O" -x 1 --formats apng >/dev/null
check "no -p bypasses recolor shade limit" "yes" \
  "$(has "$O/many/original/many_original_1x.png")"

O="$WORK/o8"; run "$FIX/still4.png" -A -o "$O" --formats apng >/dev/null
check "-A builds every theme" "yes" \
  "$([[ -d "$O/still4/mono" && -d "$O/still4/duo" && -d "$O/still4/six" ]] && echo yes || echo no)"

run "$FIX/still4.png" -A -p mono -o "$WORK/x" >/dev/null 2>&1
check "-A and -p together is an error" "1" "$?"

O="$WORK/o9"; run "$FIX/still4.png" -p 111111,222222,333333,444444 -o "$O" --formats apng >/dev/null
check "one-off hex list still works" \
  "111111,222222,333333,444444" "$(colors_of "$O/still4/custom/still4_custom_1x.png")"

section "palette sources"

PAL="$WORK/pal"; mkdir -p "$PAL"
SET4="112233,445566,778899,AABBCC"

O="$WORK/p1"; run "$FIX/still4.png" -p "112233 445566 778899 AABBCC" -o "$O" --formats apng >/dev/null
check "inline: spaces instead of commas" "$SET4" \
  "$(colors_of "$O/still4/custom/still4_custom_1x.png")"

O="$WORK/p2"; run "$FIX/still4.png" -p "#112233, #445566, #778899, #aabbcc" -o "$O" --formats apng >/dev/null
check "inline: '#' prefixes and lowercase" "$SET4" \
  "$(colors_of "$O/still4/custom/still4_custom_1x.png")"

run "$FIX/still4.png" -p "112233 nope" -o "$WORK/x" >/dev/null 2>&1
check "inline: a bad token is an error, not a shorter palette" "1" "$?"

MONO="000000,555555,AAAAAA,FFFFFF"
O="$WORK/h1"; run "$FIX/still4.png" -p "#000,#555,#aaa,#fff" -o "$O" --formats apng >/dev/null
check "inline: #RGB expands to #RRGGBB" "$MONO" \
  "$(colors_of "$O/still4/custom/still4_custom_1x.png")"

O="$WORK/h2"; run "$FIX/still4.png" -p "000 555 aaa fff" -o "$O" --formats apng >/dev/null
check "inline: 3 digits need no '#' when you typed them" "$MONO" \
  "$(colors_of "$O/still4/custom/still4_custom_1x.png")"

O="$WORK/h3"; run "$FIX/still4.png" -p "#000f,#5558,#aaa4,#fff0" -o "$O" --formats apng >/dev/null
check "inline: #RGBA drops the alpha nibble" "$MONO" \
  "$(colors_of "$O/still4/custom/still4_custom_1x.png")"

O="$WORK/h4"; run "$FIX/still4.png" -p "#112233FF,#445566FF,#778899FF,#AABBCCFF" -o "$O" --formats apng >/dev/null
check "inline: #RRGGBBAA drops the trailing alpha" "$SET4" \
  "$(colors_of "$O/still4/custom/still4_custom_1x.png")"
O="$WORK/h5"; run "$FIX/still4.png" -p "FF112233,FF445566,FF778899,FFAABBCC" -o "$O" --formats apng >/dev/null
check "inline: bare AARRGGBB drops the leading alpha" "$SET4" \
  "$(colors_of "$O/still4/custom/still4_custom_1x.png")"

O="$WORK/h6"; run "$FIX/still4.png" -p "#000,555555,#aaa,FFFFFF" -o "$O" --formats apng >/dev/null
check "inline: shorthand and full form can be mixed" "$MONO" \
  "$(colors_of "$O/still4/custom/still4_custom_1x.png")"

run "$FIX/still4.png" -p "#00,#000" -o "$WORK/x" >/dev/null 2>&1
check "inline: two digits is not a color" "1" "$?"

printf '#000\n#555\n#aaa\n#fff\n' > "$PAL/short.hex"
O="$WORK/h7"; run "$FIX/still4.png" -p "@$PAL/short.hex" -o "$O" --formats apng >/dev/null
check "@file: #RGB shorthand expands" "$MONO" \
  "$(colors_of "$O/still4/short/still4_short_1x.png")"

printf '000\n555\naaa\nfff\n' > "$PAL/bare3.hex"
run "$FIX/still4.png" -p "@$PAL/bare3.hex" -o "$WORK/x" >/dev/null 2>&1
check "@file: bare 3-digit tokens are not colors" "1" "$?"
echo '{"height":300,"minWidth":404,"colors":["aabbcc","112233","778899","445566"]}' > "$PAL/n.json"
O="$WORK/h8"; run "$FIX/still4.png" -p "@$PAL/n.json" -o "$O" --formats apng >/dev/null
check "@file: numbers beside the colors stay out of the palette" "$SET4" \
  "$(colors_of "$O/still4/n/still4_n_1x.png")"

printf '#aabbcc\n#112233\n#778899\n#445566\n' > "$PAL/ramp.hex"
O="$WORK/p3"; run "$FIX/still4.png" -p "@$PAL/ramp.hex" -o "$O" --formats apng >/dev/null
check "@file: .hex, sorted darkest -> lightest" "$SET4" \
  "$(colors_of "$O/still4/ramp/still4_ramp_1x.png")"

{ echo "GIMP Palette"; echo "Name: Facade"; echo "#"
  echo " 17  34  51	Decade"; echo " 68  85 102	Beefed"
  echo "119 136 153	Faded";  echo "170 187 204	Accede"; } > "$PAL/g.gpl"
O="$WORK/p4"; run "$FIX/still4.png" -p "@$PAL/g.gpl" -o "$O" --formats apng >/dev/null
check "@file: .gpl decimals, color names not read as hex" "$SET4" \
  "$(colors_of "$O/still4/g/still4_g_1x.png")"

printf ';paint.net Palette File\n;Colors: 4\nFF112233\nFF445566\nFF778899\nFFAABBCC\n' > "$PAL/p.txt"
O="$WORK/p5"; run "$FIX/still4.png" -p "@$PAL/p.txt" -o "$O" --formats apng >/dev/null
check "@file: .txt AARRGGBB, ';' comments skipped" "$SET4" \
  "$(colors_of "$O/still4/p/still4_p_1x.png")"

O="$WORK/p6"
printf '#112233\n#445566\n#778899\n#AABBCC\n' | run "$FIX/still4.png" -p - -o "$O" --formats apng >/dev/null
check "stdin: a pasted color list" "$SET4" \
  "$(colors_of "$O/still4/pasted/still4_pasted_1x.png")"

run "$FIX/still4.png" -p "@$PAL/nope.hex" -o "$WORK/x" >/dev/null 2>&1
check "@file: a missing file is an error" "1" "$?"
: > "$PAL/empty.hex"
run "$FIX/still4.png" -p "@$PAL/empty.hex" -o "$WORK/x" >/dev/null 2>&1
check "@file: no colors in it is an error" "1" "$?"

LCACHE="$WORK/cache"; mkdir -p "$LCACHE/repixel/lospec"
echo '{"name":"Fake","author":"","colors":["aabbcc","112233","778899","445566"]}' \
  > "$LCACHE/repixel/lospec/repixel-test-fake.json"
O="$WORK/p7"
XDG_CACHE_HOME="$LCACHE" run "$FIX/still4.png" -p lospec:repixel-test-fake -o "$O" --formats apng >/dev/null
check "lospec: cached slug, sorted, own output folder" "$SET4" \
  "$(colors_of "$O/still4/repixel-test-fake/still4_repixel-test-fake_1x.png")"

O="$WORK/p8"
XDG_CACHE_HOME="$LCACHE" run "$FIX/still4.png" \
  -p https://lospec.com/palette-list/repixel-test-fake -o "$O" --formats apng >/dev/null
check "lospec: a full URL resolves to the same slug" "$SET4" \
  "$(colors_of "$O/still4/repixel-test-fake/still4_repixel-test-fake_1x.png")"

O="$WORK/p9"; run "$FIX/still4.png" -p "@$PAL/ramp.hex" --sort none -o "$O" --formats apng >/dev/null
check "--sort none keeps an import's own order" "AABBCC" \
  "$(magick "$O/still4/ramp/still4_ramp_1x.png" -crop 1x1+0+0 -depth 8 txt: \
     | grep -oiE '#[0-9A-F]{6}' | tr -d '#' | tr '[:lower:]' '[:upper:]')"
O="$WORK/p10"; run "$FIX/still4.png" -p "AABBCC,112233,778899,445566" --sort lum -o "$O" --formats apng >/dev/null
check "--sort lum reorders a typed list too" "112233" \
  "$(magick "$O/still4/custom/still4_custom_1x.png" -crop 1x1+0+0 -depth 8 txt: \
     | grep -oiE '#[0-9A-F]{6}' | tr -d '#' | tr '[:lower:]' '[:upper:]')"
run "$FIX/still4.png" -p mono --sort sideways -o "$WORK/x" >/dev/null 2>&1
check "unknown --sort is rejected" "1" "$?"

cat > "$PAL/loose.conf" <<'EOF'
loose = #112233 #445566 #778899 #aabbcc
EOF
O="$WORK/p11"
"$REPIXEL" --themes "$PAL/loose.conf" "$FIX/still4.png" -p loose -o "$O" --formats apng >/dev/null 2>&1
check "themes.conf: space-separated, '#'-prefixed line" "$SET4" \
  "$(colors_of "$O/still4/loose/still4_loose_1x.png")"

section "formats (ProRes is opt-in)"

O="$WORK/f1"; run "$FIX/anim.png" -p mono -o "$O" >/dev/null
VD="$O/anim/mono"
check "default omits the ProRes master" "no"  "$(hasglob "$VD/*_prores.mov")"
check "default includes mp4"            "yes" "$(hasglob "$VD/*.mp4")"
check "default includes apng"           "yes" "$(has "$VD/anim_mono_1x.png")"
if command -v img2webp >/dev/null 2>&1; then
  check "default includes webp"         "yes" "$(has "$VD/anim_mono_1x.webp")"
fi

O="$WORK/f2"; run "$FIX/anim.png" -p mono -o "$O" --formats all >/dev/null
check "--formats all adds ProRes" "yes" "$(hasglob "$O/anim/mono/*_prores.mov")"

O="$WORK/f3"; run "$FIX/anim.png" -p mono -o "$O" --formats mov >/dev/null
check "--formats mov gives the mov"       "yes" "$(hasglob "$O/anim/mono/*_prores.mov")"
check "--formats mov gives nothing else"  "no"  "$(hasglob "$O/anim/mono/*.mp4")"

O="$WORK/f4"; run "$FIX/anim.png" -p mono -o "$O" --formats png >/dev/null
check "--formats png is accepted as apng" "yes" "$(has "$O/anim/mono/anim_mono_1x.png")"

run "$FIX/still4.png" -p mono -o "$WORK/x" --formats nope >/dev/null 2>&1
check "unknown format is rejected" "1" "$?"
run "$FIX/still4.png" -p mono -o "$WORK/x" --fit sideways >/dev/null 2>&1
check "unknown --fit is rejected" "1" "$?"
run "$FIX/still4.png" -p mono -o "$WORK/x" -x 0 >/dev/null 2>&1
check "--scale 0 is rejected" "1" "$?"
OUT="$(run "$FIX/still4.png" --fit 2>&1)"
check "option without a value is rejected cleanly" \
  "yes" "$([[ "$OUT" == *"--fit needs a value"* ]] && echo yes || echo no)"

section "scale"

O="$WORK/s1"; run "$FIX/still4.png" -p mono -o "$O" --formats apng >/dev/null
check "auto keeps 16x on a small source" "yes" "$(has "$O/still4/mono/still4_mono_16x.png")"
check "auto 16x dimensions" "512x128" "$(dims_of "$O/still4/mono/still4_mono_16x.png")"

O="$WORK/s2"; run "$FIX/big.png" -p duo -o "$O" --formats apng >/dev/null
check "auto steps down on a 400px source (2560/400 -> 6x)" \
  "yes" "$(has "$O/big/duo/big_duo_6x.png")"
check "auto stays under --max-dim" "2400x2400" "$(dims_of "$O/big/duo/big_duo_6x.png")"

O="$WORK/s3"; run "$FIX/big.png" -p duo -o "$O" --max-dim 800 --formats apng >/dev/null
check "--max-dim 800 -> 2x" "yes" "$(has "$O/big/duo/big_duo_2x.png")"

O="$WORK/s4"; run "$FIX/still4.png" -p mono -o "$O" -x 3 --formats apng >/dev/null
check "explicit -x overrides auto" "96x24" "$(dims_of "$O/still4/mono/still4_mono_3x.png")"

O="$WORK/s5"; run "$FIX/still4.png" -p mono -o "$O" -x 1 --formats apng >/dev/null
check "-x 1 writes no upscaled copy" "no" "$(has "$O/still4/mono/still4_mono_1x_1x.png")"

section "max-shades guard"

OUT="$(run "$FIX/many.png" -p mono -o "$WORK/m1" --formats apng 2>&1)"; RC=$?
check "a gradient source is refused, not ground through" "1" "$RC"
check "the refusal names the limit" \
  "yes" "$([[ "$OUT" == *"distinct shades"* && "$OUT" == *"max-shades"* ]] && echo yes || echo no)"
OUT="$(run "$FIX/many.png" -p mono -o "$WORK/m2" --max-shades 300 --formats apng 2>&1)"
check "--max-shades raises the limit" \
  "yes" "$([[ "$OUT" != *"distinct shades"* ]] && echo yes || echo no)"

section "crop and split"

O="$WORK/c1"; run "$FIX/still4.png" -p mono -o "$O" -c 0,0,16,8 -x 2 --formats apng >/dev/null
check "crop applies before scaling" "32x16" "$(dims_of "$O/still4/mono/still4_mono_2x.png")"
check "crop narrows the shade set, and the palette refits" \
  "000000,FFFFFF" "$(colors_of "$O/still4/mono/still4_mono_1x.png")"

run "$FIX/still4.png" -p mono -o "$WORK/x" -c 0,0,999,999 >/dev/null 2>&1
check "an oversized crop on a single named source is fatal" "1" "$?"

O="$WORK/c2"; run "$FIX/anim.png" -p mono -o "$O" -s 2 --formats apng >/dev/null
check "split writes part1" "yes" "$(has "$O/anim/mono/anim_mono_1x_part1.png")"
check "split writes part2" "yes" "$(has "$O/anim/mono/anim_mono_1x_part2.png")"

section "output location"

O="$WORK/od"; OUT="$(run "$FIX/still4.png" -p mono -o "$O" --formats apng)"
check "the resolved absolute output path is printed" \
  "yes" "$([[ "$OUT" == *"output -> $O"* ]] && echo yes || echo no)"

section "info modes"

OUT="$(run "$FIX/still6.png" --list-colors)"
check "--list-colors works without -p" \
  "yes" "$([[ "$OUT" == *"6 shades"* ]] && echo yes || echo no)"
OUT="$(run --list-themes)"
check "--list-themes works with no input" \
  "yes" "$([[ "$OUT" == *"mono"* ]] && echo yes || echo no)"

section "gallery"

GDIR="$WORK/gallery"; mkdir -p "$GDIR"
GROWS=(); GN=0

strip() {
  local label="$1" fixture="$2" palette="$3"; shift 3
  local o="$GDIR/o$GN" out="$GDIR/r$GN.png"; GN=$((GN+1))
  run "$FIX/$fixture" -p "$palette" -o "$o" --formats apng "$@" >/dev/null
  local src; src="$(ls "$o"/*/*/*_1x.png 2>/dev/null | head -1)"
  [[ -n "$src" ]] || { no "gallery: nothing built for $label"; return 0; }
  magick "$src" -scale 1040x76! -bordercolor white -border 2 "$out.band.png"
  if [[ -n "$FONT" ]]; then
    magick -background white -fill '#222222' -font "$FONT" -pointsize 16 \
      label:"$label" -bordercolor white -border 5 "$out.lbl.png"
    magick "$out.lbl.png" "$out.band.png" -background white -gravity west \
      -append "$out"
  else
    mv "$out.band.png" "$out"
  fi
  rm -f "$out.band.png" "$out.lbl.png"
  GROWS+=("$out")
}

heading() {
  [[ -n "$FONT" ]] || return 0
  local out="$GDIR/h$GN.png"; GN=$((GN+1))
  magick -background white -fill black -font "$FONT" -pointsize 21 \
    label:"$1" -bordercolor white -border 10 "$out"
  GROWS+=("$out")
}

heading "Fitting: the 4-colour 'warm' palette onto N shades"
strip "2 shades  - palette larger, snaps to real palette colours" still2.png warm
strip "4 shades  - equal counts, palette verbatim (bit-exact)"    still4.png warm
strip "6 shades  - palette smaller, 2 blends inserted"            still6.png warm

heading "--mix: same palette, 6 shades, different blend space"
for sp in oklab oklch srgb linear; do
  strip "$sp" still6.png warm --mix "$sp"
done

heading "mono (4 colours) vs grayscale (2 colours), both on 6 shades"
strip "mono      - must hit 555555 and AAAAAA on the way"  still6.png mono
strip "grayscale - free to space evenly (oklab)"           still6.png grayscale
strip "grayscale --mix srgb"                               still6.png grayscale --mix srgb

magick "${GROWS[@]}" -background white -gravity west -append \
  -bordercolor white -border 22 "$GALLERY"
echo "  wrote $GALLERY  ($(magick identify -format '%wx%h' "$GALLERY"))"

printf '\n%s%d passed%s, %s%d failed%s\n' "$G" "$PASS" "$N" \
  "$( ((FAIL)) && echo "$R" || echo "$D")" "$FAIL" "$N"
(( KEEP )) && echo "outputs kept in $WORK"
exit $(( FAIL > 0 ))
