/**
 **********************************************************************************************************************
 * @file       Maze.pde
 * @author     Naomi Catwell, Elie Hymowitz, Steve Ding, Colin Gallacher
 * @version    V4.0.0
 * @date       08-January-2021
 * @brief      Maze game example using 2-D physics engine
 **********************************************************************************************************************
 * @attention
 *
 *
 **********************************************************************************************************************
 */



/* library imports *****************************************************************************************************/ 
import processing.serial.*;
import java.util.concurrent.*;
import static java.util.concurrent.TimeUnit.*;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.io.FileReader;
import java.util.ArrayList;
/* end library imports *************************************************************************************************/  

/* scheduler definition ************************************************************************************************/ 
private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
/* end scheduler definition ********************************************************************************************/ 

/* device block definitions ********************************************************************************************/
Board             haplyBoard;
Device            widgetOne;
Mechanisms        pantograph;

byte              widgetOneID                         = 5;
int               CW                                  = 0;
int               CCW                                 = 1;
boolean           renderingForce                     = false;
/* end device block definition *****************************************************************************************/



/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 120;
/* end framerate definition ********************************************************************************************/ 



/* elements definition *************************************************************************************************/

/* Screen and world setup parameters */
float             pixelsPerCentimeter                 = 40.0;

/* generic data for a 2DOF device */
/* joint space */
PVector           angles                              = new PVector(0, 0);
PVector           torques                             = new PVector(0, 0);

/* task space */
PVector           posEE                               = new PVector(0, 0);
PVector           fEE                                 = new PVector(0, 0); 

/* World boundaries */
FWorld            world;
float             worldWidth                          = 25.0;  
float             worldHeight                         = 10.0; 

float             edgeTopLeftX                        = 0.0; 
float             edgeTopLeftY                        = 0.0; 
float             edgeBottomRightX                    = worldWidth; 
float             edgeBottomRightY                    = worldHeight;

float             gravityAcceleration                 = 980; //cm/s2
/* Initialization of virtual tool */
HVirtualCoupling  s;

/* define maze blocks */
ArrayList<FBody> maze;
ArrayList<FBody> enemies;
ArrayList<FBody> interactables;

/* define start and stop button */
FCircle           startButton;
FCircle           finishButton;

/* define game start */
boolean           gameStart                           = false;

/* text font */
PFont             f;

String GAME_STATUS_MESSAGE = "";
int previousFrame = 0;
int currentFrame = 0;


enum WORD{
  NONE, WORD1, WORD2, WORD3
}
WORD WORD_STATE = WORD.NONE;

/* end elements definition *********************************************************************************************/  

void read_maze(){
  try {
            // Path to maze definition
            String filePath = "C:\\Users\\naomi\\Documents\\GIT\\ETS\\CanHaptics\\Labs\\Lab02\\config\\layout.config";
            
            maze = new ArrayList<FBody>();
            enemies = new ArrayList<FBody>();
            interactables = new ArrayList<FBody>();

            // Read the file
            BufferedReader reader = new BufferedReader(new FileReader(filePath));
            
            String line = reader.readLine();
            int row = 0;
            System.out.println("LAYOUT: ");
            while (line != null) {
              System.out.println(line);
              
              for(int col = 0; col < line.length(); col++){
                if(line.charAt(col) == '1'){
                  FBox box = new FBox(1, 1);                  
                  box.setPosition(edgeTopLeftX+col, edgeTopLeftY+row); 
                  box.setFill(0);
                  box.setNoStroke();
                  box.setStaticBody(true);
                  maze.add(box);
                  world.add(box);
                }
                else if(line.charAt(col) == 'h' || line.charAt(col) == 'v' || line.charAt(col) == 'H' || line.charAt(col) == 'V'){
                  FCircle enemy = new FCircle(1);
                  enemy.setPosition(edgeTopLeftX+col, edgeTopLeftY+row); 
                  enemy.setName(String. valueOf(line.charAt(col)));
                  enemy.setDensity(80);
                  enemy.setFill(random(255),random(255),random(255));
                  enemy.setStaticBody(true);
                  enemy.setDrawable(false);
                  enemies.add(enemy);
                  world.add(enemy);
                }
                else if (line.charAt(col) == 's'){
                  startButton = new FCircle(2.0);
                  startButton.setPosition(edgeTopLeftX+col, edgeTopLeftY+row); 
                  startButton.setFill(0, 255, 0);
                  startButton.setStaticBody(true);
                  startButton.setName("StartButton");
                  world.add(startButton);
                }
                else if(line.charAt(col) == 'f'){
                  finishButton = new FCircle(2.0);
                  finishButton.setPosition(edgeTopLeftX+col, edgeTopLeftY+row); 
                  finishButton.setFill(200,0,0);
                  finishButton.setStaticBody(true);
                  finishButton.setSensor(true);
                  finishButton.setName("FinishButton");
                  world.add(finishButton);
                }
                else if(line.charAt(col) == 't'){
                  FBox tactilePuddle  = new FBox(1,1);
                  tactilePuddle.setPosition(edgeTopLeftX+col, edgeTopLeftY+row); 
                  tactilePuddle.setDrawable(false);
                  tactilePuddle.setFill(150,150,255,80);
                  tactilePuddle.setDensity(100);
                  tactilePuddle.setSensor(true);
                  tactilePuddle.setNoStroke();
                  tactilePuddle.setStatic(true);
                  tactilePuddle.setName("TactilePuddle");
                  interactables.add(tactilePuddle);
                  world.add(tactilePuddle);
                }
                else if(line.charAt(col) == 'i'){
                  FBox stuckBox = new FBox(1, 1);
                  stuckBox.setPosition(edgeTopLeftX+col, edgeTopLeftY+row);
                  stuckBox.setDrawable(false);
                  stuckBox.setFill(random(255),random(255),random(255));
                  stuckBox.setSensor(true);
                  stuckBox.setNoStroke();
                  stuckBox.setStatic(true);
                  stuckBox.setName("StuckBox");
                  interactables.add(stuckBox);
                  world.add(stuckBox);
                }
              }
              row++;
              line = reader.readLine();
            }
            
            reader.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
}

/* setup section *******************************************************************************************************/
void setup(){
  /* put setup code here, run once */
  /* screen size definition */
  size(1000, 800);
  
  /* set font type and size */
  f = createFont("Arial", 16, true);

  /* device setup */  
  /**  
   * The board declaration needs to be changed depending on which USB serial port the Haply board is connected.
   * In the base example, a connection is setup to the first detected serial device, this parameter can be changed
   * to explicitly state the serial port will look like the following for different OS:
   *
   *      windows:      haplyBoard = new Board(this, "COM10", 0);
   *      linux:        haplyBoard = new Board(this, "/dev/ttyUSB0", 0);
   *      mac:          haplyBoard = new Board(this, "/dev/cu.usbmodem1411", 0);
   */
  haplyBoard          = new Board(this, Serial.list()[0], 0);
  widgetOne           = new Device(widgetOneID, haplyBoard);
  pantograph          = new Pantograph();
  
  widgetOne.set_mechanism(pantograph);

  widgetOne.add_actuator(1, CCW, 2);
  widgetOne.add_actuator(2, CCW, 1);

  widgetOne.add_encoder(1, CCW, 168, 4880, 2);
  widgetOne.add_encoder(2, CCW, 12, 4880, 1);  
  
  widgetOne.device_set_parameters();  
  
  /* 2D physics scaling and world creation */
  hAPI_Fisica.init(this); 
  hAPI_Fisica.setScale(pixelsPerCentimeter); 
  world = new FWorld();
  
  read_maze();
  
  /* Setup the Virtual Coupling Contact Rendering Technique */
  s = new HVirtualCoupling((0.75)); 
  s.h_avatar.setDensity(0); 
  s.h_avatar.setFill(255,0,0); 
  s.h_avatar.setSensor(false);

  s.init(world, edgeTopLeftX+worldWidth/2, edgeTopLeftY+2); 
  
  /* World conditions setup */
  world.setGravity((0.0), gravityAcceleration); //1000 cm/(s^2) 
  world.draw();
    
  /* setup framerate speed */
  frameRate(baseFrameRate);  
  
  /* setup simulation thread to run at 1kHz */
  SimulationThread st = new SimulationThread();
  scheduler.scheduleAtFixedRate(st, 1, 1, MILLISECONDS);
}
/* end setup section ***************************************************************************************************/



/* draw section ********************************************************************************************************/
void draw(){
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  if(renderingForce == false){
    background(255);
    textFont(f, 22);
 
    /*if(gameStart){
      for (FBody enemy : enemies){        
        enemy.setDrawable(true);
      }
      for (FBody mazeBlock : maze){        
        mazeBlock.setDrawable(true);
      }
      for (FBody interactable : interactables){        
        interactable.setDrawable(true);
      }
    }
    
      fill(128, 128, 128);
      textAlign(CENTER);
      text(GAME_STATUS_MESSAGE + "\nTouch the green circle to start the maze", width/2, 60);
      
      /*for (FBody enemy : enemies){
        enemy.setDrawable(false);
      }
      for (FBody mazeBlock : maze){        
        mazeBlock.setDrawable(false);
      }
      for (FBody interactable : interactables){        
        interactable.setDrawable(false);
      }*/
    
  
    world.draw();
  }
}
/* end draw section ****************************************************************************************************/

void keyPressed(){
  
  System.out.println("KEY: " + key);
  switch(key){
    case '0' : WORD_STATE = WORD.NONE; break;
    case '1' : WORD_STATE = WORD.WORD1; break;
    case '2' : WORD_STATE = WORD.WORD2; break;
    case '3' : WORD_STATE = WORD.WORD3; break;
  }
  System.out.println("WORD STATE : " + WORD_STATE);
}
ff

int direction = 1;
int animation_steps = 0;
int MAX_ENEMY_STEPS = 6;
void animate(){
  for (FBody enemy : enemies){
    if(enemy.getName().equals("h")){
      enemy.adjustPosition(direction * 0.5, 0);
    }
    else if(enemy.getName().equals("H")) { 
      enemy.adjustPosition(-direction * 0.5, 0);
    }
    else if(enemy.getName().equals("v")) { 
      enemy.adjustPosition(0, direction * 0.5);
    }
    else if(enemy.getName().equals("V")) { 
      enemy.adjustPosition(0, -direction * 0.5);
    }
  }
  if(animation_steps >= MAX_ENEMY_STEPS){
    animation_steps = 0;
    direction *= -1;
  }
  animation_steps++;
}

void game_over(boolean won){
  gameStart = false;
  s.h_avatar.setSensor(true);
  GAME_STATUS_MESSAGE = won? "YOU WON!" : "YOU LOST!";
}

/* simulation section **************************************************************************************************/
class SimulationThread implements Runnable{
  
  public void run(){
    /* Put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
    
    renderingForce = true;
    
    if(haplyBoard.data_available()){
      /* GET END-EFFECTOR STATE (TASK SPACE) */
      widgetOne.device_read_data();
    
      angles.set(widgetOne.get_device_angles()); 
      posEE.set(widgetOne.get_device_position(angles.array()));
      posEE.set(posEE.copy().mult(200));  
    }
    
    s.setToolPosition(edgeTopLeftX+worldWidth/2-(posEE).x, edgeTopLeftY+(posEE).y-7); 
    s.updateCouplingForce();
    
    fEE.set(-s.getVirtualCouplingForceX(), s.getVirtualCouplingForceY());
        
    fEE.div(100000); //dynes to newtons
    
    torques.set(widgetOne.set_device_torques(fEE.array()));
    widgetOne.device_write_torques();
    
    if (s.h_avatar.isTouchingBody(startButton)){
      gameStart = true;
      s.h_avatar.setSensor(false);
    }

    if(gameStart){
      if (s.h_avatar.isTouchingBody(finishButton)){
        game_over(true);
      }

      s.h_avatar.setDamping(0);
      for (FBody interactable : interactables){
        if(interactable.getName().equals("StuckBox") && s.h_avatar.isTouchingBody(interactable)){
          s.h_avatar.setDamping(800);
        }        
      }
    
      for (FBody enemy : enemies){
        if(s.h_avatar.isTouchingBody(enemy)){
          game_over(false);
        }
      }
    }
  
    currentFrame++;
    if(currentFrame - previousFrame > 1000){
      previousFrame = currentFrame;      
      animate();
    }
    
    world.step(1.0f/1000.0f);
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/