# Progress

## Repository setup (2026-09-20)
- Original (upstream, read-only): https://github.com/glitchreal/Dungeon-quest
- Autotest (origin): https://github.com/glitchreal/Dungeon-quest-autotest
- Visibility: PRIVATE
- Local branch: main @ fc256b9ae819547d7937f0691b51bf7820bb22c9
- Verified: origin/main == upstream/main == local HEAD at setup time.
- Remote policy:
  - `origin` = autotest repo (fetch + push). All future commits/pushes target ONLY origin.
  - `upstream` = original repo (fetch only, push disabled via `no_push`).
  - `remote.pushDefault` = origin.
- Rule: never push to upstream. Never commit credentials, private server links, webhook URLs, logs with secrets, or sensitive executor config.
