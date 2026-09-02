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
                  row_views[row.index]&.then(&:activate)
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

    # Ports the display_time_label flag: an entry repeats the time column only
    # when it differs from the entry above it.
    def mark_time_labels(list)
      list.each_with_index do |entry, index|
        entry.display_time_label =
          index.zero? || entry.time.strftime('%X') != list[index - 1].time.strftime('%X')
      end
    end

    # Rows are looked up by list position rather than by widget identity, so
    # the mapping survives whatever wrapper object the bindings hand back.
    def rebuild_rows
      row_views.each(&:dispose)
      @row_views = entries.map { |entry| row_view_for(entry) }

      entries_box.tap do |lb|
        lb.remove(lb.first_child) while lb.first_child

        row_views.each { |view| lb.append(view.build) }
      end
    end

    def row_view_for(entry)
      EventViewRow.new(entry: entry, catalog: catalog,
                       show_category: query.category == Category.important,
                       size_group: category_sizegroup)
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
