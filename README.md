AFPE-RBX
========


About
----------
Another Fucking Pseudo Emulator is a project for a Roblox game. I originally thought of this like by this point a year ago and it's been drained
by le laziness for that long. If I was dedicated I would've had this done by a couple of weeks. But at the same time school exists so eh. But seriously
I need help my laziness as taken me for too long. The project is written in Lua.

This is an 16-bit pseudo emulator based on the DEC PDP-8 minicomputer and partially the MOS Technology 6502. It features a single Accumulator. It can access `$FFFF` addresses with a byte value in each one. All computation such as addition, storing, or any other operation to numbers accounts for a twos-complement for the number forcefully. I/O is done through a makeshift port-mapped I/O which takes in an operation and the user designates a port to output the either a 16-bit wide value from the AC register to via specifying a number between 0 and 255.

## Programming Aspects
The program exists as a module and an OOP system for the CPU. A cpu object is created by calling the `new` function from the loaded module which is assigned to a variable. Functions exist to write data to the memory of the object and to start the program. The afpe module then includes some useful functions such as converting bool tables to numbers

Notes
-----------
* Note that this is written in Roblox's dialect of Lua, *Luau*. So function calls and library calls will not be the same, along with syntax such as static
  types, assignment operators, and more.
* If you're looking into this code, I'm sorry, things happen when you stretch a week project into like 8-9 months out of laziness and forget key parts of the code.
* I think I'm losing my mind, I need something to do and something that I'm good at, I feel like I'm not good at anything I do.
