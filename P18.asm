;Wario and Waluigi
[org 0x100]

jmp start

; Global Variables
score       dw 0
lives       dw 3
time        dw 30

; Interrupt related variables and general flags
oldKbIsr:       dd 0
oldTimerIsr:    dd 0
gameOverFlag:   dw 0
quitFlag:       dw 0
pauseFlag:      dw 0
exitConfirmed: dw 0

; string related Variables
strintro:       db 'WARIO AND WALUIGI: FROGGER', 0
strmember1:     db 'MEMBER 1: MUHAMMAD HAMDAN SUBZWARI', 0
strroll1:       db 'ROLL NO: 25L-2018', 0
strmember2:     db 'MEMBER 2: MUHAMMAD AYAAN', 0
strroll2:       db 'ROLL NO: 25L-2015', 0
strsemester:    db 'FALL 2026', 0
strstart:       db 'PRESS ANY KEY TO START', 0

strexit:        db 'ARE YOU SURE YOU WANT TO EXIT THE GAME?', 0
stryesno:       db 'PRESS Y TO EXIT / N TO RESUME', 0
strfinal:       db 'FINAL SCORE: ', 0
strgameover:    db 'GAME OVER', 0
strthanks:      db 'THANK YOU FOR PLAYING!', 0

strscore    db 'SCORE ', 0
strlives    db 'LIVES ', 0
strfrogger  db 'FROGGER', 0
strtime     db 'TIME 0:', 0
strmedian   db 'MEDIAN', 0
strhome     db 'HOME', 0

;Frog Related Variables
frogrow:     dw 160 * 21
frogcol:     dw 39
frogsave:    dw 0, 0, 0
secticks:    dw 0
homecols:    dw 10, 30, 50
homefilled:  dw 0, 0, 0

; Vehicle pictures
carright    db 0xDC, 0xDB, 0xDB, 0xDC, '>'
carleft     db '<', 0xDC, 0xDB, 0xDB, 0xDC
truckright  db 0xDC, 0xDC, 0xDC, 0xDB, 0xDB, '>'
truckleft   db '<', 0xDB, 0xDB, 0xDC, 0xDC, 0xDC
bikeright   db 0xDB, 0xDC, 0xDC, 0xDC, '>'
bikeleft    db '<', 0xDC, 0xDC, 0xDC, 0xDB

; Vehicle arrays, one word per vehicle (9 vehicles)
rows        dw 160 * 5, 160 * 5, 160 * 7, 160 * 7, 160 * 9, 160 * 14, 160 * 16, 160 * 16, 160 * 18
; cols ARE SCALED BY 2 internally to allow for fractional speeds!
cols        dw 40, 120, 20, 100, 60, 30, 50, 130, 70
dirs        dw 0, 0, 1, 1, 0, 1, 0, 0, 1
lens        dw 5, 5, 6, 6, 5, 5, 5, 5, 5
attrs       dw 0x0C, 0x0C, 0x0B, 0x0B, 0x0E, 0x0D, 0x09, 0x09, 0x0C
sprites     dw carleft, carleft, truckright, truckright, carleft, carright, bikeleft, bikeleft, carright
; speeds ARE SCALED BY 2 (1=0.5, 2=1.0, 3=1.5, 4=2.0, 5=2.5, 6=3.0)
speeds      dw 6, 6, 5, 5, 4, 3, 2, 2, 1

; Stack-Based printstr
printstr:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx
        push si
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax

        mov  si, [bp+8]
        mov  di, [bp+6]
        mov  ah, [bp+4]

    nextchar:
        lodsb
        cmp  al, 0
        je   strdone
        stosw
        jmp  nextchar

    strdone:
        pop  es
        pop  di
        pop  si
        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  6

; Stack-Based printnum
printnum:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx
        push dx
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax

        mov  ax, [bp+8]
        mov  di, [bp+6]
        mov  dh, [bp+4]

        mov  bx, 10
        mov  cx, 0

    divloop:
        mov  dx, 0
        div  bx
        push dx
        inc  cx
        cmp  ax, 0
        jne  divloop

    printdigits:
        pop  ax
        add  al, '0'
        mov  ah, [bp+4]
        stosw
        loop printdigits

        pop  es
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  6
		
; Timer ISR: moves all lanes, counts down the crossing timer, checks for hits
timerIsr:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es
        push cs
        pop  ds              ; ds = our segment
		
        mov  ax, 0xB800
        mov  es, ax          ; es = video memory for the drawing routines
        cld                  ; string instructions go forward

        cmp  word [pauseFlag], 1
        je   timerExit

        cmp  word [gameOverFlag], 1
        je   timerExit

        ; Move every vehicle one step
        mov  bx, 0
    isrMoveLoop:
        cmp  word [dirs+bx], 0
        jne  isrGoRight
        call moveleft
        jmp  isrMoveNext
    isrGoRight:
        call moveright
    isrMoveNext:
        add  bx, 2
        cmp  bx, 18
        jl   isrMoveLoop

        ; Count down the crossing timer
        call checkTimer
        cmp  word [gameOverFlag], 1
        je   timerExit       ; timer ran out on the last life

        ; did the frog get hit
        call checkCollision
        cmp  ax, 1
        jne  timerExit
        call comeBackFrigga
        call lifeLost

    timerExit:
        pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
		
        jmp  far [cs:oldTimerIsr]   ; chain to BIOS, it sends the EOI

; Keyboard ISR: handles arrow keys and requests exit confirmation on ESC.
kbIsr:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
        push ds
        push es

        push cs
        pop  ds

        mov  ax, 0xB800
        mov  es, ax
        cld

        in   al, 0x60

        cmp  al, 0x01
        jne  kbIsrArrows

        mov  word [quitFlag], 1
        mov  word [pauseFlag], 1
        jmp  kbIsrEnd

    kbIsrArrows:
        cmp  word [pauseFlag], 1
        je   kbIsrEnd

        cmp  word [gameOverFlag], 1
        je   kbIsrEnd

        mov  ah, al
        call moveMyFrigga

    kbIsrEnd:
        mov  al, 0x20
        out  0x20, al

        pop  es
        pop  ds
        pop  bp
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax

        iret
		
; Display the intro screen
showIntro:
        push ax
        push bx
        push cx
        push dx
        push di
        push es

        mov  ax, 0x0003
        int  0x10

        mov  ax, 0xB800
        mov  es, ax

        mov  di, 0
        mov  cx, 80 * 25
        mov  ax, 0x1720
        rep  stosw
		
		mov  ax, 0x1F40
        mov  di, 0
        mov  cx, 80
        rep  stosw

        mov  di, 160 * 24
        mov  cx, 80
        rep  stosw

        mov  di, 0
        mov  cx, 25

    introBorder:
        mov  word [es:di], 0x1F40
        mov  word [es:di+158], 0x1F40
        add  di, 160
        loop introBorder

        push strintro
        push 694
        push 0x1F
        call printstr

        push strmember1
        push 1326
        push 0x1F
        call printstr

        push strroll1
        push 1662
        push 0x1F
        call printstr

        push strmember2
        push 1976
        push 0x1F
        call printstr

        push strroll2
        push 2302
        push 0x1F
        call printstr

        push strsemester
        push 2630
        push 0x1F
        call printstr

        push strstart
        push 3098
        push 0x1F
        call printstr

        xor  ah, ah
        int  0x16

        pop  es
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax

        ret
		
; Confirm the exit and return AX == 1 for Yes
confirmExit:
        push bx
        push cx
        push dx
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax

        mov  di, 0
        mov  cx, 80 * 25
        mov  ax, 0x1F20
        rep  stosw
		
		mov  ax, 0x1F40
        mov  di, 0
        mov  cx, 80
        rep  stosw

        mov  di, 160 * 24
        mov  cx, 80
        rep  stosw

        mov  di, 0
        mov  cx, 25

    confirmBorder:
        mov  word [es:di], 0x1F40
        mov  word [es:di+158], 0x1F40
        add  di, 160
        loop confirmBorder

        push strexit
        push 1640
        push 0x1F
        call printstr

        push stryesno
        push 2130
        push 0x1F
        call printstr
		
	; restore the old keyboard handler
		xor  ax, ax
		mov  es, ax

        cli
		
        mov  ax, [oldKbIsr]
        mov  [es:9*4], ax
        mov  ax, [oldKbIsr+2]
        mov  [es:9*4+2], ax
		
        sti

    exitRead:
        mov  ah, 0x01
        int  0x21

        cmp  al, 'Y'
        je   exitYes

        cmp  al, 'y'
        je   exitYes

        cmp  al, 'N'
        je   exitNo

        cmp  al, 'n'
        je   exitNo

        jmp  exitRead

    exitYes:
        mov  word [exitConfirmed], 1
        jmp  exitDone

    exitNo:
        mov  word [exitConfirmed], 0
		
    exitDone:
	; restore our kbISR
		xor  ax, ax
        mov  es, ax

        cli
		
        mov  word [es:9*4], kbIsr
        mov  [es:9*4+2], cs
		
        sti

        pop  es
        pop  di
        pop  dx
        pop  cx
        pop  bx

        mov  ax, [exitConfirmed]

        ret
		
; display the final screen
showEndScreen:
        push ax
        push cx
        push di
        push es

        mov  ax, 0x0003
        int  0x10

        mov  ax, 0xB800
        mov  es, ax

        mov  di, 0
        mov  cx, 80 * 25
        mov  ax, 0x0E20
        rep  stosw
		
		mov  ax, 0x0E40
        mov  di, 0
        mov  cx, 80
        rep  stosw

        mov  di, 160 * 24
        mov  cx, 80
        rep  stosw

        mov  di, 0
        mov  cx, 25

    endBorder:
        mov  word [es:di], 0x0E40
        mov  word [es:di+158], 0x0E40
        add  di, 160
        loop endBorder

        push strgameover
        push 1350
        push 0x0E
        call printstr

        push strfinal
        push 1824
        push 0x0E
        call printstr

        push word [score]
        push 1850
        push 0x0E
        call printnum

        push strthanks
        push 2458
        push 0x0E
        call printstr

        pop  es
        pop  di
        pop  cx
        pop  ax

        ret
		
; save old interrupts and install the actual game ISRs
installInterrupts:
        push ax
        push es

        xor  ax, ax
        mov  es, ax

        mov  ax, [es:9*4]
        mov  [oldKbIsr], ax

        mov  ax, [es:9*4+2]
        mov  [oldKbIsr+2], ax

        mov  ax, [es:8*4]
        mov  [oldTimerIsr], ax

        mov  ax, [es:8*4+2]
        mov  [oldTimerIsr+2], ax

        cli

        mov  word [es:8*4], timerIsr
        mov  [es:8*4+2], cs

        mov  word [es:9*4], kbIsr
        mov  [es:9*4+2], cs

        sti

        pop  es
        pop  ax

        ret

; Restores the original BIOS keyboard and timer interrupt vectors.
restoreInterrupts:
        push ax
        push es

        xor  ax, ax
        mov  es, ax

        cli

        mov  ax, [oldKbIsr]
        mov  [es:9*4], ax

        mov  ax, [oldKbIsr+2]
        mov  [es:9*4+2], ax

        mov  ax, [oldTimerIsr]
        mov  [es:8*4], ax

        mov  ax, [oldTimerIsr+2]
        mov  [es:8*4+2], ax

        sti

        pop  es
        pop  ax

        ret
		
; checks if the user pressed exit or lives were lost
gameLoop:
        push ax

    gameWait:
        cmp  word [gameOverFlag], 1
        je   gameEnded

        cmp  word [quitFlag], 1
        jne  gameWait

        call confirmExit

        cmp  ax, 1
        je   playerConfirmed

        ; Player selected N, resume the game
        call drawGameScreen

        mov  word [quitFlag], 0
        mov  word [pauseFlag], 0

        jmp  gameWait

    playerConfirmed:
        mov  word [exitConfirmed], 1
        jmp  gameLoopDone

    gameEnded:
        mov  word [exitConfirmed], 1

    gameLoopDone:
        pop  ax
        ret

; Main Program
start:
        call showIntro

        call drawGameScreen

        call installInterrupts

        call gameLoop

        call restoreInterrupts

        call showEndScreen

        mov  ax, 0x4C00
        int  0x21

; draws the entire game screen
drawGameScreen:
        ; Set Video Mode 3
        mov  ax, 0x0003
        int  0x10

        mov  ax, 0xB800
        mov  es, ax

        ; Draw Scoreboard
        mov  di, 0
        mov  cx, 80
        mov  ax, 0x0E20
        rep  stosw

        ; Draw Top Safe Zone
        mov  di, 160
        mov  cx, 80 * 3
        mov  ax, 0x2020
        rep  stosw

        ; Draw Upper Road
        mov  di, 160 * 4
        mov  cx, 80 * 7
        mov  ax, 0x0720
        rep  stosw

        ; Draw Median Safe Zone
        mov  di, 160 * 11
        mov  cx, 80 * 2
        mov  ax, 0x7020
        rep  stosw

        ; Draw Lower Road
        mov  di, 160 * 13
        mov  cx, 80 * 7
        mov  ax, 0x0720
        rep  stosw

        ; Draw Bottom Safe Zone
        mov  di, 160 * 20
        mov  cx, 80 * 3
        mov  ax, 0x7020
        rep  stosw

        ; Draw Lane Lines
        mov  ax, 0x0F2D
        call drawdashedlines

        ; Print Score Text
        push strscore
        push 2
        push 0x0E
        call printstr

        ; Print Score Value
        push word [score]
        push 14
        push 0x0E
        call printnum

        ; Print Lives Text
        push strlives
        push 30
        push 0x0E
        call printstr

        ; Print Lives Value
        push word [lives]
        push 42
        push 0x0E
        call printnum

        ; Print Frogger Text
        push strfrogger
        push 70
        push 0x0E
        call printstr

        ; Print Time Text
        push strtime
        push 140
        push 0x0E
        call printstr

        ; Print Time Value
        push word [time]
        push 154
        push 0x0E
        call printnum

        ; Print Median Text
        push strmedian
        push 1762
        push 0x70
        call printstr

        ; Draw Entities
        call drawhomeslots
        call redrawFilledHomes
        call drawvehicles
        call saveMyFrogga
        call newFrogga

        ; Print Home Text
        push strhome
        push 402
        push 0x20
        call printstr
		
		ret
		
; redraws all the previously filled home slots
redrawFilledHomes:
        push ax
        push bx

        mov  bx, 0

    redrawHomeLoop:
        cmp  word [homefilled+bx], 0
        je   redrawHomeNext

        call drawFilledSlot

    redrawHomeNext:
        add  bx, 2
        cmp  bx, 6
        jl   redrawHomeLoop

        pop  bx
        pop  ax

        ret

; Moves vehicle bx left according to its speed
moveleft:
        push ax
        push dx

        ; Erase the entire vehicle at current position
        call erasevehicle

        ; Step left by the fixed-point speed value
        mov  ax, [speeds+bx]
        sub  word [cols+bx], ax

        ; If fully off the left edge, start again past the right edge
        mov  ax, [cols+bx]
        mov  dx, [lens+bx]
        shl  dx, 1       ; Scale the length size to fixed-point size
        add  ax, dx
        cmp  ax, 0
        jg   leftdraw
        mov  word [cols+bx], 160

    leftdraw:
        call drawvehicle
        pop  dx
        pop  ax
        ret

; Moves vehicle bx right according to its speed
moveright:
        push ax
        push dx

        ; Erase the entire vehicle at current position
        call erasevehicle

        ; Step right by the fixed-point speed value
        mov  ax, [speeds+bx]
        add  word [cols+bx], ax

        ; If fully off the right edge, start again before the left edge
        cmp  word [cols+bx], 160
        jl   rightdraw
        mov  ax, 0
        mov  dx, [lens+bx]
        shl  dx, 1       ; Scale the length size to fixed-point size
        sub  ax, dx
        mov  [cols+bx], ax

    rightdraw:
        call drawvehicle
        pop  dx
        pop  ax
        ret

; Erases the full vehicle footprint before it jumps to its next frame
erasevehicle:
        push ax
        push cx
        push dx
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax
        mov  cx, [lens+bx]
        mov  dx, [cols+bx]
        sar  dx, 1           ; Shift Arithmetic Right divides internal col by 2

    erasedrawnext:
        cmp  dx, 0
        jl   eraseskip
        cmp  dx, 80
        jge  eraseskip
        mov  di, [rows+bx]
        add  di, dx
        add  di, dx
        mov  word [es:di], 0x0720

    eraseskip:
        add  dx, 1
        loop erasedrawnext

        pop  es
        pop  di
        pop  dx
        pop  cx
        pop  ax
        ret

; Draws vehicle bx, cells outside the screen are skipped
drawvehicle:
        push ax
        push cx
        push dx
        push si
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax
        mov  si, [sprites+bx]
        mov  cx, [lens+bx]
        mov  dx, [cols+bx]
        mov  ah, [attrs+bx]
        sar  dx, 1           ; Shift Arithmetic Right divides internal col by 2

    drawnext:
        lodsb
        cmp  dx, 0
        jl   drawskip
        cmp  dx, 80
        jge  drawskip
        mov  di, [rows+bx]
        add  di, dx
        add  di, dx
        mov  [es:di], ax

    drawskip:
        add  dx, 1
        loop drawnext

        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  ax
        ret

; Subroutines for Drawing Entities
drawdashedlines:
        mov  di, 160 * 6
        call dodashes
        mov  di, 160 * 8
        call dodashes
        mov  di, 160 * 15
        call dodashes
        mov  di, 160 * 17
        call dodashes
        ret

dodashes:
        mov  cx, 20
    dashloop:
        stosw
        stosw
        add  di, 4
        loop dashloop
        ret

drawhomeslots:
        mov  bx, 0
    slotloop:
        mov  ax, 0x0020
        mov  cx, 6
        mov  di, 160 * 1 + 20
        add  di, bx
        rep  stosw
        mov  cx, 6
        mov  di, 160 * 2 + 20
        add  di, bx
        rep  stosw
        mov  cx, 6
        mov  di, 160 * 3 + 20
        add  di, bx
        rep  stosw
        add  bx, 40
        cmp  bx, 120
        jl   slotloop
        ret

; Draws all vehicles at their starting columns
drawvehicles:
        push bx
        mov  bx, 0
    drawvloop:
        call drawvehicle
        add  bx, 2
        cmp  bx, 18
        jl   drawvloop
        pop  bx
        ret

;The frog occupies 3 cells, draw it
newFrogga:
        push ax
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax

        mov  di, [frogrow]
        add  di, [frogcol]
        add  di, [frogcol]

        mov  ah, 0x2F
        mov  al, '('
        mov  [es:di], ax
        mov  al, 0x07
        mov  [es:di+2], ax
        mov  al, ')'
        mov  [es:di+4], ax

        pop  es
        pop  di
        pop  ax

        ret

;Save the cells underneath the frog
saveMyFrogga:
        push ax
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax

        mov  di, [frogrow]
        add  di, [frogcol]
        add  di, [frogcol]

        mov  ax, [es:di]
        mov  [frogsave], ax
        mov  ax, [es:di+2]
        mov  [frogsave+2], ax
        mov  ax, [es:di+4]
        mov  [frogsave+4], ax

        pop  es
        pop  di
        pop  ax

        ret

;Redraws what was underneath the frog initially
comeBackFrigga:
        push ax
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax

        mov  di, [frogrow]
        add  di, [frogcol]
        add  di, [frogcol]

        mov  ax, [frogsave]
        mov  [es:di], ax
        mov  ax, [frogsave+2]
        mov  [es:di+2], ax
        mov  ax, [frogsave+4]
        mov  [es:di+4], ax

        pop  es
        pop  di
        pop  ax

        ret

;Reset the frog and timer after a collision
lazarusFrog:
        mov  word [frogrow], 160 * 21
        mov  word [frogcol], 39
        mov  word [time], 30
        mov  word [secticks], 0

        call saveMyFrogga
        call newFrogga
        call updateHUD

        ret

;Erase and reprint the 0th row (Rimer, Score, etc)
updateHUD:
        push ax
        push cx
        push di
        push es

        mov  ax, 0xB800
        mov  es, ax
        cld

        mov  ax, 0x0E20
        mov  di, 14
        mov  cx, 8
        rep  stosw

        mov  di, 42
        mov  cx, 2
        rep  stosw

        mov  di, 154
        mov  cx, 3
        rep  stosw

        push word [score]
        push 14
        push 0x0E
        call printnum

        push word [lives]
        push 42
        push 0x0E
        call printnum

        cmp  word [time], 10
        jae  timeTwo

        mov  word [es:154], 0x0E30
        push word [time]
        push 156
        push 0x0E
        call printnum
        jmp  hudEnd

    timeTwo:
        push word [time]
        push 154
        push 0x0E
        call printnum

    hudEnd:
        pop  es
        pop  di
        pop  cx
        pop  ax

        ret

; Returns ax = 1 if any vehicle overlaps the frog, otherwise ax = 0
checkCollision:
        push bx
        push cx
        push dx

        mov  bx, 0

    collNext:
        mov  ax, [rows+bx] ;diff row to where the frog is
        cmp  ax, [frogrow]
        jne  collSkip

        mov  dx, [cols+bx]
        sar  dx, 1
        mov  cx, dx
        add  cx, [lens+bx]
        dec  cx
        cmp  cx, [frogcol] ;col is diff to where frog is
        jl   collSkip

        mov  ax, [frogcol]
        add  ax, 2
        cmp  dx, ax
        jg   collSkip

        mov  ax, 1 ;did collide
        jmp  collDone

    collSkip:
        add  bx, 2
        cmp  bx, 18
        jl   collNext
        mov  ax, 0

    collDone:
        pop  dx
        pop  cx
        pop  bx

        ret

;If scan code for an arrow key is detected, move the Frog
moveMyFrigga:
        push ax

        cmp  ah, 0x48
        je   keyUp

        cmp  ah, 0x50
        je   keyDown

        cmp  ah, 0x4B
        je   keyLeft

        cmp  ah, 0x4D
        je   keyRight

        jmp  keyDone ;arrow key was not pressed

    keyUp:
        cmp  word [frogrow], 160 * 4
        jne  keyUpMove
        call tryHome ;reached the end
        jmp  keyDone

    keyUpMove:
        call comeBackFrigga
        sub  word [frogrow], 160
        jmp  keyMoved

    keyDown:
        cmp  word [frogrow], 160 * 22
        je   keyDone ;already at the bottom
        call comeBackFrigga
        add  word [frogrow], 160
        jmp  keyMoved

    keyLeft:
        cmp  word [frogcol], 0
        je   keyDone
        call comeBackFrigga
        sub  word [frogcol], 1
        jmp  keyMoved

    keyRight:
        cmp  word [frogcol], 77
        je   keyDone
        call comeBackFrigga
        add  word [frogcol], 1

    keyMoved:
        call checkCollision
        cmp  ax, 1
        jne  keySafe
        call lifeLost
        jmp  keyDone

    keySafe:
        call saveMyFrogga ;redraw the frog
        call newFrogga

    keyDone:
        pop  ax
        ret

;Did we reach home, end of last row and fill up a slot we lined up with
tryHome:
        push ax
        push bx

        mov  bx, 0

    homeNext:
        cmp  word [homefilled+bx], 0
        jne  homeSkip; filled

        mov  ax, [frogcol]
        cmp  ax, [homecols+bx]
        jb   homeSkip

        mov  ax, [homecols+bx]
        add  ax, 3
        cmp  [frogcol], ax
        ja   homeSkip

        mov  word [homefilled+bx], 1
        call drawFilledSlot

        add  word [score], 50
        mov  ax, [time]
        add  [score], ax

        call comeBackFrigga
        call checkLevel
        call lazarusFrog

        jmp  homeDone

    homeSkip:
        add  bx, 2
        cmp  bx, 6
        jl   homeNext

    homeDone:
        pop  bx
        pop  ax

        ret

;js draw a frog inside the HOME
drawFilledSlot:
        push di
        push es

        mov  di, 0xB800
        mov  es, di

        mov  di, [homecols+bx]
        shl  di, 1
        add  di, 160 * 2 + 2

        mov  word [es:di], 0x0A28
        mov  word [es:di+2], 0x0A07
        mov  word [es:di+4], 0x0A29

        pop  es
        pop  di

        ret

;are all slots filled? Yes, speed this up
checkLevel:
        push ax
        push bx

        mov  bx, 0

    levelCheck:
        cmp  word [homefilled+bx], 0
        je   levelDone
        add  bx, 2
        cmp  bx, 6
        jl   levelCheck
        mov  bx, 0

    levelReset:
        mov  word [homefilled+bx], 0
        add  bx, 2
        cmp  bx, 6
        jl   levelReset
        call drawhomeslots
        mov  bx, 0

    levelSpeed:
        add  word [speeds+bx], 1
        add  bx, 2
        cmp  bx, 18
        jl   levelSpeed

    levelDone:
        pop  bx
        pop  ax
        ret

;check the timer ticks, lower the corssing time and js lose a life if zero
checkTimer:
        add  word [secticks], 1
        cmp  word [secticks], 18
        jne  timerDone

        mov  word [secticks], 0
        sub  word [time], 1
        call updateHUD

        cmp  word [time], 0
        jne  timerDone
        call comeBackFrigga
        call lifeLost

    timerDone:
        ret

;sub one life, check if game over or send frog back to start
lifeLost:
        sub  word [lives], 1
        cmp  word [lives], 0
        jne  lifeLostReset
        call gameOver
        ret

    lifeLostReset:
        call lazarusFrog
        ret

;freeze the game and show the game over banner, ESC is handled by kbIsr
gameOver:
        mov  word [gameOverFlag], 1
        mov  word [pauseFlag], 1

        call updateHUD

        push strgameover
        push 1980
        push 0x4F
        call printstr

        ret