require 'cgi'
require 'set'
require 'openssl'
require 'rest_client'
require 'json'

# Version
require "lending_club/version"

# API operations
# require 'lending_club/api_operations/create'
# require 'lending_club/api_operations/update'
# require 'lending_club/api_operations/delete'
require 'lending_club/api_operations/list'

# Resources
require 'lending_club/util'
require 'lending_club/lending_club_object'
require 'lending_club/api_resource'
require 'lending_club/singleton_api_resource'
require 'lending_club/list_object'
require 'lending_club/loan'
# require 'stripe/balance'
# require 'stripe/balance_transaction'
# require 'stripe/customer'
# require 'stripe/certificate_blacklist'
# require 'stripe/invoice'
# require 'stripe/invoice_item'
# require 'stripe/charge'
# require 'stripe/plan'
# require 'stripe/coupon'
# require 'stripe/token'
# require 'stripe/event'
# require 'stripe/transfer'
# require 'stripe/recipient'
# require 'stripe/card'
# require 'stripe/subscription'
# require 'stripe/application_fee'
# require 'stripe/refund'
# require 'stripe/application_fee_refund'

# Errors
require 'lending_club/errors/lending_club_error'
require 'lending_club/errors/api_error'
# require 'lending_club/errors/api_connection_error'
# require 'lending_club/errors/card_error'
# require 'lending_club/errors/invalid_request_error'
require 'lending_club/errors/authentication_error'

module LendingClub
  # DEFAULT_CA_BUNDLE_PATH = File.dirname(__FILE__) + '/data/ca-certificates.crt'
  # @api_base = 'https://api.stripe.com'

  # @ssl_bundle_path  = DEFAULT_CA_BUNDLE_PATH
  # @verify_ssl_certs = true
  # @CERTIFICATE_VERIFIED = false

  class << self
    attr_accessor :api_key, :api_base, :api_version
  end

  def self.api_url(url='')
    @api_base + url
  end

  def self.request(method, url, api_key, params={}, headers={})
    unless api_key ||= @api_key
      raise AuthenticationError.new('No API key provided. ' + 
        'Set your API key using "LendingClub.api_key = <API-KEY>"')
    end

    if api_key =~ /\s/
      raise AuthenticationError.new('Your API key is invalid, as it contains ' +
        'whitespace. (HINT: You can double-check your API key from the ' +
        'Stripe web interface.')
    end

    # request_opts = { :verify_ssl => false }

    # if ssl_preflight_passed?
    #   request_opts.update(:verify_ssl => OpenSSL::SSL::VERIFY_PEER,
    #                       :ssl_ca_file => @ssl_bundle_path)
    # end

    # if @verify_ssl_certs and !@CERTIFICATE_VERIFIED
    #   @CERTIFICATE_VERIFIED = CertificateBlacklist.check_ssl_cert(@api_base, @ssl_bundle_path)
    # end

    params = Util.objects_to_ids(params)
    url = api_url(url)

    case method.to_s.downcase.to_sym
    when :get, :head, :delete
      # Make params into GET parameters
      url += "#{URI.parse(url).query ? '&' : '?'}#{uri_encode(params)}" if params && params.any?
      payload = nil
    else
      payload = uri_encode(params)
    end

    request_opts.update(:headers => request_headers(api_key).update(headers),
                        :method => method, 
                        :open_timeout => 30,
                        :payload => payload, 
                        :url => url, 
                        :timeout => 80)

    begin
      response = execute_request(request_opts)
    rescue SocketError => e
      handle_restclient_error(e)
    rescue NoMethodError => e
      # Work around RestClient bug
      if e.message =~ /\WRequestFailed\W/
        e = APIConnectionError.new('Unexpected HTTP response code')
        handle_restclient_error(e)
      else
        raise
      end
    rescue RestClient::ExceptionWithResponse => e
      if rcode = e.http_code and rbody = e.http_body
        handle_api_error(rcode, rbody)
      else
        handle_restclient_error(e)
      end
    rescue RestClient::Exception, Errno::ECONNREFUSED => e
      handle_restclient_error(e)
    end

    [parse(response), api_key]
  end

  private

  # def self.ssl_preflight_passed?
  #   if !verify_ssl_certs && !@no_verify
  #     $stderr.puts "WARNING: Running without SSL cert verification. " +
  #       "Execute 'Stripe.verify_ssl_certs = true' to enable verification."

  #     @no_verify = true

  #   elsif !Util.file_readable(@ssl_bundle_path) && !@no_bundle
  #     $stderr.puts "WARNING: Running without SSL cert verification " +
  #       "because #{@ssl_bundle_path} isn't readable"

  #     @no_bundle = true
  #   end

  #   !(@no_verify || @no_bundle)
  # end

  # def self.user_agent
  #   @uname ||= get_uname
  #   lang_version = "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})"

  #   {
  #     :bindings_version => Stripe::VERSION,
  #     :lang => 'ruby',
  #     :lang_version => lang_version,
  #     :platform => RUBY_PLATFORM,
  #     :publisher => 'stripe',
  #     :uname => @uname
  #   }

  # end

  # def self.get_uname
  #   `uname -a 2>/dev/null`.strip if RUBY_PLATFORM =~ /linux|darwin/i
  # rescue Errno::ENOMEM => ex # couldn't create subprocess
  #   "uname lookup failed"
  # end

  def self.uri_encode(params)
    Util.flatten_params(params).
      map { |k,v| "#{k}=#{Util.url_encode(v)}" }.join('&')
  end

  def self.request_headers(api_key)
    headers = {
      :authorization => "Authorization #{api_key}",
      :content_type => 'application/json'
    }
  end

  def self.execute_request(opts)
    RestClient::Request.execute(opts)
  end

  def self.parse(response)
    begin
      # Would use :symbolize_names => true, but apparently there is
      # some library out there that makes symbolize_names not work.
      response = JSON.parse(response.body)
    rescue JSON::ParserError
      raise general_api_error(response.code, response.body)
    end

    Util.symbolize_names(response)
  end

  def self.general_api_error(rcode, rbody)
    APIError.new("Invalid response object from API: #{rbody.inspect} " +
                 "(HTTP response code was #{rcode})", rcode, rbody)
  end

  def self.handle_api_error(rcode, rbody)
    begin
      error_obj = JSON.parse(rbody)
      error_obj = Util.symbolize_names(error_obj)
      error = error_obj[:error] or raise LendingClubError.new # escape from parsing

    rescue JSON::ParserError, StripeError
      raise general_api_error(rcode, rbody)
    end

    case rcode
    when 400, 404
      raise invalid_request_error error, rcode, rbody, error_obj
    when 401
      raise authentication_error error, rcode, rbody, error_obj
    when 402
      raise card_error error, rcode, rbody, error_obj
    else
      raise api_error error, rcode, rbody, error_obj
    end

  end

  # def self.invalid_request_error(error, rcode, rbody, error_obj)
  #   InvalidRequestError.new(error[:message], error[:param], rcode,
  #                           rbody, error_obj)
  # end

  def self.authentication_error(error, rcode, rbody, error_obj)
    AuthenticationError.new(error[:message], rcode, rbody, error_obj)
  end

  # def self.card_error(error, rcode, rbody, error_obj)
  #   CardError.new(error[:message], error[:param], error[:code],
  #                 rcode, rbody, error_obj)
  # end

  def self.api_error(error, rcode, rbody, error_obj)
    APIError.new(error[:message], rcode, rbody, error_obj)
  end

  def self.handle_restclient_error(e)
    connection_message = "Please check your internet connection and try again. " \
        "If this problem persists, you should check Stripe's service status at " \
        "https://twitter.com/stripestatus, or let us know at support@stripe.com."

    case e
    when RestClient::RequestTimeout
      message = "Could not connect to Stripe (#{@api_base}). #{connection_message}"

    when RestClient::ServerBrokeConnection
      message = "The connection to the server (#{@api_base}) broke before the " \
        "request completed. #{connection_message}"

    when RestClient::SSLCertificateNotVerified
      message = "Could not verify Stripe's SSL certificate. " \
        "Please make sure that your network is not intercepting certificates. " \
        "(Try going to https://api.stripe.com/v1 in your browser.) " \
        "If this problem persists, let us know at support@stripe.com."

    when SocketError
      message = "Unexpected error communicating when trying to connect to Stripe. " \
        "You may be seeing this message because your DNS is not working. " \
        "To check, try running 'host stripe.com' from the command line."

    else
      message = "Unexpected error communicating with Stripe. " \
        "If this problem persists, let us know at support@stripe.com."

    end

    # raise APIConnectionError.new(message + "\n\n(Network error: #{e.message})")
  end
end
