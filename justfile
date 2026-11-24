# Fork maintenance recipes (FORK.md §3, §7). Upstream is termux/termux-app, branch `master`.
# Nothing here pushes: pushing is a deliberate act (FORK.md §1).

default:
    @just --list

# Drift from upstream plus the structural tripwires, for a human.
upstream-status:
    #!/usr/bin/env bash
    set -uo pipefail
    git fetch upstream --tags --quiet
    read -r behind ahead < <(git rev-list --left-right --count upstream/master...HEAD)
    echo "behind upstream/master: $behind    ahead (commits we carry): $ahead"
    echo
    just upstream-tripwire 2>/dev/null || true
    echo
    echo "next: just sync   (a merge, NOT a rebase; FORK.md §3)"

# `upstream-status` wraps this for humans; .github/workflows/upstream-tripwire.yml
# consumes it and opens an issue. One implementation, two callers: do not fork the logic.
# Structural tripwires only, as markdown; exits 1 when any fires.
upstream-tripwire:
    #!/usr/bin/env bash
    set -uo pipefail
    git rev-parse --verify --quiet upstream/master >/dev/null || {
      echo "no upstream/master ref: run git fetch upstream"; exit 1; }
    behind=$(git rev-list --count HEAD..upstream/master)
    if [ "$behind" -eq 0 ]; then echo "- up to date with \`upstream/master\`."; exit 0; fi
    hit=0
    # merge-base..upstream/master, NOT HEAD..upstream/master: the two-dot form of `git diff`
    # is a tree diff and would also report everything OUR side carries, read backwards
    # (rift fork, UPSTREAM-SYNC.md §13: that made a tripwire fire on every run forever).
    mb=$(git merge-base HEAD upstream/master)
    tv=terminal-view/src/main/java/com/termux/view
    sp=termux-shared/src/main/java/com/termux/shared

    # 1. The gesture seam: every fork hook (FORK.md §2.A) lives in these three files.
    if ! git diff --quiet "$mb..upstream/master" -- \
        "$tv/TerminalView.java" "$tv/TerminalViewClient.java" "$tv/GestureAndScaleRecognizer.java"; then
      echo "- **[!] gesture seam changed**: upstream touched TerminalView / TerminalViewClient / GestureAndScaleRecognizer, where our swipe hooks sit (FORK.md §2.A):"
      echo '```'
      git diff --stat "$mb..upstream/master" -- \
        "$tv/TerminalView.java" "$tv/TerminalViewClient.java" "$tv/GestureAndScaleRecognizer.java"
      echo '```'
      hit=1
    fi

    # 2. The property registry. A key missing from TERMUX_APP_PROPERTIES_LIST reads as unset
    # with no warning, so a reshaped registry can kill our keys without a compile error.
    # `grep -c`, never `grep -q`: with pipefail a short-circuiting grep -q SIGPIPEs the
    # upstream `git diff` and the pipeline returns 141, so a real match reports "no hit".
    reg=$(git diff "$mb..upstream/master" -- \
        "$sp/termux/settings/properties/TermuxPropertyConstants.java" \
        "$sp/termux/settings/properties/TermuxSharedProperties.java" \
        "$sp/settings/properties/SharedProperties.java" 2>/dev/null \
      | grep -cE '^[-+].*(TERMUX_APP_PROPERTIES_LIST|getInternalPropertyValueFromValue|mPropertiesList)')
    if [ "${reg:-0}" -gt 0 ]; then
      echo "- **[!] property registry changed** ($reg line(s)): re-check that swipe-left-sequence / swipe-right-sequence still load (FORK.md §2.A hazard H1)."
      hit=1
    fi

    # 3. Toolchain: CI image, SDK levels and Gradle moved.
    tc=$(git diff "$mb..upstream/master" -- gradle.properties build.gradle \
        gradle/wrapper/gradle-wrapper.properties 2>/dev/null \
      | grep -cE '^[-+].*(compileSdkVersion|minSdkVersion|targetSdkVersion|distributionUrl|com\.android\.tools\.build)')
    if [ "${tc:-0}" -gt 0 ]; then
      echo "- **[!] build toolchain changed** ($tc line(s)): SDK levels, Gradle or AGP moved; check .github/workflows/fork-build.yml still builds."
      hit=1
    fi

    # 4. Hard ceiling: never skip a second upstream minor release (rift fork rule).
    minor() { printf '%s' "$1" | sed -nE 's/^v?0\.([0-9]+).*/\1/p'; }
    ours=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)
    theirs=$(git describe --tags --abbrev=0 upstream/master 2>/dev/null || true)
    om=$(minor "$ours"); tm=$(minor "$theirs")
    if [ -n "$om" ] && [ -n "$tm" ] && [ $((tm - om)) -ge 2 ]; then
      echo "- **[!] two or more upstream minor releases behind** ($ours -> $theirs): a rewrite has probably landed; sync now."
      hit=1
    fi

    if [ "$hit" -eq 0 ]; then echo "- no structural tripwire ($behind commit(s) behind); a batched merge is fine."; fi
    exit "$hit"

# Merge all of upstream/master into develop, then gate on the unit tests.
sync:
    just sync-to upstream/master

# Merge one checkpoint (a smaller RANGE, never a rebase), then gate on the unit tests.
sync-to ref:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -z "$(git status --porcelain)" ] || { echo "dirty tree: commit or stash first"; exit 1; }
    git fetch upstream --tags --quiet
    git merge --no-edit {{ref}} || {
      echo "conflicts: resolve per FORK.md §4, run ./gradlew test, then git commit"; exit 1; }
    ./gradlew test
    echo "merged {{ref}} and tests pass. CI still has to build the APK. Push when ready: git push origin develop"
