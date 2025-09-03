# UE5Com プロジェクト

## 概要

このリポジトリは、Unreal Engine 5 (UE5) を中心に、MATLAB/Simulink、Pythonといった外部アプリケーションとリアルタイムで連携するための通信基盤およびサンプルプロジェクトです。
中核技術として **ZeroMQ (ØMQ)** を採用し、異なるプロセス間で画像データや制御信号を効率的に送受信する仕組みを提供します。

## プロジェクト構成

このリポジトリは、以下の主要なコンポーネントで構成されています。

- **`UE5Com/`**: Unreal Engine 5のメインプロジェクトです。
  - **`Plugins/ZeroMQCommunication/`**: UE5と外部アプリケーション間のZeroMQ通信を担うプラグインです。
- **`PythonHub/`**: UE5とMATLAB/Simulink間の通信を中継するPython製のZeroMQハブサーバーです。
- **`MATLAB_Image_Processing/`**: ZeroMQを介して画像を受信し、画像処理を行うMATLABネイティブライブラリです。
- **`Simulink_Image_Processing/`**: 同様の機能をSimulinkで実現するためのS-Functionブロックライブラリです。
- **`Python_Image_Processing/`**: 同様の機能をPythonで実装したライブラリです。

## 各コンポーネントの概要と使い方

### 1. UE5Com - Unreal Engine 5 プロジェクト

UE5側のメインプロジェクトです。`UE5Com.uproject` を開いてプロジェクトを起動します。

#### `Plugins/ZeroMQCommunication`

このプラグインは、UE5内でZeroMQ通信を行うための機能を提供します。
- **画像送信**: UE5内のカメラから取得した映像を、指定したアドレスとトピックで外部に送信します。
- **制御受信**: 外部から送信された制御コマンド（アクターの位置や回転など）を受信し、UE5内のアクターに適用します。

**別プロジェクトへの提供方法:**

1. このリポジトリの `UE5Com/Plugins/ZeroMQCommunication` ディレクトリを、対象のUE5プロジェクトの `Plugins` ディレクトリにコピーします(存在しなければ、同名のフォルダを新規に作成ください)。
2. UE5エディタを起動し、メニューの `編集 > プラグイン` から `ZeroMQCommunication` を検索し、有効化します。
3. エディタを再起動すると、プラグインが利用可能になります。

詳細な設定や使い方については、プラグイン内のドキュメントやソースコードを参照してください。

### 2. PythonHub - ZeroMQハブサーバー

UE5とMATLAB/Simulink間の通信を中継する役割を担います。各アプリケーション間の接続情報を一元管理し、メッセージのルーティングを行います。

**主な機能:**
- UE5からの画像データを受信し、MATLAB/Simulinkへ転送
- MATLAB/Simulinkからの制御コマンドを受信し、UE5へ転送

使い方や設定方法の詳細は、`PythonHub/README.md` を参照してください。

### 3. MATLAB/Simulink/Python 画像処理ライブラリ

UE5から送信された画像データを受信し、画像処理を行うためのライブラリ群です。それぞれMATLAB、Simulink、Pythonのネイティブ環境で動作します。

- **`MATLAB_Image_Processing/`**: MATLABスクリプトベースのライブラリ。
- **`Simulink_Image_Processing/`**: Simulinkモデルで使用できるブロックライブラリ。
- **`Python_Image_Processing/`**: Pythonスクリプトベースのライブラリ。

各ライブラリには、ZeroMQ通信、画像特徴抽出、リアルタイム表示などの機能が含まれています。
セットアップ方法やAPIの詳細については、各ディレクトリ内の `README.md` を参照してください。

## ワークフローの例

1. `PythonHub` サーバーを起動します。
2. `UE5Com` プロジェクトを実行し、`ZeroMQCommunication` プラグインを介して `PythonHub` に接続します。
3. `MATLAB_Image_Processing` または `Simulink_Image_Processing` を起動し、`PythonHub` に接続します。
4. UE5から送信されたカメラ映像が `PythonHub` を経由してMATLAB/Simulinkで受信され、リアルタイムで表示・処理されます。
5. MATLAB/Simulinkから送信された制御信号が `PythonHub` を経由してUE5に送られ、UE5内のアクターが制御されます。
