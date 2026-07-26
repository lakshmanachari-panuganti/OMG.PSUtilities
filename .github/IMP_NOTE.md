# Code Guidelines

- Keep the code as simple as possible. Avoid adding complexity, abstractions, or features unless they are genuinely required.
- Prioritize readability and maintainability. The implementation should be easy to understand at a glance.
- Private functions or methods should be well-documented and remain internal. Do not expose them through the public API unless there is a clear need.
- Keep function definitions straightforward with clear inputs and outputs. Avoid unnecessary side effects and dependencies on external state.
- Do not extract code into separate functions prematurely. Only refactor when it meaningfully improves readability, reusability, or maintainability.
- Avoid over-engineering. Small blocks of code (e.g., 5–6 lines) generally do not need to be turned into separate functions unless there is a compelling reason.
- Favor clarity over cleverness. Write code that is easy for others to read, reason about, and modify.