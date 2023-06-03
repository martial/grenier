import oscP5.*;
import netP5.*;
import java.io.UnsupportedEncodingException;
import ddf.minim.*;
import ddf.minim.analysis.*;
OscP5 oscP5;

// PFont myFont;
// int fontsize = 24;
// float lineheight = 1.1;

// String receivedPrompt = "";
// String receivedChat = "";
// float maxWidth = 610;
// float padding = 20;

// color listen_color = color(200, 200, 200);//152, 251, 152);
// color process_color = color(255, 255, 255);//216, 191, 216);
// color requesting_color = color(225, 225, 225);//216, 191, 216);
// String mode = "listening";

// BackgroundColorFader fader;
// ListeningCircle listen_circle;

// Minim minim;
// AudioInput audioInput;

JSONObject json;

// boolean quiet = false;


Prompt prompt1;
Prompt prompt2;

void setup()
{
    size(1280, 600);

    json = loadJSONObject("server-config.json");

    String host = json.getString("ip_address");
    int port = json.getJSONObject("ports").getInt("server_to_pde");
    int port2 = json.getJSONObject("ports2").getInt("server_to_pde");

    prompt1 = new Prompt(port);
    prompt2 = new Prompt(port2);
}

void draw()
{
    background(255);

    prompt1.draw(0);
    prompt2.draw(1);
}

void keyPressed()
{
}
