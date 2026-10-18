# コーディングスタイル（C/C++）

> 正本: `.claude/rules/cpp/coding-style.md`（英語）。
> [共通ルール](../common/coding-style.md)を C++ 固有の内容で拡張したもの。

## 一次情報

plain C++ には公式の命名規約が無いのでプロジェクトで決めるが、次の 2 文書には従う。この文書と
食い違ったら、正しいのは一次情報でありこの文書のほうがバグである。要約ではなく原文を読む:

- [C++ 規格 working draft `[lex.name]`](https://eel.is/c++draft/lex.name) — 予約識別子。
  下記のフィールド規約はこの条文から導いている
  （[Markdown 版](https://raw.githubusercontent.com/cplusplus/draft/main/source/lex.tex)）
- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines) — NL.5 は
  名前に型を埋める形を否定するが、`m_` と `p` は明示的に免除している
  （[Markdown 版](https://raw.githubusercontent.com/isocpp/CppCoreGuidelines/master/CppCoreGuidelines.md)）

## モダン C++（C++17/20/23）

- C スタイルの構文よりモダン C++ の機能を優先する
- 型が文脈から自明な場合は `auto` を使ってよい
- コンパイル時定数には `constexpr` を使う
- 構造化束縛を使う: `auto [key, value] = map_entry;`

## リソース管理

- **常に RAII** — 手動の `new` / `delete` は禁止
- 排他的所有権には `std::unique_ptr`
- `std::shared_ptr` は共有所有が本当に必要な場合のみ
- 生の `new` より `std::make_unique` / `std::make_shared`

### シグネチャにおける所有権

| 状況 | 使用する型 |
|------|-----------|
| 関数実行後にアクセスしない | 参照で渡す |
| 所有権を共有する（内部でコピーして保持） | `const shared_ptr<T>&` |
| 所有権を要求しない | `const weak_ptr<T>&` |
| 所有権を受け取り以降管理する | `shared_ptr<T>&&`（ムーブ） |
| 戻り値（所有権を譲渡しない） | `weak_ptr<T>`（原則） |
| 戻り値（所有権を譲渡する） | `shared_ptr<T>` |

## 初期化

- 型の既定値での初期化（値初期化）はブレース `{}` で統一する（`int tmp{};` = 0、`MyClass* node{};` = nullptr）
- 既定値以外の値を持たせる初期化は `=` を使う（`int hitPoint = 100;`、`std::string label = "Player";`）。宣言に直接続くブレースへ値を入れない（`int hitPoint{100};` は不可）。`=` の後ろのブレースは要素を与えるものなので可（`std::vector<int> indices = { 1, 2, 3 };`）
- `=` で書けない場合だけ `()` を使う。該当するのは、コンストラクターが `explicit` のとき、またはブレースだと別のオーバーロードが選ばれるとき（`std::lock_guard<std::mutex> lock(_mutex);` は `explicit`、`std::vector<int> buffer(5);` はゼロ初期化された要素 5 個。`{5}` だと値 5 が 1 個になる）
- 縮小変換を暗黙に起こさない。意図して縮めるなら `static_cast` で明示する（`int32_t count = static_cast<int32_t>(received);`）。ブレースがその検査になる — `int32_t count{received};` はコンパイルが通らないが、`int32_t count = received;` は黙って切り捨てる

```cpp
// ✅ 型の既定値 — 必ずブレース {}.
int tmp{};                  // = 0
float value{};              // = 0.0f
bool flag{};                // = false
std::string name{};         // = ""
std::vector<int> values{};  // = 空のベクター
MyClass* node{};            // = nullptr

// ✅ それ以外の値 — = で初期化する.
int hitPoint = 100;
float speed = 0.5f;
bool isAlive = true;
std::string label = "Player";
std::vector<int> indices = { 1, 2, 3 };  // = の後ろのブレースは要素を与えるものなので可.

// ✅ = で書けない場合（explicit なコンストラクター、またはブレースだと別のオーバーロードが選ばれる）は ().
std::lock_guard<std::mutex> lock(_mutex);  // lock_guard のコンストラクターは explicit.
std::vector<int> buffer(5);  // = ゼロ初期化された要素 5 個. {5} なら値 5 が 1 個になる.

// ✅ より狭い型への変換は明示する. 暗黙に任せない.
int32_t count = static_cast<int32_t>(received);  // received は int64_t で、縮小は意図的.

// ❌ 宣言に直接続くブレースで既定値以外の値を与えない.
int hitPoint{100};

// ❌ 縮小変換を暗黙に残さない. int32_t count{received}; はコンパイルが通らず、それが検査になる.
int32_t count = received;
```

## 列挙体

- スコープ無し `enum` は名前空間を汚染するため禁止。`enum class` のみ使用する（前方宣言も可能になる）
- 列挙子は `PascalCase`。最後に必ず `Max` を定義する（`enum class SceneType { Title, MainGame, Max };`）
- `ALL_CAPS` にしない。Core Guidelines Enum.5 が検査対象としている。third-party ヘッダーに同名のマクロ（`#define RED`）が在ると、列挙子が構文エラーになるため

```cpp
// ❌ スコープ無し enum は名前空間を汚染する.
enum SceneType { Title, MainGame, Max };

// ✅ enum class のみ使う. 前方宣言も可能になる.
// ✅ 列挙子は PascalCase で、Max を最後に定義する.
// ❌ ALL_CAPS にしない: Core Guidelines Enum.5 が検査対象としている. 同名のマクロ
//    （#define RED）が在ると列挙子が構文エラーになるため.
enum class SceneType { Title, MainGame, Max };
```

## インクルード

自ファイルに対応するヘッダーを先頭に置き、1 行空けてから他の include を並べる:

| 優先順位 | ルール |
|------|------|
| 1 | 階層が浅い順（`/` の数が少ないものを上に） |
| 2 | 同一階層内はアルファベット順 |
| 3 | 相対パス（`../`）は絶対パスの後 |

### インクルードガード

- すべてのヘッダーで `#ifndef` インクルードガードを使う。Core Guidelines SF.8 がガードの無い `.h` を検査対象とし、`#pragma once` をベンダー拡張として退けている（標準でなく、移植的でなく、ホストのファイルシステムの意味論をプログラムに持ち込む）
- **ガード名をファイル名だけで付けない** — SF.8 はライブラリ名やコンポーネント名といった差別化要素を含めるよう求めている。同名のヘッダーが衝突しないようにするため

```cpp
// file foobar.h
#ifndef LIBRARY_FOOBAR_H
#define LIBRARY_FOOBAR_H
// ... declarations ...
#endif  // LIBRARY_FOOBAR_H
```

- **`Source/` 配下では逆になる**。Epic はすべてのヘッダーに `#pragma once` を要求しているため、Unreal 規約がこの節を上書きする（エンジン別が言語別に優先する）

### 前方宣言

- ヘッダーでの変数宣言、関数の引数・戻り値に使う型は前方宣言に統一する
- 型の実体（メンバーへのアクセス・サイズ・継承）が必要な `.cpp` でのみ実体をインクルードする

```cpp
// ✅ ヘッダーでは前方宣言する.
class Enemy;

class Player {
public:
    void SetTarget(const std::weak_ptr<Enemy>& target);

private:
    std::weak_ptr<Enemy> _target{};
};
```

## 引数

| 状況 | 使用する型 |
|------|------|
| 変更しない・値型（基本型やコピーの軽い型） | `const T`（値渡し。`const` 必須） |
| 変更しない・上記以外 | `const T&` |
| 変更する | `T&` |

- **関数内で変更しない引数は必ず `const` にする**（例外なし）。値型引数はトップレベル `const` 付きの値渡し（`const int playerId`）、それ以外は `const T&` にする。値渡し引数のトップレベル `const` は**プロジェクト規約**で、Core Guidelines F.16 も Epic も書いていない（F.16 の例は `void f3(int x);`）が、禁止もしていない。シグネチャの位置で「ここは書き換えない」と示せるため維持する
- 基本型は値渡し。基本型以外は参照渡し（大きい型の値渡しコピーは禁止）
- 引数は渡し方にかかわらず接頭辞なしの `camelCase`（`playerId`、`name`、`hitPoint`）。フィールドだけに印を付ける理由は「命名規則」の節を参照
- 宣言と定義で `const` の付け方をそろえる（ヘッダーとソースで表記を一致させる）

```cpp
// ❌ 変更しないのに const が付いていない.
void SetHitPoint(int hitPoint);
void AddPlayer(std::string name);

// ✅ 値型は const 値渡し. 値型以外は const 参照.
void SetHitPoint(const int hitPoint);
void AddPlayer(const std::string& name);

// ✅ 変更する引数は非 const 参照.
void Damage(int& hitPoint);
```

## クラス

- メンバ変数を変更しない関数（特にゲッター）は `const` メンバ関数にする
- メンバの宣言順: public 関数 → public 変数（やむを得ない場合のみ）→ private 関数 → private 変数
- グループの中は抽象度の降順に並べる（共通規約の「グループ内の宣言順」を参照）。コンストラクタとデストラクタは対にして、そのグループの先頭に置く
- **グループごとにアクセス修飾子を書き直す**。直前と同じ修飾子でも省略しない。
  繰り返し書かれた `public:` / `private:` が「今どのグループを読んでいるか」を示す区切りになる。
  省略すると関数と変数が 1 つの塊に見えてしまう

```cpp
class VulkanInstance
{
public:
    VkInstance Get() const;

private:
    void Destroy() noexcept;

private:
    VkInstance _instance{};
};
```

グループの中は、その型が外から呼ばれる入口から、上のメンバーが組み立てに使う最小単位へと降りていく:

```cpp
class InventoryWindow
{
public:
    InventoryWindow();            // ✅ コンストラクタとデストラクタは対にして先頭。
    ~InventoryWindow();

    void Open();                  // ✅ その型が存在する理由がグループの先頭。
    void Close();                 //    Close は Open と対なので隣接させ、自然な順に書く。

    void Update();                // ✅ 開いている間に動く処理が次に来る。
    void Draw() const;            //    2 つは呼ばれる順に並べる。

    bool IsOpen() const;          // ✅ 問い合わせは最後。上のメンバーすべてが使い得る材料。
    int GetSelectedIndex() const;

private:
    void RebuildItemList();       // ✅ Open と Update から呼ばれるので、自分のグループの中で
    void ApplyFilter();           //    それらより下。ApplyFilter は RebuildItemList から呼ばれる。

private:
    bool _isOpen{};
    int _selectedIndex{};
};
```

### 機能グループの明示

複数のサブシステムを駆動するクラスは、メンバーが **機能グループ** に分かれる（インベントリの 3 つ、次にショップの 3 つ）。各機能グループには区切りコメント `//--- <名前> ---` を、そのグループの先頭メンバー（そのメンバー自身の 1 行コメントを含めた塊）の直上・メンバーと同じインデントで置く。ファイルヘッダーの `//` + ハイフンの見た目を借りて左右 3 本に縮め、桁は揃えない形で、範囲を囲む記法と違って閉じ忘れる対象が無い。区切り線は印であって文章ではないので、末尾ピリオドは付けない。

```cpp
class LobbyScene
{
public:
    //--- 画面の開閉 ---
    // ロビーに入る. 子ウィンドウはすべて閉じた状態から始まる.
    void Enter();

    // ロビーから出る. 開いている子ウィンドウはここで閉じる.
    void Exit();

    //--- インベントリ ---
    // インベントリを開く. 既に開いていれば何もしない.
    void OpenInventory();

    // インベントリを閉じる. ショップの開閉には影響しない.
    void CloseInventory();

    // 選択中の所持品の番号. 未選択なら -1.
    int GetSelectedItemIndex() const;

    //--- ショップ ---
    // ショップを開く. インベントリは自動で閉じる.
    void OpenShop();

    // ショップを閉じる.
    void CloseShop();

    // 購入に使える通貨の残量.
    int GetAvailableCurrency() const;
};
```

- **機能グループは 1 つのアクセス区分の内側に収まり**、2 つの区分に跨らない。4 つのアクセス区分の順序は相変わらず変えない。上記「グループごとにアクセス修飾子を書き直す」はそのアクセス区分の話で、機能グループに `public:` を付け直すわけではない
- 機能グループの中では共通規約の抽象度の降順がそのまま効くので、**問い合わせ・述語はその機能グループの末尾** に来る。アクセス区分の末尾へ集約しない。機能グループを使う場合の「問い合わせ・述語は最後」はこう解決する
- ハイフンは左右ちょうど 3 本、名前の前後に半角スペース 1 つ。**桁を揃えるための埋め草は入れない** — 名前を変えるたびに数え直しが必要で、全角の名前が入ると狙いの桁数が曖昧になる
- 名前が指すのはグループであってメンバーではない。3 語以内の名詞で、動詞は使わない。機能グループが 1 つだけのクラスには区切り線を置かない
- ヘッダーだけに書く。`.cpp` はヘッダーの並びをメンバー単位でそのまま繰り返すので、機能グループの境目はヘッダーで読む。定義側にも書くと同じ名前を 2 箇所で保守することになる
- **新しいメンバーは所属する機能の区切り線の直下に入れる。アクセス区分の末尾に足さない。** 機能グループの最後のメンバーが居なくなったら、同じ変更で区切り線も消す。機能名を変えたら同じ変更で区切り線も変える — 配下のメンバーを説明しなくなった区切り線は陳腐化したコメントである

## Rule of 0

- コンストラクタ・デストラクタ・コピー・ムーブは既定では **自前実装しない**
- リソース管理はスマートポインタ（`unique_ptr` / `shared_ptr`）やコンテナに委ね、正しい挙動を自動で得る
- 手動のリソース管理が避けられない場合は、Rule of 5 を適用した専用ラッパークラスに閉じ込める。そのラッパーを使う側は Rule of 0 のまま

### 1 ラッパー 1 リソース

Rule of 5 のラッパーが持つ生ハンドルは**ちょうど 1 つ**にする。1 クラスに 2 つ持たせると、
デストラクタ・ムーブ構築・ムーブ代入のすべてで両方を扱う必要があり、1 行の書き漏らしが
リークか二重解放になる。都合ではなくリソース単位で分ける。所有に対して単一責任の原則を
適用したもの。

そのラッパー専用のヘルパーは、共有ファイルにもヘッダーにも置かず、そのラッパーの
翻訳単位に閉じ込める。

あるリソースを別のリソースより先に解放する必要がある場合（Vulkan のデバッグメッセンジャーと
インスタンスなど）は、宣言順・生成順に頼る。メンバーもローカル変数も逆順で破棄されるため。
ただし**その依存関係はコメントで明示する**。コードのどこを読んでも分からないため。

```cpp
// ✅ Rule of 0: 所有をスマートポインタに委ねる.
class Player {
private:
    std::unique_ptr<Weapon> _weapon{};
};

// ❌ 手書きのデストラクタと所有する生ポインタ.
class Player {
public:
    ~Player() { delete _weapon; }

private:
    Weapon* _weapon{};
};
```

## 命名規則

- 型・クラス: `PascalCase`
- 関数・メソッド: `PascalCase`（プロジェクトの慣習。本書の例もこれに従う）
- 定数: `k` + `PascalCase`（`kMaxHealth`）。`UPPER_SNAKE_CASE` にはしない — Core Guidelines NL.9 が `ALL_CAPS` をマクロ名専用とし、マクロでない `ALL_CAPS` 名を検査対象にしている（スコープと型の規則に従う名前がマクロに見えないようにするため）。`k` は、同じく `PascalCase` の型や関数と定数を見分けるための印（Unity 規約の `k_` と同じ役割）
- 名前空間: `lowercase`
- フィールド: インスタンスフィールドは `_` + `camelCase`（`_instance`、`_isValidationEnabled`）、
  static は `s_` + `camelCase`（`s_callCount`。関数内の `static` も含む）。使用箇所で記憶域とスコープを
  示すものが他に無いのでこの 2 つだけ印を付ける。ポインターと参照には付けない（型は宣言が示している）。
- `_` の次に大文字を置く形（`_PlayerId`）と、`__` を含む識別子は**書かない**。規格はどちらも
  あらゆるスコープで処理系に予約している。`_` + 小文字はグローバル名前空間の名前としてのみ予約なので、
  メンバとローカルでは `_camelCase` が安全。名前空間スコープの変数は代わりに `s_` を付ける。
- Unreal のコードは、食い違う範囲では Unreal 規約の Epic 命名に従う（エンジン別 > 言語別）。

## フォーマット

- **clang-format** を使う — スタイル論争はしない
- コミット前に `clang-format -i <file>` を実行する
