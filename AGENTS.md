## Agent skills

### Issue tracker
GitHub Issues (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels
Default vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs
Single-context: `GLOSSARY.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.

## Shell commands

This shell is zsh, which kills a whole command on an unquoted glob: `grep -r --include=*.md .` aborts with `no matches found`, and `echo ===` aborts with `== not found`. Search with `rg 'pattern' -g '*.md' .` and quote separators (`echo "---"`); otherwise a failed command reads like an empty result.

## Run the app

`scripts/app.sh` builds and opens `Orrery.app`. Notification banners, `orrery://` links and `.orreryboard` double-click only exist inside that bundle; `swift run` shows none of them.
