import time
import numpy as np
import cv2
from zmq_handler import ZeroMQImageReceiver, ZeroMQControlSender
from feature_extractor import ImageFeatureExtractor
from displayer import ImageDisplayer

# --- Configuration ---
IMG_H = 1024
IMG_W = 1024
CHANNELS = 3
ZMQ_RX_ADDRESS = 'tcp://localhost:5555'
ZMQ_RX_TOPIC = 'Camera01'
ZMQ_TX_ADDRESS = 'tcp://*:5556'

def main():
    print("--- Starting Image Processing Test ---")
    print("Initializing components...")
    try:
        # Create a control sender
        print("Initializing ZeroMQControlSender...")
        sender = ZeroMQControlSender(ZMQ_TX_ADDRESS)
        print("ZeroMQControlSender initialized.")
        
        # Create an image receiver
        print("Initializing ZeroMQImageReceiver...")
        receiver = ZeroMQImageReceiver(ZMQ_RX_ADDRESS, ZMQ_RX_TOPIC,
            img_height=IMG_H, img_width=IMG_W, channels=CHANNELS)
        print("ZeroMQImageReceiver initialized.")
            
        # Create feature extractors
        print("Initializing ImageFeatureExtractor (ORB)...")
        orb_extractor = ImageFeatureExtractor('orb', max_features=500)
        print("ImageFeatureExtractor (ORB) initialized.")
        print("Initializing ImageFeatureExtractor (Centroid)...")
        centroid_extractor = ImageFeatureExtractor('centroid', threshold=100)
        print("ImageFeatureExtractor (Centroid) initialized.")
        
        # Create display windows
        print("Initializing ImageDisplayer (Original)...")
        original_display = ImageDisplayer(IMG_H, IMG_W, CHANNELS, title='Original Image')
        print("ImageDisplayer (Original) initialized.")
        print("Initializing ImageDisplayer (ORB)...")
        orb_display = ImageDisplayer(IMG_H, IMG_W, CHANNELS, title='ORB Features')
        print("ImageDisplayer (ORB) initialized.")
        print("Initializing ImageDisplayer (Centroid)...")
        centroid_display = ImageDisplayer(IMG_H, IMG_W, CHANNELS, title='Centroids')
        print("ImageDisplayer (Centroid) initialized.")
        
    except Exception as e:
        print(f"Error during initialization: {e}")
        return

    print("\nInitialization complete. Starting processing loop...")
    print("Press Ctrl+C in the terminal to stop.")

    start_time = time.time()
    frame_count = 0
    try:
        while True:
            # Send a dummy control command
            t = time.time() - start_time
            loc = [1000 * np.sin(t), 1000 * np.cos(t), 50]
            rot = [0, 0, 90 * np.sin(t * 0.5)]
            sender.send_transform('Camera01', loc, rot)
            
            # Receive an image
            # print("Waiting to receive image...")
            img_data = receiver.receive()
            
            if img_data:
                print(f"Image received (size: {len(img_data)} bytes).")
                frame_count += 1
                
                # Display original image
                print("Updating original display...")
                original_display.update(img_data)
                print("Original display updated.")
                
                # Reshape image data for processing
                img = np.frombuffer(img_data, dtype=np.uint8).reshape((CHANNELS, IMG_H, IMG_W))
                img = np.transpose(img, (1, 2, 0))

                # Process and display ORB features
                print("Extracting ORB features...")
                orb_img, _ = orb_extractor.extract(img)
                print("Updating ORB display...")
                orb_display.update(cv2.cvtColor(orb_img, cv2.COLOR_RGB2BGR).tobytes())
                print("ORB display updated.")
                
                # Process and display centroids
                print("Extracting centroids...")
                centroid_img, _ = centroid_extractor.extract(img)
                print("Updating centroid display...")
                centroid_display.update(cv2.cvtColor(centroid_img, cv2.COLOR_RGB2BGR).tobytes())
                print("Centroid display updated.")
                
                if frame_count % 30 == 0:
                    elapsed_time = time.time() - start_time
                    fps = frame_count / elapsed_time
                    print(f"Processed {frame_count} frames. FPS: {fps:.2f}")
            
            # Check for 'q' key to quit
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
                
    except KeyboardInterrupt:
        print("Stopping loop.")
    except Exception as e:
        print(f"Error in processing loop: {e}")
    finally:
        # --- Cleanup ---
        print("Cleaning up...")
        receiver.close()
        sender.close()
        original_display.close()
        orb_display.close()
        centroid_display.close()
        print("Test finished.")

if __name__ == '__main__':
    main()
