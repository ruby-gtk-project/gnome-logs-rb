# frozen_string_literal: true

module GnomeLogs
  # The popover shown when a log row is activated. Ports GlEventViewDetail:
  # a two-column grid of field name / field value pairs followed by the full,
  # wrapped message and the catalog explanation.
  #
  # Every row is shown unconditionally rather than hidden when its field is
  # empty, so the popover never changes size between entries.
  class EventViewDetail
    include Translation

    ROWS = [
      ['Sender', :sender_label],
      ['Time', :time_label],
      ['Message', :message_label],
      ['Audit Session', :audit_label],
      ['Kernel Device', :device_label],
      ['Priority', :priority_label],
      ['Subject', :subject_label],
      ['Defined By', :definedby_label],
      ['Support', :support_label],
      ['Documentation', :documentation_label]
    ].freeze

    def initialize(entry, catalog)
      @entry = entry
      @catalog = catalog
    end

    attr_reader :entry, :catalog

    def build
      @build ||= scrolled.tap do |sw|
        sw.child = grid

        grid.tap do |g|
          ROWS.each_with_index do |(title, value_method), index|
            g.attach(field_label(t(title)), 0, index, 1, 1)
            g.attach(public_send(value_method), 1, index, 1, 1)
          end

          g.attach(detailed_message_label, 0, ROWS.length, 2, 1)
        end
      end
    end

    def catalog_entry = @catalog_entry ||= catalog.entry_for(entry.catalog)

    def sender_label = @sender_label ||= value_label(entry.sender)
    def time_label = @time_label ||= value_label(entry.time.strftime('%x %X'))
    def message_label = @message_label ||= value_label(entry.message)
    def audit_label = @audit_label ||= value_label(entry.audit_session)
    def device_label = @device_label ||= value_label(entry.kernel_device)
    def priority_label = @priority_label ||= value_label(entry.priority_name)
    def subject_label = @subject_label ||= value_label(catalog_entry.subject)
    def definedby_label = @definedby_label ||= value_label(catalog_entry.defined_by)
    def documentation_label = @documentation_label ||= value_label(catalog_entry.documentation)

    # The catalog spec says Support is a URI, so it is rendered as a link.
    def support_label
      @support_label ||= value_label('').tap do |lbl|
        lbl.use_markup = true
        lbl.label = format('<a href="%<uri>s">%<uri>s</a>', uri: escape_markup(catalog_entry.support))
      end
    end

    # The bindings expose no g_markup_escape_text, and Support is a URI, so
    # escaping the five XML entities by hand is enough.
    ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;' }.freeze

    def escape_markup(text) = text.to_s.gsub(/[&<>"']/, ESCAPES)

    def detailed_message_label
      @detailed_message_label ||= Gtk::Label.new(catalog_entry.body).tap do |lbl|
        lbl.wrap = true
        lbl.selectable = true
        lbl.xalign = 0
        lbl.max_width_chars = 60
        lbl.margin_top = 12
        lbl.add_css_class('dim-label')
      end
    end

    def field_label(title)
      Gtk::Label.new(title).tap do |lbl|
        lbl.xalign = 1
        lbl.valign = :start
        lbl.margin_end = 12
        lbl.add_css_class('dim-label')
        lbl.attributes = Pango::AttrList.new.tap { |attrs| attrs.insert(Pango::AttrWeight.new(:bold)) }
      end
    end

    def value_label(text)
      Gtk::Label.new(text.to_s).tap do |lbl|
        lbl.wrap = true
        lbl.selectable = true
        lbl.xalign = 0
        lbl.hexpand = true
        lbl.max_width_chars = 60
        lbl.direction = :ltr
      end
    end

    def grid
      @grid ||= Gtk::Grid.new.tap do |g|
        g.row_spacing = 6
        g.column_spacing = 6
        g.margin_top = 12
        g.margin_bottom = 12
        g.margin_start = 12
        g.margin_end = 12
      end
    end

    def scrolled
      @scrolled ||= Gtk::ScrolledWindow.new.tap do |sw|
        sw.propagate_natural_width = true
        sw.propagate_natural_height = true
        sw.max_content_height = 500
        sw.hscrollbar_policy = :never
      end
    end
  end
end
