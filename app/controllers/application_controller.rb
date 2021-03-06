require 'bitstation_coinbase_client'

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :prepare_flash_class_variable
  before_filter :prepare_oauth_client
  before_filter :warn_unlinked_coinbase_account
  before_filter :check_for_unauthenticated_coinbase_account, except: [:link_coinbase_account, :oauth]
  around_filter :rescue_oauth_exception
  around_filter :rescue_unhandled_exception if Rails.env.production?

  COINBASE_CLIENT_ID = 'e4698a40d15948391bba01e0fd66a292140d9e65623709819267eac4d1f19022'
  COINBASE_CLIENT_SECRET = '4ffe034c38914e1d0a71aa4153954e2a647e6f9b4a2023fd088db220c96cc548'
  COINBASE_CALLBACK_URI = 'https://localhost:3000/sessions/oauth'

  # FIXME must be a better way
  include ActionView::Helpers::JavaScriptHelper

  private

    def coinbase_client_id
      !Rails.env.production? ? COINBASE_CLIENT_ID : ENV["BITSTATION_COINBASE_CLIENT_ID"]
    end

    def coinbase_client_secret
      !Rails.env.production? ? COINBASE_CLIENT_SECRET : ENV["BITSTATION_COINBASE_CLIENT_SECRET"]
    end

    def coinbase_callback_uri
      !Rails.env.production? ? COINBASE_CALLBACK_URI : ENV["BITSTATION_COINBASE_CALLBACK_URI"]
    end

    def ensure_signed_in
      unless signed_in?
        flash[:error] = "Please sign in first. "
        redirect_to root_url
      end
    end

    def ensure_signed_in_without_redirect
      head :forbidden unless signed_in?
    end

    def ensure_coinbase_account_linked
      ensure_signed_in
      if current_user.coinbase_account.nil?
        flash[:error] = "You need to link a Coinbase account first. "
        redirect_to require_coinbase_account_url
      end
    end

    def prepare_flash_class_variable
      @flash ||= {}
    end

    def prepare_oauth_client
      @oauth_client = OAuth2::Client.new(coinbase_client_id, coinbase_client_secret, site: 'https://coinbase.com')
    end

    def warn_unlinked_coinbase_account
      if signed_in? && current_user.coinbase_account.nil?
        @flash[:warning] = "You haven't linked a Coinbase account yet. You can link it #{view_context.link_to 'here', link_coinbase_account_path}. ".html_safe
      end
    end

    def signed_in?
      current_user != nil
    end

    def sign_in(user)
      session[:user_id] = user.id
      session[:auth_token] = user.auth_token
    end

    def has_coinbase_account_linked?
      signed_in? && !current_user.coinbase_account.nil?
    end

    def current_user
      if @current_user
        @current_user
      else
        if session[:access_code]
          @current_user = User.user_with_access_code(session[:access_code])
        else
          @current_user = session[:user_id] && session[:auth_token] && User.find_by(id: session[:user_id], auth_token: session[:auth_token])
        end
      end
    end

    def coinbase_client_with_oauth_credentials(credentials, user = nil)
      BitStationCoinbaseClient.new(coinbase_client_id, coinbase_client_secret, credentials.symbolize_keys, user)
    end

    def current_coinbase_client
      if current_user.coinbase_account && current_user.coinbase_account.oauth_credentials
        @current_coinbase_client ||= coinbase_client_with_oauth_credentials(current_user.coinbase_account.oauth_credentials, current_user)
      else
        nil
      end
    end

    def clear_current_coinbase_oauth_token
      @current_coinbase_client = nil
    end

    def current_user_name
      current_user ? current_user.name : 'Guest'
    end

    def sign_out
      session[:user_id] = nil
      session[:auth_token] = nil
      session[:access_code] = nil
    end

    def rescue_unhandled_exception
      begin
        yield
      rescue => e
        logger.error 'From the unknown error handler: '
        logger.error e.message
        logger.error e.backtrace.join("\n")

        if @is_module
          render inline: '<p>An unknown error happened. '
        else
          flash[:error] = 'An unknown error happened. '
          redirect_to root_url
        end
      end
    end

    def check_for_unauthenticated_coinbase_account
      return unless has_coinbase_account_linked?
      unless (!current_user.coinbase_account.oauth_credentials.empty? rescue false)

        code = ''
        code = 'alert("' + escape_javascript(flash[:error]) + '"); ' if flash[:error]
        render inline: '<script>' + code + 'window.location = "' + link_coinbase_account_url + '"; </script>'.html_safe
      end
    end

    def rescue_oauth_exception
      begin
        yield
      rescue OAuth2::Error
        current_user.update_coinbase_oauth_credentials(nil) if has_coinbase_account_linked?
        render inline: '<script>window.location = "' + link_coinbase_account_url + '"; </script>'.html_safe
      end
    end

    def sign_in_with_access_code(code)
      session[:access_code] = code
    end

    def signed_in_with_access_code?
      session[:access_code] && signed_in?
    end

    def check_for_unlinked_coinbase_account
      render 'dashboard/unlinked_coinbase_account', layout: false unless has_coinbase_account_linked?
    end

    def store_location
      session[:return_to] = request.fullpath if request.get? and controller_name != "sessions" and action_name != 'homepage'
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
    end

    helper_method :current_user, :signed_in?, :current_user_name, :has_coinbase_account_linked?, :sign_in_with_access_code, :signed_in_with_access_code?
end
