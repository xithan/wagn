format do
  def show view, args
    view ||= :core
    render view, args
  end

  @@variant_methods = [:capitalize, :singularize, :pluralize, :titleize,                               :downcase, :upcase, :swapcase, :reverse, :succ]
  @@variant_aliases = { capitalized: :capitalize, singular: :singularize,
                        plural: :pluralize,       title: :titleize }

  # NAME VIEWS
  view :name, closed: true, perms: :none do
    return card.name unless voo.variant
    voo.variant.split(/[\s,]+/).inject(card.name) do |name, variant|
      variant = @@variant_aliases[variant.to_sym] || variant.to_sym
      @@variant_methods.include?(variant) ? name.send(variant) : name
    end
  end

  view(:key,      closed: true, perms: :none) { card.key }
  view(:linkname, closed: true, perms: :none) { card.cardname.url_key }
  view(:url,      closed: true, perms: :none) { card_url _render_linkname }

  view :title, closed: true, perms: :none do
    voo.title || card.name
  end

  view :url_link, closed: true, perms: :none do
    link_to_resource card_url(_render_linkname)
  end

  view :link, closed: true, perms: :none do
    title = showname voo.title
    opts = { known: card.known? }
    if voo.type && !opts[:known]
      opts[:path] = { card: { type: voo.type } }
    end
    link_to_card card.name, title, opts
  end

  view(:codename, closed: true) { card.codename.to_s }
  view(:id,       closed: true) { card.id            }
  view(:type,     closed: true) { card.type_name     }

  # DATE VIEWS

  view(:created_at, closed: true) { time_ago_in_words card.created_at }
  view(:updated_at, closed: true) { time_ago_in_words card.updated_at }
  view(:acted_at,   closed: true) { time_ago_in_words card.acted_at   }

  # CONTENT VIEWS

  view :raw do
    scard = voo.structure ? Card[voo.structure] : card
    scard ? scard.raw_content : _render_blank
  end

  view :core do
    process_content _render_raw
  end

  view :content do
    _render_core
  end

  view :open_content do
    _render_core
  end

  view :closed_content, closed: true do
    Card::Content.smart_truncate _render_core
  end

  view :blank, closed: true, perms: :none do
    ""
  end

  # note: content and open_content may look like they should be aliased to
  # core, but it's important that they render core explicitly so that core view
  # overrides work.  the titled and labeled views below, however, are not
  # intended for frequent override, so this shortcut is fine.

  # NAME + CONTENT VIEWS

  view :titled do |args|
    "#{card.name}\n\n#{_render_core args}"
  end
  view :open, :titled

  view :labeled do |args|
    "#{card.name}: #{_render_closed_content args}"
  end
  view :closed, :labeled

  # SPECIAL VIEWS

  view :array, cache: :never do
    card.item_cards(limit: 0).map do |item_card|
      subformat(item_card)._render_core
    end.inspect
  end

  # none of the below belongs here!!

  view :template_rule, cache: :never, tags: :unknown_ok do
    return "" unless voo.nest_name
    if voo.nest_name.to_name.simple_relative?
      set_card = Card.fetch template_link_set_name
      subformat(set_card).render_template_link
    else
      "{{#{voo.nest_syntax}}}"
    end
  end

  def template_link_set_name
    name = voo.nest_name.to_name
    if name.absolute?
      name.trait_name :self
    elsif (type = on_type_set)
      [type, name].to_name.trait_name :type_plus_right
    else
      name.stripped.gsub(/^\+/, "").to_name.trait_name :right
    end
  end

  def on_type_set
    return unless
      (tmpl_set_name = parent.card.cardname.trunk_name) &&
      (tmpl_set_class_name = tmpl_set_name.tag_name) &&
      (tmpl_set_class_card = Card[tmpl_set_class_name]) &&
      (tmpl_set_class_card.codename == "type")

    tmpl_set_name.left_name
  end
end
