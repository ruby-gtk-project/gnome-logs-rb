# Test parity — gnome-logs-rb

| | |
|---|---|
| Upstream | `origin/master` @ `45f9646` |
| Port | `ruby` @ `6501e6b` |
| Upstream tests | 1 (`/util/timestamp_to_display`, 6 inline cases) |
| Ported | 1 / 1 |
| Gaps | 0 |
| **Does the port's suite run at all?** | **Yes, as of `6501e6b` — independently re-run this round.** See below for what that commit fixed and what this round verified directly, not from the commit message. |

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

## History: the gap a prior round of this ledger found, and what closed it

A prior round of this audit (reports at `4395dab`/`43a56c5`) found that
`spec/spec_helper.rb` hard-required `kettle/test/rspec`, a dev dependency not
installed in the fork's `nix develop` shell, so the entire suite errored
before a single example ran:

```
Failure/Error: require "kettle/test/rspec"
LoadError: cannot load such file -- kettle/test/rspec
No examples found.
0 examples, 0 failures, 2 errors occurred outside of examples
```

That round correctly refused to count the ported test as `ported` while it
could not execute, and flagged the then-current `drive_ok=true, 126/126` as a
false-green: the driver passed, but the thing a reviewer would assume "passed"
means — the RSpec suite — had never run once.

Commit `6501e6b` ("Make the spec suite runnable in the nix dev shell")
rescues that specific `LoadError` in `spec_helper.rb` (falling back to plain
RSpec, the same pattern `tally-rb` uses) and swaps a `kettle-test`-only
matcher (`be_in`) in `util_spec.rb` for a plain `include` assertion. **This
round re-ran both commands directly, not trusting the commit message:**

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
NOTE: kettle-test isn't installed; running with plain RSpec.
.....................................................................................
85 examples, 0 failures

$ nix develop --command xvfb-run -a ruby test/drive_gnome_logs.rb
126 of 126 checks passed
DRIVE OK
```

Both reproduce exactly as claimed. The fix is real, not a report claiming a
fix. `/util/timestamp_to_display`'s 6 cases are now part of an 85-example run
that actually executes, so the 1/1 test-parity claim is now backed by an
executed test, not a dormant file.

## What is still a gap

- **The `kettle-test` dev dependency is still broken, not removed.** The fix
  is a rescue around the symptom (`spec_helper.rb` degrades to plain RSpec
  when the gem is missing), not a fix of why `nix develop`'s gem set excludes
  a declared dependency, nor of the separate `bundle check`/`bundle install`
  `Bundler::Dsl::DSLError` a prior round hit against the Nix-provided
  `Gemfile` wrapper. That second failure was not re-tested this round because
  the banner's own recommended command (the `ruby -e` form, not `bundle exec`)
  is what actually runs the suite and was what this round verified; whether
  `bundle install` itself now works in this shell is untested and should not
  be assumed fixed by this commit, which touches no `Gemfile`/gemspec.
- **No CI or Rake task runs either command.** Both the spec suite and the
  driver are things a human (or an audit round) must remember to invoke by
  hand from the banner text. Nothing fails a build if either regresses again.

## Rules applied

- A ported test is only credited as `ported` once this round independently
  re-executed it and watched it pass — not on the strength of a commit
  message or a prior round's report.
- The 126 driver checks are not double-counted as the 1 upstream test's parity
  — they are `## Extra`, same as the rest of the driver's coverage.
