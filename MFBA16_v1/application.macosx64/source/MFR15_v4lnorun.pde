// BUILT FOR ROME - DOESN'T MATTER FOR THE SCREEN SIZE

// NOW ITS FULL SCREEN, WHATEVER SCREEN SIZE

// UNCOMMENT 3 SERIAL COMMENTS, READ, WRITE, AND WRITE
// BEFORE USING, AS WELL AS ADJUST ORIGINAL.PNG VALUES
// TO THE SCREEN SIZE

import processing.video.*;  // import serial -> arduino, video -> webcam
import processing.serial.*;
//SobelEdgeDetection sobel;

float[][] kernel = {{ -1, -1, -1},   // used for edge detection algorithms
                    { -1,  9, -1}, 
                    { -1, -1, -1}};
PImage img;

Serial myPort;

int displayX = 1280;  // used for calculations??????
int displayY = 720;

//int displayX = height;
//int displayY = width;

Capture cam;

void setup() {
    fullScreen();
    //size(1920, 1440);  //1920 x 1080 HD camera resolution
    println(Serial.list());  //show the serial ports
    println("done serial communication");
    background(100);  // black background (black borders)
    println("after background");
    String[] cameras = Capture.list();  // find out all of available cameras (over 100)
    //println("found cameras");
    for (int i = 0; i < cameras.length; i++) {
      println(i);
      println(cameras[i]);
      
    }
    cam = new Capture(this, 1280, 720, "Microsoft® LifeCam Studio(TM)", 30);    
    println("init camera");
    cam.start();
    println("out of setup");
    //while(myPort.available() == 0);  // don't start until Arduino is connected
    println("done");
          myPort = new Serial(this, "/dev/cu.usbmodem1411", 115200);
  println("port opened");
}

void draw() {
  if (cam.available() == true) {  //if there is a camera, stream it
    cam.read();
    image(cam, 0, 0);  //start webcam + live video stream
    println("available");
  } else {
    println("not available");}

  if(key == 'A') {  // keypress for the big button
  println("fdnskqpbnri3opads");
    save("originaL.png");  //save the screen - the original image with black borders
    PImage original = get(0,0,1440,810);
    //PImage original = get(0,0,displayX,displayY);
    original.save("original.png");
    PImage squarePartial = get((displayX - displayY)/2,0,displayY,displayY);  // 1080 x 1080 square image
    squarePartial.resize(32, 32);
    squarePartial.save("32x32.png");  // save the 32x32 image for the ARGB display
    PImage bobimage = loadImage("original.png");
    bobimage = get(0, 0, displayX, displayX / 2);
    bobimage.resize(64, 32);
    bobimage.save("image.bmp");
    img = loadImage("original.png");  // load the original image
    img.resize(684, 385);  // resize image that will fit when rotated onto the screen
  ///////////////////////EDGE DETECTION ALGORITHIM///////////////////////  
  img.loadPixels();
  // Create an opaque image of the same size as the original
  PImage edgeImg = createImage(img.width, img.height, RGB);
  // Loop through every pixel in the image.
  for (int y = 1; y < img.height-1; y++) { // Skip top and bottom edges
    for (int x = 1; x < img.width-1; x++) { // Skip left and right edges
      float sum = 0; // Kernel sum for this pixel
      for (int ky = -1; ky <= 1; ky++) {
        for (int kx = -1; kx <= 1; kx++) {
          // Calculate the adjacent pixel for this kernel point
          int pos = (y + ky)*img.width + (x + kx);
          // Image is grayscale, red/green/blue are identical
          float val = red(img.pixels[pos]);
          // Multiply adjacent pixels based on the kernel values
          sum += kernel[ky+1][kx+1] * val;
        }
      }
      // For this pixel in the new image, set the gray value
      // based on the sum from the kernel
      edgeImg.pixels[y*img.width + x] = color(sum, sum, sum);
////////////////////////EDGE DETECTION END//////////////////////////////
    }
  }
  // State that there are changes to edgeImg.pixels[]
  edgeImg.updatePixels();
  translate(385, 0);  // translate the image 385px to the right, 0px down
  rotate(PI/2);  // rotate the image 90 degrees
  image(edgeImg, 0, 0);  // put image onto the canvas
  PImage newimage = get(0, 0, 385, 684);  //get image
  save("doubles.png");
  newimage.save("edgedetect.png");  // save the processed image
  processPrinterImage();  // run through algorithm to turn into binary
  //background(0);  // set the background back to black
  //return;
  }
}
  
void processPrinterImage() {
  String      filename, basename, filenameBin;
  PImage      fdsa;
  PrintWriter output;
  int         i, x, y, b, rowBytes, totalBytes, lastBit, sum, n, r=1;
  byte[] data;
  int byteIndex = 0;

  // Select and load image
  println("Loading image...");
  filename = "photo";
  fdsa     = loadImage("edgedetect.png");

  // Morph filename into output filename and base name for data
  x = filename.lastIndexOf('.');
  if (x > 0) filename = filename.substring(0, x);  // Strip current extension
  x = filename.lastIndexOf('/');
  if (x > 0) basename = filename.substring(x + 1); // Strip path
  else      basename = filename;

  filenameBin = filename+".bin";
  println("Writing output to " + filenameBin);

  // Calculate output size
  rowBytes   = (fdsa.width + 7) / 8;
  totalBytes = rowBytes * fdsa.height;

  //Create array for bytes
  data = new byte[totalBytes];

  // Convert image to B&W, make pixels readable
  fdsa.filter(THRESHOLD);
  fdsa.loadPixels();

  // Generate body of array
  for (i=n=y=0; y<fdsa.height; y++) { // Each row...
    //    output.print("\n  ");
    for (x=0; x<rowBytes; x++) { // Each 8-pixel block within row...
      lastBit = (x < rowBytes - 1) ? 1 : (1 << (rowBytes * 8 - fdsa.width));
      sum     = 0; // Clear accumulated 8 bits
      for (b=128; b>=lastBit; b >>= 1) { // Each pixel within block...
        if ((fdsa.pixels[i++] & 1) == 0) sum |= b; // If black pixel, set bit
      }      

      //Write to byte array
      data[byteIndex] = byte(sum);
        if (byteIndex > 0) {
          data[byteIndex] = byte(data[byteIndex-1] << 8 | data[byteIndex]);
//                println("byteIndex "+( byteIndex-1)+": "+data[byteIndex-1]);
        }
      byteIndex++;
    }
  }

  // save byte array as binary file
  saveBytes(filenameBin, data);
  //if(data.length << 1000) {
    //delay(2000);
    
  byte yeah[] = loadBytes("photo.bin");
  
  println(yeah.length);
  myPort.write(36);  ///
  println("yew!");
  for( i = 0; i < yeah.length; i++) {
  myPort.write(yeah[i]);  //write over Serial to the printer
  delay(40/1000);
  }
  println("printed");
  //myPort.clear();
  //myPort.stop();
  println("stopped");
  delay(30000);
  //background(0);  // set the background back to black
  //return;

}