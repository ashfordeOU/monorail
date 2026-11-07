#!/usr/bin/env bash
# Builds Monorail for GNOME (beta): the shared core turned into JavaScript, the extension and its
# compiled settings schema, zipped as dist/monorail@ashforde.org.shell-extension.zip, ready for
# `gnome-extensions install`.
# Needs Node 22.13 or later (its built-in TypeScript type stripping), glib-compile-schemas and zip.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
uuid="monorail@ashforde.org"
build="$here/build/$uuid"
dist="$here/dist"

rm -rf "$build"
mkdir -p "$build/schemas" "$dist"
cp "$here/extension/"*.js "$build/"
cp "$here/extension/schemas/"*.gschema.xml "$build/schemas/"
glib-compile-schemas --strict "$build/schemas"

# The version shown in the Extensions app follows the other platforms' (one version for all).
version="$(tr -d '[:space:]' < "$root/VERSION")"
sed "s/@VERSION@/$version/" "$here/extension/metadata.json" > "$build/metadata.json"

node --no-warnings "$here/tools/core-to-js.mjs" "$build/core"

zip_path="$dist/$uuid.shell-extension.zip"
rm -f "$zip_path"
(cd "$build" && zip -qr "$zip_path" .)
echo "Built $zip_path"
unzip -l "$zip_path"
