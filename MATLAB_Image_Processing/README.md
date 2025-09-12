# MATLAB 画像処理ライブラリ

## 概要

このディレクトリには、ZeroMQを介した画像の受信と制御信号の送信を行うためのMATLAB関数ライブラリが含まれています。

ZeroMQライブラリは、ビルドスクリプト実行時に各環境のC++コンパイラに合わせてソースコードから自動的にビルドされるため、コンパイラのバージョン互換性の問題を気にする必要はありません。

## セットアップとビルド手順

### 1. 前提条件
- MATLAB R2023a 以降
- サポートされているC++コンパイラ (MinGW64 または Visual Studio 2019 以降)
  - MATLABを起動し、コマンドウィンドウで `mex -setup C++` を実行して、使用するコンパイラが正しく設定されていることを確認してください。

### 2. セットアップとビルドの実行
このプロジェクトのセットアップとビルドは、2つのステップで行います。

#### ステップ1: 依存関係のセットアップ (初回のみ)
1.  **`setup.bat` を実行**
    - `MATLAB_Image_Processing` ディレクトリにある `setup.bat` ファイルをダブルクリックして実行します。
    - ユーザーアカウント制御(UAC)のプロンプトが表示されたら「はい」をクリックして、管理者権限を許可してください。

2.  **自動処理の待機**
    - スクリプトが、Git、CMake、Python環境など、ビルドに必要な依存関係をすべて自動でセットアップします。
    - 初回実行時は完了までに数分かかる場合があります。完了すると、コンソールに「Press any key to continue...」と表示されます。

#### ステップ2: MEXファイルのビルド
1.  **MATLABを起動**
    - セットアップ完了後、MATLABを起動します。

2.  **ビルドスクリプトの実行**
    - MATLABのコマンドウィンドウで、以下のコマンドを実行します。
      ```matlab
      build_mex_files
      ```
    - これにより、MEXファイルがコンパイルされます。
    - `mex` ディレクトリ内に `mex_zeromq_handler.mexw64` と、依存するDLLファイルが生成されていれば成功です。
    - ビルドに失敗した場合は、MATLABのコマンドウィンドウに表示されるエラーメッセージを確認してください。

### 3. Python環境について
`setup.bat` は、`Features.ImageFeatureExtractor` など一部の機能で使用されるPython環境のセットアップも行います。

- **管理方法:** Python環境は、高速なパッケージインストーラ `uv` を用いて管理されます。必要なライブラリは `pyproject.toml` ファイルの `[project.dependencies]` セクションで定義されています。
- **ライブラリの更新:** 依存ライブラリを変更・追加・削除したい場合は、`pyproject.toml` を直接編集してください。編集後、再度 `setup.bat` を実行すると、`.venv` 仮想環境が `pyproject.toml` の内容と厳密に同期されます。コマンドラインから手動で更新する場合は `uv sync` を実行します。

### 4. 動作確認
MATLABを（通常モードで）起動し、`startup` スクリプトを実行してプロジェクトのパスを設定した後、`run_image_processing_test.m` を実行してセットアップが正しく完了したかを確認できます。
```matlab
startup
run_image_processing_test
```

### 4. トラブルシューティング
- **ビルドの失敗:** ビルドに失敗した場合、`MATLAB_Image_Processing` ディレクトリに `build_log.txt` というログファイルが生成されます。このファイルを開き、エラーメッセージの詳細を確認してください。
- **Python環境の警告:** `startup.m` やテストスクリプトの実行時に、「MATLAB could not validate the local Python environment」のような警告が表示されることがあります。`build.bat` の実行が成功していれば、通常この警告は無視して問題ありません。MEXファイルの機能はPython環境に依存しません。

## 主要なクラスと使い方

このライブラリは、機能ごとにクラスベースで構成されています。以下に主要なクラスの概要と使用例を示します。

### 1. `ZMQ.ZeroMQImageReceiver` - 画像受信

ZeroMQのSUBソケットを介して、外部から送信される画像データを受信するためのクラスです。

-   **処理概要:** 指定されたアドレスに接続し、特定のトピックを購読します。`receive` メソッドを呼び出すと、受信した画像データをMATLABの行列として返します。
-   **コンストラクタ:** `receiver = ZMQ.ZeroMQImageReceiver(address, topic, Name, Value, ...)`
    -   `address` (char): 接続先のZeroMQアドレス (例: `'tcp://localhost:5555'`)
    -   `topic` (char): 購読するトピック名 (例: `'Camera01'`)
    -   オプション: `'ImageHeight'`, `'ImageWidth'`, `'Channels'`, `'Timeout'` など
-   **主要メソッド:** `imageData = receiver.receive()`
    -   **出力** `imageData` (uint8行列): 受信した画像データ (`高さ x 幅 x チャンネル数`)。データがない場合は空行列 `[]`。

**使用例:**
```matlab
% 'tcp://localhost:5555' から 'Camera01' トピックで画像を受信
receiver = ZMQ.ZeroMQImageReceiver('tcp://localhost:5555', 'Camera01', 'ImageHeight', 720, 'ImageWidth', 1280);

% 10フレーム受信してみる
for i = 1:10
    img = receiver.receive();
    if ~isempty(img)
        fprintf('Frame %d: Image received successfully.\n', i);
        % ... 画像処理 ...
    else
        fprintf('Frame %d: No image received.\n', i);
    end
    pause(0.1);
end

% オブジェクトをクリアして接続を閉じる
clear receiver;
```

### 2. `ZMQ.ZeroMQControlSender` - 制御信号送信

Simulinkモデル内の制御信号などを、ZeroMQのPUBソケットを介して外部に送信するためのクラスです。

-   **処理概要:** 指定されたアドレスでソケットをバインドし、`sendTransform` メソッドで制御データをJSON形式で送信します。
-   **コンストラクタ:** `sender = ZMQ.ZeroMQControlSender(address)`
    -   `address` (char): バインドするZeroMQアドレス (例: `'tcp://*:5556'`)
-   **主要メソッド:** `sender.sendTransform(target_id, location, rotation)`
    -   **入力** `target_id` (char): 操作対象のアクターID (例: `'Actor1'`)
    -   **入力** `location` (1x3 double): 位置ベクトル `[x, y, z]`
    -   **入力** `rotation` (1x3 double): 回転ベクトル `[roll, pitch, yaw]`

**使用例:**
```matlab
% 'tcp://*:5556' で制御信号を送信
sender = ZMQ.ZeroMQControlSender('tcp://*:5556');

% 'MyCamera' の位置と回転を送信
location = [100, 50, 25];
rotation = [0, -15, 90];
sender.sendTransform('MyCamera', location, rotation);

clear sender;
```

### 3. `Features.ImageFeatureExtractor` - 画像からの特徴抽出

画像から特徴点を抽出します。内部でPythonのOpenCVライブラリを呼び出して処理を実行します。

-   **処理概要:** 'ORB' または 'Centroid' の2つのモードをサポートします。'ORB'はキーポイント検出、'Centroid'は二値化後の領域の重心計算を行います。
-   **コンストラクタ:** `extractor = Features.ImageFeatureExtractor(mode, Name, Value, ...)`
    -   `mode` (char): `'ORB'` または `'Centroid'`
    -   オプション ('ORB'): `'MaxFeatures'` (最大特徴点数, デフォルト 500)
    -   オプション ('Centroid'): `'Threshold'` (二値化のしきい値, デフォルト 127)
-   **主要メソッド:** `[processedImage, features] = extractor.extract(image)`
    -   **入力** `image` (uint8行列): 入力画像
    -   **出力** `processedImage` (uint8行列): 抽出された特徴が描画された画像
    -   **出力** `features` (NxM double): 抽出された特徴データの行列。
        -   ORBモード: `N x 3` (`[x, y, response]`)
        -   Centroidモード: `N x 2` (`[x, y]`)

**使用例:**
```matlab
% ORBモードで特徴抽出器を作成
extractor = Features.ImageFeatureExtractor('ORB', 'MaxFeatures', 200);

% 画像を読み込み (imgはuint8行列と仮定)
img = imread('test_image.png'); 

% 特徴を抽出
[processedImg, features] = extractor.extract(img);

% 結果を表示
imshow(processedImg);
title(sprintf('%d ORB features found', size(features, 1)));
```

### 4. `Utils.ImageDisplayer` - 画像表示

MATLABのFigureウィンドウに画像を表示するためのユーティリティクラスです。

-   **処理概要:** 指定された解像度でFigureウィンドウを準備し、`update` メソッドで表示内容を更新します。
-   **コンストラクタ:** `displayer = Utils.ImageDisplayer(height, width, channels, Name, Value, ...)`
    -   `height` (double): 画像の高さ
    -   `width` (double): 画像の幅
    -   `channels` (double): チャンネル数 (1または3)
    -   オプション: `'Title'` (ウィンドウタイトル)
-   **主要メソッド:** `displayer.update(imageData)`
    -   **入力** `imageData` (uint8行列): 表示する画像データ

**使用例:**
```matlab
% 720pのRGB画像用のディスプレイを作成
displayer = Utils.ImageDisplayer(720, 1280, 3, 'Title', 'Live Feed');

% receiverから画像を受信して表示
for i = 1:100
    img = receiver.receive();
    if ~isempty(img)
        displayer.update(img);
    end
    drawnow; % イベントを処理
end

clear displayer; % ウィンドウを閉じる
