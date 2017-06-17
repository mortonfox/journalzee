require 'oauth2'
require 'webrick'

CLIENT_ID = '********'
CLIENT_SECRET = '********'
REDIRECT_URL = 'http://localhost:8558/oauth2/callback'

$code = nil

class Callback < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    if request.query['code']
      $code = request.query['code'] unless $code

      response.status = 200
      response.content_type = 'text/plain'
      response.body = 'Okay'
    else
      response.status = 400
      response.content_type = 'text/plain'
      response.body = 'Missing code parameter'
    end
  end
end

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

while not $code
  sleep 1
end

server.shutdown
puts "code = #{$code}"

token1 = client.auth_code.get_token($code, :redirect_uri => REDIRECT_URL)

token_hash = token1.params['data']['token']
p token_hash

token = OAuth2::AccessToken.from_hash(client, token_hash)
token.options[:header_format] = '%s'

puts "Bearer token: #{token.token}"

res = token.post('/user', body: "data=#{{username: 'mortonfox'}.to_json}")

case res.status
when 200
  p res.parsed
else
  warn "#{res.status} #{res.body}"
end

__END__
