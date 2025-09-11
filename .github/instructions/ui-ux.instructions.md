---
applyTo: "**/*.{html,css,scss,js,ts,jsx,tsx,vue}"
---
Design system: base typography 14–16px; line-height 1.4–1.6; use clamp() for fluid sizing; avoid very thin fonts; spacing base 8px (4px for dense); consistent tokens.
Example: body { font-size: clamp(14px, 1.5vw, 16px); line-height: 1.5; margin: 0; }

Colors: WCAG AA contrast >= 4.5:1 (normal text) and >= 3:1 (headings >= 18px or semibold); never rely on color alone for states; include icon/text; validate light and dark mode.
Example: error button in red with “!” icon and text “Save failed”

Accessibility: semantic landmarks; skip-to-content link; DOM order reflects visual order; predictable focus order; focus never hidden; modal must trap focus and restore on close; aria-* and labels required.
Example: <header><nav><main>…</main></nav></header>; skip link visible on tab focus

Responsiveness: mobile-first; minimum touch target 44x44; gap >= 8px between targets; adjustable density; layouts responsive via stack/scroll/cards.
Example: .btn { min-width: 44px; min-height: 44px; margin-right: 8px; }

Content: actionable messages (“Correct the CPF” instead of “Invalid CPF”); avoid jargon; consistent terminology; placeholders never replace labels; dates/numbers localized; abbreviations with title/tooltip.
Example: <label>Date of Birth</label> + placeholder “dd/mm/yyyy” + aria-describedby with format hint

Forms: per-field error with correction; aria-describedby for error message; required visible; optional fields labeled; masks only as helper; progressive validation without silent blocking.
Example: <input aria-describedby="cpf-error"> <span id="cpf-error">Correct the CPF</span>; required fields marked with *

Media: meaningful alt (alt="" for decorative); use srcset/sizes; preserve aspect ratio; captions for complex charts; no autoplay with sound.
Example: <img src="photo.jpg" srcset="photo@2x.jpg 2x" alt="Portrait of a smiling person">

Motion: respect prefers-reduced-motion; animation durations 150–300ms; perceptible skeleton loading (no aggressive shimmer); critical toasts not auto-dismissing; aria-live for async feedback.
Example: @media (prefers-reduced-motion: reduce) { * { animation: none !important; } }

Tables: clear headers; responsive via stack/scroll/cards; no truncation without indicator; sorting and filters accessible; empty states must guide action.
Example: <th scope="col">Name</th>; empty-state “No records found — click + to add”

Privacy: mask sensitive data by default; never show full identifiers (e.g., CPF).
Example: CPF displayed as ***.456.***-00

Metrics: measure task time; success rate; errors per step; CLS/LCP metrics; log correlationId for relevant events.
Example: log correlationId on “checkout_started” click event