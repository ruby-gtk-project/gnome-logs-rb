# frozen_string_literal: true

module GnomeLogs
  # The sidebar plus log list. Ports GlEventViewList and, since the Ruby port
  # reads the whole result set from journalctl in one go, most of
  # GlJournalModel too: the model there existed to page a libsystemd cursor in
  # idle callbacks, which has no counterpart here.
  class EventViewList
    include Translation

    def initialize(journal:, catalog:, query:, on_entries_changed:)
      @journal = journal
      @catalog = catalog
      @query = query
      @on_entries_changed = on_entries_changed
      @entries = []
      @row_views = []
    end

    attr_reader :journal, :catalog, :query, :on_entries_changed, :entries, :row_views

    def build
      @build ||= split_view.tap do |sv|
        sv.sidebar = sidebar_page
        sv.content = content_page

        sidebar_toolbar.tap do |st|
          st.content = category_list.build
        end

        content_toolbar.tap do |ct|
          ct.add_top_bar(search_bar)
          ct.content = content_stack

          search_bar.tap do |bar|
            bar.child = search_entry_box

            search_entry_box.tap do |box|
              box.append(search_entry)
              box.append(search_options_button)

              search_entry.tap do |entry|
                entry.signal_connect('search-changed') { on_search_changed }
              end

              search_options_button.tap do |btn|
                btn.popover = search_popover.build
              end
            end
          end

          content_stack.tap do |stack|
            stack.add_named(event_scrolled, 'results')
            stack.add_named(empty_page, 'empty')

            event_scrolled.tap do |sw|
              sw.child = entries_box

              entries_box.tap do |lb|
                lb.signal_connect('row-activated') do |_, row|
                  on_row_activated(row.index)
                end
              end
            end
          end
        end

        reload
      end
    end

    # Re-reads the journal and rebuilds the list. The C version mutates a
    # GlJournalModel in place; rebuilding is fast enough here and keeps the
    # widget tree a pure function of the query.
    def reload
      @entries = load_entries
      rebuild_rows
      content_stack.visible_child_name = entries.empty? ? 'empty' : 'results'
      on_entries_changed.call(entries)
    end

    def load_entries
      journal.entries(query).select { |entry| query.matches?(entry) }.first(Query::ENTRY_LIMIT).to_a.tap do |list|
        mark_time_labels(list)
      end
    end

    # Ports the display_time_label flag of gl_journal_model_fetch_more_entries:
    # an entry repeats the time column only when the string it would show
    # differs from the one the entry above it shows.
    def mark_time_labels(list)
      Time.now.then do |now|
        list.each_with_index do |entry, index|
          entry.display_time_label =
            index.zero? || time_display(entry, now) != time_display(list[index - 1], now)
        end
      end
    end

    def time_display(entry, now) = Util.timestamp_to_display(entry.timestamp_usec, now, clock_format)

    # The desktop clock format is read once per list rather than once per row,
    # as the C version's cached priv->clock_format is.
    def clock_format = @clock_format ||= Util.clock_format

    # Rows are looked up by list position rather than by widget identity, so
    # the mapping survives whatever wrapper object the bindings hand back.
    def rebuild_rows
      row_views.each(&:dispose)
      rows = grouped_entries
      @row_views = rows.map { |entry| row_view_for(entry) }

      entries_box.tap do |lb|
        lb.remove(lb.first_child) while lb.first_child

        row_views.each { |view| lb.append(view.build) }
      end

      apply_headers(rows)
    end

    def row_view_for(entry)
      EventViewRow.new(entry: entry, catalog: catalog,
                       show_category: query.category == Category.important,
                       size_group: category_sizegroup, clock_format: clock_format)
    end

    # Ports the grouping half of gl_journal_model_fetch_idle: a run of two or
    # more adjacent entries that look like the same recurring message gets
    # collapsed under one header row, which stands in for the run until it is
    # expanded. Runs are found in display order, so this works the same way
    # whether the query sorts ascending or descending.
    def grouped_entries
      runs(entries).flat_map do |run|
        if run.length > 1
          [header_for(run)] + run.each { |entry| entry.row_type = :compressed }
        else
          run
        end
      end
    end

    def runs(list)
      list.each_with_object([]) do |entry, groups|
        if groups.last && similar_messages?(groups.last.last, entry)
          groups.last << entry
        else
          groups << [entry]
        end
      end
    end

    # Ports gl_row_entry_check_message_similarity: entries group together when
    # their messages share a first word, or when they come from the same
    # sender.
    def similar_messages?(one, other)
      first_word(one.message) == first_word(other.message) ||
        (!one.command_line.empty? && one.command_line == other.command_line)
    end

    def first_word(message) = message.to_s.split(' ', 2).first.to_s

    # Ports gl_journal_model_add_header: the header stands in for the run with
    # the first entry's own details, plus a count of what it is hiding.
    def header_for(run)
      run.first.dup.tap do |header|
        header.row_type = :header
        header.compressed_entries = run.length
      end
    end

    # Ports listbox_update_header_func: every row gets a separator above it,
    # except a compressed row immediately below its header (which should read
    # as part of one block) or the very first row in the list.
    def apply_headers(rows)
      rows.each_with_index do |entry, index|
        before = index.positive? ? rows[index - 1] : nil
        row_views[index].row.header =
          before && (entry.row_type != :compressed || before.row_type == :header) ? Gtk::Separator.new(:horizontal) : nil
      end
    end

    # Ports on_listbox_row_activated's header branch: expands or collapses the
    # run of compressed rows a header stands in for.
    def on_row_activated(index)
      view = row_views[index]
      if view
        if view.entry.row_type == :header
          toggle_group(index)
        else
          view.activate
        end
      end
    end

    def toggle_group(header_index)
      header_view = row_views[header_index]
      members = row_views[(header_index + 1)..(header_index + header_view.entry.compressed_entries)].to_a
      expanding = !members.first&.row&.visible?

      members.each { |member| member.row.visible = expanding }
      members.each { |member| toggle_css(member.row, 'compressed-row', expanding) }
      toggle_css(header_view.row, 'compressed-row-header', expanding)
      toggle_group_separators(header_index, members.length, expanding)
    end

    def toggle_group_separators(header_index, member_count, expanding)
      [row_views[header_index], row_views[header_index + 1], row_views[header_index + member_count]].each do |view|
        toggle_css(view&.row&.header, 'compressed-rows-group-separator', expanding)
      end
    end

    def toggle_css(widget, css_class, add)
      if widget
        add ? widget.add_css_class(css_class) : widget.remove_css_class(css_class)
      end
    end

    def on_search_changed
      query.search_text = search_entry.text
      reload
    end

    # The sidebar selects its default row while build is still wiring up the
    # content stack, so the no-op selection is dropped rather than reloading
    # against a stack that has no pages yet.
    def on_category_selected(category)
      unless query.category == category
        query.category = category
        reload
      end
    end

    def toggle_search = search_bar.search_mode = !search_bar.search_mode?

    def category_list
      @category_list ||= CategoryList.new(on_select: ->(category) { on_category_selected(category) })
    end

    def search_popover
      @search_popover ||= SearchPopover.new(query: query, on_change: -> { reload })
    end

    def split_view
      @split_view ||= Adwaita::NavigationSplitView.new.tap do |sv|
        sv.vexpand = true
        sv.hexpand = true
        sv.sidebar_width_fraction = 0.2
        sv.min_sidebar_width = 180
        sv.max_sidebar_width = 260
      end
    end

    def sidebar_page = @sidebar_page ||= Adwaita::NavigationPage.new(sidebar_toolbar, t('Categories'))
    def content_page = @content_page ||= Adwaita::NavigationPage.new(content_toolbar, t('Logs'))
    def sidebar_toolbar = @sidebar_toolbar ||= Adwaita::ToolbarView.new
    def content_toolbar = @content_toolbar ||= Adwaita::ToolbarView.new

    def content_stack
      @content_stack ||= Gtk::Stack.new.tap do |stack|
        stack.vexpand = true
        stack.hexpand = true
      end
    end

    def search_bar = @search_bar ||= Gtk::SearchBar.new
    def category_sizegroup = @category_sizegroup ||= Gtk::SizeGroup.new(:horizontal)

    def empty_page
      @empty_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = 'action-unavailable-symbolic'
        page.title = t('No Results')
      end
    end

    def search_entry_box
      @search_entry_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.add_css_class('linked')
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = t('Search logs')
        entry.hexpand = true
      end
    end

    def search_options_button
      @search_options_button ||= Gtk::MenuButton.new.tap do |btn|
        btn.icon_name = 'view-more-symbolic'
        btn.tooltip_text = t('Select journal field and timestamp range filtering options')
      end
    end

    def entries_box
      @entries_box ||= Gtk::ListBox.new.tap do |lb|
        lb.selection_mode = :none
        lb.add_css_class('background')
      end
    end

    def event_scrolled
      @event_scrolled ||= Gtk::ScrolledWindow.new.tap do |sw|
        sw.vexpand = true
        sw.hscrollbar_policy = :never
      end
    end
  end
end
