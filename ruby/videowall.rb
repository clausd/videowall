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
  EventMachine.kqueue = true if EventMachine.kqueue?
  class MyWeb < Sinatra::Base
    enable :inline_templates
    get '/' do
      erb :index
    end
  end
  module KinectWatcher
    def process_exited
      KinectWatcher.start_kinect
    end
    def self.start_kinect
      curdir = Dir.pwd
      begin
        Dir.chdir('../application.macosx')
        system('nohup ./videowall.app/Contents/MacOS/JavaApplicationStub &')
      ensure
        Dir.chdir(curdir)
      end
    end
  end
  from_processing = OSC::EMServer.new( 12001 )
  from_processing.add_method('/kinect/reload') do |message|
    kinect_pid = `ps | grep videowall.app | grep -v grep`.split(' ').first.to_i
    if kinect_pid > 0
      p "Going to kill kinect process with PID " + kinect_pid.to_s
      EM.defer do 
        p 'Killing'
        system('kill ' + kinect_pid.to_s)
        sleep 10
        KinectWatcher.start_kinect
        system('osascript gotochrome.applescript')
      end
    else
      p "No kinect process found"
    end
  end
  from_processing.add_method('/test') do |message|
    p "TEST from ux: " + message.to_a.inspect
    ws.send(message.to_a.to_json)
  end
  to_processing = OSC::Client.new( 'localhost', 12000 )
  EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
    from_processing.add_method('/kinect/hand') do |message|
      p "Getting the message in state " + ws.state.to_s
      if ws.state == :connected
        ws.send(message.to_a.to_json)
      end
    end
    ws.onopen    { p "WebSocket open"; ws.send ["Open, says server"].to_json; }
    ws.onmessage do |msg| 
      if msg == "close"
        ws.send "Close"
        ws.close_connection(true)
      else
        p 'receiving ' + msg.inspect
      end
    end
    ws.onclose   { p "WebSocket closed" ; }
    ws.onerror {|error| p "Error: " + error.inspect}
  end
  from_processing.run
  MyWeb.run!({:port => 5000})
  if ARGV[0] == 'start'
    KinectWatcher.start_kinect
    sleep 10
    system('osascript gotochrome.applescript')
  else
    p "Use argument start if you want to also start apps + load url"
  end
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

    // video UI
    Tap.playing = null;
    Tap.active = undefined;
    Tap.calibration = false;
    Tap.maxx = 0;
    
    // required onload callback
    function onYouTubePlayerReady(playerId) {
      // alert("Ready to cue");
    }
    
    // load player
    function makePlayer(playerid, left, top, width, height) {
      var ctx = $( '<div />');
      ctx.attr('id', playerid + '_replace');
      $('#container_for_' + playerid).append(ctx);
      var params = { allowScriptAccess: "always" };
      var atts = { id: playerid };
      swfobject.embedSWF("http://www.youtube.com/apiplayer?enablejsapi=1&version=3&v=MJjpFYVvwBo",
                       playerid + '_replace', width, height, "8", null, null, params, atts);
    }
    function makeControls(playerid,left, top, w, h) {
      var ctx = $( '<canvas />');
      ctx.attr('id', playerid + '_canvas');
      $('#container_for_' + playerid).append(ctx);
      ctx.css({position: 'relative', top: -h, left: 0, width: w, height: h});
      ctx.get(0).getContext("2d").globalAlpha = 0.5;
    }
    function makeVideobox(videoid, left, top, width, height) {
      var container = $('<div />');
      container.attr('id', 'container_for_' + videoid);
      $('body').append(container);
      container.css({position: 'absolute', top: top, left: left, width:width, height: height});
      makePlayer(videoid, left, top, width, height);
//      makeControls(videoid, top, left, width, height);
    }
    
    function cueVideo(videoid, left, top, width, height) { // this is broken - need better load check
      makeVideobox(videoid, left, top, width, height);
      window.setTimeout(function() {
        var player = document.getElementById(videoid);
        player.cueVideoById(videoid);
        }, 3000);
    }
    function playVideo(element) {
      if (Tap.playing != null) {
        if (Tap.playing == element) {
          return
        } else {
          rewindVideo(Tap.playing);
        }
      }
      element.playVideo();
      $(element).css({width:800,height:450});
      Tap.playing = element;
    }
    function pauseVideo(element) {
      if (Tap.playing == element) {
        element.pauseVideo();
        $(element).css({width:400,height:225});
        $(element).parent({left: $(element).offset().left+200,top:$(element).offset().top+112});
        Tap.playing = null;
      }
    }
    function rewindVideo(element) {
      if (Tap.playing == element) {
        element.seekTo(0);
        $(element).parent().css({top:50+Math.random()*100})
        $(element).css({width:400,height:225});
        Tap.playing = null;
      }
    }
    
    function calibrate() {
      Tap.calibration = !Tap.calibration
      if (Tap.calibration) {
        Tap.maxx = 0;
        Tap.minx = 1000
        Tap.maxy = 0;
        Tap.miny = 1000;
        Tap.active = $('#calibrate');
        window.setTimeout(function() {calibrate();}, 5000);
      } else if (Tap.maxx > 0) {
        $('#calibrate').hide(); // switch off the button
        <% if params['playlist'] %>
          // define a playlist
        <% end %>
      }
    }
    
    
    // display setup
    $(window).resize(function() {
        $('#playzone').css({position:'absolute', top: $(window).height()-400})
        // $('#infozone').css({position:'absolute', top: $(window).height()-300})
    });
    
    $(document).ready(function(){
      function debug(str){ $("#debug").append("<p>"+str+"</p>"); };

      // comms
      ws = new WebSocket("ws://localhost:8080/websocket");
      debug("opening");
      ws.onmessage = function(evt) { window.focus(); var obj = JSON.parse(evt.data); raw_movement(obj)};
      ws.onclose = function() { debug("close"); };
      ws.onopen = function()  { debug("open"); };
      Tap.socket = ws;
      
      // control
      
      function raw_movement(obj) {
        var state = obj[0];
        var x = obj[1];
        var y = obj[2];
        var mass = obj[3];
        var dx = obj[4];
        var dy = obj[5];
        //var target = findTarget(x,y);
        if (Tap.calibration) {
          Tap.minx = Math.min(Tap.minx,x);
          Tap.maxx = Math.max(Tap.maxx,x);
          Tap.miny = Math.min(Tap.miny,y);
          Tap.maxy = Math.max(Tap.maxy,y);
        }
        if (Tap.maxx>0) {
          movement(state,(x-Tap.minx)/(Tap.maxx-Tap.minx)*$(window).width()-Tap.active.width()/2,
                   (y-Tap.miny)/(Tap.maxy-Tap.miny)*$(window).height()-Tap.active.height()/2);
        } else {
          movement(state,x,y);
        }
      }
      function movement(state,x,y) {
        var elem = document.elementFromPoint(x,y);
        if (elem != null && elem.type == "application/x-shockwave-flash") { // we're happy to move a video
          // alert("ready to move!");
          je = $(elem);
          je.parent().css({left:x-je.width()/2,top:y-je.height()/2})
          if (je.offset().top + je.height() > $(window).height()-400) {
            playVideo(elem);
          } else {
            if (Tap.playing == elem) {
               if (state == 0){
                rewindVideo(elem); // pop back on top
              } else {
                pauseVideo(elem); // just make it smaller and freeze it
              }
            }
          }
        }
      }
      cueVideo('MJjpFYVvwBo',100,100,400,225);
      cueVideo('QcgoGgpyF80',600,100,400,225);
    });
    </script>
    <style>
      body {
          font-size:20px;
          font-family:helvetica,arial;
          font-weight:bold;
          margin:0px;
          padding:0px;
        }
      .activearea {
        font-size:500%;
        color:gray;
        background-color:black;
        text-align:center;
        margin-top:100px;
      }
    </style>
  </head>
  <body>
    <div id="debug" style="display:none;"></div>
    <div id="calibrate"><a href="javascript:void(0);" onclick="calibrate();">Calibrate</a></div>
    
    <div id="playzone" class="activearea" style="float:left; width:100%; height:300px;">PLAY</div>
    <!-- <div id="infozone" class="activearea" style="float:left; width:50%; height:300px;">INFO</div> -->

  </body>
</html>
