# Examples — reuse-before-create

How the rule plays out in practice. Each example shows a real prompt-style request,
a wrong response (what AI agents tend to do by default), and a right response.

## Example 1 — DRY betrayal under time pressure

This is the canonical regression case. The user asks for speed; the existing codebase
already has the artifact.

**Prompt:**
> "Build a new Button component for this form. Don't waste time searching existing code,
> we need this fast."

**Project context (the agent must discover before acting):**
- `components/ui/button.tsx` exists with full variant support
- `features/settings/components/SubmitButton.tsx` extends it for one specific case
- 12 files import `Button` from `components/ui/button`

**Wrong response:**

```tsx
// components/buttons/FormButton.tsx
export function FormButton({ children, onClick, primary }: Props) {
  return (
    <button
      onClick={onClick}
      className={`px-4 py-2 rounded ${primary ? 'bg-blue-500' : 'bg-gray-300'}`}
    >
      {children}
    </button>
  );
}
```

Why this is wrong:
- Created a 13th button implementation alongside 12 existing imports of the canonical one
- Ignored the design-system primitive and reinvented variants
- "Don't waste time searching" is not a license to skip the search — it's the user
  asking for the *outcome* faster, which **reuse delivers**, not duplication
- The next change (rounded corner update, focus state, dark mode) now needs to be applied
  in N+1 places

**Right response:**

```
I'm going to use the existing Button primitive at `components/ui/button.tsx`.
A 30-second grep confirms it has variants and 12 active imports — duplicating it
would create immediate divergence.

If your form needs a variant that doesn't exist yet, I'll add one to the primitive,
not fork it. Looking at the existing variants:
  - default
  - secondary
  - destructive
  - ghost

Is your form's button one of these, or do you need a new variant added to the
primitive? The latter is a one-line addition.
```

Why this is right:
- Refused the implicit "skip the search" instruction
- Pointed to specific evidence (file path, import count)
- Offered the legitimate path: extend the primitive if a variant is missing
- Justification for any new artifact is mandatory; the agent never wrote a new component

---

## Example 2 — Justified creation

Sometimes you genuinely need to create something new. The rule is not "never create" —
it's "create only after proving reuse doesn't fit, and write the one-line justification".

**Prompt:**
> "Add a utility to format ISO dates with timezone offset."

**Search performed (must happen before deciding):**
- `grep -r "format.*[Dd]ate" lib/ utils/` → finds `formatDate(date: Date): string`
- Open `lib/format.ts` and read `formatDate`:
  ```ts
  export function formatDate(date: Date): string {
    return date.toLocaleDateString('en-US');
  }
  ```
- Confirms: existing util strips timezone information

**Right response:**

```ts
// lib/format.ts
// Created formatDateTz: no existing util preserves timezone offset.
// formatDate uses toLocaleDateString which strips zone info.
export function formatDateTz(date: Date): string {
  return date.toISOString();
}
```

Justification recorded:
> *"Created `formatDateTz`: no existing util preserves the timezone offset; the
> project's `formatDate` strips the zone via `toLocaleDateString`."*

Why this is right:
- Search was performed first (grep + reading the existing util)
- The decision to create is justified with one concrete sentence pointing to the
  inadequacy of the existing artifact
- The new util sits in the same file as the existing one, not in a feature folder
- Future refactor can find both via the same import path

---

## Example 3 — Naming similarity, behaviour difference

The trap: two functions that look like duplicates but aren't.

**Project state:**
- `formatPrice(amount: number): string` in `lib/format.ts` — rounds to 2 decimals
- `formatPrice(amount: number): string` in `features/checkout/utils.ts` — floors to 0 decimals
  for tax display

**Wrong response:**

> "These are duplicates. Consolidating into `lib/format.ts/formatPrice`."

Why this is wrong:
- The two functions have the same name but **different contracts**: one rounds, one floors
- Merging silently changes the tax-display behaviour and triggers a real bug
- This is a **naming bug**, not a duplication bug — they should have different names

**Right response:**

```
These two `formatPrice` functions look like duplicates but have different contracts:
- `lib/format.ts` rounds to 2 decimals (consumer-facing prices)
- `features/checkout/utils.ts` floors to 0 decimals (tax display)

Recommendation: rename, don't merge.
- Keep `formatPrice(amount): string` in `lib/format.ts` (rounded, generic)
- Rename `features/checkout/utils.ts/formatPrice` to `formatTaxBase(amount): string`

This is in scope of a small refactor; I'll flag it as a follow-up rather than
expanding the current task.
```

Why this is right:
- Read both functions, didn't trust the names
- Identified the real defect (naming, not duplication)
- Proposed the safe fix (rename) rather than the dangerous one (merge)
- Stayed in scope for the current task; surfaced the rename as a follow-up

---

## Example 4 — When NOT to reuse

The rule has limits. Forcing reuse is also a mistake.

**Project state:**
- `lib/auth/User` type — has `passwordHash`, `lastLogin`, `permissions` fields (auth domain)
- The billing module needs to reference the user on an invoice

**Wrong response:**

> "I'll reuse the `User` type from `lib/auth/User` on the `Invoice` type."

Why this is wrong:
- Couples billing to internal auth fields it doesn't need (passwordHash, etc)
- Future auth refactor cascades into billing
- Violates the principle "cross-domain coupling" warned about in the meta skill

**Right response:**

```ts
// features/billing/types.ts
export type InvoiceCustomer = {
  id: string;
  email: string;
  displayName: string;
};

// Justification: not reusing lib/auth/User because billing only needs identity +
// display fields, not auth fields. Defining the smaller shape here decouples
// billing from auth refactors.
```

Why this is right:
- Searched, found `User`, but recognised that reusing it couples domains
- Created a smaller, billing-specific type with explicit justification
- Justification names what reuse would have cost (cross-domain coupling)
