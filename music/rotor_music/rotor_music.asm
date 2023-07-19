;
; LZSS Compressed SAP player for 16 match bits
; --------------------------------------------
;
; (c) 2020 DMSC
; Code under MIT license, see LICENSE file.
;
; This player uses:
;  Match length: 8 bits  (1 to 256)
;  Match offset: 8 bits  (1 to 256)
;  Min length: 2
;  Total match bits: 16 bits
;
; Compress using:
;  lzss -b 16 -o 8 -m 1 input.rsap test.lz16
;
; Assemble this file with MADS assembler, the compressed song is expected in
; the `test.lz16` file at assembly time.
;
; The plater needs 256 bytes of buffer for each pokey register stored, for a
; full SAP file this is 2304 bytes.
;

SSKCTL = $0232
;RANDOM = $d20a
SKCTL  = $d20f

    org $c0

zp
chn_copy    .ds     9
chn_pos     .ds     9
bptr        .ds     2
cur_pos     .ds     1
chn_bits    .ds     1
bit_data    .byte   1

newsong     .ds     1       ; IVO

stereo_pokey    .ds     1

POKEY = $D200

    org $9800
buffers
    .ds 256 * 9

intro_data
        ins     'intro.lz16'
intro_end

loop_data
        ins     'loop.lz16'
loop_end

.proc get_byte
    lda $1234
    inc song_ptr
    bne skip
    inc song_ptr+1
skip
    rts
.endp
song_ptr = get_byte + 1

start

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Song Initialization - this runs in the first tick:
;
.proc play_first_frame

    jsr get_byte                    ; IVO START move init here
    sta play_frame.init_chn_bits
    lda #1                          ; IVO set to 1 at init(!)
    sta bit_data
    lda #>buffers                   ; IVO reset cbuf+1 pointer
    sta cbuf+2                      ; IVO END

    ; Init all channels:
    ldx #8
    ldy #0
    sty newsong                     ; IVO signal first frame is played
clear
    ; Read just init value and store into buffer and POKEY
    jsr get_byte
    sta SHADOW, x
    sty chn_copy, x
cbuf
    sta buffers + 255
    inc cbuf + 2
    dex
    bpl clear

    ; Initialize buffer pointer:
    sty bptr
    sty cur_pos
    rts                     ; IVO turn into subroutine
.endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Wait for next frame
;
.proc wait_frame

    lda 20
delay
    cmp 20
    beq delay
    rts                     ; IVO turn into subroutine
.endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Play one frame of the song
;
.proc play_frame
    lda newsong
    beq continue
    bne play_first_frame

continue
    ldy cur_pos                 ; IVO

    lda #>buffers
    sta bptr+1

init_chn_bits=*+1
    lda #0              ; IVO: 8 bits, but 9 streams. bug?
    sta chn_bits
    ldx #8

    ; Loop through all "channels", one for each POKEY register
chn_loop:
    lsr chn_bits
    bcs skip_chn       ; C=1 : skip this channel

    lda chn_copy, x    ; Get status of this stream
    bne do_copy_byte   ; If > 0 we are copying bytes

    ; We are decoding a new match/literal
    lsr bit_data       ; Get next bit
    bne got_bit
    jsr get_byte       ; Not enough bits, refill!
    ror                ; Extract a new bit and add a 1 at the high bit (from C set above)
    sta bit_data       ;
got_bit:
    jsr get_byte       ; Always read a byte, it could mean "match size/offset" or "literal byte"
    bcs store          ; Bit = 1 is "literal", bit = 0 is "match"

    sta chn_pos, x     ; Store in "copy pos"

    jsr get_byte
    sta chn_copy, x    ; Store in "copy length"

                        ; And start copying first byte
do_copy_byte:
    dec chn_copy, x     ; Decrease match length, increase match position
    inc chn_pos, x
    ldy chn_pos, x

    ; Now, read old data, jump to data store
    lda (bptr), y

store:
    ldy cur_pos
    sta SHADOW, x        ; Store to output and buffer
    sta (bptr), y

skip_chn:
    ; Increment channel buffer pointer
    inc bptr+1

    dex
    bpl chn_loop        ; Next channel

    inc cur_pos
    rts                 ; IVO once per frame
.endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Check for ending of song and jump to the next frame
;
.proc check_end_song
    lda song_ptr + 1
song_end_high=*+1
    cmp #>0
    bne not_equal           ; IVO turn into subroutine
    lda song_ptr
song_end_low=*+1
    cmp #<0
    bne not_equal           ; IVO turn intro subroutine

    sec                     ; IVO....
    rts
not_equal
    clc
    rts
.endp

; IVO everything below

.proc music_init
    jsr detect_2nd_pokey
    jsr clear_echo

    mwa #normal_volume adjust_volume.volume
;    mwa #half_volume adjust_volume.volume
;    mwa #quarter_volume adjust_volume.volume

    lda #<intro_end
    sta check_end_song.song_end_low
    lda #>intro_end
    sta check_end_song.song_end_high
    lda #<(intro_data)
    sta song_ptr
    lda #>(intro_data)
    sta song_ptr+1
    lda #1
    sta newsong
    rts
.endp

.proc play_song
playloop
    jsr play_frame      ; generates tick two and beyond
    jsr adjust_volume

    jsr check_end_song
    bcc no_end_song
    jsr restart_music
no_end_song
    rts
.endp

.proc restart_music
    lda #<loop_end
    sta check_end_song.song_end_low
    lda #>loop_end
    sta check_end_song.song_end_high
    lda #<(loop_data)
    sta song_ptr
    lda #>(loop_data)
    sta song_ptr+1
    lda #1
    sta newsong
    rts
.endp

.proc adjust_volume
    ldy #6
adjust
    lda SHADOW+1,y
    tax
    and #$f0
    sta SHADOW+1,y
    txa
    and #$0f
    tax
volume=*+1
    lda $1234,x
    ora SHADOW+1,y
    sta SHADOW+1,y
    dey
    dey
    bpl adjust
    
    rts
.endp

.proc copy_shadow
    ldx #8
copy
    lda SHADOW,x
    sta POKEY,x
    dex
    bpl copy

    lda stereo_pokey
    beq end_copy

    ldx #8
copy2
    lda ECHO,x
    sta POKEY+$10,x
    dex
    bpl copy2

    jsr shift_echo

end_copy
    rts
.endp

.proc music_normal_volume
    mwa #normal_volume adjust_volume.volume
    rts
.endp

.proc music_low_volume
    mwa #quarter_volume adjust_volume.volume
    rts
.endp

.proc detect_2nd_pokey
    jsr wait_frame

    mva #0 SSKCTL
    mva #0 SKCTL
    mva #0 SKCTL+$10        ; make sure a potential 2nd pokey is cleared

    jsr wait_frame

    ; Restart SKCTL. This starts all the poly counters

    mva #3 SSKCTL
    mva #3 SKCTL

    jsr wait_frame

    ; Except when there's a seconds pokey!! Its counters are not restarted.
    ; Its RANDOM should not change.

    lda RANDOM+$10
    cmp RANDOM+$10
    beq detected_stereo         ; so equal means there's a 2nd pokey

detected_mono
    mva #0 stereo_pokey
    rts

detected_stereo
    mva #1 stereo_pokey
    mva #3 SKCTL+$10            ; start second pokey here
    rts
.endp

.proc clear_echo
    ldy #(endecho-echobuffer)-1
clear_echo_loop
    mva #0 echobuffer,y
    dey:bpl clear_echo_loop
    rts
.endp

.proc shift_echo
    ldy #(ECHO-echobuffer)-1+9
shift_loop
    mva SHADOW,y SHADOW+9,y
    dey:bpl shift_loop
    rts
.endp

SHADOW              ; shadow pokey
:9 .db 0

                    ; fake stereo effect:
                    ; 0*9 = small
                    ; 1*9 = medium
                    ; 2*9 = big
                    ; >3 too big imho

echobuffer
    .ds 1*9        ; total of echobuffer+ECHO MUST NOT exceed 128 bytes

ECHO
    .ds 9
endecho

normal_volume
    dta 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
half_volume
    dta 0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,7
quarter_volume
    dta 0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,4
