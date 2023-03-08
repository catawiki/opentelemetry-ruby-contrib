# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative 'subscriber'

module OpenTelemetry
  module Instrumentation
    module Grape
      # This class subscribes to the generated ActiveSupport notifications and generates spans based on them.
      class Handler
        ROOT_SUBSCRIPTION = 'endpoint_run.grape'

        SUBSCRIPTIONS = {
          'endpoint_render.grape' => :endpoint_render,
          'endpoint_run_filters.grape' => :endpoint_run_filters,
          'endpoint_run_validators.grape' => :endpoint_run_validators,
          'format_response.grape' => :format_response
        }.freeze

        class << self
          def subscribe
            Subscriber.subscribe(ROOT_SUBSCRIPTION)

            SUBSCRIPTIONS.each do |event, subscriber_method|
              ::ActiveSupport::Notifications.subscribe(event) do |*args|
                method(subscriber_method).call(*args)
              end
            end
          end

          def tracer
            ::OpenTelemetry::Instrumentation::Grape::Instrumentation.instance.tracer
          end

          private

          def endpoint_render(name, start, finish, _id, payload)

            attributes = {
              'component' => 'template',
              'operation' => name
            }
            span = tracer.start_span(name, attributes: attributes, start_timestamp: start, kind: :server)
            span.finish
          end

          def endpoint_run_filters(name, start, finish, id, payload)
            attributes = {
              'component' => 'template',
              'operation' => name
            }

            span = tracer.start_span(name, attributes: attributes, start_timestamp: start, kind: :server)
            span.finish
          end

          def endpoint_run_validators(name, start, finish, id, payload)
            attributes = {
              'component' => 'template',
              'operation' => name
            }
            span = tracer.start_span(name, attributes: attributes, start_timestamp: start, kind: :server)
            span.finish
          end

          def format_response(name, start, finish, id, payload)
            attributes = {
              'component' => 'template',
              'operation' => name
            }
            span = tracer.start_span(name, attributes: attributes, start_timestamp: start, kind: :server)
            span.finish
          end
        end
      end
    end
  end
end
