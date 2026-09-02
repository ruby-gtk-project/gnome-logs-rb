Findings: ruby-gnome GTK4 bindings
==================================

Issues hit while porting GNOME Logs from C to Ruby. Everything below was
reproduced against the exact versions in this repo's `gemset.nix`, with the
minimal repro shown. The last two sections matter as much as the first: they
record things that *look* like bugs but are not, so nobody "fixes" them later.

    gtk4 gem              4.3.8
    adwaita gem           4.3.8
    glib2 gem             4.3.8
    gobject-introspection 4.3.8
    libgtk                4.22.4
    libadwaita            1.9.3
    ruby                  3.4.9

Reproduce any of these with `nix develop --command ruby -e '...'`.


1. GtkShortcutsWindow, Section and Group cannot be instantiated
--------------------------------------------------------------

**Severity: blocking.** These three classes are unusable from Ruby.

    require 'gtk4'
    Gtk::ShortcutsWindow.new
    # TypeError: GtkWindow is not subtype of GtkShortcutsWindow

    Gtk::ShortcutsSection.new
    # ArgumentError: wrong number of arguments (given 0, expected 1..2)
    Gtk::ShortcutsSection.new(:vertical, 0)
    # TypeError: GtkBox is not subtype of GtkShortcutsSection

    Gtk::ShortcutsGroup.new(:vertical, 0)
    # TypeError: GtkBox is not subtype of GtkShortcutsGroup

`Gtk::ShortcutsShortcut.new` works; only the three container classes fail.

**Cause.** None of these types declare their own constructor in the GIR, so
ruby-gnome inherits `initialize` from the parent binding — `Gtk::Window` for
the window, `Gtk::Box` for the section and group. The inherited initializer
calls the *parent's* C constructor, producing a `GtkWindow`/`GtkBox`, and the
subsequent type check rejects it. The `expected 1..2` arity is the giveaway:
that is `Gtk::Box.new(orientation, spacing)` showing through.

In C these are built with `g_object_new`, which the bindings do not fall back
to when a GIR constructor is absent.

**Workaround.** GtkBuilder instantiates them without complaint, so describe
the window in interface XML and pull it out:

    Gtk::Builder.new(string: '<interface><object class="GtkShortcutsWindow" id="w"/></interface>')
                .get_object('w')
    # => Gtk::ShortcutsWindow

`lib/gnome_logs/shortcuts_window.rb` does this, generating the XML from a Ruby
table so the shortcut list is still declared as data rather than markup.


2. g_markup_escape_text is not bound
------------------------------------

**Severity: minor, but a correctness trap.**

    GLib.markup_escape_text('a<b')
    # NoMethodError: undefined method 'markup_escape_text' for module GLib
    GLib::Markup
    # NameError: uninitialized constant GLib::Markup

    GLib.methods.grep(/escape|markup/)   # => []

Nothing in `GLib` or `Gtk` escapes markup. `GLib::Regex.escape_string` exists,
which is unrelated and will not help.

This matters because `Gtk::Label#use_markup = true` parses its label as
markup, so any interpolated value needs escaping first. Without a binding the
obvious code is silently wrong on data containing `&` or `<` — and log
messages contain both constantly.

**Workaround.** Escape the five XML entities by hand; see `ESCAPES` in
`lib/gnome_logs/event_view_detail.rb`.


3. GLib::DateTime has no to_time or to_unix
-------------------------------------------

**Severity: minor.** You cannot get a Ruby `Time` or an epoch integer directly.

    d = Gtk::Calendar.new.date       # => GLib::DateTime
    d.to_time                        # NoMethodError
    d.to_unix                        # NoMethodError
    d.to_local                       # NoMethodError

The bound surface is: `copy day_of_month format format_iso8601 gtype hour
minute month second year`. `g_date_time_to_unix` and `g_date_time_to_local`
are both absent.

**Workaround.** `format` reaches strftime, so either works:

    Time.at(Integer(d.format('%s')))
    Time.parse(d.format_iso8601)     # "2026-09-02T16:19:33.339167+01"

Building a `Time` from the extracted components is fine too, but drops the
offset, so only do it when you want a local wall-clock time — which is what
`SearchPopover#midnight` wants.


4. g_action_group_list_actions is not bound
-------------------------------------------

**Severity: cosmetic.** There is no way to enumerate a `GActionGroup`'s
actions, on `Gtk::ApplicationWindow`, `Gtk::Application`, or
`Gio::SimpleActionGroup`:

    g = Gio::SimpleActionGroup.new
    g.insert(Gio::SimpleAction.new('demo'))
    g.respond_to?(:list_actions)     # => false
    g.respond_to?(:action_names)     # => false

Everything else on the interface is bound — `has_action?`, `lookup_action`,
`query_action`, `activate_action`, `get_action_enabled`. Only enumeration is
missing. Query a known name instead; this only bites while testing.


5. Confusing error for a missing version constant
-------------------------------------------------

**Severity: cosmetic.**

    Gtk::MAJOR_VERSION
    # NameError: uninitialized constant Gtk::MAJOR_VERSION
    #   from glib2/deprecatable.rb:112:in 'GLib::Deprecatable#const_missing'

The constant lives at `Gtk::Version::MAJOR`. The frame pointing into
`Deprecatable#const_missing` suggests a deprecation rather than a plain typo,
which sends you looking in the wrong place.


Not bugs — conventions that look like bugs
------------------------------------------

**`get_` is dropped only for zero-argument getters.** `Gtk::ListBox#row_at_index`
does not exist, and it is tempting to call that a gap. It is not: ruby-gnome
strips the `get_` prefix for property-like accessors and keeps it for methods
that take arguments. This is consistent across the API:

    Gtk::ListBox#selected_row          ✓    #get_selected_row            ✗
    Gtk::ListBox#get_row_at_index      ✓    #row_at_index                ✗
    Gtk::ListBox#get_row_at_y          ✓    #row_at_y                    ✗
    Gtk::Grid#get_child_at             ✓    #child_at                    ✗
    Gtk::Widget#parent                 ✓    #get_parent                  ✗
    Gtk::Widget#get_ancestor           ✓    #ancestor                    ✗
    Gtk::TextView#get_iter_at_location ✓    #iter_at_location            ✗

Same for `get_action_enabled` in section 4: it takes an action name, so it
keeps the prefix.

**`Gtk::InfoBar` is still bound** despite being deprecated in GTK 4.10.
`add_child`, `add_button`, `revealed=` and the `response` signal all work.


Correction to the bundled ruby-gtk skill
----------------------------------------

The skill's `references/adwaita-quirks.md` states that `Adwaita::Application`
and `Adwaita::ApplicationWindow` are "BROKEN — DO NOT USE", with the advice to
substitute `Gtk::Application` and `Gtk::ApplicationWindow`.

**That is no longer true at adwaita 4.3.8 / libadwaita 1.9.3.** A full
lifecycle — construct, assign an Adwaita `content`, present, query — succeeds:

    app = Adwaita::Application.new('org.example.t', :default_flags)
    app.signal_connect('activate') do
      win = Adwaita::ApplicationWindow.new(app)
      win.content = Adwaita::ToolbarView.new    # note: content=, not child=
      win.present
      # => visible: true, app.windows.size: 1
    end
    app.run([$PROGRAM_NAME])

Note `content=` rather than `child=`; `AdwApplicationWindow` overrides the
child property, and passing `child=` is a likely source of the original
"broken" diagnosis.

This port still uses `Gtk::Application` + `Gtk::ApplicationWindow`, per the
skill. That combination works and is not worth churning; but new code need not
avoid the Adwaita classes, and the skill's quirks reference should be
re-verified against current gem versions rather than trusted outright.


Adjacent: GetText binds a text domain per class, and `extend` loses it
---------------------------------------------------------------------

Not a GNOME binding issue, but it cost the most time here, and any GTK app
using the `gettext` gem will hit it.

`bindtextdomain` binds the domain to the class or module that calls it, and a
lookup finds that binding by walking the ancestors of `self.class`. So a
module that binds the domain passes it on through `include` — where `self` is
an instance and the module is in `self.class.ancestors` — but **not** through
`extend`, where `self` is the class itself and the module sits in the
singleton ancestry, which is never consulted.

The failure is silent: the lookup resolves in an unbound domain and returns
the msgid, so those strings come out in English with no error anywhere.

    module Translation
      include GetText
      bindtextdomain('gnome-logs', path: ...)
      module_function
      def t(message) = _(message)
    end

    Translation.t('Important')            # => "Wichtig"   direct call, fine

    class Instance
      include Translation                 # instance methods
      def title = t('Important')          # => "Wichtig"   fine
    end

    class Klass
      extend Translation                  # class methods
      def self.title = t('Important')     # => "Important" SILENTLY UNTRANSLATED
    end

That asymmetry is what makes it nasty: most of an app translates correctly
while the few classes using class-level helpers do not, which reads like a
missing msgid rather than a binding problem. Here it was `Category`, whose
titles are built by class methods — the sidebar stayed English while every
other string translated.

**Fix.** Do not rely on `include`/`extend` to carry the binding. Have every
lookup delegate to the single module that bound the domain, which then works
identically for both:

    module Translation
      extend GetText
      bindtextdomain('gnome-logs', path: ...)
      def t(message) = Translation.translate(message)
      def self.translate(message) = _(message)
    end

See `lib/gnome_logs/translation.rb`.

A second trap while diagnosing this: `Gtk::Application` with `:default_flags`
registers a D-Bus name, so relaunching while an older instance is alive
*remote-activates that instance* and exits 0 immediately. A stale process will
happily serve screenshots of code you replaced ten minutes ago. Confirm with
`pgrep -f` before concluding a fix did not work.
