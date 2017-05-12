class ApplicationController < ActionController::API
  rescue_from ApplicationRecord::RecordNotFoundError, with: :render_404

  def render_404
    render json: { status: 404, message: "Not found" }
  end
end
