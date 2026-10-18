# コーディングスタイル（Rust）

> 正本: `.claude/rules/rust/coding-style.md`（英語）。
> [共通ルール](../common/coding-style.md)を Rust 固有の内容で拡張したもの。

## 一次情報

要約ではなく原文を読む。下記の命名表の全行を 1 本で裏付けられる文書は無いので、3 本とも必要:

- [rustc lint 一覧（warn-by-default）](https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html) —
  実際に強制される分で、下記「使い分けの原則」が委ねる先。`non_snake_case` が変数・名前付き
  フィールド・モジュール、`non_camel_case_types` が型・トレイト・列挙の値、
  `non_upper_case_globals` が `static` を覆う
- [Rust Style Guide "Other style advice"](https://raw.githubusercontent.com/rust-lang/rust/master/src/doc/style-guide/src/advice.md) —
  3 本のうち構造体フィールドと予約語回避（`r#crate` / `crate_`）を定めているのはここだけ
- [Rust API Guidelines - Naming](https://rust-lang.github.io/api-guidelines/naming.html) —
  モジュール・トレイト・型引数・ライフタイム、および `as_` / `to_` / `into_` と `iter` の
  メソッド命名体系。構造体フィールドと引数は定めていない

## 使い分けの原則

言語に依存しない部分は共通ルールに従う。Rust と衝突する場合は、
**stable のツールの設定で共通ルールを満たせるか**で判断する。

- **stable で設定できるもの**（行幅、インデント）→ **共通ルールを優先し**、`rustfmt` の設定を合わせる。
  `rust/rustfmt.toml` を参照
- **`rustc` の既定 lint が強制するもの**（主に命名）→ **Rust を優先する**。既定 lint に逆らうと
  ビルドのたびに警告が出るため、割に合わない
- **nightly でしか設定できないもの**（波かっこの位置）→ **Rust を優先する**。整形の好みのために
  プロジェクトを未安定のツールチェーンに縛るのは代償が大きすぎる

判断は `cargo fmt` と `cargo clippy` に委ねる。この文書とツールの言い分が食い違ったら、
正しいのはツールであり、この文書のほうがバグである。

## そのまま引き継ぐもの

- **不変性** — Rust の束縛は既定で不変。変更が必要な箇所だけ `mut` を付ける
- **KISS / DRY / YAGNI**、および SOLID・デメテルの法則
- **ファイル構成** — 小さいファイルを多く。目安 200〜400 行、最大 800 行。種類別ではなく機能別に分ける
- **エラー処理** — エラーを黙って握りつぶさない。境界で入力を検証する
- **名前の質** — 略語や 1 文字の名前を使わない（ループの `i` / `j` は例外）、型名を繰り返さない、
  否定形の真偽値を作らない（`is_not_alive` ではなく `is_dead`）、手段ではなく役割で命名する
- **真偽値の接頭辞** — `is_` / `has_` / `should_` / `can_`
- **検索・イベントの動詞** — 検索する関数には `find`、イベントハンドラーは `on_` で始める
- **制御構文** — 前後に空行を 1 つ入れる。深いネストより早期リターン。マジックナンバーを書かない
- **コメントは日本語** — 各行の末尾に半角ピリオド `.` を付ける、全角と半角の間に半角スペースを入れる、
  `-er` / `-or` / `-ar` のカタカナ語尾には長音記号を付ける。残作業は `// TODO:`、注意書きは `// NOTE:`、
  2 行以上になる場合はラベルの直後で改行する
- **体裁** — インデント 4 スペース、1 行 120 文字、末尾に空行 1 つ。`rustfmt.toml` で機械的に適用する

## 異なるもの

### 命名

| 対象 | 共通ルール | Rust のルール | 理由 |
|------|------|------|------|
| 関数・メソッド | `PascalCase` | `snake_case` | `non_snake_case` lint |
| 変数・フィールド | `camelCase` | `snake_case` | `non_snake_case` lint |
| 引数 | `camelCase`（接頭辞なし） | `snake_case`（接頭辞なし） | Rust で先頭の `_` は「意図的に未使用」の意味になる |
| フィールド | `_camelCase`（static は `s_camelCase`） | `snake_case`（接頭辞なし） | フィールドは常に `self` 経由で参照するため |
| 型・トレイト | `PascalCase` | `PascalCase` | 同じ |
| 定数・static | C++ は `kPascalCase`、C# は `PascalCase` | `SCREAMING_SNAKE_CASE` | `non_upper_case_globals` lint。`ALL_CAPS` を求めるのはここでは Rust だけ |
| enum の値 | `PascalCase`、末尾が上限 | `PascalCase`、`Max` は作らない | `non_camel_case_types` lint |
| モジュール・ファイル名 | — | `snake_case` | `non_snake_case` lint |
| 非同期関数 | `Async` 接尾辞 | 接尾辞なし | `async fn` はシグネチャ上すでに明示されている |

**上限を示す番兵は定義しない。** C++ / C# では列挙の範囲を示すために使うが、Rust は `match` の
網羅性検査があるため不要で、番兵があると全ての `match` に無意味な腕が増える。

```rust
// ❌ 共通規約をそのまま持ち込んだ形.
enum SceneType { Title, MainGame, Max }

// ✅ Rust の規約. 番兵は作らない.
enum SceneType {
    Title,
    MainGame,
}
```

### ファイルヘッダー

C++ で使う `///` は「直後の要素を説明する」ドキュメントコメントなので、ファイル先頭に単独で置くと
コンパイルエラー（`E0585`）になる。`//!` を使う。これはモジュール自身の説明になり、`cargo doc` にも載る。

```rust
//---------------------------------------
//! @file   main.rs
//!
//! @brief  Vulkan で三角形を描画するアプリケーションのエントリーポイント.
//!
//! @date   2026/08/16
//!
//! @author <作成者名>
//---------------------------------------
```

要素に対しては通常どおり `///` を使う。C++ / C# の `/// <summary>` という XML 形式は使わない。
`rustdoc` は Markdown を解釈するので、素の Markdown で書き、`# Errors` / `# Panics` / `# Safety` の
見出しを使う。

### 文字コード

Rust のソースは共通ルールと違い **BOM なしの UTF-8** とする。Rust のエコシステム、`cargo`、
公開されているクレートはいずれも BOM が無い前提で作られている。

### スマートポインター表の代わりに所有権

共通ルールの `shared_ptr` / `weak_ptr` の表は適用しない。Rust では同じ情報を型で表す。

| 状況 | 使用する型 |
|------|------|
| 読むだけ。保持しない | `&T` |
| 変更する。保持しない | `&mut T` |
| 呼ばれた側が所有権を受け取る | `T` |
| 共有所有が本当に必要 | `Rc<T>` / `Arc<T>` |
| 共有所有かつ変更もする | `Rc<RefCell<T>>` / `Arc<Mutex<T>>` — 理由をコメントに書く |

`Rc` / `Arc` は、単一の所有者にすることがどうしてもできない場合にだけ使う。多くの場合は
「どこか 1 か所が持つ」形に組み替えたほうが単純で速い。

### Rule of 0 は Drop に対応する

C++ の Rule of 0 はそのまま移せる。**通常の型に `impl Drop` を書かない。** メモリの解放は所有権が
面倒を見る。`Drop` を書くのは、明示的な後始末が要るリソース（`ash` が返す Vulkan のハンドル、
ファイルディスクリプター、ロックなど）専用のラッパー型だけにし、その利用側には後始末を書かせない。

### エラー処理

- `Result<T, E>` を返し、`?` で伝播させる。回復可能な失敗で panic しない
- `unwrap()` / `expect()` を使ってよいのは、テスト、起動時に落として良い `main` の中、
  そして「起こり得ない」ことをコメントで示せる箇所だけ
- `expect("...")` のメッセージには、呼び出した処理名ではなく**破られた前提**を書く

### unsafe

`ash` は薄いバインディングなので、Vulkan の呼び出しはほとんどが `unsafe` になる。影響範囲を閉じ込める。

- `unsafe` ブロックは可能な限り小さくする。関数全体を包まない
- `unsafe` ブロックには必ず `// SAFETY:` コメントを付け、健全性を保証している前提を書く
- 安全なラッパーを用意し、`unsafe` を呼び出し側に漏らさない

### 整形

整形は `rustfmt` が行い、設定できる範囲は `rust/rustfmt.toml` で指定する。行幅 120 文字と
インデント 4 スペースは共通ルールから取っている。

**波かっこの位置だけは例外。** Rust は開きかっこを同一行に置くため、C++ 側（Allman）とは見た目が異なる。

```rust
fn main() {
    if is_ready {
        run();
    } else {
        wait();
    }
}
```

`brace_style` と `control_brace_style` を使えば変更できるが、これらは `rustfmt` の**未安定オプション**で
nightly ツールチェーンでしか使えない。波かっこの配置のためにプロジェクトを nightly に縛るのは
割に合わないので、Rust の既定をそのまま採用する。

```bash
cargo fmt
```

```bash
cargo clippy
```

作業完了とする前に両方をきれいにする。共通ルールと違い、**桁を手で揃えない**（`rustfmt` が元に戻すため）。

## コード品質チェックリスト

作業完了とする前に確認する。

- [ ] `cargo fmt --check` が通る
- [ ] `cargo clippy` の警告が無い
- [ ] 許可された箇所以外に `unwrap()` / `expect()` が無い
- [ ] すべての `unsafe` ブロックに `// SAFETY:` コメントがある
- [ ] リソース用ラッパー以外に `impl Drop` が無い
- [ ] ファイルは 800 行未満、関数は 50 行未満
