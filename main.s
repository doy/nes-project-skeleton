.MEMORYMAP
DEFAULTSLOT  0
SLOTSIZE     $4000
SLOT 0       $C000
SLOTSIZE     $2000
SLOT 1       $0000 ; location doesn't matter, CHR data isn't in main memory
.ENDME

.ROMBANKMAP
BANKSTOTAL  2
BANKSIZE    $4000
BANKS       1
BANKSIZE    $2000
BANKS       1
.ENDRO


.ENUM $0000
buttons_pressed DB
sleeping        DB
.ENDE


  .bank 0
  .org $0000
; the ppu takes two frames to initialize, so we have some time to do whatever
; initialization of our own that we want to while we wait. we choose here to
; set up cpu flags in the first frame and clear out system ram in the second
; frame (clearing out ram isn't at all necessary, but we can't do anything
; useful at this point anyway, so we may as well in order to make things more
; predictable).
RESET:
  SEI              ; disable IRQs
  CLD              ; disable decimal mode
  LDX #$40
  STX $4017.w      ; disable APU frame IRQ
  LDX #$FF
  TXS              ; Set up stack (grows down from $FF to $00, at $0100-$01FF)
  INX              ; now X = 0
  STX $2000.w      ; disable NMI (we'll enable it later once the ppu is ready)
  STX $2001.w      ; disable rendering (same)
  STX $4010.w      ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002        ; bit 7 of $2002 is reset once vblank ends
  BPL vblankwait1  ; and bit 7 is what is checked by BPL

  ; set everything in ram ($0000-$07FF) to $00, except for $0200-$02FF which
  ; is conventionally used to hold sprite attribute data. we set that range
  ; to $FE, since that value as a position moves the sprites offscreen, and
  ; when the sprites are offscreen, it doesn't matter which sprites are
  ; selected or what their attributes are
clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem

  ; initialize variables in ram
  LDA #$00
  STA buttons_pressed
  STA sleeping

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

  ; now that the ppu is ready, we can start initializing it
LoadPalettes:
  LDA $2002    ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006    ; write the high byte of $3F00 address
  LDA #$00
  STA $2006    ; write the low byte of $3F00 address
  LDX #$00
LoadPalettesLoop:
  LDA palette.w, x      ;load palette byte
  STA $2007             ;write to PPU
  INX                   ;set index to next byte
  CPX #$20
  BNE LoadPalettesLoop  ;if x = $20, 32 bytes copied, all done

  LDA #%00010000   ; enable sprites
  STA $2001

  LDA #%10000000   ; enable NMI interrupts
  STA $2000

loop:
  INC sleeping
sleep:
  LDA sleeping
  BNE sleep

  JSR read_controller1

  ; game logic

  JMP loop

NMI:
  PHA
  TXA
  PHA
  TYA
  PHA

  ; drawing code

  LDA #$00
  STA sleeping

  PLA
  TAY
  PLA
  TAX
  PLA
  RTI

read_controller1:
  ; latch
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016

  ; clock
  LDX #$00
read_controller1_values:
  CPX #$08
  BPL end_read_controller1

  LDA $4016
  AND #%00000001
  ASL buttons_pressed
  ORA buttons_pressed
  STA buttons_pressed
  INX
  JMP read_controller1_values

end_read_controller1:
  RTS

palette:
  .db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F
  .db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C

  .orga $FFFA    ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial


  .bank 1 slot 1
  .org $0000
  .incbin "sprites.chr"
