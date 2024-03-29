require "google/apis/gmail_v1"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require 'webrick'

class OAuthCallbackWebServer

  # @return [WEBrick::HTTPServer] srv
  attr_accessor :srv
  attr_accessor :code

  def initialize(addr = 'localhost', port = 80)
    self.srv = WEBrick::HTTPServer.new(
      BindAddress: addr,
      Port: port,
      :Logger => WEBrick::Log.new("/dev/null", WEBrick::Log::INFO),
      :AccessLog => [[File.open("/dev/null", 'w'), WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
    )
    self.add_get_code_handler
  end

  def add_get_code_handler
    # @type [WEBrick::HTTPRequest] req
    # @type [WEBrick::HTTPResponse] res
    proc = Proc.new { |req, res|
      code = req.query['code']
      self.code = code
      res.body = "oauth finished. your code is #{code}"
      res.status = 200
      self.srv.shutdown
    }
    self.srv.mount_proc('/oauth2callback', proc)
  end

  def start
    t = Thread.start do
      self.srv.start
    end
    t.join
    { code: self.code }
  end

  def wait_for_response
    self.start
  end

end

client_secret_path = File.expand_path(File.dirname(__FILE__) + "/./credentials/client_secret.json")

$stdout.puts <<-EOS
########
client_secret.json path を入力
  #
  # 準備 client_secret/client_id steps.
  # 
  0.  GCP(https://console.cloud.google.com/) にアクセス、プロジェクトを作成
      0.1 プロジェクト作成(https://console.cloud.google.com/cloud-resource-manage).
      0.2 Gmail API をプロジェクトで有効に. (https://console.cloud.google.com/apis/library/gmail.googleapis.com)
  1. 認証情報を作成 Credentials(https://console.cloud.google.com/apis/credentials/oauthclient).
  2. OAuth Client をデスクトップアプリで作成。
  3. JSON(client_secret.json)をダウンロード。secretが含まれてることを確認。

  準備ができたら、secret.json を保存する。


default=#{client_secret_path}
EOS
$stdout.print(" path > ")
path = $stdin.gets
client_secret_path = path.to_s.strip unless path.to_s.strip.empty?

token_path = File.expand_path(File.dirname(__FILE__) + "/./credentials/tokens.yaml")
$stdout.puts <<-EOS
#########
token.yml パスを指定
  token.yml にユーザーのトークン(access_token/refresh_token)を保存。
   
default=credentials/tokens.yaml
EOS
$stdout.print(" path > ")
path = $stdin.gets
token_path = path.to_s.strip unless path.to_s.strip.empty?

user_id = "default_user"
$stdout.puts <<-EOS
Enter user id to be oauth.
  user_id will be used to distingush user access_token. 
   
default="default_user@example.com"
EOS
$stdout.print(" user_id > ")
name = $stdin.gets
user_id = name.to_s.strip unless name.to_s.strip.empty?

####
SCOPE = 'https://mail.google.com/'
# OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
OOB_URI = 'http://localhost:8080/'
APPLICATION_NAME = "Google Account OAuth for Gmail"
authorizer = Google::Auth::UserAuthorizer.new(
  Google::Auth::ClientId.from_file(client_secret_path),
  SCOPE,
  Google::Auth::Stores::FileTokenStore.new(file: token_path)
)

url = authorizer.get_authorization_url(base_url: OOB_URI)
credentials = authorizer.get_credentials(user_id)
if credentials.nil?
  url = authorizer.get_authorization_url(base_url: OOB_URI)
  puts <<-EOS
  #### 
  Open the following URL in the browser and enter the resulting code after authorization:
  #{url}

  Code Showing in Browser
  EOS
  s = OAuthCallbackWebServer.new('localhost', '8080')
  ret = s.wait_for_response
  p ret
  credentials = authorizer.get_and_store_credentials_from_code(
    user_id: user_id, code: ret[:code], base_url: OOB_URI
  )

else
  puts "###"
  puts "Token is exists. refresh access token."
  credentials.refresh!
end

puts "###"
puts "UserID:#{user_id}"
puts "AccessToken:#{credentials.access_token}"
puts "RefreshToken:#{credentials.refresh_token}"
puts "tokes are saved in #{token_path}"

puts "####"
puts "Test Access Gmail Api as User(#{user_id})"
service = Google::Apis::GmailV1::GmailService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = credentials
result = service.list_user_labels user_id
puts "Get Gmail Labels"
puts "Labels:"
puts "No labels found" if result.labels.empty?
result.labels.each { |label| puts "- #{label.name}" }




