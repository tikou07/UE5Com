# Python_Image_Processing ライブラリ

概要
-----
本ディレクトリは、Unreal Engine 5 (UE5) から ZeroMQ 経由で送られてくる画像データを受信して表示・簡易処理するための Python ライブラリ群です。主な機能は以下の通りです。

- ZeroMQ を使った画像受信 (ZeroMQImageReceiver)
- UE5 側へ制御情報（Transform）を送信する PUB ソケット (ZeroMQControlSender)
- 受信画像を OpenCV ウィンドウへ表示するユーティリティ (ImageDisplayer)
- ORB 特徴量抽出および二値画像の重心検出 (ImageFeatureExtractor)
- 全体を統合する `main.py` により、受信→表示→特徴抽出→表示 の一連のテストが実行可能

Python環境のセットアップと管理
--------------------------------
本プロジェクトでは、高速なPythonパッケージインストーラ兼リゾルバである `uv` を用いて、Pythonの仮想環境とライブラリを管理します。依存関係は `pyproject.toml` ファイルで定義されています。

### 初回セットアップ
1. `build.bat` をダブルクリックして実行します。
2. スクリプトが自動的に `uv` をダウンロードし、`.venv` という名前のPython仮想環境を構築します。
3. `pyproject.toml` に記載されたライブラリが仮想環境にインストール（同期）されます。
4. 実行ログは `build_log.txt` に出力されます。エラーが発生した場合は、このログファイルを確認してください。

### ライブラリの追加・更新
プロジェクトに必要なライブラリを変更・追加・削除する場合は、`pyproject.toml` ファイル内の `[project.dependencies]` リストを編集します。

編集後、環境を同期するには、以下のいずれかの方法を実行します。
- **方法1（推奨）:** `build.bat` を再度実行します。
- **方法2（手動）:** ターミナルで `uv sync` コマンドを実行します。
  ```bash
  # uv.exeへのパスを通しているか、ThirdParty/uv/uv.exe を直接指定
  uv sync
  ```

### スクリプトの実行
`main.py` を実行するには、いくつかの方法があります。

#### 方法1: `uv run` を使用する（推奨）
`uv run` コマンドを使うと、仮想環境を明示的に有効化 (`activate`) する必要がなく、シンプルにスクリプトを実行できます。
```bash
uv run python main.py
```

#### 方法2: 仮想環境を有効化して実行する
従来通り、仮想環境を有効化してからスクリプトを実行することも可能です。
```bash
# 仮想環境を有効化
.venv\Scripts\activate.bat

# スクリプトを実行
python main.py
```
実行後、ウィンドウが開き、受信画像・特徴表示が行われます。`q` キーで終了、Ctrl+C でも停止可能です。

各モジュールの詳細
------------------

ZeroMQImageReceiver (zmq_handler.py)
- 目的:
  - SUB ソケットで指定アドレス・トピックから画像データを受信する
- コンストラクタ引数:
  - address: 接続先アドレス (例: 'tcp://localhost:5555')
  - topic: 受信するトピック名 (例: 'Camera01')
  - bind_mode: True なら bind、False なら connect（デフォルト False）
  - timeout: 受信タイムアウト（ミリ秒、デフォルト 100）
  - img_height, img_width, channels: 画像サイズ情報（受信側で扱う想定値。デフォルト 1024,1024,3）
- メソッド:
  - receive()
    - 受信が成功するとバイナリデータ (memoryview / buffer) を返す
    - タイムアウト時は None を返す
    - 期待されるメッセージ形式: multipart [topic, data]
    - 実装メモ: topic が一致する場合に `image_data.buffer` を返します（memoryview の underlying buffer）
- close()
  - ソケットとコンテキストを閉じる

ZeroMQControlSender (zmq_handler.py)
- 目的:
  - PUB ソケットで UE5 等に制御情報（Transform）を送る
- コンストラクタ引数:
  - address: bind するアドレス (例: 'tcp://*:5556')
- メソッド:
  - send_transform(target_id, location, rotation)
    - target_id: 文字列（例: 'Camera01'）
    - location: iterable (x,y,z) の数値リスト
    - rotation: iterable (roll,pitch,yaw) の数値リスト
    - 実装: 内部で JSON にして send_string します
- close()
  - ソケットとコンテキストを閉じる

ImageDisplayer (displayer.py)
- 目的:
  - 受信したバイト列や numpy 配列を OpenCV のウィンドウに表示する
- コンストラクタ:
  - ImageDisplayer(height, width, channels, title='Image Display')
    - height, width, channels: 表示対象の画像サイズ・チャンネル数
    - title: ウィンドウタイトル（デフォルト 'Image Display'）
- メソッド:
  - update(image_data)
    - image_data に受信したバイト列（bytes / memoryview / buffer）や numpy.ndarray を渡す
    - 処理内容:
      1. bytes や memoryview を np.frombuffer で読み取り、フラットな uint8 配列にする（例外時はそのまま扱う）
      2. 必要に応じてパディングまたはトリミングして長さを height*width*channels に合わせる
      3. チャンネルが複数の場合は (channels, height, width) → transpose → (height, width, channels) にリシェイプ
         - これは送信側がチャネル優先 (C,H,W) のフラット配列で送ってくることを想定した処理
      4. チャンネルが 3 の場合は RGB→BGR に変換して OpenCV に渡す
      5. ウィンドウが作られていなければ生成し、cv2.imshow で表示、cv2.waitKey(1) を呼ぶ
    - 注意:
      - image_data が既に numpy.ndarray の場合、update は直接それを扱います（dtype と形状に注意）
  - close()
    - 作成したウィンドウを破棄

ImageFeatureExtractor (feature_extractor.py)
- 目的:
  - 受信画像に対して ORB 特徴量抽出または二値画像の重心（Centroid）検出を行い、可視化画像と特徴配列を返す
- コンストラクタ:
  - ImageFeatureExtractor(mode, max_features=500, threshold=127)
    - mode: 'orb' または 'centroid'（小文字で比較）
    - max_features: ORB モード時の特徴点数上限
    - threshold: centroid（閾値）モード時の二値化閾値
- メソッド:
  - extract(image)
    - image: numpy.ndarray（dtype=np.uint8）を想定。RGB カラ―画像 (H,W,3) を想定（centroid はグレースケールも許容）
    - 戻り値: (processed_image, features)
      - processed_image: 特徴を描画した RGB 画像（numpy uint8）
      - features:
        - ORB モード: ndarray(float32, N x 3) 各行 [x, y, response]
        - Centroid モード: ndarray(float32, M x 2) 各行 [cX, cY]
- 実装詳細:
  - ORB:
    - 入力を RGB→GRAY に変換、ORB で keypoints を検出、元画像上に keypoints を描画
    - 特徴配列は (x, y, response) の形で返す
  - Centroid:
    - RGB をグレースケール化し閾値で二値化、輪郭抽出を行い矩形のモーメントから重心を算出
    - binary image をカラー変換し、重心にマーカーを描画して返す

main.py のワークフロー
--------------------
`main.py` は各コンポーネントを初期化し、ループで以下を繰り返します:

1. ZeroMQControlSender でダミーの transform（location, rotation）を送信
2. ZeroMQImageReceiver.receive() で画像を受信
3. 受信したバイト列を ImageDisplayer.update() に渡してオリジナル画像を表示
4. numpy に変換して (H,W,C) 形式に整形
5. ImageFeatureExtractor（ORB）で特徴抽出 → 描画画像を ImageDisplayer で表示
6. ImageFeatureExtractor（Centroid）で重心検出 → 描画画像を別ウィンドウで表示
7. フレーム数に基づく FPS ログ出力
8. キー入力 `q` でループ終了（または Ctrl+C）

注意点・トラブルシューティング
----------------------------
- 送信側（UE5）と受信側でトピック名、アドレス、送信データのレイアウト (C,H,W のフラットバイト列) を必ず合わせてください。topic が一致しないと画像を受信しません。
- 受信データのバイト長が期待値と異なる場合、displayer は自動でパディング/トリミングしますが、 異なる画像解像度・チャンネル順を使っていると正しく表示されません。
- OpenCV の GUI が表示されない場合:
  - Windows のリモートセッションや headless 環境ではウィンドウ表示がうまく動作しないことがあります。この場合は画像をファイル出力して確認してください。
- ZeroMQ の PUB/SUB は接続順に敏感です。PUB を bind、SUB を connect とする一般的パターンに従うか、送信側の準備が整う前に受信側が待機しているか確認してください。
- firewall やポート競合に注意してください（ポート 5555, 5556 を使用している例が多いです）。

サンプルコード (最小例)
---------------------
受信して表示する最小の流れ（概念）:
```python
from Python_Image_Processing.zmq_handler import ZeroMQImageReceiver
from Python_Image_Processing.displayer import ImageDisplayer

receiver = ZeroMQImageReceiver('tcp://localhost:5555', 'Camera01', img_height=1024, img_width=1024, channels=3)
displayer = ImageDisplayer(1024, 1024, 3, title='Original')

while True:
    data = receiver.receive()
    if data is not None:
        displayer.update(data)
```

テスト用ツール
--------------
リポジトリ内にテスト用スクリプトや UE5 サンプルがある場合、それらを使って送信側を模擬できます。ルートにある `test_ue5_image_sender.py` や `UE5_Sample` ディレクトリを参照してください（利用方法はそれぞれの README を確認してください）。

今後の改善案
-------------
- 受信プロトコルのバージョン管理（ヘッダやメタデータを付与して柔軟にする）
- 画像フォーマット（例: HWC / CHW / BGR / RGB）の自動検知と柔軟対応
- 受信画像をログとしてファイル保存するオプション
- Web ベースのビューア (WebSocket 経由でブラウザに画像を送る)

変更履歴
--------
- README 作成日: 2025-09-02

ライセンス / コントリビュート
----------------------------
本プロジェクトはリポジトリのルートにあるライセンス表記に従ってください。修正を行う場合は git commit & push を行ってください（.clinerules に「何等かの修正を加えたら、git commit & push をお願いします。」とあります）。
