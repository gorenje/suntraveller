# coding: utf-8
['sinatra','haml','thin','rest-client','yaml'].map { |a| require(a) }

namespace :webapp do
  desc "Start application"
  task :start do
    Thin::Server.new((ENV['PORT']||'3001').to_i).tap do |s|
      s.app = PanoApp
    end.start
  end
end

class PanoApp < Sinatra::Base
  enable :inline_templates
  set :show_exceptions, :after_handler

  def y_to_zoom(y,lat)
    # This comes from:
    #    https://groups.google.com/forum/#!msg/google-maps-js-api-v3/hDRO4oHVSeM/osOYQYXg2oUJ
    Math.log(156543.03392 * Math.cos(lat * Math::PI / 180) / y, 2)
  end

  get '/image' do
    content_type :json
    body = RestClient.get("https://gist.githubusercontent.com"+
                          "/gorenje/038a6a617f6501921bcc8be9d2046386/raw").body
    objid,link = YAML.load(body)[:data].reject {|a| a.first == params[:l]}.sample

    link =~ /@([-?[:digit:]\.]+),([-?[:digit:]\.]+).+,([-?[:digit:]\.]+)y.*,([-?[:digit:]\.]+)h.*,([-?[:digit:]\.]+)t.+\!1s(.+)\!2e/

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
      },
      :zoom => y_to_zoom($3.to_f, $1.to_f).to_i
    }.to_json
  end

  get '/' do
    haml :suntraveller, :layout => false
  end
end

__END__


@@ suntraveller
!!!
%html
  %head
    %script{:src => "https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.min.js"}
    %meta{:charset => "utf-8"}/
    %title Sun Traveller
    :css
      html, body {
        height: 100%;
        margin: 0;
        padding: 0;
        background-color: black;
        color: white;
      }
      #pano {
        float: top;
        height: 80%;
        width: 100%;
      }
      #map {
        float: bottom;
        height: 10%;
        width: 100%;
      }
  %body
    %center
      %h3 Sun Traveller
      %button{ :onclick => "nextLocation();" } Next Sun
    #map
    #pano
    #pano2

    :javascript
      var panorama, map, panoramaOptions, panorama2, lastobjid = null;

      function nextLocation() {
        $.get( "/image?l="+lastobjid, function(data) {
                 map.setCenter( data.location )
                 panorama2.setPano(data.id)
                 panorama.setPov(data.pov)
                 panorama.setZoom(data.zoom)
                 lastobjid = data.objid;
               })
      }

      function initialize() {
        google.maps.streetViewViewer = 'photosphere';

        var start = {lat: 36.058946, lng: -86.789344};

        panoramaOptions = {
            position: start,
            mode: 'webgl',
            clickToGo: true,
            addressControlOptions: {
                position: google.maps.ControlPosition.TOP_LEFT
            },
            linksControl: true,
            panControl:false,
            enableCloseButton: false,
            zoomControlOptions:{
                position:google.maps.ControlPosition.RIGHT_TOP
            },
            pov: {
              heading: 0,
              pitch: 10
            }
        };

        map = new google.maps.Map(document.getElementById('map'), {
          center: start,
          zoom: 14
        });
        panorama = new google.maps.StreetViewPanorama(
                          document.getElementById('pano'), panoramaOptions);
        map.setStreetView(panorama);

        panorama2 = new google.maps.StreetViewPanorama(
                          document.getElementById('pano2'), panoramaOptions);

        // Why this is done, read this:
        //    https://issuetracker.google.com/issues/35825559#comment216
        google.maps.event.addListener(panorama2, "pano_changed", function() {
           if ( !(panorama2.getPano().match(/F:/)) ) {
             panorama.setPano( panorama2.getPano() );
           }
        });

        nextLocation()
      }
    %script{:async => "", :defer => "defer", :src => "https://maps.googleapis.com/maps/api/js?key=#{ENV['GOOGLE_API_KEY']}&callback=initialize"}
      :cdata
