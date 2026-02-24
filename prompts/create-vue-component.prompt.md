---
description: Generate Vue 3 components with Composition API, TypeScript, and Quasar Framework
mode: ask
tools: ['codebase', 'search', 'findFiles', 'readFile']
---

# Create Vue Component
Generate a Vue 3 component following repository standards with Composition API, TypeScript, and Quasar integration.

## Instructions
Create a new Vue component based on:
- [vue-quasar.instructions.md](../.github/instructions/vue-quasar.instructions.md)
- [vue-quasar-architecture.instructions.md](../.github/instructions/vue-quasar-architecture.instructions.md)
- [frontend.instructions.md](../.github/instructions/frontend.instructions.md)
- [ui-ux.instructions.md](../.github/instructions/ui-ux.instructions.md)

## Input Variables
- `${input:componentName:Component name (PascalCase)}` - Component name
- `${input:featurePath:Feature path (e.g., features/orders)}` - Location in feature structure
- `${input:componentType:Type (Page/Dialog/Form/Card/List)}` - Component category
- `${input:hasStore:Use Pinia store? (yes/no)}` - Whether to include store integration

## Component Structure

### Template Section
```vue
<template>
  <q-${componentType} class="${kebab-case-name}">
    <!-- Quasar components with proper structure -->
    <q-card-section v-if="loading">
      <q-spinner color="primary" size="3em" />
    </q-card-section>
    
    <q-card-section v-else>
      <!-- Component content -->
    </q-card-section>
  </q-${componentType}>
</template>
```

### Script Setup with TypeScript
```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useI18n } from 'vue-i18n';

// Props definition with TypeScript
interface Props {
  modelValue?: string;
  readonly?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  readonly: false
});

// Emits definition
interface Emits {
  (e: 'update:modelValue', value: string): void;
  (e: 'submit'): void;
}

const emit = defineEmits<Emits>();

// Composables
const $q = useQuasar();
const { t } = useI18n();

// Reactive state
const loading = ref(false);
const data = ref<DataType[]>([]);

// Computed properties
const hasData = computed(() => data.value.length > 0);

// Lifecycle
onMounted(async () => {
  await loadData();
});

// Methods
async function loadData() {
  try {
    loading.value = true;
    // Implementation
  } catch (error) {
    $q.notify({
      type: 'negative',
      message: t('errors.loadFailed')
    });
  } finally {
    loading.value = false;
  }
}
</script>
```

### Styling
```vue
<style scoped lang="scss">
.${kebab-case-name} {
  // Component-specific styles
  // Use Quasar utilities when possible
  padding: $space-md;
  
  &__section {
    margin-bottom: $space-sm;
  }
}
</style>
```

## Requirements

### TypeScript Integration
- Define interfaces for props, emits, and data structures
- Use type annotations for all reactive declarations
- Export types if used by other components

### i18n Localization
- All user-facing text through `t()` function
- Keys in EN, translations in pt-BR
- Namespace keys by feature: `featureName.componentName.textKey`

### Quasar Components
- Use appropriate Quasar components (QBtn, QInput, QTable, etc.)
- Follow Quasar naming conventions (kebab-case in template)
- Include loading states and error handling
- Use Quasar plugins: Notify, Dialog, Loading

### Pinia Store Integration (if applicable)
```typescript
import { useFeatureStore } from '@/stores/featureStore';

const store = useFeatureStore();

// Use store actions and getters
const items = computed(() => store.items);
await store.fetchItems();
```

### Error Handling
- Try-catch blocks for async operations
- User-friendly error notifications with Quasar Notify
- Proper loading state management
- Graceful degradation for failed operations

### Accessibility
- Proper ARIA labels
- Keyboard navigation support
- Focus management
- Semantic HTML structure

## File Organization
Place component in feature-first structure:
```
src/
  features/
    ${featurePath}/
      components/
        ${ComponentName}.vue
      composables/
        use${ComponentName}.ts
      types/
        ${componentName}.types.ts
```

Generate clean, production-ready Vue 3 component following all repository conventions.