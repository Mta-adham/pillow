You are optimizing `GifImageFile.n_frames` in this repository checkout.

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
Do not update images during n_frames or is_animated seeking
```

## Objective

Speed up `n_frames` and `is_animated` on GIF images by avoiding unnecessary image-update work during frame counting.

## Scope

Start on the hot path in these files (change others only if strictly necessary):

- `src/PIL/GifImagePlugin.py`

## Performance benchmark

GSO scores this task with the harness below (`timeit` microbenchmarks with warm-up inside Docker).

```python
import os, json, timeit, requests
from PIL import Image

TEST_GIF_FILENAME = 'iss634.gif'
TEST_GIF_URL = 'https://github.com/python-pillow/Pillow/raw/main/Tests/images/iss634.gif'

def setup():
    if not os.path.exists(TEST_GIF_FILENAME):
        r = requests.get(TEST_GIF_URL, stream=True)
        r.raise_for_status()
        with open(TEST_GIF_FILENAME, 'wb') as f:
            for chunk in r.iter_content(8192):
                if chunk:
                    f.write(chunk)
    return TEST_GIF_FILENAME

def experiment():
    with Image.open(TEST_GIF_FILENAME) as img:
        n_frames = img.n_frames
        is_animated = img.is_animated
    return {'n_frames': n_frames, 'is_animated': is_animated}
```

The benchmark uses `iss634.gif`, a 42-frame animated GIF.

## Hints

`n_frames` counts frames by repeatedly calling `self.seek(self.tell() + 1)` until `EOFError`. `is_animated` calls `self.seek(1)` to check for a second frame.

Each `seek` call triggers `_seek`, which loads and fully updates the image pixel data for the new frame — palette conversion, disposal compositing, and so on. When only counting frames, none of that pixel work is needed.

Look at `_seek` and consider how to skip image update work when the caller only needs to know that a frame exists.

The issue title is the hint: do not **update images** during `n_frames` / `is_animated` seeking.

Frame counting only needs to parse GIF structure — not decode pixels, convert palettes, or composite disposal regions.

Add a lightweight code path through `_seek` when the caller only needs to know that another frame exists.

## Anti-patterns

- Optimizing import-time or cold paths the benchmark never executes.
- Micro-opts that do not change the hot loop shown above.
- Skipping `./test` — a fast but broken patch scores zero.
- Reading or copying from `expert/` — that is the scoring reference, not input.

## Constraints

- **Drop-in replacement:** keep the public API under test unchanged (signatures, return types, errors, observable behavior).
- Do not rename public symbols or change import paths callers rely on.
- Do not add new required dependencies.
- **Correctness:** After calling `n_frames` or `is_animated`, subsequent `seek` + `load` calls must still produce correct pixel data for each frame.
