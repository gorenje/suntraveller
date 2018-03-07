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
      },
      :zoom => y_to_zoom($3.to_f, $1.to_f).to_i
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
      #map {
        float: bottom;
        height: 100%;
        width: 100%;
      }
      #pano {
        display: none;
      }
      #buttoncontainer {
        z-index: 5;
        position: fixed;
        top: 30px;
        width: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        pointer-events: none;
      }
      .button:hover, .button:focus{
        background-color: rgba(57,150,48,0.50);
      }
      #nextsunbutton {
        pointer-events:auto;
      }
      #waitingForGedot {
        background: url("/images/loader.svg") no-repeat scroll center center rgba(255,255,255,0.7);
        position: fixed;
        height: 100vh;
        width: 100vw;
        z-index: 10000;
        display: none;
      }
      .button {
        padding:40px 25px;
        cursor:pointer;
        background:rgba(53,177,40,0.5);
        border:1px solid rgba(51,132,42,0.50);
        -moz-border-radius: 10px;
        -webkit-border-radius: 10px;
        border-radius: 10px;
        color:#f3f3f3;
        font-size:1.1em;
      }

  %body
    #waitingForGedot
    #buttoncontainer
      %button#nextsunbutton.button{ :onclick => "nextLocation();" }
        Sun Traveller - Next Sun
    #map
    #pano

    :javascript
      var panorama, map, panoramaOptions, panorama2, lastobjid = null;

      function nextLocation() {
        $('#waitingForGedot').fadeIn(500);
        $.get( "/image?l="+lastobjid, function(data) {
          map.setCenter( data.location )
          panorama2.setPano(data.id)
          panorama.setPov(data.pov)
          panorama.setZoom(data.zoom)
          setTimeout(function(){
            $('#waitingForGedot').fadeOut(500);
          },500)
          lastobjid = data.objid;
        }).fail(function(){
          $('#waitingForGedot').fadeOut(500);
        })
      }

      function initialize() {
        google.maps.streetViewViewer = 'photosphere';

        var start = #{@start[:location].to_json};

        panoramaOptions = {
          position: start,
          mode: 'webgl',
          clickToGo: true,
          addressControl: true,
          addressControlOptions: {
              position: google.maps.ControlPosition.TOP_LEFT
          },
          linksControl: true,
          panControl:false,
          enableCloseButton: false,
          zoomControl: true,
          zoomControlOptions:{
              position:google.maps.ControlPosition.RIGHT_TOP
          },
          pov: #{@start[:pov].to_json},
          zoom: #{@start[:zoom]},
          pano: "#{@start[:id]}",
          showRoadLabels: false,
          motionTracking: false,
          motionTrackingControl: true,
          motionTrackingControlOptions:{
              position:google.maps.ControlPosition.RIGHT_TOP
          },

        };

        // This setup, taken from:
        //   https://developers.google.com/maps/documentation/javascript/examples/streetview-overlays
        map = new google.maps.Map(document.getElementById('map'), {
          center: start,
          zoom: 14,
          streetViewControl: false
        });
        panorama = map.getStreetView();
        panorama.setOptions(panoramaOptions);
        panorama.setVisible(true);

        // Why this is done, read this:
        //    https://issuetracker.google.com/issues/35825559#comment216
        panorama2 = new google.maps.StreetViewPanorama(
                          document.getElementById('pano'), panoramaOptions);
        google.maps.event.addListener(panorama2, "pano_changed", function() {
          if ( !(panorama2.getPano().match(/F:/)) ) {
            panorama.setPano( panorama2.getPano() );
          }
        });
      }
    - if ENV['GOOGLE_API_KEY']
      %script{:async => "", :defer => "defer", :src => "https://maps.googleapis.com/maps/api/js?key=#{ENV['GOOGLE_API_KEY']}&callback=initialize"}
        :cdata
    - else
      %script{:async => "", :defer => "defer", :src => "https://maps.googleapis.com/maps/api/js?signed_in=true&callback=initialize"}
        :cdata

@@ loader
!!! XML
%svg#loader-1{"enable-background" => "new 0 0 40 40", :height => "40px", :space => "preserve", :version => "1.1", :viewbox => "0 0 40 40", :width => "40px", :x => "0px", :xmlns => "http://www.w3.org/2000/svg", "xmlns:xlink" => "http://www.w3.org/1999/xlink", :y => "0px"}
  :css
    .loader {
      fill: #044057;
    }
    .loader__circle {
      opacity: .2;
    }
  %path.loader.loader__circle{:d => "M20.201,5.169c-8.254,0-14.946,6.692-14.946,14.946c0,8.255,6.692,14.946,14.946,14.946 s14.946-6.691,14.946-14.946C35.146,11.861,28.455,5.169,20.201,5.169z M20.201,31.749c-6.425,0-11.634-5.208-11.634-11.634 c0-6.425,5.209-11.634,11.634-11.634c6.425,0,11.633,5.209,11.633,11.634C31.834,26.541,26.626,31.749,20.201,31.749z"}
  %path.loader.loader__inner{:d => "M26.013,10.047l1.654-2.866c-2.198-1.272-4.743-2.012-7.466-2.012h0v3.312h0 C22.32,8.481,24.301,9.057,26.013,10.047z"}
    %animateTransform{:attributeType => "xml", :attributeName => "transform", :type => "rotate",  :from => "0 20 20",  :to => "360 20 20", :dur => "0.5s", :repeatCount => "indefinite"}
      :cdata
