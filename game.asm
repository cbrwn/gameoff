  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

;;;;;;;;;;;;;;;
  .bank 0
  .org $C000 

PLAYERWIDTH    = $08
PLAYERHEIGHT   = $08
PLAYERSPEED    = $01
TURNSPEED      = $10
SPRITECARBASE  = $08 ; start of car sprites
CARSPRITE      = $0200

  .rsset $0000
buttons   .rs 1

playerx        .rs 1
playery        .rs 1
rotationindex  .rs 1
playerrotation .rs 1
playerrottimer .rs 1
tempmovement   .rs 1 ; used for 

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
  lda #$00;#$20
  sta $2006
  ldx #$00
loadbackgroundloop
  lda nametable,x
  sta $2007
  inx
  cpx #$a0 ; 128
  bne loadbackgroundloop

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
  cpx #$10
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
  sta playery
  jsr updaterotationfromindex

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

  ; read inputs
  jsr readcontroller

  ; game logic
  jsr rotateplayer
  jsr moveplayer

  ; end of nmi
  jsr enablenmi

  RTI ; return from interrupt

rotateplayer:
  lda buttons
  and #%00000001
  beq plleftturn
  ; right is down
  lda playerrottimer
  clc
  adc #TURNSPEED
  sta playerrottimer
  bcc plleftturn
  ; rotation thing rolled over
  jsr plrotateright ; deal with it in this subroutine or whatever it's called
plleftturn:
  lda buttons
  and #%00000010
  beq plturnend
  ; left is down
  lda playerrottimer
  sec
  sbc #TURNSPEED
  sta playerrottimer
  bcs plturnend
  ; rotation thing rolled over
  jsr plrotateleft
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

moveplayer:
  ; idea here is to adjust x/y to show which directions we need to move
  ; 0 = negative movement, 1 = no movement, 2 = positive movement
  ; this is awful i should figure out how negatives work if they even do natively
  ldx #$01 ; net x movement
  ldy #$01 ; net y movement
  lda buttons
  and #%00001100
  beq mplend ; no movement buttons are held
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
  beq mplforwardcheck
  iny
mplforwardcheck:
  lda buttons
  and #%00001000 ; forward
  beq mplbackwardcheck
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
  bne mplbackwardcheck
  inc playery
mplbackwardcheck:
  lda buttons
  and #%00000100 ; backward
  beq mplend
  ; todo: implement backwards once I figure out how to do it well
mplend:
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
  .db $0f,$2D,$27,$30,  $15,$30,$1a,$09,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ; background palette
  .db $0c,$1C,$15,$14,  $22,$21,$15,$30,  $39,$1C,$15,$14,  $22,$02,$38,$3C   ; sprite palette

sprites:
  .db $10,SPRITECARBASE,$01,$80 ; $0200

; background stuff
nametable:
  .db $fa,$fa,$f9,$f9,$fa,$fa,$fa,$fa,$fa,$f9,$fa,$fa,$f9,$fa,$fa,$fa
  .db $fa,$fa,$fa,$f9,$fa,$fa,$fa,$fa,$fa,$f9,$fa,$fa,$fa,$fa,$fa,$fa

  .db $f9,$fa,$fa,$fa,$fa,$fa,$fa,$e7,$fb,$fb,$fb,$fb,$fb,$fb,$fb,$fb
  .db $fb,$fb,$fb,$fb,$fb,$fa,$fa,$f9,$fa,$fa,$fa,$fa,$fa,$fa,$f9,$fa

  .db $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fc,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
  .db $ff,$ff,$ff,$ff,$ff,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88

  .db $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fc,$ff,$ff,$fd,$fd,$fd,$fd,$fd,$fd
  .db $fd,$fd,$fd,$fd,$fd,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88

  .db $fa,$fa,$fa,$fa,$fa,$fa,$fa,$fc,$ff,$fe,$ff,$ff,$ff,$ff,$ff,$ff
  .db $ff,$ff,$ff,$ff,$ff,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88,$88

attribute:
  ; order of bits: BOTTOMLEFT | BOTTOMRIGHT | TOPRIGHT | TOPLEFT 
  .db %01010101,%01010101,%00000101,%00000101,%00000101,%00000101,%00000101,%00000101
  .db %00000101,%00000101,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000

; direction bit layout
; R L U D
; 0 0 0 0
directions:
  ;    U   UR  R  RD   D  LD  L    LU
  .db $02,$0a,$08,$09,$01,$05,$04,$06

  .org $FFFA
  .dw NMI ; label to jump to on nmi
  .dw RESET
  .dw 0 ; not using irq
  
  
;;;;;;;;;;;;;;  
  .bank 2
  .org $0000
  .incbin "sprites.chr"