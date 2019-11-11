@;==============================================================================
@;
@;	"garlic_itcm_graf.s":	código de rutinas de soporte a la gestión de
@;							ventanas gráficas (versión 1.0)
@;
@;==============================================================================

NVENT	= 4					@; número de ventanas totales
PPART	= 2 				@; número de ventanas horizontales o verticales
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

	.global _gg_escribirLinea
	@; Rutina para escribir toda una linea de caracteres almacenada en el
	@; buffer de la ventana especificada;
	@;Parámetros:
	@;	R0: ventana a actualizar (int v)
	@;	R1: fila actual (int f)
	@;	R2: número de caracteres a escribir (int n)
_gg_escribirLinea:
	push {r0-r8,lr}
	ldr r3,=_gd_wbfs			@; r3 = @inicial vector _gd_wbufs
	mov r4,#WBUFS_LEN			@; r4 = 36
	mul r5,r4,r0				@; r5 = nro ventana * WBUFS_LEN
	add r5,#4					@; r5 = nro ventana * WBUFS_LEN + 4
	add r5,r3					@; r5 = _gd_wbfs + nro ventana * WBUFS_LEN + 4 // r5 = @buffer ventana especifica
	mov r7,r1					@; r7 = fila actual
	mov r8,r2					@; r8 = num_caracteres escribir
	mov r1,#PPART
	sub sp,#4					@; almacenar en pila referencias cociente y resto
	mov r2,sp
	sub sp,#4
	mov r3,sp
	bl _ga_divmod				@; ejecuta div: (n_vent/PPART)
	add sp,#8					@; restaura sp
	ldr r3,[r3]					@; r3 = resto div. // columna ventana
	ldr r2,[r2]					@; r2 = coc. div. // fila ventana
	mov r0,#PCOLS
	mov r1,#VFILS
	mul r4,r0,r1				@; r4 = PCOLS * VFILS
	mul r1,r4,r2				@; r1 = PCOLS*VFILS*coc
	mov r6,#VCOLS
	mul r3,r6,r3				@; r3 = VCOLS * resto
	add r1,r3					@; r1 = PCOLS*VFILS*coc + VCOLS*res
	mov r2,#2
	ldr r4,=0x06002000
	mla r2,r1,r2,r4				@; r2 = 1er pos ventana // @base fondo + 2*(PCOLS*VFILS*coc + VCOLS*res);
	mov r3,#2					
	mov r1,#PCOLS
	mul r3,r1					@; r3 = PCOLS*2*fila	
	mul r3,r7					@; r3 = 1er pixel ventana + PCOLS*2*fila (1er pos. linea a escribir)
	add r2,r3					@; r2 = pos.escritura
	mov r6,#0					@; r6 = despl buffer
	mov r7,#0					@; r7 = despl ventana
.Lbuclebuffer:
	cmp r6,r8
	beq .Lfinal					@; si despl buffer == num_caracteres escribir ACABA
	ldrb r1,[r5,r6]				@; r1 = cod. ASCII caracter
	sub r1,#32					@; resta 32 a r1 para tener cod. baldosa
	mov r0,#96
	cmp r1,r0
	movhs r1,#0					@; si cod. baldosa supera limites, escribe caracter vacio
	strh r1,[r2,r7]				@; modifica indice de baldosa en donfo
	add r6,#1					@; incrementos
	add r7,#2
	b .Lbuclebuffer				@; iteración
.Lfinal:
	pop {r0-r8,pc}


	.global _gg_desplazar
	@; Rutina para desplazar una posición hacia arriba todas las filas de la
	@; ventana (v), y borrar el contenido de la última fila
	@;Parámetros:
	@;	R0: ventana a desplazar (int v)
_gg_desplazar:
	push {r0-r7,lr}
	ldr r4, =0x06002000			@; r4 = @base fondo
	mov r1, #PPART				@; r1 = PPART
	sub sp,#4					@; espacio pila cociente y resto
	mov r2,sp
	sub sp,#4
	mov r3,sp
	bl _ga_divmod				
	add sp,#8					@; restaurar puntero pila
	ldr r3,[r3]					@; r3 = resto div. // columna ventana
	ldr r2,[r2]					@; r2 = coc. div. // fila ventana
	mov r0,#PCOLS
	mov r1,#VFILS
	mul r4,r0,r1				@; r4 = PCOLS * VFILS
	mul r1,r4,r2				@; r1 = PCOLS*VFILS*coc
	mov r6,#VCOLS
	mul r3,r6,r3				@; r3 = VCOLS * resto
	add r1,r3					@; r1 = PCOLS*VFILS*coc + VCOLS*res
	mov r2,#2
	ldr r4,=0x06002000
	mla r2,r1,r2,r4				@; r2 = 1er pos ventana // @base fondo + 2*(PCOLS*VFILS*coc + VCOLS*res);
	mov r1,r2					@; r1 = 1er pos ventana
	mov r4,#2
	mul r2,r6,r4				@; r2 = num_bytes_copiar (2*VCOLS)
	mul r5,r4,r0				@; r5 = 2*pcols (incremento linea)
	mov r7,#0
	mov r6,#VFILS
.Lrepeat:
	cmp r6,r7
	beq .Lfin_dma				@; si nro_interaciones == VFILS
	add r0,r1,r5				@; @fuente = @fuente + 1 linea
	bl _gs_copiaMem				@; desplaza linea hacia arriba
	add r7,#1
	mov r1,r0					@; @fuente ==> @destino
	b .Lrepeat
.Lfin_dma:	
	add r1,r5					@; @ultima_linea, tratamiento rellanando posiciones con caracteres en blanco
	mov r5,#0					@; r5 = 0 = cont_posiciones
	mov r6,#VCOLS				@; r6 = VCOLS
	mov r7,#0					@; r7 = desplazamiento sobre ultima linea
	cmp r5,r6
	beq .Lfin_ultima			@; si cont_posiciones==VCOLS, ACABA
	mov r2,#0		
	strh r2,[r1,r7]				@; escribe 0 (caracter blanco) en ultima linea
	add r5,#1					@; cont_posiciones++
	add r7,#2					@; incremento despl sobre fondo
.Lfin_ultima:
	pop {r0-r7,pc}


	.global _gg_fijarBaldosa
_gg_fijarBaldosa:
	push {lr}
	strh r2,[r0,r1]
	pop {pc}

.end

