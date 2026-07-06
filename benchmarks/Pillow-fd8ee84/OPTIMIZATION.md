# Expert optimization: `TiffImageFile.is_animated`

**API:** `TiffImageFile.is_animated` (same pattern in `GifImagePlugin.is_animated`)  
**Files:** `PIL/TiffImagePlugin.py`, `PIL/GifImagePlugin.py`

## Summary

Answers “is this multi-frame?” without a seek probe when the frame count is already
known. The baseline always saves position, tries `seek(1)`, and restores — even when
`_n_frames` was populated earlier.

## Changes

In the `is_animated` property (apply the same structure in both TIFF and GIF plugins):

1. **Check cached frame count first**
   ```python
   if self._n_frames is not None:
       self._is_animated = self._n_frames != 1
   ```

2. **Fall back to seek probe only when unknown** — Keep the existing logic inside
   `else:`:
   ```python
   else:
       current = self.tell()
       try:
           self.seek(1)
           self._is_animated = True
       except EOFError:
           self._is_animated = False
       self.seek(current)
   ```

3. **Do not seek when `_n_frames` is set** — The `tell()` / `seek(1)` / `seek(current)`
   dance runs only in the `else` branch.

## Why it's faster

When `_n_frames` is already known (e.g. from metadata or a prior `n_frames` read),
`is_animated` becomes a single integer comparison. The baseline always performs at least
one extra `seek(1)` round-trip, which parses and may decode the next frame.
