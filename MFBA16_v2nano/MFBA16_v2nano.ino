/*

	
	Thermal Printer client
	based on Qduino Platform
	
	file 	: MFR_qdmv10.ino
	author 	: Quin Etnyre 
	date 	: 2016.05.19
	
	
	MIT license stuff 

  This is an Arduino library for the Adafruit Thermal Printer.
  Pick one up at --> http://www.adafruit.com/products/597
  These printers use TTL serial to communicate, 2 pins are required.

  Adafruit invests time and resources providing this open source code.
  Please support Adafruit and open-source hardware by purchasing products
  from Adafruit!

  Written by Limor Fried/Ladyada for Adafruit Industries.
  MIT license, all text above must be included in any redistribution.
 *************************************************************************/


 
#include "Qduino.h"
#include "SoftwareSerial.h"
#include "Adafruit_Thermal.h"
#include "SD.h"
#include "SPI.h"
#include "Wire.h"


qduino q;

File myFile;


// binary image statistics

#define photo_width  385
#define photo_height 684

#define TX_PIN 5 // Arduino transmit  YELLOW WIRE  labeled RX on printer
#define RX_PIN 6 // Arduino receive   GREEN WIRE   labeled TX on printer

#define SOH    0x01
#define EOT   0x04
#define ACK   0x06
#define NACK  0x15

#define TRUE 1
#define FALSE 0

enum {FRAME_NULL,FRAME_OK,FRAME_BAD,FRAME_END} _xframes;

unsigned int rx_size = 0, IMAGE_SIZE = 33536;


unsigned char xm_frame[133];
int calcrc(unsigned char *ptr, int count);

// create primary objects

SoftwareSerial mySerial(RX_PIN, TX_PIN); 	// Declare SoftwareSerial obj first
Adafruit_Thermal printer(&mySerial, 4);     // Pass addr to printer constructor

int frameNums = 0;

// Then see setup() function regarding serial & printer begin() calls.

void setup() 
{
  
  //SD.remove("photo.bin");

  q.setup();

  mySerial.begin(9600);
  Serial.begin(38400);

  printer.begin();
  printer.wake();  //wake me up


  // blink Blue and Red if no SD card inserted
  
  if (!SD.begin(12)) 
  {
		while(1)
			{
			
				q.setRGB(qduino::BLUE);
				delay(500);
				q.setRGB(qduino::RED);
				delay(500);
			}
			
   } 
  
}

void loop() 

{

	while(1)
	{
	
		get_image();		// receive image via XModem protocol
		print_image();		// send image to thermal printer
		//printer_sleep();

	}	
 
    
 } // end loop

  
  
void print_image(void)
    
  {
    myFile = SD.open("photo.bin", FILE_READ);
	
	if(myFile == NULL)
		{
			while(1)
			{
			
				q.setRGB(qduino::GREEN);
				delay(500);
				q.setRGB(qduino::RED);
				delay(500);
			}
			
					
		}
	else
		{
    
      q.ledOff();
			printer.printBitmap(photo_width, photo_height, &myFile);

			myFile.close();
			q.setRGB(qduino::BLUE);
			SD.remove("photo.bin");
			printer.feed(3);
		}

 } // end print image
  

void printer_sleep(void)
{
  q.setRGB(qduino::RED);
  printer.sleep();      // Tell printer to sleep
  /*q.setRGB(qduino::ORANGE);
  delay(3000);
  q.setRGB(qduino::CYAN);
  //printer.wake();       // MUST call wake() before printing again, even if reset
  q.setRGB(qduino::GREEN);
  //printer.setDefault(); // Restore printer to defaults*/
  q.ledOff();
 } 
  
  
void get_image(void)
{

	unsigned char done = FALSE;
	int frame_count = 0;
	unsigned char frame_status;
	unsigned char frame_index;
	// open sd file for writing
	
	myFile = SD.open("photo.bin", FILE_WRITE);

  //delay(1000);
	
	while(done == FALSE)
	{
	
		frame_status = read_xframe(&xm_frame[0]);
		if(frame_status == FRAME_OK)
			{
			  q.setRGB(qduino::GREEN);
        
				// write 128 bytes to image file
				
				for(frame_index = 0; frame_index < 128;frame_index++)
					{
						myFile.write(xm_frame[frame_index + 3]);
            delayMicroseconds(20);
					
					}
					            delay(50);
				// send the ACK
				Serial.write(ACK);
				
			}

		else if(frame_status == FRAME_BAD)
			{

				 q.setRGB(qduino::RED);
				// send a NACK
				Serial.write(NACK);

			}
	
		else if(frame_status == FRAME_END)
				{
					
					// image transfer done
					q.setRGB(qduino::BLUE);
					Serial.write(ACK);
				
					// close file on SD card
					myFile.close();
					done = TRUE;

				}
	
	}

}


unsigned char read_xframe(unsigned char *frame_ptr)
{
	int xframe_status,frame_crc1,frame_crc2;
	unsigned char done, index;
	char rxd;
	static unsigned char transfer_start = TRUE;
	unsigned long frame_timer_now,frame_timer_last;
	
	done = FALSE;
	index = 0;
	xframe_status = FRAME_NULL;

	
	frame_timer_now = millis();
	frame_timer_last = frame_timer_now;
	
	while(!done)
		{
			
			// if start of transfer cycle send 'C' every 3 seconds
			if(transfer_start)
			{	
				
				frame_timer_now = millis();
				if((frame_timer_now - frame_timer_last) > 2999)
					{
						Serial.print('C');
						frame_timer_last = frame_timer_now;
					}
			}
			
			if(Serial.available())
				{
					
					rxd = Serial.read();
					
					transfer_start = FALSE;
					
					if((index == 0) && (rxd == EOT))
						{
              q.setRGB(qduino::PURPLE);
							transfer_start = TRUE;
							xframe_status = FRAME_END;
							done = TRUE;
							continue;
						}

					else 
						{
							*(frame_ptr + index) = rxd;
							index++;
						}
				
				}

			if(index > 132)	// received one xmodem frame
				{
					frame_crc1 = calcrc((&frame_ptr[3]),128);
					frame_crc2 = (int)(frame_ptr[131]) * 256 + (int)(frame_ptr[132]);
					
					if(frame_crc1 == frame_crc2)
						xframe_status = FRAME_OK;
					else 
						xframe_status = FRAME_BAD;
					
					done = TRUE;
					continue;

				}


		}

	return(xframe_status);

} // end read_xframe
	
int calcrc(unsigned char *ptr, int count)
{
    int crc;
    unsigned char *p,i;

    crc = 0;
	p = ptr;

    while (--count >= 0)
    {
        crc = crc ^ (int) *ptr++ << 8;
        i = 8;
        do
        {
            if (crc & 0x8000)
                crc = crc << 1 ^ 0x1021;
            else
                crc = crc << 1;
        } while(--i);
    }
    return (crc);
}



