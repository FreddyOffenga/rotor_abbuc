; rotor intro 

            org $0600

first_screen_off
            lda #0
            sta 559
            lda 20
wait_black
            cmp 20
            beq wait_black
            rts

            ini first_screen_off

            org $2000
rotor_font
            ins 'font\rotor.fnt'

            org $610
intro_main
            lda #<dl_intro
            sta $230
            lda #>dl_intro
            sta $231

            lda #>rotor_font
            sta 756

            lda #0
            sta 710

            lda #34
            sta 559

; reset clock
            lda #0
            sta 20
            sta 19
            
            rts

footer_intro
            dta d'Kod:F#READY  Music:IvoP  Gfx:IvoP,Fred_M'

dl_intro
            dta $70,$70,$70

            dta $4f
            dta a(intro_image)
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
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f

            dta $0f,$0f,$0f,$0f,$0f,$0f

            dta $4f
            dta a(intro_image+$ff0)
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
            dta $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
            dta $0f,$0f
            
            dta $20
            dta $42
            dta a(footer_intro)

            dta $41
            dta a(dl_intro)
            
            org $a010
intro_image
            ins 'gfx\intro\intro_v4_gr8_inverted.gr8'

            ini intro_main
