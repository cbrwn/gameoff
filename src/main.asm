  .inesprg 1
  .ineschr 1
  .inesmap 0
  .inesmir 1

;;;;;;;;;;;;;;;
  .bank 0
  .org $C000 

STATE_INTRO = $00
STATE_MENU  = $01
STATE_RACE  = $02
STATE_END   = $03

  .rsset $0000
buttons   .rs 1
gamestate .rs 1

  .include "intro.asm"
  .include "race.asm"
  .include "end.asm"
  .include "menu.asm"

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
  INX
  BNE clrmem

  jsr clearsprites
   
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

  jsr startintrostate

  jsr enablenmi

loopsies:
  ; just waiting for nmi
  JMP loopsies

NMI:
  LDA #$00
  STA $2003  ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014  ; set the high byte (02) of the RAM address, start the transfer

  ; read inputs
  jsr readcontroller

  lda gamestate
  cmp #STATE_INTRO
  beq nintro

  lda gamestate
  cmp #STATE_MENU
  beq nmenu

  lda gamestate
  cmp #STATE_RACE
  beq ngame

  lda gamestate
  cmp #STATE_END
  beq nend
  
nmiend:
  rti ; in case state isn't handled

  ; set a bunch of labels here so we can branch to the states while in range
nintro:
  jmp dointrostate

ngame:
  jmp dogamestate

nend:
  jmp doendstate

nmenu:
  jmp domenustate

waitvblank:
  bit $2002
  bpl waitvblank
  rts

clearsprites:
  ldx #$00
  lda #$FE
clearspriteloop:
  sta $0200, x
  inx
  cpx #$00
  bne clearspriteloop
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

disablenmi: ; (and rendering but whatever)
  lda #$00
  sta $2000 ; no nmi
  sta $2001 ; or rendering
  rts

enablesound:
  lda #%00000001 ; square 1 channel
  sta $4015
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
 
;;;;;;;;;;;;;;  
  .bank 1
  .org $E000
palette:
  .db $0f,$2D,$27,$30,  $15,$30,$1a,$09,  $0c,$00,$0f,$30,  $22,$27,$17,$0F   ; background palette
  .db $15,$1C,$15,$14,  $22,$21,$15,$30,  $39,$1C,$15,$14,  $22,$02,$38,$3C   ; sprite palette

sprites:
  .db $10,SPRITECARBASE,$01,$80 ; $0200

menuselecttiles: ; low bytes of the tiles corresponding to the menu indicator position
  .db $26,$66,$a6

lapselections:
  .db $03,$06,$09

speedselections:
  .db $90,$b0,$f0

; difficulty strings
difstringeasy:
  ;    E   A   S   Y  N/A N/A
  .db $15,$11,$23,$29,$fa,$fa

difstringmedium:
  ;    M   E   D   I   U   M
  .db $1d,$15,$14,$19,$25,$1d

difstringhard:
  ;    H   A   R   D  N/A N/A
  .db $18,$11,$22,$14,$fa,$fa

; background stuff
introscreen:
  .incbin "introscreen.bin"

endscreen:
  .incbin "endscreen.bin"

menuscreen:
  .incbin "menuscreen.bin"

; direction bit layout
; R L U D
; 0 0 0 0
directions:
  ;    U   UR  R  RD   D  LD  L    LU
  .db $02,$0a,$08,$09,$01,$05,$04,$06

; track stuff

; track backgrounds
track1background:
  .incbin "racetrack1.bin"

track2background:
  .incbin "racetrack2.bin"

trackbgoffsets:
  .db LOW(track1background), HIGH(track1background)
  .db LOW(track2background), HIGH(track2background)

; track walls
track1walls:
  ; left, top, right, bottom
  .db $31, $30, $90, $7f
  .db $61, $65, $a0, $be
  .db $99, $af, $d0, $be
  .db $89, $50, $d0, $6f
  .db $0a, $a0, $40, $e7
  .db $c1, $8f, $f0, $9f
  .db $b1, $01, $f0, $2f

track2walls:
  .db $32, $31, $3f, $8e
  .db $32, $31, $bf, $3e
  .db $b2, $41, $cf, $7e
  .db $b2, $31, $bf, $9e
  .db $92, $91, $bf, $9e
  .db $92, $91, $af, $be
  .db $62, $61, $8f, $6e
  .db $62, $61, $6f, $de
  .db $00, $b1, $6f, $de
  .db $d2, $c1, $fb, $fb
  .db $e2, $91, $fb, $fb
  .db $d2, $00, $fb, $1e

trackwalloffsets:
  .db LOW(track1walls), HIGH(track1walls)
  .db LOW(track2walls), HIGH(track2walls)

trackwallcounts:
  ; track1, track2
  .db $07, $0c

tracklabels:
  ;   timer high, timer low, lap high, lap low, countdown high, cdown low
  .db $23, $21, $23, $61, $21, $d0 ; track 1
  .db $23, $23, $23, $63, $23, $48 ; track 2

trackfinishlinex:
  ; track1, track2
  .db $92, $7f

trackfinishliney:
  .db $bd, $df ; track 1 top,bot
  .db $0d, $2f ; track 2 top,bot

trackplayerstarts:
  .db $80, $ca ; track 1 x,y
  .db $70, $15 ; track 2 x,y

  .org $FFFA
  .dw NMI ; label to jump to on nmi
  .dw RESET
  .dw 0 ; not using irq
  
  
;;;;;;;;;;;;;;  
  .bank 2
  .org $0000
  .incbin "sprites.chr"