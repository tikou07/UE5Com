# ZeroMQ Communication Plugin for Unreal Engine 5

## 概要

このプラグインは、Unreal Engine 5 (UE5) と外部アプリケーション（Python, MATLAB, Simulinkなど）との間で、ZeroMQを利用した高速な非同期通信を実現するためのものです。特に、カメラ映像の送信やアクターの制御といった、リアルタイム性が要求されるデータ交換に最適化されています。

## 主な機能

-   **ZeroMQによる通信**: 高速かつ軽量な非同期メッセージングライブラリであるZeroMQを使用し、UE5と外部アプリケーション間での効率的なデータ交換を実現します。
-   **カメラ映像の送信**: UE5内のカメラが捉えた映像を、指定された解像度とフレームレートで外部アプリケーションにリアルタイムで送信します。
-   **アクターの制御**: 外部アプリケーションから送信されたコマンドに基づき、UE5内のアクター（キャラクターやオブジェクトなど）の位置や回転を制御します。
-   **柔軟な接続設定**: 通信ポートやサーバーIP、映像の解像度などをブループリントから容易に設定・変更できます。
-   **マルチカメラ対応**: 複数のカメラアクターを個別に登録し、それぞれの映像を独立して送信・管理できます。

## 導入方法

### 1. プラグインの配置

本プラグイン (`ZeroMQCommunication`) フォルダを、導入したいUE5プロジェクトの `Plugins` フォルダにコピーします。`Plugins` フォルダが存在しない場合は、プロジェクトのルートディレクトリ（`.uproject` ファイルがある場所）に作成してください。

```
MyProject/
├── Content/
├── Config/
├── Source/
├── MyProject.uproject
└── Plugins/
    └── ZeroMQCommunication/
        ├── ...
        └── ZeroMQCommunication.uplugin
```

### 2. ZeroMQライブラリの準備

本プラグインをビルド・使用するには、ZeroMQライブラリが必要です。

-   **Windows**:
    必要なライブラリ (`.lib`, `.dll`) は `Source/ZeroMQCommunication/ThirdParty/ZeroMQ/` に同梱済みのため、追加の作業は不要です。
    
    もしご自身でライブラリを再ビルドしたい場合は、[vcpkg](https://github.com/microsoft/vcpkg) などのパッケージマネージャを使用するのが簡単です。
    ```bash
    # vcpkgをインストール後
    vcpkg install zeromq:x64-windows-static
    ```
    生成された `lib` と `dll`、そして `include` フォルダを `ThirdParty/ZeroMQ` 以下の対応するディレクトリに配置してください。

-   **Linux / Mac**:
    ビルドを行うには、対象プラットフォーム用にコンパイルされたZeroMQのスタティックライブラリ (`libzmq.a`) をご自身で用意し、以下の場所に配置する必要があります。
    
    -   **Linux**: `Source/ZeroMQCommunication/ThirdParty/ZeroMQ/lib/Linux/libzmq.a`
    -   **Mac**: `Source/ZeroMQCommunication/ThirdParty/ZeroMQ/lib/Mac/libzmq.a`

    ライブラリは、各OSのパッケージマネージャを使ってインストールするか、[ZeroMQの公式サイト](https://zeromq.org/download/) からソースコードをダウンロードしてビルドすることができます。

    **Linux (Ubuntu/Debian) でのビルド例:**
    ```bash
    sudo apt-get install libtool pkg-config build-essential autoconf automake
    wget https://github.com/zeromq/libzmq/releases/download/v4.3.5/zeromq-4.3.5.tar.gz
    tar -xvf zeromq-4.3.5.tar.gz
    cd zeromq-4.3.5
    ./configure
    make
    sudo make install
    # 生成された libzmq.a を所定の場所にコピー
    ```

### 3. プロジェクトのビルド

C++プロジェクトの場合、Visual Studioでプロジェクトのソリューションファイルを開き、ビルドを実行してください。これにより、プラグインがプロジェクトに組み込まれます。

### 4. プラグインの有効化

UE5エディタを起動し、メニューの `編集` > `プラグイン` を開きます。検索バーに `ZeroMQ` と入力し、`ZeroMQ Communication` プラグインを有効にします。エディタの再起動を求められた場合は、指示に従ってください。

## 使用方法

（...既存の使用方法セクションは変更なし...）

## モジュール設計

### ZeroMQ (サードパーティライブラリ)

-   本プラグインの中核をなす、高性能な非同期メッセージングライブラリです。
-   TCPプロトコル上で、PUB-SUB（出版-購読）、REQ-REP（要求-応答）などの様々な通信パターンをサポートします。
-   本プラグインでは、主にPUB-SUBパターンを利用して、UE5からの映像データ（PUB）と、外部アプリケーションからの制御データ（SUB）の送受信を行っています。

### 通信プロトコルについて

-   **TCP/IP**: このプラグインは、ネットワークを介した安定した通信を実現するため、`TCP/IP` プロトコルを使用しています。接続文字列は、ブループリントやC++で設定されたIPアドレスとポート番号に基づき、内部的に `tcp://<IPアドレス>:<ポート番号>` の形式で構築されます。
-   **その他のプロトコル**: ZeroMQは `inproc` (同一プロセス内スレッド間通信) や `ipc` (プロセス間通信) など、他の高速な通信プロトコルもサポートしていますが、本プラグインの現在の実装では `TCP/IP` のみを利用しています。

### 主要クラス

（...既存の主要クラスセクションは変更なし...）

## プラグインのパッケージ化

このプラグインを他のプロジェクトで簡単に利用できるように、配布可能なパッケージを作成するためのPowerShellスクリプトを用意しています。

### 手順

1.  **`PackagePlugin.ps1` を編集 (初回のみ)**:
    *   プラグインのルートディレクトリにある `PackagePlugin.ps1` をテキストエディタで開きます。
    *   `$UeEnginePath = "C:\Program Files\Epic Games\UE_5.3\Engine"` の行を、ご自身のUnreal Engineのインストールパスに合わせて修正し、保存します。

2.  **スクリプトの実行**:
    *   PowerShellを開き、`cd` コマンドでこのプラグインのディレクトリに移動します。
    *   以下のコマンドを実行します。
        ```powershell
        powershell -ExecutionPolicy Bypass -File .\PackagePlugin.ps1
        ```

3.  **完了**:
    *   ビルドと必須DLLのコピーが自動的に実行されます。
    *   完了すると、`Package` フォルダ内に `ZeroMQCommunication` フォルダが作成されます。このフォルダが、配布可能なプラグイン本体です。
    *   この `ZeroMQCommunication` フォルダを、導入したい他のプロジェクトの `Plugins` フォルダにコピーすることで、プラグインを利用できます。
