class ApplicationController < ActionController::API
  class NotAuthorizedError < Exception; end

  before_action :authenticate

  rescue_from NotAuthorizedError, with: :not_authorized
  rescue_from ApplicationRecord::RecordNotFoundError, with: :render_404

  private

  def not_authorized
    render json: { status: 403, message: "Not authorized" }
  end

  def render_404
    render json: { status: 404, message: "Not found" }
  end

  def authenticate
    # Having a single access token should be good enough for now,
    # as this API is not intended to be used by different clients (for now)
    if params[:access_token] != Rails.application.credentials.access_token
      raise NotAuthorizedError, "Invalid access token"
    end

    true
  end
end
