# Generate a list of daily captures suitable for inserting into a
# Livejournal/Dreamwidth post.
# Requires oauth2 and launchy gems. (Run 'gem install oauth2 launchy')
# Run 'ruby journalzee.rb -h' for command line help.

require 'oauth2'
require 'webrick'
require 'optparse'
require 'date'
require 'launchy'

# Wrapper for Munzee API.
class MunzeeAPI
  REDIRECT_URL = 'http://localhost:8558/oauth2/callback'.freeze
  DEFAULT_CONF_FILE = '~/.munzee.conf'.freeze
  DEFAULT_TOKEN_FILE = '~/.munzee.token'.freeze

  class HTTPError < StandardError
  end

  # Servlet to handle authentication callback.
  class Callback < WEBrick::HTTPServlet::AbstractServlet
    @auth_code = nil

    # Handler will extract the auth code from the callback request.
    def do_GET request, response
      if request.query['code']
        self.class.instance_variable_set(:@auth_code, request.query['code']) unless self.class.instance_variable_get(:@auth_code)
        response.body = 'Okay'
        raise WEBrick::HTTPStatus::OK
      else
        response.body = 'Missing code parameter'
        raise WEBrick::HTTPStatus::BadRequest
      end
    end

    def self.wait_auth_code
      sleep 1 until @auth_code
      @auth_code
    end
  end

  def initialize params = {}
    @conf_file = params[:conf_file] || DEFAULT_CONF_FILE
    @token_file = params[:token_file] || DEFAULT_TOKEN_FILE
    load_config

    @token = nil
    @client = OAuth2::Client.new(@client_id, @client_secret,
                                 site: 'https://api.munzee.com',
                                 authorize_url: '/oauth',
                                 token_url: '/oauth/login',
                                 raise_errors: false)

    load_token unless params[:force_login]

    # If the token file cannot be read or the access token has expired or the
    # force_login parameter is true, authenticate with Munzee to get a new
    # access token.
    login if @token.nil? || @token.expired?
  end

  def load_config
    config = YAML.load_file(File.expand_path(@conf_file))

    %w(client_id client_secret).each { |key|
      raise "#{key} is missing from configuration file #{@conf_file}" unless config.key?(key)
      instance_variable_set("@#{key}", config[key])
    }
  end

  def load_token
    File.open(File.expand_path(@token_file)) { |io|
      token_hash = JSON.parse(io.read)
      @token = OAuth2::AccessToken.from_hash(@client, token_hash)
      @token.options[:header_format] = '%s'
    }
  rescue
    nil
  end

  def login
    url = @client.auth_code.authorize_url(redirect_uri: REDIRECT_URL, scope: 'read')

    # Run a WEBrick server to catch the callback after the user authorizes the
    # app.
    log = WEBrick::Log.new($stdout, WEBrick::Log::ERROR)
    server = WEBrick::HTTPServer.new(Port: 8558, Logger: log, AccessLog: [])
    server.mount '/oauth2/callback', Callback

    # Suppress the favicon.ico error message.
    server.mount_proc('/favicon.ico') { raise WEBrick::HTTPStatus::NotFound }

    Thread.new { server.start }

    # Open the authorization URL and wait for the callback.
    Launchy.open(url)

    auth_code = Callback.wait_auth_code

    server.shutdown

    token1 = @client.auth_code.get_token(auth_code, redirect_uri: REDIRECT_URL)

    # Munzee returns the token two levels deep in the JSON response. Extract
    # the token and recreate our AccessToken.
    token_hash = token1.params['data']['token']

    @token = OAuth2::AccessToken.from_hash(@client, token_hash)
    @token.options[:header_format] = '%s'

    # Save the token to the token file.
    File.open(File.expand_path(@token_file), 'w') { |io|
      io.write(@token.to_hash.to_json)
    }
  end

  def post path, params
    res = @token.post(path, body: "data=#{params.to_json}")
    raise HTTPError, "#{res.status} #{res.body}" if res.status != 200
    res.parsed['data']
  end
end

def parse_cmdline
  args = {}

  optp = OptionParser.new

  optp.banner = "Usage: #{File.basename $PROGRAM_NAME} [options] [startdate [enddate]]"

  optp.on('-h', '-?', '--help', 'Option help') {
    puts optp
    exit
  }

  optp.on('-l', '--login', 'Ignore saved token and force a new login') {
    args[:force_login] = true
  }

  optp.separator <<-ENDS
Recommended format for dates is YYYY-MM-DD, e.g. 2017-06-15.
If no dates are specified, process the most recent weekend.
If only one date is specified, it's a one-day date range.
  ENDS

  optp.parse!

  if ARGV.empty?
    # If date range was not specified, use the most recent weekend.
    today = Date.today

    # How many days back to the most recent Saturday?
    mod_saturday = (today.wday - 6) % 7

    # If today is Saturday, we want the previous full weekend.
    mod_saturday = 7 if mod_saturday.zero?

    start_date = today - mod_saturday
    end_date = start_date + 1
  else
    start_date = Date.parse(ARGV.shift)

    end_date = if ARGV.empty?
                 # Just one date specified means a one-day range.
                 start_date
               else
                 Date.parse(ARGV.shift)
               end
  end

  # In case the date range was specified in the wrong order.
  args[:start_date], args[:end_date] = [start_date, end_date].sort

  args
end

def do_report_day munz, date
  result = munz.post('/statzee/player/day', day: date)

  # Omit social munzees.
  captures = result['captures'].reject { |cap| cap['capture_type_id'] == '32' }

  return if captures.empty?

  puts <<-EOM

#{date.strftime '%A %Y-%m-%d'}:

  EOM

  # Iterate over all captures.
  captures.each.with_index(1) { |cap, i|
    url = "https://www.munzee.com/m/#{cap['username']}/#{cap['code']}/"
    puts <<-EOM
#{i}: <a href="#{url}">#{cap['friendly_name']}</a> by #{cap['username']}
    EOM
  }
end

def do_report munz, startdate, enddate
  puts <<-EOM
<lj-cut text="The munzees...">
<div style="margin: 10px 30px; border: 1px dashed; padding: 10px;">
  EOM

  startdate.upto(enddate) { |date|
    do_report_day(munz, date)
    sleep 1 # Avoid flooding the Munzee API.
  }

  puts <<-EOM
</div>
</lj-cut>
  EOM
end

args = parse_cmdline

munz = MunzeeAPI.new(force_login: args[:force_login],
                     conf_file: '~/.journalzee.conf',
                     token_file: '~/.journalzee.token')

do_report(munz, args[:start_date], args[:end_date])

__END__
