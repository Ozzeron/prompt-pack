# Examples — handoff

Sample handoffs showing the expected tone, structure, and discipline.

## Example 1 — Backend endpoint added

> ✅ Good

```
## Summary
Added POST /api/orders/:id/cancel for users to cancel their own pending orders.
Existing 200/404 paths stayed; new 409 returned when an order isn't cancellable.

## Changes
- `src/routes/orders.ts` — new route, validation, authz, mutation
- `src/services/orders.ts` — `cancelOrder()` business logic
- `src/__tests__/orders.cancel.test.ts` — 4 cases
- `prisma/migrations/0042_add_orders_cancelled_at.sql` — soft-cancel column

## How to verify
1. `pnpm test src/__tests__/orders.cancel.test.ts` — should be 4/4 green
2. Local: log in as a user, create a pending order, POST /api/orders/:id/cancel,
   confirm 200 and `cancelled_at` populated in DB
3. Try the same endpoint as a different user — should be 403

## Tested
- ✅ Unit: 4 cases (happy / not-found / wrong-user / already-completed)
- ✅ Manual: local hit through Postman, both happy and 403 cases
- ⚠️ Not verified under concurrent cancel attempts; current code uses a single
  UPDATE so a race shouldn't double-credit, but no load test was run

## Risks / edge cases
- Orders in "shipping" status return 409, not 403 — intentional but worth confirming
  with product
- The migration is additive only (no DROP); safe to deploy ahead of code

## Out of scope (not done)
- Email notification to the user on cancel — separate ticket
- Refund flow — currently just marks cancelled, money handling is unchanged

## Suggestions
> Surface only. Not applied. User decides.

- **Must:** Concurrent-cancel test before high-traffic launch
- **Nice-to-have:** Add `cancelled_by` column for audit (would need a follow-up migration)
- **Out-of-scope idea:** Bulk cancel for admin tools — clearly a separate feature
```

Why this works:
- Neutral tone, no "successfully implemented"
- Tests are specified (count, file path, command to run)
- Risks are real, not pro forma
- Suggestions are surfaced, not applied

---

## Example 2 — Small frontend fix

> ✅ Good

```
## Summary
Fixed the OrderTable filter dropdown not closing when clicking outside on mobile.
The Radix Popover was missing `modal={false}`; tap-outside is detected differently
on touch devices.

## Changes
- `src/features/orders/OrderTableFilters.tsx` — added `modal={false}` to Popover

## How to verify
1. `pnpm dev`, narrow viewport to ≤375px (or use Chrome devtools mobile)
2. Open the filter dropdown
3. Tap anywhere outside the dropdown
4. Dropdown should close. Before fix, it stayed open.

## Tested
- ✅ Manual: Chrome devtools mobile (iPhone 13 preset) and real iPhone
- ⚠️ Not added to E2E suite; current Playwright tests don't cover this interaction
```

Why this works:
- Single-line summary captures the cause, not just the symptom
- "How to verify" is reproducible by the reviewer
- Honest about what wasn't tested

---

## Example 3 — What NOT to do

> ❌ Bad

```
## Summary
Successfully implemented the order cancel feature with comprehensive testing and
robust error handling.

## Changes
- Multiple files updated

## Tested
Tests pass.
```

Problems:
- "Successfully implemented" / "comprehensive" / "robust" — vague self-praise
- "Multiple files updated" — useless to a reviewer
- "Tests pass" — which tests? how many? what command?
- No "How to verify", no risks, no out-of-scope, no suggestions

The skill exists to prevent exactly this kind of handoff.

---

## Example 4 — Prototype mode

> ✅ Good

```
## Summary
Built the new dashboard layout with mock data while the API contract is
being finalised. UI is wired to a typed mock module that can be swapped
for real hooks once the endpoints land.

## Changes
- `src/features/dashboard/MockData.ts` — typed mock data, marked with `// TODO: backend pending`
- `src/features/dashboard/DashboardPage.tsx` — layout, sections, data hooks
- `src/features/dashboard/components/*.tsx` — three new components

## How to verify
1. `pnpm dev` → navigate to /dashboard
2. Confirm sections render with mock data
3. Resize to mobile — layout should stack

## Tested
- ✅ Visual on Chrome desktop + mobile viewport
- ⚠️ No tests yet; mocks make tests brittle until contract stabilises

## Risks / edge cases
- All "data" is hardcoded; nothing reflects real user state
- Backend contract may change; the mock module is the integration seam

## Out of scope (not done)
- Real API integration — blocked on backend
- Loading/error/empty states — wired to mock so they don't trigger; will add when real

## Suggestions
- **Must:** Wire real hooks within 1 week or revisit; mocks rot
- **Nice-to-have:** Add the loading/empty/error states now using mock toggles
```

Why this works:
- Mode is explicit (prototype with mocks)
- Risks acknowledge mocks aren't real
- Out-of-scope flags exactly what's deferred and why
- Suggestion includes a deadline ("Must")
