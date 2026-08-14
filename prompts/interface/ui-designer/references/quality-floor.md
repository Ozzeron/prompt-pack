# UI quality floor

> Reference for [ui-designer](../SKILL.md). Load it when you reach the states, responsive, accessibility, or performance pass.

## 5. States — non-negotiable

Every interactive surface ships with all four states:

- **Default** — what the user sees most of the time
- **Loading** — shown when data is being fetched (skeleton or progress indicator)
- **Empty** — shown when there's no data (specific to the surface, not a generic "No data")
- **Error** — shown when something failed (with a retry action when applicable)

For mutations:
- **Pending** — disabled action, indicator that operation is in flight
- **Success** — visible result; toast only if the user can't see the change directly
- **Failure** — error message at the form/action level, not a global toast

Skipping any of these is the most common UI shipping bug.

## 6. Responsive and mobile

- Design **mobile-first** unless the product is genuinely desktop-only (admin tools, IDE,
  CAD). "Mobile-first" means start with the small viewport and grow up, not the other way.
- Touch targets minimum 44×44 pt. Hover-only controls don't exist on touch devices —
  always have a tap path.
- Don't hide critical actions behind hover. Don't hide critical info behind tabs or
  accordions on mobile if scrolling works.
- Test on a real narrow viewport (≤375px) before declaring it done.

## 7. Accessibility — the floor, not the ceiling

These are non-negotiable:

- **Semantic HTML** — `<button>` for actions, `<a>` for navigation, headings in order
- **ARIA only when semantic HTML is insufficient** — not as default decoration. A `<button>`
  doesn't need `role="button"`.
- **Labels** on every form input (`<label htmlFor>`, not just placeholder)
- **Form errors** associated to inputs via `aria-describedby`, not just visually placed nearby
- **Focus states** visible on every interactive element
- **Focus trap only in real modals/dialogs** — don't trap focus in popovers, tooltips, or
  inline reveals; users get stuck
- **Keyboard navigable** — every action reachable without a mouse
- **Colour contrast** ≥ 4.5:1 for text, ≥ 3:1 for large text and UI elements
- **Screen-reader text** for icon-only buttons (`<span class="sr-only">`)
- **No reliance on colour alone** — pair colour with icon or text for status
- **Respect `prefers-reduced-motion`** — disable non-essential animation when the user
  has opted out at the OS level

If shadcn/Radix primitives are used, most of this is free. Don't break it by wrapping or
overriding.

## 8. Performance basics

- Don't render lists of 1000+ items without virtualisation
- Defer below-the-fold content (lazy components, intersection observer)
- Optimise images — proper format, proper size, proper loading attribute
- Animate `transform` and `opacity`, never `width`/`height`/`left`/`top`
- No layout shift on load (reserve space, use skeletons matching final shape)
