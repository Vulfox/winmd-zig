# winmd-zig
[![CI](https://github.com/Vulfox/winmd-zig/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/Vulfox/winmd-zig/actions/workflows/test.yml)

The goal of this library is to provide a way for a pure zig automation of reading/generating windows api projections in the same way that [windows-rs](https://github.com/microsoft/windows-rs) provides them today.

Starting off, the winmd file ingestion process needs to be done, which this library should cover. In time, this may graduate to just being called `windows-zig` and integrate the winmd reader as part of the build time generation of windows bindings for zig projects.

I don't forsee the potential `windows-zig` being integrated within the zig std libs, but I do see it being used for repos that needs/want full access to the Win32 and WinRT bindings that don't exist in the zig std libs.

## Disclaimer
I am a zig newb and this port of the windows-rs was to help get a better feel for both (rust and zig) languages and the zig ecosystem. I am 99% sure any rust->zig code I am porting could be improved upon. Any tips are greatly appreciated!

## Other Notable Repos
- https://github.com/marlersoft/zigwin32gen
  - This repo is doing something similar to what this repo is attempting to accomplish longterm. It is much further along in the development process and will most likely be user ready before this one.
  - Differences: zigwin32gen repo currently appears to provide only Win32 bindings, where as as this repo is attempting to provide both Win32 and WinRT bindings.
- https://github.com/microsoft/winmd
- https://github.com/microsoft/win32metadata
- https://github.com/microsoft/windows-rs
