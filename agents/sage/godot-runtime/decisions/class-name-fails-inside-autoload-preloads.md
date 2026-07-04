---
id: class-name-fails-inside-autoload-preloads
type: team_decision
title: class_name self-references break inside autoload preload chains — use const preload + drop annotations
domain: godot-runtime
tags: [autoload, class_name, preload, gdscript]
status: proposed
enforcement: block
applies_to: [godot-runtime, "scripts/autoload/**", "scripts/runtime/**"]
source: ai
timestamp: 2026-07-04T00:00:00Z
---

## Pattern

Godot 4.7 resolves `class_name X` **after** its own script has finished
compiling. If script A is used as an autoload (via `project.godot [autoload]`)
and preloads script B via `const B = preload("res://B.gd")`, and B references
its own `class_name` for a return type or a `.new()` self-reference, B fails
to compile with `Identifier not found: <ClassName>`. The failure cascades:
A fails to load, all consumers see "Failed to load script".

## Why

- `class_name` registration happens during resource system load — a script
  loaded via `preload()` from an autoload runs before that registration
  finishes for itself.
- Same-file `-> UnitState` annotations, `UnitState.new()`, or `Array[UnitState]`
  parameter types all try to resolve the identifier before it exists.
- Consumers of the autoload then hit runtime errors like
  `Nonexistent function 'from_starter' in base 'GDScript'` because the class
  never finished compiling.

## Do

- For any class used by an autoload, in autoload code write:
  `const FooClass = preload("res://path/to/foo.gd")` and call
  `FooClass.new()` / `FooClass.from_x()` — never `Foo.new()`.
- Inside the class file itself, drop return-type annotations on `static`
  factory methods: write `static func from_x(...)` — not `-> Foo`.
- Prefer plain `var xs: Array = []` over `var xs: Array[Foo] = []` for
  fields declared in autoload-loaded scripts. Type inference (`:=`) also
  needs an explicit type when the callee's return type was stripped.
- Keep `class_name` on the file — it still helps the editor and non-autoload
  consumers; just don't rely on it inside the preload chain.

## Avoid

- `class_name X` + `-> X` in the same file when that file is preloaded from
  an autoload.
- `X.new()` inside its own definition when `class_name X` is used and the
  file is loaded via preload.
- Walrus (`var y := foo.bar()`) when `bar()` has no return type and the
  compiler can't infer — leads to the same "Cannot infer the type" cascade.
