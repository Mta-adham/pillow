# Task: Optimise `Image.split`

## Objective

Speed up `Image.split()` which separates a multi-channel image into individual single-channel images.

## Repository

`python-pillow/Pillow` — base commit `d8af3fc` (see `metadata.json`)

## Files to optimise

Primary: `PIL/Image.py` and `_imaging.c` (the C extension)

## Performance benchmark

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

## What to look at

`Image.split()` in `PIL/Image.py` — look at how it handles images that are already loaded vs lazily loaded, and whether it forces unnecessary mode conversions or full pixel copies before extracting bands.

In `_imaging.c`, the C-level `ImagingGetBand` function extracts a single channel. Check whether the split path avoids redundant work when the image data is already in the correct format.

## Correctness constraint

Each channel returned by `split()` must have the correct mode, size, and pixel values for all supported image modes (RGB, RGBA, LA, P, L, 1, etc.).
