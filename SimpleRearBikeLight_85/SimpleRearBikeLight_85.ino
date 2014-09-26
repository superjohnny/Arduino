
/* 
Rear LED bike light driver for bicycle.
Runs on ATTiny85
Cycles through states on button press.
If time between presses is greater than 5 seconds, next presses turns off
last state is preserved when between press time is expired
*/

#include <avr/sleep.h>

#define wakePin 2
#define LED1 1
#define LED2 4
#define holdTime 15000
#define debounceDelay 150
#define maxStates 6
#define maxFlashIndex 2000
#define highFlashIndex 1900
#define flashOffset 100

byte state = 1;
byte lastState = 1;
byte pressed = 0;
byte waking = 0;
long lastDebounceTime = 0;
long lastTimeButtonPress = 0;
int flashIndexLeft = 0;
int flashIndexRight = 0;

void setup() {
  // put your setup code here, to run once:
  pinMode(wakePin, INPUT_PULLUP);
  digitalWrite(wakePin, HIGH);
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
}

void loop() {
  // put your main code here, to run repeatedly:

  readButton();
  
  switch(state)
  {
    case 0: //turn off
      //set pwm to off
      //enable button as interupt
      //sleep 
      sleepNow();
      break;
    case 1: //low light
      analogWrite(LED1, 20);
      analogWrite(LED2, 20);
      break;
    case 2: //medium light
      analogWrite(LED1, 80);
      analogWrite(LED2, 80);
      break;      
    case 3: //flash sync
      flashIndexLeft = flashChannel(flashIndexLeft, LED1);
      flashIndexRight = flashChannel(flashIndexRight, LED2);
      break;      
    case 4: //flash async
      flashIndexLeft = flashChannel(flashIndexLeft, LED1);
      flashIndexRight = flashChannel(flashIndexRight, LED2);
      break;      
    case 5: //glow
      flashIndexLeft = glowChannel(flashIndexLeft, LED1);
      flashIndexRight = glowChannel(flashIndexRight, LED2);
      break;
    case 6: //bright light
      //set pwm to full 
      analogWrite(LED1, 255);
      analogWrite(LED2, 255);
      break;
  }
}

int flashChannel(int index, byte channel)
{
  //flash a channel, and cycle the index
  if (++index > highFlashIndex)
  {
    analogWrite(channel, 255);
  } else {
    analogWrite(channel, 20);
  }
  
  if (index > maxFlashIndex)
    return 0;
    
  return index;  
}

int glowChannel(int index, byte channel)
{
  
  if (++index > 2000)
    index = 0;
  
  float phase = (index / 30.0);
  float value = (sin(phase) * 110) + 145;
  
  analogWrite(channel, value);
  return index;
}

void readButton()
{
  if ((PINB&(1<<wakePin))==0)
  {
    lastDebounceTime = millis();     
    pressed = true;
  }
  if (pressed && (millis() - lastDebounceTime) > debounceDelay) 
  {

    pressed = false;
    
      
    if (!waking) {
      lastState = 0; //default lastState to off
      if (++state > maxStates) {
        state = 0;
      }
    }
    
    //if time between presses are greater than holdTime then go straight to off
    if ((millis() - lastTimeButtonPress) > holdTime) {
      lastState = state;
      state = 0;
    }
    
    
    //for flash states set sync or async offsets
    if (state == 3 | state == 5) {
      flashIndexLeft = 0;
      flashIndexRight = 0;
    } else if (state == 4) {
      flashIndexLeft = 0;
      flashIndexRight = 100;
    }
    
    
    waking = false;
    lastTimeButtonPress = millis();
  }  
}

void wakeUpNow()
{
  //dont need to do anything
}

void sleepNow()
{
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
  sleep_enable();
  
  attachInterrupt(0, wakeUpNow, LOW);
  sleep_mode(); // go to sleep
  sleep_disable(); // first thing after wakeup
  detachInterrupt(0);

  //restore the last state
  state = lastState - 1;

  //ensure off isnt restored
  if (state < 1 | state > maxStates)
    state = 1;
    
  waking = true;
}
