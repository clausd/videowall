class Settings {
   
   String _filename;
   String lines[];
   int i_line = 0;
   String buffer = "";
   String sep = "";
   
   Settings(String f) {
     _filename = f;
   }
   
   int loadSettings() {
     lines = loadStrings(_filename);
     i_line = 0;
     return lines.length;
   }
   
   int saveSettings() {
     lines = buffer.split(" ");
     saveStrings(_filename,lines);
     return lines.length;
   }
   
   float readFloat() {
     return Float.parseFloat(lines[i_line++]);
   }
   
   void readFloats(float[] farray) {
     for (int i = 0;i<farray.length; i++) {
       farray[i] = readFloat();
     }
   }
   
   int readInt() {
     return Integer.parseInt(lines[i_line++]);
   }
   
   String readString() {
      return lines[i_line++];     
   }
   
   void addString(String s) {
     buffer = buffer + sep + s;
     sep = " ";
   }
   
   void addInt(int i) {
     addString("" + i);
   }
   
   void addFloat(float f) {
     addString("" + f);
   }
   
   void addFloats(float[] a) {
      for (int i = 0; i<a.length; i++) {
       addFloat(a[i]);
      } 
   }
}
