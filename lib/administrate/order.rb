module Administrate
  class Order
    def initialize(attribute = nil, direction = nil)
      @attribute = attribute
      @direction = sanitize_direction(direction) || :asc
    end

    def apply(relation)
      return order_by_association(relation) unless
        reflect_association(relation).nil?

      order = "#{relation.table_name}.#{attribute} #{direction}"

      return relation.reorder(order) if
        relation.columns_hash.keys.include?(attribute.to_s)

      relation
    end

    def ordered_by?(attr)
      attr.to_s == attribute.to_s
    end

    def order_params_for(attr)
      {
        order: attr,
        direction: reversed_direction_param_for(attr)
      }
    end

    attr_reader :direction

    private

    attr_reader :attribute

    # Added from v0.13.0 to prevent SQL injection
    # https://github.com/thoughtbot/administrate/security/advisories/GHSA-2p5p-m353-833w
    def sanitize_direction(direction)
      return unless %w[asc desc].include?(direction.to_s)
      direction.to_sym
    end

    def reversed_direction_param_for(attr)
      if ordered_by?(attr)
        opposite_direction
      else
        :asc
      end
    end

    def opposite_direction
      direction == :asc ? :desc : :asc
    end

    def order_by_association(relation)
      return order_by_count(relation) if has_many_attribute?(relation)

      return order_by_id(relation) if belongs_to_attribute?(relation)

      return order_by_sortable_column(relation) if has_one_attribute?(relation)

      relation
    end

    def order_by_count(relation)
      relation.
      left_joins(attribute.to_sym).
      group(:id).
      reorder("COUNT(#{attribute}.id) #{direction}")
    end

    def order_by_id(relation)
      # LPL: Explicitly include table to mitigate ambiguity
      relation.reorder("#{relation.table_name}.#{attribute}_id #{direction}")
    end

    def order_by_sortable_column(relation)
      relation.joins(attribute.to_sym).merge(associated_model.order(sortable_column => direction.to_sym))
    end

    def has_many_attribute?(relation)
      reflect_association(relation).macro == :has_many
    end

    def belongs_to_attribute?(relation)
      reflect_association(relation).macro == :belongs_to
    end

    def has_one_attribute?(relation)
      reflect_association(relation).macro == :has_one
    end

    def reflect_association(relation)
      relation.klass.reflect_on_association(attribute.to_s)
    end

    def associated_model
      attribute.titleize.constantize
    end

    def sortable_column
      associated_model.sortable_column
    end
  end
end
