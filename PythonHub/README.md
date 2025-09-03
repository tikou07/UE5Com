# Python ZeroMQ Hub

UE5とMATLAB/Simulinkの間でZeroMQ通信を中継するPythonサーバーです。

## 機能

- UE5からの画像データ受信
- MATLAB/Simulinkへの画像データ転送
- MATLAB/Simulinkからの制御コマンド受信
- UE5への制御コマンド転送
- HTTP API（開発・テスト用）

## インストール

### UV環境での実行（推奨）

```bash
# 依存関係のインストール
uv sync

# サーバーの起動
uv run python zeromq_hub.py
```

### 通常のPython環境での実行

```bash
# 依存関係のインストール
pip install pyzmq opencv-python numpy pillow flask requests scipy matplotlib

# サーバーの起動
python zeromq_hub.py
```

## 使用方法

### 基本的な起動

```bash
uv run python zeromq_hub.py
```

### オプション付きの起動

```bash
# ログレベルを指定
uv run python zeromq_hub.py --log-level DEBUG

# 設定ファイルを指定
uv run python zeromq_hub.py --config config.json

# 画像表示機能を有効にして起動（デバッグ用）
uv run python zeromq_hub.py --show-images

# 複数オプションの組み合わせ
uv run python zeromq_hub.py --show-images --log-level DEBUG
```

### 画像表示機能

`--show-images` オプションを使用すると、UE5から受信した画像をリアルタイムで表示できます：

**機能:**
- リアルタイム画像表示
- FPS表示
- カメラID表示
- 画像サイズ・時刻情報
- キーボードショートカット

**キーボード操作:**
- `ESC`: 画像表示終了
- `S`: スクリーンショット保存
- `F`: フルスクリーン切り替え

**注意事項:**
- GUI環境が必要（ヘッドレス環境では自動的に無効化）
- 複数カメラの場合、各カメラごとに個別ウィンドウが表示
- 画像表示はデバッグ・監視用途で、パフォーマンスに影響する場合があります

### 設定ファイル例

```json
{
  "ue5": {
    "image_port": 5555,
    "control_port": 5556,
    "bind_address": "*"
  },
  "matlab": {
    "image_port": 5557,
    "control_port": 5558,
    "bind_address": "*"
  },
  "http": {
    "enabled": true,
    "port": 8080,
    "host": "0.0.0.0"
  },
  "image": {
    "max_size": [1024, 1024],
    "quality": 85,
    "format": "JPEG"
  },
  "logging": {
    "level": "INFO"
  }
}
```

## API

### ZeroMQHub クラス

#### 初期化
```python
hub = ZeroMQHub(config)
```

#### メソッド
- `start()`: サーバー開始
- `stop()`: サーバー停止
- `send_camera_command(camera_id, location, rotation)`: カメラコマンド送信
- `add_image_callback(callback)`: 画像処理コールバック追加
- `add_control_callback(callback)`: 制御コマンドコールバック追加

### HTTP API（開発・テスト用）

#### 画像送信
```bash
curl -X POST http://localhost:8080/image \
  -H "Camera-ID: Camera01" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @image.jpg
```

#### 制御コマンド送信
```bash
curl -X POST http://localhost:8080/control \
  -H "Content-Type: application/json" \
  -d '{
    "type": "camera_transform",
    "camera_id": "Camera01",
    "location": {"x": 100, "y": 200, "z": 300},
    "rotation": {"pitch": 0, "yaw": 45, "roll": 0}
  }'
```

#### ステータス確認
```bash
curl http://localhost:8080/status
```

## 通信プロトコル

### ポート設定
- **5555**: UE5からの画像データ受信（SUB）
- **5556**: UE5への制御コマンド送信（PUB）
- **5557**: MATLABへの画像データ送信（PUB）
- **5558**: MATLABからの制御コマンド受信（SUB）

### メッセージフォーマット

#### 画像データ（マルチパート）
```
[カメラID（文字列）, JPEG画像データ（バイナリ）]
```

#### 制御コマンド（JSON文字列）
```json
{
  "type": "camera_transform",
  "camera_id": "Camera01",
  "location": {"x": 100.0, "y": 200.0, "z": 300.0},
  "rotation": {"pitch": 0.0, "yaw": 45.0, "roll": 0.0}
}
```

## カスタマイズ

### 画像処理コールバックの追加

```python
def my_image_callback(camera_id: str, image_data: bytes):
    # 画像データの処理
    print(f"Received image from {camera_id}: {len(image_data)} bytes")

hub.add_image_callback(my_image_callback)
```

### 制御コマンドコールバックの追加

```python
def my_control_callback(command: dict):
    # 制御コマンドの処理
    print(f"Received command: {command}")

hub.add_control_callback(my_control_callback)
```

## トラブルシューティング

### よくある問題

1. **ポートが使用中**
   ```
   Error: Address already in use
   ```
   - 他のプロセスがポートを使用していないか確認
   - 設定ファイルで別のポートを指定

2. **ZeroMQライブラリが見つからない**
   ```
   ImportError: No module named 'zmq'
   ```
   - `uv sync` または `pip install pyzmq` を実行

3. **画像データが受信できない**
   - UE5プラグインが正しく設定されているか確認
   - ファイアウォール設定を確認

### ログレベルの変更

```bash
# デバッグ情報を表示
uv run python zeromq_hub.py --log-level DEBUG

# エラーのみ表示
uv run python zeromq_hub.py --log-level ERROR
```

## 開発

### テスト実行

```bash
# 単体テスト
uv run pytest

# カバレッジ付きテスト
uv run pytest --cov=zeromq_hub
```

### コード品質チェック

```bash
# フォーマット
uv run black zeromq_hub.py

# リント
uv run flake8 zeromq_hub.py

# 型チェック
uv run mypy zeromq_hub.py
```

## ライセンス

MIT License
