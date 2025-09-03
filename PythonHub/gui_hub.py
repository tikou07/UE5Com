#!/usr/bin/env python3
"""
GUI for UE5 <-> Python ZeroMQ Hub
- PySide6 based desktop app
- Starts/stops a ZeroMQ SUB worker that receives multipart messages [camera_id, image_bytes]
- Displays realtime logs and an embedded image preview (toggleable)
- Allows editing the config_zeromq.json and running the firewall setup batch

Usage:
  (from repo root)
  python PythonHub/gui_hub.py
"""

import json
import os
import subprocess
import sys
import threading
import traceback
from pathlib import Path

import zmq
import uuid
import time
from PySide6 import QtCore, QtGui, QtWidgets
from zeromq_hub import ZeroMQHub

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = Path(__file__).resolve().parent / "config_zeromq.json"
FIREWALL_BATCH = ROOT / "setup_firewall_ue5_python.bat"


class ZeroMQWorker(QtCore.QThread):
    frame_received = QtCore.Signal(str, bytes)  # camera_id, image_bytes
    log = QtCore.Signal(str)

    def __init__(self, bind_address: str, parent=None):
        super().__init__(parent)
        self.bind_address = bind_address
        self._running = False
        self.context = None
        self.socket = None

    def run(self):
        try:
            self.context = zmq.Context()
            self.socket = self.context.socket(zmq.SUB)
            # Bind so UE5 can connect (matches test scripts)
            self.socket.bind(self.bind_address)
            self.socket.setsockopt(zmq.SUBSCRIBE, b"")
            self.socket.setsockopt(zmq.RCVTIMEO, 2000)  # 2s timeout
            self._running = True
            self.log.emit(f"ZeroMQ SUB bound to {self.bind_address}")
            while self._running:
                try:
                    parts = self.socket.recv_multipart()
                except zmq.Again:
                    continue
                except Exception as e:
                    self.log.emit(f"ZeroMQ receive error: {e}")
                    break

                if not parts:
                    continue

                if len(parts) >= 2:
                    try:
                        camera_id = parts[0].decode("utf-8", errors="ignore")
                    except Exception:
                        camera_id = "camera"
                    img_bytes = parts[1]
                    self.frame_received.emit(camera_id, img_bytes)
                else:
                    self.log.emit(f"Unexpected multipart length: {len(parts)}")
        except Exception as e:
            self.log.emit(f"Worker exception: {e}\n{traceback.format_exc()}")
        finally:
            try:
                if self.socket:
                    self.socket.close(linger=0)
                if self.context:
                    self.context.term()
            except Exception:
                pass
            self.log.emit("ZeroMQ worker stopped")

    def stop(self):
        self._running = False
        # wait a little for thread to exit gracefully
        self.wait(2000)


class MainWindow(QtWidgets.QMainWindow):
    frame_received_signal = QtCore.Signal(str, bytes)

    def __init__(self):
        super().__init__()
        self.setWindowTitle("UE5 ZeroMQ Hub - GUI")
        self.resize(1000, 700)

        # Central widget
        central = QtWidgets.QWidget()
        self.setCentralWidget(central)
        layout = QtWidgets.QVBoxLayout(central)

        # Top controls
        top_row = QtWidgets.QHBoxLayout()
        self.start_button = QtWidgets.QPushButton("Start")
        self.stop_button = QtWidgets.QPushButton("Stop")
        self.stop_button.setEnabled(False)
        self.preview_checkbox = QtWidgets.QCheckBox("Preview (embed)")
        self.preview_checkbox.setChecked(True)
        self.firewall_button = QtWidgets.QPushButton("Run Firewall Setup")
        self.conn_status_label = QtWidgets.QLabel("Control: N/A")
        top_row.addWidget(self.start_button)
        top_row.addWidget(self.stop_button)
        top_row.addWidget(self.preview_checkbox)
        top_row.addStretch()
        top_row.addWidget(self.firewall_button)
        top_row.addWidget(self.conn_status_label)
        layout.addLayout(top_row)

        # Splitter: left preview+logs, right config
        splitter = QtWidgets.QSplitter(QtCore.Qt.Horizontal)
        layout.addWidget(splitter, stretch=1)

        left_widget = QtWidgets.QWidget()
        left_layout = QtWidgets.QVBoxLayout(left_widget)

        # Preview area
        preview_group = QtWidgets.QGroupBox("Image Preview")
        preview_layout = QtWidgets.QVBoxLayout(preview_group)
        self.preview_label = QtWidgets.QLabel()
        self.preview_label.setAlignment(QtCore.Qt.AlignCenter)
        self.preview_label.setMinimumSize(320, 240)
        self.preview_label.setStyleSheet("background-color: #222; color: #fff;")
        preview_layout.addWidget(self.preview_label)
        left_layout.addWidget(preview_group, stretch=3)

        # Log area
        log_group = QtWidgets.QGroupBox("Logs")
        log_layout = QtWidgets.QVBoxLayout(log_group)
        self.log_text = QtWidgets.QPlainTextEdit()
        self.log_text.setReadOnly(True)
        log_layout.addWidget(self.log_text)
        left_layout.addWidget(log_group, stretch=2)

        splitter.addWidget(left_widget)

        # Right: config editor
        right_widget = QtWidgets.QWidget()
        right_layout = QtWidgets.QVBoxLayout(right_widget)
        cfg_group = QtWidgets.QGroupBox("Config (config_zeromq.json)")
        cfg_layout = QtWidgets.QVBoxLayout(cfg_group)
        self.cfg_editor = QtWidgets.QPlainTextEdit()
        cfg_layout.addWidget(self.cfg_editor)
        cfg_btn_row = QtWidgets.QHBoxLayout()
        self.load_cfg_btn = QtWidgets.QPushButton("Reload")
        self.save_cfg_btn = QtWidgets.QPushButton("Save")
        cfg_btn_row.addWidget(self.load_cfg_btn)
        cfg_btn_row.addWidget(self.save_cfg_btn)
        cfg_btn_row.addStretch()
        cfg_layout.addLayout(cfg_btn_row)
        right_layout.addWidget(cfg_group)

        # Camera control panel
        cam_group = QtWidgets.QGroupBox("Camera Control")
        cam_layout = QtWidgets.QGridLayout(cam_group)
        # Camera ID
        cam_layout.addWidget(QtWidgets.QLabel("Camera ID:"), 0, 0)
        self.camera_id_edit = QtWidgets.QLineEdit("Camera01")
        cam_layout.addWidget(self.camera_id_edit, 0, 1, 1, 3)
        # Position inputs
        cam_layout.addWidget(QtWidgets.QLabel("Position (X Y Z):"), 1, 0)
        self.pos_x = QtWidgets.QDoubleSpinBox()
        self.pos_x.setRange(-100000.0, 100000.0)
        self.pos_x.setValue(0.0)
        self.pos_y = QtWidgets.QDoubleSpinBox()
        self.pos_y.setRange(-100000.0, 100000.0)
        self.pos_y.setValue(0.0)
        self.pos_z = QtWidgets.QDoubleSpinBox()
        self.pos_z.setRange(-100000.0, 100000.0)
        self.pos_z.setValue(0.0)
        cam_layout.addWidget(self.pos_x, 1, 1)
        cam_layout.addWidget(self.pos_y, 1, 2)
        cam_layout.addWidget(self.pos_z, 1, 3)
        # Rotation inputs
        cam_layout.addWidget(QtWidgets.QLabel("Rotation (Pitch Yaw Roll):"), 2, 0)
        self.rot_pitch = QtWidgets.QDoubleSpinBox()
        self.rot_pitch.setRange(-360.0, 360.0)
        self.rot_pitch.setValue(0.0)
        self.rot_yaw = QtWidgets.QDoubleSpinBox()
        self.rot_yaw.setRange(-360.0, 360.0)
        self.rot_yaw.setValue(0.0)
        self.rot_roll = QtWidgets.QDoubleSpinBox()
        self.rot_roll.setRange(-360.0, 360.0)
        self.rot_roll.setValue(0.0)
        cam_layout.addWidget(self.rot_pitch, 2, 1)
        cam_layout.addWidget(self.rot_yaw, 2, 2)
        cam_layout.addWidget(self.rot_roll, 2, 3)
        # Send button
        self.send_cam_btn = QtWidgets.QPushButton("Send Transform")
        cam_layout.addWidget(self.send_cam_btn, 3, 0, 1, 4)

        # ACK and options
        ack_row = QtWidgets.QHBoxLayout()
        self.ack_checkbox = QtWidgets.QCheckBox("Wait for ACK")
        self.ack_checkbox.setChecked(False)
        ack_row.addWidget(self.ack_checkbox)
        ack_row.addWidget(QtWidgets.QLabel("Timeout(s):"))
        self.ack_timeout = QtWidgets.QDoubleSpinBox()
        self.ack_timeout.setRange(0.1, 10.0)
        self.ack_timeout.setValue(0.8)
        self.ack_timeout.setSingleStep(0.1)
        ack_row.addWidget(self.ack_timeout)
        ack_row.addWidget(QtWidgets.QLabel("Retries:"))
        self.ack_retries = QtWidgets.QSpinBox()
        self.ack_retries.setRange(0, 10)
        self.ack_retries.setValue(3)
        ack_row.addWidget(self.ack_retries)
        cam_layout.addLayout(ack_row, 4, 0, 1, 4)

        # Interpolation controls
        interp_row = QtWidgets.QHBoxLayout()
        self.interp_checkbox = QtWidgets.QCheckBox("Use Interp")
        self.interp_checkbox.setChecked(False)
        interp_row.addWidget(self.interp_checkbox)
        interp_row.addWidget(QtWidgets.QLabel("Interp time(s):"))
        self.interp_time = QtWidgets.QDoubleSpinBox()
        self.interp_time.setRange(0.0, 30.0)
        self.interp_time.setSingleStep(0.1)
        self.interp_time.setValue(1.0)
        interp_row.addWidget(self.interp_time)
        cam_layout.addLayout(interp_row, 5, 0, 1, 4)

        right_layout.addWidget(cam_group)

        # Control history
        history_group = QtWidgets.QGroupBox("Control History")
        history_layout = QtWidgets.QVBoxLayout(history_group)
        self.ctrl_history = QtWidgets.QPlainTextEdit()
        self.ctrl_history.setReadOnly(True)
        history_layout.addWidget(self.ctrl_history)
        right_layout.addWidget(history_group)

        splitter.addWidget(right_widget)
        splitter.setSizes([700, 300])

        # Status bar
        self.status = self.statusBar()
        self.status.showMessage("Ready")

        # Worker / Hub
        self.worker = None
        self.hub = None
        # thread-safe bridge: hub callbacks run in background threads, emit Qt signal to update UI
        self.frame_received_signal.connect(self.on_frame_received)

        # Connect signals
        self.start_button.clicked.connect(self.start_worker)
        self.stop_button.clicked.connect(self.stop_worker)
        self.load_cfg_btn.clicked.connect(self.load_config)
        self.save_cfg_btn.clicked.connect(self.save_config)
        self.firewall_button.clicked.connect(self.run_firewall_batch)
        self.preview_checkbox.stateChanged.connect(self.on_preview_toggle)
        self.send_cam_btn.clicked.connect(self.send_camera_command)

        # Load config initially
        self.load_config()

    def append_log(self, msg: str):
        self.log_text.appendPlainText(msg)
        # auto-scroll
        self.log_text.verticalScrollBar().setValue(self.log_text.verticalScrollBar().maximum())

    def load_config(self):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                txt = f.read()
            self.cfg_editor.setPlainText(txt)
            self.append_log(f"Loaded config: {CONFIG_PATH}")
        except Exception as e:
            self.append_log(f"Failed to load config: {e}")
            # create default
            default = {
                "ue5": {"image_port": 5555, "control_port": 5556, "bind_address": "*"},
                "image": {"format": "JPEG"},
            }
            self.cfg_editor.setPlainText(json.dumps(default, indent=4))

    def save_config(self):
        try:
            text = self.cfg_editor.toPlainText()
            # validate JSON
            data = json.loads(text)
            with open(CONFIG_PATH, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=4)
            self.append_log(f"Saved config to {CONFIG_PATH}")
        except Exception as e:
            self.append_log(f"Failed to save config: {e}")

    def get_bind_address(self):
        try:
            data = json.loads(self.cfg_editor.toPlainText())
            ue5 = data.get("ue5", {})
            port = int(ue5.get("image_port", 5555))
            # bind to wildcard for SUB
            address = f"tcp://*:{port}"
            return address
        except Exception as e:
            self.append_log(f"Invalid config, using default port 5555 ({e})")
            return "tcp://*:5555"

    def start_worker(self):
        """Start the ZeroMQHub instance and register callbacks."""
        if self.hub and getattr(self.hub, "running", False):
            self.append_log("Worker already running")
            return

        # Load config from editor or file
        try:
            cfg = json.loads(self.cfg_editor.toPlainText())
        except Exception:
            try:
                with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                    cfg = json.load(f)
            except Exception:
                cfg = None

        try:
            self.hub = ZeroMQHub(config=cfg, show_images=False)
            # Register a background callback that emits a Qt signal to update UI safely.
            # Also print to stdout for diagnostic visibility when running headless.
            def _hub_image_cb(cid, img):
                try:
                    print(f"GUI: hub callback received camera={cid} bytes={len(img)}", flush=True)
                except Exception:
                    pass
                self.frame_received_signal.emit(cid, img)
            self.hub.add_image_callback(_hub_image_cb)

            # Control callback with stdout echo for diagnostics
            def _hub_control_cb(cmd):
                try:
                    print(f"GUI: control callback received: {cmd}", flush=True)
                except Exception:
                    pass
                self.append_log(f"Control received: {cmd}")
            self.hub.add_control_callback(_hub_control_cb)

            self.hub.start()
            self.append_log("Worker (ZeroMQHub) started")
            self.start_button.setEnabled(False)
            self.stop_button.setEnabled(True)
            self.status.showMessage("Running")
        except Exception as e:
            self.append_log(f"Failed to start hub: {e}")
            self.hub = None

    def stop_worker(self):
        """Stop the ZeroMQHub (if running) and reset UI state."""
        if hasattr(self, "hub") and self.hub:
            try:
                self.hub.stop()
                self.append_log("Worker (ZeroMQHub) stopped")
            except Exception as e:
                self.append_log(f"Error stopping hub: {e}")
            finally:
                self.hub = None

        self.start_button.setEnabled(True)
        self.stop_button.setEnabled(False)
        self.status.showMessage("Stopped")
        # clear preview
        self.preview_label.clear()
        self.preview_label.setText("Preview disabled")

    def on_frame_received(self, camera_id: str, img_bytes: bytes):
        ts = QtCore.QDateTime.currentDateTime().toString("HH:mm:ss.zzz")
        self.append_log(f"[{ts}] Received frame from {camera_id} ({len(img_bytes):,} bytes)")
        if self.preview_checkbox.isChecked():
            # Load bytes directly into QPixmap
            pixmap = QtGui.QPixmap()
            ok = pixmap.loadFromData(img_bytes)
            if ok:
                # scale to fit label while keeping aspect ratio
                scaled = pixmap.scaled(self.preview_label.size(), QtCore.Qt.KeepAspectRatio, QtCore.Qt.SmoothTransformation)
                self.preview_label.setPixmap(scaled)
            else:
                self.append_log("Failed to load image data into QPixmap")

    def on_preview_toggle(self, state):
        if state == QtCore.Qt.Checked:
            self.append_log("Preview ON")
        else:
            self.append_log("Preview OFF")
            self.preview_label.clear()
            self.preview_label.setText("Preview disabled")

    def run_firewall_batch(self):
        if not FIREWALL_BATCH.exists():
            self.append_log(f"Firewall batch not found: {FIREWALL_BATCH}")
            return
        self.append_log("Running firewall setup batch (may require admin privileges)...")
        try:
            # Run in new process; note this will not elevate privileges automatically
            subprocess.Popen([str(FIREWALL_BATCH)], shell=True)
            self.append_log("Firewall batch executed")
        except Exception as e:
            self.append_log(f"Failed to run firewall batch: {e}")

    def ensure_control_socket(self):
        """No-op. Control sockets are managed by ZeroMQHub; use hub.send_camera_command()."""
        self.append_log("Control socket management delegated to ZeroMQHub")
        return

    def ensure_ack_socket(self):
        """No-op. ACK handling is not used in this configuration (delegated to ZeroMQHub if needed)."""
        self.append_log("ACK socket management delegated to ZeroMQHub (not active)")
        return

    def _ack_listener_loop(self):
        """ACK listener not used in this configuration."""
        return

    def send_camera_command(self):
        """Collect values from UI and send a camera_transform command via ZeroMQHub."""
        try:
            camera_id = self.camera_id_edit.text().strip()
            loc_x = float(self.pos_x.value())
            loc_y = float(self.pos_y.value())
            loc_z = float(self.pos_z.value())
            pitch = float(self.rot_pitch.value())
            yaw = float(self.rot_yaw.value())
            roll = float(self.rot_roll.value())

            message_id = str(uuid.uuid4())

            # include interp_time if requested
            try:
                interp_time = None
                if hasattr(self, "interp_checkbox") and self.interp_checkbox.isChecked():
                    interp_time = float(self.interp_time.value())
            except Exception:
                interp_time = None

            ts = time.strftime("%H:%M:%S")

            if not hasattr(self, "hub") or self.hub is None:
                self.append_log("Control hub not available; cannot send command")
                try:
                    self.ctrl_history.appendPlainText(f"[{ts}] {message_id} FAILED: no hub")
                except Exception:
                    pass
                return

            try:
                # Hub will include message_id automatically if needed; pass it through explicitly
                self.hub.send_camera_command(
                    camera_id,
                    (loc_x, loc_y, loc_z),
                    (pitch, yaw, roll),
                    message_id=message_id
                )
                cmd_summary = {
                    "camera_id": camera_id,
                    "location": {"x": loc_x, "y": loc_y, "z": loc_z},
                    "rotation": {"pitch": pitch, "yaw": yaw, "roll": roll},
                    "message_id": message_id,
                    "interp_time": interp_time
                }
                self.append_log(f"Sent camera command via hub: {cmd_summary}")
                try:
                    self.ctrl_history.appendPlainText(f"[{ts}] SENT {message_id} camera={camera_id} interp={interp_time or 0.0}")
                except Exception:
                    pass
            except Exception as e:
                self.append_log(f"Failed to send camera command: {e}")
                try:
                    self.ctrl_history.appendPlainText(f"[{time.strftime('%H:%M:%S')}] ERROR {message_id} {e}")
                except Exception:
                    pass

        except Exception as e:
            self.append_log(f"Error preparing camera command: {e}")


def main():
    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
