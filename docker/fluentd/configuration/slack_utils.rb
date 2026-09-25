require 'net/http'
require 'uri'
require 'json'

MAX_FIELD_CHARS = 2900
DEBUG_LOG_PATH = '/tmp/slack_debug.log'
SLACK_HTTP_OPEN_TIMEOUT = 2
SLACK_HTTP_READ_TIMEOUT = 5

def debug_log(msg)
  File.open(DEBUG_LOG_PATH, 'a') { |f| f.puts("[#{Time.now}] #{msg}") }
rescue StandardError
  nil
end

def strip_control_chars(str)
  str.to_s
     .gsub(/\e\[[0-9;]*[a-zA-Z]/, '')
     .gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '')
     .scrub('')
end

def truncate(str, limit)
  str.length > limit ? str[0, limit] + "\n... (truncated)" : str
end

def send_to_slack(fields, webhook_url)
  uri = URI(webhook_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = SLACK_HTTP_OPEN_TIMEOUT
  http.read_timeout = SLACK_HTTP_READ_TIMEOUT
  request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  request.body = fields.to_json

  begin
    response = http.request(request)
  rescue StandardError => e
    debug_log("HTTP request failed, dropping message: #{e.class} #{e.message}")
    return
  end

  debug_log("REQUEST: #{fields.to_json}")
  debug_log("RESPONSE: #{response.code} #{response.body}")

  if response.code == '429'
    debug_log("Slack API throttled (429), dropping message: #{fields['tag']}")
    return
  end

  puts "Slack webhook error: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)
end

def entry_to_fields(entry)
  tag         = strip_control_chars(entry['tag'] || entry['tag_key'] || 'unknown')
  message     = strip_control_chars(entry['message_key'] || entry['log'] || '')
  category    = strip_control_chars(entry['category_key'] || 'general')
  stack_trace = strip_control_chars(entry['stack_trace'] || 'N/A')

  {
    'tag'         => truncate(tag, MAX_FIELD_CHARS),
    'message'     => truncate(message, MAX_FIELD_CHARS),
    'category'    => truncate(category, MAX_FIELD_CHARS),
    'stack_trace' => truncate(stack_trace, MAX_FIELD_CHARS)
  }
end

def process_slack_messages(file_path, webhook_url)
  unless File.exist?(file_path)
    debug_log("File not found: #{file_path}")
    return
  end

  excluded_patterns = [
    /Warning: got packets out of order/i,
  ]

  File.readlines(file_path).each do |line|
    begin
      entry = JSON.parse(line)
      fields = entry_to_fields(entry)

      next if excluded_patterns.any? { |pattern| fields['message'] =~ pattern }

      send_to_slack(fields, webhook_url)
    rescue JSON::ParserError => e
      debug_log("Failed to parse line: #{line}. Error: #{e.message}")
    end
  end
end