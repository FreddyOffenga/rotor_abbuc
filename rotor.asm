; R O T O R (II)

; F#READY, 2023-10-16
; Version 2.5.1
; For cartridge release

; - added more gradual levels (level 1 - 7)
; - added single player support (against robot)
; - added demo mode
; - added support for Atari mouse
; - added autostart demo after about 2 minutes

; Main idea:
; - two players ONE and TWO move in a circle
; - the ball gets color of player to indicate who should catch it
; - when the ball hits the circle, the other player gets a point

            icl 'lib/labels.inc'

; color scheme
BASE_COLOR_P1   = $50   ; purple
BASE_COLOR_P2   = $b0   ; green

HEADER_FG_COLOR = 14
HEADER_P1_COLOR = BASE_COLOR_P1
HEADER_P2_COLOR = BASE_COLOR_P2

; must be in decimal format, so $11 is 11
MAX_SCORE   = $11

pm_area     = $0c00
msl_area    = pm_area+$180
p0_area     = pm_area+$200
p1_area     = pm_area+$280
p2_area     = pm_area+$300
p3_area     = pm_area+$380

; outer tables 256 for 360 degrees
outer_x_256     = $1000
outer_y_256     = $1100

screen_y_lo     = $1200
screen_y_hi     = $1300

pm_shape_lo     = $1400 ; 128 bytes
pm_shape_hi     = $1480 ; 128 bytes

WIDTH           = 320
HEIGHT          = 192

SCREEN_WIDTH    = 40

outer_x_margin  = 48 ;47-32
inner_x_margin  = 64

circle_center_x = WIDTH/2
circle_center_y = HEIGHT/2

ball_top_margin     = 6
ball_left_margin    = 64+5

; pm upper margin
upper_margin    = 1
left_margin     = 32

music_toggle    = $80

shadow_HPOSP0   = $81
shadow_HPOSP1   = $82

winner_color    = $83

shape_ptr       = $84
tmp_screen      = $86

stick_slow_speed = $88
stick_fast_speed = $89

player_mode     = $8a
MODE_2_PLAYER   = 0
MODE_1_PLAYER   = 1
MODE_DEMO       = 2
NR_OF_PLAYER_MODES = 3
INIT_PLAYER_MODE = MODE_2_PLAYER

player_mode_saved = $8b

game_state      = $8c
STATE_IN_GAME   = 0
STATE_IN_MENU   = 1
STATE_IN_END    = 2

volume_hit_bat  = $8d
volume_hit_edge = $8e

end_screen_delay = $8f

; player vars must be in sequence for zp,x indexing

p1_shape        = $90
p2_shape        = $91

player1_x       = $94
player2_x       = $95

player1_y       = $98
player2_y       = $99

p1_angle        = $9c
p2_angle        = $9d

mp_collision    = $a0
in_collision    = $a1
player_nr_hit   = $a2       ; which player hit the ball? 1=player1, 2=player2
edge_delay      = $a3
bat_collision_delay = $a4

; ball vars
ball_current_x      = $a6
ball_current_y      = $a7
ball_angle_start    = $aa
ball_angle_end      = $ab
ball_speed          = $ac

edge_collision      = $ad
edge_hit_count      = $ae

tmp_angle1          = $b0
tmp_angle2          = $b1
add_to_angle        = $b2
angle_diff_bat      = $b3
tmp_angle_direction = $b4
player_turn         = $b5       ; who's turn to hit ball? 1=player1, 2=player2
game_restart        = $b6
tmp_angle_diff      = $b7
magnitude           = $b8       ; word

robot_angle_end     = $ba       ; 2 bytes
robot1_angle_end    = robot_angle_end
robot2_angle_end    = robot_angle_end+1

; $c0 - $df free for music

_divisor    = $e0   ; word
_dividend   = $e2   ; word
_remainder  = $e4   ; word
_result     = _dividend         ; save memory by reusing divident to store the result

tmp_x1      = $e6   ; byte
tmp_y1      = $e7   ; byte
tmp_x2      = $e8   ; byte
tmp_y2      = $e9   ; byte

current_x   = $ea  ; word  8.8 fixed point
current_y   = $ec  ; word  8.8 fixed point

step_x      = $ee  ; word  8.8 fixed point
step_y      = $f0  ; word  8.8 fixed point

tmp_dx      = $f2  ; byte
tmp_dy      = $f3  ; byte

_multiplicand   = $f6   ; word
_multiplier     = $f8   ; byte

; direction:
; 0 : x1<x2 or y1<y2 = add
; 1 ; x1>=y2 or y1>=y2 = subtract

dir_x       = $fa  ; byte
dir_y       = $fb  ; byte

line_end_x  = $fc  ; byte
line_end_y  = $fd  ; byte

            icl 'intro.asm'

; real data is loaded at $2000 ($1700+$900)
            org $1700
            icl 'music\rotor_music\rotor_music.asm'

            icl 'lib/drivers.inc'       

reset_pressed
            jsr intro_main

main
            lda #255
            sta 764

; for fast loaders, wait 10 seconds or continue with spacebar
wait_a_sec
            lda 764
            cmp #255
            bne any_key_pressed

            lda 19
            cmp #2
            bcc wait_a_sec

any_key_pressed
            lda #255
            sta 764

; start the game!
 
            lda #0
            sta SDMCTL
            sta game_restart
            sta end_screen_delay
            sta winner_color

            lda #128
            sta volume_hit_bat
            sta volume_hit_edge
            sta music_toggle        ; 128 = on, 0 = off

            lda #1
            sta 580 ; coldstart

;            lda #1
;            sta 9   ; boot

;            lda #<reset_pressed
;            sta $0a
;            lda #>reset_pressed
;            sta $0b

            jsr driver_init

            jsr make_shape_index

            jsr make_outer_256

            jsr make_screen_y_tab

            jsr invert_backdrop
            lda #$60
            sta invert_backdrop ; dirty hack to fix warm reset :P

            jsr reset_score
            jsr show_score_p1
            jsr show_score_p2

            jsr init_sprites
            jsr init_colors

; init. game vars
            ldx #INIT_LEVEL_INDEX
            stx current_level_index
            jsr set_level_ball_speed

            lda #INIT_PLAYER_MODE
            sta player_mode
            sta player_mode_saved
            jsr show_player_mode

            lda #STATE_IN_MENU
            sta game_state           ; start with menu

            jsr music_init

            jsr show_menu_options

            jsr reset_autostart_demo

            lda #<display_list
            sta SDLSTL
            lda #>display_list
            sta SDLSTH

; start vbi

            lda #$c0
            sta NMIEN

            lda #7          ; sets VVBLKI
            ldy #<vbi
            ldx #>vbi
            jsr $e45c       ; SETVBV

wait_mouse
            lda driver_mode
            cmp #2
            bne wait_mouse

            lda player_mode
            cmp #MODE_1_PLAYER
            beq single_driver
            jsr driver_mouse_fast_p2
single_driver
            jsr driver_mouse_fast_p1

            jmp wait_mouse

;------------------------
; 8bit * 8bit = 16bit multiply
; By White Flame
; Multiplies _multiplicand by _multiplier and stores result in .A (low byte, also in .X) and .Y (high byte)
; uses extra zp var _multiplicand+1

; .X and .Y get clobbered.  Change the tax/txa and tay/tya to stack or zp storage if this is an issue.
;  idea to store 16-bit accumulator in .X and .Y instead of zp from bogax

; In this version, both inputs must be unsigned
; Remove the noted line to turn this into a 16bit(either) * 8bit(unsigned) = 16bit multiply.

_multi8
            lda #$00
            tay
            ;sty _multiplicand+1          ; remove this line for 16*8=16bit multiply
            beq _enter_loop
_do_add
            clc
            adc _multiplicand
            tax

            tya
            adc _multiplicand+1
            tay
            txa
_mul_loop
            asl _multiplicand
            rol _multiplicand+1
_enter_loop                     ; accumulating multiply entry point (enter with .A=lo, .Y=hi)
            lsr _multiplier
            bcs _do_add
            bne _mul_loop
            rts

; reset PM0/1 to playfield settings
dli_header
            pha

            lda #8
            sta COLPF1

            lda shadow_HPOSP0
            sta HPOSP0
            lda shadow_HPOSP1
            sta HPOSP1

            lda #0
            sta SIZEP0
            sta SIZEP1

            lda #BASE_COLOR_P1+10
            sta COLPM0
            lda #BASE_COLOR_P2+10
            sta COLPM1

            lda #<dli_menu
            sta VDSLST
            lda #>dli_menu
            sta VDSLST+1

            txa
            pha
            tya
            pha

            jsr copy_shadow
            lda music_toggle
            beq skip_music
            jsr play_song
skip_music

            pla
            tay
            pla
            tax

            pla
            rti

dli_menu
            pha
            txa
            pha

            lda #$0e
            sta WSYNC
            sta COLBK
            lda #$0a
            sta WSYNC
            sta COLBK
            lda #0
            sta WSYNC
            sta COLBK

            ldx #0
color_it1
            lda menu_colpf2,x
            sta WSYNC
            sta COLPF2
            inx
            cpx #18
            bne color_it1

            ldx #0
color_it2
            lda menu_colpf0,x
            ora winner_color
            sta WSYNC
            sta COLPF0
            inx
            cpx #38
            bne color_it2

            lda #0
            sta WSYNC
            sta COLBK
            lda #$0a
            sta WSYNC
            sta COLBK
            lda #$0e
            sta WSYNC
            sta COLBK
            lda #0
            sta WSYNC
            sta COLBK
            
            pla
            tax
            pla
            rti

menu_colpf2
            dta BASE_COLOR_P1
            dta BASE_COLOR_P1
            dta BASE_COLOR_P1
            dta BASE_COLOR_P1
            dta BASE_COLOR_P1
            dta BASE_COLOR_P1
            dta BASE_COLOR_P1
            dta BASE_COLOR_P1

            dta BASE_COLOR_P2
            dta BASE_COLOR_P2
            dta BASE_COLOR_P2
            dta BASE_COLOR_P2
            dta BASE_COLOR_P2
            dta BASE_COLOR_P2
            dta BASE_COLOR_P2
            dta BASE_COLOR_P2

            dta 0,0

menu_colpf0
;            dta 0,0,$28,$28,$2a,$2a,$2c,$2c
;            dta $7c,$7c,$7a,$7a,$78,$78,0,0
            dta 0,0
            dta 0,14,14,12,10,8,6,0
            dta 0,14,14,12,10,8,6,0
            dta 0,14,14,12,10,8,6,0
            dta 0,0,0,0
            dta 0,0,0,0,0,0,0,0

; make pointers from y-position to screen memory
; screen memory is 3 blocks
; screen_mem1 : 102 lines, 4080 bytes
; screen_mem2 : 102 lines, 4080 bytes
; screen_mem3 :  20 lines,  800 bytes

make_screen_y_tab
            lda #<screen_mem1
            sta tmp_screen
            lda #>screen_mem1
            sta tmp_screen+1

            ldx #0
fill_y_tab1
            jsr store_y_line
            inx
            cpx #102
            bne fill_y_tab1

; x = 102
            lda #<screen_mem2
            sta tmp_screen
            lda #>screen_mem2
            sta tmp_screen+1

fill_y_tab2
            jsr store_y_line
            inx
            cpx #204
            bne fill_y_tab2

            lda #<screen_mem3
            sta tmp_screen
            lda #>screen_mem3
            sta tmp_screen+1

; x = 204
fill_y_tab3
            jsr store_y_line
            inx
            cpx #224
            bne fill_y_tab3
            rts

store_y_line
            lda tmp_screen
            sta screen_y_lo,x
            lda tmp_screen+1
            sta screen_y_hi,x
            
            lda tmp_screen
            clc
            adc #SCREEN_WIDTH
            sta tmp_screen
            lda tmp_screen+1
            adc #0
            sta tmp_screen+1
            rts

; @todo invert backdrop image
; now we have to do it here :P
invert_backdrop
            lda #<screen_mem1
            sta tmp_screen
            lda #>screen_mem1
            sta tmp_screen+1
            
            ldx #16     ; 16 pages = 4K
            jsr do_x_pages
           
            lda #<screen_mem2
            sta tmp_screen
            lda #>screen_mem2
            sta tmp_screen+1
            
            ldx #16     ; 16 pages = 4K
            jsr do_x_pages

            lda #<screen_mem3
            sta tmp_screen
            lda #>screen_mem3
            sta tmp_screen+1
            
            ldx #4     ; 4 pages = 1K
            jsr do_x_pages
            rts

; invert x pages, starting from tmp_screen

do_x_pages
            ldy #0
do_page
            lda (tmp_screen),y
            eor #$ff
            sta (tmp_screen),y
            iny
            bne do_page 

            inc tmp_screen+1
            dex
            bne do_page
            rts

turn_color_ball
            ldx player_turn
            lda color_turn,x
            sta COLOR3
            rts
            
color_turn  dta 0,BASE_COLOR_P1+6,BASE_COLOR_P2+6                           

show_menu_options
            lda #<controller_text
            sta menu_line1_ptr
            lda #>controller_text
            sta menu_line1_ptr+1

            jsr show_player_mode

            lda #<level_text
            sta menu_line3_ptr
            lda #>level_text
            sta menu_line3_ptr+1

            lda #0
            sta winner_color
            rts

show_end_screen
            lda #<empty_text
            sta menu_line1_ptr
            sta menu_line3_ptr
            lda #>empty_text
            sta menu_line1_ptr+1
            sta menu_line3_ptr+1

            lda score_p1
            cmp score_p2
            bcc player_2_wins

            lda #<winner_one_text
            sta menu_line2_ptr
            lda #>winner_one_text
            sta menu_line2_ptr+1

            lda #BASE_COLOR_P1
            sta winner_color
            rts

player_2_wins
            lda #<winner_two_text
            sta menu_line2_ptr
            lda #>winner_two_text
            sta menu_line2_ptr+1

            lda #BASE_COLOR_P2
            sta winner_color

            rts

; A, X, Y are already saved by the OS
vbi
;            lda #$28
;            sta $d01a

; toggle music on/off with spacebar
            lda 764
            cmp #$21
            bne no_spacebar
            lda music_toggle
            eor #128
            sta music_toggle
            bne music_turned_on
            jsr music_off

music_turned_on
            lda #255
            sta 764

no_spacebar
            jsr play_sound_bat
            jsr play_sound_edge

            lda #<dli_header
            sta VDSLST
            lda #>dli_header
            sta VDSLST+1

            lda #%00101110  ; enable P/M DMA
            sta SDMCTL
            lda #0
            sta 77      ; attract off
            lda #>rotor_font
            sta 756

            lda #$30
            sta HPOSP0
            lda #$b0
            sta HPOSP1

; menu switching thingy

            lda CONSOL
            cmp #3  ; option button
            bne no_option_pressed
            lda game_state
            cmp #STATE_IN_MENU
            beq check_game_state

; prevent menu option directly after leaving in-game state
            lda #3
            sta previous_consol

go_menu_mode
            jsr wipe_ball

            jsr music_normal_volume

            jsr switch_to_menu

            jmp check_game_state

no_option_pressed
            cmp #6  ; start pressed
            bne check_autostart
            jsr is_driver_unknown
            beq check_autostart
            bne reset_game

check_autostart
; check autostart state

            lda autostart_demo
            beq check_game_state

; reset game

reset_game
            jsr music_low_volume

            jsr wipe_ball

            jsr reset_robot_angle_end

            lda #1
            sta game_restart

            jsr reset_autostart_demo

            lda #STATE_IN_GAME
            sta game_state

check_game_state
            lda game_state
            bne no_main_game_state
            jmp main_game_vbi

no_main_game_state
            cmp #STATE_IN_END
            bne menu_vbi

; end screen vbi
            lda end_screen_delay
            bne stay_in_end_screen

            jsr restart_music
            jsr music_normal_volume

            jsr switch_to_menu

            jmp menu_vbi

stay_in_end_screen
            jsr play_sound_end_game
            dec end_screen_delay
            jmp wait_depressed

switch_to_menu
            lda player_mode_saved
            sta player_mode

            jsr show_menu_options

            jsr reset_driver_mode

            lda #STATE_IN_MENU
            sta game_state
            rts

; demo autostart

autostart_demo  dta 0
autostart_timer dta 0,0

reset_autostart_demo
            lda #0
            sta autostart_demo      ; do not start again
            sta autostart_timer
            lda #30                 ; N * 5 seconds (roughly)
            sta autostart_timer+1
            rts

handle_autostart_timer
            lda autostart_timer
            ora autostart_timer+1
            beq idle_timer
            dec autostart_timer
            bne running_timer
            dec autostart_timer+1
            bne running_timer

; timer reached zero
            lda #1
            sta autostart_demo
            lda player_mode
            sta player_mode_saved
            lda #2
            sta player_mode

running_timer
idle_timer
            rts

is_driver_unknown
            lda driver_mode
            cmp #3
            rts

; within menu vbi

menu_vbi
            jsr handle_autostart_timer

            lda player_mode
            beq check_human_buttons

            jsr is_player1_button_pressed
            beq check_consol_buttons
            jsr is_driver_unknown
            beq check_consol_buttons
            jmp reset_game

check_human_buttons
            jsr is_both_buttons
            beq check_consol_buttons
            jsr is_driver_unknown
            beq check_consol_buttons
            jmp reset_game

check_consol_buttons
            lda CONSOL
            cmp #5          ; select
            bne no_level_select
            
            lda previous_consol
            cmp #5
            beq wait_depressed

            jsr increase_level
            ldx current_level_index
            jsr set_level_ball_speed

            lda #5
            sta previous_consol
            jmp wait_depressed

no_level_select
            cmp #3          ; option
            bne no_player_mode_select

            lda previous_consol
            cmp #3
            beq wait_depressed

            jsr increase_player_mode
            jsr show_player_mode

            lda #3
no_player_mode_select
            sta previous_consol

wait_depressed
            lda #1      ; dl jump
            sta menu_dl_hook
            lda #<menu_dl_part
            sta menu_dl_hook+1
            lda #>menu_dl_part
            sta menu_dl_hook+2

; detect/show controller type (used for both players)
            jsr detect_show_driver

            lda player_mode
            cmp #MODE_2_PLAYER
            beq no_robot_in_menu

            cmp #MODE_1_PLAYER
            beq one_robot_in_menu
; demo mode, both robots in menu
            lda p1_angle
            cmp robot1_angle_end
            bne robot1_moves_to_goal

            lda RANDOM
            sta robot1_angle_end

robot1_moves_to_goal
one_robot_in_menu
            lda p1_angle
            eor #128
            sta robot2_angle_end

no_robot_in_menu
            jsr handle_player1
            jsr handle_player2

            jmp exit_vbi

; X = port/driver to detect
detect_show_driver
            jsr driver_detect
            tay
            lda driver_text_lo,y
            sta tmp_screen
            lda driver_text_hi,y
            sta tmp_screen+1

            ldy #7
show_driv
            lda (tmp_screen),y
            sta driver_screen,y
            dey
            bpl show_driv
            rts

; main game vbi
main_game_vbi
            lda game_restart
            beq no_restart

; restart game

            jsr silence_end

            lda #0
            sta game_restart
            
            jsr reset_score
            jsr show_score_p1
            jsr show_score_p2

            ldx p1_angle
            stx ball_angle_start
            jsr ball_to_start_position
            jsr prepare_ball_end_position

            lda #0
            sta mp_collision
            sta in_collision
            sta edge_delay
            sta edge_collision
            sta edge_hit_count
            sta HITCLR

            lda #2
            sta player_turn

            jsr turn_color_ball
            jmp exit_vbi

no_restart
; remove menu hook
            lda #$0f        ; dl gfx 8
            sta menu_dl_hook
            sta menu_dl_hook+1
            sta menu_dl_hook+2

            lda M0PL
            sta mp_collision
            lda M1PL
            ora mp_collision
            sta mp_collision

            lda M0PF
            sta edge_collision
            lda M1PF
            ora edge_collision
            sta edge_collision
;           beq no_edge_collision

;            inc edge_hit_count
;            lda edge_hit_count
;            cmp #2
;            bcc edge_hit_counting

;            sei
;lalala      jmp lalala

;no_edge_collision
;            lda #0
;            sta edge_hit_count

edge_hit_counting
            jsr handle_player1
            jsr handle_player2

; handle ball

            jsr wipe_ball         

; Check ball collision with bat

            lda bat_collision_delay
            beq check_allowed
            dec bat_collision_delay
            jmp move_one

check_allowed
            lda mp_collision
            beq reset_in_collision

            lda in_collision
            bne no_first_hit

            inc in_collision            
            jsr bounce_bat_ball 
            
            jsr start_sound_bat          
            
            jmp move_one
            
reset_in_collision
            lda #0
            sta in_collision        

move_one
no_first_hit
            jsr move_current_xy

            lda edge_collision
            beq still_moving

; edge detected

edge_detected
            jsr start_sound_edge

            lda ball_angle_end
            sta ball_angle_start

            jsr ball_current_to_start_position
            jsr prepare_ball_end_position

            jsr update_score
            bne game_ends

; switch turns
            lda player_turn
            eor #3              ; 1 => 2, 2 => 1
            sta player_turn
            jsr turn_color_ball
            jsr set_robot_angle_end

still_moving
            lda current_x+1
            sta ball_current_x
            lda current_y+1
            sta ball_current_y

            jsr show_ball

            lda #0
            sta $d018           

; anything in A to clear collisions
            sta HITCLR

exit_vbi

; always set header stuff
            lda #3
            sta SIZEP0
            sta SIZEP1

; background in PM0/1 for header
            lda #255
            ldx #7
fill_pm_header
            sta p0_area,x
            sta p1_area,x
            dex
            bpl fill_pm_header

;            lda #$04
;            sta $d01a
            jmp $e462

game_ends
            lda #255
            sta end_screen_delay

            jsr show_end_screen

            lda #STATE_IN_END
            sta game_state

            jmp exit_vbi

start_sound_bat
            lda #10
            sta volume_hit_bat
            rts

play_sound_end_game
            jsr music_off

            lda end_screen_delay
            cmp #192
            bcc silence_end
            lsr
            and end_screen_delay
            lsr
            ora #$20
            sta SHADOW+4
            ;lda end_screen_delay
            lda #$aa
            sta SHADOW+5
            rts
silence_end
            lda #0
            sta SHADOW+5
            rts

play_sound_bat
            lda volume_hit_bat
            bmi silenced_bat

            lda player_turn
            asl
            asl
            adc #$30
            sbc angle_diff_bat
            sta SHADOW+4    ; $d204
            lda volume_hit_bat
            ora #$a0
            sta SHADOW+5    ; $d205
            dec volume_hit_bat
silenced_bat
            rts

start_sound_edge
            lda #4
            sta volume_hit_edge
            rts

play_sound_edge
            lda volume_hit_edge
            bmi silenced_edge
            bne no_silenced_edge
            sta SHADOW+5    ; $d205
            dec volume_hit_edge
            rts            

no_silenced_edge
            lda #$08
            sta SHADOW+4    ; $d204
            lda volume_hit_edge
            ora #$26
            sta SHADOW+5    ; $d205
            dec volume_hit_edge
silenced_edge
            rts

; Update score
; Score > max score, then exit A = 1, otherwise A = 0

update_score
            lda player_turn
            cmp #1
            bne was_player2_turn
; was player 1 turn, so player 2 gets a point
            jsr inc_score_p2
            jsr show_score_p2

            lda score_p2
            cmp #MAX_SCORE
            bne reset_edge_delay

            lda #STATE_IN_MENU
            sta game_state
            rts

was_player2_turn
            jsr inc_score_p1
            jsr show_score_p1

            lda score_p1
            cmp #MAX_SCORE
            bne reset_edge_delay

            lda #STATE_IN_MENU
            sta game_state
            rts

reset_edge_delay
            lda #10
            sta edge_delay

no_edge

            lda #0      ; no end game
; anything in A to clear collisions
            sta HITCLR
            rts

; player 1
; - wipe shape at previous y-position
; - move player using controller
; - set sprite positions

handle_player1
            jsr wipe_p1         ; wipe previous shape player 1

            lda player_mode
            cmp #2
            beq do_p1_is_computer

            ldx #0              ; player 1
            jsr main_driver
            jsr move_player
            
            jsr show_p1
            rts

; p1 now controlled by computer
do_p1_is_computer
            lda game_state

            ldx #0              ; player 1
            jsr robot_controller

            jsr move_player

            jsr show_p1
            rts

; player 2
; - wipe shape at previous y-position
; - move player using controller
; - set sprite positions

handle_player2
            jsr wipe_p2         ; wipe previous shape player 2

            lda player_mode
            bne do_p2_is_computer

            ldx #1              ; player 2
            jsr main_driver

            jsr move_player
            jsr show_p2
            rts

; p2 now controlled by computer
do_p2_is_computer
            lda game_state

            ldx #1              ; player 2
            jsr robot_controller

            jsr move_player
            jsr show_p2

not_in_game
            rts

reset_robot_angle_end
            lda #0
            sta robot1_angle_end
            lda #128
            sta robot2_angle_end
            rts

set_robot_angle_end
            ldx player_turn
            dex
            lda RANDOM
            and #7
            clc
            adc ball_angle_end
            sec
            sbc #3
            sta robot_angle_end,x

; other robot (not your turn)
            lda player_turn
            eor #3
            tax
            dex

            lda RANDOM
            and #15
            clc
            adc ball_angle_end
            sec
            sbc #7
            eor #128            ; other side
            sta robot_angle_end,x

            rts

; x = 0 (robot 1), x = 1 (robot 2)

robot_controller
;            lda ball_angle_end  ; current ball end
            lda robot_angle_end,x
            sta tmp_angle1
            lda p1_angle,x
            sta tmp_angle2

            jsr calc_angle_diff

            lda tmp_angle_diff
            beq comp_in_catch_position
            lda tmp_angle_direction
            bne move_comp_clockwise

            lda RANDOM
            and #3
            bne comp_in_catch_position
            lda p1_angle,x
            adc stick_slow_speed
            sta p1_angle,x
            rts
move_comp_clockwise

            lda RANDOM
            and #3
            bne comp_in_catch_position

            lda p1_angle,x
            sbc stick_slow_speed
            sta p1_angle,x
comp_in_catch_position
            rts

; move player 1/2
; right - clockwise, left = anti-clockwise

; X = 0, player 1
; X = 1, player 2

; Y = driver mode:
; 0 : stick
; 1 : paddle
; 2 : mouse
; 3 : computer
            
move_player
            lda p1_angle,x
            and #127                    ; restrict angle to 0..179 degrees
            eor #64                     ; perpendicular to the circle angle
            sta p1_shape,x

            ldy p1_angle,x
            lda inner_x_tab,y
            lsr
            adc #inner_x_margin/2
            sta player1_x,x
            lda inner_y_tab,y
            lsr
            sta player1_y,x

            ldy p1_shape,x
            jsr shape_to_ptr

            rts

; Set ball at start position
; - start angle current player
; - start position by inner table
; - collision delay set?

; Set ball current position to start position
; input:
; X = angle of start position
; output:
; ball position: (ball_current_x, ball_current_y)
; (tmp_x1, tmp_y1) = (ball_current_x, ball_current_y)
ball_to_start_position
            lda inner_x_tab,x
            sta ball_current_x
            sta tmp_x1
            lda inner_y_tab,x
            sta ball_current_y
            sta tmp_y1
            rts

; Prepare ball end position
; - end angle current player
; - end position by outer table
; - calculate step size x,y

; Input:
; - ball_angle_start
; - ball speed
; Output:
; - ball_andle_end
; - ball start position (tmp_x1, tmp_y1)
; - ball end position (tmp_x2, tmp_y2)
; - step size (step_x, step_y) for ball movement
prepare_ball_end_position
            lda ball_angle_start
            eor #128        ; other side
            sta ball_angle_end
            tax
            jsr angle_to_end_position
                        
            jsr init_current_xy
            
; move current a little bit            
            jsr move_current_xy
; ignore end indicator, since we only just started

            lda #10         ; ball can touch bat at start position, so use this delay
            sta bat_collision_delay
            rts

; x = angle 0..255
outer_angle_to_start_position
            lda outer_x_256,x
            sta ball_current_x
            sta tmp_x1
            lda outer_y_256,x
            sta ball_current_y
            sta tmp_y1
            rts

ball_current_to_start_position
            lda ball_current_x
            sta tmp_x1
            lda ball_current_y
            sta tmp_y1
            rts

; Ball collides with bat
; - start ball angle = end ball angle
; - calculate diff between bat and ball end angle
; - calculate new end angle
; - Set ball at start position
; - Prepare ball end position

bounce_bat_ball
; set new start of ball
; @todo check ball angles
; set new ball start angle (= previous end angle)
            lda ball_angle_end
            sta ball_angle_start
            
; alternative?
            ;ldx ball_angle_start
            ;jsr ball_to_start_position          
            jsr ball_current_to_start_position

; which player hit the ball?
; collision bits:
; xxxxx1x1 : 1 is player1 collision
; xxxx1010 : 2 is player2 collision

            lda mp_collision
            lsr
            lsr
            ora mp_collision
            and #%00000011      ; 01 = player1, 10 = player2, 11 = both

; who's turn is it and who bounced the ball?

            and player_turn
            beq no_switch_turn

            lda player_turn
            eor #3              ; 1 => 2, 2 => 1
            sta player_turn

no_switch_turn
            jsr turn_color_ball

            lda player_turn
            eor #3
            tax
            dex                 ; index 0,1 (player = 1,2)
            lda p1_angle,x

; Calculate diff between bat angle position and new ball start position
            sta tmp_angle1

            lda ball_angle_start
            sta tmp_angle2

            jsr calc_angle_diff

            asl
            asl
            asl
            sta angle_diff_bat

            lda tmp_angle1
            clc
            adc add_to_angle
            eor #128            ; other side
            sta tmp_angle1
            
            lda tmp_angle_direction
            bne diff_clockwise
; diff counter clockwise
            lda tmp_angle1
            clc
            adc angle_diff_bat
            sta tmp_angle1
            jmp calc_done            

diff_clockwise
            lda tmp_angle1
            sec
            sbc angle_diff_bat
            sta tmp_angle1
            
; calculation done            
calc_done
            lda tmp_angle1
            sta ball_angle_end
            tax
            jsr angle_to_end_position

            jsr set_robot_angle_end

            jmp init_current_xy

; x = angle 0..255
angle_to_end_position
            lda outer_x_256,x
            sta tmp_x2
            lda outer_y_256,x
            sta tmp_y2
            rts

wipe_ball
            lda ball_current_y
            lsr
            adc #ball_top_margin
            tax                 ; x = real y position on screen
            lda #0
            sta msl_area,x
            sta msl_area+1,x
            sta msl_area+2,x
            sta msl_area+3,x
            rts

show_ball
            lda ball_current_y
            lsr
            adc #ball_top_margin
            tax                 ; x = real y position on screen

            lda #%00000010
            sta msl_area,x
            sta msl_area+3,x
            lda #%00000111
            sta msl_area+1,x
            sta msl_area+2,x

            lda ball_current_x
            lsr
            adc #ball_left_margin
            sta HPOSM1
            adc #2
            sta HPOSM0

            rts

show_p1
; y position
            lda player1_y
            clc
            adc #upper_margin
            tax

            ldy #0
show_shape1
            lda (shape_ptr),y
            sta p0_area,x 
            iny
            lda (shape_ptr),y
            sta p2_area,x
            inx
            iny
            cpy #32
            bne show_shape1

; x position
            lda player1_x
            clc
            adc #left_margin
            sta shadow_HPOSP0
            adc #8
            sta HPOSP2
            rts

show_p2
; y position
            lda player2_y
            clc
            adc #upper_margin
            tax

            ldy #0
show_shape2
            lda (shape_ptr),y
            sta p1_area,x
            iny
            lda (shape_ptr),y
            sta p3_area,x
            inx
            iny
            cpy #32
            bne show_shape2

; x position
            lda player2_x
            clc
            adc #left_margin
            sta shadow_HPOSP1
            adc #8
            sta HPOSP3
            rts

wipe_p1
            lda player1_y
            clc
            adc #upper_margin
            tax

            ldy #16
            lda #0
wipe_it1            
            sta p0_area,x 
            sta p2_area,x
            inx
            dey
            bne wipe_it1 
            rts

wipe_p2
            lda player2_y
            clc
            adc #upper_margin
            tax
            
            ldy #16
            lda #0
wipe_it2            
            sta p1_area,x
            sta p3_area,x
            inx
            dey
            bne wipe_it2 
            rts

make_shape_index
            lda #<pm_shapes
            sta shape_ptr
            lda #>pm_shapes
            sta shape_ptr+1
            
            ldx #0
fill_pm_tab
            lda shape_ptr
            sta pm_shape_lo,x
            lda shape_ptr+1
            sta pm_shape_hi,x
            
            lda shape_ptr
            clc
            adc #32
            sta shape_ptr
            lda shape_ptr+1
            adc #0
            sta shape_ptr+1
            
            inx
            bpl fill_pm_tab
            
            rts
            
; there are 128 shapes, each 32 bytes

; y = shape index
shape_to_ptr
            lda pm_shape_lo,y
            sta shape_ptr
            lda pm_shape_hi,y
            sta shape_ptr+1

            rts

; turn 1024 tables into 256 bytes for ball edge lookup
make_outer_256
            ldy #0
            ldx #0
conv_256
            lda outer_x_tab,x
            sta outer_x_256,y
            lda outer_x_tab+$100,x
            sta outer_x_256+64,y
            lda outer_x_tab+$200,x
            sta outer_x_256+128,y
            lda outer_x_tab+$300,x
            sta outer_x_256+192,y
            
            lda outer_y_tab,x
            sta outer_y_256,y
            lda outer_y_tab+$100,x
            sta outer_y_256+64,y
            lda outer_y_tab+$200,x
            sta outer_y_256+128,y
            lda outer_y_tab+$300,x
            sta outer_y_256+192,y

            inx
            inx
            inx
            inx
            iny
            cpy #64
            bne conv_256            
            rts

show_score_p1
            lda score_p1
            lsr
            lsr
            lsr
            lsr
            beq do_space1
            ora #16
do_space1
            sta score_chars_p1
            lda score_p1
            and #15
            ora #16
            sta score_chars_p1+1
            rts

show_score_p2
            lda score_p2
            lsr
            lsr
            lsr
            lsr
            beq do_space2
            ora #16
do_space2
            sta score_chars_p2
            lda score_p2
            and #15
            ora #16
            sta score_chars_p2+1
            rts
                        
reset_score
            lda #0
            sta score_p1
            sta score_p2
            rts            
         
inc_score_p1
            sed
            lda score_p1
            clc
            adc #1
            sta score_p1    
            cld
            rts

inc_score_p2
            sed
            lda score_p2
            clc
            adc #1
            sta score_p2
            cld
            rts

; calculate the difference between angle1 and angle2

; input:
; tmp_angle1 (0..255)
; tmp_angle2 (0..255)

; output:
; tmp_angle_diff, A: difference between angle1 and angle2
; tmp_angle_direction: 0 = anti-clockwise, 1 = clockwise

calc_angle_diff
            lda #0
            sta add_to_angle
            sta tmp_angle_direction

; make sure we can compare angles, otherwise add $40 to angles
            lda tmp_angle1
            cmp #$c0
            bcs too_large
            lda tmp_angle2
            cmp #$c0
            bcc not_too_large
too_large
            lda tmp_angle1
            sec
            sbc #$40
            sta tmp_angle1
            
            lda tmp_angle2
            sec
            sbc #$40
            sta tmp_angle2
            
            lda #$40
            sta add_to_angle

not_too_large
            lda tmp_angle2
            cmp tmp_angle1
            bcc angle2_smaller_angle1
; ball >= play
            sec
            sbc tmp_angle1
            sta tmp_angle_diff
            
            inc tmp_angle_direction
            jmp diff_calculated
                        
angle2_smaller_angle1
            lda tmp_angle1
            sec
            sbc tmp_angle2
            sta tmp_angle_diff

diff_calculated
            lda tmp_angle_diff           
            rts

; X = angle
; lookup magnitude of angle 0 to angle X
angle_to_magnitude
            lda magnitudes_lo,x
            sta magnitude
            lda magnitudes_hi,x
            sta magnitude+1
            rts

; tmp_dx = abs(tmp_x2 - tmp_x1)
calc_abs_tmp_dx
            lda tmp_x2
            sec
            sbc tmp_x1
            bcs x2_le
            eor #255
            clc
            adc #1
x2_le       sta tmp_dx

; tmp_dy = abs(tmp_y2 - tmp_y1)
calc_abs_tmp_dy
            lda tmp_y2
            sec
            sbc tmp_y1
            bcs y2_le
            eor #255
            clc
            adc #1
y2_le       sta tmp_dy
            rts
            
calc_dx_div_magnitude
            lda #0
            sta _dividend
            lda tmp_dx
            sta _dividend+1

            lda magnitude+1
            sta _divisor
            lda #0
            sta _divisor+1
            
            jsr _div16

; todo multiply result with velocity            
            lda _result
            sta step_x
            lda _result+1
            sta step_x+1
            
            rts
            
calc_dy_div_magnitude
            lda #0
            sta _dividend
            lda tmp_dy
            sta _dividend+1
            
            lda magnitude+1
            sta _divisor
            lda #0
            sta _divisor+1

            jsr _div16
            
; todo multiply result with velocity
            lda _result
            sta step_y
            lda _result+1
            sta step_y+1
            
            rts

; divide 16bit
; https://codebase64.org/doku.php?id=base:16bit_division_16-bit_result

; _result = _dividend / divisor

_div16      lda #0          ;preset remainder to 0
            sta _remainder
            sta _remainder+1
            ldx #16         ;repeat for each bit: ...

_div_loop   asl _dividend    ;dividend lb & hb*2, msb -> Carry
            rol _dividend+1  
            rol _remainder   ;remainder lb & hb * 2 + msb from carry
            rol _remainder+1
            lda _remainder
            sec
            sbc _divisor ;substract divisor to see if it fits in
            tay         ;lb result -> Y, for we may need it later
            lda _remainder+1
            sbc _divisor+1
            bcc _div_skip    ;if carry=0 then divisor didn't fit in yet

            sta _remainder+1 ;else save substraction result as new remainder,
            sty _remainder   
            inc _result  ;and INCrement result cause divisor fit in 1 times

_div_skip   dex
            bne _div_loop 
            rts

; Calculations for step size

; not optimised for speed or size
; step should be set according to the angle

; move in straight line (x1,y1) to (x2,y2)

; 1. set start/end of line
; set (tmp_x1, tmp_y1)
; set (tmp_x2, tmp_y2)

; 2. init. current_x, current_y
; - set current x,y to start of line (tmp_x1, tmp_y2)
; - calculates step sizes for x,y
; - calculated directions for x,y
;            jsr init_current_xy

; 3. use current_x, current_y to plot or set a position
;            lda current_x+1
;            sta x_position
;            lda current_y+1
;            sta y_position
;            jsr plot_pixel

; 4. move current_x, current_y to next position on line
; A=0 still moving
;           move_current_xy

init_current_xy
            lda #$7f      ; was 128 for half pixel
            sta current_x
            sta current_y

            lda tmp_x1
            sta current_x+1
            
            lda tmp_y1
            sta current_y+1

; dx = abs(tmp_x1 - tmp_x2)
            jsr calc_abs_tmp_dx

; dy = abs(tmp_y1 - tmp_y2)
            jsr calc_abs_tmp_dy

; set directions
            lda tmp_x1
            cmp tmp_x2
            bcc x1_smaller_x2
; x1 >= x2
            lda #1
            bne set_dir_x
x1_smaller_x2
            lda #0
set_dir_x
            sta dir_x
            
            lda tmp_y1
            cmp tmp_y2
            bcc y1_smaller_y2
; y1 >= y2
            lda #1
            bne set_dir_y
y1_smaller_y2
            lda #0
set_dir_y
            sta dir_y

; Calculate diff between start angle and end angle

            lda ball_angle_start
            sta tmp_angle1
            lda ball_angle_end
            sta tmp_angle2
            
            jsr calc_angle_diff

; lookup magnitude of vector (tmp_x1, tmp_y1), (tmp_x2, tmp_y2)
            ldx tmp_angle_diff
            jsr angle_to_magnitude
            
            jsr calc_dx_div_magnitude
            jsr calc_dy_div_magnitude
            
; Calculate step size by ball speed
            
; step_x = step_x * speed
            
            lda step_x
            sta _multiplicand
            lda step_x+1
            sta _multiplicand+1
            lda ball_speed
            sta _multiplier

            jsr _multi8
;result in .A (low byte, also in .X) and .Y (high byte)
            sta step_x
            sty step_x+1
skip_step_x_hi
            
; step_y = step_y * speed

            lda step_y
            sta _multiplicand
            lda step_y+1
            sta _multiplicand+1
            lda ball_speed
            sta _multiplier

            jsr _multi8
;result in .A (low byte, also in .X) and .Y (high byte)
            sta step_y
            sty step_y+1
skip_step_y_hi

            rts

; Move ball position 
; Add one step, until end reached
; Input:
; - step size (step_x, step_y)
; - current ball position (current_x, current_y)
; - end position (tmp_x2, tmp_y2)
; Output:
; A (0 = still moving, 1 = end reached)
move_current_xy
            lda #0
            sta line_end_x
            sta line_end_y

; sets line end indicators here
            jsr move_current_x
            jsr move_current_y

            lda line_end_x
            and line_end_y
            beq no_end_reached

end_reached
; set current to (x2,y2)
            lda tmp_x2
            sta current_x+1
            lda tmp_y2
            sta current_y+1
            
            lda #0
            sta current_x
            sta current_y
            
            lda #1 ; end reached
            
no_end_reached  ; A = 0
            rts

move_current_x
            lda dir_x
            bne move_current_left

; move right, add
            lda current_x
            clc
            adc step_x
            sta current_x
            lda current_x+1
            adc step_x+1
            sta current_x+1

            lda current_x+1
            cmp tmp_x2
            bcc no_line_end
exact_end_x
;            lda #1
;            sta line_end_x
no_line_end
            rts
            
move_current_left
            lda current_x
            sec
            sbc step_x
            bcc clear_skip
            nop
clear_skip
            sta current_x
            lda current_x+1
            sbc step_x+1
            sta current_x+1
            bcc below_zero
                        
            lda tmp_x2
            cmp current_x+1
            bcc no_line_end
;            lda #1
;            sta line_end_x
            rts
below_zero            
;            lda #1
;            sta line_end_x
;            sta line_end_y
            rts
move_current_y
            lda dir_y
            bne move_current_up

; move down, add
            lda current_y
            clc
            adc step_y
            sta current_y
            lda current_y+1
            adc step_y+1
            sta current_y+1
            
            lda current_y+1
            cmp tmp_y2
            bcc no_line_end
exact_end_y
;            lda #1
;            sta line_end_y
            rts

move_current_up
            lda current_y
            sec
            sbc step_y
            sta current_y
            lda current_y+1
            sbc step_y+1
            bcc below_zero
            sta current_y+1
            
            lda tmp_y2
            cmp current_y+1
            bcc no_line_end
;            lda #1
;            sta line_end_y
            rts                            
            
init_sprites
            ldx #0
            txa
set_p
            sta p0_area,x
            sta p1_area,x
            sta p2_area,x
            sta p3_area,x
            inx
            bpl set_p

            lda #%0110001  ; overlap OR colors, missile = 5th player, prio player 0..3
            sta GPRIOR

            lda #>pm_area
            sta PMBASE

            lda #3          ; P/M both on
            sta GRACTL

            lda #$90
            sta HPOSP2
            lda #$A0
            sta HPOSP3  
            rts

init_colors
            lda #BASE_COLOR_P1+10
            sta PCOLR2
            lda #BASE_COLOR_P2+10
            sta PCOLR3
            
            lda #0
            sta COLOR2

            lda #HEADER_FG_COLOR
            sta COLOR1

            lda #HEADER_P1_COLOR
            sta PCOLR0
            lda #HEADER_P2_COLOR
            sta PCOLR1

            rts

previous_consol
            dta 0

current_level_index
            dta 0
NR_OF_LEVELS = 7
INIT_LEVEL_INDEX = 0
level_speeds
            dta 2,3,4,5,6,7,8
;level_speeds_lo
;            dta 128
stick_slow_speed_tab
            dta 1,2,2,2,3,3,3
stick_fast_speed_tab
            dta 2,2,3,3,4,4,4

; X = level (0..NR_OF_LEVELS)
set_level_ball_speed
            lda stick_slow_speed_tab,x
            sta stick_slow_speed
            lda stick_fast_speed_tab,x
            sta stick_fast_speed

            lda level_speeds,x
            sta ball_speed
            txa
            clc
            adc #1
            ora #16
            sta level_char
            rts
            
increase_level
            inc current_level_index
            lda current_level_index
            cmp #NR_OF_LEVELS
            bne ok_level
            lda #INIT_LEVEL_INDEX
            sta current_level_index
ok_level           
            rts

increase_player_mode
            inc player_mode
            lda player_mode
            cmp #NR_OF_PLAYER_MODES
            bne ok_player_mode
            lda #INIT_PLAYER_MODE
            sta player_mode
ok_player_mode
            sta player_mode_saved
            rts

show_player_mode
            ldx player_mode
            lda player_mode_lo,x
            sta menu_line2_ptr
            lda player_mode_hi,x
            sta menu_line2_ptr+1
            rts

            .align $100
inner_x_tab
inner_y_tab = *+$100
            ins 'data\in210.dat'
      
            .align $400            
; outer circle 1024 plot points on 360 degrees
outer_x_tab
outer_y_tab = *+1024
            ins 'data\out224.dat'
           
            .align $400
; table of magnitudes (length) between angle 0 and 0..255
; fixed point 8.8 : hi.lo
magnitudes_lo
magnitudes_hi = *+256
            ins 'data\magnitud.dat'

            .align $400
display_list
            dta $42+128         ; dli_header
            dta a(score_line)

; 102 x 40 = 4080 bytes            
            dta $4f
            dta a(screen_mem1)
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
menu_dl_hook
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

            dta $0f,$0f,$0f,$0f,$0f,$0f

; 42 + 60 = 102, 4080 bytes
            dta $4f
            dta a(screen_mem2)
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f

            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

            dta $0f,$0f

; 60 lines
menu_dl_end
            dta $4f
            dta a(screen_mem2+(42*SCREEN_WIDTH))
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f

; 20 x 40 = 800
            dta $4f
            dta a(screen_mem3)       
            dta $0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            
            dta $41
            dta a(display_list)

menu_dl_part
            dta 128 ; dli_menu
            dta $20
            dta $42
            dta a(rotor_logo_text)
            dta 2
            dta $30
            dta $46
menu_line1_ptr
            dta a(controller_text)
            dta $46
menu_line2_ptr
            dta a(two_player_text)
            dta $46
menu_line3_ptr
            dta a(level_text)
            dta $30
            dta $42
            dta a(start_text)
            dta $10
            dta $01 ; jump
            dta a(menu_dl_end)

score_line  
            dta d' ONE '
score_chars_p1
            dta d'-- '

            dta d'          '
            dta d'          '

            dta d'     TWO '
score_chars_p2
            dta d'-- '

score_p1    dta 0
score_p2    dta 0

            .align $100
rotor_logo_text
            dta d'              '
            dta $45,$46,$47,$48,$49,$4a,$4b,$4c,$4d,$4e,$4f,$50
            dta $40
            dta d'             '
            dta d'              '
            dta $51,$52,$53,$54,$55,$56,$57,$58,$59,$5a,$5b,$5c
            dta d'              '

controller_text
            dta d'  CONTROL:'
driver_screen
            dta d'          '

two_player_text
            dta d'   HUMAN VS HUMAN   '

one_player_text
            dta d'   HUMAN VS ROBOT  '

demo_player_text
            dta d'        DEMO        '

level_text
            dta d'      LEVEL '
level_char            
            dta d'1       '

start_text
            dta d'     START or FIRE buttons to play!     '*
stick_text
            dta d'STICK   '
paddle_text
            dta d'PADDLE  '
mouse_text
            dta d'MOUSE   '
unknown_text
            dta d'UNKNOWN '

empty_text
            dta d'                    '
winner_one_text
            dta d'  PLAYER ONE WINS!  '
winner_two_text
            dta d'  PLAYER TWO WINS!  '

driver_text_lo
            dta <stick_text
            dta <paddle_text
            dta <mouse_text
            dta <unknown_text
            
driver_text_hi
            dta >stick_text
            dta >paddle_text
            dta >mouse_text
            dta >unknown_text

player_mode_lo
            dta <two_player_text
            dta <one_player_text
            dta <demo_player_text

player_mode_hi
            dta >two_player_text
            dta >one_player_text
            dta >demo_player_text

; 4 KB
; 128 x 32 bytes shapes
            .align $1000
pm_shapes
            ins 'data\pm_128_x_32.dat'

; 9 KB for backdrop image
            .align $1000
screen_mem1 = * ; 4K
;            org screen_mem1
            ins 'gfx\backdrop2.gr8',0,102*SCREEN_WIDTH

            .align $1000
screen_mem2 = * ; 4K
;            org screen_mem2
            ins 'gfx\backdrop2.gr8',102*SCREEN_WIDTH,102*SCREEN_WIDTH

            .align $1000
screen_mem3 = * ; 1K
;            org screen_mem3
            ins 'gfx\backdrop2.gr8',204*SCREEN_WIDTH,20*SCREEN_WIDTH

            run main
