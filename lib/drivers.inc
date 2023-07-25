; drivers for game
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

driver_init
            lda #0  ; stick
            sta driver_mode

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

; stick detect by using left/right
; paddle by connecting/rotate
; driving controller by rotate

; return A = driver mode
; 0 = stick detected
; 1 = paddle detected
; 2 = driving detected

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
            lda STICK0
            cmp #12
            bne no_driving_detect
            lda #2
            sta driver_mode
            rts

no_driving_detect
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
; 2 : driving
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
            dta <driver_stick
            dta <driver_stick

driver_hi
            dta >driver_stick
            dta >driver_paddle
            dta >driver_stick
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

; X=port number to check (paddle uses only port 1)
; check fire button (paddle uses left/right stick as fire button)
; A=0 not pressed, 1=pressed

is_both_buttons
            lda driver_mode
            cmp #1
            beq check_paddle_fire

            lda STRIG0
            bne not_both_stick
            lda STRIG1
            bne not_both_stick

both_fire
            lda #1
            rts

check_paddle_fire
            lda STICK0
            cmp #3
            beq both_fire

not_both_stick
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

paddle_offsets
            dta 0,0