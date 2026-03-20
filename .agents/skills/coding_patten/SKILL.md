---
name: Industry Standard Coding Patterns & Optimization
description: Instructs the agent to follow industry-standard coding patterns, write performance-optimized code, and always provide clear explanations of what the code does.
---

# Industry Standard Coding Patterns & Optimization-Focused Code

## Core Directive

When writing or modifying code, you **MUST** follow all of the rules below. Every piece of code you produce must be **industry-standard**, **performance-optimized**, and **clearly explained**.

---

## 1. Code Quality Standards

### 1.1 Clean Code Principles
- **Single Responsibility**: Every class, function, and method must do **one thing only**. If a function is doing more than one job, split it.
- **DRY (Don't Repeat Yourself)**: Extract repeated logic into reusable helper functions, mixins, or utility classes. Never copy-paste similar code blocks.
- **KISS (Keep It Simple, Stupid)**: Prefer simple, readable solutions over clever or over-engineered ones. Code should be understandable at a glance.
- **YAGNI (You Aren't Gonna Need It)**: Do not add functionality unless it is explicitly needed right now.

### 1.2 Naming Conventions
- Use **descriptive, self-documenting names** for variables, functions, classes, and files.
- Follow the language's naming convention strictly:
  - **Dart/Flutter**: `camelCase` for variables/functions, `PascalCase` for classes/enums/typedefs, `snake_case` for file names, `SCREAMING_SNAKE_CASE` for constants.
- Avoid abbreviations unless they are universally understood (e.g., `id`, `url`, `http`).
- Boolean variables and getters should read as questions: `isLoading`, `hasError`, `canSubmit`.

### 1.3 Function & Method Design
- Keep functions **short** (ideally under 20-30 lines). If a function is getting long, decompose it.
- Use **named parameters** for better readability, especially when a function takes more than 2 parameters.
- Avoid **deeply nested code** (max 2-3 levels of nesting). Use early returns, guard clauses, or extraction to flatten logic.
- Always handle **edge cases** and **null safety** explicitly.

### 1.4 Error Handling
- Never silently swallow exceptions. At minimum, log them.
- Use **specific exception types** instead of catching generic `Exception` or `Object`.
- Provide **meaningful error messages** that help in debugging.
- In BLoC/Cubit, always emit a proper error/failure state with a user-friendly message.

---

## 2. Architecture & Design Patterns

### 2.1 Separation of Concerns
- **UI Layer**: Only handles rendering and user interaction. No business logic in widgets.
- **BLoC/Cubit Layer**: Contains all business logic. Receives events/calls, processes them, and emits states.
- **Repository Layer**: Abstracts the data source. The BLoC should never know whether data comes from an API, local DB, or cache.
- **Data Layer (Services/Data Sources)**: Handles raw API calls, database queries, and local storage operations.

### 2.2 Dependency Injection
- Use **constructor injection** for all dependencies (e.g., repositories into BLoCs, services into repositories).
- Register dependencies via `GetIt` or equivalent service locator, configured in a central `injection.dart` file.
- Prefer **interfaces/abstract classes** for dependencies to enable testability and loose coupling.

### 2.3 State Management (BLoC Pattern)
- Define **granular, descriptive events** — avoid generic events like `LoadData`. Use `FetchUserProfile`, `SubmitRegistrationForm`, etc.
- Define **clear, immutable states** using `Equatable` for efficient state comparison.
- Use `sealed class` or `freezed` for states/events where appropriate for exhaustive pattern matching.
- Never call `add()` on a closed BLoC — always guard with `isClosed` check when adding events asynchronously.
- Use `transformEvents` or `debounce`/`throttle` for search or rapid-fire events.

### 2.4 Model & Data Classes
- Models should be **immutable** — use `final` fields and `const` constructors.
- Implement `fromJson` / `toJson` for serialization. Use `json_serializable` or manual factories.
- Use `copyWith` methods for creating modified copies of immutable objects.
- Implement `Equatable` or override `==` and `hashCode` for value equality.

---

## 3. Performance & Optimization

### 3.1 Flutter/Widget Optimization
- Use `const` constructors wherever possible — this prevents unnecessary rebuilds.
- Prefer **small, focused widgets** over one monolithic build method. Extract widget subtrees into separate `StatelessWidget` or `StatefulWidget` classes.
- Use `BlocBuilder` with `buildWhen` to **rebuild only when the relevant piece of state changes**.
- Use `BlocListener` for one-time side effects (navigation, snackbars) — never for rebuilding UI.
- Avoid calling `setState` in deep widget trees — prefer BLoC/Cubit state management.
- Use `ListView.builder` or `ListView.separated` instead of `ListView(children: [...])` for large lists.
- Cache expensive computations using `late final` or memoization.

### 3.2 Network & Data Optimization
- Implement **caching** for API responses where appropriate (in-memory or local DB).
- Use **pagination** for large data lists — never load all records at once.
- Cancel ongoing network requests when they are no longer needed (e.g., on BLoC close using `CancelToken`).
- Debounce search/filter input to avoid firing requests on every keystroke.

### 3.3 Memory Management
- Always **close** streams, `StreamSubscription`s, `AnimationController`s, and `TextEditingController`s in `dispose()` or BLoC's `close()`.
- Avoid **retaining references** to `BuildContext` across async gaps. Use `mounted` check in `StatefulWidget` or capture values before the gap.
- Prefer `const` values and compile-time constants for reusable data like colors, text styles, padding, etc.

### 3.4 Dart-Specific Optimization
- Use **collection `if`** and **collection `for`** instead of imperative list building.
- Prefer `final` and `const` wherever a variable doesn't need to be reassigned.
- Use **spread operator** (`...`) for combining lists/maps cleanly.
- Prefer `switch` expressions (Dart 3+) for exhaustive, concise conditional logic.
- Use `extension` methods to add reusable functionality to existing types without subclassing.

---

## 4. Code Explanation Requirement

### Every code block you provide MUST include an explanation.

When writing or suggesting code, **always** include a clear, structured explanation covering:

1. **Purpose**: What does this code achieve? Why does it exist?
2. **How It Works**: A step-by-step walkthrough of the logic. Explain the flow, not just the syntax.
3. **Key Decisions**: Why this approach was chosen over alternatives (e.g., "Using `BlocBuilder` with `buildWhen` here instead of a raw `StreamBuilder` to avoid unnecessary widget rebuilds").
4. **Dependencies**: What does this code depend on (other classes, packages, services)?
5. **Edge Cases Handled**: Note any null checks, error handling, or boundary conditions explicitly addressed.

### Explanation Format

Use this pattern when explaining code:

```
### What This Code Does

**Purpose:** [One-line summary]

**Detailed Breakdown:**
- [Step 1 explanation]
- [Step 2 explanation]
- ...

**Why This Approach:**
- [Rationale for design decisions]

**Dependencies:**
- [List of required imports, services, or classes]
```

> **Important:** Do NOT provide code without explanation. Even for small fixes, briefly describe what changed and why.

---

## 5. Code Review Checklist

Before finalizing any code, mentally verify:

- [ ] Follows **single responsibility** — each function/class does one thing
- [ ] **No duplicated code** — common logic is extracted
- [ ] **Proper null safety** — no force-unwrapping without validation
- [ ] **Error states handled** — UI shows errors gracefully, BLoC emits failure states
- [ ] **Performance optimized** — const constructors, buildWhen, lazy loading, pagination
- [ ] **Resources cleaned up** — controllers, subscriptions, and streams disposed
- [ ] **Naming is clear and descriptive** — no ambiguous abbreviations
- [ ] **Code is explained** — purpose, logic, and decisions are documented

---

## 6. File & Project Structure

- Group files by **feature** (e.g., `login/`, `profile/`, `jobs/`), not by type.
- Within each feature, maintain sub-folders: `bloc/`, `models/`, `screens/`, `widgets/`, `repository/`.
- Keep shared/reusable code in top-level folders: `widgets/`, `services/`, `utils/`, `theme/`.
- One class per file. File name must match the primary class name in `snake_case`.

---

## Summary

Every line of code you write must be:
1. **Clean** — readable, well-named, single-purpose
2. **Optimized** — performant, memory-safe, efficient
3. **Explained** — clearly documented with purpose, logic, and rationale
4. **Robust** — error-handled, null-safe, edge-case-aware
5. **Maintainable** — follows established architecture, easy to extend
