# Minesweeper+ Android Implementation

As Minesweeper+ is written in BeefLang, which has very limited "support" for Android, I decided to take some liberties with this implmentation.

Limitations:
* libffi is disabled
* BeefRT and raylib is listed as a submodule so we can link it through CMake, we do not use pre-compiled binaries.

I'm using [raymob](https://github.com/Bigfoot71/raymob) to simply the raylib implementation for Android.

**MAKE SURE YOU CLONED WITH THE `--recursive` TAG SO `BeefRT` WAS CLONED!**

## Compiling
1. Download and install [Android Studio](https://developer.android.com/studio)
2. Open the `android` directory in Android Studio
3. Run the `buildbeef.cmd` script, this will compile the `MinesweeperAndroid` project to compatible Android binaries.
4. Run the game using the simulator *or real hardware* of your choice in Android Studio.