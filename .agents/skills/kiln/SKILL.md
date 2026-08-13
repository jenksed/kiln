```markdown
# kiln Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches the core development patterns and conventions used in the `kiln` TypeScript codebase. It covers file organization, code style, import/export practices, and testing patterns. The repository does not use a specific framework, focusing on idiomatic TypeScript with custom workflows and conventions.

## Coding Conventions

### File Naming
- Use **camelCase** for file names.
  - Example: `myModule.ts`, `userService.ts`

### Import Style
- Use **relative imports** for referencing modules.
  - Example:
    ```typescript
    import { helperFunction } from './utils';
    ```

### Export Style
- Use **named exports** for all modules.
  - Example:
    ```typescript
    // In userService.ts
    export function getUser(id: string) { ... }
    export const USER_ROLE = 'admin';
    ```

### Commit Messages
- Freeform style, no enforced prefixes.
- Average commit message length is 33 characters.

## Workflows

### Adding a New Module
**Trigger:** When you need to add new functionality.
**Command:** `/add-module`

1. Create a new `.ts` file using camelCase naming.
2. Implement your logic using named exports.
3. Use relative imports to include dependencies.
4. Write a corresponding test file named `moduleName.test.ts`.
5. Commit your changes with a clear, concise message.

### Refactoring Code
**Trigger:** When improving or restructuring existing code.
**Command:** `/refactor`

1. Identify the code to refactor.
2. Update file names to camelCase if needed.
3. Ensure all imports remain relative.
4. Use named exports consistently.
5. Update or add tests as necessary.
6. Commit with a descriptive message.

### Running Tests
**Trigger:** Before pushing changes or verifying functionality.
**Command:** `/run-tests`

1. Locate all files matching `*.test.*`.
2. Run tests using your preferred TypeScript test runner.
3. Review and fix any failing tests.

## Testing Patterns

- Test files follow the pattern: `*.test.*` (e.g., `userService.test.ts`).
- The testing framework is not specified; use your preferred runner.
- Place tests alongside or near the modules they test.
- Example test file structure:
  ```typescript
  import { getUser } from './userService';

  describe('getUser', () => {
    it('returns a user by ID', () => {
      // test implementation
    });
  });
  ```

## Commands
| Command      | Purpose                                   |
|--------------|-------------------------------------------|
| /add-module  | Scaffold and implement a new module       |
| /refactor    | Refactor existing code and update tests   |
| /run-tests   | Run all test files in the codebase        |
```