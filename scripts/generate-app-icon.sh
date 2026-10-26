#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname -- "$script_dir")
icon_source="$repo_dir/Assets/AppIcon.icon"
catalog_dir="$repo_dir/Assets/Assets.xcassets/AppIcon.appiconset"
developer_dir=${DEVELOPER_DIR:-$(xcode-select -p)}
ictool="$developer_dir/../Applications/Icon Composer.app/Contents/Executables/ictool"

if [ ! -f "$icon_source/icon.json" ]; then
    echo "Missing Icon Composer source: $icon_source" >&2
    exit 2
fi
if [ ! -x "$ictool" ]; then
    echo "Icon generation requires Icon Composer from the selected Xcode 27 installation." >&2
    exit 2
fi

stage_dir=$(mktemp -d)
cleanup() { rm -rf "$stage_dir"; }
trap cleanup EXIT HUP INT TERM

"$ictool" "$icon_source" --export-image \
    --output-file "$stage_dir/rendered.png" --platform macOS --rendition Default \
    --width 1024 --height 1024 --scale 1 --design-generation 27

# Icon Composer exports an edge-to-edge tile. Legacy macOS asset catalogs need
# the transparent canvas inset that the native icon pipeline adds at build time.
source_path="$stage_dir/PaddrIcon.png"
xcrun swift - "$stage_dir/rendered.png" "$source_path" <<'SWIFT'
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3,
      let source = NSImage(contentsOfFile: arguments[1]),
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024,
          pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
          isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to prepare the fallback icon canvas")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill(using: .copy)
source.draw(in: NSRect(x: 100, y: 100, width: 824, height: 824),
            from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode the fallback icon")
}
try png.write(to: URL(fileURLWithPath: arguments[2]))
SWIFT

render() {
    size=$1
    filename=$2
    sips -z "$size" "$size" "$source_path" --out "$stage_dir/$filename" >/dev/null
    actual_width=$(sips -g pixelWidth "$stage_dir/$filename" | awk '/pixelWidth:/ { print $2 }')
    actual_height=$(sips -g pixelHeight "$stage_dir/$filename" | awk '/pixelHeight:/ { print $2 }')
    if [ "$actual_width" != "$size" ] || [ "$actual_height" != "$size" ]; then
        echo "Generated unexpected dimensions for $filename." >&2
        exit 1
    fi
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

for generated in "$stage_dir"/icon_*.png; do
    mv "$generated" "$catalog_dir/$(basename "$generated")"
done

mv "$source_path" "$repo_dir/Assets/PaddrIcon.png"

echo "Regenerated Paddr fallback PNG and AppIcon renditions from Assets/AppIcon.icon."
