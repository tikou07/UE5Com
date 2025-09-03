import cv2
import numpy as np

class ImageFeatureExtractor:
    def __init__(self, mode, max_features=500, threshold=127):
        self.mode = mode.lower()
        self.max_features = max_features
        self.threshold = threshold

        if self.mode == 'orb':
            self.orb = cv2.ORB_create(nfeatures=self.max_features)
        elif self.mode != 'centroid':
            raise ValueError("Mode must be 'orb' or 'centroid'")

    def extract(self, image):
        if not isinstance(image, np.ndarray) or image.dtype != np.uint8:
            raise TypeError("Input image must be a numpy array of type uint8.")

        if self.mode == 'orb':
            return self._extract_orb(image)
        else: # centroid
            return self._extract_centroids(image)

    def _extract_orb(self, image):
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        keypoints = self.orb.detect(gray, None)
        
        processed_image = cv2.drawKeypoints(image, keypoints, None, color=(255, 0, 0))
        
        features = np.array([[kp.pt[0], kp.pt[1], kp.response] for kp in keypoints], dtype=np.float32)
        
        return processed_image, features

    def _extract_centroids(self, image):
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
        else:
            gray = image

        _, binary_image = cv2.threshold(gray, self.threshold, 255, cv2.THRESH_BINARY)
        
        contours, _ = cv2.findContours(binary_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        features = []
        for contour in contours:
            M = cv2.moments(contour)
            if M["m00"] != 0:
                cX = int(M["m10"] / M["m00"])
                cY = int(M["m01"] / M["m00"])
                features.append([cX, cY])
        
        features = np.array(features, dtype=np.float32)
        
        processed_image = cv2.cvtColor(binary_image, cv2.COLOR_GRAY2RGB)
        for x, y in features:
            cv2.drawMarker(processed_image, (int(x), int(y)), color=(0, 255, 0), markerType=cv2.MARKER_CROSS, thickness=2)
            
        return processed_image, features
