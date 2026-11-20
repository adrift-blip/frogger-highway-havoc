# Frogger: Highway Havoc

A classic Frogger-style arcade game implemented in **8086 Assembly
Language** using **NASM**. The game runs as a DOS `.COM` program in
DOSBox and draws its interface directly to VGA text-mode video memory.

## Overview

Guide the frog from the bottom of the screen to one of the three home
slots at the top. Six traffic lanes stand between the starting area and
the home row. Vehicles move continuously in alternating directions, and
each lane has its own movement speed.

Reach an unoccupied home slot to earn points. Avoid the traffic and
complete each crossing before the timer expires. Filling all three home
slots advances the game to the next level, where traffic becomes faster.

## Features

-   **Six traffic lanes:** Three lanes below the median and three above
    it.
-   **Moving vehicles:** Cars, trucks, and motorcycles travel in
    alternating directions.
-   **Different lane speeds:** Each lane has an independent speed; lanes
    nearer the home area are configured to move faster.
-   **Keyboard controls:** Use the arrow keys to move the frog one row
    or column at a time.
-   **Collision detection:** Contact with a vehicle costs one life and
    returns the frog to the starting position.
-   **Crossing countdown:** Each attempt starts with 30 seconds. Running
    out of time costs a life.
-   **Scoring:** Filling an empty home slot awards 50 points, plus the
    remaining crossing time.
-   **Progressive difficulty:** Filling all three home slots clears them
    and increases the speed of every lane.
-   **Interrupt-driven updates:** A custom timer ISR updates vehicle
    positions and the crossing timer; a keyboard ISR handles movement
    and the ESC key.
-   **Exit confirmation:** Press ESC and choose Y to quit or N to
    resume.
-   **Game screens:** Includes an introduction screen, in-game HUD,
    game-over display, and final score.

## How to Play

1.  Start the game and press a key at the introduction screen.
2.  Use the **arrow keys** to guide the frog toward an available home
    slot.
3.  Avoid vehicles in all six lanes.
4.  Reach an empty home slot to score points and begin another crossing.
5.  Complete all three home slots to advance to a faster level.
6.  You begin with **3 lives**. A collision or an expired crossing timer
    costs one life.
7.  Press **ESC** to open the exit confirmation screen:
    -   **Y** --- confirm exit.
    -   **N** --- return to the game.

The game ends when all lives are lost or the player confirms that they
want to exit.

## Controls

  Key           Action
  ------------- ----------------------------------
  Up Arrow      Move up
  Down Arrow    Move down
  Left Arrow    Move left
  Right Arrow   Move right
  ESC           Pause and open exit confirmation
  Y             Confirm exit
  N             Resume the game

## How the Code Works

The source is organized into data declarations, reusable procedures,
interrupt service routines, and the main game flow.

### 1. Screen and video memory

The game uses 80×25 text mode. It writes character-and-attribute words
directly to video memory at segment `0xB800`. The screen is drawn by
filling regions for the starting area, roads, median, home area, and
scoreboard.

Procedures such as `drawGameScreen`, `drawhomeslots`, `drawvehicles`,
and `drawdashedlines` build the game layout. The frog and vehicles are
also drawn by writing directly to video memory.

### 2. Vehicle data and movement

Vehicle information is stored in parallel arrays:

-   `rows` --- screen row for each vehicle.
-   `cols` --- horizontal position.
-   `dirs` --- direction of movement.
-   `lens` --- vehicle length.
-   `attrs` --- display attribute.
-   `sprites` --- address of the vehicle's character sequence.
-   `speeds` --- movement speed.

The timer ISR iterates over the vehicles and calls `moveleft` or
`moveright` according to each vehicle's direction. These procedures
erase the vehicle at its old position, update its position, wrap it
around the screen edge when necessary, and draw it again.

Vehicle columns and speeds use a scaled representation so that movement
can be smaller than one text column per timer update. The drawing and
collision routines convert the stored column position to a screen
column.

### 3. Frog movement and collision detection

The frog's position is stored in `frogrow` and `frogcol`. The keyboard
ISR reads the keyboard scan code and passes it to `moveMyFrigga`, which
identifies the arrow key and updates the frog's position.

Before moving, the program restores the characters that were underneath
the frog. After movement, it checks whether the frog overlaps a vehicle
using `checkCollision`. If a collision is detected, `lifeLost` decreases
the lives count and `lazarusFrog` resets the frog and crossing timer.

The program saves the three screen cells underneath the frog in
`frogsave`, allowing the original road or safe-zone characters to be
restored when the frog moves.

### 4. Home slots, score, and levels

The three home positions are stored in `homecols`, while `homefilled`
records which slots have been reached. When the frog reaches the home
row, `tryHome` checks whether its position matches an unfilled slot.

A successful crossing: - Marks the slot as filled. - Draws a frog in
that slot. - Adds 50 points and the remaining time to the score. -
Resets the player frog for the next crossing.

`checkLevel` checks whether all three slots are filled. If they are, it
clears the slot state, redraws the home slots, and increases every
vehicle's speed.

### 5. Timer and keyboard interrupt handlers

The program saves the original interrupt vectors before installing its
own handlers.

-   **Timer ISR (`timerIsr`):** Runs on timer interrupts. It moves the
    vehicles, updates the crossing countdown through `checkTimer`, and
    checks for collisions. It then chains to the original timer handler.
-   **Keyboard ISR (`kbIsr`):** Reads keyboard scan codes, processes
    arrow-key movement, and sets the pause and quit flags when ESC is
    pressed. It acknowledges the keyboard interrupt before returning.

The crossing timer is updated using a tick counter (`secticks`). Once
the counter reaches its configured threshold, the displayed time is
decreased by one second.

### 6. Pause, exit, and cleanup

The main game loop checks the game-over and quit flags. When ESC is
pressed, the game pauses and `confirmExit` displays the Y/N prompt. The
original keyboard handler is temporarily restored so the response can be
read using a DOS software interrupt. Choosing N reinstalls the game's
keyboard handler and redraws the game screen; choosing Y proceeds to the
final screen.

Before terminating, `restoreInterrupts` restores the original timer and
keyboard interrupt vectors. This allows the DOS environment to continue
using its normal handlers after the game exits.

### 7. Reusable output procedures

`printstr` and `printnum` are stack-parameterized procedures used to
display text and decimal numbers at specified video-memory positions.
They preserve the registers they use and return by removing their
parameters from the stack.

## Code Structure

The project is delivered as a single assembly source file:

``` text
frogger-highway-havoc/
└── P18.asm
```

The source contains: - Game variables, strings, vehicle sprites, and
vehicle arrays. - Text and number printing procedures. - Timer and
keyboard interrupt service routines. - Introduction, game,
exit-confirmation, and end-screen procedures. - Vehicle drawing,
movement, and collision routines. - Frog movement, home-slot, scoring,
timer, and level logic. - Main program setup and interrupt cleanup.

## Requirements

-   NASM assembler
-   DOSBox
-   A DOS-compatible environment for running the assembled `.COM`
    program

## Build and Run

1.  Assemble the source file with NASM:

    ``` bash
    nasm -f bin P18.asm -o frogger.com
    ```

2.  Start DOSBox and mount the directory containing `frogger.com`. For
    example, if the files are in `C:\Frogger`:

    ``` text
    mount c c:\Frogger
    c:
    ```

3.  Run the game:

    ``` text
    frogger.com
    ```

## Project Context

Developed as a **Fall 2026 Computer Organization and Assembly Language
(COAL)** semester project. The project demonstrates low-level
programming concepts including 8086 registers, stack-based procedures,
direct video-memory access, software interrupts, hardware interrupt
handling, and interrupt-vector management.

## Authors

-   **Muhammad Hamdan Subzwari** --- 25L-2018
-   **Muhammad Ayaan** --- 25L-2015
