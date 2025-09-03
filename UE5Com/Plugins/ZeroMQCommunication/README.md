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

### 2. プロジェクトのビルド

C++プロジェクトの場合、Visual Studioでプロジェクトのソリューションファイルを開き、ビルドを実行してください。これにより、プラグインがプロジェクトに組み込まれます。

### 3. プラグインの有効化

UE5エディタを起動し、メニューの `編集` > `プラグイン` を開きます。検索バーに `ZeroMQ` と入力し、`ZeroMQ Communication` プラグインを有効にします。エディタの再起動を求められた場合は、指示に従ってください。

## 使用方法

本プラグインの主要な機能は、シーンに配置したアクターの詳細パネルから設定できます。

### 1. カメラ映像の送信 (`AZeroMQCameraActor`)

`AZeroMQCameraActor` をシーンに配置すると、詳細パネルに以下の設定項目が表示されます。

-   **ZeroMQ Camera**
    -   `Camera ID`: 外部アプリケーションがこのカメラを識別するための一意のIDです。
    -   `Auto Register`: ゲーム開始時に自動で通信サブシステムに登録するかどうか。
    -   `Enable Image Capture`: 映像のキャプチャと送信を有効にするか。
    -   `Image Capture Interval`: 映像をキャプチャする間隔（秒）。`1.0` の場合、1秒に1回キャプチャします。
    -   `Capture Resolution`: キャプチャする映像の解像度（幅 x 高さ）。
    -   `Image Format`: `Color`（カラー）または `Grayscale`（グレースケール）を選択できます。
    -   `Grayscale Coefficients`: グレースケール変換に使用するRGBの係数です。

-   **ZeroMQ Connection**
    -   `Image Port`: 映像データを送信するためのポート番号。
    -   `Image Bind Mode`: `True` の場合、UE5側がサーバー（Bind）となり、外部アプリケーションからの接続を待ち受けます。`False` の場合、UE5側がクライアント（Connect）として外部サーバーに接続します。

### 2. アクターの制御 (`UZeroMQReceiverComponent`)

任意のアクターに `ZeroMQReceiverComponent` を追加すると、詳細パネルに以下の設定項目が表示されます。

-   **ZeroMQ Connection**
    -   `Server IP`: 接続先の外部アプリケーションのIPアドレス。
    -   `Port`: 制御コマンドを受信するためのポート番号。

コンポーネントを追加した後、アクターのイベントグラフで `On Transform Received` イベントを使用することで、受信したデータに基づいてアクターを制御できます。このイベントは、外部から制御コマンドを受信するたびにトリガーされ、`Transform` データ（位置、回転、カメラID）を出力します。

### 3. ブループリントによる高度な制御

`UZeroMQCommunicationSubsystem` をブループリントから直接操作することも可能です。これにより、実行中に動的に設定を変更したり、接続を開始・停止したりといった高度な制御が実現できます。

-   **Get Game Instance Subsystem**: ノードを使い `ZeroMQ Communication Subsystem` のインスタンスを取得します。
-   **Update Settings**: `FZeroMQSettings` 構造体を作成し、IPアドレス、各種ポート、解像度などを設定してこの関数に渡すことで、通信設定を更新できます。
-   **Start Connection / Stop Connection**: これらの関数を呼び出すことで、任意のタイミングで通信を開始・停止できます。

## フォルダ構成

```
ZeroMQCommunication/
├── Binaries/               # コンパイルされたバイナリファイル
├── Content/                # プラグイン固有のコンテンツ（ブループリントなど）
├── Intermediate/           # ビルド時の中間ファイル
├── Source/
│   └── ZeroMQCommunication/
│       ├── Private/        # .cpp ファイル（実装）
│       │   ├── ZeroMQCameraActor.cpp
│       │   ├── ZeroMQCommunication.cpp
│       │   ├── ZeroMQCommunicationSubsystem.cpp
│       │   ├── ZeroMQControlledActor.cpp
│       │   ├── ZeroMQReceiverComponent.cpp
│       │   └── ... (Worker thread implementations)
│       ├── Public/         # .h ファイル（公開API）
│       │   ├── ZeroMQCameraActor.h
│       │   ├── ZeroMQCommunication.h
│       │   ├── ZeroMQCommunicationSubsystem.h
│       │   ├── ZeroMQControlledActor.h
│       │   └── ZeroMQReceiverComponent.h
│       └── ThirdParty/     # 外部ライブラリ（ZeroMQ）
└── ZeroMQCommunication.uplugin # プラグイン情報ファイル
```

## モジュール設計

### ZeroMQ (サードパーティライブラリ)

-   本プラグインの中核をなす、高性能な非同期メッセージングライブラリです。
-   TCPプロトコル上で、PUB-SUB（出版-購読）、REQ-REP（要求-応答）などの様々な通信パターンをサポートします。
-   本プラグインでは、主にPUB-SUBパターンを利用して、UE5からの映像データ（PUB）と、外部アプリケーションからの制御データ（SUB）の送受信を行っています。

### 主要クラス

-   **`UZeroMQCommunicationSubsystem`**:
    -   プラグイン全体の管理を行うシングルトンクラス（`GameInstanceSubsystem`として実装）。
    -   ZeroMQのコンテキストとソケットの初期化・破棄を担当します。
    -   `AZeroMQCameraActor` の登録・解除を行い、各カメラからの映像送信を管理します。
    -   通信設定（IP、ポートなど）を保持し、接続の開始・停止を制御します。
    -   バックグラウンドスレッド (`FZeroMQWorkerThread`) を生成し、ZeroMQのブロッキング処理がゲームスレッドに影響を与えないように設計されています。

-   **`AZeroMQCameraActor`**:
    -   シーンに配置可能なカメラアクター。
    -   `SceneCaptureComponent2D` を内包し、指定された解像度でシーンをキャプチャします。
    -   キャプチャした映像 (`UTextureRenderTarget2D`) をJPEG形式に変換し、`UZeroMQCommunicationSubsystem` を介して送信します。

-   **`UZeroMQReceiverComponent`**:
    -   任意のアクターに追加可能なコンポーネント。
    -   外部アプリケーションから送信される制御コマンドを受信するための専用のZeroMQソケット（SUB）を持ちます。
    -   受信したデータをパースし、`FCameraTransform` 構造体に変換後、`OnTransformReceived` デリゲートをブロードキャストします。

-   **`AZeroMQControlledActor`**:
    -   `UZeroMQReceiverComponent` を使用したアクターのサンプル実装。
    -   `OnTransformReceived` イベントを購読し、受信したトランスフォーム情報に基づいて自身を動かします。

-   **`FZeroMQWorkerThread` / `FZeroMQReceiverWorker`**:
    -   ZeroMQの通信処理をバックグラウンドで実行するためのワーカースレッドクラス。
    -   これにより、ソケットの待機（ブロッキング）処理がUE5のメインスレッド（ゲームループ）を妨げることなく、スムーズな通信が可能になります。
