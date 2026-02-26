/**
 * Theme Configuration Template
 *
 * This template provides the structure for defining themes in the nettoolskit-ui-vue
 * design system. Each theme includes colors, fonts, logo, and gradients.
 *
 * @example
 * ```typescript
 * import { [PROJECT_NAME]Theme } from './theme.config';
 * import { initTheme } from '@shared/composables/ui/useTheme';
 *
 * // Initialize theme on app startup
 * initTheme('[PROJECT_NAME_LOWERCASE]');
 * ```
 */

// ============================================================================
// TYPES
// ============================================================================

/** Theme color palette */
export interface ThemeColors {
  /** Primary brand color */
  primary: string;
  /** Darker shade of primary (hover states) */
  primaryDark: string;
  /** Lighter shade of primary (backgrounds) */
  primaryLight: string;
  /** Secondary/neutral color */
  secondary: string;
  /** Accent color for highlights */
  accent: string;
  /** Main background color */
  background: string;
  /** Light background for sections */
  backgroundLight: string;
  /** Primary text color */
  text: string;
  /** Secondary text color */
  textLight: string;
  /** Muted/disabled text color */
  textMuted: string;
  /** Border color */
  border: string;
  /** Success state color */
  success: string;
  /** Warning state color */
  warning: string;
  /** Error state color */
  error: string;
  /** Info state color */
  info: string;
}

/** Theme font configuration */
export interface ThemeFonts {
  /** Display font for headings (e.g., 'Poppins') */
  display: string;
  /** Body font for text (e.g., 'Inter') */
  body: string;
}

/** Theme logo configuration */
export interface ThemeLogo {
  /** Single letter for compact logo */
  letter: string;
  /** Full text for logo */
  text: string;
  /** Optional tagline */
  tagline?: string;
}

/** Theme gradient definitions */
export interface ThemeGradients {
  /** Hero section background gradient */
  hero: string;
  /** Primary gradient for buttons/CTAs */
  primary: string;
  /** Loading skeleton animation gradient */
  loading: string;
}

/** Complete theme configuration */
export interface ThemeConfig {
  /** Theme display name */
  name: string;
  /** Color palette */
  colors: ThemeColors;
  /** Font configuration */
  fonts: ThemeFonts;
  /** Logo configuration */
  logo: ThemeLogo;
  /** Gradient definitions */
  gradients: ThemeGradients;
}

// ============================================================================
// THEME DEFINITIONS
// ============================================================================

/**
 * [PROJECT_NAME] Theme
 *
 * [THEME_DESCRIPTION]
 * Primary color: [PRIMARY_COLOR_HEX]
 * Use case: [USE_CASE_DESCRIPTION]
 */
export const [PROJECT_NAME_CAMEL]Theme: ThemeConfig = {
  name: '[PROJECT_NAME]',
  colors: {
    // Primary palette
    primary: '[PRIMARY_COLOR]',        // e.g., '#1976d2' (blue) or '#4A9B7F' (teal)
    primaryDark: '[PRIMARY_DARK]',     // Darker shade for hover
    primaryLight: '[PRIMARY_LIGHT]',   // Lighter shade for backgrounds

    // Neutral palette
    secondary: '#f5f5f5',
    accent: '[PRIMARY_COLOR]',         // Usually same as primary

    // Backgrounds
    background: '#ffffff',
    backgroundLight: '#f5f7fa',

    // Text
    text: '#424242',
    textLight: '#757575',
    textMuted: '#9e9e9e',

    // Borders
    border: '#e0e0e0',

    // Semantic colors
    success: '#28a745',
    warning: '#ffc107',
    error: '#dc3545',
    info: '#17a2b8',
  },
  fonts: {
    display: 'Poppins',
    body: 'Inter',
  },
  logo: {
    letter: '[LOGO_LETTER]',           // e.g., 'S' for Sentinela
    text: '[PROJECT_NAME]',
    tagline: '[TAGLINE]',              // e.g., 'Sistema de Busca'
  },
  gradients: {
    hero: 'linear-gradient(135deg, #ffffff 0%, #f5f7fa 100%)',
    primary: 'linear-gradient(135deg, [PRIMARY_COLOR] 0%, [PRIMARY_DARK] 100%)',
    loading: 'linear-gradient(90deg, #f5f5f5 0%, #e0e0e0 50%, #f5f5f5 100%)',
  },
};

/**
 * Dark Theme
 *
 * Dark mode variant for reduced eye strain
 */
export const darkTheme: ThemeConfig = {
  name: 'Dark',
  colors: {
    primary: '#6366f1',
    primaryDark: '#4f46e5',
    primaryLight: '#818cf8',
    secondary: '#1e1e2e',
    accent: '#6366f1',
    background: '#0f0f1a',
    backgroundLight: '#1e1e2e',
    text: '#e4e4e7',
    textLight: '#a1a1aa',
    textMuted: '#71717a',
    border: '#27272a',
    success: '#22c55e',
    warning: '#eab308',
    error: '#ef4444',
    info: '#3b82f6',
  },
  fonts: {
    display: 'Poppins',
    body: 'Inter',
  },
  logo: {
    letter: '[LOGO_LETTER]',
    text: '[PROJECT_NAME]',
    tagline: '[TAGLINE]',
  },
  gradients: {
    hero: 'linear-gradient(135deg, #0f0f1a 0%, #1e1e2e 100%)',
    primary: 'linear-gradient(135deg, #6366f1 0%, #4f46e5 100%)',
    loading: 'linear-gradient(90deg, #1e1e2e 0%, #27272a 50%, #1e1e2e 100%)',
  },
};

// ============================================================================
// THEME REGISTRY
// ============================================================================

/** Available themes */
export const themes = {
  [PROJECT_NAME_LOWERCASE]: [PROJECT_NAME_CAMEL]Theme,
  dark: darkTheme,
} as const;

/** Theme name type */
export type ThemeName = keyof typeof themes;

/** Default theme */
export const DEFAULT_THEME: ThemeName = '[PROJECT_NAME_LOWERCASE]';

// ============================================================================
// CSS VARIABLE MAPPING
// ============================================================================

/**
 * Apply theme to document via CSS variables
 *
 * @param theme - Theme configuration to apply
 */
export function applyThemeToDocument(theme: ThemeConfig): void {
  const root = document.documentElement;

  // Colors
  Object.entries(theme.colors).forEach(([key, value]) => {
    const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
    root.style.setProperty(`--theme-${cssKey}`, value);
  });

  // Fonts
  root.style.setProperty('--theme-font-display', theme.fonts.display);
  root.style.setProperty('--theme-font-body', theme.fonts.body);

  // Gradients
  Object.entries(theme.gradients).forEach(([key, value]) => {
    root.style.setProperty(`--theme-gradient-${key}`, value);
  });
}