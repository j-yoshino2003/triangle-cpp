---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.hh"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.cs"
  - "**/*.csx"
  - "**/*.rs"
  - "**/CMakeLists.txt"
---
# Code Layout Rules

> Loaded only when a source file is read or edited (see `paths:` above). The design rules that
> always apply live in `coding-style.md` (`common-coding-style.md` in the Codex and Antigravity
> copies).
> Japanese reference translation: `docs/ja-JP/rules/common/code-layout.md`.

## File Format

| Item | Rule |
|------|------|
| Encoding | UTF-8 with BOM |
| End of file | One trailing blank line |
| Indent | 4 spaces |
| Max line length | 120 characters |

File headers use a dedicated format, separate from normal comment rules.
**Leave exactly one blank line between the header block and whatever follows it** — `#pragma once`,
the first `#include`, or the first `using`. The header describes the file; what follows is code, and
the blank line is what keeps the two from reading as one block.

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

## Include / Using Order

- For `#include`, shallower paths come first (fewer `/`), alphabetical within the same depth; `using` directives sort alphabetically

```cpp
// ✅ Shallower paths first.
#include "System/Core.h"
#include "System/Memory/Allocator.h"
```

## Declaration Order Within a Group

Each language rule defines the **groups** a declaration belongs to (C++: public functions → public variables → private functions → private variables). **Groups are never reordered.** Inside one group, one principle decides the order.

**Descending level of abstraction — the caller above, the callee below** (vertical ordering, the stepdown rule). A group opens with the way the type is entered from outside and closes with the primitives the members above are built from, so the group reads as a top-down narrative:

- The reason the type exists leads the group (`Open` / `Close` for a window)
- What runs while the type is in that state follows (`Update` / `Draw`)
- Queries and predicates come last (`IsOpen`, `GetSelectedIndex`) — every member above may use them, which makes them the group's primitives, not its subject
- A dispatcher precedes the branches it dispatches to, and each branch precedes what it delegates to in turn: depth in the call graph is depth in the file

Two rules sit on top of the principle:

1. **Pairs stay adjacent, in their natural order** — `Open` / `Close`, `Acquire` / `Release`, `Begin` / `End`, a getter with its setter, an overload set, and the constructor with the destructor. Pairing outranks abstraction level: a destruction contract is only readable next to its construction contract, so the two sit together at the top of their group instead of at its two ends
2. **At equal abstraction, order by the sequence they are called in** — `Initialize` before `Update`, `Open` before `Draw`

**A new member is inserted where the principle puts it — never appended to the end of its group.** Appending is how a group's order decays: the group ends up in the order the features were added, which no reader can predict. Where the principle is silent, keep the order already there — reordering equals adds diff noise and nothing else.

Abstraction descends **within** a group, not across groups. A private helper called by a public function stays in the private group, however close to its caller it would read. Group order wins.

A source file defines its members in the declaration order of its header, group by group and member by member.

In review, raise an ordering issue only when a member is clearly out of place under the principle or rule 1. A tie you would have broken differently is not a finding.

## Types and Values

```csharp
float speed = 0.5f;         // ✅ Always suffix float literals with f.
int count = GetCount();     // ✅ State the type explicitly where it aids readability.
                            //    (C++: auto is fine when the type is obvious — the cpp rule wins.)
```

```csharp
// ❌ A local variable used only once in its scope.
int total = basePrice * quantity + shippingFee;
return total;

// ✅ Return directly; extract a function if the expression is complex.
return CalculateTotalPrice(basePrice, quantity, shippingFee);
```

## Prefer Concise Expressions

Replace control statements with LINQ / STL algorithms for filtering, transforming, and aggregating:

```csharp
// ✅ C#: LINQ (Where, Select, FirstOrDefault, ...).
List<string> names = players.Where(player => player.IsAlive)
                            .Select(player => player.Name)
                            .ToList();
```

```cpp
// ✅ C++: STL algorithms (find_if, transform, any_of, ...).
auto it = std::find_if(players.begin(), players.end(),
                       [](const Player& player) { return player.IsAlive(); });
```

## Control Flow

- **Braces required** for `if` / `else if` / `else` / `for` / `while` / `do-while`, even single statements
- **Merge duplicated conditions** that lead to the same result: `if (isDead || hitPoint <= 0)`
- **Hoist loop-invariant computations** out of the loop body
- **Ternary operator**: allowed only when the whole line fits under 120 characters; otherwise use `if` / `else`
- **switch**: put `default` first; extract multi-line case bodies into functions; consider the State pattern when behavior varies greatly per state
- **while**: reserve `while (true)` for intentional infinite loops; use `for` / `do-while` otherwise
- **Multi-line conditions**: once a condition spans 2 or more lines, break right after each `||` / `&&` and align the operands
- **Surrounding blank lines**: always leave one blank line before and after a control statement, including between consecutive control statements

```csharp
// ✅ Two lines or more: break after || / && and align the operands.
if (player.IsAlive() &&
    player.GetHitPoint() > 0 &&
    !player.IsStunned())
{
    Attack(player);
}
```

```csharp
int damage = CalculateDamage(attacker, defender);

// ✅ One blank line before and after every control statement.
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

## Blank Lines

| Position | Blank line |
|------|------|
| Around member declarations | One |
| Around type-level braces | One |
| Just inside braces (`{` after / `}` before) | None |
| Before and after a control statement | One |
| Between consecutive control statements | One |
