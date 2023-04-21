import oscP5.*;
import netP5.*;
import java.io.UnsupportedEncodingException;

OscP5 oscP5;
NetAddress sender;

PFont myFont;
int fontsize = 24;
float lineheight = 1.1;

String receivedPrompt = "raconte moi une histoire";
String receivedChat =
"Bien sûr, je serais heureux de vous raconter une histoire. Voici une histoire que j'ai créée pour vous :\n"+
"Il était une fois, dans une forêt dense et sombre, un petit renard nommé Roux. Roux était différent des autres renards car il avait des taches blanches sur ses pattes et une mèche blanche sur sa queue, ce qui le rendait facilement reconnaissable. Les autres renards se moquaient souvent de lui et le traitaient de Renard tacheté.\n"+
"Un jour, Roux a décidé qu'il était fatigué d'être taquiné par les autres renards et qu'il voulait prouver qu'il était capable de faire quelque chose de grand. Il a entendu parler d'une compétition qui avait lieu dans la forêt - une course de vitesse pour les animaux les plus rapides et les plus agiles. Il a décidé qu'il participerait à cette compétition et qu'il montrerait à tous les autres renards qu'il était capable de courir aussi vite qu'eux, voire plus vite.\n"+
"Le jour de la compétition est finalement arrivé. Roux était nerveux mais déterminé. Il a couru aussi vite qu'il le pouvait, en se concentrant sur la ligne d'arrivée. Les autres renards ont";

float maxWidth = 700;
float padding = 20;

color listen_color = color(0,0,0);//152, 251, 152);
color process_color = color(255,255,255);//216, 191, 216);

String mode = "listening";

BackgroundColorFader fader;
ListeningCircle listen_circle;

float listen_timeout = 0;

void setup() 
{
    size(800, 600);

    // Initialize oscP5 and listen on port 8000
    oscP5 = new OscP5(this, 8000);
    sender = new NetAddress("127.0.0.1", 8000);
    
    fader = new BackgroundColorFader(1000);  // Create an instance of BackgroundColorFader with a fade duration of 5 seconds
    fader.changeColor(listen_color);//152, 251, 152);

    listen_circle = new ListeningCircle("Listening...");

    smooth();
    myFont = loadFont("Cogito-Regular-22.vlw");
    textFont(myFont);
}

void draw() 
{
    // if (listen_timeout>=0)
    // {
    //   listen_timeout += (1/((float)60))/3;
    //   if ( listen_timeout>=1 && mode != "listening" )
    //   {
    //       fader.changeColor(listen_color);
    //       receivedPrompt = "";
    //       receivedChat = "";
    //       mode = "listening";
    //   }
    // }

    fader.update();

    if (mode == "listening")
    {
        listen_circle.draw(myFont);
    }
    else
    {
        textFont(myFont, fontsize);
        textLeading(fontsize*lineheight);
        textAlign(LEFT, TOP);
        fill(0);

        // Display the received prompt text on the screen
        String wrappedText = wordWrap("You ask : \n"+receivedPrompt, maxWidth);
        text(wrappedText, padding, padding);

        float offset_y = (getNumLines(wrappedText)+1)*fontsize*lineheight;

        // 

        text("Chat :", padding, padding+offset_y);
        offset_y += fontsize*lineheight;

        //

        // String txt = receivedChat;
        // String[] txt_list = split(txt, ' ');
        // String new_str = "";
        // for ( int i = 0; i < frameCount%txt_list.length; i++)
        // {
        //   new_str += txt_list[i]+" ";
        // }
        String new_str = receivedChat;
        
        float max_height = height-padding-offset_y;

        wrappedText = wordWrap(new_str, maxWidth);
        int n_lines = getNumLines(wrappedText);
        float h = n_lines*fontsize*lineheight;

        if (h>max_height)
        {
          while(h>max_height)
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
    }
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
            listen_timeout = -1;
            fader.changeColor(process_color);
            mode = "processing";
        }
        if (status.equals("listening")) 
        {
            listen_timeout = 0;
            fader.changeColor(listen_color);
            receivedPrompt = "";
            receivedChat = "";
            mode = "listening";
        }
    }

    if (msg.checkAddrPattern("/volume/")) 
    {
        float volume = msg.get(0).floatValue(); 
        listen_circle.setVolume(volume);     
    }
}

int getNumLines(String str)
{
    int count = 0;
    for(int i=0; i < str.length(); i++)
    {    
        if(str.charAt(i) == '\n') count++;
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
        listen_timeout = -1;
        mode = "processing";
        fader.changeColor(process_color);
    }
    else 
    { 
        mode = "listening"; 
        fader.changeColor(listen_color);
    }
}
