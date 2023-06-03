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
  float smoothedVolume;
  float fade;
  float rotationSpeed = 0.01;
  float scale;
  color circleColor = color(255,255,255);

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
    this.rotationSpeed = 0.01;
     this.scale = 1.0;
  }

  void setVolume(float volume)
  {
    float alpha = 0.6;
    this.smoothedVolume = alpha * volume + (1 - alpha) * this.smoothedVolume;
    this.volume =this.smoothedVolume  * this.scale;
  }

  void draw(PFont font)
  {
    float t = ((millis() - this.start_time)/1000.0) / this.fade;
    t = constrain(t, 0, 1);



    this.radius = width/24 + this.volume*(width/24);
    this.fontsize = 16 + this.volume*(16);
    
    float fc = (float)frameCount * this.rotationSpeed;
    float pct = (fc % 360)/360.0;

    textFont(font, this.fontsize);
    textAlign(CENTER);

    noFill();
    stroke(circleColor);
    strokeWeight(2);

    push();
    float padding = 28.0f;
    translate(width/2 - width/24 - padding , height - width/24 - padding);


    // ellipse(0, 0, r*2, r*2);

    float str_width = textWidth(str);
    float full_length = PI*this.radius*2;
    int repeats = floor(full_length / str_width);
    float spacing = (full_length-(repeats*str_width)) / repeats;

    float arc_length = pct*full_length;

    // Variables for the sound wave
    float waveAmplitude = 10 * this.smoothedVolume ; // Adjust this value to change the amplitude of the wave
    float waveFrequency = 5;  // Adjust this value to change the frequency of the wave

    for (int j = 0; j < repeats; j++ )
    {
      for (int i = 0; i < str.length(); i++ )
      {
        // The character and its width
        char currentChar = str.charAt(i);
        float w = textWidth(currentChar);
        arc_length += w/2;

        float theta = PI + arc_length / this.radius;

        // Calculate the sine wave for the sound wave
        float waveOffset = waveAmplitude * sin(waveFrequency * theta);

        push();

        translate((this.radius + waveOffset) * cos(theta), (this.radius + waveOffset) * sin(theta));
        rotate(theta + PI/2);

        noStroke();
        fill(circleColor);
        text(currentChar, 0, 0);

        pop();

        arc_length += w/2;
      }

      arc_length += spacing;
    }

    pop();
  }
}
