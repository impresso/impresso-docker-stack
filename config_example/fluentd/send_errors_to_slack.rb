require 'net/http'
require 'uri'
require 'json'
require_relative './slack_utils'

$slack_webhook_url = ENV['SLACK_ERRORS_WEBHOOK_URL']

if $slack_webhook_url.nil?
  puts "Please set SLACK_ERRORS_WEBHOOK_URL environment variable"
  exit 1
end

def main
  file_path = ARGV[0]
  process_slack_messages(file_path, $slack_webhook_url)
end

if __FILE__ == $0
  main
end