---
applyTo: frontend/**/*.{vue,ts,js}
priority: high
---

# Vue + Quasar Clean Architecture

Follow feature-first organization aligned with Clean Architecture layers.

# Structure Overview

```
frontend/src/
├── app/                    # Application composition (global)
│   ├── router/            # Vue Router + guards
│   ├── store/             # Pinia stores (global only)
│   ├── boot/              # Quasar boot files (axios, auth, sentry, dayjs)
│   ├── styles/            # Global styles (quasar-variables.sass)
│   └── plugins/           # Vue/Quasar plugins
├── i18n/                  # Internationalization (global)
│   ├── index.ts           # vue-i18n configuration
│   └── locales/           # Translation files (pt-BR.ts, en-US.ts)
├── shared/                # Cross-cutting, independent of features
│   ├── domain/            # Pure types, value objects, errors
│   ├── application/       # Generic use cases, validators, ports
│   │   └── services/      # Shared services (NotificationService, FilterService)
│   ├── infrastructure/    # HTTP clients, storage, logger, gateways
│   │   └── adapters/      # Shared adapters (QuasarNotificationAdapter)
│   ├── presentation/      # Reusable UI components (atoms/molecules), icons
│   │   ├── components/    # Shared components (BaseInput, BaseButton, MetricCard)
│   │   └── composables/   # Shared composables (useNotification, useFormRules)
│   ├── config/            # Configuration files (theme.config.ts)
│   ├── utils/             # Pure helpers
│   ├── constants/         # Shared constants
│   └── dtos/              # Data Transfer Objects
├── modules/               # Feature-first modules (isolated by layers)
│   └── <feature>/
│       ├── domain/        # Entities, Value Objects, repository contracts
│       ├── application/   # Feature use cases (services), ports
│       ├── infrastructure/# Adapters to APIs, mappers, repositories
│       └── presentation/  # Vue + Quasar pages/components
│           ├── pages/     # Feature pages
│           ├── components/# Feature-specific components
│           ├── composables/# Feature-specific composables
│           ├── forms/     # Feature-specific form logic
│           └── routes.ts  # Feature routes
├── layouts/               # Global Quasar layouts (MainLayout.vue)
├── App.vue                # Root component
└── main.ts                # Application entry point
```

## ❌ FORBIDDEN Structures (DO NOT CREATE)

These folders should NOT exist in `frontend/src/`:
- ❌ `src/pages/` → Pages belong in `modules/<feature>/presentation/pages/`
- ❌ `src/components/` → Components belong in `shared/presentation/components/` or `modules/<feature>/presentation/components/`
- ❌ `src/presentation/` → Presentation layer must be inside `shared/` or `modules/`
- ❌ `src/app/i18n/` → Internationalization is in `src/i18n/` (not inside app/)
- ❌ `src/composables/` → Composables belong in `shared/presentation/composables/` or feature presentation layer
- ❌ `src/samples/` → Demo/sample code should not duplicate `shared/` or module code. Remove immediately if found.

# Layer Rules

## Domain Layer
- Pure TypeScript models and business rules
- No Vue/Quasar imports
- No external dependencies (except utility types)
- Contains: Entities, Value Objects, Domain Errors, Repository Interfaces
- Example: `Invoice.ts`, `Money.ts`, `InvoiceRepo.ts` (interface)

## Application Layer
- Use cases and orchestration
- Depends on domain and ports (interfaces)
- No Vue/Quasar imports
- Contains: Services, Use Cases, Application Errors, Port Definitions
- Example: `CreateInvoice.ts`, `ListInvoices.ts`

## Infrastructure Layer
- Implements ports using concrete adapters
- Uses axios/fetch, localStorage, IndexedDB, WebSockets
- Contains: HTTP repositories, Mappers, DTOs, API clients
- Maps backend DTOs to domain entities
- Example: `HttpInvoiceRepo.ts` implements `InvoiceRepo`

## Presentation Layer
- Vue + Quasar components, pages, composables
- Can import from application and domain
- Contains: Pages, Components, Forms, Composables, Local State
- Example: `BillingListPage.vue`, `InvoiceTable.vue`, `useInvoiceForm.ts`

# Import Boundaries

## MUST FOLLOW
```typescript
// ✅ Allowed
presentation → application, domain
application → domain, ports
infrastructure → domain, ports

// ❌ Forbidden
application → presentation
domain → application, infrastructure, presentation
infrastructure → presentation (optional restriction)
```

## Import Aliases
```typescript
// Use these aliases consistently
import { Invoice } from '@shared/domain/Invoice'
import { CreateInvoice } from '@modules/billing/application/CreateInvoice'
import { HttpInvoiceRepo } from '@modules/billing/infrastructure/HttpInvoiceRepo'
import { InvoiceTable } from '@modules/billing/presentation/components/InvoiceTable.vue'
```

# Shared Component Library (nettoolskit-ui-vue)

## Structure
```
shared/
├── adapters/                    # Infrastructure adapters
│   └── QuasarNotificationAdapter.ts
├── components/                  # Vue components
│   ├── form/                    # Form inputs
│   │   ├── BaseInput.vue
│   │   ├── BaseSelect.vue
│   │   ├── BaseMultiSelect.vue
│   │   ├── BaseTextarea.vue
│   │   ├── BaseDatePicker.vue
│   │   └── BaseTimePicker.vue
│   ├── layout/                  # Layout components
│   │   ├── BaseHeader.vue
│   │   ├── BaseSidebar.vue
│   │   ├── BaseFooter.vue
│   │   ├── BaseSection.vue
│   │   └── BaseHero.vue
│   └── ui/                      # UI components
│       ├── BaseButton.vue
│       ├── BaseCard.vue
│       ├── BaseChip.vue
│       ├── BaseLogo.vue
│       ├── MetricCard.vue
│       ├── InfoCard.vue
│       ├── BasePricingCard.vue
│       ├── BaseCreditCard.vue
│       ├── BaseFeatureCard.vue
│       ├── BaseSteps.vue
│       └── SectionHeader.vue
├── composables/                 # Vue composables
│   ├── data/
│   │   ├── useFilters.ts
│   │   └── useTableColumns.ts
│   ├── forms/
│   │   ├── useFormRules.ts
│   │   └── useBaseField.ts
│   ├── services/
│   │   └── useNotification.ts
│   ├── ui/
│   │   ├── useDialog.ts
│   │   ├── useDialogActions.ts
│   │   ├── useResponsive.ts
│   │   └── useTheme.ts
│   └── utils/
│       ├── useDebounce.ts
│       └── useAsync.ts
├── config/                      # Configuration
│   └── theme.config.ts          # Theme definitions
├── services/                    # Business services
│   ├── NotificationService.ts
│   ├── FilterService.ts
│   └── FormValidationService.ts
├── styles/                      # SCSS styles
│   ├── design-system.scss       # CSS variables & tokens
│   ├── global.scss              # Global styles
│   └── quasar-variables.scss    # Quasar customization
├── utils/                       # Utility functions
│   ├── validators.ts
│   └── async.ts
└── index.ts                     # Single entry point
```

## Single Entry Point Export
```typescript
// shared/index.ts
// ============================================================================
// COMPONENTS - Form
// ============================================================================
export { default as BaseInput } from './components/form/BaseInput.vue'
export { default as BaseSelect } from './components/form/BaseSelect.vue'
export { default as BaseMultiSelect } from './components/form/BaseMultiSelect.vue'
export { default as BaseTextarea } from './components/form/BaseTextarea.vue'
export { default as BaseDatePicker } from './components/form/BaseDatePicker.vue'
export { default as BaseTimePicker } from './components/form/BaseTimePicker.vue'

// ============================================================================
// COMPONENTS - Layout
// ============================================================================
export { default as BaseHeader } from './components/layout/BaseHeader.vue'
export { default as BaseSidebar } from './components/layout/BaseSidebar.vue'
export { default as BaseFooter } from './components/layout/BaseFooter.vue'
export { default as BaseSection } from './components/layout/BaseSection.vue'
export { default as BaseHero } from './components/layout/BaseHero.vue'

// ============================================================================
// COMPONENTS - UI
// ============================================================================
export { default as BaseButton } from './components/ui/BaseButton.vue'
export { default as BaseCard } from './components/ui/BaseCard.vue'
export { default as BaseChip } from './components/ui/BaseChip.vue'
export { default as BaseLogo } from './components/ui/BaseLogo.vue'
export { default as MetricCard } from './components/ui/MetricCard.vue'
export { default as BasePricingCard } from './components/ui/BasePricingCard.vue'
export { default as BaseCreditCard } from './components/ui/BaseCreditCard.vue'
export { default as BaseFeatureCard } from './components/ui/BaseFeatureCard.vue'
export { default as BaseSteps } from './components/ui/BaseSteps.vue'

// ============================================================================
// COMPOSABLES
// ============================================================================
export * from './composables/forms/useFormRules'
export * from './composables/forms/useBaseField'
export * from './composables/ui/useDialog'
export * from './composables/ui/useResponsive'
export * from './composables/ui/useTheme'
export * from './composables/data/useFilters'
export * from './composables/data/useTableColumns'
export * from './composables/utils/useDebounce'
export * from './composables/utils/useAsync'
export * from './composables/services/useNotification'

// ============================================================================
// SERVICES
// ============================================================================
export * from './services/NotificationService'
export * from './services/FilterService'
export * from './services/FormValidationService'

// ============================================================================
// CONFIG - Theme
// ============================================================================
export * from './config/theme.config'
```

## Usage in Features
```typescript
// Import from single entry point
import {
  BaseInput,
  BaseButton,
  BaseCard,
  useFormRules,
  useTheme,
  useNotification,
} from '@shared';

// Or import specific items
import { BaseInput } from '@shared/components/form/BaseInput.vue';
import { useTheme } from '@shared/composables/ui/useTheme';
```

# Theme Configuration

## Theme Config Structure
```typescript
// shared/config/theme.config.ts
export interface ThemeConfig {
  name: string;
  colors: ThemeColors;
  fonts: ThemeFonts;
  logo: ThemeLogo;
  gradients: ThemeGradients;
}

export const sentinelaTheme: ThemeConfig = {
  name: 'Sentinela',
  colors: {
    primary: '#1976d2',
    primaryDark: '#1565c0',
    primaryLight: '#42a5f5',
    // ... other colors
  },
  fonts: {
    display: 'Poppins',
    body: 'Inter',
  },
  logo: {
    letter: 'S',
    text: 'Sentinela',
    tagline: 'Sistema de Busca',
  },
  gradients: {
    hero: 'linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%)',
    primary: 'linear-gradient(135deg, #1976d2 0%, #1565c0 100%)',
  },
};

export const plateaTheme: ThemeConfig = {
  name: 'PlaTEA',
  colors: {
    primary: '#4A9B7F',
    primaryDark: '#3a7a63',
    primaryLight: '#6bc4a6',
    // ... other colors
  },
  // ...
};

export const themes = {
  sentinela: sentinelaTheme,
  platea: plateaTheme,
  dark: darkTheme,
} as const;
```

## Theme Initialization
```typescript
// main.ts
import { initTheme } from '@shared';

// Initialize theme on app startup
initTheme('sentinela'); // or 'platea', 'dark'
```

# Module Example: demo

```
modules/demo/
├── domain/
│   ├── DemoEntity.ts           # Entity (if needed)
│   └── types.ts                # Domain types
├── application/
│   ├── DemoService.ts          # Use case/Service
│   └── types.ts                # Application types
├── infrastructure/
│   ├── HttpDemoRepo.ts         # Repository implementation
│   ├── mappers/
│   │   └── demo.mapper.ts      # DTO ↔ Domain mapping
│   └── dto/
│       └── demo.dto.ts         # Backend DTOs
├── presentation/
│   ├── pages/
│   │   └── DemoPage.vue        # Feature page
│   ├── components/
│   │   ├── MetricCard.vue      # Feature-specific component
│   │   └── DataTable.vue
│   ├── composables/
│   │   └── useDemoData.ts      # Feature-specific composable
│   └── routes.ts               # Feature routes
└── index.ts                    # Barrel export
```

# Stores (Pinia)

## Feature Stores
Place feature stores inside the feature module:
- `modules/<feature>/application/<Feature>Store.ts` (business logic)
- `modules/<feature>/presentation/store.ts` (UI-coupled state)

## Global Stores
Keep truly global stores in:
- `app/store/authStore.ts`
- `app/store/settingsStore.ts`

# Routing

## Feature Routes
Each module exports its routes:
```typescript
// modules/billing/presentation/routes.ts
export const billingRoutes = [
  {
    path: '/billing',
    component: () => import('./pages/BillingListPage.vue'),
    meta: { requiresAuth: true }
  }
]
```

## Root Router
Aggregate all feature routes:
```typescript
// app/router/index.ts
import { billingRoutes } from '@modules/billing/presentation/routes'

const routes = [
  ...billingRoutes,
  // ... other modules
]
```

# Quasar Integration

## Boot Files
Configure integrations in `app/boot/`:
- `axios.ts` - HTTP client setup
- `auth.ts` - Authentication
- `sentry.ts` - Error tracking
- `dayjs.ts` - Date utilities
- `theme.ts` - Theme initialization

## Theme Boot File
```typescript
// app/boot/theme.ts
import { boot } from 'quasar/wrappers';
import { initTheme } from '@shared';

export default boot(() => {
  initTheme('sentinela');
});
```

## Global Styles
Keep in `app/styles/`:
- `quasar-variables.sass` - Quasar variable overrides
- `global.scss` - Global CSS

# Composables

## Feature Composables
Place inside module's presentation:
```typescript
// modules/billing/presentation/forms/useInvoiceForm.ts
export function useInvoiceForm() {
  // Feature-specific form logic
}
```

## Generic Composables
Place in shared:
```typescript
// shared/composables/utils/useDebounce.ts
export function useDebounce<T>(value: Ref<T>, delay: number) {
  // Generic reusable logic
}
```

# Testing

## Unit Tests
- Domain: Pure and fast
- Application: Mock ports
- Infrastructure: MSW/axios-mock
- Presentation: @vue/test-utils

## Test Location
```
tests/
├── unit/
│   ├── domain/
│   ├── application/
│   ├── infrastructure/
│   └── presentation/
└── e2e/
    └── billing/
```

# Best Practices

## 0. CSS Organization
- **Always prefer Quasar utility classes** (`row`, `column`, `items-center`, `q-gutter-md`) over custom CSS
- Keep component-specific CSS in `<style scoped>` within .vue files (Vue 3 best practice)
- Separate files only for: design tokens (design-system.scss), global resets (global.scss), Quasar variables
- Add utility classes to design-system.scss sparingly - prefer Quasar classes first
- Before writing custom CSS, check if Quasar provides the functionality
- Document why custom CSS is needed with comments in the code
- **Use theme CSS variables** for brand colors (--theme-primary, --theme-background, etc.)

## 1. Feature Isolation
Keep features self-contained in modules/. Avoid cross-feature dependencies.

## 2. Barrel Exports
Use index.ts to control public API:
```typescript
// modules/billing/index.ts
export { CreateInvoice } from './application/CreateInvoice'
export { InvoiceTable } from './presentation/components/InvoiceTable.vue'
// Don't export internal implementation details
```

## 3. DTO Mapping
Always map DTOs in infrastructure layer:
```typescript
// infrastructure/mappers/invoice.mapper.ts
export class InvoiceMapper {
  static toDomain(dto: InvoiceDTO): Invoice {
    return new Invoice(dto.id, new Money(dto.amount, dto.currency))
  }

  static toDTO(invoice: Invoice): InvoiceDTO {
    return {
      id: invoice.id,
      amount: invoice.money.amount,
      currency: invoice.money.currency
    }
  }
}
```

## 4. Prevent Layer Violations
Use ESLint plugin-boundaries or import/no-restricted-paths:
```javascript
// .eslintrc.cjs
rules: {
  'boundaries/element-types': ['error', {
    rules: [
      { from: 'application', disallow: ['presentation'] },
      { from: 'domain', disallow: ['application','infrastructure','presentation'] }
    ]
  }]
}
```

## 5. Pure Domain
Domain layer must be framework-agnostic:
```typescript
// ✅ Good - Pure domain
export class Invoice {
  constructor(
    public readonly id: string,
    public readonly money: Money
  ) {}
}

// ❌ Bad - Framework coupled
import { Ref } from 'vue'
export class Invoice {
  public readonly amount: Ref<number>
}
```

# Migration Strategy

When refactoring existing code to this architecture:

1. **Create module structure** for new features
2. **Move domain models** to domain/ folder
3. **Extract use cases** to application/ folder
4. **Move API calls** to infrastructure/ folder
5. **Keep Vue components** in presentation/ folder
6. **Update imports** to use aliases
7. **Add barrel exports** (index.ts)
8. **Remove code duplication**: Check for duplicate directories (e.g., `samples/` duplicating `shared/`)
9. **Refactor CSS**: Replace custom flexbox with Quasar classes, keep scoped styles in .vue files
10. **Add design system utilities**: Create reusable utilities in design-system.scss only when Quasar doesn't provide them
11. **Implement theme system**: Add theme.config.ts and useTheme composable for multi-project support

# Common Patterns

## Repository Pattern
```typescript
// domain/InvoiceRepo.ts (interface)
export interface InvoiceRepo {
  findById(id: string): Promise<Invoice>
  save(invoice: Invoice): Promise<void>
}

// infrastructure/HttpInvoiceRepo.ts (implementation)
export class HttpInvoiceRepo implements InvoiceRepo {
  async findById(id: string): Promise<Invoice> {
    const dto = await api.get(`/invoices/${id}`)
    return InvoiceMapper.toDomain(dto)
  }
}
```

## Use Case Pattern
```typescript
// application/CreateInvoice.ts
export class CreateInvoice {
  constructor(private repo: InvoiceRepo) {}

  async execute(data: CreateInvoiceData): Promise<Invoice> {
    const invoice = Invoice.create(data)
    await this.repo.save(invoice)
    return invoice
  }
}
```

## Composable Pattern
```typescript
// presentation/forms/useInvoiceForm.ts
import { CreateInvoice } from '../../application/CreateInvoice'
import { HttpInvoiceRepo } from '../../infrastructure/HttpInvoiceRepo'

export function useInvoiceForm() {
  const repo = new HttpInvoiceRepo()
  const createInvoice = new CreateInvoice(repo)

  const submit = async (data: FormData) => {
    await createInvoice.execute(data)
  }

  return { submit }
}
```

# Reference

Full documentation: `.docs/frontend/vue-quasar-clean-architecture-structure.md`
Component library: [nettoolskit-ui-vue](https://github.com/ThiagoGuislotti/nettoolskit-ui-vue)