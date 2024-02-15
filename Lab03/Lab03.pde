/**
 **********************************************************************************************************************
 * @file       Lab03.pde
 * @author     Naomi Catwell, 
 * @date       16-February-2024
 * @brief      Express three vocabulary words
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
private final ScheduledExecutorService scheduler      = Executors.newScheduledThreadPool(1);
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

ArrayList<FBody> worldBodies;
ArrayList<FBody> movingWalls;
ArrayList<FBody> stickList;

/* text font */
PFont             f;

/* animation */
int previousFrame = 0;
int currentFrame = 0;
float MAX_DISTANCE = 22;
float distanceTraveled = 0;
float distancePerStep = 0.1;
boolean enableAnimation = true;
boolean resetAnimation = false;


/* end elements definition *********************************************************************************************/  



/* setup section *******************************************************************************************************/
void setup(){
  /* put setup code here, run once: */
  
  /* screen size definition */
  size(1000, 800);
  
  /* set font type and size */
  f                   = createFont("Arial", 16, true);

  
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
  //haplyBoard          = new Board(this, Serial.list()[0], 0);
  haplyBoard          = new Board(this, "COM6", 0);
  widgetOne           = new Device(widgetOneID, haplyBoard);
  pantograph          = new Pantograph();
  
  widgetOne.set_mechanism(pantograph);

  widgetOne.add_actuator(1, CCW, 2);
  widgetOne.add_actuator(2, CW, 1);
 
  widgetOne.add_encoder(1, CCW, 241, 10752, 2);
  widgetOne.add_encoder(2, CW, -61, 10752, 1);
  
  
  widgetOne.device_set_parameters();
  
  
  /* 2D physics scaling and world creation */
  hAPI_Fisica.init(this); 
  hAPI_Fisica.setScale(pixelsPerCentimeter); 
  world               = new FWorld();
  
  
  /* Set maze barriers */
  read_layout_config();
  
  /* Setup the Virtual Coupling Contact Rendering Technique */
  s                   = new HVirtualCoupling((0.75)); 
  s.h_avatar.setDensity(4); 
  s.h_avatar.setFill(255,0,0); 
  s.h_avatar.setSensor(true);

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

int layoutIndex = 1;
void read_layout_config(){
  try {        
    worldBodies = new ArrayList<FBody>();
    movingWalls = new ArrayList<FBody>();
    stickList = new ArrayList<FBody>();

    for(int fileIndex = 1; fileIndex < 4; fileIndex++){
      // Read the file
      String filePath = "C:\\Users\\naomi\\Documents\\GIT\\ETS\\CanHaptics\\Labs\\Lab03\\config\\layout" + fileIndex + ".config";
      BufferedReader reader = new BufferedReader(new FileReader(filePath));
      
      String line = reader.readLine();
      int row = 0;
      System.out.println("LAYOUT: ");
      while (line != null) {
        System.out.println(line);
        
        for(int col = 0; col < line.length(); col++){
          if(line.charAt(col) == 'w'){
            FBox wall = new FBox(1, 1);                  
            wall.setPosition(edgeTopLeftX+col, edgeTopLeftY+row); 
            wall.setFill(0);
            wall.setNoStroke();
            wall.setStaticBody(true);
            wall.setName("wall");
            world.add(wall);
          }
          else if(line.charAt(col) == '1'){
            FCircle s1 = new FCircle(0.7);                  
            s1.setPosition(edgeTopLeftX+col, edgeTopLeftY+row); 
            s1.setFill(0);
            s1.setNoStroke();
            s1.setStaticBody(true);
            s1.setName("1");
            worldBodies.add(s1);
            world.add(s1);
          }
          else if(line.charAt(col) == '2'){
            FBox s2 = new FBox(1, 1);                  
            s2.setPosition(edgeTopLeftX+col, edgeTopLeftY+row); 
            s2.setFill(0);
            s2.setNoStroke();
            s2.setStaticBody(true);
            s2.setName("2");
            s2.setDrawable(false);
            movingWalls.add(s2);
            worldBodies.add(s2);
            world.add(s2);
          }
          else if(line.charAt(col) == '3'){
            FCircle s3 = new FCircle(random(1,5));
            s3.setPosition(edgeTopLeftX+col, edgeTopLeftY+row);
            s3.setFill(random(255),random(255),random(255));
            s3.setSensor(true);
            s3.setNoStroke();
            s3.setStatic(true);
            s3.setName("3");
            s3.setDrawable(false);
            stickList.add(s3);
            worldBodies.add(s3);
            world.add(s3);
          }
        }
        row++;
        line = reader.readLine();
      }
      reader.close();
    }
    
    
  } catch (IOException e) {
      e.printStackTrace();
  }
}
/* end setup section ***************************************************************************************************/

/* IO section */
void keyPressed(){  
  System.out.println("LAYOUT: " + key);  
  switch(key){
    case 's' : ToggleForce(true);  break;
    case 'q' : ToggleForce(false);  break;
    case '1' : layoutIndex = 1; break;
    case '2' : layoutIndex = 2; resetAnimation = true; break;
    case '3' : layoutIndex = 3; break;
  }
}
/* End IO section */


/* draw section ********************************************************************************************************/
void animate(){
  if(enableAnimation){
    for (FBody body : movingWalls){
      body.adjustPosition(distancePerStep, 0);      
    }

    distanceTraveled += distancePerStep;
    if(distanceTraveled >= MAX_DISTANCE){
      enableAnimation = false;
    }
  }
}

void draw(){
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  if(renderingForce == false){
    background(255);

    for(FBody body : worldBodies){
      body.setDrawable(false);
      body.setSensor(true);
    }

    for(FBody body : worldBodies){
      if(body.getName() != null && body.getName().equals(Integer.toString(layoutIndex))){
        body.setDrawable(true);
        if(body.getName().equals("1") || body.getName().equals("2")){
          body.setSensor(false);
        }
      }
    }
   
    world.draw();
  }
}
/* end draw section ****************************************************************************************************/


/* simulation section **************************************************************************************************/
class SimulationThread implements Runnable{
  
  public void run(){
    /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
    
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


    s.h_avatar.setDamping(0);
    for (FBody body : stickList){
      if(layoutIndex == 3 && s.h_avatar.isTouchingBody(body)){
        s.h_avatar.setDamping(900);
      }        
    }
    
    currentFrame++;
    if(currentFrame - previousFrame > 100){
      previousFrame = currentFrame;      
      animate();    
      if(resetAnimation){
        for (FBody body : movingWalls){
          body.adjustPosition(-distanceTraveled, 0);
        }
        distanceTraveled = 0;
        resetAnimation = false;
        enableAnimation = true;
      }
    }
    
    world.step(1.0f/1000.0f);
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/

/* Helper functions */
void ToggleForce(boolean produceForce){
  s.h_avatar.setSensor(!produceForce);
}