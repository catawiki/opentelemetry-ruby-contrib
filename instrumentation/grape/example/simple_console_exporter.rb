# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'pp'

# Outputs {SpanData} to the console.
#
# Potentially useful for exploratory purposes.
class SimpleConsoleExporter
  def initialize
    @stopped = false
  end

  def export(spans, timeout: nil)
    return OpenTelemetry::SDK::Trace::Export::FAILURE if @stopped

    Array(spans).each do |span|
      pp "#{span.name} span_id: #{span.hex_span_id}, trace_id: #{span.hex_trace_id}, parent_id: #{span.hex_parent_span_id}"
    end

    OpenTelemetry::SDK::Trace::Export::SUCCESS
  end

  def force_flush(timeout: nil)
    OpenTelemetry::SDK::Trace::Export::SUCCESS
  end

  def shutdown(timeout: nil)
    @stopped = true
    OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end
