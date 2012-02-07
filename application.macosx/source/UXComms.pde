import oscP5.*;
import netP5.*;

class UXComms {
  
  float alfa = 0.09;
  float dragged_x;
  float dragged_y;
  float avg_x;
  float avg_y;
  float dev_x; // low: click, high: swipe - neither: drag
  float dev_y;
  int state = UXState.OFF;

  // comms
  OscP5 oscP5 = new OscP5(this,12000);
  NetAddress remoteAddress = new NetAddress("127.0.0.1",12001);
  
  void observe(PVector coords, float mass) {
    if (state == UXState.OFF) {
      dragged_x = coords.x;
      avg_x = dragged_x;
      dragged_y = coords.y;
      avg_y = dragged_y;
      dev_x = 0;
      dev_y = 0;
      state = UXState.TOUCH;
    } else {
      avg_x = exp_avg(coords.x,avg_x);
      avg_y = exp_avg(coords.y,avg_y);
      dev_x = exp_deviation(coords.x,avg_x,dev_x);
      dev_y = exp_deviation(coords.y,avg_x,dev_y);
      if (l2(dev_x,dev_y)> UXState.SWIPETHRESHOLD) {
        state = UXState.SWIPE;
      } else {
        if (l2(dev_x,dev_y)> UXState.DRAGTHRESHOLD) {
          state = UXState.DRAG;
        } else {
          state = UXState.TOUCH;
        }
        dragged_x = coords.x;
        dragged_y = coords.y;
      }
    }
    if (state == UXState.TOUCH || state == UXState.DRAG) {
      send(state,avg_x,avg_y);
    }
    print("Mass : " + mass + " avg : " + avg_x + "," + avg_y + " dev : " + l2(dev_x,dev_y) + " state : " + state + " - ");
  }
  
  void observe_empty() {
    if (state == UXState.SWIPE) {
      send(state, dragged_x, dragged_y, avg_x-dragged_x,avg_y-dragged_y); // swipe is: origin + 
      state = UXState.OFF;
    } else if (state != UXState.OFF) {
      state = UXState.OFF;
      send(state,dragged_x, dragged_y); // signal click end (
    }
  }
  
  void send(int state, float x, float y) {
    send(state, x, y, 0 , 0);
  }
  
  void send(int state, float x, float y, float dx, float dy) {
    /* in the following different ways of creating osc messages are shown by example */
    OscMessage myMessage = new OscMessage("/kinect/hand");
    
    myMessage.add(state);
    
    myMessage.add(x);
    myMessage.add(y);
    myMessage.add(dx);
    myMessage.add(dy);
  
    /* send the message */
    oscP5.send(myMessage, remoteAddress);  
  }
  
  void signalReload() {
    OscMessage myMessage = new OscMessage("/kinect/reload");
    oscP5.send(myMessage, remoteAddress);
  }
  
  float exp_avg(float value, float last_avg) {
    return alfa*value+(1-alfa)*last_avg; 
  }

  float exp_deviation(float value, float exp_avg, float last_dev) {
    return exp_avg(abs(value-exp_avg),last_dev);
  }

  float l2(float x1, float x2) {
    return sqrt(x1*x1+x2*x2);
  }
}

