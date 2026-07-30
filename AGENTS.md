# AGENTS.md

- Speak terse, smart caveman. Keep technical precision; code and user-facing copy stay normal.
- Read `README.md` for behavior. Read `./repixel` for implementation and CLI contract. Avoid duplicating either here.
- Project is one strict-mode Bash CLI plus `themes.conf`. Quote paths; preserve macOS/Linux tool compatibility.
- Pixel output is contract: nearest-neighbor scaling and palette colors must remain bit-exact.
- Run `test/run.sh` after changes. Use `--keep` for visual inspection; use `--regen` only when intentionally changing committed fixtures.
- CLI changes require matching tests plus updates to `repixel` help header and `README.md`.
- Do not edit generated `out/`, cache, or `test/work/`. Never stage, commit, or push.
