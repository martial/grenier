class ListeningCircle 
{
    String str;
    float volume;
    float radius;
    float amp;
    float fontsize;

    float start_time;
    float start_volume;
    float end_volume;

    float fade;

    ListeningCircle(String str)
    {
        this.str = str;
        
        this.volume = 0;
        this.start_volume = 0;
        this.end_volume = 0;
        
        this.amp = 10;

        this.radius = width/12;
        this.fontsize = 16;

        this.fade = 0.1;
    }

    void setVolume(float volume)
    {
        this.start_volume = this.volume;
        this.end_volume = volume*this.amp;
        this.end_volume = max(this.end_volume,0);
        this.end_volume = min(this.end_volume,1);
        this.start_time = millis();
    }

    void draw(PFont font)
    {
        float t = ((millis() - this.start_time)/1000.0) / this.fade;
        t = constrain(t, 0, 1);
        
        this.volume = lerp(this.start_volume, this.end_volume, t);

        this.radius = width/12 + this.volume*(width/12);
        this.fontsize = 16 + this.volume*(16);

        float pct = (frameCount%360)/360.0;

        textFont(font, this.fontsize);
        textAlign(CENTER);

        noFill();
        stroke(255);
        strokeWeight(2);

        push();
        translate(width/2, height/2);

        // ellipse(0, 0, r*2, r*2);

        float str_width = textWidth(str);
        float full_length = PI*this.radius*2;
        int repeats = floor(full_length / str_width);
        float spacing = (full_length-(repeats*str_width)) / repeats;

        float arc_length = pct*full_length;
        
        for (int j = 0; j < repeats; j++ ) 
        {
            for (int i = 0; i < str.length(); i++ ) 
            {
                // The character and its width
                char currentChar = str.charAt(i);
                float w = textWidth(currentChar); 
                arc_length += w/2;

                float theta = PI + arc_length / this.radius;

                push();
                translate(this.radius*cos(theta), this.radius*sin(theta)); 
                rotate(theta + PI/2); 

                noStroke();
                fill(255);
                text(currentChar, 0, 0);

                popMatrix();

                arc_length += w/2;
            } 

            arc_length += spacing;     
        }

        pop();
    }
}