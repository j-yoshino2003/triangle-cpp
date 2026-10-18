# コーディングスタイル（Unreal Engine）

> 正本: `.claude/rules/unreal/coding-style.md`（英語）。
> [C++ ルール](../cpp/coding-style.md)を Unreal 固有の内容で拡張したもの。`Source/` 配下では **Epic のコーディング標準が汎用 C++ 命名規則を上書きする**。

## 一次情報

プロジェクト独自の変種ではなく Epic 公式の標準に従う。この文書と食い違ったら、正しいのは
一次情報でありこの文書のほうがバグである。要約ではなく原文を読む:

- [Epic C++ Coding Standard for Unreal Engine](https://dev.epicgames.com/documentation/ja-jp/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine) —
  メンバ変数の接頭辞は**定義していない**ので、`Source/` 配下のフィールドには印を付けない。
  また、型推論とインデントについては汎用 C++ ルールより厳しく、どちらも `*.Build.cs` まで
  及ぶ — 下記の 2 つの節を参照

## 命名（Epic 規約 — 必須）

- クラス: `UObject` 派生は `U`、Actor は `A`、通常の構造体は `F`、Slate ウィジェットは `S`、インターフェースは `I`、列挙体は `E`、テンプレートは `T` を接頭辞に
- 列挙メンバー: `PascalCase`（Epic 命名）。型名は Epic の `E` 接頭辞を維持。プロジェクトの「最後のメンバー」規約は維持するので `Max` を最後に定義する（`ESceneType { Title, MainGame, Max }`）
- 定数: 他の変数と同じ `PascalCase`（`const int32 CountPlusOne`）。Epic は定数専用の表記を定めていないので、C++ ルールが定数に付ける `k` 接頭辞はここでは外す。マクロは `UE_` + `UPPER_SNAKE_CASE` のままで、`ALL_CAPS` が属するのはここだけ
- bool 型: `b` 接頭辞 — `bIsAlive`、`bHasAmmo`
- 関数・変数・引数: `PascalCase`（camelCase / snake_case は使わない）。プロジェクト独自の接頭辞は付けず、Epic 命名をそのまま使う
- 参照で渡して関数が書き換える引数には `Out` を接頭辞として付ける（`OutResult`）。bool の場合は `b` を先に置く（`bOutResult`）。メンバや別名と紛れる引数には `In` を使う
- [C++ ルール](../cpp/coding-style.md)のフィールドの印は `Source/` 配下では**適用しない**。フィールドは素の `PascalCase`（`_maxHealth` ではなく `MaxHealth`）で、引数にも `_` は付けない

```cpp
UCLASS()
class MYGAME_API AEnemyCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category = "Combat")
    void ApplyDamage(float DamageAmount);

private:
    UPROPERTY(EditAnywhere, Category = "Combat")
    float MaxHealth = 100.f;

    bool bIsDead = false;
};
```

## 型推論の例外

Epic は読み手に型が見えている状態を要求するため、汎用 C++ ルールの「型が文脈から明らかなら `auto`」と
「構造化バインディングを使う」は**ここでは適用しない**:

- `auto` を**使わない**。Epic が認める例外はちょうど 3 つで、lambda の束縛（型をコードで表現できない）、
  iterator 変数、そして型を実質的に書き表せないテンプレートコード。`auto` を使う場合も、型名に付けるのと
  同じように `const` / `&` / `*` を正しく書く
- C++20 の構造化バインディングを**使わない** — Epic は事実上可変個引数の `auto` として扱っている
- C# の `var` にも同じことが適用される。`*.Build.cs` と `*.Target.cs` がそれに当たる

## コメントの言語 — 意図的な逸脱

Epic は**すべてのコードとコメントに米国英語のスペルとグラマーを使うこと**を必須とし、チェンジリストの
記述にも及ぶとしている。それでもこのプロジェクトはコメントを日本語で書く（`AGENTS.md`、
`common/code-comments.md`）。チームが日本語で読み書きするためである。これは意図的な逸脱であり、
追随漏れと誤解されないようここに記録する。識別子は英語のままなので、上記の命名規約には影響しない。

## メモリ管理の例外

汎用 C++ ルールの「`std::unique_ptr` / `std::shared_ptr` を使う」はエンジン型には**適用しない**:

- `UObject` 派生型は GC 管理 — `UPROPERTY()` フィールドまたは `TObjectPtr<T>` で保持する（`UPROPERTY` 無しの生ポインタは GC 後にダングリングする）
- オブジェクトより長生きし得る非所有参照には `TWeakObjectPtr<T>`
- 非 `UObject` 型には `TUniquePtr`、`TSharedPtr` / `TSharedRef`（エンジンコンテナ）を使う（`std::` スマートポインタは使わない）

## エンジンコンテナと文字列

- エンジンに面するコードでは `std::vector` / `std::map` より `TArray`、`TMap`、`TSet` を使う
- 文字列: `FString`（可変）、`FName`（識別子・高速比較）、`FText`（ユーザー向け・ローカライズ）— 用途で選ぶ。ユーザーに見える文字列を `FString` にハードコードしない

## ヘッダー

- **すべてのヘッダーは `#pragma once` で始める** — Epic が要求しており、使用するすべてのコンパイラが対応していると明記している。これは [C++ ルール](../cpp/coding-style.md)の `#ifndef` インクルードガード（Core Guidelines SF.8 に従ったもの）を**上書きする**。2 つの公式文書がここで実際に対立しているため、`Source/` 配下ではエンジン別が勝つ
- include-what-you-use に従い、前方宣言でヘッダーを最小に保つ
- `#include "X.generated.h"` は `UCLASS` / `USTRUCT` ヘッダーの最後のインクルードにする

## フォーマット

- **行始まりの空白はスペースではなくタブ**、タブ幅は 4 文字。Epic が明記しており C# にも及ぶため、
  `Source/**` だけでなく `*.Build.cs` / `*.Target.cs` も対象。これは
  [共通レイアウト規約](../common/code-layout.md)の 4 スペースを**上書きする**。Visual Studio は C# ファイルを
  スペース既定にしているので、プロジェクトごとに設定を変える必要がある
- Allman スタイルの波括弧（Epic 標準）。プロジェクトの `.clang-format` があればそれに従う

## 生成と破棄

- `new` / `delete` は禁止 — 生成は `NewObject` / `CreateDefaultSubobject` / `SpawnActor` を使う
- 破棄は GC に委ねる。`UObject` を `delete` しない

```cpp
// ❌ new で生成して delete で解放している.
UWeapon* Weapon = new UWeapon();
delete Weapon;

// ✅ 生成は NewObject / CreateDefaultSubobject / SpawnActor で行う.
// ✅ 破棄は GC に委ねる. UObject を delete しない.
UPROPERTY()
TObjectPtr<UWeapon> Weapon;

Weapon = NewObject<UWeapon>(this);
```

## 引数

- `UObject` 派生型は参照ではなく生ポインタで渡す（`AActor* Target`）
- それ以外の型は `const T&` / `T&` で渡す（`const FString& Name`）

```cpp
// ✅ UObject 派生型は参照ではなく生ポインタで渡す.
void SetTarget(AActor* Target);

// ✅ それ以外の型は const T& / T&.
void SetName(const FString& Name);
```

## 文字列リテラル

- 文字列リテラルは `TEXT("...")` で囲む

```cpp
// ✅ 文字列リテラルは TEXT("...") で囲む.
FString Name = TEXT("Player");
```

## ログとアサーション

- ログは `UE_LOG(LogTemp, Warning, TEXT("..."), ...)` を使う

```cpp
// ✅ ログ.
UE_LOG(LogTemp, Warning, TEXT("Item count: %d"), ItemCount);
```

| 用途 | マクロ |
|------|------|
| 不変条件（回復不可能） | `check()` / `checkf()` |
| 回復可能な検証 | `ensure()` / `ensureMsgf()` |
| Blueprint 公開イベント | `DECLARE_DYNAMIC_MULTICAST_DELEGATE*` |
| C++ 内部のみのイベント | `DECLARE_MULTICAST_DELEGATE*` |
