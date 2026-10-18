# コーディングスタイル（Unity）

> 正本: `.claude/rules/unity/coding-style.md`（英語）。
> [C# ルール](../csharp/coding-style.md)を Unity 固有の内容で拡張したもの。`Assets/` 配下では本ファイルが優先。

## 一次情報

プロジェクト独自の変種ではなく Unity 公式のガイドに従う。この文書と食い違ったら、正しいのは
一次情報でありこの文書のほうがバグである。要約ではなく原文を読む:

- [C# スクリプティングにおける命名とコードスタイルのヒント](https://unity.com/ja/how-to/naming-and-code-style-tips-c-scripting-unity) —
  このページはフィールドの接頭辞について**自己矛盾している**。散文は `m_` / `k_` / `s_` を
  「スタイルガイドが使っている形」として挙げるが、ページ内のコード例はすべて素の `_` を使う
  （`private bool _isDead;`、`private static int _myPrivate;`）。**本ファイルはコード例に従う**。
  これは C# 公式の規約とも一致する。散文から採ったのは定数の `k_` だけで、こちらは矛盾する例が無い

## MonoBehaviour ライフサイクル

実行順:

```
Awake → OnEnable → Start → Update → LateUpdate → OnDisable → OnDestroy
                              ↑
                        FixedUpdate（物理）
```

| タイミング | 用途 |
|------|------|
| `Awake` | 自己完結する初期化 |
| `Start` | 他コンポーネントの参照解決 |

- Unity の標準メッセージ関数（`Awake`、`Update` 等）には XML コメント不要（エンジンが自動的に呼び出すため）

## MonoBehaviour の作法

- 1 ファイル 1 `MonoBehaviour`。ファイル名はクラス名と一致させる（Unity の要件）
- Inspector 公開は `public` フィールドではなく `[SerializeField] private` を使う
- コンポーネント参照は `Awake` / `Start` でキャッシュする — `Update` 内で `GetComponent` を呼ばない
- `GetComponent` + null チェックより `TryGetComponent` を使う

```csharp
public sealed class PlayerMovement : MonoBehaviour
{
    [SerializeField] private float _moveSpeed = 5f;
    private Rigidbody _cachedRigidbody;

    private void Awake()
    {
        _cachedRigidbody = GetComponent<Rigidbody>();
    }
}
```

## 不変性の例外

共通ルールの「常に新しいオブジェクトを生成」は Unity のホットパスでは**緩和**される:

- `MonoBehaviour` / `ScriptableObject` のライフサイクルはエンジン管理 — `new` せず `AddComponent`、`Instantiate`、`ScriptableObject.CreateInstance` を使う
- 毎フレームのコードでは、GC 圧を避けるため構造体（`Vector3`・`Quaternion` 等）やプールされたオブジェクトを再利用・書き換えしてよい
- フレームループ外のドメイン・ゲームロジックのモデルは不変性を維持する

## null 判定

- `UnityEngine.Object` は `==` がオーバーロードされている — `if (obj == null)` か暗黙の bool 変換（`if (obj)`）を使い、`is null` や `?.` は使わない
- 通常の C# クラスは通常の null 処理に従う

## 非同期とコルーチン

- フレームベースのタイミングにはコルーチンまたは `Awaitable`（Unity 6+）を使う
- Unity イベントハンドラー以外で `async void` を避ける（例外が握りつぶされる）
- コルーチンの停止・イベント購読解除は `OnDisable` / `OnDestroy` で必ず行う

## 命名

- 型・メソッド・public フィールドは `PascalCase`。引数とローカルは接頭辞なし
- private / internal のフィールドは `_` + `camelCase`。**static も含める**（`_isDead`、`_myPrivate`）— ここが素の C# との差で、C# 側は static に `s_` を付ける。Unity のコード例は両方とも素の `_`
- ハンガリアン記法は「古い規則」、`m_PascalCase` は「最近の C# では一般的でない」とされているので、どちらも使わない。ページが言っているのは `m_` + `PascalCase` についてで、`m_` 一般についてではない点に注意
- 定数: `k_` + `PascalCase`（`k_MaxHealth`）— 素の C# との差のもう 1 点で、C# 側は `PascalCase` のみ
- 列挙型の名前とメンバー: `PascalCase`、prefix / suffix は付けない。プロジェクトの「最後のメンバー」規約は維持するので `Max` を最後に定義する
- Unity メッセージ関数（`Awake`、`Update`、`OnTriggerEnter`）はエンジンの綴りを維持し `private` とする

## Inspector 補助属性

- `[RequireComponent]`、`[Header]`、`[Tooltip]`、`[Range]` などの補助属性を活用する

```csharp
// ✅ 補助属性を活用する.
[RequireComponent(typeof(Rigidbody))]
public sealed class PlayerMover : MonoBehaviour
{
    [Header("Movement settings")]
    [Tooltip("Movement speed per second.")]
    [Range(0f, 10f)]
    [SerializeField] private float _moveSpeed = 5f;
}
```

## 毎フレームのアロケーション

- `Update` 内での `new` や文字列連結は GC Alloc を発生させる — 値が変わったときだけ更新する

```csharp
// ❌ Update 内の頻繁な new や文字列連結は GC Alloc を起こす.
private void Update()
{
    _scoreLabel.text = "Score: " + _score;
}

// ✅ 値が変わったときだけ更新する.
private void OnScoreChanged(int score)
{
    _scoreLabel.text = $"Score: {score}";
}
```

## リソースの読み込み

- `Resources.Load` は使わない（レガシー API のため避ける）— Addressables を優先する

```csharp
// ❌ Resources.Load は避ける（レガシー API）.
GameObject prefab = Resources.Load<GameObject>("Player");

// ✅ Addressables を優先する.
AsyncOperationHandle<GameObject> handle = Addressables.LoadAssetAsync<GameObject>("Player");
```
