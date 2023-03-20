# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Instrumentation
    module Grape
      # Handles the events instrumented with ActiveSupport notifications.
      # These handlers contain all the logic needed to create and connect spans.
      class EventHandler
        class << self
          # Handles the start of the endpoint_run.grape event (the parent event), where the context is attached
          def endpoint_run_start(_name, _id, payload)
            name = span_name(payload[:endpoint])
            span = tracer.start_span(name, attributes: run_attributes(payload), kind: :server)
            token = OpenTelemetry::Context.attach(OpenTelemetry::Trace.context_with_span(span))

            payload.merge!(__opentelemetry_span: span, __opentelemetry_ctx_token: token)
          end

          # Handles the end of the endpoint_run.grape event (the parent event), where the context is detached
          def endpoint_run_finish(_name, _id, payload)
            span = payload.delete(:__opentelemetry_span)
            token = payload.delete(:__opentelemetry_ctx_token)
            return unless span && token

            if payload[:exception_object]
              handle_error(span, payload[:exception_object])
            else
              span.set_attribute(OpenTelemetry::SemanticConventions::Trace::HTTP_STATUS_CODE, payload[:endpoint].status)
            end

            span.finish
            OpenTelemetry::Context.detach(token)
          end

          # Handles the endpoint_render.grape event
          def endpoint_render(_name, start, _finish, _id, payload)
            name = span_name(payload[:endpoint])
            attributes = {
              'component' => 'template',
              'operation' => 'endpoint_render'
            }
            tracer.in_span(name, attributes: attributes, start_timestamp: start, kind: :server) do |span|
              handle_error(span, payload[:exception_object]) if payload[:exception_object]
            end
          end

          # Handles the endpoint_run_filters.grape events
          def endpoint_run_filters(_name, start, finish, _id, payload)
            filters = payload[:filters]
            type = payload[:type]

            # Prevent submitting empty filters
            return if (!filters || filters.empty?) || !type || (finish - start).zero?

            name = span_name(payload[:endpoint])
            attributes = {
              'component' => 'web',
              'operation' => 'endpoint_run_filters',
              'grape.filter.type' => type.to_s
            }
            tracer.in_span(name, attributes: attributes, start_timestamp: start, kind: :server) do |span|
              handle_error(span, payload[:exception_object]) if payload[:exception_object]
            end
          end

          # Handles the format_response.grape event
          def format_response(_name, start, _finish, _id, payload)
            endpoint = payload[:env]['api.endpoint']
            name = span_name(endpoint)
            attributes = {
              'component' => 'template',
              'operation' => 'format_response',
              'grape.formatter.type' => formatter_type(payload[:formatter])
            }
            tracer.in_span(name, attributes: attributes, start_timestamp: start, kind: :server) do |span|
              handle_error(span, payload[:exception_object]) if payload[:exception_object]
            end
          end

          private

          def tracer
            Grape::Instrumentation.instance.tracer
          end

          def span_name(endpoint)
            "#{api_instance(endpoint)} #{request_method(endpoint)} #{path(endpoint)}"
          end

          def run_attributes(payload)
            endpoint = payload[:endpoint]
            path = path(endpoint)
            {
              'component' => 'web',
              'operation' => 'endpoint_run',
              'grape.route.endpoint' => api_instance(endpoint),
              'grape.route.path' => path,
              'grape.route.method' => endpoint.options[:method].first,
              OpenTelemetry::SemanticConventions::Trace::HTTP_METHOD => request_method(endpoint),
              OpenTelemetry::SemanticConventions::Trace::HTTP_ROUTE => path
            }
          end

          def handle_error(span, exception)
            span.record_exception(exception)
            span.status = OpenTelemetry::Trace::Status.error("Unhandled exception of type: #{exception.class}")
            return unless exception.respond_to?('status') && exception.status

            span.set_attribute(OpenTelemetry::SemanticConventions::Trace::HTTP_STATUS_CODE, exception.status)
          end

          def api_instance(endpoint)
            endpoint.options[:for].base.to_s
          end

          def request_method(endpoint)
            endpoint.options.fetch(:method).first
          end

          def path(endpoint)
            namespace = endpoint.routes.first.namespace
            version = endpoint.routes.first.options[:version] || ''
            prefix = endpoint.routes.first.options[:prefix].to_s || ''
            parts = [prefix, version] + namespace.split('/') + endpoint.options[:path]
            parts.reject { |p| p.blank? || p.eql?('/') }.join('/').prepend('/')
          end

          def formatter_type(formatter)
            basename = formatter.name.split('::').last
            # Convert from CamelCase to snake_case
            basename.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
          end
        end
      end
    end
  end
end
