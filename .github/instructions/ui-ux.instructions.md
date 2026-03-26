---
applyTo: "**/*.{html,css,scss,js,ts,jsx,tsx,vue}"
priority: medium
---

# Design System

## Typography
- Base typography 14–16px
- Line-height 1.4–1.6
- Use clamp() for fluid sizing
- Avoid very thin fonts
- **Font pairing**: Display font (Poppins) for titles, Body font (Inter) for text
```css
:root {
  --theme-font-display: 'Poppins', sans-serif;
  --theme-font-body: 'Inter', sans-serif;
}

h1, h2, h3 {
  font-family: var(--theme-font-display);
  font-weight: 700;
}

body {
  font-family: var(--theme-font-body);
  font-size: clamp(14px, 1.5vw, 16px);
  line-height: 1.5;
}
```

## Spacing Scale
- Base spacing 8px (4px for dense)
- Consistent tokens in `design-system.scss`
```css
:root {
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 16px;
  --spacing-lg: 24px;
  --spacing-xl: 32px;
  --spacing-2xl: 48px;
  --spacing-3xl: 64px;
  --spacing-4xl: 80px;
}
```

## Shadows (Softer for Modern Look)
```css
:root {
  --shadow-soft: 0 2px 8px rgba(0, 0, 0, 0.05);
  --shadow-medium: 0 4px 16px rgba(0, 0, 0, 0.08);
  --shadow-strong: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.card {
  box-shadow: var(--shadow-soft);
  transition: box-shadow var(--transition-fast);
}

.card:hover {
  box-shadow: var(--shadow-medium);
}
```

## Transitions
```css
:root {
  --transition-fast: 200ms ease-in-out;
  --transition-normal: 300ms ease-in-out;
  --transition-slow: 500ms ease-in-out;
}
```

## CSS Variables
- **Theme variables** for runtime switching: `--theme-*`
- **Static tokens** for design system: `--spacing-*`, `--shadow-*`, `--transition-*`
- **Quasar utility classes first** - prefer built-in classes over custom CSS
```css
/* design-system.scss - Theme Variables */
:root {
  /* Theme colors (switchable at runtime) */
  --theme-primary: #1976d2;
  --theme-primary-dark: #1565c0;
  --theme-primary-light: #42a5f5;
  --theme-secondary: #f5f5f5;
  --theme-accent: #1976d2;
  --theme-background: #ffffff;
  --theme-background-light: #f5f7fa;
  --theme-text: #424242;
  --theme-text-light: #757575;
  --theme-text-muted: #9e9e9e;
  --theme-border: #e0e0e0;
  --theme-success: #28a745;
  --theme-warning: #ffc107;
  --theme-error: #dc3545;
  --theme-info: #17a2b8;

  /* Gradients */
  --theme-gradient-hero: linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%);
  --theme-gradient-primary: linear-gradient(135deg, #1976d2 0%, #1565c0 100%);
  --theme-gradient-loading: linear-gradient(90deg, #f5f5f5 0%, #e0e0e0 50%, #f5f5f5 100%);
}
```

# Colors

## Contrast Requirements
- WCAG AA contrast >= 4.5:1 (normal text) and >= 3:1 (headings >= 18px or semibold)
- Never rely on color alone for states
- Include icon/text for visual clarity
- Validate light and dark mode

## Color Usage
- **Use Quasar color props** when possible: `color="primary"`, `color="warning"`, `color="negative"`
- **Custom colors via CSS variables** for brand-specific needs
- **Theme colors** for consistent branding across projects
```vue
<!-- ✅ Quasar color props -->
<q-btn label="Clear" color="warning" />
<q-btn label="Save" color="primary" />

<!-- ✅ Theme colors with CSS variables -->
<div class="themed-card">
  <h2 class="themed-title">Title</h2>
</div>

<style scoped>
.themed-card {
  background: var(--theme-background);
  border: 1px solid var(--theme-border);
}

.themed-title {
  color: var(--theme-primary);
}
</style>
```

## Semantic Color Palette
| Token | Purpose | Example |
|-------|---------|---------|
| `--theme-primary` | Brand color, CTAs | Buttons, links |
| `--theme-secondary` | Supporting elements | Backgrounds |
| `--theme-accent` | Highlights | Active states |
| `--theme-success` | Positive feedback | Success messages |
| `--theme-warning` | Caution states | Warnings |
| `--theme-error` | Error states | Validation errors |
| `--theme-info` | Informational | Tips, notices |

# Accessibility

## Semantic Structure
- Semantic landmarks (`<header>`, `<nav>`, `<main>`, `<footer>`)
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

## Accessibility Testing Checklist

### Keyboard Navigation
- [ ] All interactive elements focusable via Tab
- [ ] Focus order matches visual order
- [ ] Focus visible on all elements
- [ ] Escape closes modals/dropdowns
- [ ] Enter/Space activates buttons

### Screen Reader
- [ ] All images have alt text
- [ ] Form fields have labels
- [ ] Error messages announced
- [ ] Dynamic content uses aria-live
- [ ] Landmarks properly defined

### Visual
- [ ] 4.5:1 contrast for normal text
- [ ] 3:1 contrast for large text (18px+)
- [ ] Color not sole indicator
- [ ] Animations respect prefers-reduced-motion

### Testing Tools
- axe DevTools browser extension
- WAVE Web Accessibility Evaluator
- Lighthouse accessibility audit
- VoiceOver (Mac) / NVDA (Windows)

# Responsiveness

## Mobile-First Breakpoints
```scss
// Base styles for mobile (< 600px)
.container { padding: var(--spacing-md); }

// Tablet (600px - 1023px)
@media (min-width: 600px) {
  .container { padding: var(--spacing-lg); }
}

// Desktop (1024px - 1439px)
@media (min-width: 1024px) {
  .container { padding: var(--spacing-xl); max-width: 1200px; }
}

// Large Desktop (1440px+)
@media (min-width: 1440px) {
  .container { max-width: 1400px; }
}
```

## Touch Targets
- Minimum touch target 44x44
- Gap >= 8px between targets (use `q-gutter-sm` or larger)
- Adjustable density
- Layouts responsive via stack/scroll/cards

## Quasar Responsive Utilities
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

## useResponsive Composable
```typescript
import { useResponsive } from '@shared/composables/ui/useResponsive';

const { isMobile, isTablet, isDesktop, breakpoint } = useResponsive();

// Use in templates
// <div v-if="isMobile">Mobile view</div>
// <div v-else>Desktop view</div>
```

# Content

## Writing Guidelines
- Actionable messages ("Correct the CPF" instead of "Invalid CPF")
- Avoid jargon
- Consistent terminology
- Placeholders never replace labels
- Dates/numbers localized
- Abbreviations with title/tooltip
```html
<label>Date of Birth</label>
<!-- Placeholder "dd/mm/yyyy" + aria-describedby with format hint -->
```

# Forms

## Validation
- Per-field error with correction
- Aria-describedby for error message
- Required visible
- Optional fields labeled
- Masks only as helper
- Progressive validation without silent blocking

## useFormRules Composable
```typescript
import { useFormRules } from '@shared/composables/forms/useFormRules';

const { rules, emailRules, cpfRules, cnpjRules, phoneRules } = useFormRules();

// Available rules
rules.required        // Field is required
rules.email           // Valid email format
rules.minLength(n)    // Minimum n characters
rules.maxLength(n)    // Maximum n characters
rules.numeric         // Numbers only
rules.cpf             // Valid Brazilian CPF
rules.cnpj            // Valid Brazilian CNPJ
rules.phone           // Valid phone number
```

## Form Example
```vue
<template>
  <q-form @submit="onSubmit">
    <BaseInput
      v-model="form.email"
      label="Email"
      type="email"
      :rules="emailRules"
      aria-describedby="email-hint"
    />
    <span id="email-hint" class="text-caption">Enter your work email</span>
    
    <BaseInput
      v-model="form.cpf"
      label="CPF"
      mask="###.###.###-##"
      :rules="cpfRules"
    />
    
    <q-btn type="submit" label="Submit" color="primary" :loading="loading" />
  </q-form>
</template>

<script setup lang="ts">
import { BaseInput, useFormRules } from '@shared';

const { emailRules, cpfRules } = useFormRules();
</script>
```

# Media

## Images
- Meaningful alt (alt="" for decorative)
- Use srcset/sizes
- Preserve aspect ratio
- Captions for complex charts
- No autoplay with sound
```html
<img src="photo.jpg" srcset="photo@2x.jpg 2x" alt="Portrait of a smiling person">
```

## Lazy Loading
```vue
<q-img src="cover.jpg" ratio="16/9" loading="lazy" />
```

# Motion

## Animation Guidelines
- Respect prefers-reduced-motion
- Animation durations 150–300ms
- Perceptible skeleton loading (no aggressive shimmer)
- Critical toasts not auto-dismissing
- Aria-live for async feedback
```css
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; }
}

.card {
  transition: transform var(--transition-fast), box-shadow var(--transition-fast);
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-medium);
}
```

## Skeleton Loading
```vue
<template>
  <div v-if="loading" class="skeleton-card">
    <div class="skeleton-line skeleton-title"></div>
    <div class="skeleton-line"></div>
    <div class="skeleton-line"></div>
  </div>
  <div v-else>
    <!-- Actual content -->
  </div>
</template>

<style scoped>
.skeleton-card {
  padding: var(--spacing-lg);
}

.skeleton-line {
  height: 16px;
  background: var(--theme-gradient-loading);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: 4px;
  margin-bottom: var(--spacing-sm);
}

.skeleton-title {
  width: 60%;
  height: 24px;
}

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
</style>
```

# Tables

## Best Practices
- Clear headers
- Responsive via stack/scroll/cards
- No truncation without indicator
- Sorting and filters accessible
- Empty states must guide action
```html
<th scope="col">Name</th>
// Empty-state "No records found — click + to add"
```

## useTableColumns Composable
```typescript
import { useTableColumns } from '@shared/composables/data/useTableColumns';

const { columns, visibleColumns, toggleColumn } = useTableColumns([
  { name: 'name', label: 'Name', field: 'name', sortable: true },
  { name: 'email', label: 'Email', field: 'email', sortable: true },
  { name: 'status', label: 'Status', field: 'status' },
]);
```

# Privacy

## Data Masking
- Mask sensitive data by default
- Never show full identifiers (e.g., CPF)
```html
<!-- CPF displayed as ***.456.***-00 -->
```

# Metrics

## Performance Targets
- LCP < 2.5s
- FID < 100ms
- CLS < 0.1
- Lighthouse score >= 90

## Tracking
- Measure task time
- Success rate
- Errors per step
- CLS/LCP metrics
- Log correlationId for relevant events
```javascript
// log correlationId on "checkout_started" click event
```

# Landing Page Sections

## Section Structure
1. **Hero** - Value proposition, primary/secondary CTAs
2. **Problem** - Pain points addressed
3. **Features** - Key capabilities with icons (BaseFeatureCard)
4. **How It Works** - Process steps (BaseSteps)
5. **Pricing** - Plans/credits (BasePricingCard, BaseCreditCard)
6. **Social Proof** - Testimonials, logos
7. **CTA** - Final conversion section
8. **Footer** - Links, legal, social (BaseFooter)

## Section Spacing
```css
.section {
  padding: var(--spacing-3xl) 0; /* 64px vertical */
}

.section-title {
  margin-bottom: var(--spacing-2xl); /* 48px */
}
```

## Visual Hierarchy
- Use consistent section spacing (64px-80px between sections)
- Alternate background colors for visual separation
- Limit to 2-3 accent colors
- Maintain 60-30-10 color rule (primary-secondary-accent)

# Component Usage

## Available Shared Components

### Form Components
| Component | Purpose |
|-----------|---------|
| `BaseInput` | Text input with validation |
| `BaseSelect` | Single select dropdown |
| `BaseMultiSelect` | Multi-select with chips |
| `BaseTextarea` | Multiline text input |
| `BaseDatePicker` | Date selection |
| `BaseTimePicker` | Time selection |

### Layout Components
| Component | Purpose |
|-----------|---------|
| `BaseHeader` | Application header |
| `BaseSidebar` | Navigation sidebar |
| `BaseFooter` | Page footer |
| `BaseSection` | Content section wrapper |
| `BaseHero` | Hero/banner section |

### UI Components
| Component | Purpose |
|-----------|---------|
| `BaseButton` | Styled button |
| `BaseCard` | Content card |
| `BaseChip` | Tag/chip element |
| `BaseLogo` | Brand logo |
| `MetricCard` | Dashboard metric |
| `BasePricingCard` | Pricing plan card |
| `BaseCreditCard` | Credit package card |
| `BaseFeatureCard` | Feature highlight |
| `BaseSteps` | Process steps |