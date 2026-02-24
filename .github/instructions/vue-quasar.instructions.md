---
applyTo: "**/*.vue"
priority: medium
---

# SFC (Single File Components)
- Use `<script setup>` with TypeScript
- **Keep CSS in `<style scoped>`** within .vue files - this is the Vue 3 best practice
- Separate files only for: design tokens, CSS variables, global resets, utility classes
- Use `<style scoped lang="scss">` for component-specific styles
- Inherits frontend.instructions.md rules
```vue
<template>
  <div class="search-container">
    <!-- Prefer Quasar classes first -->
    <div class="row items-center justify-end q-gutter-md">
      <q-btn label="Action" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
const count = ref(0);
</script>

<style scoped lang="scss">
// ✅ Component-specific styles belong here
.search-container {
  background: var(--theme-background);
  border-radius: 16px;
  padding: var(--spacing-lg);
  box-shadow: var(--shadow-soft);
}

// ❌ Avoid duplicating what Quasar provides
// Use Quasar classes instead: row, items-center, q-gutter-md
</style>
```

# Composables

## Composable Categories

### UI Composables
```typescript
// useTheme - Theme management and switching
const { theme, setTheme, primaryColor, isDark } = useTheme();

// useDialog - Modal dialog helpers
const { confirm, alert, prompt } = useDialog();

// useResponsive - Breakpoint detection
const { isMobile, isTablet, isDesktop, breakpoint } = useResponsive();

// useNotification - Toast notifications
const { notify, success, error, warning, info } = useNotification();
```

### Form Composables
```typescript
// useFormRules - Validation rule factories
const { rules, emailRules, cpfRules, cnpjRules } = useFormRules();

// useBaseField - Field state management
const { value, error, validate, reset } = useBaseField(initialValue);
```

### Data Composables
```typescript
// useFilters - Filter state management
const { filters, applyFilters, resetFilters } = useFilters();

// useTableColumns - Column visibility
const { columns, visibleColumns, toggleColumn } = useTableColumns();

// useAsync - Loading/error state handling
const { data, loading, error, execute } = useAsync(fetchData);
```

### Utility Composables
```typescript
// useDebounce - Debounced values
const debouncedSearch = useDebounce(searchQuery, 300);

// usePagination - Pagination logic
const { page, pageSize, totalPages, nextPage, prevPage } = usePagination();
```

## Composable Naming
- Prefix with `use*`
- Use named exports (never default)
- Place in appropriate category folder
```typescript
// ✅ Good
export function useFormRules() { /* ... */ }
export function useTheme() { /* ... */ }

// ❌ Bad
export default function formRules() { /* ... */ }
```

# Pinia
- Global state management
- Composables consume stores without tight coupling to view components
```javascript
const userStore = useUserStore();
const { isLoggedIn } = storeToRefs(userStore)
```

# Router
- Lazy-load routes
- Implement guards in composables (useAuthGuard)
- Predictable scrollBehavior
```javascript
const routes = [{ path: '/users', component: () => import('pages/Users.vue') }];
router.beforeEach(useAuthGuard)
```

# Quasar
- Use QTable with row-key, virtual-scroll, server-side mode
- QForm with :greedy="true"
- QNotify or QBanner for user feedback
- **ALWAYS prefer Quasar utility classes over custom CSS**: Use `row`, `column`, `items-center`, `justify-between`, `q-gutter-md` instead of custom flexbox
- Only write custom CSS for specific design requirements not covered by Quasar
```vue
<!-- Prefer Quasar classes -->
<div class="row items-center justify-between q-gutter-md">
  <q-input v-model="search" />
  <q-btn label="Search" />
</div>

<!-- Avoid custom CSS when Quasar classes exist -->
<div class="custom-flex-container">
  <q-input v-model="search" />
  <q-btn label="Search" />
</div>

<q-form :greedy="true" @submit="onSubmit">
  <q-input v-model="name" />
</q-form>
```

# HTTP
- Boot axios + provide useApi composable
- Inherit frontend interceptors
```javascript
const api = useApi();
await api.get('/users')
```

# Performance
- Prefer computed over watch
- Watchers only in composables
- Use v-show instead of v-if for toggles
- ShallowRef/markRaw for heavy objects
```javascript
const fullName = computed(() => `${firstName.value} ${lastName.value}`)
```

# Layout
- QLayout with QDrawer behavior="mobile"
- Dense toolbars
- QImg with ratio and lazy loading
- **Use Quasar spacing utilities**: `q-mb-md`, `q-mt-lg`, `q-pa-sm`, `q-gutter-md`
- **Use Quasar flex utilities**: `row`, `column`, `items-start`, `items-center`, `items-end`, `justify-start`, `justify-center`, `justify-end`, `justify-between`
```vue
<q-img src="cover.jpg" ratio="16/9" loading="lazy" />

<!-- Quasar spacing -->
<div class="q-mb-md q-pa-lg">
  <div class="row items-center justify-end q-gutter-sm">
    <q-btn label="Clear" color="warning" />
    <q-btn label="Search" color="primary" />
  </div>
</div>
```

# Responsive
- UseResponsive composable for breakpoints
- Avoid widespread $q.screen
- Render QTable as grid on mobile
```javascript
const { isMobile } = useResponsive();
if (isMobile.value) { /* render grid */ }
```

# Safe areas
- Respect CSS env(safe-area-inset-*) for iOS/Android devices
```css
padding-bottom: env(safe-area-inset-bottom);
```

# QTable server-side
- Use useQTableData composable with query params (?page,size,sort,filter)
- Stable row-key
- Virtual-scroll and loading
```javascript
const { rows, loading } = useQTableData({ page, size, sort, filter })
```

# Component Prop Patterns

## Consistent Prop Interface
```typescript
// ✅ Good - Consistent across components
interface BaseComponentProps {
  modelValue?: unknown;      // v-model binding
  label?: string;            // Display label
  hint?: string;             // Helper text
  disable?: boolean;         // Disabled state
  loading?: boolean;         // Loading state
  rules?: ValidationRule[];  // Validation rules
}
```

## Event Naming
- Use `update:modelValue` for v-model
- Use past tense for completed actions: `selected`, `deleted`, `submitted`
- Use present tense for ongoing: `selecting`, `loading`
```vue
<script setup lang="ts">
const emit = defineEmits<{
  'update:modelValue': [value: string];
  'selected': [item: Item];
  'deleted': [id: string];
}>();
</script>
```

# Slot Patterns

## Named Slots for Flexibility
```vue
<template>
  <div class="base-card">
    <slot name="header">
      <div class="card-header">{{ title }}</div>
    </slot>
    
    <slot><!-- Default content --></slot>
    
    <slot name="actions">
      <div class="card-actions row q-gutter-sm">
        <q-btn v-if="showCancel" label="Cancel" @click="$emit('cancel')" />
        <q-btn label="Confirm" color="primary" @click="$emit('confirm')" />
      </div>
    </slot>
  </div>
</template>
```

## Scoped Slots for Data Exposure
```vue
<template>
  <BaseList :items="items">
    <template #item="{ item, index }">
      <CustomItem :data="item" :position="index" />
    </template>
  </BaseList>
</template>
```

# CSS Best Practices

## Hierarchy of CSS Approaches
1. **First choice**: Quasar utility classes (`row`, `column`, `items-center`, `q-gutter-md`, etc.)
2. **Second choice**: Design system utility classes from `design-system.scss` (`.truncate`, `.line-clamp-2`, etc.)
3. **Last resort**: Component-specific CSS in `<style scoped>`

## When to Use Each Approach
```vue
<template>
  <!-- ALWAYS prefer Quasar classes -->
  <div class="row items-center justify-between q-gutter-md q-mb-lg">
    <q-input v-model="search" class="col-grow" />
    <div class="row q-gutter-sm">
      <q-btn label="Clear" color="warning" />
      <q-btn label="Search" color="primary" />
    </div>
  </div>

  <!-- Use design-system utilities for common patterns -->
  <p class="truncate">Very long text that will be truncated...</p>
  <p class="line-clamp-2">Multi-line text limited to 2 lines...</p>

  <!-- Custom CSS only for unique component needs -->
  <div class="custom-gradient-background">
    Content with unique styling
  </div>
</template>

<style scoped lang="scss">
// Only write CSS that Quasar doesn't provide
.custom-gradient-background {
  background: var(--theme-gradient-primary);
  border-radius: 16px;
  padding: var(--spacing-lg);
  box-shadow: var(--shadow-soft);
  transition: all var(--transition-fast);
  
  &:hover {
    box-shadow: var(--shadow-medium);
    transform: translateY(-2px);
  }
}

// ❌ DON'T duplicate Quasar functionality
// .flex-row { display: flex; } → Use class="row"
// .items-center { align-items: center; } → Use class="items-center"
// .gap-md { gap: 1rem; } → Use class="q-gutter-md"
</style>
```

## Code Duplication Prevention
- Before writing custom CSS, check if Quasar provides it
- Document why custom CSS is needed with comments
- Add comments suggesting Quasar alternatives for future refactoring
```scss
// Note: Consider using Quasar class "row items-center" instead of custom flexbox
.custom-container {
  display: flex; // Required for specific animation needs
  align-items: center;
}
```

## Utility Classes from design-system.scss
Available reusable utilities (use sparingly, prefer Quasar first):
- `.truncate` - Single line ellipsis
- `.line-clamp-2`, `.line-clamp-3` - Multi-line truncation
- `.grid-auto-fit` - Responsive grid with auto-fit
- `.space-y-sm`, `.space-y-md`, `.space-y-lg` - Vertical spacing between children

# Theme Integration

## Using Theme in Components
```vue
<template>
  <div class="themed-card">
    <BaseLogo size="lg" :show-tagline="true" />
    <h2 class="themed-title">{{ title }}</h2>
  </div>
</template>

<script setup lang="ts">
import { useTheme } from '@shared/composables/ui/useTheme';

const { primaryColor, isDark } = useTheme();
</script>

<style scoped lang="scss">
.themed-card {
  background: var(--theme-background);
  border: 1px solid var(--theme-border);
  color: var(--theme-text);
}

.themed-title {
  color: var(--theme-primary);
  font-family: var(--theme-font-display);
}
</style>
```

## Theme-Aware Components
```vue
<template>
  <q-btn
    :color="isDark ? 'white' : 'primary'"
    :text-color="isDark ? 'primary' : 'white'"
    label="Action"
  />
</template>

<script setup lang="ts">
import { useTheme } from '@shared/composables/ui/useTheme';
const { isDark } = useTheme();
</script>
```
