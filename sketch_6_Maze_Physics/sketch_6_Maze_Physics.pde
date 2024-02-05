/**
 **********************************************************************************************************************
 * @file       Maze.pde
 * @author     Elie Hymowitz, Steve Ding, Colin Gallacher
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
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
/* end library imports *************************************************************************************************/  
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;

import javax.imageio.ImageIO;
import java.io.FileReader;
import java.util.ArrayList;
import javax.swing.Timer;
import java.awt.event.*;
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

/* define maze blocks */
FBox              b1;
FBox              b2;
FBox              b3;
FBox              b4;
FBox              b5;
FBox              l1;
ArrayList<FBox> maze;

/* define start and stop button */
FCircle           c1;
FCircle           c2;

/* define game ball */
FCircle           g2;
FBox              g1;

/* define game start */
boolean           gameStart                           = false;

/* text font */
PFont             f;
int[][] pixelArray;
int mazeImageWidth;
int mazeImageHeight;
Timer timer = null;
/* end elements definition *********************************************************************************************/  

void read_maze(){
  try {
            // Specify the path to your black and white image
            //String filePath = "C:\\Users\\naomi\\Documents\\GIT\\ETS\\CanHaptics\\Lab01\\sketch_6_Maze_Physics\\img\\maze1.png";
            String filePath = "C:\\Users\\naomi\\Documents\\GIT\\ETS\\CanHaptics\\Lab01\\sketch_6_Maze_Physics\\maze\\hello_maze.maze";
            
            //maze = new FBox[230][230];
            maze = new ArrayList<FBox>();

            // Read the image
            BufferedReader reader = new BufferedReader(new FileReader(filePath));
            
            String line = reader.readLine();
            int row = 0;
            while (line != null) {
              System.out.println(line);
              // read next line
              
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
              }
              row++;
              line = reader.readLine();
            }

            reader.close();
            // Get the width and height of the image
            /*mazeImageWidth = image.getWidth();
            mazeImageHeight = image.getHeight();
            
            // Create a 2D array to store the pixel values
            pixelArray = new int[mazeImageWidth][mazeImageHeight];
            
            // Loop through each pixel and populate the 2D array
            for (int x = 0; x < mazeImageWidth; x++) {
                for (int y = 0; y < mazeImageHeight; y++) {
                    // Get the RGB value of the pixel
                    int rgb = image.getRGB(x, y);
                    
                    // Extract the red component (assuming it's a grayscale image)
                    int red = (rgb >> 16) & 0xFF;
                    
                    // Convert to binary (black = 1, white = 0)
                    pixelArray[x][y] = (red == 0) ? 1 : 0;
                    System.out.print(pixelArray[x][y]);
                }
                System.out.println("");
            }
            
            // Now, 'pixelArray' contains 0s for white pixels and 1s for black pixels
            
            // You can use the 'pixelArray' for further processing or analysis
            */
        } catch (IOException e) {
            e.printStackTrace();
        }
}

/* setup section *******************************************************************************************************/
void setup(){
  /* put setup code here, run once: */
  //read_image();
  System.out.println(mazeImageWidth);
  System.out.println(mazeImageHeight);
  /* screen size definition */
  size(1000, 800);
  //size((int)(mazeImageWidth) * 10, (int)(mazeImageHeight) * 10);
  
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
  world               = new FWorld();
  
  read_maze();

  timer = new Timer(30, new ActionListener() {
      public void actionPerformed(ActionEvent e) {
          
      }
  });
  // Set maze barriers 
  /*maze = new FBox[pixelArray.length][pixelArray[0].length];
  for (int x = 0; x < pixelArray.length; x++) {
    for (int y = 0; y < pixelArray[0].length; y++) {
        
        if(pixelArray[x][y] == 1){
          maze[x][y] = new FBox(1, 1);
          maze[x][y].setPosition(edgeTopLeftX+x, edgeTopLeftY+y); 
          maze[x][y].setFill(0);
          maze[x][y].setNoStroke();
          maze[x][y].setStaticBody(true);
          world.add(maze[x][y]);

        }
    }
  }
*/

  /*b1                  = new FBox(0.1, 5.0);
  b1.setPosition(edgeTopLeftX+worldWidth/4.0-2, edgeTopLeftY+worldHeight/2+1.5); 
  b1.setFill(0);
  b1.setNoStroke();
  b1.setStaticBody(true);
  world.add(b1);
  
  b2                  = new FBox(1.0, 5.0);
  b2.setPosition(edgeTopLeftX+worldWidth/4.0, edgeTopLeftY+worldHeight/2-1.5); 
  b2.setFill(0);
  b2.setNoStroke();
  b2.setStaticBody(true);
  world.add(b2);
   
  b3                  = new FBox(0.5, 3.0);
  b3.setPosition(edgeTopLeftX+worldWidth/4.0+8, edgeTopLeftY+worldHeight/2+1.5); 
  b3.setFill(0);
  b3.setNoStroke();
  b3.setStaticBody(true);
  world.add(b3);
  
  b4                  = new FBox(1.0, 5.0);
  b4.setPosition(edgeTopLeftX+worldWidth/4.0+12, edgeTopLeftY+worldHeight/2-1.5); 
  b4.setFill(0);
  b4.setNoStroke();
  b4.setStaticBody(true);
  world.add(b4);
   
  b5                  = new FBox(3.0, 2.0);
  b5.setPosition(edgeTopLeftX+worldWidth/2.0, edgeTopLeftY+worldHeight/2.0+2);
  b5.setFill(0);
  b5.setNoStroke();
  b5.setStaticBody(true);
  world.add(b5);*/
  
  /* Set viscous layer */
 /* l1                  = new FBox(27,4);
  l1.setPosition(24.5/2,8.5);
  l1.setFill(150,150,255,80);
  l1.setDensity(100);
  l1.setSensor(true);
  l1.setNoStroke();
  l1.setStatic(true);
  l1.setName("Water");
  world.add(l1);*/
  
  /* Start Button */
  c1                  = new FCircle(2.0); // diameter is 2
  c1.setPosition(edgeTopLeftX+2.5, edgeTopLeftY+worldHeight/2.0-3);
  c1.setFill(0, 255, 0);
  c1.setStaticBody(true);
  world.add(c1);
  
  /* Finish Button */
  c2                  = new FCircle(2.0);
  c2.setPosition(worldWidth-2.5, edgeTopLeftY+worldHeight/2.0);
  c2.setFill(200,0,0);
  c2.setStaticBody(true);
  c2.setSensor(true);
  world.add(c2);
  
  /* Game Box */
 /* g1                  = new FBox(1, 1);
  g1.setPosition(2, 4);
  //g1.setDensity(80);
  g1.setFill(random(255),random(255),random(255));
  g1.setName("Widget");
  world.add(g1);*/
  
  /* Game Ball */
  g2                  = new FCircle(1);
  g2.setPosition(3, 4);
  g2.setDensity(80);
  g2.setFill(random(255),random(255),random(255));
  g2.setName("Widget");
  world.add(g2);
  
  /* Setup the Virtual Coupling Contact Rendering Technique */
  s                   = new HVirtualCoupling((0.75)); 
  s.h_avatar.setDensity(4); 
  s.h_avatar.setFill(255,0,0); 
  s.h_avatar.setSensor(true);

  s.init(world, edgeTopLeftX+worldWidth/2, edgeTopLeftY+2); 
  
  /* World conditions setup */
  world.setGravity((0.0), gravityAcceleration); //1000 cm/(s^2)
  //world.setEdges((edgeTopLeftX), (edgeTopLeftY), (edgeBottomRightX), (edgeBottomRightY)); 
  //world.setEdgesRestitution(.4);
  //world.setEdgesFriction(0.5);
  

 
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
 
    if(gameStart){
      fill(0, 0, 0);
      textAlign(CENTER);
      text("Push the ball or square to the red circle", width/2, 60);
      textAlign(CENTER);
      text("Touch the green circle to reset", width/2, 90);
    
      //b1.setFill(0, 0, 0);
      /*b2.setFill(0, 0, 0);
      b3.setFill(0, 0, 0);
      b4.setFill(0, 0, 0);
      b5.setFill(0, 0, 0);*/
      
    
    }
    else{
      fill(128, 128, 128);
      textAlign(CENTER);
      text("Touch the green circle to start the maze", width/2, 60);
    
      //b1.setFill(255, 255, 255);
     /* b2.setFill(255, 255, 255);
      b3.setFill(255, 255, 255);
      b4.setFill(255, 255, 255);
      b5.setFill(255, 255, 255);*/
    }
  
    world.draw();
  }
}
/* end draw section ****************************************************************************************************/

int previousFrame = 0;
int currentFrame = 0;

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
    
    if (s.h_avatar.isTouchingBody(c1)){
      gameStart = true;
      //g1.setPosition(2,8);
      //g2.setPosition(3,8);
      s.h_avatar.setSensor(false);
    }
  
    /*if(g1.isTouchingBody(c2) || g2.isTouchingBody(c2)){
      gameStart = false;
      s.h_avatar.setSensor(true);
    }*/
  
    currentFrame++;
    if(currentFrame - previousFrame > 1000){
      previousFrame = currentFrame;
      g2.adjustPosition(0.1, 0);
    }
    
  
     //Viscous layer codes 
    /*if (s.h_avatar.isTouchingBody(l1)){
      s.h_avatar.setDamping(400);
    }
    else{
      s.h_avatar.setDamping(10); 
    }
  
    if(gameStart && g1.isTouchingBody(l1)){
      g1.setDamping(20);
    }
  
    if(gameStart && g2.isTouchingBody(l1)){
      g2.setDamping(20);
    }
    */
    world.step(1.0f/1000.0f);
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/