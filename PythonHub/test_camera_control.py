#!/usr/bin/env python3
"""
Simple test script to send camera_transform commands to UE5 via ZeroMQ.

Usage examples:
  # send a single transform
  python PythonHub/test_camera_control.py --camera Camera01 --loc 100 200 300 --rot 0 90 0

  # broadcast (empty camera_id)
  python PythonHub/test_camera_control.py --broadcast --loc 0 0 300 --rot 0 0 0

Notes:
- Reads PythonHub/config_zeromq.json for UE5 control port / host.
- Attempts to bind a PUB socket to tcp://*:{control_port}. If bind fails (port in use),
  it will try to connect to tcp://{server_ip}:{control_port} as a fallback.
- Adds a short sleep before sending to allow subscribers (UE5) to connect.
"""

import argparse
import json
import time
import sys
from pathlib import Path

import zmq

CONFIG_PATH = Path(__file__).resolve().parent / "config_zeromq.json"


def load_config():
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Failed to read config ({CONFIG_PATH}): {e}")
        return {}


def make_pub_socket(ctx, control_port, server_ip):
    """Create a PUB socket. Try bind first, fallback to connect."""
    sock = ctx.socket(zmq.PUB)
    bind_addr = f"tcp://*:{control_port}"
    connect_addr = f"tcp://{server_ip}:{control_port}"
    try:
        sock.bind(bind_addr)
        print(f"Control PUB bound to {bind_addr}")
        return sock, bind_addr
    except Exception as e:
        print(f"Bind to {bind_addr} failed: {e}. Trying connect to {connect_addr}")
        try:
            sock.connect(connect_addr)
            print(f"Control PUB connected to {connect_addr}")
            return sock, connect_addr
        except Exception as e2:
            print(f"Connect to {connect_addr} failed: {e2}")
            sock.close()
            return None, None


def build_command(camera_id: str, loc: tuple, rot: tuple):
    cmd = {
        "type": "camera_transform",
        "camera_id": camera_id,
        "location": {"x": float(loc[0]), "y": float(loc[1]), "z": float(loc[2])},
        "rotation": {"pitch": float(rot[0]), "yaw": float(rot[1]), "roll": float(rot[2])}
    }
    return cmd


def main():
    parser = argparse.ArgumentParser(description="Send camera transform commands to UE5 via ZeroMQ")
    parser.add_argument("--camera", "-c", type=str, default="Camera01", help="Camera ID (use empty string for broadcast)")
    parser.add_argument("--broadcast", action="store_true", help="Send as broadcast (empty camera_id)")
    parser.add_argument("--loc", nargs=3, type=float, required=True, metavar=("X", "Y", "Z"), help="Location X Y Z")
    parser.add_argument("--rot", nargs=3, type=float, required=True, metavar=("PITCH", "YAW", "ROLL"), help="Rotation pitch yaw roll")
    parser.add_argument("--delay", type=float, default=0.5, help="Delay (s) before sending to allow subscribers to connect")
    parser.add_argument("--repeat", type=int, default=1, help="Number of times to send the command")
    parser.add_argument("--interval", type=float, default=0.2, help="Interval between repeated sends (s)")
    args = parser.parse_args()

    cfg = load_config()
    ue5 = cfg.get("ue5", {})
    control_port = int(ue5.get("control_port", 5556))
    server_ip = ue5.get("bind_address", "127.0.0.1")
    # If bind_address is '*' in config, use localhost as connect fallback
    if server_ip == "*" or server_ip == "":
        server_ip = "127.0.0.1"

    camera_id = "" if args.broadcast else args.camera

    ctx = zmq.Context()
    sock, addr = make_pub_socket(ctx, control_port, server_ip)
    if sock is None:
        print("Failed to create control PUB socket. Exiting.")
        return 1

    # Wait a short time for subscriber (UE5) to connect
    print(f"Waiting {args.delay}s for subscribers to connect...")
    time.sleep(args.delay)

    cmd = build_command(camera_id, args.loc, args.rot)
    msg = json.dumps(cmd)

    for i in range(args.repeat):
        try:
            # send_string sends a single frame containing the JSON (UE5 worker expects a string JSON)
            sock.send_string(msg)
            print(f"[{i+1}/{args.repeat}] Sent: {msg}")
        except Exception as e:
            print(f"Failed to send message: {e}")
            break
        if i < args.repeat - 1:
            time.sleep(args.interval)

    # give a moment for sockets to flush
    time.sleep(0.1)
    sock.close()
    ctx.term()
    return 0


if __name__ == "__main__":
    sys.exit(main())
