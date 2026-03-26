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
```javascript
const onSearch = useDebouncedSearch(query => api.get('/users', { params: { q: query } }), 300)
```

# Forms
- Validate fields individually
- Show loading, error and success states clearly
```html
<input aria-describedby="email-error">
<span id="email-error">Invalid email format</span>
// Show spinner while submitting
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
- `shared/src/styles/design-system.scss` - CSS variables, design tokens, utility classes
- `shared/src/styles/global.scss` - Global base styles, reset, typography
- `shared/src/styles/quasar-variables.scss` - Quasar framework customization
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

# Production
- Remove console.* and debugger
- Limit bundle size per route
- **Eliminate code duplication**: Scan for duplicate directories/files before releases
- **Refactor to Quasar utilities**: Replace custom CSS with Quasar classes during maintenance
- **Design system consistency**: Use CSS variables from design-system.scss
```javascript
// eslint rule "no-console" and build analyzer to ensure < 200KB per route
// Regular scans to catch duplication: frontend/samples/ duplicating shared/
```