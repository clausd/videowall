import oscP5.*;
import netP5.*;

class UXComms {
  
  float alfa = 0.9;
  float enter_x;
  float enter_y;
  float avg_x;
  float avg_y;
  float dev_x; // low: click, high: swipe - neither: drag
  float dev_y;

  // comms
  OscP5 oscP5 = new OscP5(this,12000);
  NetAddress remoteAddress = new NetAddress("127.0.0.1",12001);
  
  class UXState {
    final int OFF = 0;
    final int TOUCH = 1;
    final int CLICK = 2;
    final int DRAG = 3;
    final int SWIPE = 4;
    final float DRAGTHRESHOLD = 20;   // clearly need to work on good values here....
    final float SWIPETHRESHOLD = 500;
  }
  
  boolean state = UXState.OFF;
  
  void observe(PVector coords, float mass) {
    print("Mass : " + mass + "\n");
    if (state == UXState.OFF) {
      enter_x = coords.x;
      avg_x = enter_x;
      enter_y = coords.y;
      avg_u = enter_y;
      dev_x = 0;
      dev y = 0;
      state = UXState.TOUCH;
    } else {
      avg_x = exp_avg(coords.x,avg_x);
      avg_y = exp_avg(coords.y,avg_y);
      dev_x = exp_deviation(coords.x,avg_x.dev_x);
      dev_y = exp_deviation(coords.y,avg_x.dev_y);
      if (l2(dev_x,dev_y)> UXState.SWIPETHRESHOLD) {
        state = UXState.SWIPE;
      } else if (l2(dev_x,dev_y)> UXState.DRAGTHRESHOLD) {
        state = UXState.DRAG;
      }
    }
    if (state == UXState.TOUCH || state == UXState.DRAG) {
      send(state,avg_x,avg_y);
    }
  }
  
  void observe_empty() {
    if (state == UXState.TOUCH) {
      state = UXState.CLICK;
      send(state,entered_x, entered_y);
    }
    if (state == UXState.SWIPE) {
      send(state, entered_x, entered_y, avg_x-entered_x,avg_y-entered_y,); // swipe is: origin + 
    }
    if (state != UXState.OFF) {
      state = UXState.off;
      send(state,avg_x, avg_y); // signal click end (
    }
  }
  
  send(int state, float x, float y) {
    send(state, x, y, 0 , 0);
  }
  
  send(int state, float x, float y, float dx, float dy) {
       /* in the following different ways of creating osc messages are shown by example */
    OscMessage myMessage = new OscMessage("/kinect/hand");
    
    myMessage.add(state);
    
    myMessage.add(x);
    myMessage.add(y);
    myMessage.add(dx);
    myMessage.add(dy);
  
    /* send the message */
    oscP5.send(myMessage, myRemoteLocation);  
  }
  
  float exp_avg(float value, float last_avg) {
    return alfa*value+(1-alfa)*last_avg; 
  }

  float exp_deviation(float value, float exp_avg, float last_dev) {
    return exp_avg(abs(value-exp_avg),last_dev);
  }

}

