<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a hardware-based Tic Tac Toe game in Verilog. The player selects one of the nine board positions using the four square select inputs, then pulses the submit input to place the current player’s mark. The game alternates automatically between X and O after each valid move.

Internally, the board is stored using two 9-bit registers: one register tracks the X positions, and the other tracks the O positions. After every move, the circuit checks all possible win conditions, including rows, columns, and diagonals. If X wins, O wins, or the board fills with no winner, the game enters a finished state and prevents additional moves until reset.

The design also generates video timing using the included hvsync_generator.v module. The video output draws the Tic Tac Toe grid, the X and O marks, the currently selected square, and a colored status border. The output pins provide hsync, vsync, and RGB color signals.

## How to test

Set ui[3:0] to select a board square from 0 to 8.

The board positions are:

0 | 1 | 2
3 | 4 | 5
6 | 7 | 8

After selecting a square, pulse ui[4] high to submit the move. The first valid move places an X, the next valid move places an O, and the game continues alternating turns.

Use ui[5] to reset the game. The reset clears the board, clears the win/draw status, and sets the next move back to X.

The output pins can be checked as follows:
uo[0] = hsync
uo[1] = vsync
uo[2] = red
uo[3] = green
uo[4] = blue
uo[5] = X win indicator
uo[6] = O win indicator
uo[7] = draw indicator

The bidirectional pins are used as debug/status outputs:
uio[0] = current turn
uio[1] = game over
uio[2] = valid square selected
uio[3] = selected square is empty
uio[4] = synchronized submit signal
uio[5] = X win debug
uio[6] = O win debug
uio[7] = draw debug

## External hardware

This project can be tested with switches or buttons for the inputs and LEDs or a logic analyzer for the status outputs.

For the video output, external display hardware is needed to view the generated Tic Tac Toe board. The design provides simple RGB, HSYNC, and VSYNC-style video signals, so it may require a compatible VGA-style test setup, resistor DACs for color lines, or a Tiny Tapeout demo board/video adapter depending on the test environment.
