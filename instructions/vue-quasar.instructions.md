---
applyTo: "**/*.vue"
---
SFC: use <script setup> with TypeScript; inherits frontend.instructions.md rules.
Example: <script setup lang="ts"> import { ref } from 'vue'; const count = ref(0); </script>

Composables: provide useQTablePaging, useFormRules, useAuth, useDebouncedSearch for cross-feature logic.
Example: const { rows, pagination } = useQTablePaging(apiEndpoint)

Pinia: global state management; composables consume stores without tight coupling to view components.
Example: const userStore = useUserStore(); const { isLoggedIn } = storeToRefs(userStore)

Router: lazy-load routes; implement guards in composables (useAuthGuard); predictable scrollBehavior.
Example: const routes = [{ path: '/users', component: () => import('pages/Users.vue') }]; router.beforeEach(useAuthGuard)

Quasar: use QTable with row-key, virtual-scroll, server-side mode; QForm with :greedy="true"; QNotify or QBanner for user feedback.
Example: <q-form :greedy="true" @submit="onSubmit"><q-input v-model="name" /></q-form>

HTTP: boot axios + provide useApi composable; inherit frontend interceptors.
Example: const api = useApi(); await api.get('/users')

Performance: prefer computed over watch; watchers only in composables; use v-show instead of v-if for toggles; shallowRef/markRaw for heavy objects.
Example: const fullName = computed(() => `${firstName.value} ${lastName.value}`)

Layout: QLayout with QDrawer behavior="mobile"; dense toolbars; QImg with ratio and lazy loading.
Example: <q-img src="cover.jpg" ratio="16/9" loading="lazy" />

Responsive: useResponsive composable for breakpoints; avoid widespread $q.screen; render QTable as grid on mobile.
Example: const { isMobile } = useResponsive(); if (isMobile.value) { /* render grid */ }

Safe areas: respect CSS env(safe-area-inset-*) for iOS/Android devices.
Example: padding-bottom: env(safe-area-inset-bottom)

QTable server-side: use useQTableData composable with query params (?page,size,sort,filter); stable row-key; virtual-scroll and loading.
Example: const { rows, loading } = useQTableData({ page, size, sort, filter })