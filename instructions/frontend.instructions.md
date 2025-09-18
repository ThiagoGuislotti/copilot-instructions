---
applyTo: "**/*.{html,css,scss,js,ts,jsx,tsx}"
---

# Architecture
- Hooks/composables for reactive logic
- Presentational components using props and slots
- Services for pure HTTP requests
```javascript
const { rows } = useTablePaging(apiEndpoint);
<UserCard :user="u" v-slot:actions><button>Edit</button></UserCard>
```

# Naming
- Prefix composables with use*
- Never use default exports
- Avoid side effects on import
```javascript
export function useAuth() { /* ... */ } // not export default
// Import modules without executing code automatically
```

# HTTP
- Implement interceptors for token and correlationId
- Timeout
- Retry with backoff
- Cancel with AbortController
- Standard error object {code,message,details?,correlationId}
```javascript
// Request adds Authorization: Bearer <token> and x-correlation-id
// Response applies exponential backoff retry on 502/503/504
// Cancel via AbortController; timeout 10s
```

# Performance
- Apply code-splitting by route or feature
- Debounce or throttle events
- Optimize images and fonts
- Maintain Lighthouse score >= 90
```javascript
const onSearch = useDebouncedSearch(query => api.get('/users', { params: { q: query } }), 300)
```

# Forms
- Validate fields individually
- Show loading, error and success states clearly
```html
<input aria-describedby="email-error">
<span id="email-error">Invalid email format</span>
// Show spinner while submitting
```

# Security
- Enforce strict CSP
- Enable HSTS
- Configure cookies SameSite and Secure at gateway or reverse proxy
```http
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000
Set-Cookie: session=...; Secure; SameSite=Strict
```

# Production
- Remove console.* and debugger
- Limit bundle size per route
```javascript
// eslint rule "no-console" and build analyzer to ensure < 200KB per route
```