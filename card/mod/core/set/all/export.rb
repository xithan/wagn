format :json do
  def default_export_args args
    args[:count] ||= 0
    args[:count] += 1
    args[:processed_keys] ||= ::Set.new
  end

  # export the card itself and all nested content (up to 10 levels deep)
  view :export, cache: :never do |args|
    # avoid loops
    return [] if args[:count] > 10 || args[:processed_keys].include?(card.key)
    args[:processed_keys] << card.key

    Array.wrap(render_atom(args)).concat(
      render_export_items(count: args[:count])
    )
  end

  def default_export_items_args args
    args[:processed_keys] ||= ::Set.new
  end

  # export all nested content (up to 10 levels deep)
  view :export_items, cache: :never do |args|
    result = []
    card.each_nested_chunk do |chunk|
      next if nest_name_main? chunk
      next unless (r_card = chunk.referee_card)
      next if r_card.new? || r_card == card
      next if args[:processed_keys].include?(r_card.key)
      result << r_card
    end
    result.uniq!
    result.map! { |ca| subformat(ca).render_export(args) }
    result.flatten.reject(&:blank?)
  end

  def nest_name_main? chunk
    chunk.respond_to?(:options) && chunk.options && chunk.options[:nest_name] &&
      chunk.options[:nest_name] == "_main"
  end
end
