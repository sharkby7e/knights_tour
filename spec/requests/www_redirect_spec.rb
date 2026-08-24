require "rails_helper"

RSpec.describe "www redirect", type: :request do
  it "redirects a www request to the same path on the apex domain, permanently" do
    host! "www.sidquinsaat.com"

    get "/tours"

    expect(response).to redirect_to("https://sidquinsaat.com/tours")
    expect(response).to have_http_status(:moved_permanently)
  end

  it "leaves apex requests alone" do
    host! "sidquinsaat.com"

    get "/tours"

    expect(response).to be_successful
  end
end
