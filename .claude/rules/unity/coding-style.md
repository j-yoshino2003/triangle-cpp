---
paths:
  - "**/Assets/**/*.cs"
  - "**/Packages/**/*.cs"
  - "**/*.asmdef"
---
# Unity Coding Style

> This file extends [csharp/coding-style.md](../csharp/coding-style.md) with Unity-specific content.
> Where the two conflict, Unity rules win inside `Assets/`.
> Japanese reference translation: `docs/ja-JP/rules/unity/coding-style.md`.

## Official Sources

Unity's own guide, not a project variant. Where this file disagrees with it, it is right and this
file is the bug. Read the original, not a summary of it:

- [Naming and code style tips for C# scripting in Unity](https://unity.com/ja/how-to/naming-and-code-style-tips-c-scripting-unity) —
  the page contradicts itself on field prefixes. Its prose names `m_` / `k_` / `s_` as its own
  style guide's choice, while every code example on it uses a bare `_` (`private bool _isDead;`,
  `private static int _myPrivate;`). **This file follows the examples**, which also agree with the
  C# official rule. The one prefix taken from the prose is `k_` on constants, which no example
  contradicts

## MonoBehaviour Lifecycle

Execution order:

```
Awake → OnEnable → Start → Update → LateUpdate → OnDisable → OnDestroy
                              ↑
                        FixedUpdate (physics)
```

| Timing | Purpose |
|------|------|
| `Awake` | Self-contained initialization |
| `Start` | Resolving references to other components |

- Unity message functions (`Awake`, `Update`, `OnTriggerEnter`, ...) need no XML comment — the engine calls them automatically

## MonoBehaviour Conventions

- One `MonoBehaviour` per file, file name matches the class name (Unity requires this)
- Prefer `[SerializeField] private` fields over `public` fields for Inspector exposure
- Cache component lookups in `Awake`/`Start` — never call `GetComponent` in `Update`
- Use `TryGetComponent` over `GetComponent` + null check

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

## Immutability Exception

The common rule "ALWAYS create new objects" is **relaxed** for Unity hot paths:

- `MonoBehaviour`/`ScriptableObject` lifecycles are engine-managed — never `new` them; use `AddComponent`, `Instantiate`, `ScriptableObject.CreateInstance`
- In per-frame code, reuse and mutate structs (`Vector3`, `Quaternion`) and pooled objects to avoid GC pressure
- Keep immutability for domain/game-logic models outside the frame loop

## Null Checks

- `UnityEngine.Object` overloads `==` — use `if (obj == null)` or implicit bool, never `is null` or `?.` on Unity objects
- Plain C# classes follow normal C# null-handling rules

## Async and Coroutines

- Use coroutines or `Awaitable` (Unity 6+) for frame-based timing
- Avoid `async void` except for Unity event handlers; exceptions are swallowed
- Always stop coroutines and unsubscribe events in `OnDisable`/`OnDestroy`

## Naming

- Types, methods, and public fields: `PascalCase`; parameters and locals carry no prefix
- Private and internal fields: `_` + `camelCase`, **static ones included** (`_isDead`, `_myPrivate`) — this is where Unity differs from plain C#, which puts `s_` on a static. Unity's examples use a bare `_` for both
- Hungarian notation is an outdated convention and `m_PascalCase` is uncommon in modern C#, so neither is used. Note that the page's point is about `m_` + `PascalCase`, not about `m_` in general
- Constants: `k_` + `PascalCase` (`k_MaxHealth`) — the other place Unity differs from plain C#, which uses bare `PascalCase`
- Enum names and members: `PascalCase`, no prefix or suffix. The project's last-member rule still applies, so define `Max` last
- Unity message methods (`Awake`, `Update`, `OnTriggerEnter`) keep exact engine spelling and stay `private`

## Inspector Attributes

```csharp
// ✅ Make use of the helper attributes.
[RequireComponent(typeof(Rigidbody))]
public sealed class PlayerMover : MonoBehaviour
{
    [Header("Movement settings")]
    [Tooltip("Movement speed per second.")]
    [Range(0f, 10f)]
    [SerializeField] private float _moveSpeed = 5f;
}
```

## Per-Frame Allocation

```csharp
// ❌ Frequent new or string concatenation inside Update causes GC allocations.
private void Update()
{
    _scoreLabel.text = "Score: " + _score;
}

// ✅ Update only when the value changes.
private void OnScoreChanged(int score)
{
    _scoreLabel.text = $"Score: {score}";
}
```

## Resource Loading

```csharp
// ❌ Avoid Resources.Load (legacy API).
GameObject prefab = Resources.Load<GameObject>("Player");

// ✅ Prefer Addressables.
AsyncOperationHandle<GameObject> handle = Addressables.LoadAssetAsync<GameObject>("Player");
```
