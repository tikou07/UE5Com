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

## セットアップとビルド手順

### 1. 前提条件
- MATLAB R2023a 以降
- Simulink
- サポートされているC++コンパイラ (MinGW64 または Visual Studio 2019 以降)
  - MATLABを起動し、コマンドウィンドウで `mex -setup C++` を実行して、使用するコンパイラが正しく設定されていることを確認してください。

### 2. ビルドの実行 (初回のみ)
このプロジェクトのセットアップとビルドは、`build.bat` を実行するだけで完結します。

1.  **`build.bat` を実行**
    - `Simulink_Image_Processing` ディレクトリにある `build.bat` ファイルをダブルクリックして実行します。
    - ユーザーアカウント制御(UAC)のプロンプトが表示されたら「はい」をクリックして、管理者権限を許可してください。

2.  **自動処理の待機**
    - スクリプトが、Git、CMake、Python環境など、ビルドに必要な依存関係をすべて自動でセットアップします。
    - 最終的にZeroMQライブラリのビルドとS-Functionのコンパイルが行われます。
    - 初回実行時は完了までに数分かかる場合があります。完了すると、コンソールに「Press any key to continue...」と表示されます。
    - ビルドに失敗した場合は、`build_log.txt` を確認してください。

### 3. Python環境について
`build.bat` は、S-Functionのビルドプロセスに加え、一部のブロック（Image Feature Extractionなど）で使用されるPython環境のセットアップも行います。

- **管理方法:** Python環境は、高速なパッケージインストーラ `uv` を用いて管理されます。必要なライブラリは `pyproject.toml` ファイルの `[project.dependencies]` セクションで定義されています。
- **ライブラリの更新:** 依存ライブラリを変更・追加・削除したい場合は、`pyproject.toml` を直接編集してください。編集後、再度 `build.bat` を実行すると、`.venv` 仮想環境が `pyproject.toml` の内容と厳密に同期されます。コマンドラインから手動で更新する場合は `uv sync` を実行します。

### 4. Simulinkライブラリの使用
セットアップ完了後、MATLABを起動し、`startup.m` を実行してください。
Simulinkライブラリブラウザを開くと、**"ZeroMQ Image Lib"** という名前のライブラリが表示されます。ここからブロックをモデルにドラッグ＆ドロップして使用できます。
`Image_Processing_Test.slx` がサンプルモデルとして含まれています。

## ライブラリ (`zeromq_image_lib.slx`) の内容

このライブラリには、以下の主要なSimulinkブロックが含まれています。

-   **ZeroMQ Image Receiver**: 外部からZeroMQ経由で送信された画像データを受信します。
-   **ZeroMQ Control Sender**: Simulinkモデル内の制御信号を外部に送信します。
-   **Image Display**: 受信した画像データをSimulinkシミュレーション中にリアルタイムで表示します。
-   **Image Feature Extraction**: 画像から特徴点などを抽出します。

各ブロックのダイアログにある **[ヘルプ]** ボタンをクリックすると、パラメータや使用方法に関する詳細なドキュメント（HTML）が表示されます。
