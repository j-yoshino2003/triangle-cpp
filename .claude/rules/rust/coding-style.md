---
paths:
  - "**/*.rs"
---
# Rust Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with Rust specific content.
> Japanese reference translation: `docs/ja-JP/rules/rust/coding-style.md`.

## Official Sources

Read the original, not a summary of it. No single document covers every row of the naming table
below, so all three are needed:

- [rustc lints, warn by default](https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html) —
  what is actually enforced, and what the Split Rule below defers to. `non_snake_case` covers
  variables, named fields, and modules; `non_camel_case_types` covers types, traits, and enum
  variants; `non_upper_case_globals` covers statics
- [Rust Style Guide, "Other style advice"](https://raw.githubusercontent.com/rust-lang/rust/master/src/doc/style-guide/src/advice.md) —
  the only one of the three that states struct fields and reserved-word names (`r#crate`, `crate_`)
- [Rust API Guidelines, Naming](https://rust-lang.github.io/api-guidelines/naming.html) — modules,
  traits, type parameters, lifetimes, plus the `as_` / `to_` / `into_` and `iter` method conventions.
  It states no rule for struct fields or parameters

## The Split Rule

Follow the common rules wherever they are language-neutral. Where they collide with Rust, the
deciding question is **whether stable tooling can be configured to satisfy the common rule**:

- **Configurable on stable** — line width, indentation → **the common rule wins**, and we configure
  `rustfmt` to match. See `rust/rustfmt.toml`.
- **Enforced by a default `rustc` lint** — naming, mostly → **Rust wins.** Fighting a default lint
  means a warning on every build, which is not a workable trade.
- **Configurable only on nightly** — brace placement → **Rust wins.** Pinning the project to an
  unstable toolchain is too high a price for a formatting preference.

`cargo fmt` and `cargo clippy` are the arbiters. If this document and the tools disagree, the tools
are right and this document is a bug.

## What Carries Over Unchanged

- **Immutability** — Rust bindings are immutable by default. Add `mut` only where mutation is required.
- **KISS / DRY / YAGNI** and the SOLID / Law of Demeter guidance.
- **File organization** — many small files, 200-400 lines typical, 800 max. Organize by feature, not by type.
- **Error handling** — never silently swallow errors. Validate at system boundaries.
- **Name quality** — no abbreviations or single letters (`i` / `j` in loops excepted), do not repeat the
  type name, no negated booleans (`is_dead`, not `is_not_alive`), name functions by role not mechanism.
- **Boolean prefixes** — `is_` / `has_` / `should_` / `can_`.
- **Search / event verbs** — search functions contain `find`, event handlers start with `on_`.
- **Control flow** — one blank line before and after each control statement. Prefer early returns
  over deep nesting. No magic numbers.
- **Comments in Japanese** — end each comment line with a half-width period `.`, put a space between
  full-width and half-width characters, use long-vowel marks for `-er` / `-or` / `-ar` katakana endings.
  `// TODO:` for remaining work, `// NOTE:` for cautions, body on the next line when it spans 2+ lines.
- **Layout** — 4 spaces, 120 columns, one trailing blank line. Enforced by `rustfmt.toml`.

## What Differs

### Naming

| Item | Common rule | Rust rule | Why |
|------|------|------|------|
| Functions / methods | `PascalCase` | `snake_case` | `non_snake_case` lint |
| Variables / fields | `camelCase` | `snake_case` | `non_snake_case` lint |
| Parameters | `camelCase`, no prefix | `snake_case`, no prefix | A leading `_` means "intentionally unused" in Rust |
| Fields | `_camelCase` (static: `s_camelCase`) | `snake_case`, no prefix | Fields are always reached through `self` |
| Types / traits | `PascalCase` | `PascalCase` | same |
| Constants / statics | `kPascalCase` in C++, `PascalCase` in C# | `SCREAMING_SNAKE_CASE` | `non_upper_case_globals` lint. Rust is the one language here that wants `ALL_CAPS` |
| Enum variants | `PascalCase`, last member is the limit | `PascalCase`, no `Max` | `non_camel_case_types` lint |
| Modules / file names | — | `snake_case` | `non_snake_case` lint |
| Async functions | `Async` suffix | no suffix | `async fn` is already visible in the signature |

**Do not define a limit sentinel variant.** It exists in C++/C# to bound iteration; Rust gets
exhaustiveness from `match`, and a sentinel forces a meaningless arm in every `match`.

```rust
// ❌ 共通規約をそのまま持ち込んだ形.
enum SceneType { Title, MainGame, Max }

// ✅ Rust の規約. 番兵は作らない.
enum SceneType {
    Title,
    MainGame,
}
```

### File Header

The `///` form used in C++ is a doc comment that must document a following item; a bare `///` block
at the top of a file is a compile error (`E0585`). Use `//!` — it becomes the module's own
documentation and shows up in `cargo doc`.

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

Items below use `///` as usual. Do not use the C++/C# `/// <summary>` XML form — `rustdoc` renders
Markdown, so write plain Markdown and use `# Errors` / `# Panics` / `# Safety` sections.

### Encoding

Rust source files are **UTF-8 without BOM**, unlike the common rule. The Rust ecosystem, `cargo`,
and every published crate assume no BOM.

### Ownership Replaces the Smart Pointer Table

The common rules' `shared_ptr` / `weak_ptr` signature table does not apply. Rust encodes the same
information in the type system:

| Situation | Type |
|------|------|
| Read only, not stored | `&T` |
| Modified, not stored | `&mut T` |
| Callee takes ownership | `T` |
| Shared ownership genuinely required | `Rc<T>` / `Arc<T>` |
| Shared ownership plus mutation | `Rc<RefCell<T>>` / `Arc<Mutex<T>>` — justify it in a comment |

Reach for `Rc` / `Arc` only when a single owner is genuinely impossible. Most of the time
restructuring so one place owns the data is simpler and faster.

### Rule of 0 Becomes Drop

The C++ Rule of 0 maps directly: **do not write `impl Drop` in ordinary types.** Ownership already
releases memory. Write `Drop` only in a dedicated wrapper around a resource that needs explicit
teardown — a Vulkan handle from `ash`, a file descriptor, a lock — and keep every user of that
wrapper free of manual cleanup.

### Error Handling

- Return `Result<T, E>` and propagate with `?`. Do not panic on recoverable failures.
- `unwrap()` / `expect()` are allowed only in tests, in `main` for startup failures that should abort,
  and where a comment proves the case is impossible.
- `expect("...")` messages state **what invariant was violated**, not what the call was.

### unsafe

`ash` is a thin binding, so most Vulkan calls are `unsafe`. Contain the damage:

- Keep each `unsafe` block as small as possible — never wrap a whole function body.
- Every `unsafe` block gets a `// SAFETY:` comment stating which invariant makes it sound.
- Safe wrappers expose a safe API; `unsafe` does not leak into calling code.

### Formatting

`rustfmt` does the formatting; `rust/rustfmt.toml` sets what can be set — line width 120 and
4-space indentation, both taken from the common rules.

**Brace placement is the exception.** Rust keeps the opening brace on the same line, so the C++ side
(Allman) and the Rust side differ here:

```rust
fn main() {
    if is_ready {
        run();
    } else {
        wait();
    }
}
```

`brace_style` and `control_brace_style` would change this, but they are **unstable `rustfmt`
options** available only on the nightly toolchain. Pinning the project to nightly for brace
placement is not a trade worth making, so Rust's default stands.

```bash
cargo fmt
```

```bash
cargo clippy
```

Both must be clean before work is considered complete. Unlike the common rules,
**do not hand-align code** — `rustfmt` will undo it.

## Code Quality Checklist

Before marking work complete:

- [ ] `cargo fmt --check` passes
- [ ] `cargo clippy` reports no warnings
- [ ] No `unwrap()` / `expect()` outside the allowed cases
- [ ] Every `unsafe` block has a `// SAFETY:` comment
- [ ] No `impl Drop` outside dedicated resource wrappers
- [ ] Files are focused (<800 lines), functions are small (<50 lines)
