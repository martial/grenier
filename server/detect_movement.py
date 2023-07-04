import cv2
import mediapipe as mp
import numpy as np
from pythonosc import udp_client
from collections import deque

mp_drawing = mp.solutions.drawing_utils
mp_pose = mp.solutions.pose

# Set up OSC client
osc_client = udp_client.SimpleUDPClient("127.0.0.1", 5005)

# Create a deque for moving average calculation
MOVING_AVERAGE_SIZE = 10  # you can change this value
moving_average_values = deque(maxlen=MOVING_AVERAGE_SIZE)

def calculate_movement(prev_landmarks, curr_landmarks):
    if prev_landmarks is None or curr_landmarks is None:
        return 0

    sum_distance = 0
    for pl, cl in zip(prev_landmarks.landmark, curr_landmarks.landmark):
        sum_distance += np.sqrt((pl.x - cl.x) ** 2 + (pl.y - cl.y) ** 2 + (pl.z - cl.z) ** 2)
    return sum_distance

def moving_average(value, values):
    values.append(value)
    return sum(values) / len(values)

def main():
    cap = cv2.VideoCapture(1)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    with mp_pose.Pose(min_detection_confidence=0.5, min_tracking_confidence=0.5) as pose:
        prev_landmarks = None
        while cap.isOpened():
            success, image = cap.read()
            if not success:
                break

            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            image.flags.writeable = False
            results = pose.process(image)

            image.flags.writeable = True
            image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

            normalized_nose_x = 0.0
            normalized_nose_y = 0.0
            normalized_nose_z = 0.0
            if results.pose_landmarks:
                mp_drawing.draw_landmarks(
                    image, results.pose_landmarks, mp_pose.POSE_CONNECTIONS)

                movement = calculate_movement(prev_landmarks, results.pose_landmarks)
                movement_avg = moving_average(movement, moving_average_values)

                cv2.putText(image, f"Movement intensity: {movement_avg:.2f}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)

                osc_client.send_message("/movementIntensity", movement_avg)

                # Get normalized nose position
                nose = results.pose_landmarks.landmark[0]
                normalized_nose_x = (nose.x - 0.5) * 2.0
                normalized_nose_y = (nose.y - 0.5) * 2.0
                normalized_nose_z = nose.z
                prev_landmarks = results.pose_landmarks
                print(normalized_nose_z)

            # Send normalized nose position via OSC
            osc_client.send_message("/nose", [normalized_nose_x, normalized_nose_y, normalized_nose_z])

            cv2.imshow('MediaPipe Pose', image)
            if cv2.waitKey(5) & 0xFF == 27:
                break

        cap.release()


if __name__ == "__main__":
    main()
