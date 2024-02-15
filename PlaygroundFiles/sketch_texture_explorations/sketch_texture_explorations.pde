import controlP5.*;

ControlP5 cp5;

String[] textfieldNames = {"tf1", "tf2", "tf3", "tf4", "tf5"};

void setup() {
  size(700,400);

  PFont font = createFont("arial",20);

  cp5 = new ControlP5(this);

  int y = 20;
  int spacing = 60;
  for(String name: textfieldNames){
    cp5.addTextfield(name)
       .setPosition(20,y)
       .setSize(100,40)
       .setFont(font)
       .setFocus(true)
       .setColor(color(255,0,0))
       ;
     y += spacing;
  }

  textFont(font);
}

void draw() {
  background(0);
}

void controlEvent(ControlEvent theEvent) {
  if(theEvent.isAssignableFrom(Textfield.class)) {
    println("controlEvent: accessing a string from controller '"
    +theEvent.getName()+"': "
    +theEvent.getStringValue()
    );
  }
}