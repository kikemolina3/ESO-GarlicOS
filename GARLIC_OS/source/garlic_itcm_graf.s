﻿@;==============================================================================
@;
@;	"garlic_itcm_graf.s":	código de rutinas de soporte a la gestión de
@;							ventanas gráficas (versión 1.0)
@;
@;==============================================================================

NVENT	= 16					@; número de ventanas totales
PPART	= 4 				@; número de ventanas horizontales o verticales
							@; (particiones de pantalla)
L2_PPART = 2				@; log base 2 de PPART

VCOLS	= 32				@; columnas y filas de cualquier ventana
VFILS	= 24
PCOLS	= VCOLS * PPART		@; número de columnas totales (en pantalla)
PFILS	= VFILS * PPART		@; número de filas totales (en pantalla)

WBUFS_LEN = 68				@; longitud de cada buffer de ventana (32+4)

BASE = 0x06000000

BASE_SUB = 0x06200000

.section .itcm,"ax",%progbits

	.arm
	.align 2

	.global _gg_escribirLinea
	@; Rutina para escribir toda una linea de caracteres almacenada en el
	@; buffer de la ventana especificada;
	@;Parámetros:
	@;	R0: ventana a actualizar (int v)
	@;	R1: fila actual (int f)
	@;	R2: número de caracteres a escribir (int n)
_gg_escribirLinea:
	push {r0 - r8, lr}
	ldr r3, =_gd_wbfs			@; r3 = @inicial vector _gd_wbufs
	mov r4, #WBUFS_LEN			@; r4 = 36
	mul r5, r4, r0				@; r5 = nro ventana * WBUFS_LEN
	add r5, #4					@; r5 = nro ventana * WBUFS_LEN + 4
	add r5, r3					@; r5 = _gd_wbfs + nro ventana * WBUFS_LEN + 4 // r5 = @buffer ventana especifica
	mov r7, r1					@; r7 = fila actual
	mov r8, r2					@; r8 = num_caracteres escribir
	bl _gg_calcIniFondo
	mov r2, r0
	mov r3, #2*PCOLS	
	mul r3, r7					@; r3 = 1er pixel ventana + PCOLS*2*fila (1er pos. linea a escribir)
	add r2, r3					@; r2 = pos.escritura
	mov r6, #0					@; r6 = despl buffer
	mov r4, #2 										
	mul r8, r4
.Lbuclebuffer:
	cmp r6, r8
	beq .Lfinal					@; si despl buffer == num_caracteres escribir ACABA
	ldrh r1, [r5, r6]			@; r1 = cod. ASCII caracter
	sub r1, #32					@; resta 32 a r1 para tener cod. baldosa
	strh r1, [r2, r6]			@; modifica indice de baldosa en donfo
	add r6, #2					@; incrementos
	b .Lbuclebuffer				@; iteración
.Lfinal:
	pop {r0 - r8, pc}


	.global _gg_desplazar
	@; Rutina para desplazar una posición hacia arriba todas las filas de la
	@; ventana (v), y borrar el contenido de la última fila
	@;Parámetros:
	@;	R0: ventana a desplazar (int v)
_gg_desplazar:
	push {r0 - r7, lr}
	bl _gg_calcIniFondo
	mov r1, r0					@; r1 = 1er pos ventana
	mov r2, #2*VCOLS
	mov r5, #2*PCOLS
	mov r7, #0
	mov r6, #VFILS
.Lrepeat:
	cmp r6, r7
	beq .Lfin_copia				@; si nro_interaciones == VFILS
	add r0, r1, r5				@; @fuente = @fuente + 1 linea
	bl _gs_copiaMem				@; desplaza linea hacia arriba
	add r7, #1
	mov r1, r0					@; @fuente ==> @destino
	b .Lrepeat
.Lfin_copia:	
	sub r1, r5					@; @ultima_linea, tratamiento rellanando posiciones con caracteres en blanco
	mov r5, #0					@; r5 = 0 = cont_posiciones
	mov r6, #VCOLS				@; r6 = VCOLS
	mov r7, #0					@; r7 = desplazamiento sobre ultima linea
.Lrepeat2:
	cmp r5, r6
	beq .Lfin_ultima			@; si cont_posiciones==VCOLS, ACABA
	mov r2, #0		
	strh r2, [r1, r7]			@; escribe 0 (caracter blanco) en ultima linea
	add r5, #1					@; cont_posiciones++
	add r7, #2					@; incremento despl sobre fondo
	b .Lrepeat2
.Lfin_ultima:
	pop {r0 - r7, pc}


	.global _gg_fijarBaldosa
_gg_fijarBaldosa:
	push {lr}
	strh r2, [r0, r1]
	pop {pc}
	
	.global _gg_cambiaColor
	@;	Rutina que cambia el color de la fuente segun reciba por parametro
	@; Parámetros:
	@;		r0 = @inicial de la fuente
	@;		r1 = tamaño del bloque de datos
	@;		r2 = color
_gg_cambiaColor:
	push {r0-r6, lr}
	mov r6, #0
.Lrep:
	ldrh r3, [r0, r6]				@; r3 = 2 bytes de color a analizar
	and r4, r3, #0xff				@; byte bajo
	and r5, r3, #0xff00				@; byte alto
	cmp r4, #0
	beq .L1
	mov r4, r2
.L1:
	cmp r5, #0
	beq .L2
	mov r5, r2, lsl #8
.L2:
	orr r3, r4, r5
	strh r3, [r0, r6]
	add r6, #1
	cmp r6, r1
	blo .Lrep
	pop {r0-r6, pc}
	
	.global _gg_calcIniFondo
	@;  Rutina que obtiene la dir. de memoria con la primera baldosa de la 
	@;  ventana pasada por parámetro
	@; Parámetros:
	@; 		r0 = ventana
	@; Retorna: 
	@; 		r0 --> @memoria 1a baldosa de ventana
_gg_calcIniFondo:
	push {r1 - r7, lr}
	ldr r1, =BASE							@; dir. inicial fondo escritura
	mov r2, #1
	mov r2, r2, lsl #L2_PPART
	sub r2, #1								@; r2 = mascara columna
	and r4, r2, r0							@; r4 = columna
	mov r2, r2, lsl #L2_PPART				@; r2 = mascara fila
	and r5, r2, r0							
	mov r5, r5, lsr #L2_PPART				@; r5 = fila
	mov r6, #PCOLS*VFILS*2	
	mul r2, r5, r6							@; r2 = 2*PCOLS*VFILS*fila
	mov r6, #VCOLS*2
	mul r3, r4, r6							@; r3 = 2*VCOLS*columna
	add r2, r3								
	add r0, r1, r2							@; r0 = dir. mem. 1er baldosa de la ventana especificada
	pop {r1 - r7, pc}
	
	
	.global _gg_escribirLineaTabla
	@; escribe los campos básicos de una linea de la tabla correspondiente al
	@; zócalo indicado por parámetro con el color especificado; los campos
	@; son: número de zócalo, PID, keyName y dirección inicial
	@;Parámetros:
	@;	R0 (z)		->	número de zócalo
	@;	R1 (color)	->	número de color (de 0 a 3)
_gg_escribirLineaTabla:
	push {r0-r12, lr}
	mov r10, r0
	mov r2, #(32*4+6)*2			@; desplazamiento hasta 1er pixel zocalo 0
	ldr r3, =BASE_SUB
	add r3, r2					@; primer pixel zocalo 0
	ldr r4, =_gd_pcbs
	mov r2, #6*4				@; tamaño de 1 entrada de _gd_pcbs 
	mla r4, r0, r2, r4			@; r4 = dir. mem _gd_pcbs[z]	
	mov r12, #128
	mul r12, r1
	@; OBTENCION E IMPRESION PID
	mov r11, r4
	ldr r5, [r4]				@; r5 = PID
	sub sp, #12
	mov r0, sp					@; r0 = dir. mem. *char con PID
	mov r8, sp				
	add sp, #12					@; restaurar pila
	mov r1, #3					@; longitud 3 (2 cifras + '\0')
	mov r2, r5					@; r2 = PID
	bl _gs_num2str_dec
	mov r4, #32*2
	mul r4, r10
	add r3, r4					@; r3 = posicion ESCRITURA PID
.Ly:
	ldrb r7, [r8]
	cmp r7, #0
	beq .Lx
	sub r7, #32
	add r7, r12
	strh r7, [r3]
	add r8, #1
	add r3, #2
	b .Ly
.Lx:
	add r3, #2
	@; OBTENCION E IMPRESION KEYNAME
	add r11, #16
	mov r2, #0
.Literachar:
	ldrb r7, [r11]
	sub r7, #32
	add r7, r12
	strh r7, [r3]
	add r3, #2
	add r11, #1
	add r2, #1
	cmp r2, #4
	blo .Literachar
	pop {r0-r12, pc}


	.global _gg_escribirCar
	@; escribe un carácter (baldosa) en la posición de la ventana indicada,
	@; con un color concreto;
	@;Parámetros:
	@;	R0 (vx)		->	coordenada x de ventana (0..31)
	@;	R1 (vy)		->	coordenada y de ventana (0..23)
	@;	R2 (car)	->	código del caràcter, como número de baldosa (0..127)
	@;	R3 (color)	->	número de color del texto (de 0 a 3)
	@; pila (vent)	->	número de ventana (de 0 a 15)
_gg_escribirCar:
	push {r0-r5, lr}
	mov r4, r0					@; r4 = coordenada X
	add sp, #4*7				@; 4bytes * 7 pos. memoria (6 regs + lr)
	ldr r0, [sp]				@; localizacion de 5to parametro
	sub sp, #4*7
	bl _gg_calcIniFondo
	mov r5, #PCOLS*2
	mul r5, r1					@; r5 = VCOLS * 2 * columnas previas	
	mov r1, #2
	mul r4, r1					@; r4 = 2 * coordenada X
	add r5, r4					@; posicionamiento en ventana
	add r5, r0					@; r5 = @inicial + desplazamiento --> baldosa a escribir	
	mov r1, #128
	mla r2, r3, r1, r2  		@; r2 = codigo baldosa a escribir
	strh r2, [r5]
	pop {r0-r5, pc}


	.global _gg_escribirMat
	@; escribe una matriz de 8x8 carácteres a partir de una posición de la
	@; ventana indicada, con un color concreto;
	@;Parámetros:
	@;	R0 (vx)		->	coordenada x inicial de ventana (0..31)
	@;	R1 (vy)		->	coordenada y inicial de ventana (0..23)
	@;	R2 (m)		->	puntero a matriz 8x8 de códigos ASCII (dirección)
	@;	R3 (color)	->	número de color del texto (de 0 a 3)
	@; pila	(vent)	->	número de ventana (de 0 a 15)
_gg_escribirMat:
	push {r0-r8, lr}
	mov r4, r0					@; r4 = coordenada X
	add sp, #4*10				@; 4bytes * 10 pos. memoria (9 regs + lr)
	ldr r0, [sp]				@; localizacion de 5to parametro
	sub sp, #4*10
	bl _gg_calcIniFondo
	mov r5, #PCOLS*2
	mul r5, r1					@; r5 = PCOLS * 2 * filas previas	
	mov r1, #2
	mul r4, r1					@; r4 = 2 * coordenada X
	add r5, r4					@; posicionamiento en ventana
	add r5, r0					@; r5 = @inicial + desplazamiento --> baldosa a escribir
	mov r1, #128
	mul r3, r1					@; r3 = desplazamiento a sumar de baldosas
	mov r8, #0					@; r8 = contador de col
.Literacol:
	mov r6, #0					@; r6 = contador de fila
.Literafila:
	cmp r6, #8				
	bhs .Lfinfila				
	ldrb r7, [r2]				@; r7 = cod. ASCII de caracter
	cmp r7, #32	
	blo .Lnoescribible			@; comprobacion codigo escribible
	sub r7, #32
	add r7, r3					@; suma desplz. color
	strh r7, [r5]				@; escritura baldosa en pantalla
.Lnoescribible:
	add r5, #2					@; @mem fondo2 + 2
	add r6, #1					@; fila++
	add r2, #1					@; @matriz a escribir + 1 (siguiente caracter)
	b .Literafila
.Lfinfila:
	add r5, #2*PCOLS-16			@; salto linea a 1a pos 
	add r8, #1					@; columna++
	cmp r8, #8
	blo .Literacol
	pop {r0-r8, pc}


	.global _gg_rsiTIMER2
	@; Rutina de Servicio de Interrupción (RSI) para actualizar la representa-
	@; ción del PC actual.
_gg_rsiTIMER2:
	push {lr}


	pop {pc}
	
.end

