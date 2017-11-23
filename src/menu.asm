; main menu

DIFFICULTYCOUNT  = $03
LAPSELECTCOUNT   = $03
TRACKSELECTCOUNT = $03

SELECTIONTILEHIGH = $22
DIFFICULTYSTRINGLENGTH = $06
DIFFICULTYLABELLOW  = $73
DIFFICULTYLABELHIGH = $22
LAPLABELLOW  = $B3
LAPLABELHIGH = $22
TRACKLABELLOW  = $33
TRACKLABELHIGH = $22

selectindex  = $02
menuloadlow  = $03
wasbuttondwn = $03 ; use the same address cos menuload is only used for loading
menuloadhigh = $04

trackselectindex = $04
diffselectindex  = $05
diffselectvalue  = $0a
lapselectindex   = $06
lapselectvalue   = $09

diftextlow = $07
diftexthigh = $08

startmenustate:
  jsr disablenmi

  jsr clearsprites
  jsr loadmenustuff

  lda #STATE_MENU
  sta gamestate

  lda #$00
  sta selectindex
  sta lapselectindex
  sta trackselectindex
  ldy #$00
  lda lapselections, y
  sta lapselectvalue

  lda #$01
  ldy #$01
  sta wasbuttondwn
  sta diffselectindex
  lda speedselections, y
  sta diffselectvalue

  jsr enablenmi
  rts

domenustate:

  jsr updateselectindicator
  jsr updatedifficultylabel
  jsr updatelapselectlabel
  jsr updatetrackselectlabel

  jsr enablenmi

  jsr menuselectionchange
  jsr menuactions
  
  lda wasbuttondwn
  bne nostartgame
  lda buttons
  and #%00010000
  beq nostartgame
  jmp startgame
nostartgame:

  jsr buttonpresscheck

  jmp nmiend

startgame:
  ; apply all the selections and start the game
  ; lap count
  lda lapselectvalue
  sta maxlap
  ; drive speed
  ldx diffselectindex
  lda speedselections, x
  sta drivespeed

  ; set label positions
  lda #LOW(tracklabels)
  sta diftextlow
  lda #HIGH(tracklabels)
  sta diftexthigh
  jsr setyforlabelsetup
  jsr loadlabelpositions

  ; set background address locations
  lda #LOW(trackbgoffsets)
  sta diftextlow
  lda #HIGH(trackbgoffsets)
  sta diftexthigh
  jsr setyforbackgroundsetup
  jsr loadbackgroundaddresses

  ; set wall address locations
  lda #LOW(trackwalloffsets)
  sta diftextlow
  lda #HIGH(trackwalloffsets)
  sta diftexthigh
  jsr setyforbackgroundsetup
  jsr loadwalladdresses

  ; set number of walls
  lda #LOW(trackwallcounts)
  sta diftextlow
  lda #HIGH(trackwallcounts)
  sta diftexthigh
  ldy trackselectindex
  lda [diftextlow], y
  sta trackwallcount

  ; set finish line x position
  ldx trackselectindex
  lda trackfinishlinex, x
  sta finishlinex

  ; set finish line y positions
  lda #LOW(trackfinishliney)
  sta diftextlow
  lda #HIGH(trackfinishliney)
  sta diftexthigh
  jsr setyforbackgroundsetup
  jsr loadfinishlinepositions

  ; set player position
  lda #LOW(trackplayerstarts)
  sta diftextlow
  lda #HIGH(trackplayerstarts)
  sta diftexthigh
  jsr setyforbackgroundsetup
  jsr loadplayerstarts

  jsr startgamestate
  jmp nmiend

loadlabelpositions:
  ; assume diftextlow and diftexthigh are set to the
  ; label of the text positions and y is set to the first value
  lda [diftextlow], y
  sta timertilehigh
  iny
  lda [diftextlow], y
  sta timertilelow
  iny
  lda [diftextlow], y
  sta laptilehigh
  iny
  lda [diftextlow], y
  sta laptilelow
  iny
  lda [diftextlow], y
  sta cdowntilehigh
  iny
  lda [diftextlow], y
  sta cdowntilelow
  rts

loadbackgroundaddresses:
  lda [diftextlow], y
  sta trackbgloadlow
  iny
  lda [diftextlow], y
  sta trackbgloadhigh
  rts

loadwalladdresses:
  lda [diftextlow], y
  sta trackwallloadlow
  iny
  lda [diftextlow], y
  sta trackwallloadhigh
  rts

loadfinishlinepositions:
  lda [diftextlow], y
  sta finishlineytop
  iny
  lda [diftextlow], y
  sta finishlineybot
  rts

loadplayerstarts:
  lda [diftextlow], y
  sta playerx
  iny
  lda [diftextlow], y
  sta playery
  rts

menuactions:
  lda wasbuttondwn
  bne menacend
  lda buttons
  and #%11000011
  beq menacend
  ; was pressed

  lda selectindex
  beq changetrack

  lda selectindex
  cmp #$01
  beq changedifficulty

  lda selectindex
  cmp #$02
  beq changelaps
menacend:
  rts

changetrack:
  inc trackselectindex
  lda trackselectindex
  cmp #TRACKSELECTCOUNT
  bne changetrackend
  lda #$00
  sta trackselectindex
changetrackend:
  jmp menacend

changedifficulty:
  inc diffselectindex
  lda diffselectindex
  cmp #DIFFICULTYCOUNT
  bne changedifend
  lda #$00
  sta diffselectindex
changedifend:
  ldx diffselectindex
  lda speedselections, x
  sta diffselectvalue
  jmp menacend

changelaps:
  inc lapselectindex
  lda lapselectindex
  cmp #LAPSELECTCOUNT
  bne changelapsend
  lda #$00
  sta lapselectindex
changelapsend:
  ; update select value
  ldx lapselectindex
  lda lapselections, x
  sta lapselectvalue
  jmp menacend

menuselectionchange:
  lda wasbuttondwn
  bne mscoverflowend
  lda buttons
  and #%00000100
  beq msccheckup
  ; down pressed
  inc selectindex
  jmp mscend
msccheckup:
  lda buttons
  and #%00001000
  beq mscend
  ; up pressed
  dec selectindex
mscend:
  ; wrap around selection
  lda selectindex
  cmp #$ff
  bne msccheckoverflow
  ; rolled under
  lda #$02
  sta selectindex
msccheckoverflow:
  lda selectindex
  cmp #$03
  bne mscoverflowend
  lda #$00
  sta selectindex
mscoverflowend:
  rts

buttonpresscheck:
  lda buttons
  beq bpcnopressed
  lda #$01
  sta wasbuttondwn
  jmp bpcend
bpcnopressed:
  lda #$00
  sta wasbuttondwn
bpcend:
  rts

; do this simply now but it can be made a lot nicer
setdifficultyeasy:
  lda #HIGH(difstringeasy)
  sta diftexthigh
  lda #LOW(difstringeasy)
  sta diftextlow
  jmp diflabeladdressset

setdifficultymedium:
  lda #HIGH(difstringmedium)
  sta diftexthigh
  lda #LOW(difstringmedium)
  sta diftextlow
  jmp diflabeladdressset

setdifficultyhard:
  lda #HIGH(difstringhard)
  sta diftexthigh
  lda #LOW(difstringhard)
  sta diftextlow
  jmp diflabeladdressset

; sets y to trackindex * 6
setyforlabelsetup:
  ldy #$00
  ldx trackselectindex
  jmp ylabelendofloop
ylabelsetuploop:
  iny
  iny
  iny
  iny
  iny
  iny
  dex
ylabelendofloop:
  cpx #$00
  bne ylabelsetuploop
  rts

; sets y to trackindex * 2
setyforbackgroundsetup:
  ldy #$00
  ldx trackselectindex
  jmp ybgsendofloop
ybgsetuploop:
  iny
  iny
  dex
ybgsendofloop:
  cpx #$00
  bne ybgsetuploop
  rts


updatedifficultylabel:
  lda diffselectindex
  beq setdifficultyeasy

  lda diffselectindex
  cmp #$01
  beq setdifficultymedium

  lda diffselectindex
  cmp #$02
  beq setdifficultyhard

  jmp setdifficultyeasy
diflabeladdressset:
  lda $2002
  lda #DIFFICULTYLABELHIGH
  sta $2006
  lda #DIFFICULTYLABELLOW
  sta $2006
  ldy #$00
diflabelloop:
  lda [diftextlow], y
  sta $2007
  iny
  cpy #DIFFICULTYSTRINGLENGTH
  bne diflabelloop
  rts

updateselectindicator:
  ldx #$00
usiloop:
  lda $2002
  lda #SELECTIONTILEHIGH
  sta $2006
  lda menuselecttiles, x
  sta $2006
  cpx selectindex
  bne usinoarrow
  lda #$2c
  jmp usiapplytile
usinoarrow:
  lda #$fa
  jmp usiapplytile
usiapplytile:
  sta $2007
  inx
  cpx #$03
  bne usiloop
  rts

updatelapselectlabel:
  lda $2002
  lda #LAPLABELHIGH
  sta $2006
  lda #LAPLABELLOW
  sta $2006
  lda lapselectvalue
  sta $2007
  rts

updatetrackselectlabel:
  lda $2002
  lda #TRACKLABELHIGH
  sta $2006
  lda #TRACKLABELLOW
  sta $2006
  lda trackselectindex
  clc
  adc #$01
  sta $2007
  rts

loadmenustuff:  
  lda #LOW(menuscreen)
  sta menuloadlow
  lda #HIGH(menuscreen)
  sta menuloadhigh
  lda $2002
  lda #$20
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
  ldy #$00
loadmenubgl1:
loadmenubgl2:
  lda [menuloadlow], y
  sta $2007

  iny ; loop2

  cpy #$00
  bne loadmenubgl2 ; keep going til y wraps around to 0
  inc menuloadhigh
  inx
  cpx #$04
  bne loadmenubgl1
  rts