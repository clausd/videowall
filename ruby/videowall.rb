#!/usr/bin/env ruby
require 'rubygems'
require 'em-websocket'
require 'sinatra/base'
require 'thin'
require 'osc-ruby'
require 'osc-ruby/em_server'
require 'json'

# em-websocket relies on bytesize (and nothing else in 1.9 Strings..... Bad, bad library for not doing this so I have to)
if RUBY_VERSION < "1.9"
  class String
    def bytesize
      return self.length
    end
  end
end

EM.run do
  class MyWeb < Sinatra::Base
    enable :inline_templates
    get '/' do
      erb :index
    end
  end
  from_processing = OSC::EMServer.new( 12001 )
  to_processing = OSC::Client.new( 'localhost', 12000 )
  EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
    from_processing.add_method('/kinect/hand') do |message|
      ws.send(message.to_a.to_json)
    end
    from_processing.add_method('/test') do |message|
      p "TEST from ux: " + message.to_a.inspect
      ws.send(message.to_a.to_json)
    end
    ws.onopen    { p "WebSocket open"; ws.send ["Open, says server"].to_json}
    ws.onmessage do |msg| 
      if msg == "close"
        ws.send "Close"
        ws.close_connection(true)
      else
        p 'receiving ' + msg.inspect
#        to_processing.send(OSC::Message.new("/hello", msg))
      end
    end
    ws.onclose   { p "WebSocket closed" }
    ws.onerror {|error| p "Error: " + error.inspect}
  end
  from_processing.run
  MyWeb.run!({:port => 5000})
end


__END__
@@index
<html>
  <head>
    <title>Video wall</title>
    <script src='http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js'></script>
    <script src='http://ajax.googleapis.com/ajax/libs/swfobject/2.2/swfobject.js'></script>

    <script type="text/javascript">
    var Tap = {};
    
    $(document).ready(function(){
      function debug(str){ $("#debug").append("<p>"+str+"</p>"); };

      // comms
      ws = new WebSocket("ws://localhost:8080/websocket");
      debug("opening");
      ws.onmessage = function(evt) { var obj = JSON.parse(evt.data); out = obj[0]; $("#msg").append("<p>"+out+"</p>"); };
      ws.onclose = function() { debug("close"); };
      ws.onopen = function()  { debug("open"); };
      Tap.socket = ws;
      // video UI
      // required onload callback
      function onYouTubePlayerReady(playerId) {
        debug("Player " + playerId + " loaded");
          //ytplayer = document.getElementById("myytplayer");
      }      
    });
    </script>
  </head>
  <body>
    <h1>Debug</h1>
    <div id="debug"></div>
    <div id="ytapiplayer">
        You need Flash player 8+ and JavaScript enabled to view this video.
    </div>
    <script type="text/javascript">
      var params = { allowScriptAccess: "always" };
      var atts = { id: "myytplayer" };
      swfobject.embedSWF("http://www.youtube.com/apiplayer?enablejsapi=1&version=3&v=MJjpFYVvwBo",
                       "ytapiplayer", "425", "356", "8", null, null, params, atts);
      function play() {
        ytplayer = document.getElementById("myytplayer");
        if (ytplayer) {
          ytplayer.cueVideoById("MJjpFYVvwBo");
        }
      }
      // player.getPlaylist():Array
      // player.playVideo()
      // player.seekTo - working with player.getCurrentTime() for swipe actions
    </script>
    <a href="javascript:void(0);" onclick="play();">Play</a>
  </body>
</html>
