import oscP5.*;
import netP5.*;
import java.io.UnsupportedEncodingException;
import ddf.minim.*;
import ddf.minim.analysis.*;
OscP5 oscP5;

JSONObject json;

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
