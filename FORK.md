# Fork maintenance guide

This is a **fork** of [`termux/termux-app`](https://github.com/termux/termux-app) that carries
one small local change on top of upstream. It is maintained the way the rift fork
([`Xieyt/rift`, `FORK.md`](https://github.com/Xieyt/rift/blob/develop/FORK.md)) is: a short stack of
single-purpose commits on a `develop` branch, upstream absorbed by **merge**, drift watched by a
tripwire that runs by itself, and every sync written down.

Read this before syncing with upstream or adding a local feature.

> **Status, 2026-11-24:** forked at `upstream/master` `8629e63`, 0 commits behind. One feature
> (§2.A). **Not yet verified on a device**: nothing here has been compiled or run (§6).

---

## 1. Repository topology

| Remote | URL | Role |
|---|---|---|
| `origin` | `https://github.com/Xieyt/termux-app` | our fork (push here) |
| `upstream` | `https://github.com/termux/termux-app` | source of truth (never push here) |

- **`develop`**: `upstream/master` **merged** with our commits on top. It is the default branch and
  the one CI builds. Do not rename it casually; anything pinning the branch name breaks.
- There is **no mirror branch**. Read `upstream/master` directly (`git fetch upstream`).

> **Rule:** local work never touches upstream. We only push to `origin`. Upstream sees a PR only
> when we open one deliberately from a dedicated feature branch. (Enforced: `.omp/rules/fork-never-push-upstream.md`.)

---

## 2. What this fork adds

### A. `feat: horizontal swipe writes a configurable key sequence`
**Files:** `terminal-view/.../TerminalView.java`, `terminal-view/.../TerminalViewClient.java`,
`app/.../TermuxTerminalViewClient.java`, `termux-shared/.../TermuxPropertyConstants.java`,
`termux-shared/.../TermuxSharedProperties.java`, `app/src/test/.../SwipePropertiesTest.java`.

**Why:** Termux turns a pinch into a font-size change and a vertical swipe into scrolling, but
`TerminalView.onScroll` never reads `distanceX`, so a sideways swipe is detected and discarded.
Programs that are driven by tabs (herdr, tmux) have nothing to bind it to.

**Behaviour:**
- A touch whose travel is horizontal-dominant (`|dx| > 2|dy|`) and long enough
  (`max(4 × paging slop, width / 5)`) calls `TerminalViewClient.getHorizontalSwipeSequence(toLeft)`
  on lift and writes the returned string to the session, with a haptic tick.
- `toLeft` means the **finger moved left**.
- While a sideways swipe is in progress the vertical scroll is suppressed, so it does not also
  scroll the pane.
- Active **only while the running program has mouse tracking on** (herdr, tmux, vim with mouse).
  In a plain shell the sequence would be typed as text, so swipes stay inert there.
- Default is off: with neither key set, behaviour is upstream's exactly.

**Config** (`~/.termux/termux.properties`; values use `java.util.Properties` escapes, so `\u0002`
is the Ctrl+B byte):

```properties
# herdr default bindings: prefix (Ctrl+B) then n / p
swipe-left-sequence=\u0002n
swipe-right-sequence=\u0002p
```

Swipe left (finger moves left) goes to the **next** tab. Reload with `termux-reload-settings`.
[INFERENCE] herdr's default `next_tab = "prefix+n"` and `previous_tab = "prefix+p"` come from
herdr's docs; the swipe-to-tab path has not been run.

**Conflict risk:** MEDIUM. Five call sites inside the anonymous `GestureAndScaleRecognizer.Listener`
in `TerminalView` (`onUp`, `onScroll`, `onFling`, `onDown`, plus a field); all logic is in private
methods appended at the end of the class so a sync conflict is a one-line decision, not a rewrite.
The client hook is an additive `default` method, and the property keys are *inserted* into the
registry list rather than edited, so neighbouring upstream changes merge cleanly.

**Hazards (clean merges that silently break this):**

| id | hazard | detect / fix |
|---|---|---|
| H1 | A key missing from `TERMUX_APP_PROPERTIES_LIST` loads without a warning and reads as unset. Swipes never fire. Compiles clean. | `SwipePropertiesTest`; the tripwire reports registry changes |
| H2 | `scrolledWithFinger = true` must run **before** our early return in `onScroll`. Otherwise `onUp` sends a mouse click at the lift point and a swipe in herdr clicks a pane. | keep `trackHorizontalSwipe(...)` directly below the `scrolledWithFinger = true;` line |
| H3 | `GestureAndScaleRecognizer` drops `e1`, which is why travel is accumulated in `onScroll`. If upstream passes it through, the accumulator can go. | tripwire flags that file |
| H4 | `getHorizontalSwipeSequence` is consulted twice per scroll event just to ask "enabled?". Cheap today; revisit if the property read stops being a map lookup. | read before optimising |

### Dropped / superseded (do NOT re-add)
None yet. Before defending a local patch at sync time, check whether upstream already does it.

---

## 3. Syncing with upstream (merge, never rebase)

```bash
just upstream-status   # drift + structural tripwires: does this need syncing NOW?
just sync              # merge upstream/master, then ./gradlew test
git push origin develop
```

- **Merge, not rebase.** A merge resolves each conflict once and `rerere` (enabled in this clone:
  `git config rerere.enabled true`) replays it. A rebase re-resolves per upstream commit.
  (`.omp/rules/fork-sync-never-rebase.md`.)
- **Range merge, not commit-by-commit.** The whole range is the smaller conflict set. If it is too
  big, `just sync-to <ref>` merges a checkpoint, and the boundary must not split a revert pair.
- **Cadence is enforced, not remembered.** `.github/workflows/upstream-tripwire.yml` runs weekly and
  keeps one rolling `upstream-sync` issue. A hard ceiling fires when we are two upstream minors
  behind. The rift fork needed 132 commits and four rewrites in one pass before this existed.
- **A sync is not finished until it is reported.** Green gates say nothing broke; they do not say what
  arrived. Append to `UPSTREAM-SYNC.md`: (1) what each upstream commit changes in behaviour, (2) every
  conflict and which side won and why, (3) what changed on our side as a result, (4) what is still
  unverified (for a headless gate, always the on-device behaviour).

### Keep upstream-only files untouched
`.github/workflows/*` from upstream stay as they are. Our CI lives in **new** files
(`fork-build.yml`, `upstream-tripwire.yml`), so a sync never conflicts there. Upstream's own
`debug_build.yml` triggers on `master` and so never runs on `develop`; that is expected.

---

## 4. Conflict-resolution playbook

Conflicts land in the gesture listener in `TerminalView.java` and the property registry.

1. **Take upstream's structure, re-apply our layer.** The rift fork resolved a 24-hunk rewrite by
   taking upstream's file wholesale and re-applying the feature as a patch series; the next 24
   upstream commits then cost three conflicted files. Do the same here.
2. Re-check each hazard in §2.A after any merge touching `terminal-view/`.
3. Record the resolution in `UPSTREAM-SYNC.md`, because `rerere`'s cache is local and uncommitted.

---

## 5. Maintenance philosophy

- **One commit per feature, never many.** Squash before pushing a new feature.
- **Quarantine tooling from behaviour.** The maintenance scaffolding (this file, `justfile`,
  workflows, `.omp/rules/`) is its own commit and is new files only.
- **Keep micro-fixes as their own tiny commits** so they are trivial to drop when upstream absorbs them.
- **Drop anything upstream has absorbed.**
- A new local feature: build it, squash it into one commit, keep it above the tooling commit,
  and update §2 here.

---

## 6. Building & verifying

**There is no Android SDK or JDK on the machine this fork was written on**, so nothing has been
compiled locally. The first compile happens in CI.

- `.github/workflows/fork-build.yml` (push to `develop`, or run manually) runs `./gradlew test` and
  `assembleDebug` for the **`apt-android-7`** variant and uploads the APKs as an artifact.
- Tests: `SwipePropertiesTest` (the H1 guard) runs in `./gradlew test`.

### Installing a build: read this first
- GitHub-release and `assembleDebug` builds are signed with the public test key committed at
  `app/testkey_untrusted.jks` (upstream `README.md`, "Security warning"). So a CI build **installs
  over a Termux installed from GitHub releases**.
- It does **not** install over an **F-Droid** or **Google Play** Termux: different signing keys, and
  Android refuses (`App not installed`). Uninstalling to get around that deletes
  `/data/data/com.termux`, which is where `$PREFIX`, `$HOME` and any `proot-distro` rootfs live.
  **Back up first** (`tar czf` of `$HOME` and `$PREFIX/var/lib/proot-distro` to shared storage).
- Termux plugins (`Termux:API`, `Termux:Widget`, ...) share `sharedUserId` `com.termux` and must come
  from the same signing source as the app.
- The APK's package variant must match the bootstrap already installed (`apt-android-7` unless the
  device is Android 5/6).

### On-device checklist (unrun)
- Swipe left/right in herdr switches tab, and does **not** also scroll or click.
- Vertical swipe still scrolls the pane; tap still focuses; pinch still resizes the font.
- In a plain shell, sideways swipe does nothing.
- With the keys unset, behaviour equals stock Termux.
- Edit `termux.properties`, run `termux-reload-settings`, swipe: the new sequence is used.

---

## 7. Enforced guards

TTSR rules in `.omp/rules/*.md` interrupt a mistake **while it is being made**, which is the only
useful moment for a policy a compiler cannot see. Each carries `probes: fire/silent` examples;
validate them with `omp ttsr test --rule .omp/rules/<name>.md --source tool --tool bash '<cmd>'`,
never by eye (two of the rift fork's five regexes were wrong on first write).

| rule | catches | doc it enforces |
|---|---|---|
| `fork-never-push-upstream` | `git push ... upstream ...` | §1 |
| `fork-sync-never-rebase` | `git rebase ... upstream ...` | §3 |
| `fork-remote-state-not-cached` | reading `origin/<b>` counts from a stale ref | §7 |

Invariants checkable *after* the fact belong in tests, not rules (`SwipePropertiesTest`). Do not
migrate one into the other: a rule fires before the edit exists, a test after it lands.

---

## 8. Quick reference

```bash
git fetch upstream
git rev-list --left-right --count upstream/master...develop   # "<behind> <ahead>"
git log --oneline upstream/master..develop                    # what we carry
just upstream-status                                          # drift + tripwires, human
just upstream-tripwire                                        # tripwires only, markdown, exit 1 on a hit
git ls-remote --symref origin HEAD                            # confirm default branch with the remote
```
