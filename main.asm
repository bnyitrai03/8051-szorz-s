; -----------------------------------------------------------
; Mikrokontroller alapú rendszerek házi feladat
; Készítette: Nyitrai Bence
; Neptun code: QEM0OR
; Feladat leírása:
;		Belső memóriában lévő két darab 16 bites előjeles szám szorzása, túlcsordulás figyelése.
; 		Az eredmény is 16 bites előjeles szám legyen, a túlcsordulás ennek figyelembevételével állítandó.
;		Bemenet: a két operandus és az eredmény kezdőcímei (mutatók).
;		Kimenet: eredmény (a kapott címen), OV
; -----------------------------------------------------------

$NOMOD51 ; a sztenderd 8051 regiszter definíciók nem szükségesek

$INCLUDE (SI_EFM8BB3_Defs.inc) ; regiszter és SFR definíciók

; Változóknak helyfoglalás
	DSEG AT 0x40
Op1: DS 2                             ; Operandus1-nek helyet foglalunk (16 bites)
Op2: DS 2							  ; Operandus2-nek helyet foglalunk (16 bites)
Result: DS 2						  ; Végeredménynek helyet foglalunk (16 bites)

; Ugrótábla létrehozása
	CSEG AT 0
	SJMP Main

	myprog SEGMENT CODE					; saját kódszegmens létrehozása
	RSEG myprog 						; saját kódszegmens kiválasztása
; ------------------------------------------------------------
; Főprogram
; ------------------------------------------------------------
; Feladata: a szükséges inicializációs lépések elvégzése és a
;			feladatot megvalósító szubrutin meghívása
; ------------------------------------------------------------
Main:
	CLR IE_EA                      ; interruptok tiltása watchdog tiltás idejére
	MOV WDTCN,#0DEh                ; watchdog timer tiltása
	MOV WDTCN,#0ADh
	SETB IE_EA                     ; interruptok engedélyezése
	USING 0                        ; 0-ás regiszter bank kiválasztása

; paraméterek előkészítése a szubrutin híváshoz
	MOV Op1,   #0x01 		       ; az első operandus alsó bájtjának beírása a belső memóriába
	MOV Op1 +1,#0x00 		       ; felső bájt írása
	MOV Op2,   #0xFF 			   ; a második operandus beírása a belső memóriába, hasonló módon
	MOV Op2 +1,#0xFF

	MOV R0, #Op1      			   ; az első, második operandus és az eredmény kezdő címe lesz a
	MOV R1, #Op2	  			   ; szubrutin bemenete
	MOV R3, #Result
	CALL MultiplicationSubroutine  ; szorzás elvégzése, az eredmény a Result változóban látható

	JMP $ 						   ; végtelen ciklusban várunk

; -----------------------------------------------------------
; Szorzó szubrutin
; -----------------------------------------------------------
; Funkció: 		két darab 16 bites előjeles szám szorzása
; Bementek:		R0 - első operandus címe
;			 	R1 - második operandus címe
;               R3 - eredmény címe
; Kimenetek:  	eredmény (a kapott címen)
;				OV
; Regisztereket módosítja:
;		                  A, B, PSW
; JMP $ sorba levő breakpointon állva előáll a helyes eredmény
; -----------------------------------------------------------

MultiplicationSubroutine:
	PUSH AR0                ; regiszterek mentése
	PUSH AR1
	PUSH AR2
	PUSH AR3
	PUSH AR4
	PUSH AR5
	PUSH AR6
	PUSH AR7

	CLR PSW_F0              ; előjel nélküliként inicializáljuk az előjeleket tároló flageket
	CLR PSW_F1

; előjel vizsgálat Op1-nek
	INC R0                  ; AR0-át beállítjuk Op1 felső bájtjára
	MOV A, @R0
	ANL A, #0x80            ; megnézzük az első operandus előjelét
	JNZ Negative_Op1        ; 1 AND 1 = 1, tehát negatív a szám ilyenkor

; értéket adunk R2-nak és R4-nek ha Op1 alapból pozitív
	MOV A, @R0
	MOV R4,A                ; Unsigned-ra konvertált Op1 felső bájtja lesz R4-ben
    DEC R0
	MOV A, @R0
	MOV R2, A               ; Unsigned-ra konvertált Op1 alsó bájtja lesz R2-be
	JMP Op2_sign_check

Negative_Op1:
	SETB PSW_F0                    ; elmentjük hogy Op1 alapból negatív volt
	MOV A, @R0					   ; aztán berakjuk R6-ba Op1 felső bájtját
	MOV R6, A
	DEC R0                         ; lépünk Op1 alsó bájtjára, hogy azt is átadjuk a rutinnak
	MOV A, @R0
	MOV R0, A                      ; R0-án keresztül
	CALL Convert                   ; meghívjuk a szubrutint
	MOV A, R6
	MOV R4, A                      ; R4-be lesz Op1 felső bájtja
	MOV A, R0
	MOV R2, A                      ; R2-be lesz Op1 alsó bájtja

; előjel vizsgálat Op2-nek
Op2_sign_check:
	INC R1                  ; R1-et beállítjuk Op2 felső bájtjára
	MOV A, @R1
	ANL A, #0x80            ; megnézzük a második operandus előjelét
	JNZ Negative_Op2        ; 1 AND 1 = 1, tehát negatív a szám ilyenkor

; értéket adunk a R1,R5-nek ha Op2 alapból pozitív
	MOV A, @R1
	MOV R5, A                ; Unsigned-ra konvertált Op2 felső bájtja lesz R5-be
	DEC R1
	MOV A, @R1
	MOV R1, A                ; Unsigned-ra konvertált Op2 alsó bájtja lesz R1-be
	JMP Result_sign

Negative_Op2:
	SETB PSW_F1                   ; elmentjük hogy Op2 alapból negatív volt
	MOV A, @R1					  ; aztán berakjuk R6-ba Op2 felső bájtját
	MOV R6, A
	DEC R1                        ; lépünk Op2 alsó bájtjára, hogy azt is átadjuk a rutinnak
	MOV A, @R1                    ; R0-án keresztül
	MOV R0, A
	CALL Convert                   ; meghívjuk a szubrutint
	MOV A, R6
	MOV R5, A                      ; R5-be lesz Op2 felső bájtja
	MOV A, R0
	MOV R1, A                      ; R1-be lesz Op1 alsó bájtja

;kiszámoljuk a végeredmény előjelét
Result_sign:
	MOV A, PSW               ; F1 PSW 5. bite, F0 PSW 1. bite
	ANL A, #0x22             ; ha F1 és F0 is 0, akkor az eredmény pozitív
	JZ Positive
	MOV A, PSW
	ANL A, #0x22             ; kimaszkoljuk a többi bitet
	XRL A, #0x22             ; ha F1 és F0 is 1, akkor is az eredmény pozitív
	JZ Positive              ; 1 XOR 1 = 0

	SETB PSW_F0              ; innentől F0 tárolja a végeredmeény előjelét
	JMP Multiply

Positive:
	CLR PSW_F0               ; innentől F0 flag tárolja a végeredmény előjelét

Multiply:
	CLR PSW_F1               ; innentől F1 flag tárolja hogy túlcsordúltunk-e
; unsigned Op1 alsó bájtja szorozva unsigned Op2 alsó bájtjával
	MOV   A, R2    	        ; A-ban Op1 konvertált alsó bájtja
	MOV   B, R1    	   	    ; B-ben Op2 konvertált alsó bájtja
	MUL   AB           		; A szorzat eredményének a felső bájtja B-be kerül

    MOV R6, A               ; A-ba pedig az alsó
	MOV A, R3      		    ; A szorzat alsó bájtját berakjuk a végerdemény címének alsó bájtjára
	MOV R0, A
	MOV A, R6
	MOV @R0, A
	MOV R7, B               ; (UOp1L * UOp2L)-nak a felső bájtját eltároljuk későbbi művelethez R7-be

; UOp1 felső bájtja szorozva UOp2 alsó bájtjával
	MOV  A, R4     	         ; A-ban UOp1 felső bájtja (R4)
	MOV  B, R1    	   	     ; B-ben UOp2 alsó bájtja  (R1)
	MUL  AB           	     ; B-be kerül a felső bájt
						     ; A-ba pedig az alsó
	ADD A, R7                ; (UOp1H * Uop2L)-nak az alsó bájtját hozzáadjuk (UOp1L * UOp2L)-nak a felső bájtjához
	MOV R7, A
	JNB PSW_OV, Op1H_x_Op2L
	SETB PSW_F1                   ; túlcsorduláskor állítjuk F1 flaget

Op1H_x_Op2L:
	CLR A
	ORL A, B                 ; (UOp1H * UOp2L)-nak a felső bájtja, ha nem 0, akkor is túlcsordultunk
	JZ Op1L_x_Op2H
	SETB PSW_F1                   ; túlcsorduláskor állítjuk F1 flaget

Op1L_x_Op2H:
; UOp1 alsó bájtja szorozva UOp2 felső bájtjával
	MOV A, R5   	           ; A-ban UOp2 felső bájtja (R5)
	MOV B, R2   	   	       ; B-ben UOp1 alsó bájtja  (R2)
	MUL AB           	       ; B-be kerül a felső bájt
						       ; A-ba pedig az alsó
	ADD A, R7			       ; ha (UOp1L * UOp2H)-nak alsó bájtja plussz R7-be eddig számolt összeg
	JNB PSW_OV, Result_upper_byte
	SETB PSW_F1                   ; túlcsorduláskor állítjuk F1 flaget

Result_upper_byte:
; (UOp1L*UOp2L) felső bájtja + (UOp1H*UOp2L) alsó bájtja + (UOp1L*UOp2H) alsó bájtja lesz
; a végeredmény felső bájtja
	MOV R6, A
	INC R3                     ; R3 alapból az alsó bájtra mutat
	MOV A, R3
	DEC R3                     ; visszaállítjuk
	MOV R0, A
	MOV A, R6
	MOV @R0, A                 ; a végeredmény felső bájtjának a címére berakjuk az összeget

	CLR A
	ORL A, B                    ; (UOp1L * UOp2H)-nak a felső bájtja, ha nem 0, akkor túlcsordultunk
	JZ Op1H_x_Op2H
	SETB PSW_F1                   ; túlcsorduláskor állítjuk F1 flaget

Op1H_x_Op2H:
; UOp1 felső bájtja szorozva UOp2 felső bájtjával 0-át kell adjon, különben túlcsordultunk
	MOV A, #FF
	ANL A, R4                    ; UOp1 felső bájtja R4-ben, UOp2 felső bájtja pedig R5-ben
	JZ Check_negative
	MOV A, #FF
	ANL A, R5                     ;UOp2 felső bájtja pedig R5-ben
	JZ Check_negative             ; UOp1H vagy UOp2H = 0-val, különben túlcsordultunk
    SETB PSW_F1                   ; túlcsorduláskor állítjuk F1 flaget

Check_negative:
; Az erdményt át kell írni negatívra ha az operandusok előjelei különbözőek
	MOV A,PSW
	ANL A,#0x20                    ; kimaszkoljuk PSW_F0-át
	JZ Overflow_check              ; ha 0 akkor pozitív a végeredmény
	MOV A, R3                      ; az eredmény alsó bájtát berakjuk R0-ba
	MOV R0, A                      ; aztán meghívjuk a konvertáló függvényt
	MOV A, @R0
	MOV R0, A                      ; konvertálandó alsó bájt
	CALL Convert                   ; a felső bájt még R6-ba van
	MOV A, R0
	MOV R4, A                      ; R4-be az alsó bájt kerül
; felülírjuk a végeredményt
	MOV A,R3
    MOV R0,A
	MOV A, R4                       ; R4-be volt a végeredmény alsó bájtja
	MOV @R0, A                      ; R3-al nem lehet így címezni, ezért töltöttük át R0-ba
	INC R3
	MOV A,R3
	DEC R3                          ; R3-at visszaállítjuk
	MOV R0,A
	MOV A, R6                       ; R6-ba volt a végeredmény felső bájtja
	MOV @R0, A

; megnézzük, hogy túlcsordult-e a szorzás
Overflow_check:
    MOV A,PSW
	ANL A,#0x02                      ; kimaszkoljuk PSW_F1-et, ami a túlcsordulást tárolja
	JNZ Invalid_result               ; ha 1 akkor túlcsordult a végeredmény
	CLR PSW_OV                       ; 0 akkor nem
	JMP Func_end

Invalid_result:
	SETB PSW_OV                       ; beállítjuk a túlcsordulást

Func_end:

	POP AR7                           ; regiszterek visszaállítása
	POP AR6
	POP AR5
	POP AR4
	POP AR3
	POP AR2
	POP AR1
	POP AR0
	RET
; ------------------------------------------------------------------------------------------------

; -----------------------------------------------------------
; Kettes komplemens konverter szubrutin
; -----------------------------------------------------------
; Funkció: 		egy darab 16 bites szám kettes komplemens konverziója
; Bement:		R0 - alsó bájt
;               R6 - felső bájt
; Kimenet:  	R0 - alsó bájt
;               R6 - felső bájt
; Regisztereket módosítja:
;		                  A, PSW, R0, R6
Convert:
	MOV A, R6
	CPL A                            ; megnegáljuk a felső
	MOV R6, A
	MOV A, R0
	CPL A                            ; majd az alsó bájtot is
	CLR C
	ADD A, #1                        ; korábbi negálás után az az alsó bájthoz hozzáadunk 1-et
	MOV R0, A                        ; aztán visszaadjuk majd
	CLR A
	ADDC A, R6                       ; ha volt átvitel az alsó bájtról, akkor azt hozzáadjuk a felsőhöz
	MOV R6, A                        ; R6-ba visszamegy a delső bájt
	RET

END
