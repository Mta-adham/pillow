# Task: Optimise `TiffImageFile.is_animated` (and `GifImageFile.is_animated`)

## Objective

Improve the runtime of the `is_animated` property on PIL TIFF and GIF image objects without changing observable behaviour.

## Repository

`python-pillow/Pillow` — base commit `fd8ee8437bfb07449fb12e75f7dcb353ca0358bf^`

## Files to optimise

- `PIL/TiffImagePlugin.py`
- `PIL/GifImagePlugin.py`

Both files contain an `is_animated` property with the same structure. Apply the fix to both.

## Performance benchmark

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

## What to look at

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

## Correctness constraint

`is_animated` must return the correct value regardless of whether `n_frames` was called first or not.
