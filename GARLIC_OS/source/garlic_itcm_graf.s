@;==============================================================================
@;
@;	"garlic_itcm_graf.s":	código de rutinas de soporte a la gestión de
@;							ventanas gráficas (versión 1.0)
@;
@;==============================================================================

NVENT	= 4					@; número de ventanas totales
PPART	= 2					@; número de ventanas horizontales o verticales
							@; (particiones de pantalla)
L2_PPART = 1				@; log base 2 de PPART

VCOLS	= 32				@; columnas y filas de cualquier ventana
VFILS	= 24
PCOLS	= VCOLS * PPART		@; número de columnas totales (en pantalla)
PFILS	= VFILS * PPART		@; número de filas totales (en pantalla)

WBUFS_LEN = 36				@; longitud de cada buffer de ventana (32+4)

.section .itcm,"ax",%progbits

	.arm
	.align 2
	
_coc_:	.word 0
_res_:  .word 0 


	.global _gg_escribirLinea
	@; Rutina para escribir toda una linea de caracteres almacenada en el
	@; buffer de la ventana especificada;
	@;Parámetros:
	@;	R0: ventana a actualizar (int v)
	@;	R1: fila actual (int f)
	@;	R2: número de caracteres a escribir (int n)
_gg_escribirLinea:
	push {r0-r12, lr}
	ldr r3, =_gd_wbfs
	mov r4, #WBUFS_LEN
	mul r5, r4, r0
	@;ldrb r4, [r5, #4]			@; r5 = dir. inicial WBUF ventana correspondiente
	add r5, #4
	add r12, r5, r3
	@; hallar pos inicial ventana			2*(PCOLS*VFILS*coc + VCOLS*res);
	
	ldr r4, =0x06002000			@; r3 = dir base fondo 2
	mov r8, r0					@; r8 = ventana
	mov r9, r1					@; r9 = fila actual
	mov r10, r2					@; r10 = num caracteres escribir
	mov r1, #PPART
	ldr r2, =_coc_
	ldr r3, =_res_
	bl _ga_divmod
	mov r5, #PCOLS
	mov r6, #VFILS
	mul r7, r5, r6
	ldr r3, [r3]
	ldr r2, [r2]
	mul r6, r7, r2				@; r6 = PCOLS*VFILS*coc
	mov r11, #VCOLS
	mul r3, r11, r3
	add r6,r3
	mov r5, #2
	mla r5, r6 ,r5, r4				@; r5 = 1er pixel ventana
	
	mov r6, #0
	mov r7,#0
.Lbuclebuffer:
	cmp r6,r10
	beq .Lfinal
	
	ldrb r11, [r12, r6]
	sub r11, #32
	@;mov r11, #40
	strh r11, [r5, r7]
	

	add r6,#1
	add r7,#2
	b .Lbuclebuffer
	
.Lfinal:
	pop {r0-r12, pc}


	.global _gg_desplazar
	@; Rutina para desplazar una posición hacia arriba todas las filas de la
	@; ventana (v), y borrar el contenido de la última fila
	@;Parámetros:
	@;	R0: ventana a desplazar (int v)
_gg_desplazar:
	push {lr}


	pop {pc}


	.global _gg_fijarBaldosa
_gg_fijarBaldosa:
	push {lr}
	strh r2, [r0,r1]
	pop {pc}

.end

