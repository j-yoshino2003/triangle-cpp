# Triangle-cpp

Vulkan を使った C++ 実装で、ウィンドウに三角形 1 枚を表示する最小構成のプロジェクトです。

## 概要

グラフィックス API の学習用に、Vulkan の初期化からフレーム描画までを一通り自分で書くことを目的に
しています。描画するのは頂点カラーで塗られた三角形 1 枚だけで、シーン管理・アセット読み込み・
UI などは持ちません。

やること:

- Vulkan インスタンス / 物理デバイス / 論理デバイス / キューの初期化
- GLFW で作ったウィンドウに対するサーフェスとスワップチェーンの構築
- GLSL で書いた頂点・フラグメントシェーダーの SPIR-V へのビルド時コンパイル
- グラフィックスパイプラインの構築とコマンドバッファの記録
- 同期オブジェクトを使ったフレームループ

やらないこと:

- Windows 以外のプラットフォーム対応
- 深度バッファ・テクスチャ・ユニフォームバッファ（三角形の表示に不要なため）

## 前提環境

| 項目 | 内容 |
| --- | --- |
| OS | Windows 11 |
| IDE | Visual Studio（プラットフォームツールセット v145） |
| 言語標準 | C++20（`/std:c++20`） |
| 構成 | x64 の Debug / Release |
| Vulkan SDK | 1.4.357.0（環境変数 `VULKAN_SDK` を参照する） |

## 構成の方針

| 項目 | 選択 | 理由 |
| --- | --- | --- |
| ビルド | 既存の `cpp.vcxproj` / `cpp.slnx` | Visual Studio だけで完結させる |
| ウィンドウ・入力 | GLFW 3.4 | Vulkan 公式チュートリアルが前提にしており、サーフェス生成が最短で書ける |
| GLFW の入手 | NuGet パッケージ `glfw` | ネイティブパッケージで、ヘッダー・インポートライブラリ・DLL コピーが自動設定される |
| Vulkan の入手 | インストール済み SDK | Vulkan のネイティブ NuGet パッケージは存在しないため、SDK を直接参照する |
| API スタイル | C API（`vulkan.h`） | チュートリアル・サンプル・エラー情報が最も揃っている |

### NuGet パッケージ `glfw` について

`glfw` 3.4.0 は GLFW 公式のプリビルドバイナリを NuGet 化したもので、`build/native/glfw.targets`
がインクルードパス・リンク対象・`glfw3.dll` の出力先コピーまで設定します。

- 既定は動的リンク。`GlfwLinkage` を `static` にすると静的リンクに切り替わる
- 同梱ライブラリのツールセットは v120〜v143 だが、`glfw.targets` が
  `PlatformToolsetVersion` 143 以上 150 未満を v143 にマップするため、v145 のプロジェクトでも
  そのままリンクできる（MSVC は v140 以降バイナリ互換）

## ビルドと実行

### 初回に必要な準備

| 準備 | 内容 |
| --- | --- |
| Vulkan SDK | インストールして、環境変数 `VULKAN_SDK` が設定されていること。未設定ならビルドが `EnsureVulkanSdk` で止まり、足りないファイルを名指しで示します |
| NuGet の復元 | `packages/` はコミットしていないため、新規 clone には GLFW 本体がありません |

NuGet の復元は Visual Studio のビルド時の自動復元で行われます。`msbuild` を直接叩く場合や
自動復元が無効な場合は、先に復元してください。復元せずにビルドすると
`EnsureNuGetPackageBuildImports` が「NuGet パッケージの復元を使ってください」と明示的に止めます。

```bash
nuget restore cpp.slnx
```

### ビルド

1. Visual Studio で `cpp.slnx` を開く
2. 構成を `Debug | x64` にする
3. ビルドする（`glfw3.dll` は出力ディレクトリへ自動コピーされる）

シェーダーは `shaders\*.vert` / `*.frag` をビルド時に `$(VULKAN_SDK)\Bin\glslc.exe` で SPIR-V へ
コンパイルし、`x64\<構成>\shaders\` に出力します。シェーダーを増やすときは `cpp.vcxproj` の
`CustomBuild` 項目を 1 行足すだけです。

現時点では C++ のソースがまだ無いため、ビルドしても実行ファイルは生成されません。シェーダーの
コンパイルと `glfw3.dll` のコピーまでが走ります。

## ディレクトリ構成

| パス | 内容 |
| --- | --- |
| `shaders/` | GLSL シェーダー。ビルド時に SPIR-V へコンパイルされる |
| `cpp.slnx` / `cpp.vcxproj` / `cpp.vcxproj.filters` | Visual Studio のソリューションとプロジェクト |
| `packages.config` | NuGet の参照（GLFW） |
| `docs/manuals/` | セットアップと開発ツールの手順書 |
| `docs/reviews/` | クロスレビューのレポート |
| `docs/ja-JP/` | コーディング規約の日本語訳リファレンスとハーネスのガイド |
| `specs/` | 仕様書（spec-kit） |
| `scripts/` | spec-kit のランチャー |

AI コーディングエージェントのハーネス（`AGENTS.md`、`CLAUDE.md`、`.claude/`、`.codex/`、
`.agent/`、`.specify/`、`参考リンク.md`）については [AGENTS.md](AGENTS.md) を参照してください。

## 開発ツール

| ツール | 状態 | 用途 |
| --- | --- | --- |
| Vulkan SDK 1.4.357.0 | 導入済み | ヘッダー・`vulkan-1.lib`・`glslc.exe`・検証レイヤ |
| `vkconfig-gui.exe` | SDK 同梱 | コードを変えずに有効なレイヤーを確認・変更する |
| `vkcube.exe` | SDK 同梱 | ドライバーと SDK 自体の切り分け用サンプル |
| RenderDoc v1.46 | 未導入 | フレームキャプチャ。描画結果とパイプライン状態を調べる |

手順書:

- セットアップの記録 — [docs/manuals/vulkan-triangle-setup.md](docs/manuals/vulkan-triangle-setup.md)
- RenderDoc の導入と使い方 — [docs/manuals/renderdoc-setup.md](docs/manuals/renderdoc-setup.md)

三角形が出ない段階で最初に頼るのは RenderDoc ではなく検証レイヤです。API の使い方違反は検証レイヤが
メッセージで指摘しますが、RenderDoc が効くのは「検証レイヤは黙っているのに画面が真っ黒」という
段階からです。検証レイヤの有効化とデバッグメッセンジャーの作成はまだ入っていません。

## 参考

| 文書 | URL |
| --- | --- |
| Vulkan Tutorial | https://docs.vulkan.org/tutorial/latest/ |
| Vulkan 仕様書 | https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html |
| GLFW ドキュメント | https://www.glfw.org/docs/latest/ |
| NuGet パッケージ `glfw` | https://www.nuget.org/packages/glfw/ |
| RenderDoc | https://renderdoc.org/ |