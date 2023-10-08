
; F#READY

driver_tmp      .ds 2
driver_mode     .ds 1

paddle_vals = 229
paddle_add  = 287       ; 65536 / 229

            .align $100
paddle_to_256
            .ds $100

; paddle initial value
prev_paddle_value
            .ds 1

; previous mouse value (player 1,2)
prev_mouse_value
            .ds 2

driver_init
            lda #0  ; stick
            sta driver_mode

            sta prev_mouse_value
            sta prev_mouse_value+1

            lda PADDL0
            sta prev_paddle_value

            lda #0
            sta p1_angle
            lda #128
            sta p2_angle

; init paddle table

            lda #0
            sta driver_tmp
            sta driver_tmp+1
            
            ldx #0
store_pv
            lda driver_tmp+1
            sta paddle_to_256,x
            
            lda driver_tmp
            clc
            adc #<paddle_add
            sta driver_tmp
            lda driver_tmp+1
            adc #>paddle_add
            sta driver_tmp+1
            inx
            cpx #paddle_vals
            bne store_pv
            rts

reset_driver_mode
            lda #0
            sta driver_mode     ; reset driver mode
            rts

; stick detect by using left/right
; paddle by connecting/rotate
; mouse controller by movement

; return A = driver mode
; 0 = stick detected
; 1 = paddle detected
; 2 = mouse detected

driver_detect
            lda PADDL0
            cmp #228
            bne paddle_detect
            lda PADDL1
            cmp #228
            beq no_paddle_detect
paddle_detect
            lda #1
            sta driver_mode
            rts

no_paddle_detect
            lda driver_mode
            cmp #2
            beq keep_mouse
            lda STICK0
            cmp #12
            bne no_mouse_detect
            lda #2
            sta driver_mode
keep_mouse
            rts

no_mouse_detect
            cmp #7      ; paddle button also gives this
            beq stick_detect    
            cmp #11     ; paddle button also gives this
            bne no_stick_detect
stick_detect
            lda #0
            sta driver_mode
            rts

no_stick_detect
; default is the last value
            lda driver_mode
            rts

; move player 1/2
; right - clockwise, left = anti-clockwise

; X = 0, player 1
; X = 1, player 2

; A = driver mode:
; 0 : stick
; 1 : paddle
; 2 : mouse
; 3 : computer

main_driver
            ldy driver_mode
            lda driver_lo,y
            sta driver_ptr
            lda driver_hi,y
            sta driver_ptr+1

driver_ptr = *+1
            jmp $ffff  

driver_lo
            dta <driver_stick
            dta <driver_paddle
            dta <driver_mouse
            dta <driver_stick

driver_hi
            dta >driver_stick
            dta >driver_paddle
            dta >driver_mouse
            dta >driver_stick

; joystick driver

driver_stick
            lda STICK0,x
            cmp #15
            beq move_done
            cmp #11
            bne no_left

            lda p1_angle,x
            sec
            sbc stick_slow_speed
            sta p1_angle,x

            lda STRIG0,x
            bne no_fast

            lda p1_angle,x
            sec
            sbc stick_fast_speed
            sta p1_angle,x
no_fast
            
            jmp move_done
no_left     cmp #7
            bne move_done

            lda p1_angle,x
            clc
            adc stick_slow_speed
            sta p1_angle,x

            lda STRIG0,x
            bne no_fast_right

            lda p1_angle,x
            clc
            adc stick_fast_speed
            sta p1_angle,x
no_fast_right
move_done
            rts

; check if player1 button is pressed
; A=0 not pressed, 1=pressed

is_player1_button_pressed
            lda driver_mode
            cmp #1
            beq check_player1_paddle_fire

            lda STRIG0
            beq fire_pressed
            bne fire_not_pressed

check_player1_paddle_fire
            lda STICK0
            cmp #11
            beq fire_pressed
            bne fire_not_pressed

; X=port number to check (paddle uses only port 1)
; check fire button (paddle uses left/right stick as fire button)
; A=0 not pressed, 1=pressed

is_both_buttons
            lda driver_mode
            cmp #1
            beq check_paddle_fire

            lda STRIG0
            bne fire_not_pressed
            lda STRIG1
            bne fire_not_pressed

fire_pressed
            lda #1
            rts

check_paddle_fire
            lda STICK0
            cmp #3
            beq fire_pressed

fire_not_pressed
            lda #0
            rts

; paddle driver
            
driver_paddle            
            lda PADDL0,x
            tay
            lda paddle_to_256,y
            eor paddle_offsets,x
            sta p1_angle,x
            rts

; keyboard driver (always player1)
; not used here, but might come in handy sometime

driver_keyboard
            ldx #0          ; player 1

            lda SKSTAT
            and #4
            bne key_done

still_pressed
            lda KBCODE
            cmp #$16        ; $56 including SHIFT
            bne no_z_key

            lda p1_angle,x
            clc
            adc stick_slow_speed
            sta p1_angle,x

            jmp key_done

no_z_key    cmp #$17        ; $57 including SHIFT
            bne key_done

            lda p1_angle,x
            sec
            sbc stick_slow_speed
            sta p1_angle,x
key_done
            rts

; mouse driver (Atari ST compatible)

driver_mouse
            rts
;            lda STICK0,x
;            eor #15
;            jmp driver_mouse_main

driver_mouse_fast_p1
            lda PORTA
            ldx #0
            jmp driver_mouse_main

driver_mouse_fast_p2
            lda PORTA
            lsr
            lsr
            lsr
            lsr
            ldx #1
; have to call this many times per frame for each player
driver_mouse_main
            and #%00000011
            pha
            ora prev_mouse_value,x
            tay
            pla
            asl
            asl
            sta prev_mouse_value,x  ; store previous bits at 0000AA00 position for next time

            lda mouse_transitions,y
            adc p1_angle,x
            sta p1_angle,x
            rts

; nibble coded transitions for mouse
; 15,13,12,14 = anti-clockwise
; 15,14,12,13 = clockwise
; only lowest 2 bits change, so we need 16 values for all transitions

; index is the combined value of nibble AABB
; where AA is previous bits and BB current bits
mouse_transitions
            dta 0   ; 00 -> 00 (12 -> 12)
            dta 2   ; 00 -> 01 (12 -> 13)
            dta 254 ; 00 -> 10 (12 -> 14)
            dta 0   ; 00 -> 11 (12 -> 15)
            dta 254 ; 01 -> 00 (13 -> 12)
            dta 0   ; 01 -> 01 (13 -> 13)
            dta 0   ; 01 -> 10 (13 -> 14)
            dta 2   ; 01 -> 11 (13 -> 15)
            dta 2   ; 10 -> 00 (14 -> 12)
            dta 0   ; 10 -> 01 (14 -> 13)
            dta 0   ; 10 -> 10 (14 -> 14)
            dta 254 ; 10 -> 11 (14 -> 15)
            dta 0   ; 11 -> 00 (15 -> 12)
            dta 254 ; 11 -> 01 (15 -> 13)
            dta 2   ; 11 -> 10 (15 -> 14)
            dta 0   ; 11 -> 11 (15 -> 15)

paddle_offsets
            dta 0,0