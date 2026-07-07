# Task: Optimise `GifImageFile.n_frames`

## Objective

Speed up `n_frames` and `is_animated` on GIF images by avoiding unnecessary image-update work during frame counting.

## Repository

`python-pillow/Pillow` — base commit `f854676` (see `metadata.json`)

## File to optimise

- `src/PIL/GifImagePlugin.py`

## Performance benchmark

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

## What to look at

`n_frames` counts frames by repeatedly calling `self.seek(self.tell() + 1)` until `EOFError`. `is_animated` calls `self.seek(1)` to check for a second frame.

Each `seek` call triggers `_seek`, which loads and fully updates the image pixel data for the new frame — palette conversion, disposal compositing, and so on. When only counting frames, none of that pixel work is needed.

Look at `_seek` and consider how to skip image update work when the caller only needs to know that a frame exists.

## Correctness constraint

After calling `n_frames` or `is_animated`, subsequent `seek` + `load` calls must still produce correct pixel data for each frame.
