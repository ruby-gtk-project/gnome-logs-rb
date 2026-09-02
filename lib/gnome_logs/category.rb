# frozen_string_literal: true

module GnomeLogs
  # One entry of the sidebar category list. Replaces GlCategoryListFilter and
  # query_add_category_matches: each category knows both the journalctl matches
  # that narrow the read and the predicate that refines it.
  #
  # journalctl ORs matches on the same field and ANDs across fields, which is
  # exactly the semantics gl_query_to_string built by hand. The "field is
  # present" checks (hardware, security) have no journalctl equivalent, so they
  # live in the predicate instead.
  class Category
    extend Translation

    attr_reader :id, :title, :matches, :predicate

    def initialize(id:, title:, matches: [], predicate: ->(_entry) { true })
      @id = id
      @title = title
      @matches = matches
      @predicate = predicate
    end

    def matches?(entry) = predicate.call(entry)

    def self.uid = @uid ||= Process.uid.to_s

    def self.important
      @important ||= new(id: :important, title: t('Important'),
                         matches: %w[PRIORITY=0 PRIORITY=1 PRIORITY=2 PRIORITY=3])
    end

    def self.all = @all ||= new(id: :all, title: t('All'))

    def self.applications
      @applications ||= new(id: :applications, title: t('Applications'),
                            matches: ['_TRANSPORT=journal', '_TRANSPORT=stdout',
                                      '_TRANSPORT=syslog', "_UID=#{uid}"])
    end

    def self.system
      @system ||= new(id: :system, title: t('System'), matches: ['_TRANSPORT=kernel'])
    end

    def self.security
      @security ||= new(id: :security, title: t('Security'),
                        predicate: ->(entry) { !entry.audit_session.empty? })
    end

    def self.hardware
      @hardware ||= new(id: :hardware, title: t('Hardware'), matches: ['_TRANSPORT=kernel'],
                        predicate: ->(entry) { !entry.kernel_device.empty? })
    end

    # Only the categories the C version actually implements. Alerts, Starred,
    # Updates and Usage are hidden rows upstream, so they are not ported.
    def self.visible = @visible ||= [important, all, applications, system, security, hardware]

    def self.default = all

    # The per-row category shown in the Important view, ported from
    # gl_event_view_row_construct_category_label. Checks run most-specific
    # first: applications, hardware, system, security, other.
    def self.label_for(entry)
      if %w[kernel stdout syslog].include?(entry.transport) && entry.uid == uid
        t('Applications')
      elsif entry.transport == 'kernel' && !entry.kernel_device.empty?
        t('Hardware')
      elsif entry.transport == 'kernel'
        t('System')
      elsif !entry.audit_session.empty?
        t('Security')
      else
        t('Other')
      end
    end
  end
end
