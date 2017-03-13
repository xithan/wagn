require "csv"

format :csv  do
  def default_nest_view
    :core
  end

  def default_item_view
    @depth.zero? ? :csv_row : :name
  end

  view :csv_row do |_args|
    array = _render_raw.scan(/\{\{[^\}]*\}\}/).map do |inc|
      process_content(inc).strip
    end

    CSV.generate_line(array).strip
    # strip is because search already joins with newlines
  end

  view :missing do |_args|
    ""
  end

  view :csv_title_row do |_args|
    # NOTE: assumes all cards have the same structure!
    begin
      card1 = search_with_params.first

      parsed_content = Card::Content.new card1.raw_content, self
      if parsed_content.__getobj__.is_a? String
        ""
      else
        titles = parsed_content.map do |chunk|
          next if chunk.class != Card::Content::Chunk::Nest
          opts = chunk.options
          if %w(name link).member? opts[:view]
            opts[:view]
          else
            opts[:nest_name].to_name.tag
          end
        end.compact
        CSV.generate_line titles.map { |title| title.to_s.upcase }
      end
    rescue
      ""
    end
  end
end
