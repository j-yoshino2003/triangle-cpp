---
paths:
  - "**/*.cs"
  - "**/*.csx"
---
# C# Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with C#-specific content.
> Japanese reference translation: `docs/ja-JP/rules/csharp/coding-style.md`.

## Official Sources

This project follows the official C# conventions rather than a project variant. Where this file
disagrees with them, they are right and this file is the bug. Read the original, not a summary
of it:

- [C# identifier naming rules and conventions](https://learn.microsoft.com/ja-jp/dotnet/csharp/fundamentals/coding-style/identifier-names) —
  naming: `_camelCase` instance fields, `s_` / `t_` statics, `PascalCase` constants
- [C# Coding Conventions](https://learn.microsoft.com/ja-jp/dotnet/csharp/fundamentals/coding-style/coding-conventions) —
  language features. Naming lives on the page above, not here

## Standards

- Follow current .NET conventions and enable nullable reference types
- Prefer explicit access modifiers on public and internal APIs
- Keep files aligned with the primary type they define

## Types and Models

- Prefer `record` or `record struct` for immutable value-like models
- Use `class` for entities or types with identity and lifecycle
- Use `interface` for service boundaries and abstractions
- Avoid `dynamic` in application code; prefer generics or explicit models

```csharp
public sealed record UserDto(Guid Id, string Email);

public interface IUserRepository
{
    Task<UserDto?> FindByIdAsync(Guid id, CancellationToken cancellationToken);
}
```

## Immutability

- Prefer `init` setters, constructor parameters, and immutable collections for shared state
- Do not mutate input models in-place when producing updated state

```csharp
public sealed record UserProfile(string Name, string Email);

public static UserProfile Rename(UserProfile profile, string name) =>
    profile with { Name = name };
```

## Using Directives

```csharp
// ✅ Put the System namespaces first.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

// ✅ Sort the rest alphabetically.
using Microsoft.Azure.Cosmos;
using Newtonsoft.Json;
```

## Variable Initialization

This table is about **local variables**. A field is already initialized to its type's default, so
never write that default out (`= 0`, `= null`, `= false`) — Unity's guide calls such an initializer
redundant and says to remove it. A field whose starting value differs from the default still gets one.

| Type category | Initializer |
|------|------|
| Value types (primitives, structs, enums) | `default` |
| Reference types (classes) | `new()` |
| Arrays and collections | `[]` (collection expression) |

```csharp
int tmp = default;          // ✅ Value types.
StringBuilder sb = new();   // ✅ Reference types.
int[] indices = [];         // ✅ Arrays and collections.
```

## Access Modifiers

- Always state the access modifier on a member, `private` included. The language lets you leave it
  implicit, but the official guidance is to make the access level unambiguous rather than to rely on
  the default

## Constants

- Use `const` when the value is known at compile time
- Use `readonly` only when `const` cannot work (reference types, runtime initialization)

## Struct Parameters

Pass value types such as large structs by reference:

| Situation | Type |
|------|------|
| Not modified | `in T` |
| Modified | `ref T` |

```csharp
// ✅ Pass unmodified value types with in.
void Apply(in LargeStruct value);

// ❌ Passing by value copies the struct.
void Apply(LargeStruct value);
```

## Expression-Bodied Members

```csharp
// ✅ Implement one-line methods and getter properties as expression-bodied members.
// ✅ Put => on the line after the member name.
public int Count
    => items.Count;

// ❌ A one-liner written with a full block body.
public int Count
{
    get { return items.Count; }
}
```

## Async and Error Handling

- Prefer `async`/`await` over blocking calls like `.Result` or `.Wait()`
- Pass `CancellationToken` through public async APIs
- Throw specific exceptions and log with structured properties

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

## Naming Conventions

Follow the official C# conventions rather than a project variant:

- Private and internal non-constant instance fields: `_` + `camelCase` (`_workerQueue`)
- Private and internal static fields: `s_` + `camelCase` (`s_callCount`); thread-static: `t_` + `camelCase`
- Method arguments and local variables: `camelCase` with no prefix
- Constants: `PascalCase` — both fields and local constants, private and internal ones included
- Enum members: `PascalCase`, no prefix or suffix; the type name is a singular noun (plural for `[Flags]`). The project's last-member rule still applies, so define `Max` last

```csharp
private IWorkerQueue _workerQueue;                  // ✅ Instance field.
private static int s_callCount;                     // ✅ Mutable static state.
private static readonly TimeSpan RetryInterval;     // ✅ A constant is PascalCase.

enum SceneType { Title, MainGame, Max }             // ✅ PascalCase, Max last.
```

## Formatting

- Use `dotnet format` for formatting and analyzer fixes
- Keep `using` directives organized and remove unused imports
- One-line methods and getter properties use expression-bodied members (see the section above); longer bodies use block syntax
