---
applyTo: "**/*.{html,css,scss,js,ts,jsx,tsx}"
priority: medium
---

# Architecture
- Hooks/composables for reactive logic
- Presentational components using props and slots
- Services for pure HTTP requests
- **Feature-first Clean Architecture**: modules/<feature>/{domain,application,infrastructure,presentation}
- **Shared resources**: shared/{domain,application,infrastructure,presentation,utils,constants}
- **CSS in SFC**: Keep component styles in `<style scoped>` within .vue files (Vue 3 best practice)
- **Prefer Quasar utilities**: Use Quasar classes before writing custom CSS
```javascript
const { rows } = useTablePaging(apiEndpoint);
<UserCard :user="u" v-slot:actions><button>Edit</button></UserCard>
```

# Naming
- Prefix composables with `use*`
- Never use default exports
- Avoid side effects on import
- Component files in PascalCase: `BaseButton.vue`, `SearchPage.vue`
- Composables in camelCase: `useAuth.ts`, `useFormRules.ts`
- CSS classes in kebab-case: `search-container`, `action-buttons`
```javascript
export function useAuth() { /* ... */ } // not export default
// Import modules without executing code automatically
```

# Component Library Pattern

## Base Component Naming
- Prefix shared components with `Base*`: `BaseButton`, `BaseInput`, `BaseCard`
- Use slots for flexible content injection
- Expose consistent prop interfaces across components
- Document props with JSDoc comments

## Component Categories
```
components/
├── form/           # BaseInput, BaseSelect, BaseTextarea, BaseDatePicker, BaseTimePicker
├── layout/         # BaseHeader, BaseFooter, BaseSection, BaseHero, BaseSidebar
└── ui/             # BaseButton, BaseCard, BaseChip, BaseLogo, MetricCard, InfoCard
```

## Export Pattern (Single Entry Point)
```typescript
// index.ts
export { default as BaseButton } from './components/ui/BaseButton.vue'
export { default as BaseInput } from './components/form/BaseInput.vue'
export * from './composables/ui/useTheme'
export * from './config/theme.config'
```

# Theme System

## Multi-Theme Architecture
- Define theme configuration interface with colors, fonts, gradients
- Use CSS custom properties for runtime theme switching
- Implement `useTheme` composable for reactive theme management
- Store theme preference in localStorage

## Theme Configuration Interface
```typescript
interface ThemeConfig {
  name: string;
  colors: {
    primary: string;
    primaryDark: string;
    primaryLight: string;
    secondary: string;
    accent: string;
    background: string;
    backgroundLight: string;
    text: string;
    textLight: string;
    textMuted: string;
    border: string;
    success: string;
    warning: string;
    error: string;
    info: string;
  };
  fonts: {
    display: string;  // Titles: Poppins
    body: string;     // Body: Inter
  };
  logo: {
    letter: string;
    text: string;
    tagline?: string;
  };
  gradients: {
    hero: string;
    primary: string;
    loading: string;
  };
}
```

## CSS Variable Naming Convention
```css
/* Theme-specific (runtime switchable) */
--theme-primary: #1976d2;
--theme-background: #ffffff;
--theme-text: #424242;

/* Static design tokens */
--spacing-xs: 4px;
--spacing-sm: 8px;
--spacing-md: 16px;
--spacing-lg: 24px;
--spacing-xl: 32px;
--spacing-2xl: 48px;
--spacing-3xl: 64px;

/* Shadows (softer for modern look) */
--shadow-soft: 0 2px 8px rgba(0, 0, 0, 0.05);
--shadow-medium: 0 4px 16px rgba(0, 0, 0, 0.08);
--shadow-strong: 0 8px 32px rgba(0, 0, 0, 0.1);

/* Transitions */
--transition-fast: 200ms ease-in-out;
--transition-normal: 300ms ease-in-out;
--transition-slow: 500ms ease-in-out;
```

## useTheme Composable
```typescript
import { useTheme, initTheme } from '@shared/composables/ui/useTheme';

// Initialize on app startup (main.ts)
initTheme('sentinela');

// Use in components
const {
  theme,           // Current theme config (readonly)
  themeName,       // Current theme name
  primaryColor,    // Computed primary color
  logo,            // Computed logo config
  isDark,          // Is dark theme?
  setTheme,        // Change theme by name
  setCustomTheme,  // Apply custom theme
} = useTheme();

// Switch themes at runtime
setTheme('platea');  // Teal theme
setTheme('dark');    // Dark mode
```

# HTTP
- Implement interceptors for token and correlationId
- Timeout
- Retry with backoff
- Cancel with AbortController
- Standard error object {code,message,details?,correlationId}
```javascript
// Request adds Authorization: Bearer <token> and x-correlation-id
// Response applies exponential backoff retry on 502/503/504
// Cancel via AbortController; timeout 10s
```

# Performance
- Apply code-splitting by route or feature
- Debounce or throttle events
- Optimize images and fonts
- Maintain Lighthouse score >= 90
- Target LCP < 2.5s, CLS < 0.1, FID < 100ms
```javascript
const onSearch = useDebouncedSearch(query => api.get('/users', { params: { q: query } }), 300)
```

# Forms
- Validate fields individually
- Show loading, error and success states clearly
- Use `useFormRules` composable for validation rules
```html
<input aria-describedby="email-error">
<span id="email-error">Invalid email format</span>
// Show spinner while submitting
```

## Form Validation Composable
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
```

# Security
- Enforce strict CSP
- Enable HSTS
- Configure cookies SameSite and Secure at gateway or reverse proxy
```http
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000
Set-Cookie: session=...; Secure; SameSite=Strict
```

# CSS Organization

## File Structure
- `shared/styles/design-system.scss` - CSS variables, design tokens, utility classes
- `shared/styles/global.scss` - Global base styles, reset, typography
- `shared/styles/quasar-variables.scss` - Quasar framework customization
- Component styles: `<style scoped lang="scss">` within .vue files

## CSS Hierarchy (Priority Order)
1. **Quasar utility classes** (ALWAYS FIRST): `row`, `column`, `items-center`, `justify-between`, `q-gutter-md`, `q-mb-lg`, `q-pa-sm`
2. **Design system utilities** (sparingly): `.truncate`, `.line-clamp-2`, `.grid-auto-fit`
3. **Component-specific CSS** (last resort): Custom styles in `<style scoped>`

## Best Practices
```vue
<template>
  <!-- ✅ CORRECT: Prefer Quasar classes -->
  <div class="row items-center justify-end q-gutter-md q-mb-lg">
    <q-btn label="Clear" color="warning" />
    <q-btn label="Search" color="primary" />
  </div>

  <!-- ✅ CORRECT: Design system utility when needed -->
  <p class="truncate">Very long text...</p>

  <!-- ✅ CORRECT: Scoped CSS for unique component needs -->
  <div class="custom-gradient">Content</div>
</template>

<style scoped lang="scss">
// Only write CSS that Quasar/design-system doesn't provide
.custom-gradient {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 16px;
  padding: var(--spacing-lg);
  box-shadow: var(--shadow-soft);
  transition: box-shadow var(--transition-fast);
  
  &:hover {
    box-shadow: var(--shadow-medium);
  }
}

// ❌ WRONG: Don't duplicate Quasar functionality
// .flex-container { display: flex; } → Use class="row"
// .space-between { justify-content: space-between; } → Use class="justify-between"
</style>
```

## Code Review Checklist
- [ ] Used Quasar classes for layout/spacing before writing custom CSS?
- [ ] Checked design-system.scss for existing utilities?
- [ ] Added comment explaining why custom CSS is needed?
- [ ] Used CSS variables for colors/spacing instead of hardcoded values?
- [ ] No duplicate code across components?
- [ ] Theme variables used for brand colors (--theme-*)?

# Landing Page Development

## Section Structure
1. **Hero** - Value proposition, primary/secondary CTAs
2. **Problem** - Pain points addressed
3. **Features** - Key capabilities with icons
4. **How It Works** - Process steps (BaseSteps component)
5. **Pricing** - Plans/credits (BasePricingCard, BaseCreditCard)
6. **Social Proof** - Testimonials, logos
7. **CTA** - Final conversion section
8. **Footer** - Links, legal, social

## Visual Hierarchy
- Use consistent section spacing (64px-80px between sections)
- Alternate background colors for visual separation
- Limit to 2-3 accent colors
- Maintain 60-30-10 color rule (primary-secondary-accent)

## Landing Page Components
```vue
<template>
  <BaseHero
    title="Welcome to Our Platform"
    subtitle="Build amazing applications"
    :cta-primary="{ label: 'Get Started', action: handleSignup }"
    :cta-secondary="{ label: 'Learn More', action: handleLearnMore }"
  />
  
  <BaseSection title="Features" subtitle="What we offer">
    <BaseFeatureCard
      v-for="feature in features"
      :key="feature.title"
      :icon="feature.icon"
      :title="feature.title"
      :description="feature.description"
    />
  </BaseSection>
  
  <BaseSteps :steps="processSteps" />
  
  <BasePricingCard
    title="Pro Plan"
    :price="29"
    period="month"
    :features="planFeatures"
    :highlighted="true"
  />
</template>
```

# Production
- Remove console.* and debugger
- Limit bundle size per route (< 200KB)
- **Eliminate code duplication**: Scan for duplicate directories/files before releases
- **Refactor to Quasar utilities**: Replace custom CSS with Quasar classes during maintenance
- **Design system consistency**: Use CSS variables from design-system.scss
- **Theme consistency**: Ensure all brand colors use --theme-* variables
```javascript
// eslint rule "no-console" and build analyzer to ensure < 200KB per route
// Regular scans to catch duplication: frontend/samples/ duplicating shared/
```
