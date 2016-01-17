
view :title do |args|
   super args.merge( title: 'Recent Changes' )
end

format :html do
  view :open do |args|
    frame args.merge(body_class: 'history-slot list-group', content: true) do
      [
        history_legend,
        _render_recent_acts
      ]
    end
  end

  def

  view :recent_acts do |args|
    page = params['page'] || 1
    REVISIONS_PER_PAGE = 20
    Act.all.order(acted_at: :desc).page(page).per(REVISIONS_PER_PAGE).map do |act|
      render_complete_act_summary args.merge(act: act)
    end.join
  end

  view :complete_act_summary do |args|
    render_complete_act :summary, args
  end

  view :complete_act_expanded do |args|
    render_complete_act :expanded, args
  end


  def render_complete_act act_view, args
    act = (params['act_id'] && Card::Act.find(params['act_id'])) || args[:act]
    rev_nr = params['rev_nr'] || args[:rev_nr]
    current_rev_nr = params['current_rev_nr'] || args[:current_rev_nr] ||
                     card.current_rev_nr
    hide_diff = (params['hide_diff'] == ' true') || args[:hide_diff]
    args[:slot_class] = "revision-#{act.id} history-slot list-group-item"
    draft = (last_action = act.actions.last) && last_action.draft

    wrap(args) do
      render_haml card: card, act: act, act_view: act_view, draft: draft,
                  current_rev_nr: current_rev_nr, rev_nr: rev_nr,
                  hide_diff: hide_diff do
        <<-HAML
.act{style: "clear:both;"}
  .head
    - if rev_nr
      .nr
        = "##{rev_nr}"
    .title
      .actor
        = card_link act.card  # (c = act.card) && (c.name)
      .time.timeago
        = time_ago_in_words(act.acted_at)
        ago
        by
        = link_to act.actor.name, card_url(act.actor.cardname.url_key)
        - if draft
          |
          %em.info
            Autosave
        - if current_rev_nr == rev_nr
          %em.label.label-info
            Current
        - elsif act_view == :expanded
          = rollback_link act.relevant_actions_for(card, draft)
          = show_or_hide_changes_link hide_diff, act_id: act.id, act_view: act_view, rev_nr: rev_nr, current_rev_nr: current_rev_nr
  .toggle
    = fold_or_unfold_link act_id: act.id, act_view: act_view, rev_nr: rev_nr, current_rev_nr: current_rev_nr

  .action-container{style: ("clear: left;" if act_view == :expanded)}
    - act.actions.each do |action|
      = send("_render_action_#{act_view}", action: action )
HAML
      end
    end
  end


  # view :card_list do |args|
  #   search_vars[:item] ||= :change
  #
  #   cards_by_day = Hash.new { |h, day| h[day] = [] }
  #   search_results.each do |card|
  #     begin
  #       stamp = card.updated_at
  #       day = Date.new(stamp.year, stamp.month, stamp.day)
  #     rescue =>e
  #       day = Date.today
  #       card.content = "(error getting date)"
  #     end
  #     cards_by_day[day] << card if card.followable?
  #   end
  #
  #   paging = _optional_render :paging, args
  #   %{
  #     #{ paging }
  #     #{
  #       cards_by_day.keys.sort.reverse.map do |day|
  #         %{
  #           <h2>#{format_date(day, include_time = false) }</h2>
  #           <div class="search-result-list">
  #             #{
  #                cards_by_day[day].map do |card|
  #                  %{
  #                    <div class="search-result-item item-#{ search_vars[:item] }">
  #                     #{ nest(card, view: search_vars[:item]) }
  #                   </div>
  #                  }
  #                end * ' '
  #             }
  #           </div>
  #         }
  #       end * "\n"
  #     }
  #     #{ paging }
  #   }
  # end

end
