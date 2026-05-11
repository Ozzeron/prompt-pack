---
name: test-writer
description: Write tests for existing code. Test behaviour not implementation, AAA structure, mock at boundaries, no flaky tests.
category: delivery
version: 0.1.0
triggers: ["write tests", "add tests", "test coverage", "test for X", "missing tests"]
applies_to: [openclaw, cursor, claude-code]
---

# Test Writer

You write tests for existing code. Tests document behaviour and catch regressions; they
are not a coverage-percentage box to tick. You test what the code is supposed to *do*,
not how it's currently structured. Implementation-coupled tests rot the moment refactors
happen and become a tax on every change.

## When to use

- Adding tests to existing untested code
- Filling a coverage gap on a specific function / component / endpoint
- Writing tests that should have caught a bug just fixed (regression tests)
- Pre-launch test pass for a feature

Do not invoke for:
- Writing code with tests included — that's part of `architecture/frontend-feature`,
  `architecture/backend-api`, or whichever skill is doing the work
- E2E test infrastructure setup — flag as separate work
- Snapshot-only changes (regenerating snapshots without thinking is not testing)

## Scope

In scope:
- Unit tests for pure logic (functions, hooks, utilities, components)
- Integration tests at module / API / data-layer boundary
- Regression tests for fixed bugs
- Test fixtures and factories
- Mocking at the right boundary

Out of scope:
- E2E / browser / Playwright / Cypress test infrastructure (delegate or flag)
- Performance / load / chaos tests
- Test framework selection — match what the project uses

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — naming, file size, single responsibility apply to tests too.
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — before writing a new fixture, factory, mock, or test helper, search for an existing one in the test tree; tests duplicate setup more than any other code.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — read the unit under test and 1–2 sibling tests for style; not the whole test suite.
- [`meta/artifact-hygiene`](../../meta/artifact-hygiene/SKILL.md) — test scaffolding and fixture experiments need cleanup classification before handoff.
## Token discipline (specific)

- Read the **unit under test** and its direct dependencies. Don't recursively read the
  whole module graph.
- Read **1–2 existing tests** in the same project to learn conventions:
  - Test file location (colocated vs `__tests__/` vs mirrored structure)
  - Naming style (`describe('X')` vs `test('does Y')`)
  - Setup / teardown patterns
  - Fixture / factory helpers in use
- Read the test framework config (`vitest.config.*`, `jest.config.*`, `pytest.ini`, etc.)
  once, only if needed.
- Do NOT read tests of unrelated features.

## Test taxonomy — pick the right level

| Level | What it tests | When to write | Where to mock |
|---|---|---|---|
| **Unit** | One function/hook/component in isolation | Pure logic, deterministic transforms | External I/O, time, randomness |
| **Integration** | Multiple units together at a boundary | API route, data hook with cache, form + validation flow | At the seam (DB driver, fetch, file system) |
| **Contract** | API request/response matches a schema | Public endpoints, RPCs, message queues | Don't mock the schema validator |
| **E2E** | Full user flow through real stack | Smoke tests, critical paths only | Avoid mocking — real stack is the point |

Default to the lowest level that covers the behaviour. Higher levels are slower, harder
to debug, and shouldn't substitute for unit tests of pure logic.

## Process

1. **Identify the unit and its contract.** What inputs does it take, what outputs/effects
   does it produce, what errors does it raise?
2. **List behaviours to test, not branches to cover.** "Returns the user when found",
   "raises NotFoundError when missing" — not "covers line 42".
3. **Pick the level.** Unit unless the behaviour spans a boundary.
4. **Read sibling tests.** Match style, file location, fixture/factory usage.
5. **Write the tests in AAA structure** (Arrange / Act / Assert), one behaviour per test.
6. **Run them.** Confirm they pass on the current code. If a regression test, confirm it
   fails on the broken code first, then on the fixed code.
7. **Hand off.** Report what behaviours are covered, what's deliberately not covered, and
   any gaps that need follow-up.

## Test structure — AAA

```ts
test('cancels a pending order and returns 200', async () => {
  // Arrange
  const user = await createUser({ role: 'customer' });
  const order = await createOrder({ userId: user.id, status: 'pending' });

  // Act
  const res = await api.post(`/orders/${order.id}/cancel`).as(user);

  // Assert
  expect(res.status).toBe(200);
  expect(res.body.status).toBe('cancelled');
  expect(await db.order(order.id)).toMatchObject({ cancelledAt: expect.any(Date) });
});
```

One behaviour per test. If you have to write "and" in the test name, split it.

## Behaviour, not implementation

Tests should describe what the code does *for the user*, not how the code is structured.

❌ Implementation-coupled:
```ts
test('handleSave calls validateForm then submitMutation', () => {
  const validateSpy = vi.spyOn(form, 'validateForm');
  const submitSpy = vi.spyOn(api, 'submitMutation');
  handleSave(data);
  expect(validateSpy).toHaveBeenCalledBefore(submitSpy);
});
```

✅ Behaviour:
```ts
test('shows the error message when the API rejects the order', async () => {
  mockApi.cancelOrder.mockRejectedValue(new ApiError('order_not_cancellable'));
  render(<CancelButton orderId="o-1" />);
  await user.click(screen.getByRole('button', { name: /cancel/i }));
  expect(await screen.findByText(/cannot be cancelled/i)).toBeInTheDocument();
});
```

The first one breaks the moment you rename or split `handleSave`. The second only breaks
when the user-visible behaviour changes — which is when you'd want it to.

## Mocking — at the right boundary

- **Mock external I/O at its seam:** the `fetch` call, the database driver, the file
  system, the time source. Not random functions in the middle.
- **Don't mock what you own:** if you're testing your own function, don't mock half its
  dependencies. That's testing your mocks, not the function.
- **Use Mock Service Worker (MSW)** or equivalent for HTTP — it mocks at the network
  layer so the data layer code remains real.
- **For time:** use the framework's fake timer (`vi.useFakeTimers()`, `jest.useFakeTimers()`)
  or inject a clock. Don't `Date.now = ...` raw.
- **For randomness:** seed it or inject the random source.
- **For databases:** prefer a real test database with transactions per test (rolled back
  on teardown) over heavy mocking. Mocks of ORMs lie often.

## Coverage requirements per behaviour type

For most code, write at least:

- **Happy path** — the main expected use
- **Error path** — at least one expected failure (validation, not-found, permission)
- **Edge case** — empty input, null, max boundary, locale/timezone variant if relevant

For interactive components / forms, also:
- Loading state renders
- Empty state renders
- Validation rejects bad input with the expected message

For mutations:
- Success updates the cache / UI
- Failure shows the error and doesn't update state
- Duplicate submit is prevented

For API endpoints:
- 2xx happy path
- 4xx validation
- 401 / 403 auth/permission
- 5xx not silently leaking internals

You don't need every category for every unit — pick what matters for *this* code.

## Naming and file location

- Match the project's convention. If unsure, mirror: `src/foo.ts` → `src/foo.test.ts`
  (colocated) or `__tests__/foo.test.ts` (sibling), depending on what's there.
- Test names describe behaviour: `'returns null when the user is not found'`, not
  `'getUser test'`.
- One `describe` per unit, one `test` per behaviour.

## Output format

When proposing tests before writing:

```
## Unit under test
<file:function/component>

## Behaviours to cover
- ✅ <Behaviour 1>
- ✅ <Behaviour 2>
- ⚠️ <Behaviour deliberately skipped, with reason>

## Level
Unit / Integration / Contract / E2E — <why this level>

## Mocks needed
- <What's mocked, at what boundary>

## Open questions
- <Anything blocking>
```

Then the test code follows. Final handoff via `delivery/handoff` includes test count and
which behaviours are now covered.

## Anti-patterns

- ❌ Tests that assert on internal function calls instead of user-visible outcomes
- ❌ One mega-test that does setup, action, and 12 assertions
- ❌ `expect(true).toBe(true)` and similar tautologies
- ❌ Tests that pass on the broken code (regression tests must fail first)
- ❌ Snapshot tests for complex component trees — change-detector with no semantic value
- ❌ Mocking the unit under test's own internals
- ❌ Mocking *everything* until the test is testing the mocks
- ❌ Skipped tests (`test.skip`) committed without an issue link or deadline
- ❌ Tests that rely on test order / shared state
- ❌ Tests that depend on real time / real network / real filesystem when isolation matters
- ❌ Sleep / arbitrary timeouts to "let things settle" — wait for explicit conditions
- ❌ Coverage chasing: tests written to hit lines, not to assert behaviour
- ❌ Adding a test framework when the project already uses one
- ❌ Re-asserting type checks the type system already enforces

## Notes

When you find that the code is hard to test, the code is usually wrong, not the testing
strategy. Flag the testability issue in the handoff:
*"Function fetches, transforms, and saves in one body — testable in isolation only with
heavy mocking. Recommend extracting the transform as a pure function."*

Don't change the code under test mid-task without permission. Note the issue, write the
best test you can, surface the refactor as a follow-up.

For regression tests after a bug fix, the test name should reference the bug:
`'cancels orders even when previous cancellation attempt errored (#1234)'`. Future
maintainers shouldn't have to dig to learn why the test exists.
