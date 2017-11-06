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
SPRITEHEADBASE = $00 ; start of head sprites
SPRITEHATBASE  = $04 ; start of hat brim sprites
PLAYERSPRITE1  = $0200
PLAYERSPRITE2  = $0204

  .rsset $0000
buttons   .rs 1

playerx   .rs 1
playery   .rs 1
playerdir .rs 1

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

LoadSprites:
  ldx #$00
LoadSpritesLoop:
  lda sprites,x
  sta  $0200,x
  inx
  cpx #$08
  bne LoadSpritesLoop

  jsr enablenmi

  ; initialize variables and stuff
  lda #$80
  sta playerx
  sta playery
  lda #$00
  sta playerdir

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
  jsr moveplayer

  ; end of nmi
  jsr enablenmi

  RTI        ; return from interrupt

moveplayer:
  ldx playerdir ; grab our current direction in case we don't need to change
  lda buttons
  and #%00001000 ; up
  beq mplcheckdown
  ; up is pressed
  lda playery
  sec
  sbc #PLAYERSPEED
  sta playery
  ldx #$01 ; direction up
mplcheckdown:
  lda buttons
  and #%00000100 ; down
  beq mplcheckleft
  ; down is pressed
  lda playery
  clc
  adc #PLAYERSPEED
  sta playery
  ldx #$03 ; direction down
mplcheckleft:
  lda buttons
  and #%00000010 ; left
  beq mplcheckright
  ; left is pressed
  lda playerx
  sec
  sbc #PLAYERSPEED
  sta playerx
  ldx #$02 ; direction left
mplcheckright:
  lda buttons
  and #%00000001
  beq mplaftermove
  ; right is pressed
  lda playerx
  clc
  adc #PLAYERSPEED 
  sta playerx
  ldx #$00 ; direction right
mplaftermove:
  ; set our direction which we set into the x register
  stx playerdir
  rts

updateplayersprite:
  lda playery
  sta PLAYERSPRITE1 ; set y pos
  sta PLAYERSPRITE2 ; put hat brim at the same position until we change it later
  lda playerx
  ldx #$03 ; offset from sprite address for x position
  sta PLAYERSPRITE1, x
  sta PLAYERSPRITE2, x ; hat brim again

  ; move hat brim based on direction
  ldy playerx
  lda playerdir
  cmp #$00
  beq upsbrimright
  cmp #$02
  beq upsbrimleft
  ldy playery
  cmp #$01
  beq upsbrimtop
  ; move brim down
  tya
  clc
  adc #PLAYERHEIGHT
  sta PLAYERSPRITE2
  jmp upsspritechange
upsbrimtop:
  ; move brim up
  tya
  sec
  sbc #PLAYERHEIGHT
  sta PLAYERSPRITE2
  jmp upsspritechange
upsbrimright:
  ; move brim right
  tya
  clc
  adc #PLAYERWIDTH
  sta PLAYERSPRITE2, x
  jmp upsspritechange
upsbrimleft:
  ; move brim left
  tya
  sec
  sbc #PLAYERWIDTH
  sta PLAYERSPRITE2, x
  jmp upsspritechange
upsspritechange:
  ; sprites based on direction
  lda #SPRITEHEADBASE
  clc
  adc playerdir
  ldx #$01 ; offset from sprite address for tile number
  sta PLAYERSPRITE1, x
  clc
  adc #$04 ; next sprite
  sta PLAYERSPRITE2, x
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
  lda #%10000000
  sta $2000
  lda #%00010000
  sta $2001
  rts
 
;;;;;;;;;;;;;;  
  .bank 1
  .org $E000
palette:
  .db $0f,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ; background palette
  .db $0c,$1C,$15,$14,  $22,$15,$06,$30,  $39,$1C,$15,$14,  $22,$02,$38,$3C   ; sprite palette

sprites:
  .db $10,$01,$01,$80 ; $0200
  .db $09,$05,$01,$80 ; $0204

  .org $FFFA
  .dw NMI ; label to jump to on nmi
  .dw RESET
  .dw 0 ; not using irq
  
  
;;;;;;;;;;;;;;  
  .bank 2
  .org $0000
  .incbin "sprites.chr"   