# コードレイアウト規約

> 正本: `.claude/rules/common/code-layout.md`（英語）。
> ソースファイルを読み書きするときだけ読み込まれる（frontmatter の `paths:` による条件読み込み）。
> 常に効く設計方針は `coding-style.md`（Codex / Antigravity の写しは `common-coding-style.md`）にある。

## ファイル形式

| 項目 | ルール |
|------|------|
| エンコード | UTF-8（BOM 付き） |
| ファイル末尾 | 空行を 1 行 |
| インデント | スペース 4 文字 |
| 1 行の最大文字数 | 120 文字以内 |

ファイル先頭のヘッダーは専用書式を使う。
**ヘッダーブロックとその後ろに続くもの（`#pragma once`・最初の `#include`・最初の `using`）の間には、
空行をちょうど 1 行入れる。** ヘッダーはファイルの説明で、後ろに続くのはコード。空行がその 2 つを
1 つの塊に見せないための区切りになる。

```cpp
//---------------------------------------
/// @file   File name
///
/// @brief  What this class does
///
/// @date   Date
///
/// @author Author name
//---------------------------------------

#pragma once

#include "System/Core.h"
```

## インクルード / using の順序

- アルファベット順。`#include` はパスの階層が浅い順を主キーとする

```cpp
// ✅ 階層の浅いパスを先に.
#include "System/Core.h"
#include "System/Memory/Allocator.h"
```

## グループ内の宣言順

宣言がどの **グループ** に属するかは言語別の規約が定める（C++ は public 関数 → public 変数 → private 関数 → private 変数）。**グループの順序は変えない。** グループの中の並びは、次の 1 つの原則で決める。

**抽象度の降順 — 呼ぶ側を上、呼ばれる側を下**（垂直的順序、段階的下降規則）。グループは「この型が外から呼ばれる入口」で始まり、「上のメンバーが組み立てに使う最小単位」で終わる。結果としてグループは上から下へ読める 1 本の流れになる。

- その型が存在する理由がグループの先頭に来る（ウィンドウなら `Open` / `Close`）
- その状態の間に動く処理が次に来る（`Update` / `Draw`）
- 問い合わせ・判定は最後（`IsOpen`、`GetSelectedIndex`）— 上のメンバーすべてが使い得るので、これらはグループの主題ではなく材料である
- 分岐を振り分ける側が、振り分けられる先より上に来る。その先がさらに委譲する相手はもっと下。コールグラフの深さが、ファイル内の深さになる

この原則の上に 2 つの規則が乗る。

1. **対になるものは隣接させ、自然な順に書く** — `Open` / `Close`、`Acquire` / `Release`、`Begin` / `End`、ゲッターとセッター、オーバーロード、そしてコンストラクタとデストラクタ。対の隣接は抽象度より優先する。破棄の契約は生成の契約の隣でしか読み取れないので、両端に離すのではなくグループの先頭に 2 つ並べて置く
2. **抽象度が同じなら、呼ばれる順に並べる** — `Initialize` は `Update` より前、`Open` は `Draw` より前

**新しいメンバーは原則が示す位置に挿入する。グループの末尾に追記しない。** 末尾への追記がグループの順序を崩す原因そのもので、結果として並びが「機能を追加した順」になり、読む側には予測できなくなる。原則が何も言わない範囲では既存の並びを維持する。同格のものを並べ替えても差分が汚れるだけで何も得られない。

抽象度が降りるのは **グループの中だけ** で、グループを跨がない。public 関数から呼ばれる private ヘルパーは、呼び出し元の近くで読めたほうがよくても private グループに留まる。グループの順序が優先する。

ソースファイルは、ヘッダーの宣言順どおりに、グループ単位・メンバー単位で定義を並べる。

レビューで順序を指摘するのは、原則または規則 1 から見て明らかに位置がおかしいときだけ。自分なら別の順にしたという程度の違いは指摘にしない。

## 型・値

- float リテラルには必ず `f` をつける（`0.5f`）
- 型は明示する（C++ は型が自明な場合のみ `auto` 可 — cpp 規約が優先）
- スコープ内で一度しか使わないローカル変数は作らず、そのまま返す（式が複雑なら関数に切り出す）

```csharp
float speed = 0.5f;         // ✅ float リテラルには必ず f をつける.
int count = GetCount();     // ✅ 読みやすさに寄与する箇所では型を明示する.
                            //    （C++: 型が自明なら auto 可 — cpp 規約が優先.）
```

```csharp
// ❌ スコープ内で一度しか使わないローカル変数.
int total = basePrice * quantity + shippingFee;
return total;

// ✅ そのまま返す. 式が複雑なら関数に切り出す.
return CalculateTotalPrice(basePrice, quantity, shippingFee);
```

## 簡潔な記述の優先

条件に基づく変換・集計は制御構文ではなく LINQ / STL アルゴリズム（`Where` / `Select` / `find_if` / `transform` 等）に置き換える。

```csharp
// ✅ C#: LINQ（Where、Select、FirstOrDefault、…）.
List<string> names = players.Where(player => player.IsAlive)
                            .Select(player => player.Name)
                            .ToList();
```

```cpp
// ✅ C++: STL アルゴリズム（find_if、transform、any_of、…）.
auto it = std::find_if(players.begin(), players.end(),
                       [](const Player& player) { return player.IsAlive(); });
```

## 制御構文

- **波括弧必須**: `if` / `else if` / `else` / `for` / `while` / `do-while` は 1 文でも必ず波括弧
- **条件式の統合**: 同じ結果に至る条件式は一つにまとめる（`if (isDead || hitPoint <= 0)`）
- **ループ**: 事前に計算できる値はループの外に出す
- **三項演算子**: 1 行 120 文字未満に収まる場合のみ使用可。収まらない場合は `if` / `else` を使う
- **switch**: `default` は一番上。複数行の処理は関数に切り出す。状態ごとに処理が大きく異なる場合は State パターンを検討
- **while**: `while (true)` は無限ループ専用。それ以外は `for` / `do-while`
- **複数行の条件式**: 条件式が 2 行以上になる場合は `||` / `&&` の直後で改行し、オペランドを揃える
- **前後の空行**: 制御構文の前後には必ず空行を 1 行入れる（連続する制御構文どうしの間も入れる）

```csharp
// ✅ 2 行以上になる条件式は || / && の後で改行し、オペランドを揃える.
if (player.IsAlive() &&
    player.GetHitPoint() > 0 &&
    !player.IsStunned())
{
    Attack(player);
}
```

```csharp
int damage = CalculateDamage(attacker, defender);

// ✅ 制御構文の前後には必ず空行を 1 行入れる.
if (damage <= 0)
{
    return;
}

foreach (Buff buff in defender.Buffs)
{
    damage = buff.Reduce(damage);
}

defender.ApplyDamage(damage);
```

## 改行

| 位置 | 空行 |
|------|------|
| メンバ変数・メンバ関数の宣言の前後 | 1 行 |
| 型・メンバ定義レベルの波括弧の前後 | 1 行 |
| 波括弧の内側（`{` 直後・`}` 直前） | 入れない |
| 制御構文の前後 | 1 行 |
| 制御構文どうしの間 | 1 行 |
