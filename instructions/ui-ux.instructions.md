---
applyTo: "**/*.{html,css,scss,js,ts,jsx,tsx,vue}"
---

# Design system
- Base typography 14–16px
- Line-height 1.4–1.6
- Use clamp() for fluid sizing
- Avoid very thin fonts
- Spacing base 8px (4px for dense)
- Consistent tokens in `design-system.scss`
- **CSS variables for colors, spacing, typography** - centralize in design-system.scss
- **Quasar utility classes first** - prefer built-in classes over custom CSS
```css
/* design-system.scss - CSS Variables */
:root {
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;
  
  --text-dark: #1a1a1a;
  --text-light: #6b7280;
  --bg-white: #ffffff;
}

body {
  font-size: clamp(14px, 1.5vw, 16px);
  line-height: 1.5;
  margin: 0;
}
```

# Colors
- WCAG AA contrast >= 4.5:1 (normal text) and >= 3:1 (headings >= 18px or semibold)
- Never rely on color alone for states
- Include icon/text for visual clarity
- Validate light and dark mode
- **Use Quasar color props** when possible: `color="primary"`, `color="warning"`, `color="negative"`
- **Custom colors via CSS variables** for brand-specific needs
```vue
<!-- ✅ Quasar color props -->
<q-btn label="Clear" color="warning" />
<q-btn label="Save" color="primary" />

<!-- ✅ Custom colors with CSS variables + icons -->
<q-btn label="Delete" class="btn-danger">
  <q-icon name="delete" /> Delete
</q-btn>

<style scoped>
.btn-danger {
  background-color: var(--color-danger);
  border-color: var(--color-danger);
}
</style>
```

# Accessibility
- Semantic landmarks
- Skip-to-content link
- DOM order reflects visual order
- Predictable focus order
- Focus never hidden
- Modal must trap focus and restore on close
- Aria-* and labels required
```html
<header><nav><main>…</main></nav></header>
// Skip link visible on tab focus
```

# Responsiveness
- Mobile-first approach
- Minimum touch target 44x44
- Gap >= 8px between targets (use `q-gutter-sm` or larger)
- Adjustable density
- Layouts responsive via stack/scroll/cards
- **Use Quasar responsive utilities**: `col`, `col-md-6`, `col-xs-12`
- **Use Quasar spacing**: `q-gutter-sm`, `q-gutter-md`, `q-mb-lg`, `q-pa-md`
```vue
<!-- ✅ Quasar responsive grid + spacing -->
<div class="row q-gutter-md">
  <div class="col-xs-12 col-md-6">
    <q-btn label="Action" class="full-width" />
  </div>
  <div class="col-xs-12 col-md-6">
    <q-btn label="Cancel" class="full-width" />
  </div>
</div>

<!-- ✅ Minimum touch target with Quasar -->
<q-btn size="md" style="min-width: 44px; min-height: 44px;" />
```

# Content
- Actionable messages (“Correct the CPF” instead of “Invalid CPF”)
- Avoid jargon
- Consistent terminology
- Placeholders never replace labels
- Dates/numbers localized
- Abbreviations with title/tooltip
```html
<label>Date of Birth</label>
<!-- Placeholder “dd/mm/yyyy” + aria-describedby with format hint -->
```

# Forms
- Per-field error with correction
- Aria-describedby for error message
- Required visible
- Optional fields labeled
- Masks only as helper
- Progressive validation without silent blocking
```html
<input aria-describedby="cpf-error">
<span id="cpf-error">Correct the CPF</span>
// Required fields marked with *
```

# Media
- Meaningful alt (alt="" for decorative)
- Use srcset/sizes
- Preserve aspect ratio
- Captions for complex charts
- No autoplay with sound
```html
<img src="photo.jpg" srcset="photo@2x.jpg 2x" alt="Portrait of a smiling person">
```

# Motion
- Respect prefers-reduced-motion
- Animation durations 150–300ms
- Perceptible skeleton loading (no aggressive shimmer)
- Critical toasts not auto-dismissing
- Aria-live for async feedback
```css
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; }
}
```

# Tables
- Clear headers
- Responsive via stack/scroll/cards
- No truncation without indicator
- Sorting and filters accessible
- Empty states must guide action
```html
<th scope="col">Name</th>
// Empty-state “No records found — click + to add”
```

# Privacy
- Mask sensitive data by default
- Never show full identifiers (e.g., CPF)
```html
<!-- CPF displayed as ***.456.***-00 -->
```

# Metrics
- Measure task time
- Success rate
- Errors per step
- CLS/LCP metrics
- Log correlationId for relevant events
```javascript
// log correlationId on “checkout_started” click event
```