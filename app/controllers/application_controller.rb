class ApplicationController < ActionController::API
  rescue_from Person::RecordNotFoundError, with: :render_404

  def render_404
    render status: 404
  end
end
