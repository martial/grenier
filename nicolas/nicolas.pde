import oscP5.*;
import netP5.*;
import java.io.UnsupportedEncodingException;
import ddf.minim.*;
import ddf.minim.analysis.*;
OscP5 oscP5;
NetAddress sender;

PFont myFont;
int fontsize = 24;
float lineheight = 1.1;

String receivedPrompt = "";
String receivedChat = "";
float maxWidth = 700;
float padding = 20;

color listen_color = color(200, 200, 200);//152, 251, 152);
color process_color = color(255, 255, 255);//216, 191, 216);

String mode = "listening";

BackgroundColorFader fader;
ListeningCircle listen_circle;

Minim minim;
AudioInput audioInput;

void setup()
{
  size(800, 600);

  // Initialize oscP5 and listen on port 8000
  oscP5 = new OscP5(this, 8000);
  sender = new NetAddress("127.0.0.1", 8000);

  fader = new BackgroundColorFader(250);  // Create an instance of BackgroundColorFader with a fade duration of 5 seconds
  fader.changeColor(listen_color);//152, 251, 152);

  listen_circle = new ListeningCircle("-");
  minim = new Minim(this);
  audioInput = minim.getLineIn(Minim.MONO, 512);

  myFont = loadFont("Cogito-Regular-22.vlw");
  textFont(myFont);

  smooth();
}

void draw()
{
  fader.update();

  float volume = audioInput.mix.level() * 1;
  listen_circle.setVolume(volume);


  textFont(myFont, fontsize);
  textLeading(fontsize*lineheight);
  textAlign(LEFT, TOP);
  fill(0);

  // Display the received prompt text on the screen
  String wrappedText = wordWrap("You ask : \n"+receivedPrompt, maxWidth);
  text(wrappedText, padding, padding);

  float offset_y = (getNumLines(wrappedText)+1)*fontsize*lineheight;

  text("Chat :", padding, padding+offset_y);
  offset_y += fontsize*lineheight;

  String new_str = receivedChat;

  float max_height = height-padding-offset_y;

  wrappedText = wordWrap(new_str, maxWidth);
  int n_lines = getNumLines(wrappedText);
  float h = n_lines*fontsize*lineheight;

  if (h>max_height)
  {
    while (h>max_height)
    {
      String[] list = new_str.split("\n");
      String[] newArray = new String[list.length-1];
      arrayCopy(list, 1, newArray, 0, newArray.length);
      list = newArray;

      new_str = join(list, '\n');
      wrappedText = wordWrap(new_str, maxWidth);
      n_lines = getNumLines(wrappedText);
      h = n_lines*fontsize*lineheight;
    }
  }

  // Display the received chat text on the screen
  text(wrappedText, padding, padding+offset_y);

  if ( mode == "listening")
    listen_circle.draw(myFont);    
}

// This method is called when an OSC message is received
void oscEvent(OscMessage msg)
{
  if (msg.checkAddrPattern("/prompt/"))
  {
    byte[] receivedBytes = msg.get(0).blobValue();
    try {
      receivedPrompt = new String(receivedBytes, "UTF-8");
    }
    catch (UnsupportedEncodingException e) {
      println("UnsupportedEncodingException: " + e.getMessage());
    }
  }

  if (msg.checkAddrPattern("/chat/"))
  {
    byte[] receivedBytes = msg.get(0).blobValue();
    try {
      receivedChat = new String(receivedBytes, "UTF-8");
    }
    catch (UnsupportedEncodingException e) {
      println("UnsupportedEncodingException: " + e.getMessage());
    }
  }

  if (msg.checkAddrPattern("/status/"))
  {
    String status = msg.get(0).stringValue();
    if (status.equals("processing"))
    {
      fader.changeColor(process_color);
      mode = "processing";
    }
    if (status.equals("listening"))
    {
      fader.changeColor(listen_color);
      // receivedPrompt = "";
      //receivedChat = "";
      mode = "listening";
    }
  }
}

int getNumLines(String str)
{
  int count = 0;
  for (int i=0; i < str.length(); i++)
  {
    if (str.charAt(i) == '\n') count++;
  }
  return count+1;
}

// Word wrap function
String wordWrap(String inputText, float maxWidth)
{
  String[] words = inputText.split(" ");
  String outputText = "";
  String currentLine = "";

  for (int i = 0; i < words.length; i++) {
    String currentWord = words[i] + " ";
    float currentLineWidth = textWidth(currentLine + currentWord);

    if (currentLineWidth < maxWidth) {
      currentLine += currentWord;
    } else {
      outputText += currentLine + "\n";
      currentLine = currentWord;
    }
  }

  outputText += currentLine;
  return outputText;
}

void keyPressed()
{
  if (mode == "listening" )
  {
    mode = "processing";
    fader.changeColor(process_color);
  } else
  {
    mode = "listening";
    fader.changeColor(listen_color);
  }
}
