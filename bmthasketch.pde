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

void setup() {
  size(640, 480);
  frameRate(FPS);
  background(backgroundColour);

  String[] arrPorts = Serial.list();
  // printArray(arrPorts);
  String portName = arrPorts[2]; // COM4
  println("portName = " + portName);
  myPort = new Serial(this, portName, BAUD);

  thread = new MyThread();
  thread.start();
}

int lastX = -1;
int lastY = -1;
void draw() {

  while (myPort.available() > 0) {
    // TODO consider yet another thread as the read may take 1/400th second
    String myString = myPort.readStringUntil(LF);
    if (myString != null) {
      String data = validateRxMessage(myString, "RX<-ESP32:");
      if (data != null) {
        DrawingAction action = parseData(data);

        println(String.format("action penDown=%b, x=%d, y=%d", action.penDown, action.x, action.y));

        if (action.penDown) {
          stroke(0);
          line(lastX, lastY, action.x, action.y);
        }

        lastX = action.x;
        lastY = action.y;
      }
    }
  }

  if (true) {
    noStroke();
    fill(backgroundColour);
    rect(5, 5, 50, 15);
    fill(textColour);
    textSize(12);
    text(String.format("%5.1f fps", frameRate), 5, 15);
  }
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
      int curY = mouseY;
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
