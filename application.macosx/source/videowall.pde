// Kinect photo booth + boxing game

import org.openkinect.*;
import org.openkinect.processing.*;
import interfascia.*;
import unlekker.util.*;
import unlekker.geom.*;
import unlekker.data.*;

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
float delta = 0.1;
boolean translation_on = false;

// interface functions
UXComms ux = new UXComms();

void setup() {
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

void draw() {
  if (do_update) {
    pushMatrix();
    background(100,0,10);
    fill(255);
    textMode(SCREEN);

    // Get the raw depth as array of integers
    ku.update(true);

    // Translate and rotate
    translate(width/2,height/2,-50);
    rotateY(sin(0.0*3.14f)); // don't need to mangle the angle like this - use a fixed perspective (slightly from side)
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
          float weight = 1.0/(v.z-ku.minz);
          if (0 < visX && visX < width && 0 < visY && visY < height) {
            weighted2d.x += visX*weight;
            weighted2d.y += visY*weight;
            mass2d += weight;
            // Draw a point
            color c = color(100-((v.z-ku.minz)/0.8*100)/2,100,100);
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
    if (mass2d > 0.0) {
      color c = color(80,100,100);
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

void keyPressed() {
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

void stop() {
  kinect.quit();
  super.stop();
}



