#include "raymob.h" // This header can replace 'raylib.h' and includes additional functions related to Android.

extern void BeefStart();
extern void BeefStop();

extern void Minesweeper_Android_Main();

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
int main(void)
{
    BeefStart();

    Minesweeper_Android_Main();

    BeefStop();

    return 0;
}