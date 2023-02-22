# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'bundler/setup'
Bundler.require(:default, :development, :test)

require 'minitest/autorun'
require 'webmock/minitest'
require 'rspec/mocks/minitest_integration'

# global opentelemetry-sdk setup:
EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER)

OpenTelemetry::SDK.configure do |c|
  c.error_handler = ->(exception:, message:) { raise(exception || message) }
  c.logger = Logger.new($stderr, level: ENV.fetch('OTEL_LOG_LEVEL', 'fatal').to_sym)
  c.add_span_processor span_processor
end

# Helper functions
def uninstall_and_cleanup
  instrumentation.instance_variable_set('@installed', false)
  unsubscribe
  EXPORTER.reset
end

def unsubscribe
  subscriptions = [
    'endpoint_run.grape',
    'endpoint_render.grape',
    'endpoint_run_filters.grape',
    'format_response.grape'
  ]
  subscriptions.each { |e| ActiveSupport::Notifications.unsubscribe(e) }
end

def spans_per_operation(operation)
  spans.select { |s| s.attributes['operation'] == operation }
end
