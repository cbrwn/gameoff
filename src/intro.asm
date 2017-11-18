introtimer = $00

startintrostate:
    jsr disablenmi
    lda #$00
    sta gamestate
    sta introtimer

    jsr enablenmi
    rts

dointrostate:
    lda introtimer
    clc
    adc #$01
    sta introtimer
    cmp #$78 ; 2 secs
    bne disnochange
    jsr startgamestate
disnochange:
    rti