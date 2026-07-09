You are optimizing `Image.split` in this repository checkout.

Edit files under `project/`. The unchanged baseline is in `baseline/` for reference.

## Success criteria

Your patch is scored by the GSO harness against **baseline** and a hidden **expert** reference. You may not reach expert speed — the goal is to get as close as possible while staying correct.

After each attempt, check repo-root `artemis_results.json`:

| Goal | Field | Target |
|------|-------|--------|
| Correct | `correctness_passed` | `1` |
| Faster than baseline | `opt_base_passed` | `1` (≥1.2× GM speedup vs baseline) |
| Near expert | `opt_commit_passed` or `vs_expert_parity_percent` | `1` or ≥95 |

Use harness timings (`runtime_s_*`, `vs_baseline_speedup`) — not ad-hoc `time.time()`.

## Workflow

1. Read the benchmark and locate the hot path in `project/`.
2. Make a focused change; preserve observable behavior.
3. Run `./compile` → `./test` → `./benchmark`.
4. Read `artemis_results.json`; iterate until gains plateau.

## Issue

```text
Merge branch 'master' into jpeg-loading-without-convertion

The upstream merge commit is not descriptive. Focus: speed up `Image.split()` for multi-band images.
```

## Objective

Speed up `Image.split()` which separates a multi-channel image into individual single-channel images.

## Scope

Start on the hot path in these files (change others only if strictly necessary):

- `PIL/FliImagePlugin.py`
- `PIL/Image.py`
- `PIL/ImageEnhance.py`
- `PIL/ImageFont.py`
- `PIL/JpegImagePlugin.py`
- `PIL/PyAccess.py`
- `PIL/SgiImagePlugin.py`
- `setup.py`

Primary hot path: `PIL/Image.py` (`split`). Supporting C changes may be required for a large speedup.

## Performance benchmark

GSO scores this task with the harness below (`timeit` microbenchmarks with warm-up inside Docker).

```python
import io, json, timeit, random, requests
from PIL import Image
import numpy as np

def setup():
    images = {}
    # RGB, RGBA, LA, P, 1-bit images of various sizes
    arr_rgb = np.random.RandomState(12345).randint(0, 256, (768, 1024, 3), dtype=np.uint8)
    images['random_RGB']  = Image.fromarray(arr_rgb, 'RGB')
    images['random_RGBA'] = Image.fromarray(
        np.dstack([arr_rgb, np.random.randint(0,256,(768,1024),dtype=np.uint8)]), 'RGBA')
    # ... (multiple image types)
    return images

def experiment(images):
    results = {}
    for label, img in images.items():
        channels = img.split()
        results[label] = {
            'num_channels': len(channels),
            'modes': [ch.mode for ch in channels],
            'sizes': [ch.size for ch in channels],
        }
    return results
```

## Hints

`Image.split()` in `PIL/Image.py` — look at how it handles images that are already loaded vs lazily loaded, and whether it forces unnecessary mode conversions or full pixel copies before extracting bands.

In `_imaging.c`, the C-level `ImagingGetBand` function extracts a single channel. Check whether the split path avoids redundant work when the image data is already in the correct format.

Baseline `Image.split()` calls `getband()` in a Python loop — one C round-trip **per channel**.

Large RGB/RGBA arrays (768×1024) dominate the benchmark; batching band extraction in native code is the likely lever.

A Python-only tweak may help marginally; a large win likely needs the C extension (`_imaging.c` / `libImaging/`) on the split path.

## Anti-patterns

- Optimizing import-time or cold paths the benchmark never executes.
- Micro-opts that do not change the hot loop shown above.
- Skipping `./test` — a fast but broken patch scores zero.
- Reading or copying from `expert/` — that is the scoring reference, not input.

## Constraints

- **Drop-in replacement:** keep the public API under test unchanged (signatures, return types, errors, observable behavior).
- Do not rename public symbols or change import paths callers rely on.
- Do not add new required dependencies.
- **Correctness:** Each channel returned by `split()` must have the correct mode, size, and pixel values for all supported image modes (RGB, RGBA, LA, P, L, 1, etc.).
