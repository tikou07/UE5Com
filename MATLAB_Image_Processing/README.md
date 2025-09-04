# MATLAB 画像処理ライブラリ

## ZeroMQについて

ZeroMQ（ØMQ）は、高性能な非同期メッセージングライブラリです。ソケットベースのAPIを提供し、異なるプロセスやネットワークノード間で効率的にデータを交換することができます。本プロジェクトでは、Unreal Engine 5、Pythonハブ、MATLABといった異なるコンポーネント間を連携させるための通信基盤として利用しています。特に、PUB-SUB（Publish-Subscribe）パターンを使用することで、画像のような大容量データをリアルタイムに配信したり、制御信号を複数のサブスクライバーに効率的にブロードキャストしたりすることが可能になります。

このディレクトリには、ZeroMQを介した画像の受信と制御信号の送信を行うためのMATLAB関数ライブラリが含まれています。これは `Simulink_Image_Processing` ディレクトリにあるコンポーネントのMATLABネイティブ版です。

## 機能

- **ZeroMQ通信**:
  - `ZMQ.ZeroMQImageReceiver`: ZeroMQのPUBソケットから画像を受信します。
  - `ZMQ.ZeroMQControlSender`: ZeroMQのSUBソケットに制御コマンド（JSON形式）を送信します。
- **画像特徴抽出**:
  - `Features.ImageFeatureExtractor`: 画像から特徴を抽出するクラスです。
- **可視化**:
  - `Utils.ImageDisplayer`: MATLABのFigureウィンドウにリアルタイムで画像を表示するユーティリティクラスです。

## セットアップ手順

### 1. 前提条件
- MATLAB R2023a 以降
- サポートされているC++コンパイラ (MinGW64 または Visual Studio 2019 以降)
  - MATLABで `mex -setup C++` を実行して設定を確認してください。

### 2. Python環境のセットアップ (初回のみ)
このプロジェクトには、画像処理機能で使用するPythonの実行環境が含まれています。必要なライブラリをインストールするために、以下のスクリプトを実行します。

1.  **PowerShellを管理者として実行**
    - Windowsのスタートメニューで「PowerShell」と検索し、「Windows PowerShell」を右クリックして **「管理者として実行」** を選択します。

2.  **セットアップスクリプトの実行**
    - PowerShellで、この `MATLAB_Image_Processing` ディレクトリに移動します。
      ```powershell
      cd "D:\path\to\your\project\MATLAB_Image_Processing" 
      ```
      (※ `D:\path\to\your\project` の部分は実際のパスに置き換えてください)
    - 次に、以下のコマンドを実行してセットアップスクリプトを開始します。
      ```powershell
      .\setup_environment.ps1
      ```
    - このスクリプトは、Visual C++ 再頒布可能パッケージのインストール（必要に応じて）と、`python_runtime` ディレクトリへのPythonライブラリ (pyzmq, numpy, opencv-python) のインストールを自動的に行います。

#### PowerShellスクリプトの実行エラー

`setup_environment.ps1` を実行する際に、以下のようなセキュリティエラーが表示される場合があります。

```
.\setup_environment.ps1 : このシステムではスクリプトの実行が無効になっているため...
```

これは、PowerShellの実行ポリシーによってスクリプトの実行がブロックされていることが原因です。
この問題を解決するには、PowerShellで以下のコマンドを実行してください。これにより、一時的に実行ポリシーを回避してスクリプトを実行できます。

```powershell
PowerShell -ExecutionPolicy Bypass -File .\setup_environment.ps1
```

### 3. MATLAB環境の設定
MATLABを起動し、`MATLAB_Image_Processing` ディレクトリをカレントディレクトリに設定してください。

### 4. MEXファイルのビルド (初回のみ)
ZeroMQ通信を高速化するためのC++ MEX関数をコンパイルします。この手順は、初回セットアップ時またはC++ソースコードに変更があった場合にのみ必要です。

`build_mex_files` スクリプトは、MATLABで選択されているC++コンパイラ（MinGWまたはVisual Studio）を自動的に検出し、適切なライブラリをリンクします。このリポジトリには両方のコンパイラ用のZeroMQライブラリが同梱されているため、追加のインストール作業は不要です。

1.  **MATLABのコマンドウィンドウで、以下のコマンドを実行します。**
    ```matlab
    build_mex_files
    ```
2.  **ビルドの確認**
    - `mex` ディレクトリ内に `mex_zeromq_handler.mexw64` のようなファイルが生成されていれば成功です。

### 5. 動作確認
`startup` スクリプトを実行してプロジェクトのパスを設定した後、`run_image_processing_test.m` を実行してセットアップが正しく完了したかを確認できます。
```matlab
startup
run_image_processing_test
```

## API詳細

### `ZMQ.ZeroMQImageReceiver`

ZeroMQ経由で画像データを受信するためのクラスです。

#### コンストラクタ: `receiver = ZMQ.ZeroMQImageReceiver(address, topic, Name, Value)`

- **処理内容**: SUBソケットを初期化し、指定されたアドレスに接続またはバインドして、トピックを購読します。
- **引数**:
  - `address` (char): 接続またはバインドするZeroMQソケットのアドレス (例: `'tcp://localhost:5555'`)。
  - `topic` (char): 購読するトピック名 (例: `'Camera01'`)。
- **名前と値のペアの引数**:
  - `'BindMode'` (logical): `true`でバインド、`false`で接続（デフォルト: `false`）。
  - `'Timeout'` (numeric): 受信タイムアウト（ミリ秒）（デフォルト: `100`）。
  - `'ImageHeight'`, `'ImageWidth'`, `'Channels'`: 期待する画像の高さ、幅、チャンネル数。

#### メソッド: `imageData = receiver.receive()`

- **処理内容**: ソケットから画像データを受信し、MATLABの行列形式に再構成します。
- **返り値**:
  - `imageData` (uint8行列): `[H x W x C]` の画像データ。タイムアウトした場合は空配列 `[]`。

### `ZMQ.ZeroMQControlSender`

ZeroMQ経由で制御コマンドを送信するためのクラスです。

#### コンストラクタ: `sender = ZMQ.ZeroMQControlSender(address)`

- **処理内容**: PUBソケットを初期化し、指定されたアドレスにバインドします。
- **引数**:
  - `address` (char): バインドするZeroMQソケットのアドレス (例: `'tcp://*:5556'`)。

#### メソッド: `sender.sendTransform(target_id, location, rotation)`

- **処理内容**: 位置と回転の情報をJSON形式で送信します。
- **引数**:
  - `target_id` (char): 制御対象のアクターID。
  - `location` (numericベクトル): `[x, y, z]` の3要素ベクトル。
  - `rotation` (numericベクトル): `[roll, pitch, yaw]` の3要素ベクトル。

### `Features.ImageFeatureExtractor`

画像から特徴量を抽出するためのクラスです。

#### コンストラクタ: `extractor = Features.ImageFeatureExtractor(mode, Name, Value)`

- **処理内容**: 指定されたモードで特徴抽出器を初期化します。
- **引数**:
  - `mode` (char): `'ORB'` または `'Centroid'`。
- **名前と値のペアの引数**:
  - `'MaxFeatures'` (numeric): 'ORB'モードでの最大特徴点数（デフォルト: `500`）。
  - `'Threshold'` (numeric): 'Centroid'モードでの二値化しきい値（デフォルト: `127`）。

#### メソッド: `[processedImage, features] = extractor.extract(image)`

- **処理内容**: 入力画像から特徴量を抽出し、結果を可視化した画像を生成します。
- **引数**:
  - `image` (uint8行列): `[H x W x C]` の入力画像。
- **返り値**:
  - `processedImage` (uint8行列): 特徴点を描画した出力画像。
  - `features` (numeric行列): 検出された特徴量のデータ。

### `Utils.ImageDisplayer`

画像をリアルタイムで表示するためのクラスです。

#### コンストラクタ: `displayer = Utils.ImageDisplayer(height, width, channels, Name, Value)`

- **処理内容**: 画像表示用のFigureウィンドウを生成します。
- **引数**:
  - `height`, `width`, `channels`: 表示する画像の高さ、幅、チャンネル数。
- **名前と値のペアの引数**:
  - `'Title'` (char): Figureウィンドウのタイトル。

#### メソッド: `displayer.update(imageData)`

- **処理内容**: Figureウィンドウの表示を更新します。
- **引数**:
  - `imageData` (uint8行列またはベクトル): 表示する画像データ。
