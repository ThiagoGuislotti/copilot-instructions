/**
 * [COMPOSABLE_NAME]
 *
 * [COMPOSABLE_DESCRIPTION]
 *
 * @example
 * ```typescript
 * import { [COMPOSABLE_NAME] } from '@shared/composables/[CATEGORY]/[COMPOSABLE_NAME]';
 *
 * const { [RETURN_VALUE_1], [RETURN_VALUE_2], [METHOD_1] } = [COMPOSABLE_NAME]();
 *
 * // Use in template or script
 * console.log([RETURN_VALUE_1].value);
 * [METHOD_1]([PARAMETER]);
 * ```
 *
 * @category [CATEGORY: ui | forms | data | utils | services]
 */

import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import type { Ref, ComputedRef } from 'vue';

// ============================================================================
// TYPES
// ============================================================================

/** Configuration options for [COMPOSABLE_NAME] */
export interface [COMPOSABLE_NAME_PASCAL]Options {
  /** [OPTION_1_DESCRIPTION] */
  [OPTION_1]?: [OPTION_1_TYPE];
  /** [OPTION_2_DESCRIPTION] */
  [OPTION_2]?: [OPTION_2_TYPE];
}

/** Return type for [COMPOSABLE_NAME] */
export interface [COMPOSABLE_NAME_PASCAL]Return {
  /** [RETURN_VALUE_1_DESCRIPTION] */
  [RETURN_VALUE_1]: Ref<[RETURN_VALUE_1_TYPE]>;
  /** [RETURN_VALUE_2_DESCRIPTION] */
  [RETURN_VALUE_2]: ComputedRef<[RETURN_VALUE_2_TYPE]>;
  /** [METHOD_1_DESCRIPTION] */
  [METHOD_1]: ([PARAM]: [PARAM_TYPE]) => [RETURN_TYPE];
  /** [METHOD_2_DESCRIPTION] */
  [METHOD_2]: () => void;
}

// ============================================================================
// CONSTANTS
// ============================================================================

const DEFAULT_OPTIONS: Required<[COMPOSABLE_NAME_PASCAL]Options> = {
  [OPTION_1]: [DEFAULT_VALUE_1],
  [OPTION_2]: [DEFAULT_VALUE_2],
};

// ============================================================================
// COMPOSABLE
// ============================================================================

/**
 * [COMPOSABLE_DESCRIPTION_DETAILED]
 *
 * @param options - Configuration options
 * @returns Reactive state and methods
 */
export function [COMPOSABLE_NAME](
  options: [COMPOSABLE_NAME_PASCAL]Options = {}
): [COMPOSABLE_NAME_PASCAL]Return {
  // Merge options with defaults
  const config = { ...DEFAULT_OPTIONS, ...options };

  // ============================================================================
  // STATE
  // ============================================================================

  const [RETURN_VALUE_1] = ref<[RETURN_VALUE_1_TYPE]>([INITIAL_VALUE_1]);

  // ============================================================================
  // COMPUTED
  // ============================================================================

  const [RETURN_VALUE_2] = computed<[RETURN_VALUE_2_TYPE]>(() => {
    // Compute derived value
    return [COMPUTED_LOGIC];
  });

  // ============================================================================
  // METHODS
  // ============================================================================

  /**
   * [METHOD_1_DESCRIPTION]
   * @param [PARAM] - [PARAM_DESCRIPTION]
   * @returns [RETURN_DESCRIPTION]
   */
  const [METHOD_1] = ([PARAM]: [PARAM_TYPE]): [RETURN_TYPE] => {
    // Implementation
    [RETURN_VALUE_1].value = [PARAM];
    return [RETURN_VALUE];
  };

  /**
   * [METHOD_2_DESCRIPTION]
   */
  const [METHOD_2] = (): void => {
    // Reset or cleanup logic
    [RETURN_VALUE_1].value = [INITIAL_VALUE_1];
  };

  // ============================================================================
  // WATCHERS
  // ============================================================================

  // watch([RETURN_VALUE_1], (newValue, oldValue) => {
  //   // React to changes
  // });

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  // onMounted(() => {
  //   // Initialize
  // });

  // onUnmounted(() => {
  //   // Cleanup
  // });

  // ============================================================================
  // RETURN
  // ============================================================================

  return {
    [RETURN_VALUE_1],
    [RETURN_VALUE_2],
    [METHOD_1],
    [METHOD_2],
  };
}

// ============================================================================
// STANDALONE FUNCTIONS (if needed)
// ============================================================================

/**
 * Initialize [COMPOSABLE_NAME] globally
 * Call this in main.ts or boot file
 *
 * @param [PARAM] - [PARAM_DESCRIPTION]
 */
export function init[COMPOSABLE_NAME_PASCAL]([PARAM]: [PARAM_TYPE]): void {
  // Global initialization logic
}
