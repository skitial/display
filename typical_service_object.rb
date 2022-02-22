# frozen_string_literal: true

module Exponea
  class WebhookTicketProcessorService < ApplicationService
    IDS_LIMIT = 100
    TICKET_ERROR_STATUS = { ticket_not_exist: 404,
                           ticket_not_valid: 422 }.freeze

    param :data, type: Types::Coercible::Hash

    def call
      validate_data.bind do |form|
        transaction.bind do
          create_jobs(form)
        end
      end
    end

    private

    def validate_data
      form = Exponea::TicketWebhookForm.new
      if form.validate(data)
        Success(form)
      else
        Failure(error_code(form.errors.details))
      end
    end

    def create_jobs(form)
      form.user_ids.in_groups_of(IDS_LIMIT, false) do |ids_batch|
        MassCreateTicketJob.enqueue(
          ids_batch, form.ticket_id, AdminUser.robot.id, form.reason
        )
      end

      Success(true)
    end

    def error_code(form_errors)
      error_field = form_errors.keys.first
      if error_field == :coupon_id
        TICKET_ERROR_STATUS[form_errors[error_field][0][:error]]
      else
        404
      end
    end
  end
end
