# gnome-logs — component identification

| | |
|---|---|
| Upstream | `origin/master` @ `45f9646` (this fork has no `main`; `master` is the only non-`ruby` branch, and is what `origin/master`/`origin/HEAD` both point at) |
| Port | `ruby` @ `6501e6b` |
| Method | `component-identification` skill: `.ui` first, then the backing `.c`, then CSS and runtime construction |

This is the identification half only — what exists on each side, per file, with
its widgets, CSS classes, signals and actions named. The four-axis comparison
and verdicts live in `component-parity.md`. Where `.reports/component-inventory.md`
already did this work (two prior rounds, `92d45b6`/`504c3f9`), this document
re-verifies it against `origin/master` rather than re-deriving it from scratch,
and calls out where that file's own language violates `accountability-ensurance`
(tracked in `accountability-ensurance.md`).

## Upstream component files (one unit = one `.c`/`.h` pair, or a standalone `.ui`)

| Upstream file(s) | Kind |
|---|---|
| `src/gl-main.c` | entry point |
| `src/gl-application.{c,h}` | application: actions, accelerators, About, CSS providers, settings watchers, `--version` |
| `src/gl-window.{c,h}` + `data/gl-window.ui` | main window: InfoBar, actions `win.search`/`win.view-boot`/`win.export`/`win.close` |
| `src/gl-eventtoolbar.{c,h}` + `data/gl-eventtoolbar.ui` | header bar: primary menu (2 sections, 4 items), boot `Gio.Menu`, search toggle |
| `src/gl-categorylist.{c,h}` + `data/gl-categorylist.ui` | sidebar: 10 rows, 4 of them `visible=False` upstream too |
| `src/gl-eventviewlist.{c,h}` + `data/gl-eventviewlist.ui` | content pane: search bar/popover, list, empty state, row-compression repeaters |
| `src/gl-eventviewrow.{c,h}` (no `.ui`) | one log row, built in code; compressed-entry box + badge, conditional |
| `src/gl-eventviewdetail.{c,h}` + `data/gl-eventviewdetail.ui` | detail popover: 10 field pairs, each conditionally hidden |
| `src/gl-searchpopover.{c,h}` + `data/gl-searchpopover.ui` | search options: 2 `TreeView`-backed stacks, 8 `SpinButton`s + 8 `Adjustment`s for time-of-day, 2 `Calendar`s in `Revealer`s, typed-date `Entry`s |
| `data/help-overlay.ui` (no backing source) | shortcuts window: 2 groups, 6 shortcuts |
| `src/gl-journal.{c,h}` | journal reader |
| `src/gl-journal.h` (`GlJournalEntry`) | model |
| `src/gl-journal-model.{c,h}` | row-compression model, feeds the eventviewlist repeater |
| `src/gl-util.c` | time formatting, clock-format lookup, uid, journal storage probing |
| `data/org.gnome.Logs.gschema.xml` | GSettings schema |
| `data/org.gnome.Logs.desktop.in`, `.metainfo.xml.in` | launcher + AppStream metadata, both carry translatable text |
| `po/` + `data/*.ui` gettext | 128 distinct messages (census below), 72 shipped languages |

## Port files (`lib/gnome_logs/`)

`main.rb`, `application.rb`, `window.rb`, `event_toolbar.rb`, `category_list.rb`,
`category.rb`, `event_view_list.rb`, `event_view_row.rb`, `event_view_detail.rb`,
`search_popover.rb`, `shortcuts_window.rb`, `journal.rb`, `journal_entry.rb`,
`query.rb`, `settings.rb`, `util.rb`, `catalog.rb`, `translation.rb` — 18 files,
one per upstream unit (`gl-journal-model.c` folded into `event_view_list.rb`;
`query.rb` and `catalog.rb` have no single upstream file, they are logic
upstream inlines).

## What a file-by-file scan under-reports (verified by reading source, not grep)

- **`data/gl-categorylist.ui` rows.** The scan sees 10 `Gtk.ListBoxRow`s; four
  (`Alerts`, `Starred`, `Updates`, `Usage`) are `visible="False"` in the
  template and have no runtime path that un-hides them in `src/gl-categorylist.c`
  — they are dead in both the app and the file. The port's `category.rb`
  builds 6, matching the 6 *live* rows exactly; this is correct identification,
  not a gap, once the dead rows are read and not just counted.
- **`src/gl-eventviewrow.c`'s conditional box.** `gl_event_view_row_set_entry`
  builds `message_box` + `compressed_entries_label` only when the row's
  `GlRowEntryType` is `GL_ROW_ENTRY_TYPE_COMPRESSED`; the scan of a cold read
  would miss this as "always built". It is a repeater-adjacent conditional
  widget, one per compressed group, and belongs to the compressed-entries
  feature as a whole.
- **`src/gl-eventtoolbar.c`'s boot menu.** Built at runtime with
  `g_menu_prepend_section`, not declared in the `.ui` — `gl-eventtoolbar.ui`
  alone under-reports this component by one whole `Gio.Menu` with a variable
  item count (one `win.view-boot` radio item per boot known to the journal).
- **Dynamic CSS on event rows.** `popover-activated-row` is added by
  `gl-eventviewrow.c`'s `row_activated` handler and removed on the detail
  popover's `closed` signal — not visible in any `.ui`, only in the `.c`.
- **`t()` as the port's translation marker.** `lib/gnome_logs/translation.rb`
  defines `t(message) = Translation.translate(message)`, which calls GetText's
  `_`. Standard `_()`/`N_()` scanners (xgettext defaults, and this audit's own
  `msgid-census.sh`) do not know `t` is a gettext keyword and silently skip
  every string passed to it as a literal. Counting `grep -c '_('` or running a
  stock extractor against this port under-reports its translated-string count
  by roughly 90%. Full detail in `translation-parity.md`.

## Non-widget data files

| Upstream | Port |
|---|---|
| `data/org.gnome.Logs.gschema.xml` | `data/org.gnome.Logs.gschema.xml` present |
| `data/style.css`, `style-hc.css` | both present |
| `data/org.gnome.Logs.metainfo.xml.in` | `data/org.gnome.Logs.metainfo.xml` present |
| `data/org.gnome.Logs.desktop.in` | `data/org.gnome.Logs.desktop` present |
| `data/org.gnome.Logs.service` | present |
| `data/gnome-logs.xml` (man page) | present |
| `data/icons/` | present |
| `po/` (72 `LINGUAS` entries) | present, unchanged |
| `help/` (user docs) | present |
| `tests/test-gl-util.c` (1 upstream test, 6 inline cases) | `spec/gnome_logs/util_spec.rb` — see `test-parity.md` for whether it runs |
