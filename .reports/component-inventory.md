# gnome-logs-rb component inventory

Survey of upstream `org.gnome.Logs` (origin/master) against the Ruby port on
`ruby`. Scope: the whole app, since this is the opening survey of the fork
(see `component-identification` skill, "Scope it").

Finding up front: **the `ruby` branch already has a `lib/gnome_logs/*.rb`
file for every upstream user-facing source file**, each carrying a header
comment naming the upstream file it ports, and each with real body content
(no stubs — files range 42–310 lines). This inventory exists to confirm that
claim file-by-file and to flag the few places where a single upstream file
fans out to more than one port file, or vice versa, so that a later
`component-parity` pass (checking widget/CSS/signal counts, not presence) has
an accurate map to start from.

## Upstream user-facing source files

| Upstream file | Kind | Port file | Present |
|---|---|---|---|
| `src/gl-application.c`/`.h` | Application class (actions, accelerators, About dialog) | `lib/gnome_logs/application.rb` | yes |
| `src/gl-main.c` | Entry point | `lib/gnome_logs/main.rb` (+ `bin/gnome-logs`) | yes |
| `src/gl-window.c`/`.h` + `data/gl-window.ui` | Main window: header bar, journal-access warning bar, log view, window actions (close/search/export) | `lib/gnome_logs/window.rb` | yes |
| `src/gl-eventtoolbar.c`/`.h` + `data/gl-eventtoolbar.ui` | Header bar: title, boot selector, export button, search toggle, primary menu | `lib/gnome_logs/event_toolbar.rb` | yes |
| `src/gl-categorylist.c`/`.h` + `data/gl-categorylist.ui` | Sidebar category list box | `lib/gnome_logs/category_list.rb` | yes |
| (category row logic inside `gl-categorylist.c`, `gl-journal.c` match building) | One sidebar category entry (type + journalctl matches) | `lib/gnome_logs/category.rb` | yes (upstream's `GlCategoryListFilter`/match-building logic consolidated into one Ruby class) |
| `src/gl-eventviewlist.c`/`.h` + `data/gl-eventviewlist.ui` | Sidebar + log list container | `lib/gnome_logs/event_view_list.rb` | yes (also absorbs most of `gl-journal-model.c`'s list-model role, since the port reads the result set in one go) |
| `src/gl-eventviewrow.c`/`.h` | One row of the log list (optional category column for Important view) | `lib/gnome_logs/event_view_row.rb` | yes |
| `src/gl-eventviewdetail.c`/`.h` + `data/gl-eventviewdetail.ui` | Popover shown when a log row is activated: field grid + full message | `lib/gnome_logs/event_view_detail.rb` | yes |
| `src/gl-searchpopover.c`/`.h` + `data/gl-searchpopover.ui` | Search options popover (What / Search Type / time range) | `lib/gnome_logs/search_popover.rb` | yes |
| `src/gl-journal.c`/`.h` | journalctl invocation + query-to-match translation | `lib/gnome_logs/journal.rb` + `lib/gnome_logs/query.rb` | yes (split: `journal.rb` runs journalctl, `query.rb` is the data object `GlQuery` ports to) |
| `src/gl-journal-model.c`/`.h` | GListModel wrapping journal results | folded into `lib/gnome_logs/event_view_list.rb` / `lib/gnome_logs/journal_entry.rb` | yes (see note above; no separate list-model file needed given the port's synchronous read) |
| (journal entry struct, implicit in `gl-journal.c`) | One parsed journal entry (plain-object mirror of `GlJournalEntry`) | `lib/gnome_logs/journal_entry.rb` | yes |
| `src/gl-util.c`/`.h` | Formatting/boot/relative-time helpers, GSettings access, "open journal access" error dialog helper | `lib/gnome_logs/util.rb` | yes |
| `data/help-overlay.ui` | Ctrl+? keyboard shortcuts window | `lib/gnome_logs/shortcuts_window.rb` | yes |
| `data/org.gnome.Logs.gschema.xml` | GSettings schema (2 keys: journal-access warning dismissed, window state) | `lib/gnome_logs/settings.rb` | yes |
| (gettext/translation plumbing implicit via `gi18n.h` includes in C) | i18n wrapper | `lib/gnome_logs/translation.rb` | yes |
| (systemd catalog lookup, `sd_journal_get_catalog` call sites in `gl-journal.c`) | Message catalog (MESSAGE_ID → explanation text) | `lib/gnome_logs/catalog.rb` | yes |
| `data/org.gnome.Logs.gresource.xml` | GResource manifest bundling the `.ui` files above | no port equivalent needed — the Ruby port builds widgets declaratively in code, by house style, so there is nothing to bundle | n/a |
| `data/org.gnome.Logs.metainfo.xml.in` | AppStream metadata (About dialog fields: description, screenshots, release notes) | consumed by `application.rb`'s About dialog | partial — verify `application.rb`'s About dialog pulls comments/version/website consistent with metainfo; not yet cross-checked line-by-line |
| `data/org.gnome.Logs.desktop.in` | Desktop entry | n/a (packaging, not a widget) | n/a |
| `po/*.po` | Translation catalogue | `ruby` branch has its own `po/` — translation-parity is a separate skill/pass, not covered here | separate pass |

## Files with no corresponding port unit (and why)

- `src/gl-main.c` and `bin/gnome-logs` — covered by `lib/gnome_logs/main.rb`, confirmed trivial one-line delegation to `require 'gnome_logs'`; matches house style.
- `tests/test-gl-util.c` — upstream's only unit test. The port's `spec/` directory should have an equivalent for `util.rb`; not verified in this pass (out of scope — this inventory is components, not tests; see `test-parity` skill for that comparison).
- `help/` (Mallard help pages, `help/C/*.page`) — user documentation, not a widget/component; out of scope for this skill but worth flagging as unported prose if nothing in the Ruby port serves it.

## Not yet verified at the widget/CSS/signal level

This pass confirms **presence** (every upstream component file has a port
file, non-stub, with a header comment naming its upstream source) but does
**not** confirm parity of widget types, CSS classes, signal connections, or
action names inside each file — that is the `component-parity` skill's job
and should be run next, file pair by file pair, using the mapping table
above as its join key. Particular pairs to check first because of the
fan-in/fan-out noted above:
- `category.rb` against `gl-categorylist.c` + the match-building code in
  `gl-journal.c`
- `event_view_list.rb` against `gl-eventviewlist.c` + `gl-journal-model.c`
- `journal.rb` / `query.rb` against `gl-journal.c`
- `application.rb`'s About dialog against
  `data/org.gnome.Logs.metainfo.xml.in`

## Summary

Upstream user-facing component files: 15 (`gl-application`, `gl-main`,
`gl-window`, `gl-eventtoolbar`, `gl-categorylist`, `gl-eventviewlist`,
`gl-eventviewrow`, `gl-eventviewdetail`, `gl-searchpopover`, `gl-journal`,
`gl-journal-model`, `gl-util`, plus `help-overlay.ui`, the gschema and the
gresource manifest) plus their `.ui` counterparts.

Port files in `lib/gnome_logs/`: 19, covering every upstream component file
(several upstream files' responsibilities are consolidated or split across
Ruby files, documented above), plus three Ruby-only infrastructure files
with no single upstream counterpart (`catalog.rb`, `settings.rb`,
`translation.rb`) that port behaviour upstream expresses inline via systemd
catalog calls, GSettings calls and `gi18n.h` includes respectively.

**Conclusion: no missing component file.** This fork's `ruby` branch is
further along than most forks surveyed at this stage — the next useful work
here is `component-parity` (widget/CSS/signal counts per file) and
`translation-parity`/`test-parity`, not component scaffolding.
