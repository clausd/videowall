import org.openkinect.*;
import org.openkinect.processing.*;

class Kinectutils {
  float[] depthLookUpTable = new float[2048];
  boolean ran_once = false;

  final double fx_d = 1.0 / 5.9421434211923247e+02;
  final double fy_d = 1.0 / 5.9104053696870778e+02;
  final double cx_d = 3.3930780975300314e+02;
  final double cy_d = 2.4273913761751615e+02;
  // Size of kinect image
  final int w = 640;
  final int h = 480;

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

  void setup() {
    if (!ran_once) {
      // Speedup: Lookup table for all possible depth values (0 - 2  047)
      for (int i = 0; i < depthLookUpTable.length; i++) {
        depthLookUpTable[i] = rawDepthToMeters(i);
      }
      ran_once = true;
    }
  }

  void update() {
    update(false);
  }

  void update(boolean update_stats) {
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
    for(int x=0; x<w; x+=skip) {
      for(int y=0; y<h; y+=skip) {
        int offset = x+y*w;
        // Convert kinect data to world xyz coordinate
        int rawDepth = _depth[offset];
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
  }


  void reConfigure(char parameter, boolean translate_on, float dv) {
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
  
  void center() {
    _transform.translate(-center.x,-center.y);
  }

  void reset() {
    front = 0;
    back = 0;
    enable_stats = true;
    _transform = new PMatrix3D();
  }
  
  void toggleStats() {
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

  float realDepth(int depthValue) {
    return depthLookUpTable[depthValue];
  }
  // These functions come from: http://graphics.stanford.edu/~mdfisher/Kinect.html
  float rawDepthToMeters(int depthValue) {
    if (depthValue < 2047) {
      return (float)(1.0 / ((double)(depthValue) * -0.0030711016 + 3.3309495161));
    }
    return 0.0f;
  }

  PVector depthToWorld(int x, int y, int depthValue) {
    PVector result = new PVector();
    double depth =  depthLookUpTable[depthValue];//rawDepthToMeters(depthValue);
    result.x = (float)((x - cx_d) * depth * fx_d);
    result.y = (float)((y - cy_d) * depth * fy_d);
    result.z = (float)(depth);
    return result;
  }

  void saveSettings() {
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

  void loadSettings() {
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

