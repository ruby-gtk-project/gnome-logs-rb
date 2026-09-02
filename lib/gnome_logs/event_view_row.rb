# frozen_string_literal: true

module GnomeLogs
  # One row of the log list. Ports GlEventViewRow: an optional category column
  # (shown only in the Important view, where entries come from every category),
  # the message, and the time on the trailing edge. Activating the row pops up
  # the detail popover, as in gl_event_view_list_on_row_activated.
  class EventViewRow
    def initialize(entry:, catalog:, show_category:, size_group:)
      @entry = entry
      @catalog = catalog
      @show_category = show_category
      @size_group = size_group
    end

    attr_reader :entry, :catalog, :show_category, :size_group

    def build
      @build ||= row.tap do |r|
        r.child = grid

        grid.tap do |g|
          g.attach(category_label, 0, 0, 1, 1) if show_category
          g.attach(message_label, 1, 0, 1, 1)
          g.attach(time_label, 2, 0, 1, 1)

          size_group.add_widget(category_label) if show_category
        end

        detail_popover.set_parent(r)
      end
    end

    # The detail grid is only built the first time the row is activated, so a
    # list of a thousand rows does not pay for a thousand detail views.
    def activate
      detail_popover.tap do |popover|
        popover.child = detail.build
        popover.popup
      end
    end

    # Popovers attached with set_parent must be detached explicitly, otherwise
    # GTK complains when the row they hang off is finalized.
    def dispose = detail_popover.unparent

    def detail = @detail ||= EventViewDetail.new(entry, catalog)

    def row = @row ||= Gtk::ListBoxRow.new.tap { |r| r.activatable = true }

    def detail_popover
      @detail_popover ||= Gtk::Popover.new.tap do |popover|
        popover.position = :bottom
        popover.has_arrow = true
      end
    end

    def grid
      @grid ||= Gtk::Grid.new.tap do |g|
        g.column_spacing = 12
        g.margin_top = 6
        g.margin_bottom = 6
        g.margin_start = 12
        g.margin_end = 12
      end
    end

    def category_label
      @category_label ||= Gtk::Label.new(Category.label_for(entry)).tap do |lbl|
        lbl.xalign = 0
        lbl.add_css_class('dim-label')
        lbl.add_css_class('event-monospace')
      end
    end

    def message_label
      @message_label ||= Gtk::Label.new(entry.single_line_message).tap do |lbl|
        lbl.direction = :ltr
        lbl.halign = :start
        lbl.xalign = 0
        lbl.ellipsize = :end
        lbl.single_line_mode = true
        lbl.add_css_class('event-monospace')
      end
    end

    # Entries that share a timestamp with the row above them leave the column
    # blank, so a burst of messages reads as one block.
    def time_label
      @time_label ||= Gtk::Label.new(entry.display_time_label ? entry.time.strftime('%X') : '').tap do |lbl|
        lbl.halign = :end
        lbl.hexpand = true
        lbl.xalign = 1
        lbl.add_css_class('dim-label')
        lbl.add_css_class('event-monospace')
        lbl.add_css_class('event-time')
      end
    end
  end
end
