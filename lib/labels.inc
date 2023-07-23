; labels for OS and hardware

x_position  = $55
y_position  = $54

SAVMSC      = $58       ; screen memory pointer

plot_pixel  = $f1d8

VDSLST      = $200

ATACHR      = $2fb      ; drawing color
draw_color  = ATACHR    ; alias

GPRIOR      = $026f

PADDL0      = $0270
PADDL1      = $0271

STICK0      = $0278
STICK1      = $0279

STRIG0      = $0284
STRIG1      = $0285

SDMCTL      = $022f
SDLSTL      = $0230
SDLSTH      = $0231

PCOLR0      = $02c0
PCOLR1      = $02c1
PCOLR2      = $02c2
PCOLR3      = $02c3

COLOR0      = $02c4
COLOR1      = $02c5
COLOR2      = $02c6
COLOR3      = $02c7

HPOSP0      = $d000
HPOSP1      = $d001
HPOSP2      = $d002
HPOSP3      = $d003
HPOSM0      = $d004
HPOSM1      = $d005
HPOSM2      = $d006
HPOSM3      = $d007

SIZEP0      = $d008
SIZEP1      = $d009
SIZEP2      = $d00a
SIZEP3      = $d00b
SIZEM       = $d00c

; collision
M0PF        = $d000
M1PF        = $d001
M2PF        = $d002
M3PF        = $d003

P0PF        = $d004
P1PF        = $d005
P2PF        = $d006
P3PF        = $d007

M0PL        = $d008
M1PL        = $d009
M2PL        = $d00a
M3PL        = $d00b

P0PL        = $d00c
P1PL        = $d00d
P2PL        = $d00e
P3PL        = $d00f

COLPM0      = $d012
COLPM1      = $d013
COLPM2      = $d014
COLPM3      = $d015

COLPF0      = $d016
COLPF1      = $d017
COLPF2      = $d018
COLPF3      = $d019
COLBK       = $d01a

GRACTL      = $d01d
HITCLR      = $d01e
CONSOL      = $d01f

AUDF1       = $d200
AUDC1       = $d201
AUDF2       = $d202
AUDC2       = $d203
AUDF3       = $d204
AUDC3       = $d205
AUDF4       = $d206
AUDC4       = $d207
AUDCTL      = $d208

RANDOM      = $d20a

PMBASE      = $d407
WSYNC       = $d40a
NMIEN       = $d40e