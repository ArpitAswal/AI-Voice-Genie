# Platform Extension: React & TypeScript Ecosystem

> **Activation**: Apply when working with `package.json` (containing React), `*.tsx`, or `*.ts` web files.

## 1. TypeScript Rigour
- Enforce strict typing. Do not use `any`; use `unknown` combined with type narrowing or runtime schema validators (`zod`) at API boundaries.
- Model multi-variant UI states using discriminated unions rather than multiple optional fields.

## 2. Component Design & State Management
- **Derive, Don't Duplicate**: Compute values on the fly during render from existing props or state rather than synchronizing them with `useEffect`.
- **Separate Server and UI State**: Manage asynchronous server cache with TanStack Query / SWR / framework loaders, and keep local UI state (modals, dropdowns) in `useState` or lightweight client stores.
- **Keys in Lists**: Always use unique, stable entity IDs as `key` props. Never use array indices if items can reorder, insert, or delete.

## 3. Hook Hygiene & Cleanup
- Every `useEffect` that attaches event listeners, creates timers, or opens WebSockets must return a clean-up function.
- Attach an `AbortController` signal to in-flight `fetch` calls to cancel pending requests when dependencies change or components unmount.

## 4. Verification Commands
- Typecheck: `npx tsc --noEmit`
- Lint: `npm run lint`
- Test: `npm test -- --run` (or `npx vitest run`)