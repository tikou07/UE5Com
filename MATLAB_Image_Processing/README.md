# MATLAB 画像処理ライブラリ

## 概要

このディレクトリには、ZeroMQを介した画像の受信と制御信号の送信を行うためのMATLAB関数ライブラリが含まれています。

ZeroMQライブラリは、`build_mex_files.m` 実行時に各環境のC++コンパイラに合わせてソースコードから自動的にビルドされるため、コンパイラのバージョン互換性の問題を気にする必要はありません。

## セットアップ手順

### 1. 前提条件
- MATLAB R2023a 以降
- サポートされているC++コンパイラ (MinGW64 または Visual Studio 2019 以降)
  - MATLABを起動し、コマンドウィンドウで `mex -setup C++` を実行して、使用するコンパイラが正しく設定されていることを確認してください。

### 2. 環境セットアップ (初回のみ)
`setup_environment.ps1` スクリプトを実行して、ビルドに必要な依存関係（Pythonライブラリ、CMake）を自動的にインストールします。

1.  **PowerShellを開く**
    - Windowsのスタートメニューで「PowerShell」と検索し、「Windows PowerShell」を開きます。（管理者権限は通常不要です）

2.  **セットアップスクリプトの実行**
    - PowerShellで、この `MATLAB_Image_Processing` ディレクトリに移動します。
      ```powershell
      cd "D:\path\to\your\project\MATLAB_Image_Processing" 
      ```
      (※ `D:\path\to\your\project` の部分は実際のパスに置き換えてください)
    - 次に、以下のコマンドを実行してセットアップスクリプトを開始します。
      ```powershell
      PowerShell -ExecutionPolicy Bypass -File .\setup_environment.ps1
      ```
    - このスクリプトは、Visual C++ 再頒布可能パッケージ、Pythonライブラリ、そしてCMakeのインストールを自動的に行います。

### 3. Gitサブモジュールの初期化 (初回のみ)
リポジトリをクローンした後、ZeroMQのソースコードを取得するためにGitサブモジュールを初期化する必要があります。プロジェクトのルートディレクトリで以下のコマンドを実行してください。
```bash
git submodule update --init --recursive
```

### 4. MEXファイルのビルド
MATLABを起動し、`MATLAB_Image_Processing` ディレクトリをカレントディレクトリに設定してから、以下のコマンドを実行します。

```matlab
build_mex_files
```
このスクリプトは、まずZeroMQライブラリをお使いのコンパイラ環境に合わせてビルドし、その後そのライブラリを使ってMEXファイルをコンパイルします。初回ビルドには数分かかる場合があります。

`mex` ディレクトリ内に `mex_zeromq_handler.mexw64` のようなファイルが生成されていれば成功です。

### 5. 動作確認
`startup` スクリプトを実行してプロジェクトのパスを設定した後、`run_image_processing_test.m` を実行してセットアップが正しく完了したかを確認できます。
```matlab
startup
run_image_processing_test
