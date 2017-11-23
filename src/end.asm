; results screen

endscreenlow  = $02
endscreenhigh = $03

lapresultpositionhigh  = $21
lapresultpositionlow   = $4e
timeresultpositionhigh = $21
timeresultpositionlow  = $cc

startendstate:
  jsr disablenmi
  
  lda #STATE_END
  sta gamestate
  jsr loadendstuff

  jsr enablenmi
  rts

doendstate:
  jsr enablenmi
  lda buttons
  and #%00010000
  beq desnostart
  jsr startmenustate
desnostart:
  jmp nmiend

loadendstuff:
  jsr clearsprites

  lda #LOW(endscreen)
  sta endscreenlow
  lda #HIGH(endscreen)
  sta endscreenhigh
  lda $2002
  lda #$20
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
  ldy #$00
loadendbgl1:
loadendbgl2:
  lda [endscreenlow], y
  sta $2007

  iny ; loop2

  cpy #$00
  bne loadendbgl2
  inc endscreenhigh
  inx
  cpx #$04
  bne loadendbgl1

  ; set result labels
  ; lap count
  lda $2002 ; start listening for address
  lda #lapresultpositionhigh
  sta $2006
  lda #lapresultpositionlow
  sta $2006
  lda currentlap
  sta $2007

  ; time label
  lda $2002
  lda #timeresultpositionhigh
  sta $2006
  lda #timeresultpositionlow
  sta $2006
  lda timer100
  sta $2007
  lda timer10
  sta $2007
  lda timer1
  sta $2007

  rts