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

  get '/images/pixel.svg' do
    content_type "image/svg+xml"
    @clrs = (params[:c] || "fff,"*9).upcase.split(/,/)
    haml :pixel, :layout => false
  end

  get '/pixelart' do
    redirect "9pixel"
  end

  get '/9pixel' do
    src = (0..9).to_a + ('a'..'f').to_a
    @random = [].tap {|t| 9.times {6.times {t << src.sample} ; t << "," }}.join
    @content = {
      "Blackhole" => "000,000,000,000,000,000,000,000,000",
      "Sunset" => "000,000,000,000,000,000,000,fffc0b,000",
      "Sunny" => "3270ed,3270ed,3270ed,3270ed,f0ff00,3270ed,3270ed,3270ed,3270ed",
      "Overcast" => "ccc,ccc,ccc,ccc,f6f2b2,ccc,ccc,ccc,ccc",
      "Sunrise" => "000,000,000,000,000,000,000,ff6d0b,000",
      "Hill" => "000,000,000,000,108a15,000,108a15,108a15,108a15",
      "Mountain" => "000,000,000,000,e4ffe5,000,108a15,108a15,108a15",
      "Horizon" => "3270ed,3270ed,3270ed,3270ed,3270ed,3270ed,108a15,108a15,108a15",
      "Rain" => "3270ed,ccc,3270ed,ccc,3270ed,ccc,108a15,108a15,108a15",
      "Desert" => "3270ed,f0ff00,3270ed,3270ed,3270ed,3270ed,ffb04a,ffb04a,ffb04a",
      "Ocean view on a clear day" => "3270ed,3270ed,f0ff00,3270ed,3270ed,3270ed,3270ed,3270ed,3270ed",
      "Ocean view on overcast day" => "f0ff00,ccc,ccc,ccc,ccc,ccc,3270ed,3270ed,3270ed",
      "Candle" => "f4f1f8,f9cf6a,f4f1f8,f4f1f8,fff,f4f1f8,f4f1f8,fff,f4f1f8",
      "Matchstick" => "f4f1f8,f4f1f8,f4f1f8,fff,fff,f00,f4f1f8,f4f1f8,f4f1f8",
      "Fried Egg" => "fff,fff,fff,fff,f0b700,fff,fff,fff,fff",
      "Snowstorm (by night)" => "fff,000,fff,000,fff,000,fff,000,fff",
      "Snowstorm (by day)" => "fff,fff,fff,fff,fff,fff,fff,fff,fff",
      "Cigarette" => "f4f1f8,ccc,f4f1f8,f4f1f8,f4f1f8,ccc,f9cf6a,fff,f00",
      "Cigar" => "f4f1f8,ccc,f4f1f8,f4f1f8,f4f1f8,ccc,966e0e,966e0e,f00",
      "Lighthouse" => "fdf62d,f9cf6a,fdf62d,302996,fff,302996,302996,fff,302996",
    }
    haml :pixelart, :layout => false
  end

  get '/' do
    @start = JSON(datapoints)["data"].select {|a| a["id"].length == 22}.sample
    haml :suntraveller, :layout => false
  end
end
