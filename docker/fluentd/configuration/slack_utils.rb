require 'net/http'
require 'uri'
require 'json'

excluded_patterns = [
  /Warning: got packets out of order/i,
]

def send_to_slack(messages, webhook_url)
  payload = {
    'message' => messages.join("\n")
  }

  uri = URI(webhook_url)

  # raise "Invalid URI: #{uri} #{payload.to_json}"

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  request.body = payload.to_json
  response = http.request(request)

  # raise "Response from server: #{response.body}"
end

def entry_to_message_string(entry)
  return "[#{entry['tag_key']}] #{entry['log']}"
end

def process_slack_messages(file_path, webhook_url)
  if File.exist?(file_path)
    file_content = File.read(file_path)

    messages = []

    File.readlines(file_path).map do |line|
      begin
        message = JSON.parse(line)
        
        request = entry_to_message_string(message)
        
        # Skip messages that match any of the excluded patterns
        should_exclude = excluded_patterns.any? { |pattern| request =~ pattern }
        messages << request unless should_exclude

        # File.open('/tmp/matomo.log', 'a') do |file|
        #   file.puts(JSON.pretty_generate(entry))
        # end
      rescue JSON::ParserError => e
        puts "Failed to parse line: #{line}. Error: #{e.message}"
        nil
      end
    end.compact

    if messages.any?
      # split into chunks of 5 messages to avoid Slack API limits of 40000 characters
      messages.each_slice(5) do |chunk|
        send_to_slack(chunk, webhook_url)
      end
    end

  else
    puts "File not found: #{file_path}"
  end
end