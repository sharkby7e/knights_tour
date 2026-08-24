class ApplicationController < ActionController::Base
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :redirect_www_to_apex

  private

  def redirect_www_to_apex
    return unless request.host == "www.sidquinsaat.com"

    redirect_to "https://sidquinsaat.com#{request.fullpath}", status: :moved_permanently, allow_other_host: true
  end
end
