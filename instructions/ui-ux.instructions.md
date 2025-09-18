---
applyTo: "**/*.{html,css,scss,js,ts,jsx,tsx,vue}"
---

Design system:
- Base typography 14–16px
- Line-height 1.4–1.6
- Use clamp() for fluid sizing
- Avoid very thin fonts
- Spacing base 8px (4px for dense)
- Consistent tokens
```css
body {
  font-size: clamp(14px, 1.5vw, 16px);
  line-height: 1.5;
  margin: 0;
}
```

Colors:
- WCAG AA contrast >= 4.5:1 (normal text) and >= 3:1 (headings >= 18px or semibold)
- Never rely on color alone for states
- Include icon/text
- Validate light and dark mode
```css
/* error button in red with “!” icon and text “Save failed” */
```

Accessibility:
- Semantic landmarks
- Skip-to-content link
- DOM order reflects visual order
- Predictable focus order
- Focus never hidden
- Modal must trap focus and restore on close
- Aria-* and labels required
```html
<header><nav><main>…</main></nav></header>
// Skip link visible on tab focus
```

Responsiveness:
- Mobile-first
- Minimum touch target 44x44
- Gap >= 8px between targets
- Adjustable density
- Layouts responsive via stack/scroll/cards
```css
.btn {
  min-width: 44px;
  min-height: 44px;
  margin-right: 8px;
}
```

Content:
- Actionable messages (“Correct the CPF” instead of “Invalid CPF”)
- Avoid jargon
- Consistent terminology
- Placeholders never replace labels
- Dates/numbers localized
- Abbreviations with title/tooltip
```html
<label>Date of Birth</label>
<!-- Placeholder “dd/mm/yyyy” + aria-describedby with format hint -->
```

Forms:
- Per-field error with correction
- Aria-describedby for error message
- Required visible
- Optional fields labeled
- Masks only as helper
- Progressive validation without silent blocking
```html
<input aria-describedby="cpf-error">
<span id="cpf-error">Correct the CPF</span>
// Required fields marked with *
```

Media:
- Meaningful alt (alt="" for decorative)
- Use srcset/sizes
- Preserve aspect ratio
- Captions for complex charts
- No autoplay with sound
```html
<img src="photo.jpg" srcset="photo@2x.jpg 2x" alt="Portrait of a smiling person">
```

Motion:
- Respect prefers-reduced-motion
- Animation durations 150–300ms
- Perceptible skeleton loading (no aggressive shimmer)
- Critical toasts not auto-dismissing
- Aria-live for async feedback
```css
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; }
}
```

Tables:
- Clear headers
- Responsive via stack/scroll/cards
- No truncation without indicator
- Sorting and filters accessible
- Empty states must guide action
```html
<th scope="col">Name</th>
// Empty-state “No records found — click + to add”
```

Privacy:
- Mask sensitive data by default
- Never show full identifiers (e.g., CPF)
```html
<!-- CPF displayed as ***.456.***-00 -->
```

Metrics:
- Measure task time
- Success rate
- Errors per step
- CLS/LCP metrics
- Log correlationId for relevant events
```javascript
// log correlationId on “checkout_started” click event
```