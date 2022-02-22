# frozen_string_literal: true

module Exponea
  class WebhookProcessorService < ApplicationService
    feature :validation, validator: Exponea::WebhookForm

    option :action_name, proc(&:downcase)
    option :id, type: Types::Coercible::Integer, as: :user_id
    option :receive_news, optional: true

    def call
      case action_name
      when "update_consent"
        update_subscription
      else
        Failure(:not_implimented)
      end
    end

    private

    def update_subscription
      Success(UpdateUserByWebhooksJob.enqueue(event_type: "receive_news",
                                        user_id: user_id,
                                        event_value: receive_news))
    end
  end
end


# frozen_string_literal: true

module Services
  class Validatable < Module
    def initialize(validator: nil)
      super() do
        define_method :validator_class do
          validator
        end
      end

      prepend Validator
    end
  end

  module Validator
    def call(*args, &block)
      validate(*args).bind do
        super(*args, &block)
      end
    end

    private

    def validate(*args)
      check_validator.bind do |form|
        validate_with_class(form, *args)
      end
    end

    def check_validator
      raise "No validator" if validator_class.nil?

      klass = Module.const_get(validator_class.to_s)
      Dry::Monads::Success(klass.new(nil))
    rescue NameError
      Dry::Monads::Failure(:wrong_validator)
    end

    def validate_with_class(form, *args)
      return Dry::Monads::Success(true) if form.validate(*args)

      Dry::Monads::Failure(form.errors.messages)
    end
  end
end


# frozen_string_literal: true

class ApplicationService
  extend  Dry::Initializer
  include Dry::Monads[:maybe, :result]
  include Memery

  FEATURES = {
    transaction: { klass: Services::Transactional, method: :include },
    validation: { klass: Services::Validatable, method: :prepend },
  }.freeze

  class << self
    def call(*args, &block)
      new(*args).call(&block)
    end

    def feature(name, *args)
      return unless FEATURES[name]

      case FEATURES[name][:method]
      when :include
        include FEATURES[name][:klass]
      when :prepend
        singleton_class.prepend(FEATURES[name][:klass].new(*args))
      end
    end
  end

  def call(&_block)
    raise NotImplementedError
  end

  # rubocop:disable Naming/MethodName
  # def Error(field, code, options = {})
  #   Failure(
  #     field:    field,
  #     message:  I18n.t(code, { scope: "errors.messages" }.merge(options)),
  #     code:     code
  #   )
  # end

  # def ReformErrors(errors)
  #   Failure(
  #     errors.map do |field, error|
  #       {
  #         field:    field,
  #         message:  error.message,
  #         code:     error.error_type,
  #       }
  #     end
  #   )
  # end
  # rubocop:enable Naming/MethodName
end
