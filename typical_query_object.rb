# frozen_string_literal: true

class CustomerExportQuery
  attr_reader :relation

  DATE_FIELDS = %w[created_at updated_at status_changed_at]
  TEXT_FIELDS = %w[export_type category status city]

  class << self
    def call(params)
      relation = new
      relation.filter(params)
    end
  end

  def initialize(relation = Customer.order(created_at: :desc))
    @relation = relation
  end

  def filter(params)
    fields = params.keys

    fields.select! {|field| (DATE_FIELDS + TEXT_FIELDS).include?(field) }

    fields.each do |field|
      @relation = send("#{field}"_is, params[field])
    end

    @relation
  end

  private

  DATE_FIELDS.each do |date_field|
    define_method("#{date_field}_is") do |date_values|
      return @relation if date_values.blank?

      rel = @relation
      if date_values[:from].present?
        from = Time.zone.parse(date_values[:from]).beginning_of_day
        rel = rel.where("customer_exports.#{date_values[:name]} >= ?", from)
      end

      if date_values[:to].present?
        to = Time.zone.parse(date_values[:to]).end_of_day
        rel = rel.where("customer_exports.#{date_values[:name]} <= ?", to)
      end

      rel
    end
  end

  TEXT_FIELDS.each do |text_field|
    define_method("#{text_field}_is") do |text_value|
      return @relation if text_value.blank?

      @relation.where(text_field => text_value)
    end
  end
end
