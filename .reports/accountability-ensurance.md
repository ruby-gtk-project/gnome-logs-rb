# Accountability ensurance — gnome-logs-rb

Grepped `lib/`, `exe/`, `.reports/`, `FINDINGS.md`, and confirmed no
`PORTING.md` exists in this tree, for `TODO`, `FIXME`, `not implemented`,
`for now`, `in a future`, `out of scope`, `n/a`, `not applicable`, `dropped
deliberately`, `by design`, `simplified`, `does not carry over`, `skipped`,
and `deliberate`.

`lib/` and `exe/` are clean of all of these — no hit in source code or
comments. **The violations are all in `.reports/component-inventory.md`**,
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

## The false-green this round found and is now recording, not excusing

**`drive_ok=true`, 126/126 checks, 0 failed is not the same claim as "the test
suite passed."** `test/drive_gnome_logs.rb`'s own header comment states, in
plain honest language that itself passes this skill's bar, that
`spec/spec_helper.rb` "currently cannot load at all in this checkout" — and
this round independently reproduced that exact failure (`LoadError: cannot
load such file -- kettle/test/rspec`, 0 examples run). That sentence is
*correctly* unvarnished; it is not the thing being flagged here. What is being
flagged: **nowhere outside that one code comment is this written down.**
`FINDINGS.md` has no entry for it. No `.reports/` file before this round's
`test-parity.md` recorded it. A runtime gate reporting "126 checks passed, 0
failed" with no asterisk is exactly the shape of false-green this skill
exists to catch, even though no one *lied* about it — the gate's own numbers,
read without `test/drive_gnome_logs.rb`'s source comment, assert a passing
test suite that has never once executed. The gate is honest about what it
ran; the gap is that what it ran was quietly substituted for what it claims,
and the substitution was legible only inside a code comment, not in any
report a reviewer would read first.

## What this means for `clean: true`

It cannot be `true`. Independent of the component/test/translation gaps
found elsewhere in this audit, `.reports/component-inventory.md` itself
— the port's own primary parity record — contains six instances of exactly
the pattern this skill exists to kill, and the test-suite's never-having-run
was not recorded anywhere a reviewer would see before this round forced it
into a report.
