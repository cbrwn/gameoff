  .inesprg 1
  .ineschr 1
  .inesmap 0
  .inesmir 1

;;;;;;;;;;;;;;;
  .bank 0
  .org $C000 

PLAYERWIDTH    = $08
PLAYERHEIGHT   = $08
PLAYERSPEED    = $01
TURNSPEED      = $10
SPRITECARBASE  = $08 ; start of car sprites
CARSPRITE      = $0200

WALLBOXCOUNT   = $07 ; number of boxes which act as walls

TIMERTILEHIGH  = $23
TIMERTILELOW   = $21
LAPTILEHIGH    = $23
LAPTILELOW     = $61

  .rsset $0000
buttons   .rs 1

playerx        .rs 1
playery        .rs 1
rotationindex  .rs 1
playerrotation .rs 1
playerrottimer .rs 1
tempmovement   .rs 1 ; used for (I never finished this comment wtf)
playeraccel    .rs 1 ; increases with up/down
playervel      .rs 1 ; moves player when it overflows
negativevel    .rs 1
; stuff to deal with getting stuck in walls because I'm too dumb
didcollide     .rs 1 ; did we collide this frame?
colframes      .rs 1 ; how many frames in a row are we inside something
noclplayerx    .rs 1 ; last x pos where we didn't collide
noclplayery    .rs 1 ; last y pos where we didn't collide

timermils      .rs 1
timer1         .rs 1
timer10        .rs 1
timer100       .rs 1

currentlap     .rs 1
maxlap         .rs 1

RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  LDX #$00
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

  jsr waitvblank

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x    ;move all sprites off screen
  INX
  BNE clrmem
   
  jsr waitvblank

LoadPalettes:
  LDA $2002    ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006    ; write the high byte of $3F00 address
  LDA #$00
  STA $2006    ; write the low byte of $3F00 address
  LDX #$00
LoadPalettesLoop:
  LDA palette, x        ;load palette byte
  STA $2007             ;write to PPU
  INX                   ;set index to next byte
  CPX #$20            
  BNE LoadPalettesLoop  ;if x = $20, 32 bytes copied, all done

loadbackground:
  lda $2002
  lda #$20
  sta $2006
  lda #$00;#20
  sta $2006
  ; load in 4 parts
  ; first part:
  ldx #$00
loadbackgroundloop0
  lda nametable0,x
  sta $2007
  inx
  cpx #$00
  bne loadbackgroundloop0
  ; second part:
  ldx #$00
loadbackgroundloop1
  lda nametable1,x
  sta $2007
  inx
  cpx #$00
  bne loadbackgroundloop1
  ; third part:
  ldx #$00
loadbackgroundloop2
  lda nametable2,x
  sta $2007
  inx
  cpx #$00
  bne loadbackgroundloop2
  ; last part:
  ldx #$00
loadbackgroundloop3
  lda nametable3,x
  sta $2007
  inx
  cpx #$C0
  bne loadbackgroundloop3

loadattribute:
  lda $2002
  lda #$23
  sta $2006
  lda #$c0
  sta $2006
  ldx #$00
loadattributeloop:
  lda attribute,x
  sta $2007
  inx
  cpx #$40
  bne loadattributeloop

LoadSprites:
  ldx #$00
LoadSpritesLoop:
  lda sprites,x
  sta  $0200,x
  inx
  cpx #$04
  bne LoadSpritesLoop

  jsr enablenmi

  ; initialize variables and stuff
  lda #$80
  sta playerx
  lda #$ca
  sta playery
  lda #$02
  sta rotationindex
  jsr updaterotationfromindex
  lda #$01
  sta currentlap
  lda #$03
  sta maxlap

loopsies:
  ; just waiting for nmi
  JMP loopsies

NMI:
  LDA #$00
  STA $2003  ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014  ; set the high byte (02) of the RAM address, start the transfer

  ; update graphics
  jsr updateplayersprite
  jsr displaytimer
  jsr displaylapcount

  ; read inputs
  jsr readcontroller

  ; game logic
  lda #$00
  sta didcollide ; reset our collision flag

  jsr incrementtimer

  jsr turncooldown
  jsr rotateplayer
  jsr accelerateplayer
  ; driveplayer twice as an easy way to move faster
  jsr driveplayer
  jsr driveplayer
  jsr collideplayer

  jsr fixstuckinwall

  ; end of nmi
  jsr enablenmi

  RTI ; return from interrupt

driveplayer:
  lda playervel
  clc
  adc playeraccel
  sta playervel
  bcc dplend
  ; velocity carried over
  jsr updatemovedirections
  lda negativevel
  bne dplreverse
  jsr moveplayerforward
  jmp dplend
dplreverse
  jsr moveplayerbackwards
dplend:
  rts

accelerateplayer:
  lda buttons
  and #%10000000
  beq aplnobutton
  ; when velocity is negative, act like no button is being held down
  lda negativevel
  bne aplnobutton
  lda playeraccel
  cmp #$b0
  bcs aplend
  inc playeraccel
  inc playeraccel
  jmp aplend
aplnobutton:
  lda playeraccel
  cmp #$00
  beq aplend
  sec
  sbc #$02
  sta playeraccel
  bcs aplend
  lda #$00
  sta playeraccel
aplend:
  ; check if we're moving backwards
  lda negativevel
  beq aplafterreverse
  ; we are moving backwards
  ; if accel is 0 then make it seem like we start going forward
  lda playeraccel
  bne aplafterreverse
  lda #$00
  sta negativevel ; just by setting negative flag to 0
aplafterreverse:
  rts

moveplayerforward:
  ; honestly this is all awful and not worth commenting I just wanted the driving to work
  cpx #$00
  bne mplforward2
  dec playerx
mplforward2:
  cpx #$02
  bne mplforward3
  inc playerx
mplforward3:
  cpy #$00
  bne mplforward4
  dec playery
mplforward4:
  cpy #$02
  bne mpfend
  inc playery
mpfend:
  rts

moveplayerbackwards:
  cpx #$00
  bne mplback2
  inc playerx
mplback2:
  cpx #$02
  bne mplback3
  dec playerx
mplback3:
  cpy #$00
  bne mplback4
  inc playery
mplback4:
  cpy #$02
  bne mplbackend
  dec playery
mplbackend:
  rts

collideplayer:
  ; check left wall
  lda playerx
  cmp #$10
  bcs clpchecktopwall
  lda #$11
  sta playerx
  jsr playercollided
  jmp clpend
clpchecktopwall:
  ; check top wall
  lda playery
  cmp #$10
  bcs clpcheckrightwall
  lda #$11
  sta playery
  jsr playercollided
  cmp clpend
clpcheckrightwall:
  ; check right wall
  lda playerx
  cmp #$e8
  bcc clpcheckbottomwall
  lda #$e7
  sta playerx
  jsr playercollided
  cmp clpend
clpcheckbottomwall:
  lda playery
  cmp #$d8
  bcc clpend
  lda #$d7
  sta playery
  jsr playercollided
clpend:
  jsr collidewalls
  rts

collidewalls
  ldy #$00
clwloop:
  jsr roundxupwalls
  ; check left side
  lda playerx
  clc
  adc #PLAYERWIDTH
  cmp walls,x
  bcc clwloopend
  ; check top side
  inx
  lda playery
  clc
  adc #PLAYERHEIGHT
  cmp walls,x
  bcc clwloopend
  ; check right side
  inx
  lda playerx
  cmp walls,x
  bcs clwloopend
  ; check bottom side
  inx
  lda playery
  cmp walls,x
  bcs clwloopend
  ; WE'VE COLLIDED!
  jsr updatemovedirections
  jsr playercollided
  rts ; we can leave this routine
clwloopend:
  iny
  cpy #WALLBOXCOUNT
  bne clwloop
  jsr updatemovedirections
  ; wow collision done
  rts

; supposed to make x = y*4
roundxupwalls:
  ldx #$00
  cpy #$00
  beq rxuwend
  tya
rxuwloop:
  inx
  inx
  inx
  inx
  sec
  sbc #$01
  cmp #$00
  bne rxuwloop
rxuwend:
  rts

; call this when the car hits a wall or something
playercollided:
  lda negativevel
  eor #$01 ; flip between 0 and 1
  ;lda #$01
  sta negativevel
  lda #$01
  sta didcollide ; set flag to keep track that we collided this frame
  ; put car at last non-wall position
  lda noclplayerx
  sta playerx
  lda noclplayery
  sta playery
  ; reduce speed too 
  clc ; make sure carry is clear before rotating
  ror playeraccel ; / 2
  lda playeraccel
  cmp #$20
  bcs plclend
  lda #$20
  sta playeraccel ; make sure accel has a minimum so we're moving if stuck in wall
plclend:
  rts

fixstuckinwall:
  lda didcollide
  beq fswnocollide
  ; we did collide
  lda colframes
  clc
  adc #$01
  sta colframes
  cmp #$10
  bcc fswend
  ; we've been in a wall for 3 frames
  ; so we'll move to our last known non-wall position
  lda noclplayerx
  sta playerx
  lda noclplayery
  sta playery
  lda #$00
  sta colframes
  sta playeraccel
  sta negativevel
  jmp fswend
fswnocollide:
  ; didn't collide this frame
  ; keep track of this position where we're out of a wall
  lda playerx
  sta noclplayerx
  lda playery
  sta noclplayery
  ; reset frame counter
  lda #$00
  sta colframes
fswend:
  rts

turncooldown:
  ; if left/right isn't down then we can reset
  lda buttons
  and #%00000011
  bne tcdbuttonheld
  lda #$ff
  jmp tcdupdatetimer
tcdbuttonheld:
  ; button is down, count down the cooldown
  lda playerrottimer
  cmp #$ff
  beq tcdend
  ; cooldown timer is < ff
  clc
  adc #TURNSPEED
  bcc tcdupdatetimer
  ; went over $ff
  lda #$ff ; limit it to $ff
tcdupdatetimer:
  sta playerrottimer
tcdend:
  rts

rotateplayer:
  lda buttons
  and #%00000001
  beq plleftturn
  ; right is down
  lda playerrottimer
  cmp #$ff
  bne plleftturn ; only want to turn if the 'cooldown' is up
  jsr plrotateright ; deal with it in this subroutine or whatever it's called
  lda #$00
  sta playerrottimer ; reset turn cooldown
plleftturn:
  lda buttons
  and #%00000010
  beq plturnend
  ; left is down
  lda playerrottimer
  cmp #$ff
  bne plturnend ; only want to turn if the 'cooldown' is up
  jsr plrotateleft
  lda #$00
  sta playerrottimer ; reset turn cooldown
plturnend:
  rts

; left/right rotations are separate because I expected them to be big and used elsewhere
; i.e. collision/bouncing
plrotateright:
  lda rotationindex
  clc
  adc #$01
  cmp #$08
  bcc rrindexfinished
  ; index is >= $08
  lda #$00 ; so we loop
rrindexfinished:
  sta rotationindex
  jsr updaterotationfromindex
  rts

plrotateleft:
  lda rotationindex
  sec
  sbc #$01
  bcs rlindexfinished
  ; underflowed to $ff
  lda #$07 ; go back to highest index
rlindexfinished:
  sta rotationindex
  jsr updaterotationfromindex
  rts

; grabs the direction number from the 'directions' data below
updaterotationfromindex:
  ldx rotationindex
  lda directions,x
  sta playerrotation
  rts

updatemovedirections:
  ; idea here is to adjust x/y to show which directions we need to move
  ; 0 = negative movement, 1 = no movement, 2 = positive movement
  ; this is awful i should figure out how negatives work if they even do natively
  ldx #$01 ; net x movement
  ldy #$01 ; net y movement
  lda playerrotation
  and #%00001000 ; right
  beq mplleftcheck
  inx
mplleftcheck:
  lda playerrotation
  and #%00000100 ; left
  beq mplupcheck
  dex
mplupcheck:
  lda playerrotation
  and #%00000010 ; up
  beq mpldowncheck
  dey
mpldowncheck:
  lda playerrotation
  and #%00000001 ; down
  beq umdfinish
  iny
umdfinish:
  rts

updateplayersprite:
  lda playery
  sta CARSPRITE ; set y pos
  lda playerx
  ldx #$03 ; offset from sprite address for x position
  sta CARSPRITE, x
  ; rotation things
  ldx #$00 ; offset from first car sprite
  lda playerrotation
  and #%00001100 ; left or right
  beq upssetsprite
  inx
  lda playerrotation
  and #%00000011 ; up or down AND left or right so it will be diagonal
  beq upssetsprite
  inx
upssetsprite:
  txa
  clc
  adc #SPRITECARBASE
  ldx #$01 ; offset from start of sprite
  sta CARSPRITE,x
  ; first reset the flippage
  ldx #$02 ; offset for sprite attributes
  lda CARSPRITE,x
  and #%00111111 ; remove the last 2 bits (flips)
  sta CARSPRITE,x
  ; horizontal flip if facing right
  lda playerrotation
  and #%00001000
  beq upsvertflip
  ; are facing right
  lda CARSPRITE,x
  ora #%01000000
  sta CARSPRITE,x
upsvertflip:
  lda playerrotation
  and #%00000001
  beq upsend
  ; facing down
  lda CARSPRITE,x
  ora #%10000000
  sta CARSPRITE,x
upsend:
  rts

incrementtimer:
  lda timermils ; not milliseconds but frames, dumb name
  clc
  adc #$01
  sta timermils
  cmp #$3c ; ~1 second
  bne inctend
  ; 1 second is up
  lda #$00
  sta timermils ; reset frame count to 0
  lda timer1
  clc
  adc #$01
  sta timer1
  cmp #$0a ; roll over from 1 to 2 digits
  bne inctend
  ; rolled over
  lda #$00
  sta timer1 ; reset second count to 0
  lda timer10
  clc
  adc #$01
  sta timer10
  cmp #$0a ; roll over
  bne inctend
  lda #$00 ; reset tens count to 0
  sta timer10
  lda timer100
  clc
  adc #$01
  sta timer100
  cmp #$0a ; rolled over
  bne inctend
  lda #$09 ; cap it at $09
  sta timer100
inctend:
  rts

displaytimer:
  lda $2002 ; start listening for an address
  lda #TIMERTILEHIGH
  sta $2006
  lda #TIMERTILELOW
  sta $2006
  lda #$0d ; clock icon
  sta $2007
  ;lda #$0e ; hyphen
  ;sta $2007
  lda timer100
  sta $2007
  lda timer10
  sta $2007
  lda timer1
  sta $2007
  rts

displaylapcount:
  lda $2002 ; start listening for an address
  lda #LAPTILEHIGH
  sta $2006
  lda #LAPTILELOW
  sta $2006
  lda #$0f ; flag icon
  sta $2007
  ;lda #$0e ; hyphen
  ;sta $2007
  lda currentlap
  sta $2007
  lda #$10 ; slash
  sta $2007
  lda maxlap
  sta $2007
  rts

readcontroller:
  lda #$01
  sta $4016
  lda #$00
  sta $4016
  ldx #$08
readcontrollerloop:
  lda $4016
  lsr a ; push bit 0 into carry
  rol buttons ; shift buttons left and push carry into bit 0
  dex
  bne readcontrollerloop
  ; 7 6  5   4  3 2 1 0
  ; A B SEL STA U D L R
  rts

waitvblank:
  bit $2002
  bpl waitvblank
  rts

enablenmi:
  lda #%10010000
  sta $2000
  lda #%00011110
  sta $2001
  ; no scrolling
  lda #$00
  sta $2005
  sta $2005 
  rts
 
;;;;;;;;;;;;;;  
  .bank 1
  .org $E000
palette:
  .db $0f,$2D,$27,$30,  $15,$30,$1a,$09,  $0c,$00,$0f,$30,  $22,$27,$17,$0F   ; background palette
  .db $15,$1C,$15,$14,  $22,$21,$15,$30,  $39,$1C,$15,$14,  $22,$02,$38,$3C   ; sprite palette

sprites:
  .db $10,SPRITECARBASE,$01,$80 ; $0200

; background stuff
  .include "map.asm"

attribute:
  .incbin "map.atr"

; direction bit layout
; R L U D
; 0 0 0 0
directions:
  ;    U   UR  R  RD   D  LD  L    LU
  .db $02,$0a,$08,$09,$01,$05,$04,$06

walls:
  ; left, top, right, bottom
  .db $31, $30, $90, $7f
  .db $61, $65, $a0, $be
  .db $99, $af, $d0, $be
  .db $89, $50, $d0, $6f
  .db $0a, $a0, $40, $e7
  .db $c1, $8f, $f0, $9f
  .db $b1, $01, $f0, $2f

  .org $FFFA
  .dw NMI ; label to jump to on nmi
  .dw RESET
  .dw 0 ; not using irq
  
  
;;;;;;;;;;;;;;  
  .bank 2
  .org $0000
  .incbin "sprites.chr"