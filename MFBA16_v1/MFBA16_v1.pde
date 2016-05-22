
// BUILT FOR ROME - DOESN'T MATTER FOR THE SCREEN SIZE

// NOW ITS FULL SCREEN, WHATEVER SCREEN SIZE

// UNCOMMENT 3 SERIAL COMMENTS, READ, WRITE, AND WRITE
// BEFORE USING, AS WELL AS ADJUST ORIGINAL.PNG VALUES
// TO THE SCREEN SIZE

import processing.video.*;  // import serial -> arduino, video -> webcam
import processing.serial.*;

/*

  Xmodem control bytes

*/

final byte SOH = 0x01;
final byte EOT = 0x04;
final byte ACK = 0x06;
final byte NAK = 0x15;
final byte ETB = 0x17;
final byte HELLO = 0x18;
final byte _C  = 0x43;

/* printer image data objects */

byte[] ImageBuffer = new byte[33536];

float[][] kernel = {{ -1, -1, -1},   // used for edge detection algorithms
                    { -1,  9, -1}, 
                    { -1, -1, -1}};
PImage img;

Serial com_port;

int displayX = 1920;  // use for final display
int displayY = 1080;   // used for calculations!

Capture cam;

void setup() {
  
    fullScreen();
    //size(1920, 1440);  //1920 x 1080 HD camera resolution
    println(Serial.list());  //show the serial ports
    background(255);  // white background (borders)
    println(Capture.list());
    
    /*String[] cameras = Capture.list();  // find out all of available cameras (over 100)

    for (int i = 0; i < cameras.length; i++) {
      println(i);
      println(cameras[i]);
    }*/
    
    cam = new Capture(this, 1920, 1080, "Microsoft® LifeCam Studio(TM)", 30);    
    //cam = new Capture(this, cameras[1]);
    println("YEW");
    
    com_port = new Serial(this, "/dev/cu.usbmodem1421", 38400);
          
    cam.start();
}

void draw() {
  
  int answer,index;
  byte val;
  
  if (cam.available() == true) {  //if there is a camera, stream it
      cam.read();
      image(cam, 0, 0);  //start webcam + live video stream
    } else {
  }

  if(key == 'A') {  // once the button is pressed...
    print("getImage ");
    getImage();
    print("create file ");
    createFile();
    print("tranfer image ");
    transmit_image(); //x modem host
    
    for(byteIndex =0; byteIndex < 33515; byteIndex++) {
      data[byteIndex] = 0;
    }
    
    print("done \r\n");
  }
}

void getImage() {
  
    //OG
    save("original.png");  //save the screen - the original image with black borders
    PImage original = get(0,0,displayX,displayY);
    original.save("original.png");
    
    //SQUARE FOR LED PANEL
    PImage square = get((displayX - displayY)/2,0,displayY,displayY);  // 1080 x 1080 square image
    square.resize(32, 32);
    square.save("32x32.png");  // save the 32x32 image for the ARGB display
    
    //BITMAP FOR 64x32 PANEL
    PImage bitmap = loadImage("original.png");
    bitmap = get(0, 0, displayX, displayX / 2);
    bitmap.resize(64, 32);
    bitmap.save("image.bmp");
    
    //EDGE DETECTED
    img = loadImage("original.png");  // load the original image
    img.resize(684, 385);  // resize image that will fit when rotated onto the screen
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
    }
  }
      // State that there are changes to edgeImg.pixels[]
      edgeImg.updatePixels();
      
      int s = 1;
      
      for (int x = 0; x < edgeImg.width; x+=s) {
        for (int y = 0; y < edgeImg.height; y+=s) {
          color oldpixel = edgeImg.get(x, y);
          color newpixel = findClosestColor(oldpixel);
          float quant_error = brightness(oldpixel) - brightness(newpixel);
          edgeImg.set(x, y, newpixel);

          edgeImg.set(x+s, y, color(brightness(edgeImg.get(x+s, y)) + 7.0/16 * quant_error) );
          edgeImg.set(x-s, y+s, color(brightness(edgeImg.get(x-s, y+s)) + 3.0/16 * quant_error) );
          edgeImg.set(x, y+s, color(brightness(edgeImg.get(x, y+s)) + 5.0/16 * quant_error) );
          edgeImg.set(x+s, y+s, color(brightness(edgeImg.get(x+s, y+s)) + 1.0/16 * quant_error));

          stroke(newpixel);      
          point(x,y);
    }
  }
      edgeImg.updatePixels();
      
      translate(385, 0);  // translate the image 385px to the right, 0px down
      rotate(PI/2);  // rotate the image 90 degrees
      image(edgeImg, 0, 0);  // put image onto the canvas
      //image(edgeImg, 0, -385);  // put image onto the canvas

      //PImage finalpic = get(150, 0, 385, 684);  //get image
      PImage finalpic = get(0,0,385,684);
      finalpic.save("edgedetect.png");  // save the processed image
      
      PImage doubles = get(0, 0, 1000, 1000);
      doubles.save("doubles.png");
}

  // GLOBAL VARIABLES FOR CREATING AND SENDING FILE
  String      filename, basename, filenameBin;
  PImage      image;
  PrintWriter output;
  int         i, x, y, b, rowBytes, totalBytes, lastBit, sum, n, r=1;
  byte[] data;
  int byteIndex = 0;

void createFile() {

  // Select and load image
  filename = "photo";
  image = loadImage("edgedetect.png");

  // Morph filename into output filename and base name for data
  x = filename.lastIndexOf('.');
  if (x > 0) filename = filename.substring(0, x);  // Strip current extension
  x = filename.lastIndexOf('/');
  if (x > 0) basename = filename.substring(x + 1); // Strip path
  else      basename = filename;

  filenameBin = filename+".bin";
  println("Writing output to " + filenameBin);

  // Calculate output size
  rowBytes   = (image.width + 7) / 8;
  totalBytes = rowBytes * image.height;
  print("total bytes ");
  print(totalBytes);
  print("\r|n");
  
  //Create array for bytes
  data = new byte[34000];

  // Convert image to B&W, make pixels readable
  image.filter(THRESHOLD);
  image.loadPixels();

  // Generate body of array
  byteIndex = 0;
  for (i=n=y=0; y<image.height; y++) { // Each row...
    //    output.print("\n  ");
    for (x=0; x<rowBytes; x++) { // Each 8-pixel block within row...
      lastBit = (x < rowBytes - 1) ? 1 : (1 << (rowBytes * 8 - image.width));
      sum     = 0; // Clear accumulated 8 bits
      for (b=128; b>=lastBit; b >>= 1) { // Each pixel within block...
        if ((image.pixels[i++] & 1) == 0) sum |= b; // If black pixel, set bit
      }      
 
 
      
      //Write to byte array
      data[byteIndex] = byte(sum);
        if (byteIndex > 0) {
          data[byteIndex] = byte(data[byteIndex-1] << 8 | data[byteIndex]);
               // println("byteIndex "+( byteIndex-1)+": "+data[byteIndex-1]);
        }
      byteIndex++;
    }
  }

  // save byte array as binary file
  saveBytes(filenameBin, data);
}
  
  // unused b/c of the x modem stuff
/*void sendPicture() {

  myPort.clear();

  println(data.length);
  myPort.write(36);      //$
  
  for(int i = 0; i < 33516; i++)
  {
    println(i);
    myPort.write(data[i]);  //write over Serial to the printer

    if(i%5000 == 0)
    {
        println("5000 bytes tx");
    }
  }

  myPort.clear();
  //delay(43000);   //Q$RWOIGAEFNVCXZ
}*/

color findClosestColor(color c) {
  color r;

  if (brightness(c) < 128) {
    r = color(0);
  }
  else {
    r = color(255);
  }
  return r;
}

final int IMAGE_SIZE = 33515;

final byte XM_WAIT = 1;
final byte XM_RUN = 2;
final byte XM_END = 3;

byte xm_buffer[] = new byte[133];

void transmit_image()
{
  if(com_port.available() > 0) {
    
  } else {
    com_port = new Serial(this, "/dev/cu.usbmodem142341", 38400);
  }
  
  int rxd = 0;
  int buffer_index = 0;
  byte transfer_done = 0;
  byte xm_state = XM_WAIT;
  int packet_count = 0;
  int byte_count;
  
  // byte temp_image[] = loadBytes("image.bin");
  
  // zero out tx array and copy across
  
  while(transfer_done == 0)
  {
    
      switch(xm_state)
       {
         
         case  XM_WAIT :
           if(com_port.available() > 0)
             {
               rxd = byte(com_port.read() & 0x00FF);
               if(rxd == 'C')
                 {
                   
                   print("C rec\r\n");
                   
                   xm_state = XM_RUN;
                 }
             }
            break;
            
            
          case XM_RUN:
              if(buffer_index < (IMAGE_SIZE)) // used to be IMAGE_SIZE -128
                {
                  format_xmframe(data,buffer_index);
                  for(byte_count = 0; byte_count < 133;byte_count++)
                    {
                     com_port.write(xm_buffer[byte_count]);
                     delay(1);
                      //delay(1/8);
                    }
                    
                    //delay(60);
                 
                   while(com_port.available() > 0)
                   {
                     rxd = com_port.read();
                   }
                   
                   
                   if(rxd == ACK)
                     {
                       packet_count++; 
                       buffer_index = buffer_index +  128; 
                       print("A ");
                       print("> ");
                       print(packet_count);
                       print(" ");
                       print(buffer_index);
                       print("\r\n");
                       //delay(20);
                      
                     }
                   else if(rxd == NAK)
                  {
                     print("frame NACK\r\n"); 
                     delay(200);
                  
                  }
                  else {
                    println("got weird stuff");
                    com_port.clear();
                  }
                } 
               else  // end of image
                {
                   
                  xm_state = XM_END;
                }
               break;
               
            case XM_END:
              com_port.write(EOT);
             
               while(com_port.available() > 0)
                   {
                     rxd = com_port.read();
                   }
             
                   if(rxd == ACK)
                    {
                      print("EOT ACK\r\n"); 
                      com_port.clear();
                      transfer_done = 1;
                       frame_count = 1;      // reset frame counter in format xframe
                    }
                    else 
                    {
                      print("EOT NACK\r\n");
                    }
             break;
             
       } // end switch
       
    // user exit
    if(keyPressed)
      {
        if (key == 'q' || key == 'Q')
        { 
           print("user exit\r\n");
          transfer_done = 1;
        }
      }
  } // end transfer done
        
} // end transmit image


// globals to format_xmframe

byte frame_count = 1;


void format_xmframe(byte buffer[], int offset)
{
  
  int buf_index;
  int packet_crc;
  byte data_payload[] = new byte[128];
  
  
  xm_buffer[0] =  SOH;
  xm_buffer[1] = frame_count;
  xm_buffer[2] = (frame_count);
  frame_count += 1;
  
  for(buf_index = 0;buf_index < 128;buf_index++)
    {
      
      data_payload[buf_index] = buffer[buf_index + offset];
      xm_buffer[3 + buf_index] = buffer[buf_index + offset];
    }
  
  
   packet_crc = calcrc(data_payload,128);
   xm_buffer[131] = byte((packet_crc  >> 8) & 0x00FF);
   xm_buffer[132] = byte(packet_crc & 0x00FF);
     
}


int calcrc( byte packet[], int count)
{
    int crc;
    byte p,i,index;

    crc = 0;
    index = 0;
    
    while (--count >= 0)
    {
        crc = (crc ^ (packet[index++] << 8)) & 0xFFFF;
        i = 8;
        while(i > 0)
        {
            if ((crc & 0x8000) == 0x8000)
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
            else
                crc = (crc << 1) & 0xFFFF;
            i--;
        } 
    }
    return (crc);
}