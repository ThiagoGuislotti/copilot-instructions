<template>
  <div class="[COMPONENT_CLASS]">
    <!-- ✅ Use Quasar classes first -->
    <div class="row items-center q-gutter-md">
      <slot name="header">
        <div class="[COMPONENT_CLASS]__header">
          {{ title }}
        </div>
      </slot>
    </div>

    <!-- Default slot for main content -->
    <slot>
      <div class="[COMPONENT_CLASS]__content">
        <!-- Content here -->
      </div>
    </slot>

    <!-- Actions slot -->
    <slot name="actions">
      <div class="row q-gutter-sm justify-end">
        <q-btn
          v-if="showCancel"
          :label="cancelLabel"
          flat
          @click="$emit('cancel')"
        />
        <q-btn
          :label="confirmLabel"
          color="primary"
          :loading="loading"
          @click="$emit('confirm')"
        />
      </div>
    </slot>
  </div>
</template>

<script setup lang="ts">
/**
 * [COMPONENT_NAME]
 *
 * [COMPONENT_DESCRIPTION]
 *
 * @example
 * <[COMPONENT_TAG]
 *   title="Example Title"
 *   :loading="isLoading"
 *   @confirm="handleConfirm"
 * >
 *   <template #header>Custom Header</template>
 *   Content here
 * </[COMPONENT_TAG]>
 */

// ============================================================================
// PROPS
// ============================================================================
interface Props {
  /** Display title */
  title?: string;
  /** Show cancel button */
  showCancel?: boolean;
  /** Cancel button label */
  cancelLabel?: string;
  /** Confirm button label */
  confirmLabel?: string;
  /** Loading state */
  loading?: boolean;
  /** Disabled state */
  disable?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  showCancel: true,
  cancelLabel: 'Cancel',
  confirmLabel: 'Confirm',
  loading: false,
  disable: false,
});

// ============================================================================
// EMITS
// ============================================================================
const emit = defineEmits<{
  /** Emitted when confirm button is clicked */
  confirm: [];
  /** Emitted when cancel button is clicked */
  cancel: [];
}>();

// ============================================================================
// COMPOSABLES
// ============================================================================
// import { useTheme } from '@shared/composables/ui/useTheme';
// const { primaryColor, isDark } = useTheme();

// ============================================================================
// STATE
// ============================================================================
// const internalState = ref<string>('');

// ============================================================================
// COMPUTED
// ============================================================================
// const computedValue = computed(() => {
//   return props.title.toUpperCase();
// });

// ============================================================================
// METHODS
// ============================================================================
// const handleAction = () => {
//   emit('confirm');
// };

// ============================================================================
// LIFECYCLE
// ============================================================================
// onMounted(() => {
//   // Initialize component
// });
</script>

<style scoped lang="scss">
// ============================================================================
// COMPONENT: [COMPONENT_NAME]
// Design: Use theme variables for brand colors
// ============================================================================

.[COMPONENT_CLASS] {
  background: var(--theme-background);
  border: 1px solid var(--theme-border);
  border-radius: 12px;
  padding: var(--spacing-lg);
  box-shadow: var(--shadow-soft);
  transition: box-shadow var(--transition-fast);

  &:hover {
    box-shadow: var(--shadow-medium);
  }

  &__header {
    font-family: var(--theme-font-display);
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--theme-text);
    margin-bottom: var(--spacing-md);
  }

  &__content {
    color: var(--theme-text-light);
    line-height: 1.6;
  }
}

// ❌ DON'T duplicate Quasar functionality
// .flex-row { display: flex; } → Use class="row"
// .items-center { align-items: center; } → Use class="items-center"
// .gap-md { gap: 1rem; } → Use class="q-gutter-md"
</style>