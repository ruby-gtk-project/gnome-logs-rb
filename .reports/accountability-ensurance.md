# Accountability ensurance — gnome-logs-rb

Grepped `lib/`, `exe/`, `.reports/`, `FINDINGS.md`, and confirmed no
`PORTING.md` exists in this tree, for `TODO`, `FIXME`, `not implemented`,
`for now`, `in a future`, `out of scope`, `n/a`, `not applicable`, `dropped
deliberately`, `by design`, `simplified`, `does not carry over`, `skipped`,
and `deliberate`.

**This round found one hit inside `lib/` itself** that prior rounds' same
grep missed: `lib/gnome_logs/util.rb:15`, `# Two deliberate differences from
the C version:`, introducing the comment that documents `Time#strftime`
losing locale-awareness for `%b`/`%p`. The underlying technical content is
accurate and worth having as a comment. But "deliberate" is exactly the
forbidden register this skill exists to catch, and it did real damage here:
the difference it waves past is a genuine runtime i18n regression (every
timestamp in the app renders its month name and AM/PM marker in English in
every non-English locale), and calling it "deliberate" is what let it sit
undocumented in any `.reports/` parity file until this round — "deliberate"
reads as "considered and accepted," not "found and flagged." It is now
written up as a real gap in `component-parity.md` (the `gl-util.c` row,
downgraded from `parity` to **gap**) and `translation-parity.md`. Rewritten
per the skill's rule:

> I wrote "two deliberate differences from the C version" over a comment
> whose second item is a full-app locale regression (English month names and
> AM/PM markers for every non-English user, in every timestamp the app
> shows), because I am an idiot who reached for "deliberate" instead of just
> stating what breaks and letting a parity report catch it. It sat in a code
> comment with no report entry for at least three prior audit rounds.
> Upstream: `gl_util_timestamp_to_display` → `g_date_time_format`, locale
> aware. Port: `lib/gnome_logs/util.rb:78-84` → `Time#strftime`, not locale
> aware for `%b`/`%p`.

**A second, separate finding in the same file's prior parity report:**
`component-parity.md`'s `gl-util.c` row (as it read before this round)
claimed `_("%s – %s")` "has no caller anywhere in the port — built but
unused." This round traced the call graph and found that claim is simply
false: `Util.boot_time_to_display` (which formats with `'%s – %s'`) is
called by `Journal::Boot#display_name`, which is called by
`event_toolbar.rb` to build the boot label and every boot menu item. This is
not a register problem like the others in this file — it is a factual error
that understated the port's real coverage, caught only because this round
re-derived the claim from source with `grep -rn` instead of trusting the
prior report. Corrected in `component-parity.md` this round.

**A third factual error, same pattern as the second:** `component-parity.md`'s
`gl-window.c` row claimed `_('Unable to read user logs')` is "never shown."
This round traced `check_journal_storage` against both the port and
upstream's `gl_window_init`'s storage-type `switch` and found the claim
false — the port shows that exact message, standalone, whenever storage is
persistent, the system journal is readable, and the user journal is not
(ordinary on a system where the user isn't in `systemd-journal`). Upstream's
own switch has the identical single-label overwrite behaviour when both
checks fail, so this was never a port-specific regression. Corrected in
`component-parity.md`, which also now records the real, previously
unreported divergence this tracing surfaced: the port's `check_journal_access`
adds an `entries.empty?` branch upstream's switch does not have.

Three factual errors in one parity report, all caught only by re-deriving
each claim from source rather than trusting the report's prior language, is
itself the accountability finding: a parity report with confident, specific
wrong claims is worse than one that says "unverified," because it reads as
checked when it was not.

**The remaining violations are all in `.reports/component-inventory.md`**,
the parity document a prior round of this same audit wrote.

## Findings, rewritten per the skill's own rule

### `.reports/component-inventory.md:262`

> ~~`data/org.gnome.Logs.gresource.xml` | n/a | not needed (no `.ui` by
> design)~~

This reads as a closed decision. It is not one — it is an unexamined claim
that a `.gresource.xml` has no job once there is no `.ui`. Becomes:

> I marked `data/org.gnome.Logs.gresource.xml` "not needed" without checking
> whether upstream's resource bundle carries anything besides compiled `.ui`
> XML — icons, the CSS files, the gschema — that this port's own `data/`
> directory might still need bundled the same way for installation, because I
> am an idiot who wrote "by design" instead of opening the file.
> Upstream: `data/org.gnome.Logs.gresource.xml.in` (verify contents directly).
> Port: no resource bundle of any kind.

### `.reports/component-inventory.md:104-105`

> ~~the four `visible=False` rows are not ported. Documented in `category.rb`
> as deliberate — they are dead upstream too. Full parity would mean four
> invisible rows; flagging, not recommending.~~

The underlying technical claim here checked out in this audit (`component-parity.md`
confirmed the 4 rows are inert upstream too and rules this out as a non-gap).
But "documented... as deliberate" and "flagging, not recommending" are still
the forbidden register — they ask a future reader to treat this as settled
rather than re-verify it. Becomes:

> I called four unported sidebar rows "deliberate" instead of just proving
> they're dead upstream and moving on, because I am an idiot who reached for
> a decision-word when a fact would have done the same job with no risk of
> being read as permission for the next gap that isn't actually dead code.
> Upstream: `data/gl-categorylist.ui`, four rows `visible="False"` with no
> runtime unhide path in `src/gl-categorylist.c` — verified this round.
> Port: `category.rb` builds the 6 live rows only.

### `.reports/component-inventory.md:134` (and the repeated "fixed this round" pattern)

> ~~fixed this round: `event_view_row.rb`'s `activate` adds the class...~~

"Fixed this round" appears as the closing phrase on nine separate gap rows in
this file, each one struck through and marked fixed by the same agent that
wrote the original gap, with no independent re-verification before the next
round trusted it. This round independently re-verified the `win.view-boot`
action, the primary-menu sections, and the compressed-entry groups and found
them actually present — so these specific "fixed" claims hold up. But the
*pattern* is the thing to flag: a report that marks its own prior claims
"fixed" is grading its own homework, and nothing in this file's history shows
anyone checking that before this round. Becomes:

> I wrote "fixed this round" nine times across two prior rounds without this
> round's agent re-deriving any of it from upstream source until a parity
> audit forced the re-check, because I am an idiot who treated my own
> yesterday's claim as evidence instead of re-reading the C.
> This round re-verified: `win.view-boot`, the primary-menu two-section
> split, the boot `Gio::Menu`, the monospace-font watcher, the sort-order
> watcher, and the compressed-entry groups all independently check out
> against `origin/master` as of this round. The habit, not the content, is
> the finding.

### `.reports/component-inventory.md:134` continued — the compressed-group separator

> ~~`EventViewList#toggle_group` ports the expand/collapse branch... (simplified:
> it does not replicate the C version's extra checks for what a *neighbouring*
> compressed group's separator should do, since two groups sitting back-to-back
> is not exercised by anything in this port).~~

This is the exact pattern the skill's own worked example (`console-rb`) was
built to catch: "simplified" sits in the same sentence as the missing
behaviour, reframing an admitted gap as an engineering trade-off. Becomes:

> I did not replicate what happens when two compressed entry groups sit back
> to back in the log list — whether the separator between them doubles up,
> disappears, or renders wrong — because I am too stupid to have written the
> test case that would have told me, and said "simplified" instead of just
> saying the behaviour is unverified.
> Upstream: `gl_journal_model_add_header`, `src/gl-journal-model.c:190-350`.
> Port: `lib/gnome_logs/event_view_list.rb`, `toggle_group` /
> `apply_headers`. Untested: adjacent-group separator interaction.

### `.reports/component-inventory.md:197-199`

> ~~Port: `Gtk::DropDown` × 2 in place of the two `TreeView`+`Button`+`Stack`
> assemblies (deliberate — `GtkTreeView` is deprecated in GTK4)~~

The underlying technical judgment (don't reproduce a deprecated GTK3-era
widget) is fine and this audit's own `component-parity.md` keeps it as a
rule-out, not a gap. The word "deliberate" is still the forbidden register —
it's doing the same "approved decision" work as every other hit on this list,
even where the decision turns out to be correct. Becomes:

> I called the `GtkTreeView` replacement "deliberate" instead of just stating
> that `GtkTreeView` is deprecated in GTK4 and leaving it at that, because
> calling anything "deliberate" in this file is how the next gap next to it
> gets read as equally considered.
> Upstream: `data/gl-searchpopover.ui`, two `Gtk.TreeView`+`Gtk.ListStore`
> assemblies. Port: two `Gtk::DropDown`s, `lib/gnome_logs/search_popover.rb`.

## The false-green a prior round found, and what has changed since

A prior round of this audit found a real false-green: `drive_ok=true`,
126/126 checks, 0 failed, while the RSpec suite had never once executed
(`LoadError: cannot load such file -- kettle/test/rspec`, 0 examples). That
round correctly refused to call it closed and wrote it into `test-parity.md`
as the single most important line in that report.

**This round, commit `6501e6b` ("Make the spec suite runnable in the nix dev
shell") fixed the underlying cause** — `spec_helper.rb` now rescues the
missing `kettle-test` dependency instead of dying on it — and this round
independently re-ran both the spec command and the driver, from the banner,
with no reliance on the commit message's own claim:

```
85 examples, 0 failures     (spec suite, re-run this round)
126 of 126 checks passed    (driver, re-run this round)
DRIVE OK
```

Both reproduce. The false-green is closed for the specific claim it was
raised against: the 1/1 ported upstream test (`/util/timestamp_to_display`)
now runs and passes inside an 85-example suite that executes, not a dormant
file. `test-parity.md` records the remaining open edge (the `kettle-test` gem
itself is still not actually installed in the shell; the fix is a rescue
around that, not a resolution of it) rather than calling the dependency
problem solved outright — see that report for the distinction.

## What this means for `clean: true`

It still cannot be `true`. The test-suite false-green is now closed and
verified, but `.reports/component-inventory.md` — the port's own primary
parity record — still contains the six instances of exactly the pattern this
skill exists to kill, documented above and not re-written by this round
(rewriting another report's prose is not this skill's job; flagging it is).
Independently, `component-parity.md` and `translation-parity.md` both record
real, unresolved content gaps (the search popover's time-of-day controls, the
detail popover's unconditional field display, 32 confirmed-missing msgids)
that have nothing to do with the test-runner fix and were not touched by it.
