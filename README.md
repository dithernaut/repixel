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
repixel logo.png                          # one file, every theme
repixel a.png b.gif ~/Desktop/sprites     # several inputs at once
repixel ~/Desktop/sprites                 # every image directly in a folder
repixel ~/Desktop/sprites -r              # ...and everything below it
repixel logo.png -p dithernaut            # one theme
repixel logo.png -p 171F41,2F7077,FB6C76,FEEDE3   # one-off colors
repixel logo.png -x 8 -o ~/Desktop/out    # scale 8x, custom output directory
repixel clip.png -c 2,2,100,100           # crop a 98x98 box, then build
repixel clip.png -s 157                   # split at frame 157 -> 2 parts
repixel clip.png -s 50,120                # split into 3 parts
repixel --list-themes                     # show themes
repixel logo.png --list-colors            # show a source's shades
```

| Option | |
|---|---|
| `-p, --palette PAL` | theme name **or** comma-separated hex list (default: every theme) |
| `-o, --out DIR` | output directory (default `./out`) |
| `-r, --recursive` | recurse into directory inputs |
| `-c, --crop BOX` | `XSTART,YSTART,XEND,YEND`, applied before everything else |
| `-s, --split FRAMES` | comma-separated frame(s) to cut each clip at |
| `-x, --scale N` | integer upscale factor (default 16) |
| `-f, --fps N` | frames per second (default 12) |
| `--formats LIST` | any of `mov,mp4,apng,webp` (default: all four) |
| `--themes FILE` | use a different theme file |
| `--reextract` | force re-extraction of source frames |

> `-c` is **crop**. The palette flag is `-p`/`--palette`; `-t`, `--theme` and
> `--colors` are all the same flag, kept so old commands keep working.

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

- **Animated** input (APNG, GIF, animated WebP) → ProRes, MP4, APNG, WebP.
- **Single-frame** input (an ordinary PNG) → PNG and WebP stills. `mov`/`mp4`
  are skipped with a note, and `--split` is ignored.

Everything else — recoloring, cropping, nearest-neighbor upscaling, theme
matching — is identical either way.

### Palettes

**`-p` takes either form** — the name of a theme in `themes.conf`
(`-p dithernaut-alt`) or a one-off comma-separated hex list
(`-p 171F41,2F7077,…`, with or without `#`). One flag either way, so there's no
precedence to remember; if you pass it twice, the last one wins. Names are
matched against `themes.conf` first, and anything that's neither a known theme
nor valid hex is an error. A named theme lands in `<out>/<source>/<theme>/`, a
hex list in `<out>/<source>/custom/`. Omit it entirely to build every theme.

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

A theme whose color count doesn't match a source's number of shades is
**skipped with a note** — the rest of the batch still runs.

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
```

Add a theme by copying a line and changing the name + colors. The number of
colors must match the number of shades in the source — run
`repixel <file> --list-colors` to see them.

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
src/                    # local scratch for sources (git-ignored)
out/                    # default output directory (git-ignored)
```

`src/` and `out/` are only a convenience for working inside this repo; repixel
has no attachment to either. The frame cache lives in `~/.cache/repixel` and is
safe to delete at any time.
