# Image Converter Ultra

macOS (13+) drag & drop image optimizer in Swift, in the spirit of ImageOptim.

Drop files or whole folders onto the window (or the Dock icon). Each image is recompressed,
the compressed file replaces the original, and the original goes to the Trash.
Resolution is never changed.

| Format | Encoder | Default quality |
|--------|---------|-----------------|
| JPEG   | JPEGli (`cjpegli`) | 90 |
| PNG    | `pngquant` | 80 |
| GIF    | `gifsicle --lossy` | 80 |

* Metadata (EXIF, XMP, ICC, IPTC; PNG text/eXIf/iCCP chunks) is copied from the original.
* If the result is not smaller, the original is left untouched.
* Sliders in the window change the qualities (saved between launches).

## Build

```bash
brew install jpeg-xl pngquant gifsicle dylibbundler
./scripts/build_app.sh
open "build/Image Converter Ultra.app"
```
The script bundles the encoders into the app. For development, `swift run` also works
(encoders are then taken from Homebrew).
