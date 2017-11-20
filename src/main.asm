  .inesprg 1
  .ineschr 1
  .inesmap 0
  .inesmir 1

;;;;;;;;;;;;;;;
  .bank 0
  .org $C000 

  .rsset $0000
buttons   .rs 1
gamestate .rs 1

  .include "intro.asm"
  .include "race.asm"

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

  jsr startgamestate;startintrostate

  jsr enablenmi

loopsies:
  ; just waiting for nmi
  JMP loopsies

NMI:
  LDA #$00
  STA $2003  ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014  ; set the high byte (02) of the RAM address, start the transfer

  lda gamestate
  cmp #$00
  bne nmistatecheck1
  jmp dointrostate ; branch around this because these are too far away to branch relatively

nmistatecheck1:
  lda gamestate
  cmp #$01
  bne nmistatecheck2
  jmp dogamestate

nmistatecheck2:

  rti ; in case state isn't handled

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

disablenmi: ; (and rendering but whatever)
  lda #$00
  sta $2000 ; no nmi
  sta $2001 ; or rendering
  rts

enablesound:
  lda #%00000001 ; square 1 channel
  sta $4015
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
background:
  .include "map.asm"
  .incbin "map.atr"

introscreen:
  .incbin "introscreen.bin"

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