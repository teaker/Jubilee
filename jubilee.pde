#include "LPD8806.h"
#include "SPI.h"
#include <avr/sleep.h>
#include "carrot.h"

//since data is on 11 and clock is on 13, we can use hardware SPI
LPD8806 strip = LPD8806(96);


int powerPin = 4;
int upModePin = 3;
int upColorPin = 2;

int upModeButtonState = HIGH;
int upModeButtonCycles = 0;
int upColorButtonState = HIGH;
int upColorButtonCycles = 0;

int CYCLES_DEBOUNCE = 2; //check the button for X ticks to see if it is bouncing
int MAX_COLORS = 8;
int MAX_MODES = 9;
int MAX_STRIPES = 5;

unsigned long tick = 0;

int mode = 1;
int color = 1;

uint16_t i, j, x, y ;
uint32_t c, d;

// Set the first variable to the NUMBER of pixels. 32 = 32 pixels in a row
// The LED strips are 32 LEDs per meter but you can extend/cut the strip

void ISR_Wake() {
  detachInterrupt(0);
  detachInterrupt(1);
}

void blackout() {
  for(int i=0; i < strip.numPixels()+1; i++) {
      strip.setPixelColor(i, strip.Color(0,0,0));
  }
  strip.show();
}


void triggerSleep() {
  blackout();

  attachInterrupt(0,ISR_Wake,LOW); //pin 2
  attachInterrupt(1,ISR_Wake,LOW); //pin 3
  
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
  sleep_enable();
  sleep_mode();
  //sleeping, until rudely interrupted
  sleep_disable();
}

void triggerModeUp() {
  ++mode;
  blackout();
}

void triggerColorUp() {
  color++;
  blackout();
}


void handleButtons() {
  if(digitalRead(powerPin) == LOW) {
    triggerSleep();
  }
  // software debounce
  if(digitalRead(upModePin) != upModeButtonState) {
    upModeButtonCycles++;
    if(upModeButtonCycles > CYCLES_DEBOUNCE) {
      upModeButtonCycles = 0;
      upModeButtonState = digitalRead(upModePin);
      if(upModeButtonState == LOW) {
        triggerModeUp();
      }
    }
  }
  // software debounce
  if(digitalRead(upColorPin) != upColorButtonState) {
    upColorButtonCycles++;
    if(upColorButtonCycles > CYCLES_DEBOUNCE) {
      upColorButtonCycles = 0;
      upColorButtonState = digitalRead(upColorPin);
      if(upColorButtonState == LOW) {
        triggerColorUp();
      }
    }
  }
}

void handleStrip() {
  switch(mode%MAX_MODES) {
    case 0: //solid
      c = GetColor(color%MAX_COLORS);
      for(i=0; i<strip.numPixels(); i++) {
        strip.setPixelColor(i, c);
      }
      break;
    case 1:
      c = GetColor((tick%3+color)% MAX_COLORS);
      for(i=0; i<strip.numPixels(); i++) {
        strip.setPixelColor(i, c);
      }
      break;
    case 2:
      if(tick % 50 == 0) {
        c = GetColor(color%MAX_COLORS);
        for(i=0; i<strip.numPixels(); i++) {
          strip.setPixelColor(i, c);
        }
      }
      if(tick % 50 == 25) {
        c = strip.Color(0,0,0);
        for(i=0; i<strip.numPixels(); i++) {
          strip.setPixelColor(i, c);
        }
      }
      break;
      case 3:  //strobe 2 color
      if(tick % 30 == 0) {
        c = GetColor(color%MAX_COLORS);
        for(i=0; i<strip.numPixels(); i++) {
          strip.setPixelColor(i, c);
        }
      }
      if(tick % 30 == 15) {
        c = GetColor(color%MAX_COLORS+2);
        for(i=0; i<strip.numPixels(); i++) {
          strip.setPixelColor(i, c);
        }
      }
      break; 
    case 4: //chasers
      d = (color / MAX_COLORS) % MAX_STRIPES + 1; //chaser
      c = GetColor(color % MAX_COLORS);       //color
      j = tick % (strip.numPixels()/d);
      for(i=0; i < strip.numPixels(); i++) {
        if(i % (strip.numPixels()/d) == j) {
          strip.setPixelColor(i, c);
        }
        else {
          strip.setPixelColor(i, strip.Color(0,0,0));
        }
      }
      break;
    case 5: //chasers + statics
      d = (color / MAX_COLORS) % MAX_STRIPES + 1; //chaser
      c = GetColor(color % MAX_COLORS);       //color
      j = tick % (strip.numPixels()/d);
      for(i=0; i < strip.numPixels(); i++) {
        x = i % (strip.numPixels()/d);
        if((x == j) || (x == 0)) {
          strip.setPixelColor(i, c);
        }
        else {
          strip.setPixelColor(i, strip.Color(0,0,0));
        }
      }
      break;
    case 6: //fuckin' rainbows
      j = tick % 384;
      for(i=0; i < strip.numPixels(); i++) {
        strip.setPixelColor(i, Wheel(((i * 384 / strip.numPixels() * (color%MAX_COLORS)) + j) % 384));
      }
      break;
    case 7:  //rainbow chaser (3 pixel chaser)
      d = (color / MAX_COLORS) % MAX_STRIPES + 1; //chaser
      c = tick % 384;       
      j = tick % (strip.numPixels()/d);
      for(i=0; i < strip.numPixels(); i++) {
        if(i % (strip.numPixels()/d) == c) {
          strip.setPixelColor(i, Wheel(((i * 384 / strip.numPixels() * (color%MAX_COLORS)) + c) % 384));        //first pixel
          strip.setPixelColor(i + 1, Wheel(((i * 384 / strip.numPixels() * (color%MAX_COLORS)) + c) % 384));    //second pixel
          strip.setPixelColor(i + 2, Wheel(((i * 384 / strip.numPixels() * (color%MAX_COLORS)) + c) % 384));    //third pixel
        }
        else {
          strip.setPixelColor(i, strip.Color(0,0,0));
        }
      }
      break;
    case 8: //carrot POV
      j = tick % 158;
      d = carrot[j];
                               //green                     //orange
      c = (j < 30)?GetColor((color+2)%MAX_COLORS):GetColor((color+3)%MAX_COLORS);
      for(i=0;i<32;i++) {
        //adding 32 to the index makes it appear on the side opposite the controller
        if(d & 0x00000001) {
          strip.setPixelColor(i+32, c);
        }
        else {
          strip.setPixelColor(i+32, strip.Color(0,0,0));
        }
        d >>= 1;
      }
      break;
  }
  
  strip.setPixelColor(strip.numPixels()-1, strip.Color(0,0,0)); //set that last LED off because it overlaps
  strip.show();
}



void setup() {
  // Start up the LED strip
  strip.begin();

  pinMode(powerPin, INPUT);    // declare pushbutton as input
  pinMode(upModePin, INPUT);    // declare pushbutton as input
  pinMode(upColorPin, INPUT);    // declare pushbutton as input
  
  triggerSleep();
}


void loop() {
  tick++;
  handleStrip();
  handleButtons();
}

// fill the dots one after the other with said color
// good for testing purposes
void colorWipe(uint32_t c, uint8_t wait) {
  int i;

  for (i=0; i < strip.numPixels(); i++) {
      strip.setPixelColor(i, c);
      strip.show();
      delay(wait);
  }
}

// Chase a dot down the strip
// good for testing purposes
void colorChase(uint32_t c, uint8_t wait) {
  int i;

  for (i=0; i < strip.numPixels(); i++) {
    strip.setPixelColor(i, 0);  // turn all pixels off
  }

  for (i=0; i < strip.numPixels(); i++) {
      strip.setPixelColor(i, c); // set one pixel
      strip.show();              // refresh strip display
      delay(wait);               // hold image for a moment
      strip.setPixelColor(i, 0); // erase pixel (but don't refresh yet)
  }
  strip.show(); // for last erased pixel
}

// An "ordered dither" fills every pixel in a sequence that looks
// sparkly and almost random, but actually follows a specific order.
void dither(uint32_t c, uint8_t wait) {

  // Determine highest bit needed to represent pixel index
  int hiBit = 0;
  int n = strip.numPixels() - 1;
  for(int bit=1; bit < 0x8000; bit <<= 1) {
    if(n & bit) hiBit = bit;
  }

  int bit, reverse;
  for(int i=0; i<(hiBit << 1); i++) {
    // Reverse the bits in i to create ordered dither:
    reverse = 0;
    for(bit=1; bit <= hiBit; bit <<= 1) {
      reverse <<= 1;
      if(i & bit) reverse |= 1;
    }
    strip.setPixelColor(reverse, c);
    strip.show();
    delay(wait);
  }
  delay(250); // Hold image for 1/4 sec
}

// "Larson scanner" = Cylon/KITT bouncing light effect
void scanner(uint8_t r, uint8_t g, uint8_t b, uint8_t wait) {
  int i, j, pos, dir;

  pos = 0;
  dir = 1;

  for(i=0; i<((strip.numPixels()-1) * 8); i++) {
    // Draw 5 pixels centered on pos.  setPixelColor() will clip
    // any pixels off the ends of the strip, no worries there.
    // we'll make the colors dimmer at the edges for a nice pulse
    // look
    strip.setPixelColor(pos - 2, strip.Color(r/4, g/4, b/4));
    strip.setPixelColor(pos - 1, strip.Color(r/2, g/2, b/2));
    strip.setPixelColor(pos, strip.Color(r, g, b));
    strip.setPixelColor(pos + 1, strip.Color(r/2, g/2, b/2));
    strip.setPixelColor(pos + 2, strip.Color(r/4, g/4, b/4));

    strip.show();
    delay(wait);
    // If we wanted to be sneaky we could erase just the tail end
    // pixel, but it's much easier just to erase the whole thing
    // and draw a new one next time.
    for(j=-2; j<= 2; j++) 
        strip.setPixelColor(pos+j, strip.Color(0,0,0));
    // Bounce off ends of strip
    pos += dir;
    if(pos < 0) {
      pos = 1;
      dir = -dir;
    } else if(pos >= strip.numPixels()) {
      pos = strip.numPixels() - 2;
      dir = -dir;
    }
  }
}

// Sine wave effect
#define PI 3.14159265
void wave(uint32_t c, int cycles, uint8_t wait) {
  float y;
  byte  r, g, b, r2, g2, b2;

  // Need to decompose color into its r, g, b elements
  g = (c >> 16) & 0x7f;
  r = (c >>  8) & 0x7f;
  b =  c        & 0x7f; 

  for(int x=0; x<(strip.numPixels()*5); x++)
  {
    for(int i=0; i<strip.numPixels(); i++) {
      y = sin(PI * (float)cycles * (float)(x + i) / (float)strip.numPixels());
      if(y >= 0.0) {
        // Peaks of sine wave are white
        y  = 1.0 - y; // Translate Y to 0.0 (top) to 1.0 (center)
        r2 = 127 - (byte)((float)(127 - r) * y);
        g2 = 127 - (byte)((float)(127 - g) * y);
        b2 = 127 - (byte)((float)(127 - b) * y);
      } else {
        // Troughs of sine wave are black
        y += 1.0; // Translate Y to 0.0 (bottom) to 1.0 (center)
        r2 = (byte)((float)r * y);
        g2 = (byte)((float)g * y);
        b2 = (byte)((float)b * y);
      }
      strip.setPixelColor(i, r2, g2, b2);
    }
    strip.show();
    delay(wait);
  }
}

/* Helper functions */

//Input a value 0 to 384 to get a color value.
//The colours are a transition r - g - b - back to r

uint32_t Wheel(uint16_t WheelPos)
{
  byte r, g, b;
  switch(WheelPos / 128)
  {
    case 0:
      r = 127 - WheelPos % 128; // red down
      g = WheelPos % 128;       // green up
      b = 0;                    // blue off
      break;
    case 1:
      g = 127 - WheelPos % 128; // green down
      b = WheelPos % 128;       // blue up
      r = 0;                    // red off
      break;
    case 2:
      b = 127 - WheelPos % 128; // blue down
      r = WheelPos % 128;       // red up
      g = 0;                    // green off
      break;
  }
  return(strip.Color(r,g,b));
}


uint32_t GetColor(int c)
{
  switch(c) {
    case 0:
      return strip.Color(127,0,0);
    case 1:
      return strip.Color(0,0,127);
    case 2:
      return strip.Color(0,127,0);
    case 3:
      return strip.Color(127,31,0);
    case 4:
      return strip.Color(127,127,0);
    case 5:
      return strip.Color(0,127,127);
    case 6:
      return strip.Color(127,0,127);
    case 7:
      return strip.Color(127,127,127);
    default:
      return strip.Color(0,0,0);
  }
}
