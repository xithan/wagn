class Card
  class Query
    class Join
      attr_accessor :conditions, :side,
        :from, :to,
        :from_table, :to_table,
        :from_alias, :to_alias,
        :from_field, :to_field

      def initialize opts={}
        from_and_to opts
        opts.each do |key, value|
          send "#{key}=", value if value.present?
        end
        @from_field ||= :id
        @to_field   ||= :id
        @conditions = []
      end

      def from_and_to opts
        [:from, :to].each do |side|
          object = opts[side]
          case object
          when nil; next
          when Array
            { table: object.shift, alias: object.shift, field: object.shift }
          when Card::Query
            { table: 'cards', alias: object.table_alias }
          when Card::Query::Reference
            { table: 'card_references', alias: object.table_alias }
          else
            raise "invalid #{side} option: #{object}"
          end.map do |key, value|
            opts[:"#{side}_#{key}"] ||= value
          end
        end
      end

      def side
        @side ||= (from && from.mods[:conj] == 'or') ? 'LEFT' : nil
      end

    end
  end
end

