# AGENTS.md

- Speak terse, smart caveman. Keep technical precision; code and user-facing copy stay normal.
- Read `README.md` for behavior. Read `./repixel` for implementation and CLI contract. Avoid duplicating either here.
- Project is one strict-mode Bash CLI plus `themes.conf`. Quote paths; preserve macOS/Linux tool compatibility.
- Pixel output is contract: nearest-neighbor scaling and palette colors must remain bit-exact.
- Add comments only when the code cannot make a necessary constraint evident. Never narrate, restate, label sections, or preserve historical context in comments.
- Write documentation for the current behavior only. Never preserve transition history such as “previously mandatory, now optional.”
- Run `test/run.sh` after changes. Use `--keep` for visual inspection; use `--regen` only when intentionally changing committed fixtures.
- CLI changes require matching tests plus updates to `repixel` help header and `README.md`.
- Do not edit generated `out/`, cache, or `test/work/`. Never stage, commit, or push.
