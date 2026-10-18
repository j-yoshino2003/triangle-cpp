# Coding Style

> Japanese reference translation: `docs/ja-JP/rules/common/coding-style.md`.
> Comment rules and notation / layout rules are separate files that load only when a source file
> is read or edited: `code-comments.md` and `code-layout.md` (`common-` prefixed in the Codex and
> Antigravity copies).

## Immutability (CRITICAL)

Prefer immutable updates: return a new value instead of mutating in place — it keeps side effects
out of hiding, keeps debugging tractable, and makes concurrency safe.
Exception: engine-managed hot paths (Unity per-frame code, Unreal gameplay loops) follow the
engine rules instead — see the `unity/` and `unreal/` rules.

## Core Principles

KISS, DRY, YAGNI. The two tie-breakers that do not follow from the acronyms alone: clarity over
cleverness, and an abstraction only once the repetition is real rather than anticipated.

## File Organization

Many small files over few large ones, organized by feature / domain rather than by type: high
cohesion, low coupling. Extract utilities out of a module that grew large.
200-400 lines typical, 800 max.

## Error Handling

- Handle errors explicitly at every level — never swallow one silently
- User-facing messages in UI code; detailed error context in server-side logs

## Input Validation

- Validate all input at system boundaries before processing, and fail fast with a clear message
- Use schema-based validation where available
- Never trust external data — API responses, user input, file content

## Naming Conventions

- Variables: `camelCase` with descriptive names; functions follow the language rule (`PascalCase` in C#/C++)
- Booleans: prefer `is`, `has`, `should`, or `can` prefixes
- Interfaces and types: `PascalCase`
- Constants: follow the language rule — `k` + `PascalCase` in C++ (`kMaxHealth`), `PascalCase` in C#, `k_` + `PascalCase` in Unity, `PascalCase` in Unreal, `SCREAMING_SNAKE_CASE` in Rust. Only Rust uses `ALL_CAPS`, because its own lint requires it; in C++ the Core Guidelines reserve `ALL_CAPS` for macro names
- Parameters: `camelCase` with no prefix (`playerId`, `isAlive`) — this is what the language conventions agree on, so no project marker is added
- Fields: a private or internal instance field is `_` + `camelCase` (`_playerId`); a static one is `s_` + `camelCase` (`s_callCount`). Nothing else marks storage or scope at the use site, which is why these two get a marker while pointers and references do not — the declaration already states the type. Engine and language rules that define their own naming win: see the `unreal/` rule (Epic naming, no field marker) and the `rust/` rule (`snake_case` reached through `self`)
- Lambda parameters are exempt from the parameter rule — they follow the variable convention instead, because they are local to one expression (`players.Where(player => player.IsAlive)`)
- Enum constants: `PascalCase` in every language — not the constant casing, because an enumerator that is `ALL_CAPS` collides with a macro of the same name. **Always define the last member as the count / limit** (`Max`), kept as a project convention across every language and engine because switch exhaustiveness and array sizing rely on it. Rust is the exception the `rust/` rule states. Type names stay `PascalCase`

### Name Quality

A name should convey its role on its own, without needing a comment:

| ❌ | ✅ | Reason |
|----|----|------|
| `int c;` | `int playerCount;` | No abbreviations or single letters (loop counters `i`, `j` are the only exception) |
| `UserInfo userInfo;` | `UserInfo player;` | Do not repeat the type name |
| `bool isNotAlive;` | `bool isDead;` | No negated boolean names |

- Name functions by what they do (role), not how they do it: `Save()` not `SaveToFile()`
- Search operations contain `Find`; event handlers start with `On`; async functions end with `Async`

## Function and Class Design

- Group many parameters into a struct/class instead of long parameter lists
- Extract 2D-array index arithmetic (`cells[y * width + x]`) into a named accessor (`GetCell(x, y)`)
- Always mark overriding functions with `override`
- Keep member variables minimal — do not store values derivable from other members; expose them as computed properties/getters

## Design Principles

Follow SOLID and the Law of Demeter, by their standard definitions. The only project-specific
point: LINQ / STL chains are exempt from the Law of Demeter, because they transform one collection
rather than traversing another object's internals.

## Code Smells to Avoid

- Deep nesting — use early returns instead of stacking conditionals
- Magic numbers — use a named constant for any meaningful threshold, delay, or limit
- Long functions — split by responsibility

## Code Quality Checklist

Before marking work complete:
- [ ] Code is readable and well-named
- [ ] Functions are small (<50 lines)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Proper error handling
- [ ] No hardcoded values (use constants or config)
- [ ] No mutation (immutable patterns used)
