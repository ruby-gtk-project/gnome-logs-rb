# frozen_string_literal: true

module GnomeLogs
  # The sidebar. Ports GlCategoryList: a list box of category rows that reports
  # the selected Category through the on_select callback.
  class CategoryList
    def initialize(on_select:)
      @on_select = on_select
    end

    attr_reader :on_select

    def build
      @build ||= scrolled.tap do |sw|
        sw.child = list_box

        list_box.tap do |lb|
          Category.visible.each { |category| lb.append(row_for(category)) }

          # Rows are matched to categories by position, which sidesteps any
          # question of widget identity across the binding boundary.
          lb.signal_connect('row-selected') do |_, row|
            Category.visible[row.index]&.then { |category| on_select.call(category) }
          end

          lb.select_row(lb.get_row_at_index(Category.visible.index(Category.default)))
        end
      end
    end

    def row_for(category)
      Gtk::ListBoxRow.new.tap { |row| row.child = category_label(category.title) }
    end

    def category_label(title)
      Gtk::Label.new(title).tap do |lbl|
        lbl.xalign = 0
        lbl.margin_top = 8
        lbl.margin_bottom = 8
        lbl.margin_start = 12
        lbl.margin_end = 12
      end
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |lb|
        lb.selection_mode = :browse
        lb.add_css_class('navigation-sidebar')
      end
    end

    def scrolled
      @scrolled ||= Gtk::ScrolledWindow.new.tap do |sw|
        sw.hscrollbar_policy = :never
        sw.vexpand = true
        sw.width_request = 180
      end
    end
  end
end
