import zmq
import json
import numpy as np

class ZeroMQImageReceiver:
    def __init__(self, address, topic, bind_mode=False, timeout=100, img_height=1024, img_width=1024, channels=3):
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.SUB)
        
        if bind_mode:
            self.socket.bind(address)
        else:
            self.socket.connect(address)
            
        self.socket.setsockopt_string(zmq.SUBSCRIBE, topic)
        self.socket.setsockopt(zmq.RCVTIMEO, timeout)
        
        self.img_height = img_height
        self.img_width = img_width
        self.channels = channels
        self.topic = topic

    def receive(self):
        try:
            # The message is multipart: [topic, data]
            topic_bytes = self.socket.recv()
            image_data = self.socket.recv(copy=False, track=False)
            
            # The topic is received as bytes, decode for comparison
            if topic_bytes.decode('utf-8') == self.topic:
                return image_data.buffer
            else:
                return None # Should not happen if subscription is working
                
        except zmq.Again:
            return None # Timeout
        except Exception as e:
            print(f"Error receiving data: {e}")
            return None

    def close(self):
        self.socket.close()
        self.context.term()

class ZeroMQControlSender:
    def __init__(self, address):
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.PUB)
        self.socket.bind(address)

    def send_transform(self, target_id, location, rotation):
        message = {
            "target_id": target_id,
            "location": list(location),
            "rotation": list(rotation)
        }
        try:
            self.socket.send_string(json.dumps(message))
        except Exception as e:
            print(f"Error sending transform data: {e}")

    def close(self):
        self.socket.close()
        self.context.term()
