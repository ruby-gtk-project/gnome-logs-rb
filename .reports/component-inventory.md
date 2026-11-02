# gnome-logs — upstream component inventory

Upstream ref: `origin/master` (C/GTK4/libadwaita, GtkBuilder `.ui`).
Port branch: `ruby`, `lib/gnome_logs/`.
Method: the `component-identification` skill — every `.ui` read as the primary
inventory, then the backing `.c` read for runtime-built widgets, dynamic CSS
classes, actions and signals.

A component is a *set* of files: upstream splits each widget between a `.c`
subclass and a `.ui` template, and both halves map to one `lib/*.rb`.

## Map

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/gl-main.c` | `lib/gnome_logs/main.rb` | entry point | yes |
| `src/gl-application.{c,h}` | `lib/gnome_logs/application.rb` | application + actions + about | yes |
| `src/gl-window.{c,h}` + `data/gl-window.ui` | `lib/gnome_logs/window.rb` | main window | yes |
| `src/gl-eventtoolbar.{c,h}` + `data/gl-eventtoolbar.ui` | `lib/gnome_logs/event_toolbar.rb` | header bar + primary menu | yes |
| `src/gl-categorylist.{c,h}` + `data/gl-categorylist.ui` | `lib/gnome_logs/category_list.rb` | sidebar list | yes |
| (category model, from `gl-categorylist.h` enum + `gl-query.c` matches) | `lib/gnome_logs/category.rb` | model | yes |
| `src/gl-eventviewlist.{c,h}` + `data/gl-eventviewlist.ui` | `lib/gnome_logs/event_view_list.rb` | content pane, search bar, list, empty state | yes |
| `src/gl-eventviewrow.{c,h}` | `lib/gnome_logs/event_view_row.rb` | one log row | yes |
| `src/gl-eventviewdetail.{c,h}` + `data/gl-eventviewdetail.ui` | `lib/gnome_logs/event_view_detail.rb` | detail popover | yes |
| `src/gl-searchpopover.{c,h}` + `data/gl-searchpopover.ui` | `lib/gnome_logs/search_popover.rb` | search options popover | yes |
| `data/help-overlay.ui` (standalone, no backing source) | `lib/gnome_logs/shortcuts_window.rb` | shortcuts window | yes |
| `src/gl-journal.{c,h}` | `lib/gnome_logs/journal.rb` | journal reader | yes |
| `src/gl-journal.h` (`GlJournalEntry`) | `lib/gnome_logs/journal_entry.rb` | model | yes |
| `src/gl-journal-model.{c,h}` | folded into `event_view_list.rb` | model | deliberate merge |
| (`gl-query.c`/`.h` — query builder, inlined upstream) | `lib/gnome_logs/query.rb` | model | yes |
| `data/org.gnome.Logs.gschema.xml` | `lib/gnome_logs/settings.rb` | GSettings | yes |
| `src/gl-util.{c,h}` | **`lib/gnome_logs/util.rb`** | time formatting helpers | **no** |
| (catalog lookup, `sd_journal_get_catalog`) | `lib/gnome_logs/catalog.rb` | model | yes |
| `po/` + `data/*.ui` gettext | `lib/gnome_logs/translation.rb` | i18n | yes |

Every upstream component file has a port file. The parity gaps are **inside**
existing files, listed below.

## Per-component detail and gaps

### `data/gl-window.ui` + `src/gl-window.c` — the main window

| Widget | × | CSS | Signals / actions | Port |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (1200×600) | 1 | — | — | `Gtk::ApplicationWindow` + `Adwaita::ToolbarView` |
| `Gtk.Box` `event_box` vertical | 1 | — | — | yes |
| `Gl.EventToolbar` | 1 | — | — | yes |
| `Gtk.InfoBar` `info_bar` (`message-type=error`, hidden) | 1 | — | — | yes |
| `Gtk.Label` `message_label` | 1 | — | — | yes |
| `Gtk.Button` `help_button` "Help" | 1 | — | `clicked` → `on_help_button_clicked` | yes (InfoBar response) |
| `Gtk.Button` `ignore_button` "Ignore" | 1 | — | `clicked` → `on_ignore_button_clicked` | yes |
| `Gl.EventViewList` | 1 | — | — | yes |

Actions installed (`GActionEntry actions[]`): `win.search` (stateful toggle,
default `false`), `win.view-boot` (stateful radio, type `s`, default `''`),
`win.export`, `win.close`.

Error / empty states: `_("Unable to read system logs")`,
`_("Unable to read user logs")`, `_("No logs available")`; export failure via
`Adw.AlertDialog` `_("Export Failed")` / `_("Unable to export log messages to a file")`;
help failure via `_("Failed To Open Help")`. `Gtk.FileDialog` save with initial
name `_("log messages")`.

**Gaps**
- `win.view-boot` stateful radio action is not installed; the port selects boots through a plain callback, so the header-bar menu cannot show the selected boot as a radio item and nothing else can drive boot selection.
- `_("Unable to read user logs")` is never shown — the port collapses both to the system-logs message.
- `gl_window_set_sort_order` has no counterpart: the port reads `sort-order` once when building `Query` and never reacts to the key changing.

### `data/gl-eventtoolbar.ui` + `src/gl-eventtoolbar.c` — the header bar

| Widget | × | CSS | Signals / actions | Port |
|---|---:|---|---|---|
| `Adw.HeaderBar` `headerbar` | 1 | — | — | yes |
| `Gtk.MenuButton` `main_menu` (`open-menu-symbolic`, primary, "Main Menu") | 1 | — | menu → `primary-menu` | yes, but packed start, not end |
| `Gtk.Button` `output_button` (`document-save-symbolic`) | 1 | — | `win.export` | yes |
| `Gtk.MenuButton` `menu_button` (title slot, `direction=none`) | 1 | `title-menu-button`, `flat` | boot `GMenu` | **CSS classes missing** |
| `Gtk.ToggleButton` `search_button` (`edit-find-symbolic`) | 1 | — | `win.search` | present, but wired to a Ruby callback instead of the action |
| `Gtk.Grid` + `Gtk.Label` title (runtime, `gl-eventtoolbar.c:139-149`) | 1+2 | `title`, `caption`, `dim-label` | — | yes, but `subtitle` used instead of `caption` |

`primary-menu` (`Gio.Menu`, 2 sections, 4 items): `app.new-window`,
`win.show-help-overlay`, `app.help`, `app.about`. Boot menu built at runtime
with `g_menu_prepend_section (boot_menu, _("Boot"), …)` and `win.view-boot`
radio items.

**Gaps**
- `title-menu-button` and `flat` on the boot button (and the whole `.title-menu-button` block in `style.css` / `style-hc.css`) are unused by the port.
- The port's primary menu is one flat section; upstream has two, so the separator between "New Window" and the rest is lost.
- The boot chooser is a `Gtk::ListBox` in a popover rather than a `Gio::Menu` of `win.view-boot` radio items, and has no `_("Boot")` section header.
- `caption` CSS class on the boot subtitle label replaced with `subtitle`.

### `data/gl-categorylist.ui` + `src/gl-categorylist.c` — the sidebar

| Widget | × | CSS | Signals | Port |
|---|---:|---|---|---|
| `Gtk.ListBox` `list_box` (`selection-mode=browse`) | 1 | `navigation-sidebar` | `row-selected` | yes |
| `Gtk.ListBoxRow` | 10 | — | — | 6 |
| `Gtk.Label` (`halign=start`) | 10 | — | — | 6 |

Rows: Important, **Alerts** (hidden), **Starred** (hidden), All, Applications,
System, Security, Hardware, **Updates** (hidden), **Usage** (hidden).

**Gap**: the four `visible=False` rows are not ported. Documented in
`category.rb` as deliberate — they are dead upstream too. Full parity would
mean four invisible rows; flagging, not recommending.

### `data/gl-eventviewlist.ui` + `src/gl-eventviewlist.c` — content pane

| Widget | × | CSS | Signals | Port |
|---|---:|---|---|---|
| `Gtk.Box` template (horizontal) | 1 | — | — | replaced by `Adw::NavigationSplitView` |
| `Adw.Flap` | 1 | — | — | replaced |
| `Gtk.Separator` `content_separator` (vertical) | 1 | — | — | **missing** |
| `Gtk.SearchBar` `event_search` | 1 | — | `notify::search-mode-enabled` | yes |
| `Gtk.Box` `search_entry_box` | 1 | `linked` | — | yes |
| `Gtk.SearchEntry` `search_entry` ("Search logs") | 1 | — | `search-changed` | yes |
| `Gtk.MenuButton` `search_dropdown_button` | 1 | — | → `GlSearchPopover` | yes |
| `Gtk.ScrolledWindow` `event_scrolled` | 1 | — | — | yes |
| `Gtk.ListBox` `entries_box` (`selection-mode=none`) | 1 | — | `row-activated` | yes |
| `Adw.StatusPage` (runtime, `action-unavailable-symbolic`, `_("No Results")`) | 1 | — | — | yes |
| `Gtk.Separator` horizontal (runtime, repeater) | N | `compressed-rows-group-separator` | — | **missing** |
| `Gtk.ListBoxRow` compressed children (repeater) | N | `compressed-row` | — | **missing** |
| row header (repeater) | N | `compressed-row-header` | — | **missing** |
| `Gtk.SizeGroup` horizontal `category_sizegroup` | 1 | — | — | yes |

Repeaters: one `GlEventViewRow` per journal entry, driven by `GlJournalModel`.
Dynamic CSS on rows: `compressed-row`, `compressed-row-header`,
`compressed-rows-group-separator`, `popover-activated-row` (added on activate,
removed on popover `closed`), and `dim-label` removed from the category and
time labels of the activated row.

**Gaps (the largest in the port)**
- **Compressed entry groups are entirely absent.** `gl-eventviewlist.c:190-350` collapses consecutive identical messages into a collapsible group with a header row, a `compressed-entries-label` count badge and group separators. Four of the app's CSS classes exist only for this and are dead in the port.
- `popover-activated-row` highlight and the `dim-label` swap on the activated row are not applied, and nothing removes them because the detail popover's `closed` signal is not connected.
- `gl_event_view_list_set_sort_order` is unported.
- The vertical separator between sidebar and content.

### `src/gl-eventviewrow.c` — one log row (no `.ui`; built in code)

| Widget | × | CSS | Notes | Port |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` template | 1 | `event` | | **`event` class missing** |
| `Gtk.Grid` | 1 | — | | yes |
| `Gtk.Label` `category_label` | 1 | `dim-label`, `event-monospace` | one of Applications / Hardware / System / Security / Other | yes |
| `Gtk.Label` `message_label` | 1 | `event-monospace` | | yes |
| `Gtk.Box` `message_box` (compressed rows only, conditional) | 1 | — | | **missing** |
| `Gtk.Label` `compressed_entries_label` (conditional) | 1 | `compressed-entries-label` | the "× N" badge | **missing** |
| `Gtk.Label` `time_label` | 1 | `dim-label`, `event-monospace`, `event-time` | blank when repeated | yes |

**Gaps**: the `event` CSS class (`.event { padding: 5px }` — the port's rows use
hand-set margins instead), the compressed-entry box and its count badge.

### `data/gl-eventviewdetail.ui` + `src/gl-eventviewdetail.c` — detail popover

`Gtk.Popover` template, `closed` → `gl_event_view_detail_popover_closed`;
`Gtk.ScrolledWindow` (min 320×300); `Gtk.Grid`, column-spacing 12, margins 12.
Ten field-label / value-label pairs, each label `detail-field-label` +
`dim-label`, each value carrying its own class:

| Field | Value CSS |
|---|---|
| Sender | `detail-comm` |
| Time | `detail-time` |
| Message | `detail-message` |
| Audit Session | `detail-audit_session` |
| Kernel Device | `detail-kernel_device` |
| Priority | `detail-priority` |
| Subject | `detail-subject` |
| Defined By | `detail-definedby` |
| Support | `detail-support` |
| Documentation | `detail-documentation` |

Plus `detailed_message_label` (`detail-message`). Upstream hides each pair when
its field is empty (`visible=False` by default).

**Gaps**: the `closed` signal (which is what clears `popover-activated-row`),
and the show/hide-per-field behaviour — the port shows all rows always, by
documented choice.

### `data/gl-searchpopover.ui` + `src/gl-searchpopover.c` — search options

Upstream: `Gtk.Popover` template, `closed` → `search_popover_closed`; a
two-page `Gtk.Stack` `menu_stack`; `popover_grid`; `parameter_stack` with
`select_parameter_button` + `Gtk.TreeView` `parameter_treeview` over
`parameter_liststore` (All Available Fields, PID, UID, GID, Message, Process
Name, Systemd Unit, Kernel Device, Audit Session, Executable Path, with
separators); `range_stack` likewise over `range_liststore` (Current Boot,
Previous Boot, Today, Yesterday, Last 3 days, Entire Journal, Set Custom
Range…); `search_type_revealer` with linked `checkbutton_substring` /
`checkbutton_exact`; and a custom-range page: `submenu_back_button` (`flat`),
`start_end_date_time_grid`, start/end `Gtk.Entry` with placeholder
`_("22 January 2016 or 1/22/2016")`, `Gtk.Revealer` + `Gtk.Calendar` each, and
**eight** `Gtk.SpinButton`s (hour, minute, second, AM/PM × start, end) with
`output`/`input`/`value-changed` handlers, plus eight `Gtk.Adjustment`s and
`Hr`/`Min`/`Sec`/`AM/PM` dim labels.

Port: `Gtk::DropDown` × 2 in place of the two `TreeView`+`Button`+`Stack`
assemblies (deliberate — `GtkTreeView` is deprecated in GTK4), both check
buttons, the revealer, the stack, both calendars, back and Apply buttons.

**Gaps**
- No time-of-day precision: the eight spin buttons, their adjustments and their `Hr`/`Min`/`Sec`/`AM/PM` labels are replaced by whole-day ranges. This is a real behaviour loss, documented in the file.
- No typed-date `Gtk.Entry` alternative to the calendars, so the `22 January 2016 or 1/22/2016` parsing path is unported.
- No `closed` handler on the popover.
- The calendars are packed directly, not inside `Gtk.Revealer`s.
- `parameter_liststore` separators are not reproduced in the dropdowns.

### `data/help-overlay.ui` — shortcuts window

`Gtk.ShortcutsWindow` → `Gtk.ShortcutsSection` → 2 `Gtk.ShortcutsGroup`
("General", "Application") → 6 `Gtk.ShortcutsShortcut`: `app.new-window`,
`win.close`, `app.help`, `win.show-help-overlay`; `win.search`, `win.export`.
Fully ported (via `Gtk::Builder`, with the binding limitation explained in the
file).

### `src/gl-application.c` — application

Actions: `app.new-window`, `app.help`, `app.about`. Accelerators: `win.close`
`<Primary>w`, `win.search` `<Primary>f`, `win.export` `<Primary>e`, `app.help`
`F1`, `app.new-window` `<Primary>n`. `adw_show_about_window` with
application-name `_("Logs")`, icon `org.gnome.Logs`, developer-name
`_("The GNOME Project")`, developers (2), designers (2),
`translator-credits`, copyright, GPL-3.0, version, website, issue-url.
Watches `org.gnome.desktop.interface` `monospace-font-name` and regenerates a
`.event-monospace` CSS fragment; watches `org.gnome.Logs` `sort-order`.
`--version` command-line option.

**Gaps**
- No `monospace-font-name` watcher, so `.event-monospace` — a class the port applies to five labels — is never defined anywhere. The log list is not monospaced.
- No `sort-order` watcher.
- No `--version` option.
- About dialog: `designers`, `developers`, `translator-credits`, `copyright`, `issue-url` all missing; `comments` is an addition not upstream.
- `app.quit` / `<Primary>q` and `win.show-help-overlay` / `<Primary>question` are **additions** beyond upstream.

### `src/gl-util.c` — no port file

12-hour and 24-hour time formats (`_("%l:%M:%S %p")` … `_("%b %e %Y %H:%M")`,
12 translated format strings), the compressed-range format `_("%s – %s")`, and
`GlUtilClockFormat` read from `org.gnome.desktop.interface` `clock-format`.
`tests/test-gl-util.c` exercises it upstream.

**Gap**: no `lib/gnome_logs/util.rb`. The port uses `strftime('%X')`
throughout, so the clock-format setting is ignored, the date-bearing formats
("Nov 2 14:03") never appear, and 12 translatable strings are unreferenced.

## Non-widget data parity

| Upstream | Port | Status |
|---|---|---|
| `data/org.gnome.Logs.gschema.xml` | present | yes |
| `data/style.css` | present | yes, but `.event-monospace`, `.event`, `.compressed-*`, `.popover-activated-row`, `.title-menu-button` rules are dead |
| `data/style-hc.css` | **absent** | high-contrast stylesheet not ported or loaded |
| `data/org.gnome.Logs.gresource.xml` | n/a | not needed (no `.ui` by design) |
| `data/org.gnome.Logs.metainfo.xml.in` | **absent** | |
| `data/org.gnome.Logs.service.in` | **absent** | D-Bus activation |
| `data/gnome-logs.xml` (man page) | present | yes |
| `data/icons/` | present | yes |
| `po/` (75 catalogues + LINGUAS + POTFILES.in) | present | yes |
| `help/` (user docs, 24 languages) | present | yes |
| `tests/test-gl-util.c` | `spec/` is **empty** | no tests at all |

## Summary of work remaining

1. `lib/gnome_logs/util.rb` — clock-format-aware time formatting (12 strings) and the `%s – %s` range format.
2. Compressed entry groups: grouping in `event_view_list.rb`, header/badge in `event_view_row.rb`, 4 CSS classes.
3. `.event-monospace` CSS from `monospace-font-name`, plus the `event` class on rows.
4. `win.view-boot` radio action and a `Gio::Menu` boot chooser with its `_("Boot")` section.
5. Sort-order plumbing: `sort-order` watcher → window → event view list.
6. `popover-activated-row` highlight and the detail popover's `closed` handler.
7. About dialog fields; `--version`; drop the non-upstream `app.quit`.
8. `style-hc.css`, `metainfo.xml`, `service` file.
9. Search popover: spin-button time precision, date entries, revealers.
10. A spec suite — none exists.
