# Test parity — gnome-logs-rb

| | |
|---|---|
| Upstream | `origin/master` @ `45f9646` |
| Port | `ruby` @ `4395dab` |
| Upstream tests | 1 (`/util/timestamp_to_display`, 6 inline cases) |
| Ported | 1 / 1 |
| Gaps | 0 |
| **But: does the port's suite run at all?** | **No.** See below. |

## Census

Upstream's entire test suite is `tests/test-gl-util.c`, registered as a single
`g_test_add_func("/util/timestamp_to_display", ...)` that loops over 6 inline
cases (3 for 12-hour format, 3 for 24-hour format: same day / same year /
different year). `tests/meson.build` builds and runs exactly this one
executable. There is no other upstream test file.

| Upstream test | Cases | Port test | Verdict |
|---|---|---|---|
| `/util/timestamp_to_display` | 6 | `spec/gnome_logs/util_spec.rb`, `describe '.timestamp_to_display'`, 6 `it` blocks matching each case's microseconds/format/expected-string triple exactly (including the U+2007 figure-space padding) | **ported** |

1/1 upstream test has a named port counterpart pinning the same six cases.
Test-count parity is met.

## Extra

`spec/gnome_logs/util_spec.rb` also covers, with no upstream counterpart:
`show_second: true`, sub-second truncation, clock-format fallback,
`.boot_time_to_display`, `.compare_timestamps` (3 cases), `.clock_format`
(2 cases), `.uid`, `.machine_id` (3 cases), `.journal_storage_type` (2 cases),
`.system_journal_path` (3 cases), `.can_read_user_journal?`. These are welcome
and do not count toward the 1/1 above.

`test/drive_gnome_logs.rb` drives the running app headlessly: 126 named
`check(...)` assertions this round, covering window construction, the sidebar,
search bar/popover, event list, detail popover, boot menu, primary menu,
shortcuts window, actions/accelerators, the InfoBar error states, and
`GnomeLogs::Catalog`/`Util`/`JournalEntry`/`Query` display-free logic run as
plain checks (its own header comment says why: see next section). This is
extra, not upstream-test parity — upstream has no app-driver equivalent to map
these to.

## The gap this ledger exists to catch: **the ported test has never actually passed**

`spec/spec_helper.rb` does `require "kettle/test/rspec"`. That gem is declared
as a development dependency in `gnome-logs-rb.gemspec` (`kettle-test`, `~> 2.0`)
but is **not installed** in the fork's own `nix develop` shell — the shell's
own `bundle check`/`bundle install` fail first, independent of `kettle-test`,
because the Nix-provided `Gemfile` wrapper can't find a gemspec at the path it
substitutes in:

```
Bundler::Dsl::DSLError: There was an error parsing `Gemfile`:
There are no gemspecs at /nix/store/.../gemfile-and-lockfile.
```

Running the banner's own documented spec command,

```
xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
```

produces, verified this round:

```
Failure/Error: require "kettle/test/rspec"
LoadError: cannot load such file -- kettle/test/rspec
No examples found.
0 examples, 0 failures, 2 errors occurred outside of examples
```

**Zero examples run. The 1/1 test-parity claim above is a claim about a file
that has never been executed in this environment, by either `bundle` or the
raw `ruby -e` the dev shell itself recommends.** The port's own
`test/drive_gnome_logs.rb` says so out loud in its header comment — "the specs
under spec/ are meant to cover the display-free half... spec/spec_helper.rb
currently cannot load at all in this checkout" — and compensates by
duplicating `Util`/`JournalEntry`/`Query`/`Catalog` assertions as driver
`check()`s instead. That compensation is real coverage (it is inside the
126/126 that passed), but it is not the ported RSpec test, and the ported
RSpec test file sitting unexecuted in the tree is a gap on its own:
**a test that has never run is unverified code wearing the shape of a pass.**

This is the single most important line in this report: **drive_ok=true and
126/126 does not mean the test suite passed. It means the test suite was never
run, and a different, non-upstream-mapped driver script passed instead.**

## Rules applied

- A ported test that cannot be executed is not `ported`, it is a gap plus a
  tooling defect, per the skill's own rule ("a test that cannot be made to
  pass is a gap plus an issue, not a comment-out"). Recorded here as the gap;
  the `kettle-test` / Nix-Gemfile defect is the reason it is hard, not a
  reason to call it closed.
- The 126 driver checks are not double-counted as the 1 upstream test's parity
  — they are `## Extra`, same as the rest of the driver's coverage.
