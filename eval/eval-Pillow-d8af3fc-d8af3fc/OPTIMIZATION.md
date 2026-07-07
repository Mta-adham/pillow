# Expert optimization: `Image.split`

**API:** `Image.split`  
**Files:** `PIL/Image.py`, `_imaging.c`, `libImaging/Bands.c` (+ related C glue)

## Task intent

GSO problem statement / commit message:

```text
Merge branch 'master' into jpeg-loading-without-convertion
```

The upstream merge commit message is not descriptive. **GSO benchmark focus:** speed up `Image.split` for multi-band images by splitting all bands in one native call instead of per-band `getband()` loops.

## Constraints

This is a **drop-in replacement** task:

- Keep the public API under test (`Image.split`) unchanged: same signatures, return types, and observable behavior for all valid inputs.
- Do not rename public functions, classes, or modules; do not change import paths callers rely on.
- Do not add new required dependencies.
- Limit edits to the file(s) listed above unless a minimal supporting change is strictly necessary for correctness or performance of the target API.

## Summary

Splits multi-band images in one native call instead of N separate `getband()` round-trips
from Python. The expert adds a vectorized `ImagingSplit` in C and routes `Image.split()`
through `self.im.split()`.

## Changes

### 1. Python — `Image.split()` (`PIL/Image.py`)

Replace the per-band Python loop:

```python
ims = []
for i in range(self.im.bands):
    ims.append(self._new(self.im.getband(i)))
return tuple(ims)
```

with a single C call:

```python
ims = map(self._new, self.im.split())
return tuple(ims)
```

Also add `getchannel(channel)` (index or band name → `self.im.getband(channel)`) for
single-band access; update the docstring to mention it.

### 2. C API — `ImagingSplit` (`libImaging/Bands.c`)

Add `ImagingSplit(Imaging imIn, Imaging bands[4])` that:

- Returns a copy for single-band images.
- Allocates all output band images up front.
- Extracts 2/3/4-band UINT8 data with a **4-pixel unrolled loop** using `MAKE_UINT32`
  (endian-aware) to write four output bytes per store instead of one-at-a-time.

Also speed up `ImagingGetBand`:

- Use `ImagingNewDirty` instead of `ImagingNew`.
- Apply the same 4-pixel `MAKE_UINT32` unroll in the extraction loop.

### 3. Python binding — `_imaging.c`

Expose the new primitive on the `Imaging` object:

- Add `_split` → `"split"` method that calls `ImagingSplit` and returns a list of
  `Imaging` wrappers.
- Add module-level `_merge` → `"merge"` (used by `Image.merge()`).

### 4. Python — `Image.merge()` (`PIL/Image.py`)

Replace the `putband` loop:

```python
im = core.new(mode, bands[0].size)
for i in range(getmodebands(mode)):
    bands[i].load()
    im.putband(bands[i].im, i)
```

with:

```python
for band in bands:
    band.load()
return bands[0]._new(core.merge(mode, *[b.im for b in bands]))
```

### 5. Supporting files in this commit

The expert commit also updates `libImaging/Convert.c`, `Resample.c`, `Storage.c`,
`Unpack.c`, and `_imaging.c` resize bindings to thread a `box` argument through
`Image.resize()`. Those are **not required for `Image.split` perf** but are part of the
same upstream commit copied into `expert/`.

## Why it's faster

The baseline crosses the Python/C boundary once per band (`getband` in a loop), and each
`ImagingGetBand` copies pixels one byte at a time. The expert splits all bands in one C
call with 4-wide stores, cutting Python overhead and memory traffic — which is what the
GSO `Image.split` benchmarks exercise.
