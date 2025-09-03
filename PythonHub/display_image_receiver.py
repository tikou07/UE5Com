#!/usr/bin/env python3
"""
ZeroMQ で UE5 から送られてくる JPEG 画像を受信して表示するスクリプト。

使い方:
  (PythonHub ディレクトリで) python -u display_image_receiver.py

動作:
  - デフォルトで tcp://*:5555 を bind して SUB で受信します（config があればそれを優先）
  - マルチパートメッセージを期待します: [camera_id, image_bytes]
  - image_bytes は JPEG バイト列と想定し、OpenCV でデコードして表示します
  - 'q' キーで終了します
"""

import json
import os
import time
import logging
from datetime import datetime

import zmq
import numpy as np
import cv2

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger("display_image_receiver")

# 設定ファイル読み込み（存在すれば）
DEFAULT_PORT = 5555
DEFAULT_HOST = "*"  # bind address

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config_zeromq_only.json")


def load_config():
    cfg = {}
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            cfg = json.load(f)
            logger.info(f"Loaded config: {CONFIG_PATH}")
    except FileNotFoundError:
        logger.info("Config file not found, using defaults.")
    except Exception as e:
        logger.warning(f"Failed to load config: {e}")
    return cfg


def get_bind_address(cfg):
    ue5 = cfg.get("ue5", {})
    port = ue5.get("image_port", DEFAULT_PORT)
    bind_addr = ue5.get("bind_address", DEFAULT_HOST)
    # If bind_address is "*" or "0.0.0.0" use tcp://*:<port> (zmq accepts * as wildcard)
    address = f"tcp://*:{port}"
    return address, port


def decode_image_from_bytes(img_bytes: bytes):
    """JPEGバイト列をOpenCV画像に変換（BGR）"""
    try:
        arr = np.frombuffer(img_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        return img
    except Exception as e:
        logger.exception(f"Failed to decode image: {e}")
        return None


def main():
    cfg = load_config()
    bind_address, port = get_bind_address(cfg)
    logger.info(f"Binding SUB socket to {bind_address} (port {port})")

    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    # bind so UE5 can connect
    socket.bind(bind_address)
    socket.setsockopt(zmq.SUBSCRIBE, b"")  # subscribe to all topics
    # set a receive timeout so we can handle exit/heartbeat
    socket.setsockopt(zmq.RCVTIMEO, 2000)  # 2000 ms

    received_count = 0
    start_time = time.time()
    last_stats_ts = start_time

    window_names = set()

    logger.info("Waiting for images from UE5. Start UE5 and enable the ZeroMQ camera actor.")
    logger.info("Press 'q' in any image window to quit.")

    try:
        while True:
            try:
                parts = socket.recv_multipart()
            except zmq.Again:
                # timeout
                # print periodic message if nothing received yet
                if received_count == 0:
                    logger.debug("No image received yet...")
                # allow key handling via OpenCV (must call waitKey even if no images)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    logger.info("Exit requested by user (q).")
                    break
                continue
            except KeyboardInterrupt:
                logger.info("KeyboardInterrupt received, exiting.")
                break
            except Exception as e:
                logger.exception(f"Unexpected error receiving message: {e}")
                time.sleep(0.1)
                continue

            if not parts:
                logger.warning("Received empty message")
                continue

            # Expect at least 2 parts: [camera_id, image_bytes]
            if len(parts) < 2:
                logger.warning(f"Unexpected multipart length: {len(parts)}")
                continue

            camera_id = None
            try:
                camera_id = parts[0].decode("utf-8")
            except Exception:
                # If camera id is binary or absent, use placeholder
                camera_id = "camera"
            img_bytes = parts[1]

            received_count += 1
            ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            logger.info(f"[{ts}] Received frame #{received_count} from '{camera_id}' ({len(img_bytes):,} bytes)")

            img = decode_image_from_bytes(img_bytes)
            if img is None:
                logger.warning("Decoded image is None (skipping display)")
                continue

            # Optionally convert color if needed (JPEG -> BGR from OpenCV is fine)
            win_name = f"UE5:{camera_id}"
            if win_name not in window_names:
                cv2.namedWindow(win_name, cv2.WINDOW_NORMAL)
                window_names.add(win_name)

            cv2.imshow(win_name, img)

            # FPS stats every 10 frames
            now = time.time()
            if received_count % 10 == 0:
                elapsed = now - start_time
                fps = received_count / elapsed if elapsed > 0 else 0.0
                logger.info(f"Stats: {received_count} frames, avg FPS: {fps:.2f}")

            # Key handling: if 'q' pressed in any window, exit
            if cv2.waitKey(1) & 0xFF == ord("q"):
                logger.info("Exit requested by user (q).")
                break

    finally:
        logger.info("Cleaning up sockets and windows...")
        try:
            socket.close()
            context.term()
        except Exception:
            pass
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass

        total_elapsed = time.time() - start_time
        if received_count > 0 and total_elapsed > 0:
            logger.info(f"Finished: received {received_count} frames in {total_elapsed:.2f}s (avg FPS {received_count/total_elapsed:.2f})")
        else:
            logger.warning("No frames were received.")

if __name__ == "__main__":
    main()
