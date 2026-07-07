# Expert optimization: `ImagingGetBBox`

**API:** `ImagingGetBBox`  
**File:** `src/libImaging/GetBBox.c`

## Task intent

GSO problem statement / commit message:

```text
Merge pull request #8194 from uploadcare/optimize-getbbox

Optimize getbbox() and getextrema() routines
```

## Constraints

This is a **drop-in replacement** task:

- Keep the public API under test (`ImagingGetBBox`) unchanged: same signatures, return types, and observable behavior for all valid inputs.
- Do not rename public functions, classes, or modules; do not change import paths callers rely on.
- Do not add new required dependencies.
- Limit edits to the file(s) listed above unless a minimal supporting change is strictly necessary for correctness or performance of the target API.

## Summary

Finds the non-empty bounding box without scanning every pixel of the image. The baseline
walks the full width and height on every row; the expert uses a three-stage search with
early exits once top, bottom, and side boundaries are known.

## Changes

1. **Stage 1 — find top edge** — Scan rows from the top. On the first row that contains
   a masked pixel, record `(bbox[0], bbox[1])` and **break** (do not scan the rest of
   that row or lower rows yet).

2. **Early empty check** — If no top row was found (`bbox[1] < 0`), return `0` immediately
   (move this check here instead of after the full scan).

3. **Stage 2 — find bottom edge** — Scan rows from `im->ysize - 1` down to `bbox[1]`.
   On the first row with data, tighten `bbox[0]` if needed, set `bbox[3] = y + 1`, and
   **break**.

4. **Stage 3 — find left/right edges** — Only scan rows `bbox[1] .. bbox[3]`. For each
   row, scan left from `x = 0` to `bbox[0]` and right from `x = im->xsize - 1` down to
   `bbox[2]`, updating `bbox[0]` / `bbox[2]` and **breaking** as soon as a pixel is found.

5. **`GetExtrema` early exit** — In the per-row min/max loop, if `imin == 0` and
   `imax == 255`, **break** out of the row loop (full 0–255 range already reached).

## Why it's faster

The baseline's `GETBBOX` macro always iterates every `(x, y)` and updates all four
bounds on every hit. Sparse or small foreground regions still pay for a full-image pass.
The expert stops as soon as each boundary is fixed and restricts the final horizontal
pass to the known vertical band.
