## Visual snapshot testing

Builds the site, screenshots every page at mobile and desktop widths, and shows
which ones your branch changed, compared against the point on `main` it
branched from.

### Running

From the repository root, on a feature branch (it refuses to run on
`master`/`main`):

```bash
npm run snapshot-chrome     # or snapshot-firefox, snapshot-safari
```

This builds and screenshots your working tree, builds and screenshots the base
commit in a throwaway git worktree (your working tree is never touched), diffs
the two, and opens a viewer at <http://localhost:8878> showing baseline,
current and diff side by side with the changed snapshots first. It exits
non-zero if anything changed, so it also works as a pass/fail check.

From this folder the same thing is
`SNAPSHOT_BROWSER=firefox ./run-snapshot-test.sh --view`, and
`./view-snapshots.sh` reopens the viewer on the last results.

### Setup

Run `npm i` in the repository root. This folder's dependencies, and the
Playwright browser for the `SNAPSHOT_BROWSER` you picked, are installed for you
on first run. If you later switch browsers, run
`npx playwright install firefox` (or `webkit` for safari) in this folder.

### Notes

- The pages come from `dist/all-paths.json`, so a new elm-pages route is
  snapshotted without any changes here. Viewports are listed in
  `take-snapshots.js`.
- The event card would otherwise show whatever Meetup's next event is, so
  `/api/next-event` answers with the fixed event in `next-event.json`. The
  build itself still fetches from Meetup and needs network access.
- The base commit has to be an elm-pages app. Baselines can't be made for
  commits from before the elm-pages conversion.
- Baselines are cached per browser and base commit. Delete `snapshots/` to
  force fresh ones; everything in there is gitignored.
- Each browser draws text slightly differently and gets its own snapshot
  folder, so switching browsers re-renders the baseline rather than reporting
  every snapshot as changed.
- Bump `renderer_version` in `run-snapshot-test.sh` after changing
  `take-snapshots.js` in a way that changes the images, so cached baselines
  get re-rendered instead of compared against.
