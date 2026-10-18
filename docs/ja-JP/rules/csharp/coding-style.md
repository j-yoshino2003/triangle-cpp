# コーディングスタイル（C#）

> 正本: `.claude/rules/csharp/coding-style.md`（英語）。
> [共通ルール](../common/coding-style.md)を C# 固有の内容で拡張したもの。

## 一次情報

プロジェクト独自の変種ではなく C# の公式規約に従う。この文書と食い違ったら、正しいのは一次情報で
ありこの文書のほうがバグである。要約ではなく原文を読む:

- [C# identifier naming rules and conventions](https://learn.microsoft.com/ja-jp/dotnet/csharp/fundamentals/coding-style/identifier-names) —
  命名の正本。`_camelCase` のインスタンスフィールド、`s_` / `t_` の static、`PascalCase` の定数
- [C# Coding Conventions](https://learn.microsoft.com/ja-jp/dotnet/csharp/fundamentals/coding-style/coding-conventions) —
  言語機能の指針。命名は上のページにあり、こちらには無い

## 基準

- 最新の .NET の慣習に従い、null 許容参照型（nullable reference types）を有効にする
- public / internal な API にはアクセス修飾子を明示する
- ファイルはそのファイルが定義する主要な型に沿った内容に保つ

## 型とモデル

- 不変の値的モデルには `record` / `record struct` を優先する
- ID とライフサイクルを持つエンティティには `class`
- サービス境界・抽象化には `interface`
- アプリケーションコードで `dynamic` は避ける（ジェネリクスや明示的なモデルを使う）

```csharp
public sealed record UserDto(Guid Id, string Email);

public interface IUserRepository
{
    Task<UserDto?> FindByIdAsync(Guid id, CancellationToken cancellationToken);
}
```

## 不変性

- 共有状態には `init` セッター、コンストラクタ引数、不変コレクションを優先する
- 更新後の状態を作るとき、入力モデルをその場で書き換えない（`with` 式を使う）

```csharp
public sealed record UserProfile(string Name, string Email);

public static UserProfile Rename(UserProfile profile, string name) =>
    profile with { Name = name };
```

## using ディレクティブ

- `System` 名前空間を最上部に配置する
- それ以外はアルファベット順に並べる

```csharp
// ✅ System 名前空間を最上部に置く.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

// ✅ 残りはアルファベット順に並べる.
using Microsoft.Azure.Cosmos;
using Newtonsoft.Json;
```

## 変数の初期化

この表は**ローカル変数**についてのもの。フィールドは型のデフォルト値に自動で初期化されるので、
そのデフォルト値（`= 0`、`= null`、`= false`）を書かない — Unity 公式がこれを冗長な初期化子として
削除するよう指示している。デフォルトと違う初期値を持つフィールドには書く。

| 型カテゴリ | 初期化 |
|------|------|
| 値型（プリミティブ・構造体・enum） | `default` |
| 参照型（クラス） | `new()` |
| 配列・コレクション | `[]`（コレクション式） |

```csharp
int tmp = default;          // ✅ 値型.
StringBuilder sb = new();   // ✅ 参照型.
int[] indices = [];         // ✅ 配列とコレクション.
```

## アクセス修飾子

- メンバーのアクセス修飾子は `private` も含めて必ず書く。言語としては省略できるが、公式の指針はデフォルトに頼らずアクセスレベルを曖昧にしないこと

## 定数

- コンパイル時に値が確定する定数は `const`
- `readonly` は `const` で代替できないケース（参照型・ランタイム初期化）に限る

## 構造体の引数

大きい構造体等の値型は参照で渡す:

| 状況 | 使用する型 |
|------|------|
| 変更しない | `in T` |
| 変更する | `ref T` |

```csharp
// ✅ 変更しない値型は in で渡す.
void Apply(in LargeStruct value);

// ❌ 値渡しは構造体をコピーする.
void Apply(LargeStruct value);
```

## 式形式メンバー

- 一行で表せるメソッドとゲッタープロパティはアロー演算子（式形式メンバー）で実装する
- `=>` は関数名・プロパティ名の次の行に記述する

```csharp
// ✅ 一行のメソッドとゲッタープロパティは式形式メンバーで実装する.
// ✅ => はメンバー名の次の行に置く.
public int Count
    => items.Count;

// ❌ 一行で済むものをブロック本体で書いている.
public int Count
{
    get { return items.Count; }
}
```

## 非同期とエラー処理

- `.Result` / `.Wait()` などのブロッキング呼び出しより `async` / `await` を優先する
- public な非同期 API には `CancellationToken` を通す
- 具体的な例外を投げ、構造化プロパティ付きでログを残す

```csharp
public async Task<Order> LoadOrderAsync(
    Guid orderId,
    CancellationToken cancellationToken)
{
    try
    {
        return await repository.FindAsync(orderId, cancellationToken)
            ?? throw new InvalidOperationException($"Order {orderId} was not found.");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Failed to load order {OrderId}", orderId);
        throw;
    }
}
```

## 命名規則

プロジェクト独自の変種ではなく、C# の公式規約に従う。

- private / internal の非定数インスタンスフィールド: `_` + `camelCase`（`_workerQueue`）
- private / internal の static フィールド: `s_` + `camelCase`（`s_callCount`）。thread-static は `t_` + `camelCase`
- 引数とローカル変数: 接頭辞なしの `camelCase`
- 定数: `PascalCase` — フィールドもローカル定数も、private / internal も含めて
- 列挙メンバー: `PascalCase`、prefix / suffix は付けない。型名は単数形の名詞（`[Flags]` は複数形）。プロジェクトの「最後のメンバー」規約は維持するので `Max` を最後に定義する

```csharp
private IWorkerQueue _workerQueue;                  // ✅ インスタンスフィールド.
private static int s_callCount;                     // ✅ 書き換わる static 状態.
private static readonly TimeSpan RetryInterval;     // ✅ 定数は PascalCase.

enum SceneType { Title, MainGame, Max }             // ✅ PascalCase で Max を最後に.
```

## フォーマット

- フォーマットとアナライザー修正には `dotnet format` を使う
- `using` ディレクティブを整理し、未使用の import を削除する
- 一行で表せるメソッド・ゲッターは式形式メンバーで実装する（上記セクション参照）。複数行の本体はブロック構文
