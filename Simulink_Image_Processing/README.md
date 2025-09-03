# MATLAB/Simulink Integration for UE5PyCom

## 概要

このディレクトリには、Unreal Engine 5、Python、およびSimulinkを連携させるためのMATLAB/Simulink関連のファイルが含まれています。
通信の中核として **ZeroMQ (ZMQ)** を利用し、外部アプリケーションとの間で画像や制御信号をリアルタイムに送受信するためのSimulink S-Functionブロックとその関連ファイルを提供します。

**ZeroMQとは:**
ZeroMQは、高性能な非同期メッセージングライブラリです。ソケットベースのAPIを提供し、プロセス間、マシン間、ネットワーク間での高速なデータ交換を可能にします。このプロジェクトでは、Publish-Subscribe (PUB/SUB) パターンを利用して、Simulinkと他のアプリケーション（PythonスクリプトやUE5など）間で効率的にデータをやり取りしています。

## フォルダ構成

-   `c_src/`: C++で実装されたS-Functionのソースコード (`.cpp`)
-   `m_src/`: MATLABスクリプトで実装されたS-Functionのソースコード (`.m`)
-   `mask/`: Simulinkブロックのユーザーインターフェース（マスク）を定義するスクリプト
-   `help/`: 各Simulinkブロックのヘルプとして表示されるHTMLファイル
-   `ThirdParty/`: ZeroMQライブラリなど、外部の依存ファイル
-   `slblocks.m`: Simulinkライブラリブラウザにカスタムライブラリを登録するための設定ファイル
-   `startup.m`: MATLAB起動時にこのプロジェクトに必要なパスを自動で設定するスクリプト
-   `build_sfunctions.m`: C++ S-Functionをコンパイル（ビルド）するためのスクリプト
-   `zeromq_image_lib.slx`: プロジェクトで提供されるS-FunctionブロックをまとめたSimulinkライブラリ
-   `Image_Processing_Test.slx`: ライブラリの使用方法を示すサンプルモデル

## セットアップ手順

### 1. 前提条件
- MATLAB R2023a 以降
- Simulink
- サポートされているC++コンパイラ (MinGW64 または Visual Studio 2019 以降)
  - MATLABで `mex -setup C++` を実行して設定してください。

### 2. 初期設定（初回のみ）
このプロジェクトを使用するための環境を自動でセットアップします。

1.  **PowerShellを管理者として実行**
    - Windowsのスタートメニューで「PowerShell」と検索し、「Windows PowerShell」を右クリックして **「管理者として実行」** を選択します。

2.  **セットアップスクリプトの実行**
    - PowerShellで、この `Simulink_Image_Processing` ディレクトリに移動します。
      ```powershell
      cd "D:\path\to\your\project\Simulink_Image_Processing" 
      ```
      (※ `D:\path\to\your\project` の部分は実際のパスに置き換えてください)
    - 次に、以下のコマンドを実行してセットアップスクリプトを開始します。
      ```powershell
      .\setup_environment.ps1
      ```
    - このスクリプトは以下の処理を自動的に行います。
        - Pythonの実行環境のセットアップ
        - 必要なPythonライブラリ (pyzmq, numpy, opencv-python) のインストール
        - ZeroMQライブラリの接続テスト
        - MATLABのPython環境設定

### 3. C++ S-Functionのビルド
この手順は、初回セットアップ後、またはC++ソースコード (`c_src/` 内のファイル) に変更があった場合に実行してください。

1.  **MATLABを起動**
    - この `Simulink_Image_Processing` ディレクトリをカレントディレクトリとしてMATLABを起動します。
2.  **ビルドスクリプトの実行**
    - MATLABのコマンドウィンドウで以下のコマンドを実行します。
      ```matlab
      build_sfunctions
      ```
    - これにより、C++で書かれたS-Functionがコンパイルされ、Simulinkで使用できるようになります。

### 4. Simulinkライブラリの使用
セットアップ完了後、MATLABを再起動してください。
Simulinkライブラリブラウザを開くと、**"ZeroMQ Image Lib"** という名前のライブラリが表示されます。ここからブロックをモデルにドラッグ＆ドロップして使用できます。

## ライブラリ (`zeromq_image_lib.slx`) の内容

このライブラリには、以下の主要なSimulinkブロックが含まれています。

-   **ZeroMQ Image Receiver**: 外部からZeroMQ経由で送信された画像データを受信します。
-   **ZeroMQ Control Sender**: Simulinkモデル内の制御信号を外部に送信します。
-   **Image Display**: 受信した画像データをSimulinkシミュレーション中にリアルタイムで表示します。
-   **Image Feature Extraction**: 画像から特徴点などを抽出します。

各ブロックのダイアログにある **[ヘルプ]** ボタンをクリックすると、パラメータや使用方法に関する詳細なドキュメント（HTML）が表示されます。
