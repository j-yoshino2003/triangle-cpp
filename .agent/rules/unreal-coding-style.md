---
paths:
  - "**/Source/**/*.cpp"
  - "**/Source/**/*.h"
  - "**/*.Build.cs"
  - "**/*.Target.cs"
  - "**/*.uproject"
  - "**/*.uplugin"
---
# Unreal Engine Coding Style

> This file extends [cpp/coding-style.md](../cpp/coding-style.md) with Unreal-specific content.
> **Epic's coding standard overrides the generic C++ naming rules** inside `Source/`.
> Japanese reference translation: `docs/ja-JP/rules/unreal/coding-style.md`.

## Official Sources

Epic's own standard, not a project variant. Where this file disagrees with it, it is right and this
file is the bug. Read the original, not a summary of it:

- [Epic C++ Coding Standard for Unreal Engine](https://dev.epicgames.com/documentation/ja-jp/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine) —
  it defines **no** member-variable prefix, which is why fields inside `Source/` carry none. It is
  also stricter than the generic C++ rule on type deduction and on indentation, and both of those
  reach `*.Build.cs` as well — see the two sections below

## Naming (Epic Convention — mandatory)

- Classes: `U` prefix for `UObject` types, `A` for Actors, `F` for plain structs, `S` for Slate widgets, `I` for interfaces, `E` for enums, `T` for templates
- Enum members: `PascalCase` (Epic naming) — the type keeps the Epic `E` prefix. The project's last-member rule still applies, so define `Max` last: `ESceneType { Title, MainGame, Max }`
- Constants: `PascalCase` like any other variable (`const int32 CountPlusOne`) — Epic defines no separate constant casing, so the `k` prefix the C++ rule puts on a constant is dropped here. Macros stay `UE_` + `UPPER_SNAKE_CASE`, which is the one place `ALL_CAPS` belongs
- Booleans: `b` prefix — `bIsAlive`, `bHasAmmo`
- Functions, variables, and parameters: `PascalCase` (not camelCase/snake_case), with no project prefix — Epic naming applies as-is
- Prefix a parameter with `Out` when it is passed by reference and written by the function (`OutResult`); a boolean one puts `b` first (`bOutResult`). Use `In` where a parameter needs disambiguating from a member or an alias
- The field markers from [cpp/coding-style.md](../cpp/coding-style.md) do **not** apply inside `Source/`: fields are plain `PascalCase` (`MaxHealth`, not `_maxHealth`), and parameters carry no `_`

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

## Type Deduction Exception

Epic requires the type to stay visible to the reader, so the generic C++ rule's "use `auto` when the
type is obvious" and "use structured bindings" do **not** apply here:

- Do **not** use `auto`. Epic allows exactly three exceptions: binding a lambda (its type cannot be
  written out), an iterator variable, and template code where the type is not practically nameable.
  Where `auto` is used, still spell `const`, `&`, and `*` on it as you would on the type name
- Do **not** use C++20 structured bindings — Epic treats them as variadic `auto`
- The same applies to `var` in C#, which is what `*.Build.cs` and `*.Target.cs` are written in

## Comment Language — a Deliberate Deviation

Epic states that **all code and comments must use US English spelling and grammar**, and extends that
to changelist descriptions. This project writes comments in Japanese anyway (`AGENTS.md`,
`common/code-comments.md`), because the team reads and writes Japanese. That is a deliberate
deviation, recorded here so it is not mistaken for an oversight. Identifiers stay in English, so the
naming rules above are unaffected.

## Memory Management Exception

The generic C++ rule "use `std::unique_ptr`/`std::shared_ptr`" does **not** apply to engine types:

- `UObject`-derived types are garbage-collected — hold them in `UPROPERTY()` fields or `TObjectPtr<T>`; a raw pointer without `UPROPERTY` will dangle after GC
- Use `TWeakObjectPtr<T>` for non-owning references that may outlive the object
- Non-`UObject` types use `TUniquePtr`, `TSharedPtr`/`TSharedRef` (engine containers), not `std::` smart pointers

## Engine Containers and Strings

- Use `TArray`, `TMap`, `TSet` over `std::vector`/`std::map` in engine-facing code
- Strings: `FString` (mutable), `FName` (identifiers, fast compare), `FText` (user-facing, localized) — pick by purpose, never hardcode user-visible `FString`

## Headers

- **Every header starts with `#pragma once`** — Epic requires it and states that every compiler in
  use supports it. This **overrides** the `#ifndef` include guard in
  [cpp/coding-style.md](../cpp/coding-style.md), which follows Core Guidelines SF.8 instead. The two
  official documents genuinely disagree here, so the engine rule wins inside `Source/`
- Follow include-what-you-use; keep headers minimal with forward declarations
- `#include "X.generated.h"` must be the last include in a `UCLASS`/`USTRUCT` header

## Formatting

- **Tabs, not spaces, for leading whitespace**, with the tab width set to 4. Epic states this
  outright and extends it to C#, so it covers `Source/**` as well as `*.Build.cs` and
  `*.Target.cs`. This **overrides** the 4-space indent in
  [common/code-layout.md](../common/code-layout.md) — Visual Studio defaults C# files to spaces, so
  the setting has to be changed per project
- Allman braces (Epic standard); use the project `.clang-format` if present

## Object Creation and Destruction

```cpp
// ❌ Created with new and freed with delete.
UWeapon* Weapon = new UWeapon();
delete Weapon;

// ✅ Create with NewObject, CreateDefaultSubobject, or SpawnActor.
// ✅ Leave destruction to the GC. Never delete a UObject.
UPROPERTY()
TObjectPtr<UWeapon> Weapon;

Weapon = NewObject<UWeapon>(this);
```

## Parameters

```cpp
// ✅ Pass UObject-derived types as a raw pointer, not a reference.
void SetTarget(AActor* Target);

// ✅ Other types: const T& / T&.
void SetName(const FString& Name);
```

## String Literals

```cpp
// ✅ Wrap string literals in TEXT("...").
FString Name = TEXT("Player");
```

## Logging and Assertions

```cpp
// ✅ Logging.
UE_LOG(LogTemp, Warning, TEXT("Item count: %d"), ItemCount);
```

| Purpose | Macro |
|------|------|
| Invariant (unrecoverable) | `check()` / `checkf()` |
| Recoverable validation | `ensure()` / `ensureMsgf()` |
| Blueprint-exposed event | `DECLARE_DYNAMIC_MULTICAST_DELEGATE*` |
| C++-only event | `DECLARE_MULTICAST_DELEGATE*` |
