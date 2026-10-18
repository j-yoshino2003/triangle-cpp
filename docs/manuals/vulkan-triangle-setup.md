# Vulkan 三角形プロジェクトのセットアップ手順

セットアップ 4 項目の記録です。**すべて完了済み**で、`Debug | x64` と `Release | x64` の
ビルドが通ることを確認してあります。

| 項目 | 実施者 | 結果 |
| --- | --- | --- |
| GLFW の NuGet 参照 | ユーザー（下記 A） | `packages.config` 形式で追加済み |
| Win32 / x86 構成の削除 | Claude（下記 B） | `cpp.vcxproj` / `cpp.slnx` から削除済み |
| Vulkan SDK の参照設定 | Claude | `cpp.vcxproj` に追加済み |
| シェーダーのビルドステップ | Claude | `cpp.vcxproj` に追加済み |

前提の環境（確認済み）:

- Visual Studio 18.10 Community（`C:\Program Files\Microsoft Visual Studio\18\Community`）
- Vulkan SDK 1.4.357.0（環境変数 `VULKAN_SDK` が設定済み）
- 作業ブランチ `feature/vulkan-triangle-setup`

A と B は Visual Studio の GUI だけで完結する操作なので、手順をそのまま残してあります。環境を
作り直すときや、別マシンで同じ構成を組むときに使えます。

---

## A. GLFW の NuGet 参照を追加する

1. `cpp.slnx` を Visual Studio で開く
2. ソリューションエクスプローラーで **cpp** プロジェクトを右クリック → **NuGet パッケージの管理**
3. **参照**（Browse）タブを開き、検索ボックスに `glfw` と入力する
4. パッケージ ID がちょうど **`glfw`**（作成者 Marcus Geelnard, Camilla Berglund / 所有者
   Sebastian Grottel）のものを選ぶ
5. バージョンに **3.4.0** を選び、**インストール**を押す
6. ライセンスの同意を求められたら同意する（GLFW は zlib/libpng ライセンス）

### 似た名前のパッケージを選ばないこと

検索結果には GLFW 関連のパッケージが複数出ます。次のものは **.NET 向け**で、C++ プロジェクトから
は使えません。

| 選ばない ID | 中身 |
| --- | --- |
| `Ultz.Native.GLFW` | Silk.NET（.NET バインディング）用のネイティブ DLL |
| `OpenTK.redist.glfw` / `opentoolkit.redist.glfw` | OpenTK（.NET）用の再配布 DLL |
| `Robust.Natives.Glfw` | RobustToolbox（.NET）用 |
| `nupengl.core` | FreeGLUT + GLFW + GLEW の OpenGL 用詰め合わせ。非推奨扱い |

選ぶべき `glfw` 3.4.0 は、GLFW 公式のプリビルドバイナリをネイティブパッケージとして包んだもので、
`build/native/glfw.targets` がインクルードパス・リンク対象・`glfw3.dll` の出力先コピーまで
自動設定します。

### 実際に入った形式

Visual Studio 18 系は C++ プロジェクトの `PackageReference` 対応が実験的に入ったバージョン帯なので、
どちらの形式になるかは環境によって変わります。この環境では **`packages.config` 形式**で入りました。

| 形式 | 目印 | この環境 |
| --- | --- | --- |
| packages.config | リポジトリ直下に `packages.config` と `packages\glfw.3.4.0\` ができ、`cpp.vcxproj` に `glfw.targets` の `<Import>` が入る | **これ** |
| PackageReference | `cpp.vcxproj` に `<PackageReference Include="glfw" Version="3.4.0" />` の行が入り、`packages\` はできない | — |

`packages.config` 形式では、Visual Studio が `EnsureNuGetPackageBuildImports` ターゲットも
`cpp.vcxproj` に書き込みます。パッケージを復元していない状態でビルドすると、これが
「NuGet パッケージの復元を使ってください」という明示的なエラーを出します。

`.gitignore` に `packages/` を追加してあるので、パッケージ本体はコミット対象になりません
（`packages.config` はコミット対象です。これが無いと復元できません）。

---

## B. Win32 / x86 構成を削除する

現状、ソリューションには x64 と x86 の両プラットフォームが、プロジェクトには x64 と Win32 の
両プラットフォームが登録されています。Windows 向けの Vulkan 学習用に 32 ビットを維持する理由が
ないので、x64 だけに揃えます。

> **名前の違い**: 同じ 32 ビットを指して、`cpp.slnx` では **x86**、`cpp.vcxproj` では
> **Win32** と表記されます。両方消す必要があります。

1. メニューの **ビルド** → **構成マネージャー**
2. **アクティブ ソリューション プラットフォーム**のドロップダウン → **編集**
3. 一覧の **x86** を選び、**削除** → 確認ダイアログで OK → **閉じる**
4. 表の **プラットフォーム**列（cpp プロジェクトの行）のドロップダウン → **編集**
5. 一覧の **Win32** を選び、**削除** → 確認ダイアログで OK → **閉じる**
6. **閉じる**で構成マネージャーを閉じ、**ファイル** → **すべて保存**

### 終わったら確認すること

- `cpp.slnx` に `<Platform Name="x86" />` の行が残っていない
- `cpp.vcxproj` に `Win32` を含む行が残っていない

構成マネージャーは `ProjectConfiguration` と `PropertyGroup` を消しても
`ItemDefinitionGroup`（警告レベルやプリプロセッサ定義を書いてあるブロック）を消し残すことが
あります。

> **この環境では** Claude が `cpp.vcxproj` を直接編集して、`ProjectConfiguration` /
> `PropertyGroup` / `ImportGroup` / `ItemDefinitionGroup` の 4 種すべてから Win32 を消しました。
> `cpp.vcxproj` に残る `<Keyword>Win32Proj</Keyword>` は**消しません**。これは「Win32 デスクトップ
> アプリ」というプロジェクト種別を表す値で、x86 プラットフォームとは無関係です。

---

## C. Vulkan SDK の参照設定（Claude 実施分）

`cpp.vcxproj` に構成非依存の `ItemDefinitionGroup` を 1 つ足し、Debug / Release の両方に効く
形で次を設定しました。構成ごとに書くと同じ内容が 2 箇所に増えるためです。

| 設定 | 値 |
| --- | --- |
| インクルードパス | `$(VULKAN_SDK)\Include` |
| リンク対象 | `$(VULKAN_SDK)\Lib\vulkan-1.lib` |

あわせて `EnsureVulkanSdk` ターゲットを足しました。`VULKAN_SDK` が未設定、またはヘッダー・
インポートライブラリ・`glslc.exe` のいずれかが見つからない場合に、どのファイルが無いかを名指しで
示してビルドを止めます。これが無いと、SDK 未インストールの環境で「`vulkan/vulkan.h` が見つからない」
という原因の分かりにくいエラーになります。

## D. シェーダーのビルドステップ（Claude 実施分）

`.vert` / `.frag` を `$(VULKAN_SDK)\Bin\glslc.exe` で SPIR-V にコンパイルし、実行ファイルの隣の
`shaders\` へ出力します。規則は `CustomBuild` の `ItemDefinitionGroup` に 1 つだけ書いてあるので、
**シェーダーを増やすときは `CustomBuild` 項目を 1 行足すだけ**です。

```xml
<ItemGroup>
  <CustomBuild Include="shaders\triangle.vert" />
  <CustomBuild Include="shaders\triangle.frag" />
</ItemGroup>
```

出力は `x64\Debug\shaders\triangle.vert.spv` のように、元のファイル名に `.spv` を付けた名前に
なります。`vert.spv` のような固定名にしていないのは、シェーダーが増えたときに名前が衝突しない
ようにするためです。

---

## 確認した結果

`Debug | x64` と `Release | x64` の両方でビルドが通り、実行まで確認済みです。

| 確認項目 | 結果 |
| --- | --- |
| ビルド | Debug / Release ともに成功 |
| シェーダー | `x64\Debug\shaders\triangle.vert.spv` と `triangle.frag.spv` が生成される |
| GLFW の DLL | `glfw3.dll` が出力ディレクトリへ自動コピーされる |
| 実行 | `GLFW 3.4.0 Win32 WGL Null EGL OSMesa VisualC DLL` / `Vulkan 1.4.357` と表示して終了コード 0 |
| `VULKAN_SDK` ガード | 未設定でビルドすると `EnsureVulkanSdk` が日本語メッセージで停止させる |

### まだ実装ではない部分

`src\main.cpp` は、インクルードパスとリンク設定が通っていることを確かめるためだけのもので、
GLFW と Vulkan のバージョンを表示して終わります。ウィンドウも描画もまだありません。次の実装段階で
中身を入れ替えます。

`shaders\triangle.vert` / `triangle.frag` は、頂点バッファを使わず頂点インデックスから座標と色を
引く形で書いてあり、三角形を出す最終版としてそのまま使えます。
