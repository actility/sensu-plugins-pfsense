#! /usr/bin/env ruby
#
# metrics-pfsense
#
# DESCRIPTION:
#  metrics-vertx get metrics from VertX
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: rest-client
#
# USAGE:
#
#
# NOTES:
#
# LICENSE:
#   Zubov Yuri <yury.zubau@gmail.com> sponsored by Actility, https://www.actility.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'json'
require 'securerandom'
require 'digest'
require 'uri'

class MetricsPFSense < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-S SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.pfsense"

  option :api_secret,
         description: 'pfSense API Secret',
         short: '-s SECRET',
         long: '--api-secter SECRET'

  option :api_key,
         description: 'pfSense API Key',
         short: '-k KEY',
         long: '--api-key KEY'

  option :host,
         description: 'spSense Host',
         short: '-h HOST',
         long: '--host HOST'

  option :port,
         description: 'spSense Port',
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 80

  option :insecure,
         description: 'Use insecure connection',
         short: '-i',
         long: '--insecure',
         default: false

  option :https,
         long: '--https',
         boolean: true,
         description: 'Enabling https connections',
         default: false

  option :verbose,
         short: '-v',
         long: '--verbose',
         boolean: true,
         description: 'Return more verbose errors',
         default: false

  def auth
    timestamp = Time.now.utc.strftime('%Y%m%dT%H%M%S')
    nonce = SecureRandom.hex(8)
    hash = Digest::SHA256.hexdigest("#{config[:api_secret]}#{timestamp}#{nonce}")
    "#{config[:api_key]}:#{timestamp}:#{nonce}:#{hash}"
  end

  def base_url
    https ||= config[:https] ? 'https' : 'http'
    "#{https}://#{config[:host]}:#{config[:port]}"
  end

  def endpoint
    debug = config[:verbose] ? 'TRUE' : 'FALSE'
    "#{base_url}/fauxapi/v1/?action=system_stats&__debug=#{debug}"
  end

  def request
    RestClient::Request.execute(
      verify_ssl: !config[:insecure],
      method: :get,
      url: endpoint,
      headers: { 'fauxapi-auth' => auth }
    )
  end

  def metrics
    response = request
    ::JSON.parse(response)
  end

  def run
    load_avg = %w[1min 5min 15min]

    metrics['data']['stats'].each do |key, metric|
      if key == 'load_average'
        metric.each_with_index do |value, index|
          output("#{config[:scheme]}.#{key}.#{load_avg[index]}", value)
        end
      else
        output("#{config[:scheme]}.#{key}", metric) unless metric.to_s.empty?
      end
    end
    ok
  end
end
