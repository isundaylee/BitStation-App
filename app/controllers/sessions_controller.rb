class SessionsController < ApplicationController
  require 'securerandom'
  require 'open-uri'
  require 'json'

  def new
    @auth_link = 'https://jiahaoli.scripts.mit.edu:444/bitstation/authenticate/?auth_token=' + generate_auth_token
  end

  def authenticate
    token = params[:auth_token]
    check_link = 'https://jiahaoli.scripts.mit.edu:444/bitstation/check/?auth_token=' + token
    result = JSON.parse(open(check_link).read)

    if result && result["success"]
      user = User.find_by(kerberos: result["kerberos"])

      if user.nil?
        user = User.create({
          kerberos: result["kerberos"],
          name: result["name"]
        })
      end

      sign_in user

      redirect_to root_path
    else
      redirect_to sessions_fail_path(message: 'Authentication failed. ')
    end
  end

  def fail
    @message = params[:message]
  end

  def destroy
    sign_out if signed_in
    redirect_to root_path
  end

  private

    def generate_auth_token
      SecureRandom.hex
    end
end
