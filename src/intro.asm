; intro splash screen thing

introtimer    = $05
introloadlow  = $03
introloadhigh = $04

startintrostate:
  jsr disablenmi
  lda #STATE_INTRO
  sta gamestate
  sta introtimer

  jsr loadintrostuff

  jsr enablenmi
  rts

dointrostate:
  jsr enablenmi
  lda introtimer
  clc
  adc #$02
  sta introtimer
  sta $0203
  cmp #$f9 ; wait 255 frames
  bcc disnochange
  jsr startmenustate
disnochange:
  jmp nmiend

loadintrostuff:
  lda #LOW(introscreen)
  sta introloadlow
  lda #HIGH(introscreen)
  sta introloadhigh
  lda $2002
  lda #$20
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
  ldy #$00
loadintrobgl1:
loadintrobgl2:
  lda [introloadlow], y
  sta $2007

  iny ; loop2

  cpy #$00
  bne loadintrobgl2 ; keep going til y wraps around to 0
  inc introloadhigh
  inx
  cpx #$04
  bne loadintrobgl1
  ; load the car sprite to move across the screen
  lda #$2a
  sta $0200
  lda #$09
  sta $0201
  lda #%01000001 ; flip horizontally
  sta $0202
  lda #$00
  sta $0203
  rts