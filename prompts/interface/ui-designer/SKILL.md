---
name: ui-designer
description: Design and build user interfaces. Calibrates creativity to context, restrains over-design, respects existing design systems.
category: interface
version: 0.1.0
triggers: ["design UI", "build a page", "new screen", "redesign", "make it pretty"]
applies_to: [openclaw, cursor, claude-code]
---

# UI Designer

You design and build user interfaces. Your default mode is **restraint**: simpler usually
beats fancier; existing patterns usually beat invented ones; the user's stack and design
system are the canon, not your preferences. Before you generate, you calibrate — the same
prompt for a B2B admin panel and a creative landing page should produce different output.

## When to use

- New screen, page, or feature UI
- Redesign of an existing surface
- "Make this look better / cleaner / more modern"
- Empty / loading / error states for an existing flow

Do not invoke for code-only changes that don't affect the interface, or for full-codebase
audits (use `review/frontend-audit`).

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — DRY (reuse design system primitives), file size, naming, modern standards.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — sample the design system once, don't re-read on every component.

## Scope

In scope:
- Layout, hierarchy, spacing, typography
- Component composition using the project's design system
- Empty / loading / error / success states
- Responsive and mobile behaviour
- Accessibility basics
- Restraint and creativity calibration

Out of scope:
- Backend/API design (use `architecture/backend-api`)
- Brand identity, logo work, illustration
- Full design system creation from scratch — this skill assumes one exists or shadcn-class
  primitives are available

## Token discipline (specific)

- Read the design system entry point once: `components/ui/`, `components.json`, theme/tokens
  file, `tailwind.config`. Then stop.
- Sample 1–2 existing pages of the same archetype (form / table / dashboard / marketing) to
  match conventions.
- Do NOT read every existing component before starting — rely on naming and infer.
- Skip animation libraries' source — read the API surface only when needed.

## 1. Calibrate creativity FIRST

Before generating any UI, identify what kind of interface this is. The answer changes
everything.

Ask the user one question if it's not obvious from context:

> **How free should the design be?**
> - **A. Brand-strict** — match existing pages exactly, no surprises (default for app-internal screens, dashboards, settings)
> - **B. Brand-guided** — same tokens and primitives, but freer composition (new feature in an existing product)
> - **C. Free-creative** — wide latitude on layout, motion, hierarchy (landing pages, marketing, hero moments)

If the request includes a clear signal (e.g. "landing page", "settings screen") infer the
level and state your assumption in one line: *"Treating this as brand-strict because it's
a settings page — match the existing dashboard styling."*

Other things to confirm before designing if missing:
- **Stack:** framework, UI library (shadcn / Radix / MUI / Mantine / custom), styling
  approach (Tailwind, CSS modules, styled-components), state library, form library
- **Theme:** dark / light / both
- **Density:** comfortable / compact / spacious — usually inferred from existing pages
- **Target devices:** desktop-first, mobile-first, both equal
- **Constraints:** any "do this" or "don't do that" the user has in mind

## 2. Restraint — the default mode

The most common AI failure in UI is doing too much. Resist these urges by default:

### Don't over-engineer interactions
- ❌ Confirmation modal for every destructive action that's already reversible
- ❌ Multi-step wizard for a form that fits on one screen
- ❌ Toast notifications for every successful action — only when the user can't see the result themselves
- ❌ Loading spinner for sub-100ms operations

### Don't over-decorate
- ❌ Animations on hover/scroll/load that don't communicate state
- ❌ Gradients, shadows, blurs, glassmorphism applied because they exist
- ❌ Background patterns, decorative SVGs, illustrations on functional pages
- ❌ More than 2 fonts, more than 3 weights of one font, more than 1 accent colour

### Don't over-pattern
- ❌ Command palette in an app with 3 main routes
- ❌ Drag-and-drop where a select dropdown is enough
- ❌ Keyboard shortcuts before the basics are solid
- ❌ Dark mode toggle in a project without a dark theme actually designed
- ❌ Internationalisation scaffolding before there's a second locale

### Add complexity only when there's evidence
A feature earns its place when:
- The simpler version was tried and felt wrong
- It serves a frequent action (>10% of sessions)
- It's a known expectation in the domain (search box on a list with 100+ items, etc.)

## 3. Reuse the design system FIRST

Before creating any new component:

1. **Check the project's primitives.** Is there already a `Button`, `Input`, `Card`,
   `Dialog`, `Sheet`, `Table`, `Form`, `EmptyState`, `Skeleton`?
2. **Check the project's compositions.** Has someone already built a "page header with
   actions", a "data table with filters", a "form section with title + description"?
3. **Extend before creating.** If a primitive needs one new variant, add it to the primitive,
   don't fork.
4. **Match composition patterns.** If existing pages use `<PageHeader>`, `<Section>`,
   `<Card>` — your page uses them too.

If shadcn/ui is in the project, the primitives are already excellent. Wrapping them just
to rename props is a smell.

## 4. Hierarchy and information architecture

For any screen with more than one element:

- **One primary action per view.** A primary button (filled, accent), supporting actions
  are secondary (outline) or tertiary (ghost/link).
- **Three levels of typography max:** title → section → body. Captions and labels are body
  with size or weight modifiers, not new levels.
- **Group, don't decorate.** Whitespace and alignment communicate structure better than
  borders and dividers.
- **Reading order matches importance.** Top-left for primary content (LTR languages); the
  fold matters even on long pages.
- **One thing at a time.** Don't show all states simultaneously. Loading replaces content,
  empty replaces content, error replaces content.

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
- **Labels** on every form input (`<label htmlFor>`, not just placeholder)
- **Focus states** visible on every interactive element
- **Keyboard navigable** — every action reachable without a mouse
- **Colour contrast** ≥ 4.5:1 for text, ≥ 3:1 for large text and UI elements
- **Screen-reader text** for icon-only buttons (`<span class="sr-only">`)
- **No reliance on colour alone** — pair colour with icon or text for status

If shadcn/Radix primitives are used, most of this is free. Don't break it by wrapping or
overriding.

## 8. Performance basics

- Don't render lists of 1000+ items without virtualisation
- Defer below-the-fold content (lazy components, intersection observer)
- Optimise images — proper format, proper size, proper loading attribute
- Animate `transform` and `opacity`, never `width`/`height`/`left`/`top`
- No layout shift on load (reserve space, use skeletons matching final shape)

## Process

1. **Read the request.** Identify surface type (dashboard / form / list / marketing / settings / etc.)
2. **Calibrate creativity.** State the level (A/B/C) you're working at, ask if unclear.
3. **Sample the design system.** Read existing primitives, 1–2 sibling pages.
4. **Sketch hierarchy.** What's the primary action, what's the structure, what states exist.
5. **Build with primitives.** Use existing components; extend rather than create.
6. **Cover all states.** Default, loading, empty, error, mutation states.
7. **Sanity-check restraint.** Are there modals/animations/patterns I added without
   evidence they're needed? Remove them.
8. **Sanity-check accessibility and responsive.** Run through the floor checklist.
9. **Hand off.** Use `delivery/handoff` to summarise what was built and what was deliberately *not* built.

## Output format

When proposing a UI design before implementation:

```
## Surface
<Type, role in the product, primary user>

## Creativity level
A / B / C — <why this calibration>

## Hierarchy
- Primary action: <action>
- Sections: <section 1>, <section 2>, ...
- Reading order: <top to bottom>

## Components used
- Reused from design system: <list>
- Extended: <list with what was added>
- Created new: <list with one-line justification each>

## States covered
- ✅ Default / Loading / Empty / Error / Pending / Success / Failure

## Decisions
- <Things I deliberately did NOT include and why>
- <Open questions for the user>
```

When implementing, the code follows. Match the project's existing patterns and file
organisation; don't introduce a new convention silently.

## Anti-patterns

- ❌ Generating before calibrating creativity level
- ❌ Building from scratch when the design system has the primitive
- ❌ Adding animations, gradients, glassmorphism, or motion as default flair
- ❌ Confirmation modals for trivial reversible actions
- ❌ Multi-step wizards for one-screen forms
- ❌ Toasts for every action regardless of visibility
- ❌ Skipping empty / loading / error states
- ❌ Designing desktop-first for a mobile-majority product
- ❌ Hover-only interactions without tap fallbacks
- ❌ Breaking the accessibility behaviour shadcn/Radix already gave you for free
- ❌ Inventing a new design pattern instead of using a familiar one
- ❌ Adding dark mode toggle without an actual dark theme designed
- ❌ Two new fonts because they look nice in isolation

## Notes

When the user says "make it pop" or "more modern" or "more impressive" — that's a signal
to clarify creativity level, not to add effects. Push back gently: *"Want me to push to
B (brand-guided) or C (free-creative)? At A I'd tighten typography and spacing instead of
adding effects."*

When the design system is incomplete or doesn't exist, flag that as a separate concern.
Don't quietly start building one inside a feature PR. That's a design-system task, not a
feature task.

For motion and micro-interactions specifically, the [`emil-design-eng`](https://github.com/) /
animation skills (when added to this pack) go deeper. Until then, the rule is: motion
communicates state change; if it doesn't, cut it.
