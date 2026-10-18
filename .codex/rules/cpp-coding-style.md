---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.hh"
  - "**/*.cxx"
  - "**/*.h"
  - "**/CMakeLists.txt"
---
# C++ Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with C++ specific content.
> Japanese reference translation: `docs/ja-JP/rules/cpp/coding-style.md`.

## Official Sources

Plain C++ has no official naming convention, so this project decides its own — but two documents
still bind it. Where this file disagrees with them, they are right and this file is the bug. Read
the original, not a summary of it:

- [C++ working draft, `[lex.name]`](https://eel.is/c++draft/lex.name) — reserved identifiers. The
  field rule below is derived from it
  ([Markdown source](https://raw.githubusercontent.com/cplusplus/draft/main/source/lex.tex))
- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines) — NL.5 condemns
  encoding a type in a name, but exempts `m_` and `p` explicitly
  ([Markdown source](https://raw.githubusercontent.com/isocpp/CppCoreGuidelines/master/CppCoreGuidelines.md))

## Modern C++ (C++17/20/23)

- Prefer **modern C++ features** over C-style constructs
- Use `auto` when the type is obvious from context
- Use `constexpr` for compile-time constants
- Use structured bindings: `auto [key, value] = map_entry;`

## Resource Management

- **RAII everywhere** — no manual `new`/`delete`
- Use `std::unique_ptr` for exclusive ownership
- Use `std::shared_ptr` only when shared ownership is truly needed
- Use `std::make_unique` / `std::make_shared` over raw `new`

### Ownership in Signatures

| Situation | Type |
|------|-----------|
| Not accessed after the call | Pass by reference |
| Share ownership (copied and kept) | `const shared_ptr<T>&` |
| No ownership required | `const weak_ptr<T>&` |
| Take ownership and manage it | `shared_ptr<T>&&` (move) |
| Return without transferring ownership | `weak_ptr<T>` (by default) |
| Return and transfer ownership | `shared_ptr<T>` |

## Initialization

Braces `{}` give a variable the type's default value. Give it any other starting value with `=`. Use `()` only where `=` cannot work: the constructor is `explicit`, or braces would select a different overload. Never leave a narrowing conversion implicit — write it with `static_cast`. Braces are the check here: `int32_t count{wideValue};` does not compile, while `int32_t count = wideValue;` truncates in silence.

```cpp
// ✅ The type's default value — always braces {}.
int tmp{};                  // = 0
float value{};              // = 0.0f
bool flag{};                // = false
std::string name{};         // = ""
std::vector<int> values{};  // = an empty vector
MyClass* node{};            // = nullptr

// ✅ Any other value — initialize with =.
int hitPoint = 100;
float speed = 0.5f;
bool isAlive = true;
std::string label = "Player";
std::vector<int> indices = { 1, 2, 3 };  // A braced list after = supplies elements, so it is fine.

// ✅ = cannot work (an explicit constructor, or braces would select another overload) — use ().
std::lock_guard<std::mutex> lock(_mutex);  // lock_guard's constructor is explicit.
std::vector<int> buffer(5);  // = five zero-initialized elements, while {5} would be one element of value 5.

// ✅ A conversion to a narrower type is written out, never left implicit.
int32_t count = static_cast<int32_t>(received);  // received is int64_t, and the narrowing is deliberate.

// ❌ Do not give a variable a non-default value through the declaration's own braces.
int hitPoint{100};

// ❌ Do not leave a narrowing conversion implicit. int32_t count{received}; fails to compile, which is the check.
int32_t count = received;
```

## Enums

```cpp
// ❌ An unscoped enum pollutes the namespace.
enum SceneType { Title, MainGame, Max };

// ✅ Use enum class only. It also allows forward declaration.
// ✅ Enumerators are PascalCase, with Max defined last.
// ❌ Never ALL_CAPS: Core Guidelines Enum.5 flags it, because a third-party macro of the same name
//    (#define RED) turns the enumerator into a syntax error.
enum class SceneType { Title, MainGame, Max };
```

## Includes

Put the header matching this file first, then a blank line, then the other includes:

| Priority | Rule |
|------|------|
| 1 | Shallower paths first (fewer `/`) |
| 2 | Alphabetical within the same depth |
| 3 | Relative paths (`../`) after absolute ones |

### Include Guard

- Use an `#ifndef` include guard in every header. Core Guidelines SF.8 flags a `.h` without one, and
  rejects `#pragma once` as a vendor extension: it is not standard, not portable, and it injects the
  host filesystem's semantics into the program
- **Do not name the guard after the file alone** — SF.8 asks for a differentiator such as the library
  or component the header belongs to, so that two headers of the same name cannot collide

```cpp
// file foobar.h
#ifndef LIBRARY_FOOBAR_H
#define LIBRARY_FOOBAR_H
// ... declarations ...
#endif  // LIBRARY_FOOBAR_H
```

- **Inside `Source/` this is reversed**: Epic requires `#pragma once` on every header, so the Unreal
  rule overrides this section there — engine rules outrank language rules

### Forward Declaration

- Types used only in header declarations, parameters, and return types get a forward declaration; include the full definition only in the `.cpp` that needs it (member access, size, inheritance)

```cpp
// ✅ Forward-declare in headers.
class Enemy;

class Player {
public:
    void SetTarget(const std::weak_ptr<Enemy>& target);

private:
    std::weak_ptr<Enemy> _target{};
};
```

## Parameters

| Situation | Type |
|------|------|
| Not modified, value type (primitive / small copyable) | `const T` (by value, `const` required) |
| Not modified, everything else | `const T&` |
| Modified | `T&` |

- **Every parameter the function does not modify must be `const`** — no exceptions. Value-type parameters get a top-level `const` (`const int playerId`), all others get `const T&`. The top-level `const` on a by-value parameter is a **project rule**: neither Core Guidelines F.16 nor Epic writes it (F.16's example is `void f3(int x);`), and neither forbids it either. It is kept because it states "this is not rewritten" at the signature
- Pass primitive types by value; pass non-primitive types by reference — by-value copies of large types are forbidden
- Parameters are `camelCase` with no prefix, whatever they are passed by (`playerId`, `name`, `hitPoint`) — see the field rule under "Naming Conventions" for why only fields carry a marker
- Write the same `const` in the declaration and the definition so header and source stay identical

```cpp
// ❌ Not modified, yet not const.
void SetHitPoint(int hitPoint);
void AddPlayer(std::string name);

// ✅ Value type → const by value. Non-value type → const reference.
void SetHitPoint(const int hitPoint);
void AddPlayer(const std::string& name);

// ✅ Modified → non-const reference.
void Damage(int& hitPoint);
```

## Classes

- Mark member functions `const` when they do not modify members (getters especially)
- Member declaration order: public functions → public variables (only when unavoidable) → private functions → private variables
- Inside one group, order by descending level of abstraction — see "Declaration Order Within a Group" in the common rule. The constructor and the destructor pair at the top of their group
- **Repeat the access specifier for every group**, even when it is the same as the one above.
  The repeated `public:` / `private:` is what tells a reader which of the four groups they are in;
  without it, functions and variables blur into one block.

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

Within a group, the order runs from the way the type is entered down to the primitives the members above are built from:

```cpp
class InventoryWindow
{
public:
    InventoryWindow();            // ✅ The constructor and the destructor pair at the top.
    ~InventoryWindow();

    void Open();                  // ✅ The reason the type exists leads the group.
    void Close();                 //    Close pairs with Open, in the natural order.

    void Update();                // ✅ What runs while the window is open comes next,
    void Draw() const;            //    in the order the two are called.

    bool IsOpen() const;          // ✅ Queries last — every member above may use them.
    int GetSelectedIndex() const;

private:
    void RebuildItemList();       // ✅ Called by Open and Update, so it sits below them
    void ApplyFilter();           //    in its own group; ApplyFilter is called by RebuildItemList.

private:
    bool _isOpen{};
    int _selectedIndex{};
};
```

### Marking Feature Groups

A class that drives several subsystems holds its members in **feature groups** — the inventory trio, then the shop trio. Mark each feature group with a divider comment `//--- <name> ---` directly above the first member of that group, counting the member's own one-line comment as part of it, at the member indent. It borrows the file header's `//` + dashes look, cut down to three dashes a side and never padded out, and unlike a range marker it has nothing to leave unclosed. The divider is a marker, not prose, so the trailing period does not apply to it.

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

- A **feature group** lives inside one access group and never spans two. The four access groups are still never reordered, and the "Repeat the access specifier for every group" rule above is about those access groups — a feature group does not get a `public:` of its own
- Inside a feature group the common rule's descending abstraction applies as usual, which means **queries and predicates come last within their own feature group** instead of being collected at the end of the access group. That is how "Queries and predicates come last" resolves once feature groups exist
- Exactly three dashes on each side, one space around the name. **Do not pad the line out to a fixed column** — the padding would need recounting every time a name changes, and a full-width name makes the intended width ambiguous
- The name labels the group, not the member: a noun of at most three words, no verb. A class with a single feature group needs no divider at all
- Header only. The `.cpp` repeats the header's order member for member, so the feature group boundaries are read from the header; repeating the dividers on the definitions would mean maintaining the same names in two places
- **A new member goes directly under the divider of the feature it belongs to, never at the end of the access group.** A feature group's last member leaving takes its divider with it in the same change, and renaming a feature renames its divider in the same change — a divider that no longer describes the members below it is a stale comment

## Rule of 0

- Do **not** hand-write any of the constructor / destructor / copy / move operations by default
- Delegate resource management to smart pointers (`unique_ptr` / `shared_ptr`) or containers so correct behavior comes for free
- When manual resource management is unavoidable, isolate it in a dedicated wrapper class that applies the Rule of 5; every user of that wrapper stays at Rule of 0

### One Wrapper, One Resource

A Rule-of-5 wrapper owns **exactly one** raw handle. Two handles in one class means the destructor,
the move constructor, and move assignment each have to juggle both, and one missed line leaks or
double-frees. Split by resource, not by convenience — this is the Single Responsibility Principle
applied to ownership.

Helpers that exist only to serve one wrapper belong to that wrapper's own translation unit, not to
a shared file and not to the header.

When one resource must be released before another — a Vulkan debug messenger before its instance —
rely on declaration and construction order, since members and locals are destroyed in reverse.
**State that dependency in a comment**, because nothing else in the code reveals it.

```cpp
// ✅ Rule of 0: delegate ownership to a smart pointer.
class Player {
private:
    std::unique_ptr<Weapon> _weapon{};
};

// ❌ Hand-written destructor and raw owning pointer.
class Player {
public:
    ~Player() { delete _weapon; }

private:
    Weapon* _weapon{};
};
```

## Naming Conventions

- Types/Classes: `PascalCase`
- Functions/Methods: `PascalCase` (project convention, as used in the examples)
- Constants: `k` + `PascalCase` (`kMaxHealth`). Not `UPPER_SNAKE_CASE` — Core Guidelines NL.9
  reserves `ALL_CAPS` for macro names and flags non-macro `ALL_CAPS` names, so that a name obeying
  scope and type rules never reads as a macro. The `k` is what keeps a constant distinguishable
  from a type or a function, which are `PascalCase` too (the Unity rule uses `k_` for the same job)
- Namespaces: `lowercase`
- Fields: an instance field is `_` + `camelCase` (`_instance`, `_isValidationEnabled`); a static
  one is `s_` + `camelCase` (`s_callCount`), a function-local `static` included. Nothing else
  marks storage or scope where the name is used, which is why these two carry a marker.
  Pointers and references carry none — the declaration already states the type
- Never write `_` followed by an uppercase letter (`_PlayerId`) or an identifier containing `__`:
  the standard reserves both to the implementation for any use. `_` + lowercase is reserved only
  as a name in the global namespace, so `_camelCase` is safe on a member and on a local, and a
  namespace-scope variable takes `s_` instead
- Unreal code follows the Epic naming convention in the Unreal engine rule where the two differ —
  engine rules outrank language rules

## Formatting

- Use **clang-format** — no style debates
- Run `clang-format -i <file>` before committing
