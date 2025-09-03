#!/usr/bin/env python3
"""
ZeroMQ Communication Hub for Unreal Engine 5 and MATLAB/Simulink Integration

This module serves as a communication bridge between UE5 and MATLAB/Simulink
using ZeroMQ for high-performance, low-latency data exchange.
"""

import json
import logging
import threading
import time
from typing import Dict, Any, Optional, Callable
import zmq
import numpy as np
import cv2
from PIL import Image
import io
import base64
import queue
import uuid
import argparse


class ImageDisplay:
    """
    Real-time image display for debugging and monitoring
    """
    
    def __init__(self, enabled: bool = False, window_size: tuple = (640, 480), fps_limit: int = 30):
        """Initialize image display."""
        self.enabled = enabled
        self.window_size = window_size
        self.fps_limit = fps_limit
        self.image_queue = queue.Queue(maxsize=10)
        self.display_thread = None
        self.running = False
        self.camera_windows = {}
        self.fps_counters = {}
        self.last_frame_time = {}
        
        # Check if GUI is available
        self.gui_available = self._check_gui_availability()
        
        if self.enabled and not self.gui_available:
            logging.getLogger(__name__).warning("GUI not available, image display disabled")
            self.enabled = False
    
    def _check_gui_availability(self) -> bool:
        """Check if GUI display is available."""
        logger = logging.getLogger(__name__)
        try:
            import os
            logger.info("Checking GUI availability...")
            
            # Check if we're in a headless environment
            if os.environ.get('DISPLAY') is None and os.name != 'nt':
                logger.warning("DISPLAY environment variable not set and not on Windows")
                return False
            
            logger.info(f"OS: {os.name}, DISPLAY: {os.environ.get('DISPLAY', 'Not set')}")
            
            # Try to initialize OpenCV window system
            logger.info("Testing OpenCV window creation...")
            cv2.namedWindow('test_window', cv2.WINDOW_NORMAL)
            cv2.destroyWindow('test_window')
            logger.info("OpenCV window test successful")
            return True
        except Exception as e:
            logger.error(f"GUI availability check failed: {e}")
            return False
    
    def start(self):
        """Start image display thread."""
        if not self.enabled:
            return
        
        self.running = True
        self.display_thread = threading.Thread(target=self._display_loop, name="Image-Display")
        self.display_thread.daemon = True
        self.display_thread.start()
        logging.getLogger(__name__).info("Image display started")
    
    def stop(self):
        """Stop image display thread."""
        if not self.enabled or not self.running:
            return
        
        self.running = False
        if self.display_thread:
            self.display_thread.join(timeout=2.0)
        
        # Close all windows
        for window_name in self.camera_windows.keys():
            cv2.destroyWindow(window_name)
        cv2.destroyAllWindows()
        
        logging.getLogger(__name__).info("Image display stopped")
    
    def add_image(self, camera_id: str, image_data: bytes):
        """Add image to display queue."""
        logger = logging.getLogger(__name__)
        
        if not self.enabled:
            logger.debug("Image display not enabled, skipping image")
            return
        
        logger.debug(f"Adding image to display queue: {camera_id} ({len(image_data)} bytes)")
        
        try:
            # Don't block if queue is full, just skip this frame
            self.image_queue.put_nowait((camera_id, image_data))
            logger.debug(f"Image added to queue successfully. Queue size: {self.image_queue.qsize()}")
        except queue.Full:
            logger.warning("Image display queue is full, skipping frame")
    
    def _display_loop(self):
        """Main display loop running in separate thread."""
        logger = logging.getLogger(__name__)
        
        while self.running:
            try:
                # Get image from queue with timeout
                camera_id, image_data = self.image_queue.get(timeout=1.0)
                
                # Decode image
                image = self._decode_image(image_data)
                if image is None:
                    continue
                
                # Update FPS counter
                self._update_fps(camera_id)
                
                # Display image
                self._display_image(camera_id, image)
                
                # Handle keyboard input
                key = cv2.waitKey(1) & 0xFF
                if key == 27:  # ESC key
                    logger.info("ESC pressed, stopping image display")
                    break
                elif key == ord('s'):  # S key - save screenshot
                    self._save_screenshot(camera_id, image)
                elif key == ord('f'):  # F key - toggle fullscreen
                    self._toggle_fullscreen(camera_id)
                
            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"Error in image display loop: {e}")
                time.sleep(0.1)
    
    def _decode_image(self, image_data: bytes) -> Optional[np.ndarray]:
        """Decode image data to OpenCV format."""
        try:
            # Try to decode as JPEG/PNG
            nparr = np.frombuffer(image_data, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if image is None:
                # Try PIL if OpenCV fails
                pil_image = Image.open(io.BytesIO(image_data))
                image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
            
            return image
        except Exception as e:
            logging.getLogger(__name__).error(f"Error decoding image: {e}")
            return None
    
    def _update_fps(self, camera_id: str):
        """Update FPS counter for camera."""
        current_time = time.time()
        
        if camera_id not in self.fps_counters:
            self.fps_counters[camera_id] = []
            self.last_frame_time[camera_id] = current_time
        
        # Add current time to counter
        self.fps_counters[camera_id].append(current_time)
        
        # Keep only last second of timestamps
        cutoff_time = current_time - 1.0
        self.fps_counters[camera_id] = [t for t in self.fps_counters[camera_id] if t > cutoff_time]
    
    def _get_fps(self, camera_id: str) -> float:
        """Get current FPS for camera."""
        if camera_id not in self.fps_counters:
            return 0.0
        return len(self.fps_counters[camera_id])
    
    def _display_image(self, camera_id: str, image: np.ndarray):
        """Display image in OpenCV window."""
        try:
            # Resize image if needed
            if self.window_size:
                image = cv2.resize(image, self.window_size)
            
            # Add overlay information
            image = self._add_overlay(camera_id, image)
            
            # Create window if it doesn't exist
            window_name = f"Camera: {camera_id}"
            if camera_id not in self.camera_windows:
                cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
                if self.window_size:
                    cv2.resizeWindow(window_name, self.window_size[0], self.window_size[1])
                self.camera_windows[camera_id] = window_name
            
            # Display image
            cv2.imshow(window_name, image)
            
        except Exception as e:
            logging.getLogger(__name__).error(f"Error displaying image for {camera_id}: {e}")
    
    def _add_overlay(self, camera_id: str, image: np.ndarray) -> np.ndarray:
        """Add overlay information to image."""
        try:
            # Get image info
            height, width = image.shape[:2]
            fps = self._get_fps(camera_id)
            
            # Add text overlay
            font = cv2.FONT_HERSHEY_SIMPLEX
            font_scale = 0.6
            color = (0, 255, 0)  # Green
            thickness = 2
            
            # Camera ID
            cv2.putText(image, f"Camera: {camera_id}", (10, 30), font, font_scale, color, thickness)
            
            # FPS
            cv2.putText(image, f"FPS: {fps:.1f}", (10, 60), font, font_scale, color, thickness)
            
            # Resolution
            cv2.putText(image, f"Size: {width}x{height}", (10, 90), font, font_scale, color, thickness)
            
            # Timestamp
            timestamp = time.strftime("%H:%M:%S")
            cv2.putText(image, f"Time: {timestamp}", (10, height - 20), font, font_scale, color, thickness)
            
            # Controls help
            help_text = "ESC: Exit | S: Screenshot | F: Fullscreen"
            text_size = cv2.getTextSize(help_text, font, 0.4, 1)[0]
            cv2.putText(image, help_text, (width - text_size[0] - 10, height - 10), 
                       font, 0.4, (255, 255, 255), 1)
            
            return image
        except Exception as e:
            logging.getLogger(__name__).error(f"Error adding overlay: {e}")
            return image
    
    def _save_screenshot(self, camera_id: str, image: np.ndarray):
        """Save screenshot of current image."""
        try:
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            filename = f"screenshot_{camera_id}_{timestamp}.jpg"
            cv2.imwrite(filename, image)
            logging.getLogger(__name__).info(f"Screenshot saved: {filename}")
        except Exception as e:
            logging.getLogger(__name__).error(f"Error saving screenshot: {e}")
    
    def _toggle_fullscreen(self, camera_id: str):
        """Toggle fullscreen mode for camera window."""
        try:
            window_name = self.camera_windows.get(camera_id)
            if window_name:
                # This is a simple implementation - OpenCV fullscreen support is limited
                cv2.setWindowProperty(window_name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
        except Exception as e:
            logging.getLogger(__name__).error(f"Error toggling fullscreen: {e}")


class ZeroMQHub:
    """
    ZeroMQ Communication Hub
    
    Manages bidirectional communication between UE5 and MATLAB/Simulink:
    - Receives images from UE5 cameras
    - Sends camera position/rotation commands to UE5
    - Forwards data to/from MATLAB/Simulink
    """
    
    def __init__(self, config: Optional[Dict[str, Any]] = None, show_images: bool = False):
        """Initialize the ZeroMQ Hub with configuration."""
        self.config = config or self._default_config()
        self.context = zmq.Context()
        
        # ZeroMQ sockets
        self.ue5_image_socket = None      # SUB - receives images from UE5
        self.ue5_control_socket = None    # PUB - sends control commands to UE5
        self.matlab_image_socket = None   # PUB - sends images to MATLAB
        self.matlab_control_socket = None # SUB - receives commands from MATLAB
        
        # HTTP fallback server (for development/testing)
        self.http_server = None
        
        # Image display
        display_config = self.config.get('display', {})
        self.image_display = ImageDisplay(
            enabled=show_images or display_config.get('enabled', False),
            window_size=tuple(display_config.get('window_size', [640, 480])),
            fps_limit=display_config.get('fps_limit', 30)
        )
        
        # State management
        self.running = False
        self.threads = []
        self.camera_states = {}
        self.image_callbacks = []
        self.control_callbacks = []
        
        # Latest images for HTTP access
        self.latest_images = {}
        self.image_lock = threading.Lock()
        # Known camera IDs discovered at runtime
        self.known_camera_ids = set()
        
        # Command queue for UE5 polling
        self.pending_commands = queue.Queue()
        self.command_lock = threading.Lock()
        
        # Setup logging
        self._setup_logging()
        
    def _default_config(self) -> Dict[str, Any]:
        """Return default configuration."""
        return {
            'ue5': {
                'image_port': 5555,
                'control_port': 5556,
                'bind_address': '*'
            },
            'matlab': {
                'image_port': 5557,
                'control_port': 5558,
                'bind_address': '*'
            },
            'http': {
                'enabled': True,
                'port': 8080,
                'host': '0.0.0.0'
            },
            'image': {
                'max_size': (1024, 1024),
                'quality': 85,
                'format': 'JPEG'
            },
            'logging': {
                'level': 'INFO',
                'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            }
        }
    
    def _setup_logging(self) -> None:
        """Setup logging configuration."""
        # Ensure logging config exists with defaults
        if 'logging' not in self.config:
            self.config['logging'] = {}
        
        log_config = self.config['logging']
        level = log_config.get('level', 'INFO')
        format_str = log_config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        
        logging.basicConfig(
            level=getattr(logging, level),
            format=format_str
        )
        self.logger = logging.getLogger(__name__)
    
    def start(self) -> None:
        """Start the ZeroMQ Hub server."""
        if self.running:
            self.logger.warning("Hub is already running")
            return
        
        self.logger.info("Starting ZeroMQ Hub...")
        
        # Initialize ZeroMQ sockets
        self._init_sockets()
        
        # Start HTTP server if enabled
        if self.config['http']['enabled']:
            self._start_http_server()
        
        # Start image display if enabled
        self.image_display.start()
        
        # Mark as running before starting threads so they observe running=True
        self.running = True
        
        # Start communication threads
        self._start_threads()
        
        self.logger.info("ZeroMQ Hub started successfully")
    
    def stop(self) -> None:
        """Stop the ZeroMQ Hub server."""
        if not self.running:
            return
        
        self.logger.info("Stopping ZeroMQ Hub...")
        self.running = False
        
        # Stop image display
        self.image_display.stop()
        
        # Wait for threads to finish
        for thread in self.threads:
            thread.join(timeout=5.0)
        
        # Close sockets
        self._close_sockets()
        
        # Terminate context
        self.context.term()
        
        self.logger.info("ZeroMQ Hub stopped")
    
    def _init_sockets(self) -> None:
        """Initialize ZeroMQ sockets."""
        # UE5 Image Socket (SUB - receives images from UE5)
        self.ue5_image_socket = self.context.socket(zmq.SUB)
        # Optionally subscribe to a configured list of camera IDs to reduce bandwidth.
        subscribe_ids = []
        try:
            subscribe_ids = self.config.get('ue5', {}).get('subscribe_ids', []) or []
        except Exception:
            subscribe_ids = []
        if subscribe_ids:
            for sid in subscribe_ids:
                try:
                    self.ue5_image_socket.setsockopt(zmq.SUBSCRIBE, sid.encode('utf-8'))
                    self.logger.info(f"Subscribed to camera ID topic: {sid}")
                except Exception as e:
                    self.logger.warning(f"Failed to subscribe to camera ID '{sid}': {e}")
        else:
            # Subscribe to all messages (default behavior)
            self.ue5_image_socket.setsockopt(zmq.SUBSCRIBE, b"")
        ue5_image_addr = f"tcp://{self.config['ue5']['bind_address']}:{self.config['ue5']['image_port']}"
        self.ue5_image_socket.bind(ue5_image_addr)
        self.logger.info(f"UE5 image socket bound to {ue5_image_addr}")
        
        # UE5 Control Socket (PUB - sends commands to UE5)
        self.ue5_control_socket = self.context.socket(zmq.PUB)
        ue5_control_addr = f"tcp://{self.config['ue5']['bind_address']}:{self.config['ue5']['control_port']}"
        self.ue5_control_socket.bind(ue5_control_addr)
        self.logger.info(f"UE5 control socket bound to {ue5_control_addr}")
        
        # MATLAB Image Socket (PUB - sends images to MATLAB)
        self.matlab_image_socket = self.context.socket(zmq.PUB)
        matlab_image_addr = f"tcp://{self.config['matlab']['bind_address']}:{self.config['matlab']['image_port']}"
        self.matlab_image_socket.bind(matlab_image_addr)
        self.logger.info(f"MATLAB image socket bound to {matlab_image_addr}")
        
        # MATLAB Control Socket (SUB - receives commands from MATLAB)
        self.matlab_control_socket = self.context.socket(zmq.SUB)
        self.matlab_control_socket.setsockopt(zmq.SUBSCRIBE, b"")
        matlab_control_addr = f"tcp://{self.config['matlab']['bind_address']}:{self.config['matlab']['control_port']}"
        self.matlab_control_socket.bind(matlab_control_addr)
        self.logger.info(f"MATLAB control socket bound to {matlab_control_addr}")
    
    def _close_sockets(self) -> None:
        """Close all ZeroMQ sockets."""
        sockets = [
            self.ue5_image_socket,
            self.ue5_control_socket,
            self.matlab_image_socket,
            self.matlab_control_socket
        ]
        
        for socket in sockets:
            if socket:
                socket.close()
    
    def _start_threads(self) -> None:
        """Start communication threads."""
        # UE5 Image Receiver Thread
        ue5_image_thread = threading.Thread(
            target=self._ue5_image_receiver,
            name="UE5-Image-Receiver"
        )
        ue5_image_thread.daemon = True
        ue5_image_thread.start()
        self.threads.append(ue5_image_thread)
        self.logger.info("Started UE5 image receiver thread")
        
        # MATLAB Control Receiver Thread
        matlab_control_thread = threading.Thread(
            target=self._matlab_control_receiver,
            name="MATLAB-Control-Receiver"
        )
        matlab_control_thread.daemon = True
        matlab_control_thread.start()
        self.threads.append(matlab_control_thread)
        self.logger.info("Started MATLAB control receiver thread")
    
    def _ue5_image_receiver(self) -> None:
        """Thread function to receive images from UE5."""
        self.logger.info("UE5 image receiver thread starting...")
        
        # Add connection status logging
        self.logger.info(f"UE5 image socket type: {self.ue5_image_socket.socket_type}")
        self.logger.info(f"Waiting for UE5 connections on port {self.config['ue5']['image_port']}")
        
        message_count = 0
        last_log_time = time.time()
        
        while self.running:
            try:
                # Check for messages with timeout
                if self.ue5_image_socket.poll(1000):  # 1 second timeout
                    self.logger.debug("Message available, receiving...")
                    message = self.ue5_image_socket.recv_multipart(zmq.NOBLOCK)
                    message_count += 1
                    
                    self.logger.info(f"Received message #{message_count} from UE5 ({len(message)} parts)")
                    self._process_ue5_image(message)
                else:
                    # Log periodically when no messages
                    current_time = time.time()
                    if current_time - last_log_time > 10.0:  # Every 10 seconds
                        self.logger.info(f"UE5 image receiver waiting... (received {message_count} messages so far)")
                        last_log_time = current_time
                        
            except zmq.Again:
                self.logger.debug("ZMQ timeout, continuing...")
                continue
            except zmq.ZMQError as e:
                self.logger.error(f"ZMQ error in UE5 image receiver: {e}")
                time.sleep(0.1)
            except Exception as e:
                self.logger.error(f"Unexpected error in UE5 image receiver: {e}")
                import traceback
                self.logger.error(f"Traceback: {traceback.format_exc()}")
                time.sleep(0.1)
        
        self.logger.info(f"UE5 image receiver thread stopped (processed {message_count} messages)")
    
    def _matlab_control_receiver(self) -> None:
        """Thread function to receive control commands from MATLAB."""
        self.logger.info("Started MATLAB control receiver thread")
        
        while self.running:
            try:
                # Receive message with timeout
                if self.matlab_control_socket.poll(1000):  # 1 second timeout
                    message = self.matlab_control_socket.recv_string(zmq.NOBLOCK)
                    self._process_matlab_control(message)
            except zmq.Again:
                continue  # Timeout, continue loop
            except Exception as e:
                self.logger.error(f"Error in MATLAB control receiver: {e}")
                time.sleep(0.1)
        
        self.logger.info("MATLAB control receiver thread stopped")
    
    def _process_ue5_image(self, message) -> None:
        """Process image message from UE5."""
        try:
            if len(message) >= 2:
                camera_id = message[0].decode('utf-8')
                image_data = message[1]
                
                # Track discovered camera IDs and log on first discovery
                if camera_id not in self.known_camera_ids:
                    try:
                        self.known_camera_ids.add(camera_id)
                        self.logger.info(f"Discovered new camera: {camera_id}. Known cameras: {sorted(self.known_camera_ids)}")
                    except Exception:
                        # Logging should not interrupt processing
                        pass
                
                self.logger.debug(f"Received image from camera {camera_id} ({len(image_data)} bytes)")
                
                # Store latest image for HTTP access
                with self.image_lock:
                    self.latest_images[camera_id] = {
                        'data': image_data,
                        'timestamp': time.time(),
                        'size': len(image_data)
                    }
                
                # Add to image display queue
                self.image_display.add_image(camera_id, image_data)
                
                # Process and forward image to MATLAB
                self._forward_image_to_matlab(camera_id, image_data)
                
                # Call registered callbacks
                for callback in self.image_callbacks:
                    callback(camera_id, image_data)
                    
        except Exception as e:
            self.logger.error(f"Error processing UE5 image: {e}")
    
    def _process_matlab_control(self, message: str) -> None:
        """Process control command from MATLAB."""
        try:
            command = json.loads(message)
            self.logger.debug(f"Received MATLAB command: {command}")
            
            # Forward command to UE5
            self._forward_command_to_ue5(command)
            
            # Call registered callbacks
            for callback in self.control_callbacks:
                callback(command)
                
        except Exception as e:
            self.logger.error(f"Error processing MATLAB control: {e}")
    
    def _forward_image_to_matlab(self, camera_id: str, image_data: bytes) -> None:
        """Forward image data to MATLAB."""
        try:
            # Create message for MATLAB
            message = [
                camera_id.encode('utf-8'),
                image_data
            ]
            
            self.matlab_image_socket.send_multipart(message, zmq.NOBLOCK)
            self.logger.debug(f"Forwarded image from {camera_id} to MATLAB")
            
        except Exception as e:
            self.logger.error(f"Error forwarding image to MATLAB: {e}")
    
    def _forward_command_to_ue5(self, command: Dict[str, Any]) -> None:
        """Forward control command to UE5."""
        try:
            message = json.dumps(command)
            self.ue5_control_socket.send_string(message, zmq.NOBLOCK)
            self.logger.debug(f"Forwarded command to UE5: {command}")
            
        except Exception as e:
            self.logger.error(f"Error forwarding command to UE5: {e}")
    
    def _start_http_server(self) -> None:
        """HTTP server disabled - using ZeroMQ only."""
        self.logger.info("HTTP server disabled - using pure ZeroMQ implementation")
    
    def add_image_callback(self, callback: Callable[[str, bytes], None]) -> None:
        """Add callback for image processing."""
        self.image_callbacks.append(callback)
    
    def add_control_callback(self, callback: Callable[[Dict[str, Any]], None]) -> None:
        """Add callback for control command processing."""
        self.control_callbacks.append(callback)

    def send_camera_command(self, camera_id: str, location: tuple, rotation: tuple, message_id: Optional[str] = None) -> None:
        """Send camera position/rotation command to UE5.

        If message_id is not provided, a UUID will be generated. The message
        dict will include 'message_id' when available to allow upstream
        systems to correlate acknowledgements if implemented.
        """
        try:
            if message_id is None:
                message_id = str(uuid.uuid4())
        except Exception:
            # Fallback in the unlikely event uuid fails
            message_id = "msg-unknown"

        command = {
            "type": "camera_transform",
            "camera_id": camera_id,
            "location": {"x": location[0], "y": location[1], "z": location[2]},
            "rotation": {"pitch": rotation[0], "yaw": rotation[1], "roll": rotation[2]},
            "message_id": message_id
        }

        try:
            self._forward_command_to_ue5(command)
        except Exception as e:
            try:
                self.logger.error(f"Failed to send camera command: {e}")
            except Exception:
                pass
    


def main():
    """Main function to run the ZeroMQ Hub."""
    import argparse
    
    parser = argparse.ArgumentParser(description='ZeroMQ Hub for UE5-MATLAB Communication')
    parser.add_argument('--config', type=str, help='Configuration file path')
    parser.add_argument('--log-level', type=str, default='INFO', 
                       choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                       help='Logging level')
    parser.add_argument('--show-images', action='store_true',
                       help='Enable real-time image display for debugging')
    
    args = parser.parse_args()
    
    # Load configuration
    config = None
    if args.config:
        try:
            with open(args.config, 'r') as f:
                config = json.load(f)
        except Exception as e:
            print(f"Error loading config file: {e}")
            return
    
    # Create hub with config (will use defaults if config is None)
    hub = ZeroMQHub(config, show_images=args.show_images)
    
    # Override log level if specified
    if 'logging' not in hub.config:
        hub.config['logging'] = {}
    hub.config['logging']['level'] = args.log_level
    
    try:
        hub.start()
        
        # Keep running until interrupted
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\nShutting down...")
    finally:
        hub.stop()


if __name__ == '__main__':
    main()
