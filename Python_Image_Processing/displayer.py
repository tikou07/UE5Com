import cv2
import numpy as np

class ImageDisplayer:
    def __init__(self, height, width, channels, title='Image Display'):
        self.height = height
        self.width = width
        self.channels = channels
        self.title = title
        self.window_created = False

    def update(self, image_data):
        if image_data is None:
            return

        try:
            image_data = np.frombuffer(image_data, dtype=np.uint8)
        except (ValueError, TypeError):
            pass # Assume it's already a numpy array

        expected_len = self.height * self.width * self.channels
        if image_data.size != expected_len:
            # Pad or truncate if necessary
            if image_data.size > expected_len:
                image_data = image_data[:expected_len]
            else:
                image_data = np.pad(image_data, (0, expected_len - image_data.size), 'constant')

        # Reshape from a flat buffer (C-style: C, W, H) to OpenCV's format (H, W, C)
        if self.channels > 1:
            image = image_data.reshape((self.channels, self.height, self.width))
            image = np.transpose(image, (1, 2, 0))
        else:
            image = image_data.reshape((self.height, self.width))
        
        # Convert RGB to BGR for OpenCV display
        if self.channels == 3:
            image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

        if not self.window_created:
            cv2.namedWindow(self.title, cv2.WINDOW_NORMAL)
            cv2.resizeWindow(self.title, self.width, self.height)
            self.window_created = True
            
        cv2.imshow(self.title, image)
        cv2.waitKey(1)

    def close(self):
        if self.window_created:
            cv2.destroyWindow(self.title)
