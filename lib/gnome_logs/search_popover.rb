# frozen_string_literal: true

module GnomeLogs
  # The search options popover. Ports GlSearchPopover: which journal field to
  # search ("What"), how to match it ("Search Type") and which slice of the
  # journal to read ("When"), plus a second page for a custom time range.
  #
  # Upstream drives the two option lists with GtkTreeView, which GTK4
  # deprecates; Gtk::DropDown gives the same choices with far less machinery.
  class SearchPopover
    include Translation

    FIELD_KEYS = Query::SEARCH_FIELD_TITLES.keys.freeze
    RANGE_KEYS = Query::RANGE_TITLES.keys.freeze
    DAY_SECONDS = 86_400
    MAIN_PAGE = 'main'
    CUSTOM_PAGE = 'custom'

    def initialize(query:, on_change:)
      @query = query
      @on_change = on_change
    end

    attr_reader :query, :on_change

    def build
      @build ||= popover.tap do |p|
        p.child = stack

        stack.tap do |s|
          s.add_named(main_box, MAIN_PAGE)
          s.add_named(custom_box, CUSTOM_PAGE)

          main_box.tap do |box|
            box.append(what_label)
            box.append(field_dropdown)
            box.append(search_type_revealer)
            box.append(when_label)
            box.append(range_dropdown)

            field_dropdown.tap do |dd|
              dd.signal_connect('notify::selected') { on_field_selected }
            end

            search_type_revealer.tap do |rev|
              rev.child = search_type_box

              search_type_box.tap do |tbox|
                tbox.append(search_type_label)
                tbox.append(substring_check)
                tbox.append(exact_check)

                substring_check.tap do |btn|
                  btn.signal_connect('toggled') { on_search_type_selected(:substring, btn) }
                end

                exact_check.tap do |btn|
                  btn.group = substring_check
                  btn.signal_connect('toggled') { on_search_type_selected(:exact, btn) }
                end
              end
            end

            range_dropdown.tap do |dd|
              dd.signal_connect('notify::selected') { on_range_selected }
            end
          end

          custom_box.tap do |box|
            box.append(back_button)
            box.append(start_label)
            box.append(start_calendar)
            box.append(end_label)
            box.append(end_calendar)
            box.append(apply_button)

            back_button.tap do |btn|
              btn.signal_connect('clicked') { s.visible_child_name = MAIN_PAGE }
            end

            apply_button.tap do |btn|
              btn.signal_connect('clicked') { apply_custom_range }
            end
          end
        end
      end
    end

    def on_field_selected
      FIELD_KEYS[field_dropdown.selected].then do |field|
        query.search_field = field
        # An all-fields search is always a substring search upstream, so the
        # search type only makes sense once a single field is chosen.
        search_type_revealer.reveal_child = field != :all
        on_change.call
      end
    end

    def on_search_type_selected(type, button)
      if button.active?
        query.search_type = type
        on_change.call
      end
    end

    def on_range_selected
      RANGE_KEYS[range_dropdown.selected].then do |range|
        if range == :custom_range
          stack.visible_child_name = CUSTOM_PAGE
        else
          query.range = range
          on_change.call
        end
      end
    end

    # Gtk::Calendar reports a date and nothing finer, so a custom range covers
    # whole days: from the start of the first to the end of the last. Upstream
    # pairs each calendar with hour and minute spin buttons; the extra
    # precision is not worth four more widgets here.
    def apply_custom_range
      query.range = :custom_range
      query.start_time = midnight(start_calendar)
      query.end_time = midnight(end_calendar) + DAY_SECONDS - 1
      stack.visible_child_name = MAIN_PAGE
      on_change.call
    end

    def midnight(calendar)
      calendar.date.then { |date| Time.new(date.year, date.month, date.day_of_month) }
    end

    def popover = @popover ||= Gtk::Popover.new

    # Without this the popover is sized for the custom-range page's calendars
    # even while the much shorter options page is showing.
    def stack
      @stack ||= Gtk::Stack.new.tap do |s|
        s.hhomogeneous = false
        s.vhomogeneous = false
      end
    end

    def start_calendar = @start_calendar ||= Gtk::Calendar.new
    def end_calendar = @end_calendar ||= Gtk::Calendar.new

    def field_dropdown
      @field_dropdown ||= Gtk::DropDown.new(Query::SEARCH_FIELD_TITLES.values.map { |title| t(title) }).tap do |dd|
        dd.selected = FIELD_KEYS.index(query.search_field)
        dd.tooltip_text = t('Select the journal field to search in')
      end
    end

    def range_dropdown
      @range_dropdown ||= Gtk::DropDown.new(Query::RANGE_TITLES.values.map { |title| t(title) }).tap do |dd|
        dd.selected = RANGE_KEYS.index(query.range)
        dd.tooltip_text = t('Select the timestamp range of log entries to show')
      end
    end

    def search_type_revealer
      @search_type_revealer ||= Gtk::Revealer.new.tap do |rev|
        rev.reveal_child = query.search_field != :all
      end
    end

    def substring_check
      @substring_check ||= Gtk::CheckButton.new(t('Substring')).tap do |btn|
        btn.active = query.search_type == :substring
      end
    end

    def exact_check
      @exact_check ||= Gtk::CheckButton.new(t('Exact')).tap do |btn|
        btn.active = query.search_type == :exact
      end
    end

    def back_button
      @back_button ||= Gtk::Button.new(label: t('Back')).tap do |btn|
        btn.has_frame = false
        btn.halign = :start
      end
    end

    def apply_button
      @apply_button ||= Gtk::Button.new(label: t('Apply')).tap do |btn|
        btn.add_css_class('suggested-action')
        btn.halign = :end
        btn.margin_top = 6
      end
    end

    def what_label = @what_label ||= dim_label(t('What'))
    def when_label = @when_label ||= dim_label(t('When'))
    def search_type_label = @search_type_label ||= dim_label(t('Search Type'))
    def start_label = @start_label ||= dim_label(t('Show Logs Starting From…'))
    def end_label = @end_label ||= dim_label(t('Show Logs Until…'))

    def dim_label(text)
      Gtk::Label.new(text).tap do |lbl|
        lbl.xalign = 0
        lbl.add_css_class('dim-label')
      end
    end

    def main_box = @main_box ||= option_box
    def custom_box = @custom_box ||= option_box

    def search_type_box = @search_type_box ||= Gtk::Box.new(:horizontal, 12)

    def option_box
      Gtk::Box.new(:vertical, 6).tap do |box|
        box.margin_top = 12
        box.margin_bottom = 12
        box.margin_start = 12
        box.margin_end = 12
      end
    end
  end
end
