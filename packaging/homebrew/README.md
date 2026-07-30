# Publishing repixel to Homebrew

Homebrew is the distribution channel that actually solves repixel's problem:
a formula declares `ffmpeg`, `imagemagick` and `webp` as dependencies, and
`brew install` pulls them in. One command, no README full of prerequisites.

You do **not** need Homebrew's approval for any of this. A personal tap is just
a GitHub repository with a naming convention.

## Concepts, briefly

| Term | What it is |
|---|---|
| **Formula** | A Ruby file describing how to install one program |
| **Tap** | A GitHub repo full of formulas. Yours is `homebrew-tap` |
| **`pkgshare`** | `$(brew --prefix)/share/repixel` — where a formula puts support files (repixel's `themes.conf`) |
| **Bottle** | A prebuilt binary. Irrelevant here: repixel is a shell script, so there's nothing to compile |

The `homebrew-` prefix on the tap repo is required and invisible in use:
a repo named `homebrew-tap` under user `dithernaut` is installed from as
`dithernaut/tap`.

## One-time setup

### 1. Tag a release in the repixel repo

The formula downloads a fixed tarball, so it needs a tag to point at.

```bash
git tag v0.1.0
git push origin v0.1.0
```

GitHub then serves the tarball automatically at
`https://github.com/dithernaut/repixel/archive/refs/tags/v0.1.0.tar.gz`.

### 2. Get its checksum

```bash
curl -sL https://github.com/dithernaut/repixel/archive/refs/tags/v0.1.0.tar.gz \
  | shasum -a 256
```

### 3. Create the tap repo

A new, empty GitHub repo named exactly `homebrew-tap`. Then:

```bash
git clone https://github.com/dithernaut/homebrew-tap
cd homebrew-tap
mkdir -p Formula
cp /path/to/repixel/packaging/homebrew/repixel.rb Formula/
```

Edit `Formula/repixel.rb`: fill in the `sha256` from step 2, and bump the `url`
if you tagged a different version. Set the `license` to whatever you actually
license it under (the formula assumes MIT — add a `LICENSE` file to the repixel
repo to match, or change both).

### 4. Test it before anyone else sees it

Install straight from the local file — no tap, no push, fast to iterate on:

```bash
brew install --formula ./Formula/repixel.rb
brew test repixel
```

`brew test` runs the `test do` block — it builds a two-shade image, recolors it,
and asserts the output file exists. To retry after an edit, `brew uninstall
repixel` first.

Once it's pushed and tappable, `brew audit` checks formula style:

```bash
brew audit --strict --online dithernaut/tap/repixel
```

None of this is optional if you want the formula to work on someone else's
machine.

Then verify the real thing:

```bash
which repixel                 # should be in $(brew --prefix)/bin
repixel --list-themes         # should print the pkgshare path
```

That second command is the one that proves `pkgshare` wiring worked. If it
prints a path under `share/repixel/`, you're done.

### 5. Push

```bash
git add Formula/repixel.rb
git commit -m "repixel 0.1.0"
git push
```

Users now install with:

```bash
brew install dithernaut/tap/repixel
```

No `brew tap` step needed first — the three-part name taps implicitly.

## Shipping an update

```bash
# in the repixel repo
git tag v0.2.0 && git push origin v0.2.0

# in the tap repo: bump url + sha256 in Formula/repixel.rb, then
git commit -am "repixel 0.2.0" && git push
```

Users get it with `brew upgrade`.

## Testing without tagging

While iterating, a `head` line lets you install straight from a branch:

```ruby
head "https://github.com/dithernaut/repixel.git", branch: "main"
```

Then `brew install --HEAD dithernaut/tap/repixel`. Keep the tagged `url` as well —
`--HEAD` is opt-in.

## About homebrew-core

Getting into core (so `brew install repixel` works with no tap prefix) requires
notability — roughly 50 GitHub stars, 30 forks, or 30 watchers, plus a
maintainer review. Not worth chasing up front. A tap works identically for
users, minus the prefix.

## The themes.conf upgrade trap

`pkgshare.install "themes.conf"` means the bundled themes are **replaced on
every upgrade**. Anyone who edits that file loses their work.

repixel handles this: it prefers `~/.config/repixel/themes.conf` when it exists,
and the formula's `caveats` block tells users to copy it there. If you change
the lookup order in the script, update the caveats to match.
