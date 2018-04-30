['sinatra','haml','thin','rest-client','yaml'].map { |a| require(a) }

class PanoApp < Sinatra::Base
  set :show_exceptions, :after_handler

  def parse_link(link,objid)
    link =~ /@([-?[:digit:]\.]+),([-?[:digit:]\.]+).+,([-?[:digit:]\.]+)y.*,([-?[:digit:]\.]+)h.*,([-?[:digit:]\.]+)t.+\!1s(.+)\!2e/

    # This comes from:
    #  https://stackoverflow.com/questions/32523173/google-maps-embed-api-panorama-id
    panoid = $6.length == 22 ? $6 : "F:#{CGI.escape($6)}"

    { :link  => link,
      :id    => panoid,
      :objid => objid,
      :location => {
        :lat => $1.to_f,
        :lng => $2.to_f
      },
      :pov => {
        :heading => $4.to_f,
        :pitch   => $5.to_f - 90
      }
    }
  end

  def datapoints
    body = RestClient.get("https://gist.githubusercontent.com"+
                          "/gorenje/038a6a617f6501921bcc8be9d2046386/raw").body
    YAML.load(body)[:data]
  end

  def sample_from_datapoints
    datapoints.reject { |a| a.first == params[:l] }.sample
  end

  get '/images/loader.svg' do
    content_type "image/svg+xml"
    haml :loader, :layout => false
  end

  get '/image' do
    content_type :json
    objid,link = sample_from_datapoints
    parse_link(link,objid).to_json
  end

  get '/' do
    @start = datapoints.
               map { |(objid,link)| parse_link(link,objid) }.
               select { |hsh| hsh[:id].length == 22 }.
               sample
    haml :suntraveller, :layout => false
  end
end
