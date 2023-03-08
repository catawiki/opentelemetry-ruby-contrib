# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Instrumentation
    module Grape
      class Subscriber

        def self.subscribe(event)
          ::ActiveSupport::Notifications.subscribe(event, new)
        end

        def start(name, _id, payload)
          span = tracer.start_span(name, kind: :server)
          token = OpenTelemetry::Context.attach(OpenTelemetry::Trace.context_with_span(span))

          payload.merge!({ __opentelemetry_span: span, __opentelemetry_ctx_token: token })
        end

        def finish(name, _id, payload)
          span = payload.delete(:__opentelemetry_span)
          token = payload.delete(:__opentelemetry_ctx_token)

          span.add_attributes(build_attributes(payload))

          span.set_error(payload[:exception_object]) if payload[:exception_object]

          span.finish
          OpenTelemetry::Context.detach(token)
        end

        def tracer
          ::OpenTelemetry::Instrumentation::Grape::Instrumentation.instance.tracer
        end

        def build_attributes(payload)
          endpoint = payload.fetch(:endpoint)
          request_method = endpoint.options.fetch(:method).first
          path = endpoint_expand_path(endpoint)
          api_instance = endpoint.options[:for]
          # TODO: missing attributes? http.status_code, http.route?
          {
            'component' => 'web',
            'operation' => 'endpoint_run',
            'grape.route.endpoint' => api_instance.base.to_s,
            'grape.route.path' => path,
            'grape.route.method' => request_method,
            'http.method' => request_method,
            'http.url' => path
          }

          # {
          #   OpenTelemetry::SemanticConventions::Trace::HTTP_METHOD => request_method,
          #   OpenTelemetry::SemanticConventions::Trace::HTTP_ROUTE => path,
          #   OpenTelemetry::SemanticConventions::Trace::HTTP_URL =>
          # }
        end

        def endpoint_expand_path(endpoint)
          # TODO: copied from ddog implementation, so we need to double check
          route_path = endpoint.options[:path]
          namespace = endpoint.routes.first&.namespace || ''

          parts = (namespace.split('/') + route_path).reject { |p| p.blank? || p.eql?('/') }
          parts.join('/').prepend('/')
        end
      end
    end
  end
end
