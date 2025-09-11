---
applyTo: "**/*.{cs,ts,js,go,rs,java,py}"
---
Clean Architecture principles: domain-driven design with domain at the center; application layer coordinates use cases; infrastructure isolated from domain; presentation depends only on application; strict dependency inversion; business rules in domain without external dependencies.
Layer separation: Domain (entities, value objects, domain services, interfaces); Application (use cases, application services, DTOs, ports); Infrastructure (repositories, external services, frameworks); Presentation (controllers, views, CLI, APIs); cross-cutting concerns separated.
SOLID principles: strict Single Responsibility; Open/Closed via abstractions; Liskov Substitution respected; Interface Segregation with focused contracts; Dependency Inversion with stable abstractions.
Domain modeling: entities with identity; immutable value objects; aggregates as consistency boundaries; domain events for communication; consistent ubiquitous language; business rules encapsulated.
Use case design: application services coordinate; command/query separation; input/output DTOs; validation in application layer; authorization separated from business logic; clear transactional boundaries.
Dependency management: abstractions in domain; implementations in infrastructure; dependency injection container; externalized configuration; environment‑specific settings; feature toggles when appropriate.
Testing strategy: isolated unit tests for domain; integration tests for infrastructure; acceptance tests for use cases; test doubles for dependencies; consistent AAA pattern; deterministic tests.
Error handling: domain exceptions for business rules; application exceptions for coordination; wrap infrastructure exceptions; consistent error codes; structured logging; correlation IDs for tracing.
Data flow: commands modify state; queries return read models; events communicate changes; saga for distributed transactions; eventual consistency acceptable; idempotency ensured.
Code organization: feature‑based folders when appropriate; shared kernel for common concepts; well‑defined bounded contexts; anti‑corruption layers for external systems; hexagonal architecture principles.
Performance: lazy loading when appropriate; caching in infrastructure; bulk operations; async/await for I/O; mindful memory usage; regular profiling.
Security: separate authentication from authorization; encryption in infrastructure; input sanitization; output encoding; audit logging; least privilege.