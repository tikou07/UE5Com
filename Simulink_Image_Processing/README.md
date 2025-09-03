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

## セットアップと使い方

### 1. MATLABの起動

**重要:** このプロジェクトを使用する際は、必ずこの `Simulink_Image_Processing` ディレクトリをMATLABのカレントディレクトリとして起動してください。

### 2. 初期設定（初回のみ）

M-file S-Function (`_m` が末尾につくブロック) を使用するには、Pythonとの連携設定が必要です。以下の手順に従ってください。

1.  **PowerShellを開く:**
    *   Windowsのスタートメニューで「PowerShell」と検索し、「Windows PowerShell」を **管理者として実行** します。

2.  **実行ポリシーの変更 (必要な場合):**
    *   PowerShellでスクリプトが実行できない場合、実行ポリシーの変更が必要なことがあります。以下のコマンドを実行して、一時的に実行を許可してください。
      ```powershell
      Set-ExecutionPolicy RemoteSigned -Scope Process
      ```

3.  **スクリプトの実行:**
    *   PowerShellで、この `Simulink_Image_Processing` ディレクトリに移動します。
      ```powershell
      cd "D:\XXX...\Simulink_Image_Processing"
      ```
      ※XXX...はSimulink_Image_Processingが置いてあるパス
    *   以下の2つのスクリプトを順番に実行します。
      ```powershell
      # Python仮想環境の構築と、必要なライブラリ (pyzmq) のインストール
      .\install_python_and_venv.ps1
      
      # Visual C++ランタイムの確認とZeroMQの接続テスト
      .\install_vc_and_test.ps1
      ```

4.  **MATLABでのPython環境設定:**
    *   スクリプトの実行が成功したら、MATLABを起動し、コマンドウィンドウで以下のコマンドを実行して、プロジェクト内にインストールされたPythonをMATLABに認識させます。
      ```matlab
      pyenv("Version", "D:\XXX...\Simulink_Image_Processing\python_runtime\python.exe")
      ```
    *   この設定は一度行えば、MATLABに保存されます。
    ※XXX...はSimulink_Image_Processingが置いてあるパス

### 3. パスの自動設定

MATLABをこのディレクトリで起動すると、`startup.m` が自動的に実行され、S-Functionやライブラリの実行に必要なすべてのフォルダがMATLABのパスに設定されます。

### 4. S-Functionのコンパイル

C++で実装されたS-Functionを使用するには、事前にコンパイル（ビルド）が必要です。MATLABのコマンドウィンドウで以下のコマンドを実行してください。

```matlab
build_sfunctions
```

これにより、`c_src` 内のソースコードがコンパイルされ、`.mexw64` ファイルが生成されます。

### 5. Simulinkライブラリの使用

MATLABを再起動すると、`slblocks.m` の設定により、Simulinkライブラリブラウザのトップレベルに **"ZeroMQ Image Lib"** が自動的に追加されます。
このライブラリからブロックをドラッグ＆ドロップしてモデル内で使用できます。

-   **リンクエラーについて:** モデルを開いた際にライブラリのリンクエラーが発生する場合、`slblocks.m` が正しく機能していない可能性があります。MATLABを再起動し、カレントディレクトリが正しいことを確認してください。

## ライブラリ (`zeromq_image_lib.slx`) の内容

このライブラリには、以下の主要なSimulinkブロックが含まれています。

-   **ZeroMQ Image Receiver**: 外部からZeroMQ経由で送信された画像データを受信します。
-   **ZeroMQ Control Sender**: Simulinkモデル内の制御信号を外部に送信します。
-   **Image Display**: 受信した画像データをSimulinkシミュレーション中にリアルタイムで表示します。
-   **Image Feature Extraction**: 画像から特徴点などを抽出します。

各ブロックのダイアログにある **[ヘルプ]** ボタンをクリックすると、パラメータや使用方法に関する詳細なドキュメント（HTML）が表示されます。
