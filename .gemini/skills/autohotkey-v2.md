# AutoHotkey V2 Skill

This skill provides expertise in AutoHotkey (AHK) V2, focusing on its modern expression-based syntax, object-oriented capabilities, and migration from V1.

## Core Syntax & Principles
- **Everything is an Expression**: Unlike V1, V2 uses expressions everywhere. No more `%var%` for variable dereferencing in commands (functions).
- **Functions over Commands**: All built-in actions are now functions (e.g., `MsgBox("Hello")` instead of `MsgBox, Hello`).
- **Strings must be quoted**: Literal strings must always be enclosed in double quotes: `"this is a string"`.
- **Variables**: Variables do not need declaration but must be initialized before use in an expression. Use `global` and `local` keywords for scope management.

## Key V2 Features
- **Objects & Classes**: Fully supported OOP with properties, methods, and `__New` constructors.
- **Maps and Arrays**: 
  - `Map()` for key-value pairs (associative arrays).
  - `[]` or `Array()` for indexed lists.
- **Fat Arrow Functions**: `(params) => expression` for concise anonymous functions.
- **Error Handling**: Uses `try`, `catch`, and `throw`. Silent failures are rare compared to V1.

## Limitations & Constraints
- **V1 Incompatibility**: V2 is not backward compatible with V1. Scripts must be fully rewritten or migrated using a converter.
- **Library Ecosystem**: While growing, some older V1 libraries haven't been ported yet.
- **Windows Only**: AHK remains a Windows-specific automation language.
- **No Native Multi-threading**: While `SetTimer` and `Pseudo-threading` exist, true multi-threading requires DLL calls or separate processes.

## Coding Standards
- Use `snake_case` or `PascalCase` for variables based on existing project style.
- Prefer `Map()` for lookups and `Array()` for lists.
- Always use parentheses for function calls, even if optional.

## Common Pitfalls
- **Double Quotes**: Forgetting quotes around strings in function parameters.
- **Assignment**: Use `:=` for all assignments. `=` is purely for comparison.
- **Scope**: Variables inside functions are local by default. Use `global` to modify global variables.