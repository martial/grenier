class BackgroundColorFader 
{
  color startColor, endColor, currentColor;
  int fadeDuration, startTime;
  boolean changeLuminosity;

  BackgroundColorFader(int fadeDuration) {
    this.fadeDuration = fadeDuration;
    this.startTime = millis();
    this.changeLuminosity = false;
  }

  void changeColor(float r, float g, float b) {
    startColor = currentColor;
    endColor = color(r, g, b);
    startTime = millis();
  }

  void changeColor(color c) {
    startColor = currentColor;
    endColor = c;
    startTime = millis();
  }

  void update() {
    float t = (float) (millis() - startTime) / fadeDuration;
    t = constrain(t, 0, 1);
    currentColor = lerpColor(startColor, endColor, t);
    if (changeLuminosity) {
      float lum = brightness(currentColor);
      float newLum = lum + 20 * cos(PI * t);
      currentColor = color(hue(currentColor), saturation(currentColor), constrain(newLum, 0, 100));
    }
    background(currentColor);
  }
}
