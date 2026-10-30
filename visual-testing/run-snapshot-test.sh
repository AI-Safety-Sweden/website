#!/bin/bash
# Visual snapshot regression test.
#
# 1. Refuse to run on master/main (you must be on a feature branch).
# 2. Build the current working tree and screenshot every page.
# 3. Check out the commit on main that this feature branch forked from (in a
#    throwaway git worktree, so your branch and working tree are never touched),
#    build it and screenshot it as the baseline.
# 4. The worktree is removed, leaving you exactly where you started.
# 5. Diff current vs baseline and list which snapshots don't match.
#
# Pass --view to open the result viewer (view-snapshots.sh) when done.
#
# SNAPSHOT_BROWSER picks the renderer (chrome, the default, firefox or safari).
# Every browser renders text slightly differently, so each one gets its own
# snapshots/<browser>/ folder and its images are only ever compared with images
# from the same browser.
#
# Baselines are cached per base commit in snapshots/<browser>/baseline-<sha>/,
# so steps 3 and 4 are skipped when that folder already exists.
set -e

cd "$(dirname "$0")"
vt_dir=$(pwd)
repo_root=$(git rev-parse --show-toplevel)

# --- 1. Must be on a feature branch ----------------------------------------
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "master" ] || [ "$branch" = "main" ] || [ "$branch" = "HEAD" ]; then
  echo "❌ You are on '$branch'. Check out a feature branch before running visual snapshot tests." >&2
  exit 1
fi

# Pick whichever of master/main exists locally as the integration branch.
if git rev-parse --verify --quiet master >/dev/null; then
  base_branch=master
elif git rev-parse --verify --quiet main >/dev/null; then
  base_branch=main
else
  echo "❌ Could not find a local 'master' or 'main' branch to compare against." >&2
  exit 1
fi

base_sha=$(git merge-base "$base_branch" HEAD)
browser=${SNAPSHOT_BROWSER:-chrome}
echo "ℹ️  Feature branch : $branch"
echo "ℹ️  Base ($base_branch) : $base_sha"
echo "ℹ️  Browser       : $browser"

# Bumped whenever the snapshot tooling changes in a way that can change the
# images, so that baselines cached by an older version are re-rendered instead
# of silently reused.
renderer_version=r1

current_dir="$vt_dir/snapshots/$browser/current"
baseline_dir="$vt_dir/snapshots/$browser/baseline-$base_sha-$renderer_version"
diff_dir="$vt_dir/snapshots/$browser/diff"

# Guarded `rm -rf`. Refuses to delete anything that isn't strictly inside this
# repo's snapshots/ folder, so a bug that leaves a path variable empty (e.g.
# "$vt_dir" unset turning "$diff_dir" into the root-anchored "/snapshots/diff")
# can never blow away an unexpected directory.
safe_rmrf() {
  local target="$1"
  if [ -z "$vt_dir" ] || [ -z "$target" ]; then
    echo "❌ safe_rmrf: refusing to delete (empty path; vt_dir='$vt_dir' target='$target')" >&2
    exit 1
  fi
  case "$target" in
    "$vt_dir/snapshots/"?*) rm -rf "$target" ;;
    *)
      echo "❌ safe_rmrf: refusing to delete '$target' (not inside '$vt_dir/snapshots/')" >&2
      exit 1
      ;;
  esac
}

# Install this folder's node deps if missing (playwright, odiff, express), and
# the browser Playwright drives.
if [ ! -d node_modules/playwright ]; then
  echo "Installing visual-testing node dependencies..."
  npm install
  if [ -z "$PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD" ]; then
    case "$browser" in
      chrome) npx playwright install chromium ;;
      firefox) npx playwright install firefox ;;
      safari) npx playwright install webkit ;;
    esac
  fi
fi

# render_snapshots <repo-dir> <output-dir>
# Builds the site inside <repo-dir> and screenshots every page into the
# absolute <output-dir>.
render_snapshots() {
  local repo_dir="$1"
  local out="$2"
  safe_rmrf "$out"
  if [ ! -f "$repo_dir/elm-pages.config.mjs" ]; then
    echo "❌ $repo_dir isn't an elm-pages app, so it can't be built and snapshotted." >&2
    exit 1
  fi
  ( cd "$repo_dir" && npm run build )
  SNAPSHOT_OUT="$out" SNAPSHOT_BROWSER="$browser" node take-snapshots.js "$repo_dir/dist"
}

# --- 2. Render current branch snapshots ------------------------------------
echo ""
echo "📸 Rendering current branch snapshots..."
render_snapshots "$repo_root" "$current_dir"

# --- 3. Render baseline snapshots for the base commit (cached) --------------
if [ -d "$baseline_dir" ] && [ -n "$(ls -A "$baseline_dir" 2>/dev/null)" ]; then
  echo ""
  echo "✅ Reusing cached baseline for $base_sha"
else
  echo ""
  echo "📸 Rendering baseline snapshots for base commit $base_sha..."
  worktree=$(mktemp -d "${TMPDIR:-/tmp}/website-baseline.XXXXXX")
  # Always clean up the worktree, even on error / Ctrl-C (this is step 4).
  cleanup() {
    git -C "$repo_root" worktree remove --force "$worktree" >/dev/null 2>&1 || true
    rm -rf "$worktree" 2>/dev/null || true
  }
  trap cleanup EXIT

  # Detached worktree at the base commit: leaves your branch + working tree
  # completely untouched. The screenshots are taken by this folder's
  # take-snapshots.js, so a change to the test tooling can never masquerade as
  # a visual diff.
  git -C "$repo_root" worktree add --quiet --detach "$worktree" "$base_sha"
  # Reuse the already-installed node modules instead of reinstalling.
  ln -s "$repo_root/node_modules" "$worktree/node_modules"

  render_snapshots "$worktree" "$baseline_dir"

  cleanup
  trap - EXIT
fi

# --- 5. Diff current vs baseline -------------------------------------------
echo ""
echo "🔍 Comparing current branch against baseline..."
safe_rmrf "$diff_dir"
compare_status=0
node compare-snapshots.js "$baseline_dir" "$current_dir" "$diff_dir" || compare_status=$?

# --- 6. Optionally start the result viewer ----------------------------------
if [ "${1:-}" = "--view" ]; then
  ./view-snapshots.sh
else
  echo ""
  echo "👀 Run ./view-snapshots.sh (or re-run with --view) to browse the images in a browser."
fi
exit $compare_status
