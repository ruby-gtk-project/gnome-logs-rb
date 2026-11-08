# Component parity — gnome-logs-rb

| | |
|---|---|
| Upstream | `origin/master` @ `45f9646` |
| Port | `ruby` @ `6501e6b` |
| Units with full (4-axis) parity | **8 / 17** |
| Units with at least one open gap | **9 / 17** |
| Runtime gate | `drive_ok=true`, 126/126 checks, covering the units the driver touches (see `test-parity.md` for what that leaves out) |

Units follow `.reports/component-inventory.md`'s file map, which this report
treats as a working document to re-verify, not as settled fact — it is written
by the port, about the port (see `accountability-ensurance.md` for the places
its own wording oversteps that).

## Unit verdicts

| Unit | Verdict | Open gap |
|---|---|---|
| `gl-main.c` → `main.rb` | parity | — |
| `gl-window.c`/`.ui` → `window.rb` | **gap** | A prior round claimed `_('Unable to read user logs')` is "never shown." This round traced `check_journal_storage` and found that claim is wrong: it shows standalone whenever storage is `:persistent`, the system journal is readable, and the user journal is not — a real, common case (no `systemd-journal` group membership). Upstream's own equivalent `switch` also overwrites the label when *both* fail (same single `GtkLabel`), so the port is a faithful 1:1 port of that logic, not a regression; corrected here. The gap that **is** real, found this round and not previously reported: `check_journal_access` adds an `elsif event_view_list.entries.empty?` branch with no upstream counterpart — upstream's warning switch is keyed purely on `storage_type`, never on whether the *current query* returned zero rows. Since this runs once at window construction against the default (unfiltered) view, the practical exposure is narrow (a persistent, readable journal with zero boots at all), but it is still a condition upstream does not warn on and the port does, and it was undocumented before this round. |
| `gl-eventtoolbar.c`/`.ui` → `event_toolbar.rb` | parity | — (boot `Gio.Menu`, primary-menu sections, `title-menu-button flat`, `caption` all verified present) |
| `gl-categorylist.c`/`.ui` → `category_list.rb` + `category.rb` | parity | 6/6 live rows; the 4 `visible=False` upstream rows have no port counterpart and need none — they are inert upstream too |
| `gl-eventviewlist.c`/`.ui` → `event_view_list.rb` | **gap** | the vertical `Gtk.Separator` between sidebar and content is not built; `gl_event_view_list_set_sort_order` has no port counterpart at this layer (sort-order plumbing lives only at the window level, per the inventory) |
| `gl-eventviewrow.c` → `event_view_row.rb` | **gap** | the `event` CSS class upstream applies (`.event { padding: 5px }`) is replaced by hand-set margins — visually similar, not the same mechanism, and the stylesheet rule is unused by the port |
| `gl-eventviewdetail.c`/`.ui` → `event_view_detail.rb` | **gap** | upstream hides each of the 10 field pairs when its value is empty (`visible=False` by default per field); the port shows all 10 always. This is a real behaviour difference a user sees (blank "Audit Session:" rows on messages that have none) |
| `gl-searchpopover.c`/`.ui` → `search_popover.rb` | **gap (largest)** | 8 `Gtk.SpinButton`s + 8 `Gtk.Adjustment`s for hour/minute/second/AM-PM on both ends of a custom range: **0 built**. 2 typed-date `Gtk.Entry`s with the `22 January 2016 or 1/22/2016` parse path: **0 built**. `parameter_liststore`'s separator rows between field groups: not reproduced in the `Gtk::DropDown` replacement. No `closed` handler on the popover. Time-of-day precision in a log search tool is not a cosmetic miss — a user cannot narrow to "between 2pm and 3pm," only to whole days. |
| `help-overlay.ui` → `shortcuts_window.rb` | parity | ported via `Gtk::Builder`, binding limitation noted in `FINDINGS.md`-equivalent comment in the file |
| `gl-application.c` → `application.rb` | **gap** | no `--version` CLI option (no Ruby-side blocker found and documented — see rule below); About dialog fields are complete; `app.quit`/`<Primary>q` intentionally dropped (upstream still has it — this is a missing accelerator, not a non-issue) |
| `gl-util.c` → `util.rb` | **gap** | all 6 time-format cases, uid, machine-id, journal-storage probing ported, and `_("%s – %s")` is called (`Journal::Boot#display_name` → `event_toolbar.rb`'s boot label and boot menu items — a prior round's claim that it was "built but unused" was independently re-checked this round and is wrong; corrected here). The real gap: `util.rb`'s own comment admits `Time#strftime` is not locale-aware, so `%b` (month) and `%p` (AM/PM) always render in English regardless of the user's locale, even though the format *strings* are still passed through gettext. Every timestamp in the event list, event detail, and boot menu is affected in any non-English locale — this is a user-visible regression from upstream's locale-correct `g_date_time_format`, not a cosmetic nit, and was previously recorded only as a "deliberate difference" in a code comment, not in any parity report. |
| `gl-journal.c` → `journal.rb` + `journal_entry.rb` | parity | — |
| `gl-journal-model.c` → folded into `event_view_list.rb` | **gap, partially closed** | compressed entry groups are now built (grouping, header row, badge, CSS toggling); the neighbouring-group separator edge case from `gl_journal_model_add_header` is explicitly not replicated (component-inventory.md says so — "simplified"; see `accountability-ensurance.md`, this is exactly the pattern that skill exists to catch) |
| `org.gnome.Logs.gschema.xml` | parity | — |
| `style.css` / `style-hc.css` | parity | both present, high-contrast swap wired to `notify::high-contrast` |
| `org.gnome.Logs.metainfo.xml` / `.desktop` / `.service` / man page / icons | parity | all present |
| `po/` (72 languages) | **gap** | files and `LINGUAS` carried over unchanged (so the 72 languages *would* keep working), but the key set the port's code actually emits does not match the catalogue those files were built for — 40 of 128 upstream messages have no counterpart text anywhere in the port. Full census in `translation-parity.md`. |

## Rule-outs that are not gaps

- The 4 hidden sidebar rows (`Alerts`, `Starred`, `Updates`, `Usage`): upstream
  ships them `visible="False"` with no code path that un-hides them. A port
  that built 4 invisible rows would have component parity and zero user-visible
  effect; this is flagged in the identification doc as a thing to be aware of,
  not counted against the port here.
- `GtkTreeView` → `Gtk::DropDown` in the search popover's two picker lists:
  `GtkTreeView` is deprecated in GTK4 and has no binding-level equivalent worth
  reproducing pixel-for-pixel. The *dropdowns* are not the gap; the missing
  separators inside them and the missing time-of-day precision alongside them
  are, and are counted above.

## What "9/17 parity" does not mean

It does not mean the app is roughly half-missing. The two heaviest gaps — the
search popover's time precision and the detail popover's per-field hiding —
are both small widget counts with large behavioural weight: a log-reading tool
is specifically a tool for narrowing down *when* and *what*, and both of those
axes are the ones cut.
