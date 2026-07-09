You are optimizing `ImagingGetBBox` in this repository checkout.

Edit files under `project/`. The unchanged baseline is in `baseline/` for reference.

## Workflow

1. Read the benchmark and locate the hot path in `project/`.
2. Make a focused change; preserve observable behavior.
3. Run `./compile` → `./test` → `./benchmark`.
4. Use the harness results to iterate until gains plateau.

## Issue

```text
Merge pull request #8194 from uploadcare/optimize-getbbox

Optimize getbbox() and getextrema() routines
```

## Objective

Speed up `Image.getbbox()` on large images by improving the bounding-box scan algorithm in C.

## Scope

Start on the hot path in these files (change others only if strictly necessary):

- `src/libImaging/GetBBox.c`

## Performance benchmark

GSO scores this task with the harness below (`timeit` microbenchmarks with warm-up inside Docker).

```python
import json, random, timeit
from PIL import Image
import numpy as np

def setup():
    w, h = 2048, 2048
    random.seed(42)
    np_edge = np.random.RandomState(202)
    np_noise = np.random.RandomState(101)

    worst_img  = Image.new('L', (w, h), 0)       # all black — no bbox
    full_img   = Image.new('L', (w, h), 255)      # all white — full bbox
    sparse_img = Image.new('L', (w, h), 0)        # a few scattered pixels
    for _ in range(50):
        sparse_img.putpixel((random.randint(0,w-1), random.randint(0,h-1)), random.randint(1,254))

    edge_arr = np.zeros((h, w), dtype=np.uint8)
    edge_arr[0,:]  = np_edge.randint(1,255,w)
    edge_arr[-1,:] = np_edge.randint(1,255,w)
    edge_arr[:,0]  = np_edge.randint(1,255,h)
    edge_arr[:,-1] = np_edge.randint(1,255,h)
    edge_img = Image.fromarray(edge_arr, 'L')

    noise_arr = np_noise.randint(0, 256, (h, w), dtype=np.uint8)
    noise_img = Image.fromarray(noise_arr, 'L')

    return {'worst': worst_img, 'full': full_img, 'sparse': sparse_img,
            'edge_random': edge_img, 'noise': noise_img}

def experiment(images):
    return {k: img.getbbox() for k, img in images.items()}
```

`worst_img` (all-black) is the worst case for the current algorithm — it scans every pixel before returning `None`.

## Hints

`src/libImaging/GetBBox.c` — the `GETBBOX` macro scans all pixels row by row, updating left/right bounds for every row. Think about whether the top, bottom, left, and right edges can be found with fewer total pixel comparisons by scanning each edge independently and stopping early.

The issue mentions both `getbbox()` and `getextrema()` — both live in the same C file and share similar scan patterns.

Try finding each bbox edge in separate passes with **early exit** once that edge is fixed, instead of scanning every pixel for all four bounds.

`worst` (all zeros) is the pathological case: an O(n²) full scan that returns `None` should become much cheaper.

## Anti-patterns

- Optimizing import-time or cold paths the benchmark never executes.
- Micro-opts that do not change the hot loop shown above.
- Skipping `./test` — a fast but broken patch scores zero.
- Reading or copying from `expert/` — that is the scoring reference, not input.

## Constraints

- **Drop-in replacement:** keep the public API under test unchanged (signatures, return types, errors, observable behavior).
- Do not rename public symbols or change import paths callers rely on.
- Do not add new required dependencies.
- **Correctness:** `getbbox()` must return identical `(x0, y0, x1, y1)` tuples (or `None`) for all image types and contents as the original implementation.
