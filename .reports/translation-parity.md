# Translation parity — gnome-logs-rb

| | |
|---|---|
| Upstream | `origin/master` @ `45f9646` |
| Port | `ruby` @ `4395dab` |
| Upstream messages | **128** distinct `(msgctxt, msgid)` keys, 161 occurrences, 8 with context, 0 plural, 3 unresolved (dynamic marker arguments the census can't read as a literal) |
| Languages | 72, carried over **unchanged** — `po/LINGUAS` and all 72 `.po` files are byte-identical to upstream's, same 8,079 translated / 237 untranslated / 0 fuzzy |
| Port messages, by the official census tool | **12** |
| Port messages, confirmed present by direct `grep -F` verification (below) | 96 |
| Confirmed, genuinely absent from the port's source at all | **32** |

## Why there are three numbers, not one

`msgid-census.sh`/`catalogue.rb` (this skill's own tooling, also what any
stock `xgettext`-style scanner would do) recognize `_(`, `N_(`, `gettext(`,
`C_(`/`NC_(`/`pgettext(`, and `ngettext(`/`n_(` as gettext markers. **The
port's house translation wrapper is `t(message)`** —
`lib/gnome_logs/translation.rb`:

```ruby
def t(message) = Translation.translate(message)
def self.translate(message) = _(message)
```

`t` is not a recognized keyword by any of those tools, so the official,
tool-run census undercounts by roughly 90%: it finds only the handful of call
sites that happen to use `_(` directly rather than the house `t(`. **This is
not a false alarm to wave away — it means the port has configured no working
pipeline to ever regenerate its own `.pot`.** There is no `po/Makevars`, no
meson `i18n.gettext(... args: ['--keyword=t'])` equivalent, and no Rake task
in `Rakefile` that calls `xgettext`/`rxgettext`/`rmsgfmt` at all (verified:
`grep -n 'gettext\|xgettext' Rakefile` returns nothing). If a translator adds
a string today, nothing in this tree will ever notice it needs extracting.

Separately, and more importantly for what a user actually sees: strings
reached through `t()` with a literal argument *do* work correctly at runtime,
because `Translation.translate` calls real `_()` underneath and the lookup is
by string content, not by which Ruby method wrapped it. So the runtime
behaviour and the tooling-visible catalogue are two different questions, and
this report answers both.

## The real content census, verified string by string

A first pass compared upstream's 128 msgids against a regex sweep of every
string literal in `lib/**/*.rb` and `data/*`. That regex mis-paired quote
characters across comments containing apostrophes (e.g. "don't"), which
silently shifted literal boundaries for the rest of each affected file and
produced false "missing" results for strings that are actually present:
`Back`, `Exact`, `Substring`, `No Results`, `Search logs`,
`translator-credits`, `Show Logs Starting From…`, `Until…`, `Log Viewer`,
`%s – %s`, and `Unable to export log messages to a file` were all flagged
missing by the regex and are in fact present (most behind `t()`).

Every one of the 48 regex-flagged candidates was then re-checked individually
with a plain `grep -F` for its exact text across `lib/` and `data/`. 16 were
the false positives above. **The following 32 produced no match anywhere —
confirmed genuinely absent from the port's source, under any name:**

```
%I:%M:%S %p                                 Select Start Date…
%T                                           Select Start Time…
%e %B %Y                                    Select Timestamp Range of the Log
22 January 2016 or 1/22/2016                  Entries to be shown
AM                                           Select a Journal Field to filter
AM/PM                                          the Logs according to it
From %s                                     Select a start date
Hr                                           Select an end date
Min                                          Select end time
Sec                                          Select journal field and timestamp
Parameters                                    range filtering options
Print version information and exit          Select start time
Match complete string only                  Show Logs from…
Match in any part of the string             Until %s
Select End Date…                            Yesterday
Select End Time…                            log;journal;debug;error;
Select Journal Field…                       Logs shows events from the systemd
                                               journal, and sorts them into
                                               categories, such as hardware and
                                               applications.
                                             Using Logs you can search your logs
                                               by typing a search term, and view
                                               detailed information about each
                                               event by clicking on it.
                                             Whether to ignore the warning that
                                               says you don't have sufficient
                                               permission to view logs. If
                                               ignored, the warning won't show
                                               up again.
```

Each maps onto a component gap already named in `component-parity.md`:

- `AM`/`PM`-adjacent (`AM`, `AM/PM`, `Hr`, `Min`, `Sec`) and the format strings
  `%I:%M:%S %p`/`%T`/`%e %B %Y` → the 8 unbuilt `Gtk.SpinButton`s and
  `Gtk.Adjustment`s for time-of-day precision in the search popover's custom
  range. (Note `PM` alone, unlike `AM`, happens to appear as a substring of
  other port text and was excluded from this list as ambiguous by a
  substring-only check; it was not independently confirmed built, and should
  be treated as equally likely missing — the time-of-day control it belongs
  to is entirely unbuilt either way.)
- `22 January 2016 or 1/22/2016` → the unbuilt typed-date `Gtk.Entry`
  alternative to the calendars.
- `Select Start/End Date…/Time…`, `Select a start/end date`, `Select
  start/end time`, `Select journal field and timestamp range filtering
  options`, `Select a Journal Field to filter the Logs according to it`,
  `Select Timestamp Range...`, `Until %s`, `Show Logs from…`, `Yesterday` →
  search-popover strings (tooltips, accessible descriptions, and custom-range
  controls) for UI elements the port does not build or does not label.
- `Match complete string only` / `Match in any part of the string` → tooltip
  text for the substring/exact search-type checkboxes; the checkboxes exist
  (`Substring`/`Exact` are both present) but these two accessible-description
  strings are not.
- `Parameters` → a label inside the search popover's field-picker page not
  found anywhere in `search_popover.rb`.
- `Print version information and exit` → the missing `--version` CLI option,
  already named as a gap in `component-parity.md`.
- `From %s` → a label format the port's boot/date summary does not build.
- `log;journal;debug;error;`, `Logs shows events from the systemd journal...`,
  `Using Logs you can search your logs...` → `.desktop`/`.metainfo.xml`
  keywords and description text. `component-identification.md` lists
  `data/org.gnome.Logs.desktop` and `data/org.gnome.Logs.metainfo.xml` as
  "present", but present means the file exists — these three strings
  specifically are not in it, so "present" overstated completeness for this
  file. A full line-by-line diff of the XML bodies against upstream's
  `.desktop.in`/`.metainfo.xml.in` was not done beyond this grep; there may be
  more such gaps inside files this audit marked "present" elsewhere.
- `Whether to ignore the warning that says you don't have sufficient
  permission to view logs. If ignored, the warning won't show up again.` →
  the GSettings schema's `<summary>`/`<description>` for the ignore-warning
  key; `data/org.gnome.Logs.gschema.xml` is present as a file but this
  specific description text is not in it.

## Rules applied

- Byte-identical or gap: no string above was counted as ported because an
  approximately matching Ruby string exists nearby. None were found close
  enough to be ambiguous, except the one `PM` case flagged explicitly above,
  which is left open rather than silently resolved either way.
- The 72-language carry-over is real and is **not** credited as full parity
  on its own — "the languages come with it" is one of three required claims,
  and the key-set claim fails, so overall parity fails regardless of how
  clean the `po/` carry-over is.
- The `t()`-vs-`_()` tooling gap is recorded as its own finding, separate
  from the 32 confirmed-missing strings, because conflating "untooled" with
  "untranslated" would understate the 32 real content gaps and overstate the
  rest.
- The 4 hidden sidebar rows (`Alerts`, `Starred`, `Updates`, `Usage`) are
  **not** counted as translation gaps, consistent with `component-parity.md`:
  upstream itself never shows them under any build configuration found in
  this audit, so there is no live string to carry over.
