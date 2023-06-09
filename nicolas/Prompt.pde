class Prompt
{
    PFont myFont;
    int fontsize = 24;
    float lineheight = 1.1;

    String receivedPrompt = "";
    String receivedChat = "";
    int maxWidth = 610;
    float padding = 20;

    color listen_color = color(200, 200, 200);//152, 251, 152);
    color process_color = color(255, 255, 255);//216, 191, 216);
    color requesting_color = color(225, 225, 225);//216, 191, 216);
    String mode = "listening";

    BackgroundColorFader fader;
    ListeningCircle listen_circle;

    Minim minim;
    AudioInput audioInput;

    boolean quiet = false;

    int port;

    Prompt(int osc_port)
    {
        port = osc_port;
        setup();
    }

    void setup()
    {
        // Initialize oscP5 and listen on port 8000
        OscProperties properties = new OscProperties();
        properties.setRemoteAddress("127.0.0.1",port);
        properties.setListeningPort(port);
        properties.setDatagramSize(8096);

        //oscP5 = new OscP5(this, port);
        oscP5 = new OscP5(this,properties);    

        fader = new BackgroundColorFader(250);  // Create an instance of BackgroundColorFader with a fade duration of 5 seconds
        fader.changeColor(listen_color);//152, 251, 152);

        listen_circle = new ListeningCircle("-");
        minim = new Minim(this);
        audioInput = minim.getLineIn(Minim.MONO, 512);

        myFont = loadFont("Cogito-Regular-22.vlw");
        textFont(myFont);

        smooth();
    }

    void draw(int offset)
    {        
        push();
        translate((offset*(padding*2+maxWidth)), 0);

        fader.update();

        float volume = audioInput.mix.level() * 1;
        listen_circle.setVolume(volume);

        textFont(myFont, fontsize);
        textLeading(fontsize*lineheight);
        textAlign(LEFT, TOP);
        fill(0);

        float offset_y = 0;
        text("You ask :", padding, padding);
        offset_y += fontsize*lineheight;
        
        String new_str = receivedPrompt;
        String wrappedText = wordWrap(new_str, maxWidth);

        // Display the received prompt text on the screen
        float max_height = (height/2)-padding-offset_y;
        int n_lines = getNumLines(wrappedText);
        float h = n_lines*fontsize*lineheight;

        if (h>max_height)
        {
            ArrayList<String> a_list = new ArrayList<String>();
            String[] list = wrappedText.split("\n");
            
            for (String e : list)
            {
              a_list.add(e);
            }
            while (h>max_height)
            {
              a_list.remove(0);
              wrappedText = String.join("\n", a_list);
              n_lines = getNumLines(wrappedText);
              h = n_lines*fontsize*lineheight;
            }
            /*
            while (h>max_height)
            {
                String[] newArray = new String[list.length-1];
                //list[0] = ""; // clear unused to avoid array max bounds
                //println("2 "+list.length+" "+newArray.length);
                arrayCopy(list, 1, newArray, 0, newArray.length);
                list = newArray;

                wrappedText = join(list, '\n');
                n_lines = getNumLines(wrappedText);
                h = n_lines*fontsize*lineheight;
            }
            */
        }

        // Display the received chat text on the screen
        text(wrappedText, padding, padding+offset_y);

        offset_y = height/2;

        text("Chat :", padding, padding+offset_y);
        offset_y += fontsize*lineheight;

        if (receivedChat.equals("InvalidRequestError — Tokens exceeeded"))
        {
            receivedChat += ". Veuillez relancer le programme";
            fill(255, 0, 0);
        }
        if (quiet)
        {
            fill(255, 165, 0);
        }

        new_str = receivedChat;
        wrappedText = wordWrap(new_str, maxWidth);
        n_lines = getNumLines(wrappedText);
        h = n_lines*fontsize*lineheight;

        if (h>max_height)
        {
            ArrayList<String> a_list = new ArrayList<String>();
            String[] list = wrappedText.split("\n");
            println(list.length);
            
            for (String e : list)
            {
              a_list.add(e);
            }
            while (h>max_height)
            {
              a_list.remove(0);
              wrappedText = String.join("\n", a_list);
              n_lines = getNumLines(wrappedText);
              h = n_lines*fontsize*lineheight;
            }
        }
        
        // Display the received chat text on the screen
        text(wrappedText, padding, padding+offset_y);

        fill(0);

        if ( mode == "listening" || mode == "requesting" )
        {
            listen_circle.draw(myFont);
        }

        pop();
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

        for (int i = 0; i < words.length; i++) 
        {
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
            quiet = false;
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
            if (status.equals("requesting"))
            {
                fader.changeColor(requesting_color);
                listen_circle.rotationSpeed = 1.0;
                listen_circle.scale = 0.0;
                listen_circle.circleColor = color(0, 0, 0);
                mode = "requesting";
            }
            if (status.equals("listening"))
            {
                fader.changeColor(listen_color);
                listen_circle.rotationSpeed = 0.001;
                listen_circle.scale = 1.0;
                listen_circle.circleColor = color(255, 255, 255);
                mode = "listening";
            }
            if (status.equals("pause"))
            {
                fader.changeColor(listen_color);
                listen_circle.rotationSpeed = 0.0;
                listen_circle.scale = 1.0;
                listen_circle.circleColor = color(255, 165, 0);
                mode = "listening";
            }
        }

        if (msg.checkAddrPattern("/reset/"))
        {
            receivedPrompt = "";
            receivedChat = "";
        }
        if (msg.checkAddrPattern("/quiet/"))
        {
            quiet = true;
            receivedChat = "Vous avez commencé à parler avant que je ne vous écoute, merci de marquer un silence";
        }        
    }
}
