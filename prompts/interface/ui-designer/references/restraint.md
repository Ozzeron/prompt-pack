# Restraint rules

> Reference for [ui-designer](../SKILL.md). Load it when the change adds motion, decoration, or a new UI pattern.

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
