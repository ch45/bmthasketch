// bmthasketch.pde

import processing.serial.*;

final float FPS = 60;
final int POLL_FREQ_MS = 100; // milliseconds
final int BAUD = 115200;
final int LF = 10;    // Linefeed in ASCII
final int backgroundColour = 255;
final int textColour = 32;

Serial myPort;
MyThread thread;
PImage backgroundImg;
PImage horizontalCarriageImg;
PImage horizontalFillImg;
PImage penHeadImg;
PImage penFillImg;
PGraphics paperFinal; // TODO vs paperDraft that may be the actual mouse x,y as a before the data goes off to the ESP32
int horizontalCarriageOffset;
int horizontalFillHeight;
int paperOffsetX;
int paperOffsetY;
int paperWidth;
int paperHeight;
int penHeadOffset;

void settings() {
  PImage img = loadImage("DrawingMachineTop.png");
  if (img != null) {
    size(img.width, img.height);
    backgroundImg = img;
  } else {
    size(640, 480);
  }
}

// x1, y1, x2, y2, origin bottom left
int[][] parts = {
  {67, 558, 1019, 666}, // horizontal carriage
  {67, 368, 1019, 516}, // horizontal fill
  {492, 520, 578, 666}, // pen head
  {592, 520, 678, 666}, // pen fill
  {210, 662, 848, 184}  // drawing bed
};
int penOffsetX = -32; //  -38;
int penOffsetY = -122; // -108;
color penColour = #00FF00;

void setup(){
  println(String.format("size width=%d, height=%d", width, height));

  createPlotterPieces(parts);

  frameRate(FPS);
  background(backgroundColour);

  String[] arrPorts = Serial.list();
  if (arrPorts.length > 2) {
    String portName = arrPorts[2]; // COM4
    println("portName = " + portName);
    myPort = new Serial(this, portName, BAUD);

    thread = new MyThread();
    thread.start();
  } else {
    println("Didn't find the serial port that the compiled sketch expects!");
    printArray(arrPorts);
  }
}

int lastX = -1;
int lastY = -1;
void draw() {
  drawBackgroundImage();
  drawReceivedData();
  if (true) {
    noStroke();
    fill(backgroundColour);
    rect(5, 5, 50, 15);
    fill(textColour);
    textSize(12);
    text(String.format("%5.1f fps", frameRate), 5, 15);
  }
}

void createPlotterPieces(int[][] data) {
  int count = 0;
  for (int[] coords : data) {
    int sx = min(coords[0], coords[2]);
    int sy = min(coords[1], coords[3]);
    int sw = abs(coords[0] - coords[2]);
    int sh = abs(coords[1] - coords[3]);

    println(String.format("sx,sy %d,%d sw,sh %d,%d", sx, sy, sw, sh));

    switch(count++) {
    case 0:
      horizontalCarriageOffset = sx;
      horizontalFillHeight = height - (sy + sh);
      horizontalCarriageImg = createImage(sw, sh, RGB);
      horizontalCarriageImg.copy(backgroundImg, horizontalCarriageOffset, horizontalFillHeight, sw, sh, 0, 0, sw, sh);
      break;
    case 1:
      horizontalFillImg = createImage(sw, sh, RGB);
      horizontalFillImg.copy(backgroundImg, sx, height - (sy + sh), sw, sh, 0, 0, sw, sh);
      break;
    case 2:
      penHeadOffset = sx;
      penHeadImg = createImage(sw, sh, RGB);
      penHeadImg.copy(backgroundImg, penHeadOffset, height - (sy + sh), sw, sh, 0, 0, sw, sh);
      break;
    case 3:
      penFillImg = createImage(sw, sh, RGB);
      penFillImg.copy(backgroundImg, sx, height - (sy + sh), sw, sh, 0, 0, sw, sh);
      break;
    case 4:
      paperOffsetX = sx;
      paperOffsetY = height - (sy + sh);
      paperWidth = sw;
      paperHeight = sh;
      paperFinal = createGraphics(paperWidth, paperHeight);
      break;
    default:
      // Nothing
      break;
    }
  }
}

void drawBackgroundImage() {
  if (backgroundImg == null) {
    return;
  }

  image(backgroundImg, 0, 0);
  image(horizontalFillImg, horizontalCarriageOffset, horizontalFillHeight);
  image(horizontalCarriageImg, horizontalCarriageOffset, mouseY + penOffsetY);
  image(penFillImg, penHeadOffset, mouseY + penOffsetY);
  image(penHeadImg, mouseX + penOffsetX, mouseY + penOffsetY);
}

void drawReceivedData() {

  paperFinal.beginDraw();

  // Paper edge guide:
  // paperFinal.noFill();
  // paperFinal.stroke(204, 102, 0);
  // paperFinal.rect(0, 0, paperWidth - 1, paperHeight - 1);

  if (myPort != null) {
    paperFinal.stroke(penColour);

    while (myPort.available() > 0) {
      // TODO consider yet another thread as the read may take 1/400th second
      String myString = myPort.readStringUntil(LF);
      if (myString != null) {
        String data = validateRxMessage(myString, "RX<-ESP32:");
        if (data != null) {
          DrawingAction action = parseData(data);

          println(String.format("action penDown=%b, x=%d, y=%d", action.penDown, action.x, action.y));

          if (action.penDown) {
            paperFinal.line(lastX - paperOffsetX, paperHeight - lastY, action.x - paperOffsetX, paperHeight - action.y);
          }

          lastX = action.x;
          lastY = action.y;
        }
      }
    }
  }

  paperFinal.endDraw();
  image(paperFinal, paperOffsetX, paperOffsetY);
}

String validateRxMessage(String data, String prefix) {
  if (data == null || prefix == null) {
    return null;
  }
  if (data.length() <= prefix.length()) {
    println("DISCARD:" + data);
    return null;
  }
  if (!data.startsWith(prefix)) {
    println("DISCARD:" + data);
    return null;
  }
  int endPos = data.length() - 1;
  if (data.charAt(endPos) != LF) {
    endPos++;
  }
  return data.substring(prefix.length(), endPos);
}

public class MyThread extends Thread {

  int x;
  int y;

  public void start() {
    super.start();
  }

  public void run()
  {
    for (;; delay(POLL_FREQ_MS)) {
      int curX = mouseX;
      int curY = paperHeight - (mouseY - paperOffsetY);
      if (curX != x || curY != y) {
        x = curX;
        y = curY;
        String sendData = String.format("TX->ESP32:%s,%d,%d\n", (mousePressed == true) ? "Pen Down" : "Pen Up", x, y);
        myPort.write(sendData);
        // print(sendData);
      }
    }
  }

}

public class DrawingAction {
  boolean penDown;
  int x;
  int y;

  public DrawingAction (boolean penDown, int x, int y) {
    this.penDown = penDown;
    this.x = x;
    this.y = y;
  }
}

DrawingAction parseData(String data) {
  // TODO consider a valid flag
  boolean penDown = false;
  int x;
  int y;
  int curPos = 0;
  if (data.startsWith("Pen")) {
    curPos += 4;
    if (data.startsWith("Up", curPos)) {
      /* penDown = false; */
      curPos += 3;
    } else if (data.startsWith("Down", curPos)) {
      penDown = true;
      curPos += 5;
    }
  }
  // println(data.substring(curPos));
  int sepOff = data.substring(curPos).indexOf(',');
  x = parseInt(data.substring(curPos, curPos + (sepOff > -1 ? sepOff : 0)));
  curPos += sepOff + 1;
  sepOff = data.substring(curPos).indexOf(',');
  y = parseInt(data.substring(curPos, curPos + (sepOff > -1 ? sepOff : data.substring(curPos).length())));
  return new DrawingAction(penDown, x, y);
}
