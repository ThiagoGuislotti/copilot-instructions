---
applyTo: "**/*.vue"
---

# SFC
- Use <script setup> with TypeScript
- Inherits frontend.instructions.md rules
```vue
<script setup lang="ts">
import { ref } from 'vue';
const count = ref(0);
</script>
```

# Composables
- Provide useQTablePaging, useFormRules, useAuth, useDebouncedSearch for cross-feature logic
```javascript
const { rows, pagination } = useQTablePaging(apiEndpoint)
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
```vue
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
```vue
<q-img src="cover.jpg" ratio="16/9" loading="lazy" />
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