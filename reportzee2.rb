require 'oauth2'
require 'webrick'

class MunzeeAPI
  CLIENT_ID = '********'
  CLIENT_SECRET = '********'
  REDIRECT_URL = 'http://localhost:8558/oauth2/callback'

  class HTTPError < StandardError
  end

  class Callback < WEBrick::HTTPServlet::AbstractServlet
    @auth_code = nil

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
      while not @auth_code
        sleep 1
      end
      @auth_code
    end
  end

  def initialize
    @token = nil
  end

  def login
    client = OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET,
                                site: 'https://api.munzee.com',
                                authorize_url: '/oauth',
                                token_url: '/oauth/login',
                                raise_errors: false)
    url = client.auth_code.authorize_url(redirect_uri: REDIRECT_URL, scope: 'read')

    server = WEBrick::HTTPServer.new(Port: 8558)
    server.mount '/oauth2/callback', Callback

    Thread.new {
      server.start
    }

    system("open '#{url}'")

    auth_code = Callback.wait_auth_code

    server.shutdown
    puts "code = #{auth_code}"

    token1 = client.auth_code.get_token(auth_code, :redirect_uri => REDIRECT_URL)

    token_hash = token1.params['data']['token']
    p token_hash

    @token = OAuth2::AccessToken.from_hash(client, token_hash)
    @token.options[:header_format] = '%s'

    puts "Bearer token: #{@token.token}"
  end

  def post path, params
    res = @token.post(path, body: "data=#{params.to_json}")
    if res.status == 200
      res.parsed
    else
      raise HTTPError, "#{res.status} #{res.body}"
    end
  end
end

munz = MunzeeAPI.new

munz.login

result = munz.post('/user', username: 'mortonfox')
p result

__END__
