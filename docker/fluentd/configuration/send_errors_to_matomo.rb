require 'net/http'
require 'uri'
require 'json'

$matomo_domain = ENV['MATOMO_DOMAIN']
$matomo_user_id = ENV['MATOMO_ERROR_USER_ID']

if $matomo_domain.nil? || $matomo_user_id.nil?
  puts "Please set MATOMO_DOMAIN and MATOMO_ERROR_USER_ID environment variables"
  exit 1
end

def entry_to_matomo_request(entry)
  qp = {
    'idsite' => 1,
    'rec' => 1,
    'apiv' => 1,
    'rand' => rand(100000),
    '_id' => $matomo_user_id,
    'e_c' => 'Backend Errors',
    'e_a' => entry['tag_key'],
    'e_n' => entry['log'],
  }

  return "?" + URI.encode_www_form(qp)
end

def send_to_matomo(requests)

  payload = {
    'requests' => requests
  }

  uri = URI("https://#{$matomo_domain}/matomo.php")

  # raise "Invalid URI: #{uri} #{payload.to_json}"

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  request.body = payload.to_json
  response = http.request(request)

  # raise "Response from server: #{response.body}"
end


def main
  file_path = ARGV[0]

  if File.exist?(file_path)
    file_content = File.read(file_path)

    requests = []

    File.readlines(file_path).map do |line|
      begin
        entry = JSON.parse(line)
        
        request = entry_to_matomo_request(entry)
        requests << request

        # File.open('/tmp/matomo.log', 'a') do |file|
        #   file.puts(JSON.pretty_generate(entry))
        # end
      rescue JSON::ParserError => e
        puts "Failed to parse line: #{line}. Error: #{e.message}"
        nil
      end
    end.compact

    if requests.any?
      send_to_matomo(requests)
    end

  else
    puts "File not found: #{file_path}"
  end
end

if __FILE__ == $0
  main
end