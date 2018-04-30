['sinatra','haml','thin','rest-client','yaml'].map { |a| require(a) }

class PanoApp < Sinatra::Base
  set :show_exceptions, :after_handler

  def datapoints
    RestClient.get("https://gist.githubusercontent.com"+
                   "/gorenje/4086f765cde6236f06c4fde0a67e2dd3/raw").body
  end

  get '/locations.json' do
    content_type :json
    datapoints
  end

  get '/images/loader.svg' do
    content_type "image/svg+xml"
    haml :loader, :layout => false
  end

  get '/' do
    @start = JSON(datapoints)["data"].select {|a| a["id"].length == 22}.sample
    haml :suntraveller, :layout => false
  end
end
