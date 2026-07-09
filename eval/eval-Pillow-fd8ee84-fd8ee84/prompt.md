You are optimizing `TiffImageFile.is_animated` in this repository checkout.

Edit files under `project/`. The unchanged baseline is in `baseline/` for reference.

## Workflow

1. Read the benchmark and locate the hot path in `project/`.
2. Make a focused change; preserve observable behavior.
3. Run `./compile` → `./test` → `./benchmark`.
4. Use the harness results to iterate until gains plateau.

## Issue

```text
Merge pull request #2315 from radarhere/is_animated

If n_frames is known, then use when determining is_animated
```

## Objective

Improve the runtime of the `is_animated` property on PIL TIFF and GIF image objects without changing observable behaviour.

## Scope

Start on the hot path in these files (change others only if strictly necessary):

- `PIL/GifImagePlugin.py`
- `PIL/TiffImagePlugin.py`

## Performance benchmark

GSO scores this task with the harness below (`timeit` microbenchmarks with warm-up inside Docker).

```python
import json, random, timeit
from PIL import Image

def setup():
    random.seed(12345)
    file_dict = {}
    for i in range(1, 4):
        frame_count = random.randint(1, 5)
        filename = f'tiff{i}.tiff'
        frames = [Image.new('RGB', (800, 800), (random.randint(0,255),)*3) for _ in range(frame_count)]
        if frame_count > 1:
            frames[0].save(filename, save_all=True, append_images=frames[1:])
        else:
            frames[0].save(filename)
        file_dict[f'tiff{i}'] = filename
    return file_dict

def experiment(data_paths):
    results = {}
    for key, filepath in data_paths.items():
        im_A = Image.open(filepath)
        animated_A = im_A.is_animated   # is_animated before n_frames
        n_frames_A = im_A.n_frames
        im_B = Image.open(filepath)
        n_frames_B = im_B.n_frames
        animated_B = im_B.is_animated   # is_animated after n_frames
        results[key] = {
            'order_A': {'is_animated': animated_A, 'n_frames': n_frames_A},
            'order_B': {'is_animated': animated_B, 'n_frames': n_frames_B},
        }
    return results
```

## Hints

Current `is_animated` in `PIL/TiffImagePlugin.py` (~line 964):

```python
@property
def is_animated(self):
    if self._is_animated is None:
        current = self.tell()
        try:
            self.seek(1)
            self._is_animated = True
        except EOFError:
            self._is_animated = False
        self.seek(current)
    return self._is_animated
```

The class also has a `_n_frames` cache populated by `n_frames`. The benchmark accesses both properties in both orderings — consider what redundant work happens when one is already cached.

The issue: when `_n_frames` is already known, derive `is_animated` from it instead of probing with `seek(1)`.

The benchmark opens each TIFF twice and calls `is_animated` both **before** and **after** `n_frames` — avoid redundant seeks when the frame count is cached.

Mirror the same fix in **both** `TiffImagePlugin.py` and `GifImagePlugin.py`.

## Anti-patterns

- Optimizing import-time or cold paths the benchmark never executes.
- Micro-opts that do not change the hot loop shown above.
- Skipping `./test` — a fast but broken patch scores zero.
- Reading or copying from `expert/` — that is the scoring reference, not input.

## Constraints

- **Drop-in replacement:** keep the public API under test unchanged (signatures, return types, errors, observable behavior).
- Do not rename public symbols or change import paths callers rely on.
- Do not add new required dependencies.
- **Correctness:** `is_animated` must return the correct value regardless of whether `n_frames` was called first or not.
