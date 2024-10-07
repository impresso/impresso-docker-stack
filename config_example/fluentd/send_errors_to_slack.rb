require 'net/http'
require 'uri'
require 'json'

$slack_webhook_url = ENV['SLACK_WEBHOOK_URL']

if $slack_webhook_url.nil?
  puts "Please set SLACK_WEBHOOK_URL environment variable"
  exit 1
end

def entry_to_message_string(entry)
  return "[#{entry['tag_key']}] #{entry['log']}"
end

def send_to_slack(messages)

  payload = {
    'message' => messages.join("\n")
  }

  uri = URI($slack_webhook_url)

  # raise "Invalid URI: #{uri} #{payload.to_json}"

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  request.body = payload.to_json
  response = http.request(request)

  # raise "Response from server: #{response.body}"
end


def main
  file_path = ARGV[0]

  if File.exist?(file_path)
    file_content = File.read(file_path)

    messages = []

    File.readlines(file_path).map do |line|
      begin
        message = JSON.parse(line)
        
        request = entry_to_message_string(message)
        messages << request

        # File.open('/tmp/matomo.log', 'a') do |file|
        #   file.puts(JSON.pretty_generate(entry))
        # end
      rescue JSON::ParserError => e
        puts "Failed to parse line: #{line}. Error: #{e.message}"
        nil
      end
    end.compact

    if messages.any?
      send_to_slack(messages)
    end

  else
    puts "File not found: #{file_path}"
  end
end

if __FILE__ == $0
  main
end