# Task: Optimise `ImagingGetBBox` (Image.getbbox)

## Objective

Speed up `Image.getbbox()` on large images by improving the bounding-box scan algorithm in C.

## Repository

`python-pillow/Pillow` — base commit `63f398b` (see `metadata.json`)

## File to optimise

- `src/libImaging/GetBBox.c`

## Performance benchmark

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

Note that `worst_img` (all-black) is the worst case for the current algorithm — it scans every pixel before returning `None`.

## What to look at

`src/libImaging/GetBBox.c` — the `GETBBOX` macro scans all pixels row by row, updating left/right bounds for every row. Think about whether the top, bottom, left, and right edges can be found with fewer total pixel comparisons by scanning each edge independently and stopping early.

## Correctness constraint

`getbbox()` must return identical `(x0, y0, x1, y1)` tuples (or `None`) for all image types and contents as the original implementation.
