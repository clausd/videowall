import processing.core.*; 
import processing.xml.*; 

import org.openkinect.*; 
import org.openkinect.processing.*; 
import interfascia.*; 
import unlekker.util.*; 
import unlekker.geom.*; 
import unlekker.data.*; 
import org.openkinect.*; 
import org.openkinect.processing.*; 
import oscP5.*; 
import netP5.*; 

import librarytests.*; 
import interfascia.*; 
import unlekker.util.*; 
import org.openkinect.*; 
import unlekker.geom.*; 
import unlekker.data.*; 
import org.openkinect.processing.*; 
import ec.util.*; 

import java.applet.*; 
import java.awt.Dimension; 
import java.awt.Frame; 
import java.awt.event.MouseEvent; 
import java.awt.event.KeyEvent; 
import java.awt.event.FocusEvent; 
import java.awt.Image; 
import java.io.*; 
import java.net.*; 
import java.text.*; 
import java.util.*; 
import java.util.zip.*; 
import java.util.regex.*; 

public class videowall extends PApplet {

// Kinect photo booth + boxing game








// UI
GUIController c;
//IFTextField email;
IFLabel question;
IFLabel response;

boolean do_update = true;

// Kinect Library object
Kinect kinect;
Kinectutils ku;

// calibration
char controlled_parm = ' ';
float delta = 0.1f;
boolean translation_on = false;

// interface functions
UXComms ux = new UXComms();

public void setup() {
  size(800,600,P3D);
  frameRate(15);
  colorMode(HSB,100);

  // Kinect setup:
  kinect = new Kinect(this);
  kinect.start();
  kinect.enableDepth(true);
  //  kinect.enableRGB(true);

  // We don't need the grayscale image in this example
  // so this makes it more efficient
  kinect.processDepthImage(false);
  ku = new Kinectutils(kinect);
  ku.loadSettings(); // always load settings from disk
   
  // GUI features
  c = new GUIController(this);
//  email = new IFTextField("Email Field", 25, 50, 150);
  question = new IFLabel("", 25, 20);
  response = new IFLabel("", 25, 80);

//  c.add(email);
  c.add(question);
  c.add(response);

  //email.addActionListener(this);
  // ui color
  IFLookAndFeel white = new IFLookAndFeel(this, IFLookAndFeel.DEFAULT);
  white.textColor = color(100,0,100);
  question.setLookAndFeel(white);
  response.setLookAndFeel(white);
}

public void draw() {
  if (do_update) {
    pushMatrix();
    background(100,0,10);
    fill(255);
    textMode(SCREEN);

    // Get the raw depth as array of integers
    ku.update(true);

    // Translate and rotate
    translate(width/2,height/2,-50);
    rotateY(sin(0.0f*3.14f)); // don't need to mangle the angle like this - use a fixed perspective (slightly from side)
//    print("(min , max) = " + ku.minz + "," + ku.maxz + " stats fixed? + " + !ku.enable_stats + " \n");

    PVector weighted2d = new PVector();
    float mass2d = 0;

    for(int x=0; x<ku.w; x+=ku.skip) {
      for(int y=0; y<ku.h; y+=ku.skip) {
        int offset = x+y*ku.w;
        PVector v = ku.world[offset];
        // draw only pixels in desirable box of pixels.....
        if (v.z<ku.maxz-ku.back && ku.minz-ku.front < v.z) {
          stroke(255);
          pushMatrix();
          float factor = 600;
          translate(-v.x*factor,v.y*factor,factor-v.z*factor);
          float visX = screenX(0,0,0);
          float visY = screenY(0,0,0);
          float weight = 1.0f/(v.z-ku.minz);
          if (0 < visX && visX < width && 0 < visY && visY < height) {
            weighted2d.x += visX*weight;
            weighted2d.y += visY*weight;
            mass2d += weight;
            // Draw a point
            int c = color(100-((v.z-ku.minz)/0.8f*100)/2,100,100);
            stroke(c);
            fill(c);
            beginShape();
            vertex(0,-1);
            vertex(1,0);  
            vertex(0,1);
            vertex(-1,0);
            endShape();
          }
          popMatrix();
        }
      }
    }
    popMatrix();
    if (ku.is_stale) {
      ux.signalReload();
      return;
    }
    if (mass2d > 0.0f) {
      int c = color(80,100,100);
      stroke(c);
      fill(c);
      weighted2d.div(mass2d);
      ellipse(weighted2d.x,weighted2d.y,20,20);
      ux.observe(weighted2d,mass2d);
    } else {
      ux.observe_empty();
    }
  }
}

public void keyPressed() {
  if (key == 'x' || key == 'y' || key == 'z' || key == 'f' || key == 'b' || key == ' ') {
    controlled_parm = key;
  } 
  else if (key == CODED) {
    if (keyCode == UP) {
      ku.reConfigure(controlled_parm,translation_on,delta);
    } 
    else if (keyCode == DOWN) {
      ku.reConfigure(controlled_parm,translation_on,-delta);
    }
  }
  else if (key == 'c') {
    ku.center();
  } 
  else if (key == 't') {
    translation_on = !translation_on;
  }
  else if (key == 'u') {
    delta = delta*10;
  } 
  else if (key == 'd') {
    delta = delta/10;
  } 
  else if (key == 'r') {
    ku.reset();
  }
  else if (key == 'k') {
    ku.toggleStats();
  }
  else if (key == 'l') {
    // load settings from disk
    ku.loadSettings();
  } 
  else if (key == 's') {
    // save settings to disk
    ku.saveSettings();
  }
  else if (key == 'q') {
    ux.signalReload();
  }
  if (controlled_parm != ' ') {
    question.setLabel("Calibrating " + controlled_parm);
    String details = "";
    if (translation_on) {
      details = "Translation on. ";
    }
    details = details + " delta=" + delta;
    response.setLabel(details);
  }
  else {
    question.setLabel("");
    response.setLabel("");
  }
}

public void stop() {
  kinect.quit();
  super.stop();
}






class Kinectutils {
  float[] depthLookUpTable = new float[2048];
  boolean ran_once = false;

  final double fx_d = 1.0f / 5.9421434211923247e+02f;
  final double fy_d = 1.0f / 5.9104053696870778e+02f;
  final double cx_d = 3.3930780975300314e+02f;
  final double cy_d = 2.4273913761751615e+02f;
  // Size of kinect image
  final int w = 640;
  final int h = 480;
  float stale_depth = -10;

  Kinect _k;
  int skip = 4;
  int[] _depth = null;
  PVector[] world = null;
  int[] _buckets = new int[10];
  int _npixels = 0;
  float minz;
  float maxz;
  PVector center;
  PMatrix3D _transform = new PMatrix3D();

  float front = 0;
  float back = 0;
  boolean enable_stats = true;
  boolean is_stale = false;

  Kinectutils(Kinect k) {
    _k = k;
    setup();
  }

  Kinectutils(Kinect k, int skip, int buckets) {
    skip = skip;  
    _buckets = new int[buckets];
    _k = k;
    setup();
  }

  public void setup() {
    if (!ran_once) {
      // Speedup: Lookup table for all possible depth values (0 - 2  047)
      for (int i = 0; i < depthLookUpTable.length; i++) {
        depthLookUpTable[i] = rawDepthToMeters(i);
      }
      ran_once = true;
    }
  }

  public void update() {
    update(false);
  }

  public void update(boolean update_stats) {
    _depth = _k.getRawDepth();
    if (world == null) {
      world = new PVector[_depth.length];
    }
    if (update_stats && enable_stats) {
      minz = abs(_transform.determinant())*10000f;
      maxz = 0;
      _npixels = 0;
      center = new PVector();
    }
    int totaldepth = 0;
    for(int x=0; x<w; x+=skip) {
      for(int y=0; y<h; y+=skip) {
        int offset = x+y*w;
        // Convert kinect data to world xyz coordinate
        int rawDepth = _depth[offset];
        totaldepth *= offset*rawDepth;
        if (rawDepth > 0) {
          PVector v = new PVector();
          _transform.mult(depthToWorld(x,y,rawDepth),v);
          world[offset] = v;
          if (update_stats && enable_stats) {
            center.add(v);
            minz = min(v.z,minz);
            maxz = max(v.z,maxz);
            _npixels += 1;
          }
        } 
        else {
          world[offset] = null;
        }
      }
    }
    if (update_stats && enable_stats) {
      center.div(_npixels);
    }
    if (totaldepth > 0) {
//      println(totaldepth);
      if (stale_depth == totaldepth) {
//        println("Gone stale");
        is_stale = true;
      }
      stale_depth = totaldepth;
    }
  }


  public void reConfigure(char parameter, boolean translate_on, float dv) {
    if (parameter == 'x') {
      if (translate_on) {
        _transform.translate(dv,0,0);
      } else {
        _transform.rotateX(dv);
      }
    }
    if (parameter == 'y') {
      if (translate_on) {
        _transform.translate(0,dv,0);
      } else {
        _transform.rotateY(dv);
      }
    }
    if (parameter == 'z') {
      if (translate_on) {
        _transform.translate(0,0,dv);
      } else {
        _transform.rotateZ(dv);
      }
    }
    if (parameter == 'f') {
      front = front + dv;
    }
    if (parameter == 'b') {
      back = back + dv;
    }
  }
  
  public void center() {
    _transform.translate(-center.x,-center.y);
  }

  public void reset() {
    front = 0;
    back = 0;
    enable_stats = true;
    _transform = new PMatrix3D();
  }
  
  public void toggleStats() {
     enable_stats = !enable_stats;
  }
  
  //  void depthStats(int nbuckets) {
  //    float minz = 10000;
  //    for (int i=0; i < _depth.length; i++) {
  //      if (realDepth(_depth[i]) > 0) {
  //        npixels++;
  //        minz = min(Kinectutils.realDepth(depth[i]),minz);
  //      }
  //    }
  //  }

  public float realDepth(int depthValue) {
    return depthLookUpTable[depthValue];
  }
  // These functions come from: http://graphics.stanford.edu/~mdfisher/Kinect.html
  public float rawDepthToMeters(int depthValue) {
    if (depthValue < 2047) {
      return (float)(1.0f / ((double)(depthValue) * -0.0030711016f + 3.3309495161f));
    }
    return 0.0f;
  }

  public PVector depthToWorld(int x, int y, int depthValue) {
    PVector result = new PVector();
    double depth =  depthLookUpTable[depthValue];//rawDepthToMeters(depthValue);
    result.x = (float)((x - cx_d) * depth * fx_d);
    result.y = (float)((y - cy_d) * depth * fy_d);
    result.z = (float)(depth);
    return result;
  }

  public void saveSettings() {
    Settings s = new Settings("settings.txt");
    float dumpable[] = new float[16];
    _transform.get(dumpable);
    s.addFloats(dumpable);
    s.addFloat(front);
    s.addFloat(back);
    if (!enable_stats) {
      s.addFloat(minz);
      s.addFloat(maxz);
    }
    s.saveSettings();
  }

  public void loadSettings() {
    Settings s = new Settings("settings.txt");
    int lines = s.loadSettings();
    if (lines >= 18) {
      float dumped_mat[] = new float[16];
      s.readFloats(dumped_mat);
      _transform.set(dumped_mat);
      front = s.readFloat();
      back = s.readFloat();
      if (lines >= 20) {
        enable_stats = false;
        minz = s.readFloat();
        maxz = s.readFloat();
      }
    }
  }
}

class Settings {
   
   String _filename;
   String lines[];
   int i_line = 0;
   String buffer = "";
   String sep = "";
   
   Settings(String f) {
     _filename = f;
   }
   
   public int loadSettings() {
     lines = loadStrings(_filename);
     i_line = 0;
     return lines.length;
   }
   
   public int saveSettings() {
     lines = buffer.split(" ");
     saveStrings(_filename,lines);
     return lines.length;
   }
   
   public float readFloat() {
     return Float.parseFloat(lines[i_line++]);
   }
   
   public void readFloats(float[] farray) {
     for (int i = 0;i<farray.length; i++) {
       farray[i] = readFloat();
     }
   }
   
   public int readInt() {
     return Integer.parseInt(lines[i_line++]);
   }
   
   public String readString() {
      return lines[i_line++];     
   }
   
   public void addString(String s) {
     buffer = buffer + sep + s;
     sep = " ";
   }
   
   public void addInt(int i) {
     addString("" + i);
   }
   
   public void addFloat(float f) {
     addString("" + f);
   }
   
   public void addFloats(float[] a) {
      for (int i = 0; i<a.length; i++) {
       addFloat(a[i]);
      } 
   }
}



class UXComms {
  
  float alfa = 0.8f;
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
  
  public void observe(PVector coords, float mass) {
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
      dev_y = exp_deviation(coords.y,avg_y,dev_y);
      if (l2(dev_x,dev_y)> UXState.SWIPETHRESHOLD) {
        state = UXState.SWIPE;
      } else if (state != UXState.SWIPE) {
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
      send(state,avg_x,avg_y,mass);
    }
//    print("Mass : " + mass + " avg : " + avg_x + "," + avg_y + " dev : " + l2(dev_x,dev_y) + " state : " + state + " - ");
    println("dev : " + l2(dev_x,dev_y) + " state : " + state + " - ");
  }
  
  public void observe_empty() {
    if (state == UXState.SWIPE) {
      send(state, dragged_x, dragged_y, 0, avg_x-dragged_x,avg_y-dragged_y); // swipe is: origin + 
      state = UXState.OFF;
    } else if (state != UXState.OFF) {
      state = UXState.OFF;
      send(state,dragged_x, dragged_y, 0); // signal click end (
    }
  }
  
  public void send(int state, float x, float y, float mass) {
    send(state, x, y, mass, 0 , 0);
  }
  
  public void send(int state, float x, float y,float mass, float dx, float dy) {
    /* in the following different ways of creating osc messages are shown by example */
    OscMessage myMessage = new OscMessage("/kinect/hand");
    
    myMessage.add(state);
    
    myMessage.add(x);
    myMessage.add(y);
    myMessage.add(mass);
    myMessage.add(dx);
    myMessage.add(dy);
  
    /* send the message */
    oscP5.send(myMessage, remoteAddress);  
  }
  
  public void signalReload() {
    OscMessage myMessage = new OscMessage("/kinect/reload");
    oscP5.send(myMessage, remoteAddress);
  }
  
  public float exp_avg(float value, float last_avg) {
//      println("v " + value + " a " + last_avg + " alfa" + alfa);
      return alfa*value+(1-alfa)*last_avg; 
  }

  public float exp_deviation(float value, float exp_avg, float last_dev) {
    return exp_avg(abs(value-exp_avg),last_dev);
  }

  public float l2(float x1, float x2) {
    return sqrt(x1*x1+x2*x2);
  }
}

static class UXState {
  static int OFF = 0;
  static int TOUCH = 1;
  static int CLICK = 2; // this is not important
  static int DRAG = 3;
  static int SWIPE = 4;
  static float DRAGTHRESHOLD = 4;   // clearly need to work on good values here....
  static float SWIPETHRESHOLD = 20;
}

  static public void main(String args[]) {
    PApplet.main(new String[] { "--bgcolor=#FFFFFF", "videowall" });
  }
}
