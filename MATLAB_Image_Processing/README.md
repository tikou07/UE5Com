# MATLAB 画像処理ライブラリ

## 概要

このディレクトリには、ZeroMQを介した画像の受信と制御信号の送信を行うためのMATLAB関数ライブラリが含まれています。

ZeroMQライブラリは、ビルドスクリプト実行時に各環境のC++コンパイラに合わせてソースコードから自動的にビルドされるため、コンパイラのバージョン互換性の問題を気にする必要はありません。

## セットアップとビルド手順

### 1. 前提条件
- MATLAB R2023a 以降
- サポートされているC++コンパイラ (MinGW64 または Visual Studio 2019 以降)
  - MATLABを起動し、コマンドウィンドウで `mex -setup C++` を実行して、使用するコンパイラが正しく設定されていることを確認してください。

### 2. Gitサブモジュールの初期化 (初回のみ)
リポジトリをクローンした後、ZeroMQのソースコードを取得するためにGitサブモジュールを初期化する必要があります。プロジェクトのルートディレクトリで以下のコマンドを実行してください。
```bash
git submodule update --init --recursive
```

### 3. ビルドの実行 (初回のみ)
このプロジェクトのセットアップとビルドは、単一のPowerShellスクリプトで完結します。

1.  **PowerShellを管理者として実行**
    - Windowsのスタートメニューで「PowerShell」と検索し、「Windows PowerShell」を右クリックして **「管理者として実行」** を選択します。

2.  **ビルドスクリプトの実行**
    - 管理者として開いたPowerShellで、この `MATLAB_Image_Processing` ディレクトリに移動します。
      ```powershell
      cd "D:\path\to\your\project\MATLAB_Image_Processing" 
      ```
      (※ `D:\path\to\your\project` の部分は実際のパスに置き換えてください)
    - 次に、以下のコマンドを実行してビルドスクリプトを開始します。
      ```powershell
      PowerShell -ExecutionPolicy Bypass -File .\build.ps1
      ```
    - このスクリプトは、依存関係のセットアップ（Python, CMake）からZeroMQライブラリのビルド、MEXファイルのコンパイルまで、すべてのプロセスを自動的に実行します。初回実行時は完了までに数分かかる場合があります。

`mex` ディレクトリ内に `mex_zeromq_handler.mexw64` のようなファイルが生成されていれば成功です。

### 4. 動作確認
MATLABを（通常モードで）起動し、`startup` スクリプトを実行してプロジェクトのパスを設定した後、`run_image_processing_test.m` を実行してセットアップが正しく完了したかを確認できます。
```matlab
startup
run_image_processing_test
