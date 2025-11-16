---
applyTo: frontend/**/*.{vue,ts,js}
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

## Shared Components Example

```
shared/
├── src/
│   └── styles/
│       ├── design-system.scss  # CSS variables, design tokens, utility classes
│       ├── global.scss         # Global base styles, reset, typography
│       └── quasar-variables.scss # Quasar customization
├── presentation/
│   ├── components/
│   │   ├── ui/
│   │   │   ├── BaseButton.vue      # Generic button
│   │   │   ├── BaseCard.vue        # Generic card
│   │   │   ├── MetricCard.vue      # Reusable metric card
│   │   │   ├── InfoCard.vue        # Reusable info card
│   │   │   ├── ChartCard.vue       # Reusable chart card
│   │   └── SectionHeader.vue   # Section headers
│   └── form/
│       ├── BaseInput.vue       # Generic input
│       ├── BaseSelect.vue      # Generic select
│       ├── BaseTextarea.vue    # Generic textarea
│       ├── BaseDatePicker.vue  # Date picker
│       └── BaseTimePicker.vue  # Time picker
└── composables/
    ├── useNotification.ts      # Wrapper for NotificationService
    ├── useFormRules.ts         # Wrapper for FormValidationService
    ├── useFilters.ts           # Wrapper for FilterService
    └── useDebounce.ts          # Generic utilities
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
// shared/presentation/composables/useDebounce.ts
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