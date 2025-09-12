---
applyTo: "**/*.{html,css,scss,js,ts,jsx,tsx}"
---
Architecture: hooks/composables for reactive logic; presentational components using props and slots; services for pure HTTP requests.
Example: const { rows } = useTablePaging(apiEndpoint); <UserCard :user="u" v-slot:actions><button>Edit</button></UserCard>

Naming: prefix composables with use*; never use default exports; avoid side effects on import.
Example: export function useAuth() { … } // not export default; import modules without executing code automatically

HTTP: implement interceptors for token and correlationId; timeout; retry with backoff; cancel with AbortController; standard error object {code,message,details?,correlationId}.
Example: request interceptor adds Authorization: Bearer <token> and x-correlation-id; response retries on 502/503/504 with exponential backoff; timeout set to 10s

Performance: apply code-splitting by route or feature; debounce or throttle events; optimize images and fonts; maintain Lighthouse score >= 90.
Example: const onSearch = useDebouncedSearch(query => api.get('/users', { params: { q: query } }), 300)

Forms: validate fields individually; show loading, error and success states clearly.
Example: <input aria-describedby="email-error"> <span id="email-error">Invalid email format</span>; show spinner while submitting

Security: enforce strict CSP; enable HSTS; configure cookies SameSite and Secure at gateway or reverse proxy.
Example: Content-Security-Policy: default-src 'self'; Strict-Transport-Security: max-age=31536000; Set-Cookie: session=...; Secure; SameSite=Strict

Production: remove console.* and debugger; limit bundle size per route.
Example: // eslint rule "no-console" and build analyzer to ensure < 200KB per route
Example useApi/interceptors: request adds Authorization: Bearer <token> and x-correlation-id; response applies exponential backoff retry on 502/503/504; cancel via AbortController; timeout 10s