require 'oauth2'
require 'webrick'
require 'launchy'

class MunzeeAPI
  REDIRECT_URL = 'http://localhost:8558/oauth2/callback'
  DEFAULT_CONF_FILE = '~/.munzee.conf'
  DEFAULT_TOKEN_FILE = '~/.munzee.token'

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

munz = MunzeeAPI.new(force_login: true,
                     conf_file: '~/.reportzee.conf',
                     token_file: '~/.reportzee.token')

result = munz.post('/user', username: 'mortonfox')
require 'ap'
ap result, indent: -4

__END__
