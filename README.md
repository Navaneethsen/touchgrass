# touchgrass 🌱

A single-file Python script that watches your AI coding agents
(Claude, opencode, Copilot CLI, codex, aider, cursor-agent, etc.),
distinguishes **ACTIVE** vs merely **alive** processes, and gently
reminds you to go outside.

> _Inspired by Adam (opencode) on TheStandup: "maybe take a break?" —
> the old Wii popup, for the model age._

100% local. stdlib-only Python. macOS-first (uses `ps`, `lsof`,
`ioreg`, `pmset`, `osascript`, `launchd`). No prompts or file
contents are ever read — only process metadata and file mtimes.

---

## Where things live

| Path | What |
|---|---|
| `~/.touchgrass/bin/touchgrass` | **The source.** Single Python file (~900 lines). |
| `/opt/homebrew/bin/touchgrass` | Symlink so `touchgrass` is on your PATH. |
| `~/.touchgrass/data/touchgrass.sqlite` | Time-series DB of samples + verdicts. |
| `~/.touchgrass/data/watch.log` | Background daemon log. |
| `~/.touchgrass/config.json` | Your overrides (only the keys you want to change). |
| `~/.touchgrass/shims/` | Optional friction shims for `claude`, `opencode`, etc. |
| `~/Library/LaunchAgents/com.touchgrass.watch.plist` | The launchd job. |
| `~/.touchgrass/README.md` | This file. |

Open the source in your editor:

```sh
$EDITOR ~/.touchgrass/bin/touchgrass
```

---

## Install (on a fresh machine)

```sh
mkdir -p ~/.touchgrass/bin
cp <source>/touchgrass ~/.touchgrass/bin/touchgrass
chmod +x ~/.touchgrass/bin/touchgrass

# put on PATH (homebrew users)
ln -s ~/.touchgrass/bin/touchgrass /opt/homebrew/bin/touchgrass
# OR add ~/.touchgrass/bin to PATH in ~/.zshrc

# start the background sampler (every 60s)
touchgrass init

# verify
touchgrass doctor
```

Requirements: macOS, Python 3.9+, command-line tools `ps`, `lsof`,
`ioreg`, `pmset`, `osascript`, `launchctl` (all standard).

---

## Daily use

```sh
touchgrass live          # snapshot of every AI agent right now
touchgrass today         # active vs alive hours, peak concurrency, top repos
touchgrass week          # same, last 7 days
touchgrass tail          # last 20 verdicts (the popups it fired)
touchgrass kill-stale    # list forgotten idle agents (add --kill to SIGTERM)
touchgrass status        # daemon + DB health
touchgrass doctor        # self-test + send a test notification
```

`touchgrass live` output:

```
TOOL          PID      ETIME   CPUTIME   %CPU  RSS(MB) STATE   WHY        CWD
copilot      98554   0:52:09   538.4    42.3   350.8   ACTIVE  cpu,pcpu   /Users/senn1
copilot      78873  86:35:43  2166.9     0.0   141.2   idle    -          /Users/senn1/github/platform
```

`STATE` rules:

- **ACTIVE** if any of: CPU delta ≥ 1s since last sample, %CPU ≥ 2,
  or this pid personally has a session file mtime'd within 2 min.
- **idle** otherwise — the process exists but isn't doing anything.

### v3 commands

```sh
touchgrass wakes [--days 7]              # pmset wake events × AI activity
touchgrass digest [--days 7] [--out FILE]# weekly markdown report (paste into Notion/Obsidian)
touchgrass shim install                  # friction wrappers (default: claude opencode copilot codex aider)
touchgrass shim list
touchgrass shim uninstall
```

To activate the **friction shim** (asks _"continue? [y/N]"_ when
you've already burned more than `daily_active_hours` today):

```sh
touchgrass shim install
echo 'export PATH="$HOME/.touchgrass/shims:$PATH"' >> ~/.zshrc
# new shell:
which claude    # → ~/.touchgrass/shims/claude
```

Bypass per-launch:

```sh
TOUCHGRASS_FORCE=1 claude        # or:  claude --force
```

---

## Modify / configure

```sh
touchgrass config --show
touchgrass config --edit         # opens ~/.touchgrass/config.json in $EDITOR
touchgrass config --reset        # deletes overrides, back to defaults
```

Available keys (only override what you need):

```json
{
  "sample_interval_s":   60,
  "active_cpu_delta_s":  1.0,
  "active_cpu_pct":      2.0,
  "active_file_window_s": 120,
  "concurrent_threshold": 4,
  "long_active_hours":    6,
  "forgotten_alive_h":   24,
  "forgotten_idle_h":     6,
  "night_start_hour":     0,
  "night_end_hour":       6,
  "daily_active_hours":   6,
  "active_streak_days":   7,
  "notify_cooldown_s":  1800,
  "ignored_tools":       ["copilot-lsp"],
  "hid_idle_skip_s":     900
}
```

Verdict rules (fire macOS notifications):

| rule | meaning |
|---|---|
| `concurrent_agents` | ≥ `concurrent_threshold` ACTIVE agents at once |
| `long_run` | one agent ACTIVE > `long_active_hours` cumulative |
| `forgotten_session` | agent alive > `forgotten_alive_h`, idle > `forgotten_idle_h` |
| `night_use` | ACTIVE during `night_start_hour`–`night_end_hour` local |
| `daily_overuse` | total ACTIVE today > `daily_active_hours` |
| `active_streak` | ACTIVE on > `active_streak_days` consecutive days |

To change the **list of tools watched** or the **exclusion regex**,
edit the script directly (it's deliberately one file):

```sh
$EDITOR ~/.touchgrass/bin/touchgrass
# look for AI_PATTERNS and EXCLUDE near the top
```

No rebuild step — next sample picks up the changes.

First time a notification fires, macOS will prompt you to allow
"Script Editor" in **System Settings → Notifications**.

---

## Uninstall

Full removal:

```sh
touchgrass shim uninstall                            # remove friction wrappers
touchgrass stop                                      # unload launchd job
rm  /opt/homebrew/bin/touchgrass                     # remove PATH symlink
rm  ~/Library/LaunchAgents/com.touchgrass.watch.plist
rm -rf ~/.touchgrass                                 # bin, data, config, shims, README

# and (if you added it) remove the shim PATH line from ~/.zshrc
sed -i '' '/\.touchgrass\/shims/d' ~/.zshrc
```

Partial — stop the background daemon but keep the CLI:

```sh
touchgrass stop
```

Partial — disable friction only:

```sh
touchgrass shim uninstall
# then remove the PATH line from your shell rc file
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `touchgrass: command not found` | `ls -la /opt/homebrew/bin/touchgrass`; re-link with `ln -s ~/.touchgrass/bin/touchgrass /opt/homebrew/bin/touchgrass` |
| `touchgrass doctor` says launchd not loaded | `touchgrass init` |
| Notifications never appear | System Settings → Notifications → enable for **Script Editor** |
| Daemon not sampling | `tail ~/.touchgrass/data/watch.log` then `touchgrass stop && touchgrass init` |
| Schema error after upgrade | Migrations are automatic; if it ever fails, back up & delete `~/.touchgrass/data/touchgrass.sqlite` and re-run `touchgrass sample` |
| Wrong process flagged ACTIVE | Lower `active_file_window_s` or add the binary's name to the `EXCLUDE` regex in the source |

---

## License

Personal tool. Do whatever you want with it.

— built with the Copilot CLI in a single session,
  inspired by the Medium post and the TheStandup conversation
  about AI psychosis.

**now go outside.**
