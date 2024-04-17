require 'openssl'

class Api::V1::TokensController < ApplicationController
  include Tokenizer

  before_action :set_user
  before_action :set_key_and_pass_phrase, only: [:generate_token]
  before_action :create_encrypted_code, only: [:generate_token]

  def generate_token
    options = {
      secret_key: @encrypted_code,
      algorithm: 'HS256',
      exp: 1.day.from_now
    }
    token = encode({ user_id: @user.id, username: @user.username }, true, options)

    render json: { status: 201, message: "Token created successfully assigned to #{@user.username}", token: token }, status: :created
  end

  def create_token
    generate_authentication_token if params[:token_type] == 'authentication'
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    render json: {
      status: 422,
      errors: e.message
    }, status: :unprocessable_entity
  end

  def set_key_and_pass_phrase
    @key = "keyForTokenAuthorizationAndAuthentication"
    @pass_phrase = "SecretPhraseToAuthenticateAndAuthorizeAPIcalls"
  end

  def create_encrypted_code
    @encrypted_code = OpenSSL::HMAC.hexdigest("SHA256", @key, @pass_phrase)
  rescue StandardError => e
    render json: {
      status: 422,
      errors: [
        "Something went wrong, please try again",
        e.message
      ]
    }, status: :unprocessable_entity
  end

  def generate_authentication_token
    remove_current_token unless @user.token.nil?

    @user.build_token(token_type: params[:token_type])

    if @user.save
      render json: {
        status: 201,
        message: 'Token created successfully',
        token: @user.token.token
      }, status: :created
    end
  rescue ActiveRecord::RecordNotSaved => e
    render json: {
      status: 422,
      error: e.message
    }, status: :unprocessable_entity
  end

  def remove_current_token
    @user.token.delete
  end
end
