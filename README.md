# repixel

Recolor flat / pixel-art **images and animations** into themed variants and
export editable video (**ProRes** + **MP4**) plus web assets (**APNG/PNG** +
**WebP**), upscaled with nearest-neighbor so the pixels stay perfectly crisp —
no blur, no quality loss.

It works on any file, anywhere. Point it at something on your Desktop and the
results land in `./out`:

```bash
repixel ~/Desktop/logo.png -p dithernaut
```

Nothing is processed unless you name it — there is no magic input directory.

## Install

```bash
brew install dithernaut/tap/repixel
```

That pulls in the three tools repixel shells out to — `ffmpeg`, `imagemagick`
and `webp` — so there's nothing else to set up.

<details>
<summary>Running from a clone instead</summary>

Install the dependencies yourself:

```bash
brew install ffmpeg imagemagick webp
```

`webp` provides `img2webp` and `cwebp`. Most ffmpeg and ImageMagick builds ship
the WebP *muxer* but no encoder, so WebP output goes through libwebp instead. If
those tools are missing, repixel says so and builds every other format.

Then put the script on your `PATH`:

```bash
ln -s "$PWD/repixel" /usr/local/bin/repixel
```

Symlinks are resolved before `themes.conf` is looked up, so this works.

</details>

The Homebrew formula lives in its own repo,
[dithernaut/homebrew-tap](https://github.com/dithernaut/homebrew-tap).

## Usage

```bash
repixel logo.png -p dithernaut            # one file, one theme
repixel a.png b.gif ~/sprites -p mono     # several inputs at once
repixel ~/Desktop/sprites -p mono         # every image directly in a folder
repixel ~/Desktop/sprites -r -p mono      # ...and everything below it
repixel logo.png -A                       # every theme in themes.conf
repixel logo.png -p 171F41,2F7077,FB6C76,FEEDE3   # one-off colors
repixel logo.png -p lospec:nyx8           # any palette on lospec.com
repixel logo.png -p @nyx8.hex             # a downloaded palette file
pbpaste | repixel logo.png -p -           # a color list copied from anywhere
repixel logo.png -p mono -x 8 -o ~/out    # scale 8x, custom output directory
repixel clip.png -p mono --formats all    # include the ProRes master
repixel clip.png -p mono -c 2,2,100,100   # crop a 98x98 box, then build
repixel clip.png -p mono -s 157           # split at frame 157 -> 2 parts
repixel clip.png -p mono -s 50,120        # split into 3 parts
repixel --list-themes                     # show themes
repixel logo.png --list-colors            # show a source's shades
```

| Option | |
|---|---|
| `-p, --palette PAL` | theme name, hex list, `@file`, `-` (stdin) or `lospec:slug` — **required**, unless `-A` |
| `-A, --all-themes` | build every theme in the theme file |
| `--fit MODE` | how a palette adapts to a source's shade count: `auto` (default), `nearest`, `ramp`, `exact` |
| `--mix SPACE` | space in-between colors are blended in: `oklab` (default), `oklch`, `srgb`, `linear` |
| `--sort MODE` | reorder a palette darkest → lightest: `auto` (default, imports only), `lum`, `none` |
| `-o, --out DIR` | output directory (default `./out`, relative to the current directory) |
| `-r, --recursive` | recurse into directory inputs |
| `-c, --crop BOX` | `XSTART,YSTART,XEND,YEND`, applied before everything else |
| `-s, --split FRAMES` | comma-separated frame(s) to cut each clip at |
| `-x, --scale N` | integer upscale factor, or `auto` (default) |
| `--max-dim N` | ceiling for `auto` scale, long edge (default 2560) |
| `-f, --fps N` | frames per second (default 12) |
| `--formats LIST` | any of `mov,mp4,apng,webp`, or `all` (default `apng,webp,mp4`) |
| `--max-shades N` | refuse a source with more than N shades (default 64) |
| `--themes FILE` | use a different theme file |
| `--reextract` | force re-extraction of source frames |

> `-c` is **crop**. The palette flag is `-p`/`--palette`; `-t`, `--theme` and
> `--colors` are all the same flag, kept so old commands keep working.

### Output goes to `./out`, wherever you are

`-o` defaults to `./out` **relative to the directory you run from**, not to the
directory the source lives in. `repixel ~/Desktop/logo.png -p mono` writes into
`$PWD/out`, never next to your original. A batch gathered from several places
therefore lands in one predictable spot. The resolved absolute path is printed
at the start and end of every run, so there's never a question of where things
went.

### Inputs

Pass **files**, **directories**, or a mix. A directory contributes the
`.png` / `.apng` / `.gif` / `.webp` files directly inside it; add `-r` to walk
the whole tree. Files you name explicitly are never filtered by extension — if
you point at it, you meant it. Anything already inside the output directory is
skipped, so re-running `repixel . -r` in a folder you've built into won't feed
the results back in.

Two inputs with the same basename would share one output folder; repixel warns
when that happens.

### Stills vs animations

repixel detects this from the file — you don't pass a flag.

- **Animated** input (APNG, GIF, animated WebP) → MP4, APNG, WebP — plus ProRes
  if you ask for it with `--formats mov` or `--formats all`.
- **Single-frame** input (an ordinary PNG) → PNG and WebP stills. `mov`/`mp4`
  are skipped with a note, and `--split` is ignored.

Everything else — recoloring, cropping, nearest-neighbor upscaling, theme
matching — is identical either way.

### Palettes

**`-p` takes colors from wherever you have them.** One flag for every form, so
there's no precedence to remember; if you pass it twice, the last one wins.

| `-p …` | |
|---|---|
| `dithernaut-alt` | a theme in `themes.conf` |
| `171F41,2F7077,…` | colors darkest → lightest. Commas, spaces or newlines; `#` optional |
| `#000,#555,#aaa,#fff` | CSS shorthand — each digit is doubled, so this is `mono` |
| `@nyx8.hex` | a palette file — `.hex`, `.gpl` (GIMP), `.txt` (Paint.NET), `.json`, or any text with hex colors in it |
| `-` | the same, read from stdin: `pbpaste \| repixel logo.png -p -` |
| `lospec:nyx8` | fetched from [lospec.com](https://lospec.com/palette-list) and cached. A full palette-list URL works too |

Names are matched against `themes.conf` first, so a theme always wins. Anything
that is neither a known theme nor a valid palette is an error — a mistyped
color fails loudly rather than quietly shortening the palette.

**Color forms.** `RRGGBB`, `#RRGGBB`, `0xRRGGBB`, and CSS shorthand `#RGB` /
`#RGBA` (each digit doubled, alpha dropped) — so `-p "#000,#555,#aaa,#fff"` is
`mono`. Alpha is always dropped, never applied: repixel recolors opaque flat
art. Eight digits are the one ambiguous case, and the `#` decides: `#RRGGBBAA`
is CSS with alpha last, bare `AARRGGBB` is Paint.NET's `.txt` with alpha first.
In a **file**, shorthand needs its `#` — a bare `300` in some file is far more
likely to be a number than a request for `#330000`. In a list you typed, `000`
is fine, since nothing else could be meant. A named theme
lands in `<out>/<source>/<theme>/`, a lospec palette or a file under its own
name, a typed-in list under `custom/`.

**Pasted palettes are re-sorted darkest → lightest.** Palettes in the wild are
stored in the artist's working order — lospec's `nyx8` is unsorted and its
`oil-6` is lightest-first — while repixel maps shade *i* onto palette entry *i*.
So imports get luminance-sorted on the way in. `themes.conf` and a list you
typed yourself are trusted as written, since both are documented as
darkest → lightest. `--sort lum` sorts those too; `--sort none` turns it off
everywhere.

**Big, hue-rich palettes are the one thing this doesn't do well.** repixel
picks a color by *where it sits in the value ramp*, so the popular 30–60 color
lospec palettes (`resurrect-64`, `apollo`, `endesga-32`) — which are chosen for
hue variety, with many colors sharing a value — collapse to four fairly
arbitrary hues on a 4-shade logo. They'll load and build; they just won't look
like the palette. Value ramps are what works, which is what the bundled lospec
themes are.

**A palette is required.** Building every theme used to be the default, which
meant a bare run encoded N themes × every format before you'd decided anything.
Pass `-A` when you actually want them all. Forgetting `-p` prints the list of
themes rather than guessing.

### Fitting: palettes and shade counts don't have to match

A palette rarely has exactly as many colors as your source has shades, and
until you know the shade count you can't tell which of your themes will apply.
`--fit` makes every palette usable on every source:

| | |
|---|---|
| **equal counts** | palette used verbatim, position for position — bit-exact |
| **palette larger** than the source's shade count | each shade snaps to its **nearest** palette entry, so every output color is a real palette color |
| **palette smaller** | every palette color still appears, and the missing steps are mixed in **Oklab** and inserted into whichever gaps are perceptually widest |

So a 4-color theme on a 2-shade source gives you the darkest **and** the
lightest — not the two darkest, which would be mud with no contrast. A 20-color
palette on a 4-shade source picks four colors that are genuinely in the palette.
And a 4-color theme on a 6-shade source keeps all four of its colors and
invents only the two in-between steps it actually needs:

```
palette   171F41 ──── 2F7077 ──── FB6C76 ──── FEEDE3
                          └ widest gaps get the new steps ┘

6 shades  171F41  2F7077  A17578  FB6C76  FFAFAC  FEEDE3
                          ^mixed          ^mixed
```

Positions that land exactly on a palette entry are snapped, so floating point
never shifts a color by a stray 1/255.

### `--mix`: which space the blends happen in

Only the **palette smaller** case blends at all — the other two reuse colors
that are already in the palette — so `--mix` does nothing unless a palette is
being stretched. Where the extra steps *go* is always decided in Oklab, so
`--mix` changes their values, never their placement.

| | |
|---|---|
| `oklab` | **default.** Perceptually uniform, straight line. No failure modes. |
| `oklch` | Oklab in polar form, so chroma stays up across a hue change instead of dipping through a desaturated middle. Better between colors *close* in hue; see the warning below. |
| `srgb` | Naive interpolation of the hex values. Reproduces classic ramps exactly. |
| `linear` | Physically correct light mixing. Midtones come out brighter than they look. |

Stretching `000000, FFFFFF` across 4 shades:

| `--mix` | | | | |
|---|---|---|---|---|
| `oklab` | `000000` | `363636` | `949494` | `FFFFFF` |
| `srgb` | `000000` | `555555` | `AAAAAA` | `FFFFFF` |
| `linear` | `000000` | `9C9C9C` | `D5D5D5` | `FFFFFF` |

Note the middle row: `-p grayscale --mix srgb` reproduces the four-gray `mono`
theme **exactly**. Grays have no chroma, so `oklch` is identical to `oklab` here.

> **Why `oklch` isn't the default.** Preserving chroma along a hue *arc* is only
> a good idea when the two colors are near each other in hue. Stretching
> `dithernaut` to 6 shades has to blend its teal `2F7077` into its coral
> `FB6C76` — nearly a 180° swing — and `oklch` comes back with **`8474C5`, a
> vivid violet** that has nothing to do with the palette. `oklab` gives the
> restrained `A17578` instead. Reach for `oklch` when your palette's steps are
> hue-adjacent and Oklab is coming out chalky.

Override the automatic choice with `--fit nearest` (never invent a color, but
two shades can collapse onto one — repixel says so when it happens), `--fit ramp`
(always sample the gradient uniformly, which drops interior palette colors), or
`--fit exact` (the original behavior: skip unless the counts match exactly).

`--max-shades` (default 64) refuses sources that aren't flat art. A photograph
has thousands of colors and would spend hours in the recolor step.

### Cropping

`-c XSTART,YSTART,XEND,YEND` crops every frame *before anything else happens*,
so shade detection, recoloring, scaling and all output formats work on the
cropped region. Bounds are **half-open** (XEND/YEND exclusive), so
`-c 2,2,100,100` gives a **98×98** box at offset 2,2.

A crop that doesn't fit is a hard error when you named a single source
explicitly, and a skip-with-note when running a batch (so mixed-size sources
still build). Cropping makes odd dimensions likely; H.264 needs even ones, so an
odd result skips the `.mp4` with a note rather than distorting the art — ProRes,
APNG and WebP are unaffected.

### Splitting

`-s FRAME[,FRAME...]` cuts each clip at those exact frames. `-s 157` → part 1 =
frames 1–157, part 2 = 158–end; `-s 50,120` → 3 parts. Parts are written as
`..._partN.<ext>`.

## Output

Files land in `<out>/<source>/<theme>/`, e.g.
`out/font-scaling/dithernaut/font-scaling_dithernaut_2032x1200_prores.mov`.

| File | What |
|---|---|
| `..._<WxH>_prores.mov` | ProRes 4444, upscaled — for Final Cut (animations only) |
| `..._<WxH>.mp4` | H.264 preview, upscaled (animations only) |
| `..._1x.png` | native resolution — APNG if animated, PNG if still |
| `..._<S>x.png` | same at the `--scale` factor (skipped when scale is 1) |
| `..._1x.webp` | native resolution WebP |
| `..._<S>x.webp` | WebP at the `--scale` factor |

### Which formats you get, and what they cost

The default is **`apng,webp,mp4`**. ProRes is deliberately opt-in: on a typical
clip it is around **95% of the output bytes** and most of the encode time, and
it's only wanted when the result is actually going into an editor. For one
108×108, 132-frame source:

| | |
|---|---|
| `_prores.mov` | **6.7 MB** |
| everything else combined | **~300 KB** |

Add it with `--formats mov`, or take the lot with `--formats all`. `--formats`
also accepts `png` as a spelling of `apng`, and rejects anything it doesn't
recognise rather than silently producing nothing.

### Scale

`-x` defaults to **`auto`**: the historical 16× unless that would push the long
edge past `--max-dim` (2560), in which case it steps down. A 108px sprite still
gets 1728. A 2000px source gets 1× instead of a 32000px file that exceeds
WebP's 16383px limit and that no encoder wants. Pass `-x N` to force an exact
factor.

**APNG/PNG vs WebP** — both are lossless and pixel-identical; WebP is just a lot
smaller (roughly 2× at 1x, 5×+ at 16x for animations, since it coalesces
repeated frames into longer durations instead of restoring them). Serve the
**1x** file and let CSS scale it for a pixel-perfect result at any size:

```css
img { image-rendering: pixelated; width: 100%; }
```

The `<S>x` files are there for contexts that won't do nearest-neighbor scaling
for you. WebP animation is supported in every current browser; if you need to
support something ancient, `<picture>` with the APNG as fallback covers it.

## Themes

Themes live in [`themes.conf`](themes.conf), one per line, colors listed
**darkest → lightest** (they map positionally onto the source's shades):

```
dithernaut = 171F41, 2F7077, FB6C76, FEEDE3
mono       = 000000, 555555, AAAAAA, FFFFFF
grayscale  = 000000, FFFFFF
```

`mono` and `grayscale` are the same idea written two ways, and are worth
comparing. `mono` is the classic four-gray Macintosh ramp — those exact values,
always present. `grayscale` is just its endpoints, so it adapts to any shade
count with a perceptually even ramp, which `mono` can't do without also hitting
`555555` and `AAAAAA` on the way. Neither is better; a two-color palette is
simply a legitimate thing to write now.

Separators are free-form — commas, spaces, or both — and `#` is optional, so a
list copied from somewhere else can be pasted in as-is.

A dozen popular [lospec](https://lospec.com/palette-list) palettes ship
alongside the originals: `1bit-monitor-glow`, `2bit-demichrome`,
`kirokaze-gameboy`, `ice-cream-gb`, `mist-gb`, `rustic-gb`, `hollow`, `oil-6`,
`nyx8`, `slso8`, `ammo-8`, `citrink`. They're the ones that are clean value
ramps, which is what lands well on flat art; each one's author is credited on
its lospec page. Anything else on the site is one `-p lospec:slug` away.

Add a theme by copying a line and changing the name + colors. The count does
**not** have to match the source's shade count — see
[Fitting](#fitting-palettes-and-shade-counts-dont-have-to-match). Run
`repixel <file> --list-colors` to see a source's shades.

Without `--themes FILE`, the first of these that exists wins:

1. `~/.config/repixel/themes.conf` — your own themes
2. `themes.conf` beside the script — a git checkout run in place
3. `../share/repixel/themes.conf` — an installed copy (Homebrew's `pkgshare`)

`--list-themes` prints which file it's using. If you install repixel through a
package manager, keep your themes in **(1)**: the installed copy is replaced on
every upgrade. Use `--themes FILE` for a per-project palette file.

## How it works

1. Extracts the source to frames, cached in `~/.cache/repixel` (keyed by full
   path, and re-extracted automatically when the file changes).
2. Crops them, if `--crop` was given.
3. Detects the source's flat colors, sorted darkest → lightest.
4. Maps each shade to the theme color at the same position, via a sentinel
   color so overlapping source/target values can't collide.
5. Upscales ×`SCALE` with nearest-neighbor and encodes each requested format.

Steps 4 and 5 are pixel-exact: sources are promoted to sRGB TrueColor before
any fill (grayscale sources would otherwise collapse every fill to its gray
value), frames are converted to RGBA before scaling (swscale rounds pal8→RGB
by ±1, which would shift theme colors), and integer nearest-neighbor scaling
replicates pixels rather than resampling. Theme colors come out bit-exact.

## Repository layout

```
repixel                 # the script — put it on your PATH
themes.conf             # named color themes (edit me)
test/run.sh             # the test suite
src/                    # local scratch for sources (git-ignored)
out/                    # default output directory (git-ignored)
```

`src/` and `out/` are only a convenience for working inside this repo; repixel
has no attachment to either. The frame cache lives in `~/.cache/repixel` and is
safe to delete at any time.

## Development

```bash
test/run.sh             # generate fixtures, run every check, clean up
test/run.sh --keep      # leave the built output in test/work/ to look at
```

The suite generates its own fixtures rather than committing binaries: flat
images with an exactly known number of shades (2, 4, 6), an oversized source,
a 256-step gradient, and a small animation. That's the point — nearly every
assertion is about repixel reproducing **specific hex values bit-exactly**, so
the inputs have to be exact too. It covers palette fitting in every shape,
`-p` being required, format and scale selection, the `--max-shades` guard,
cropping, splitting, and the argument validation.

`--keep` is the quickest way to eyeball a change: it leaves real recolored
output in `test/work/` without touching `src/` or `out/`.
