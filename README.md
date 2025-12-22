# Minesweeper+
A minesweeper clone with levels.
Play and download at https://starpelly.itch.io/minesweeper
Also available on Newgrounds, won 3rd best game of the month September 2025~! https://www.newgrounds.com/portal/view/998531

Special thanks to **Darkener** for playtesting!

## How to compile

### Desktop
Just open the project in the Beef IDE, set the startup project to `Minesweeper.Desktop` and press `F5`, it should just work.

### Newgrounds
The Newgrounds build will only work under `wasm32` and if an API app ID is written in a plain txt file under `code/Minesweeper.Newgrounds/AppID.txt`.

## Licenses
Source code is released under the GPLv3 license.
It isn't fantastic, there are a lot of repeated systems everywhere, but I really just wanted to finish it.

Assets are compiled into the executable using Beef's `Compiler.ReadBinary` function.

## Dependencies
* [raylib-beef](https://github.com/starpelly/raylib-beef)
* [BJSON](https://github.com/M0n7y5/BJSON)
