LCD_RW EQU P2.5
LCD_RS EQU P2.6
LCD_EN EQU P2.7
LCD_DATAPINS EQU P0

; Task: When reaching 0, it must repeat
	
MAIN:
	CLR A
	MOV 02DH, A		; LCD Counter
	MOV 02EH, A		; Row
	LCALL LCD_INIT
	
	MOV 10H, #27H	; 270FH = 9999D; 03E7H = 0999D; 0063H = 0099D
	MOV 11H, #0FH	; Dividend
MAIN_LOOP:

	MOV R6, 10H		; HB of Dividend
	MOV R7, 11H		; LB of Dividend
	
	CJNE R6, #0, CONT1
	CJNE R7, #0, CONT1
	JMP MAIN
	
	CONT1:
	
	MOV R4, #00H	; Prepare Divisor
	MOV R5, #07H	; 
	LCALL DIVISION	; Divide by 7
	MOV A, R5
	ORL A, R4
	JZ MAIN_SKIP1	; Jump if no remainder (Divisible by 7)
					; If not divisible, try 9
	MOV R6, 10H
	MOV R7, 11H
	
	MOV R4, #00H	; Prepare Divisor
	MOV R5, #09H	; 
	LCALL DIVISION	; Divide by 9
	MOV A, R5
	ORL A, R4
	JNZ MAIN_SKIP2	; Jump if has remainder
	
MAIN_SKIP1:			; 
	MOV A, 02DH		; LCD Counter
	JNZ MAIN_SKIP3	; Jump if A == 0
	
	MOV R7, #80H	; Move cursor to start at first line
	LCALL LCD_WRC	
	SJMP MAIN_SKIP4
	
MAIN_SKIP3:
	MOV A, 02DH
	CJNE A, #03H, MAIN_SKIP5
	
	MOV R7, #0C0H
	LCALL LCD_WRC
MAIN_SKIP5:
	MOV R7, 11H
	MOV R6, 10H
MAIN_SKIP4:			; Display number on LCD
	LCALL LCD_DISPLAY_NUMBERS
	MOV R7, #2CH	; Display comma after number
	LCALL LCD_WRD
	INC 02DH		; Increment LCD Counter
	MOV A, 02DH		; Move to A to read
	CJNE A, #06H, MAIN_SKIP6	; Jump if LCD Counter = 6: Skip
	CLR A			; Clear A
	MOV 02DH, A		; Clear LCD Counter
	INC 02EH		; Increment Row
MAIN_SKIP6:
	MOV R7, #64H	; For delay
	MOV R6, #00H
	LCALL DELAY
MAIN_SKIP2:
	MOV A, 11H		; Load LB-end
	DEC 11H			; Decrement LB-end
	JNZ MAIN_SKIP7	; Jump if LB-end is not 0
	DEC 10H			; If zero, decrement HB-end as well
MAIN_SKIP7:
	CLR C			; Clear C
	MOV A, 10H		; Store HB-end
	SUBB A, #00H	; C = 1 if (HB-end) > 00
					; 
	JNC MAIN_LOOP
	;JMP MAIN_LOOP
	JMP MAIN
RET
		
DIVISION:
	; Input: Dividend = R6R7 , Divisor = R4R5
	; Output: Quotient = R6R7, Remainder = R5
	
	CJNE R4, #00H, DIV_JMP1	; Jump if HB-sor has a value
	CJNE R6, #00H, DIV_JMP2	; Jump if HB-end has a value
	; Else if both HB of dividend and divisor is 0
	; Just divide LB of both
	MOV A, R7	; LB of Dividend
	MOV B, R5	; LB of Divisor
	DIV AB
	MOV R7, A	; Move quotient to R7
	MOV R5, B	; Move remainder to R5
RET
DIV_JMP1:
	CLR A
	XCH A, R4	; Store HB-sor to A and clear R4
	MOV R0, A	; Store HB-sor to R0

	MOV B, #08H	; Initialize loop counter (8 times for 8 bits in a byte)
DIV_LOOP1:
	MOV A, R7	; Load LB of Dividend
	ADD A, R7	; Add with itself
	MOV R7, A	; Store sum back
	
	MOV A, R6	; Load HB of Dividend
	RLC A		; Rotate left w Carry
	MOV R6, A	; Store rotated HB back
	
	MOV A, R4	; Load HB of Divisor
	RLC A		; Rotate left w Carry
	MOV R4, A	; Store rotated HB back
	
	MOV A, R6	; Load rotated HB of Dividend
	SUBB A, R5	; Subtract with LB of Divisor
	
	MOV A, R4	; Load rotated HB of Divisor
	SUBB A, R0	; Subtract with original HB of Divisor
	JC DIV_JMP3	; Jump if borrow happened, meaning R4(00) < R0 (HB-sor)
	MOV R4, A	; Store difference to R4
	
	MOV A, R6	; Load HB of Dividend
	SUBB A, R5	; Subtract HB-end with LB-sor
	
	MOV R6, A	; Store difference to R6
	INC R7		; Add 1 to LB-end
DIV_JMP3:
	DJNZ B, DIV_LOOP1 	; Repeat 8 times
	CLR A		; Clear A
	XCH A, R6	; Exchange with difference
	MOV R5, A	; Store difference to R5, aka Remainder
RET
DIV_JMP2:
	MOV A, R5	; Load LB-sor
	MOV R0, A	; Store LB-sor to R0
	MOV B, A	; Store LB-sor to B
	MOV A, R6	; Load HB-end
	DIV AB		; HB-end/LB-sor
	JB OV, DIV_JMP4	; Jump if division with 0 happened
	MOV R6, A	; Store quotient to R6
	MOV R5, B	; Store remainder to R5

	MOV B, #08H
DIV_LOOP2:
	MOV A, R7	; Load LB-end
	ADD A, R7	; Add with itself
	MOV R7, A	; Store sum to R7
	
	MOV A, R5	; Load remainder
	RLC	A		; Rotate left w carry
	MOV R5, A	; Store rotated value back
	JC DIV_JMP5
	
	SUBB A, R0	; Subtract rotated value - LB-sor
	JNC DIV_JMP6
	DJNZ B, DIV_LOOP2
RET
DIV_JMP5:
	CLR C
	SUBB A, R0
DIV_JMP6:
	MOV R5, A
	INC R7
	DJNZ B, DIV_LOOP2
DIV_JMP4:
RET
	CLR LCD_RW
	MOV LCD_DATAPINS, R7
	MOV R7, #01H
	MOV R6, #00H
	LCALL DELAY_1MS
	SETB LCD_EN
	MOV R7, #05H
	MOV R6, #00H

LCD_DISPLAY_NUMBERS:
	MOV R3, 11H
	MOV R2, 10H
	
	MOV R4, #03H
	MOV R5, #0E8H	; 03E8H = 1000D
	MOV R7, 03H
	MOV R6, 02H
	LCALL DIVISION	
	MOV R4, #00H
	MOV R5, #0AH
	LCALL DIVISION
	MOV 1CH, R5		; Move thousands place to 0CH
	
	MOV R4, #00H
	MOV R5, #64H	;0064H = 100D
	MOV R7, 03H
	MOV R6, 02H
	LCALL DIVISION	
	MOV R4, #00H
	MOV R5, #0AH
	LCALL DIVISION
	MOV 1DH, R5		; Move hundreds place to 0DH
	
	MOV R4, #00H
	MOV R5, #0AH	
	MOV R7, 03H
	MOV R6, 02H
	LCALL DIVISION	
	MOV R4, #00H
	MOV R5, #0AH
	LCALL DIVISION
	MOV 1EH, R5		; Move tens place to 0EH
	
	MOV R6, 02H
	MOV R7, 03H
	MOV R4, #00H
	MOV R5, #0AH
	LCALL DIVISION
	MOV 1FH, R5		; Move ones place to 0FH
	
	MOV A, 01CH		; Move thousands to A
	ADD A, #30H		; Add 30H
	MOV R7, A
	MOV 1CH, A
	LCALL LCD_WRD
	
	MOV A, 01DH		; Move hundreds to A
	ADD A, #30H		; Add 30H
	MOV R7, A
	MOV 1DH, A
	LCALL LCD_WRD
	
	MOV A, 01EH		; Move tens to A
	ADD A, #30H		; Add 30H
	MOV R7, A
	MOV 1EH, A
	LCALL LCD_WRD
	
	MOV A, 01FH		; Move ones to A
	ADD A, #30H		; Add 30H
	MOV R7, A
	MOV 1FH, A
	LJMP LCD_WRD
	
DELAY:
	SETB C
	MOV A, R7
	SUBB A, #00H
	MOV A, R6
	SUBB A, #00H
DELAY_HERE:
	JC DELAY_DONE
	CLR A
	MOV R5, A
	MOV R4, A
DELAY_AGAIN:
	INC R5
	CJNE R5, #00H, DELAY_SKIP
	INC R4
DELAY_SKIP:
	CJNE R4, #01H, DELAY_AGAIN
	CJNE R5, #0F4H, DELAY_AGAIN
	MOV A, R7
	DEC R7
	JNZ DELAY
	DEC R6
	SJMP DELAY
DELAY_DONE:
RET

MOV R7, #38H

DELAY_1MS:	; A delay function with parameters R6 and R7
	SETB C
	MOV A, R7
	SUBB A, #00H
	MOV A, R6
	SUBB A, #00H
	JC DELAY_1MS_DONE
		MOV R5, #0C7H
	H1:	MOV R4, #01H
	H2:	DJNZ R4, H2
		DJNZ R5, H1
	MOV A, R7
	DEC R7
	JNZ DELAY_1MS
	DEC R6
	SJMP DELAY_1MS
DELAY_1MS_DONE:
RET
	
LCD_WRC: ; LCD Write Command
	CLR LCD_EN
	CLR LCD_RS
	CLR LCD_RW
	
	MOV P0, R7
	MOV R7, #01H
	MOV R6, #00H
	ACALL DELAY_1MS
	
	SETB LCD_EN
	MOV R7, #05H
	MOV R6, #00H
	ACALL DELAY_1MS
	
	CLR LCD_EN
RET

LCD_WRD: ; LCD Write Data
	CLR LCD_EN
	SETB LCD_RS
	CLR LCD_RW
	
	MOV LCD_DATAPINS, R7
	MOV R7, #01H
	MOV R6, #00H
	ACALL DELAY_1MS
	
	SETB LCD_EN
	MOV R7, #05H
	MOV R6, #00H
	ACALL DELAY_1MS
	
	CLR LCD_EN
RET

LCD_INIT:
	MOV R7, #38H	;Function Set: 8-bit data, 2-line display, 5x8 font
	LCALL LCD_WRC
	MOV R7, #0CH	;Display On/Off Control: Display on, cursor off, blink off
	LCALL LCD_WRC
	MOV R7, #06H	;Entry Mode Set: Increment cursor position, no display shift
	LCALL LCD_WRC
	MOV R7, #01H	;Clear Display
	LCALL LCD_WRC
	MOV R7, #80H	;Set DDRAM Address: Set cursor to beginning of first line
	LCALL LCD_WRC
RET
END1:
END	