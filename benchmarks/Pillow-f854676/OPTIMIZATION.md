# Expert optimization: `GifImageFile.n_frames`

**API:** `GifImageFile.n_frames`  
**File:** `src/PIL/GifImagePlugin.py`

## Summary

Counts GIF frames without decoding pixel data. The baseline calls `seek()`, which fully
loads and composites each frame; the expert adds a lightweight `_seek(..., update_image=False)`
path that only parses the GIF structure.

## Changes

1. **`_seek(self, frame, update_image=True)`** — Add an `update_image` flag (default
   `True` for normal seeks).

2. **Skip `load()` when counting** — Guard the expensive path:
   ```python
   if self.tile and update_image:
       self.load()
   ```

3. **Skip compositing when counting** — Wrap mode conversion, palette alpha handling,
   and disposal pasting in `if update_image:`.

4. **Use lightweight seek for frame counting** — In `n_frames` (and `is_animated` probe),
   replace `self.seek(n)` with `self._seek(n, False)`.

5. **Early EOF during structure parse** — After reading a frame header, if `interlace is None`,
   raise `EOFError` immediately. When `update_image` is `False`, **return** right after
   that check instead of building tiles / decoding pixels.

## Why it's faster

`n_frames` only needs to know how many frames exist. The baseline decodes every frame
into a raster (`load()`, RGB/RGBA conversion, disposal compositing) on each `seek()`.
The expert parses GIF blocks and stops before pixel decompression when
`update_image=False`.
