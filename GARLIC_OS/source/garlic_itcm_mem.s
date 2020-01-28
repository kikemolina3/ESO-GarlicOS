@;==============================================================================
@;
@;	"garlic_itcm_mem.s":	código de rutinas de soporte a la carga de
@;							programas en memoria (version 2.0)
@;
@;==============================================================================

NUM_FRANJAS = 768
INI_MEM_PROC = 0x01002000


.section .dtcm,"wa",%progbits
	.align 2

	.global _gm_zocMem
_gm_zocMem:	.space NUM_FRANJAS			@; vector de ocupación de franjas mem.
	

.section .itcm,"ax",%progbits

	.arm
	.align 2


	.global _gm_reubicar
	@; Rutina de soporte a _gm_cargarPrograma(), que interpreta los 'relocs'
	@; de un fichero ELF, contenido en un buffer *fileBuf, y ajustar las
	@; direcciones de memoria correspondientes a las referencias de tipo
	@; R_ARM_ABS32, a partir de las direcciones de memoria destino de código
	@; (dest_code) y datos (dest_data), y según el valor de las direcciones de
	@; las referencias a reubicar y de las direcciones de inicio de los
	@; segmentos de código (pAddr_code) y datos (pAddr_data)
	@;Parámetros:
	@; R0: dirección inicial del buffer de fichero (char *fileBuf)
	@; R1: dirección de inicio de segmento de código (unsigned int pAddr_code)
	@; R2: dirección de destino en la memoria (unsigned int *dest_code)
	@; R3: dirección de inicio de segmento de datos (unsigned int pAddr_data)
	@; (pila): dirección de destino en la memoria (unsigned int *dest_data)
	@;Resultado:
	@; cambio de las direcciones de memoria que se tienen que ajustar
_gm_reubicar:
	push {r0-r12,lr}
	ldr r4,[sp,#14*4]	@;PONEMOS DIRECCIONES ARRIBA DE LA PILA
	push {r1,r2,r3,r4}
	
	ldr r3,[r0,#28]		@;COGEMOS DIRECCION FINAL DEL pAddr_code
	add r3,r0
	ldr r3,[r3,#16]
	add r3,r1

	ldr r4,[r0,#32]		@;Cargamos en r3 header.e_shoff
	add r4, r0			@;Cargamos en r4 la direccion de memoria del primer byte de la tabla de secciones
	ldrh r5,[r0,#48] 	@;Cargamos en r5 el num de secciones
	ldrh r6,[r0,#46]	@;Cargamos en r6 el tamaño de cada seccion
	mov r7,#0
.LRecorrerSecciones:
	mla r8,r6,r7,r4  	@;Cargamos en r8 la posicion del primer byte de la seccion
	ldr r9,[r8,#4]		@;Cargamos en r9 tipo de seccion
	cmp r9,#9
	bne .LNoSeccionRel
	ldr r10,[r8,#16]	@;Cargamos en r10 el offset de los relocs
	add r10, r0, r10
	ldr r11,[r8,#20]	@;Cargamos en r11 el tamaño de la seccion
	mov r12,r11,lsr#3
	mov r11,r12
	mov r8, r10
	mov r10,#1
.LRecorrerSeccion:
	add r8,#8
	ldr r9,[r8,#4]		@;Cargamos en r9 r_info
	and r9,#0xF			@;Nos quedamos con el tipo de reubicacion
	cmp r9,#2	
	bne .LNoReubicadorAdecuado
	ldr r9,[r8]   		@;Cargamos en r9 el offset de la direccion a reubicar
	cmp r9,r3
	blt .Lcodigo
	ldr r1,[sp,#8]
	ldr r2,[sp,#12]
	b .LReubicar
.Lcodigo:
	ldr r1,[sp]
	ldr r2,[sp,#4]
.LReubicar:
	sub r9,r1
	ldr r12,[r2,r9]
	sub	r12,r1
	add r12,r2
	str r12,[r2,r9]
.LNoReubicadorAdecuado:
	add r10,#1
	cmp r10,r11
	blt .LRecorrerSeccion
.LNoSeccionRel:
	add r7,#1
	cmp r7,r5
	blt .LRecorrerSecciones
	pop {r0-r3}
	pop {r0-r12,pc}


	.global _gm_reservarMem
	@; Rutina para reservar un conjunto de franjas de memoria libres
	@; consecutivas que proporcionen un espacio suficiente para albergar
	@; el tamaño de un segmento de código o datos del proceso (según indique
	@; tipo_seg), asignado al número de zócalo que se pasa por parámetro;
	@; también se encargará de invocar a la rutina _gm_pintarFranjas(), para
	@; representar gráficamente la ocupación de la memoria de procesos;
	@; la rutina devuelve la primera dirección del espacio reservado; 
	@; en el caso de que no quede un espacio de memoria consecutivo del
	@; tamaño requerido, devuelve cero.
	@;Parámetros:
	@;	R0: el número de zócalo que reserva la memoria
	@;	R1: el tamaño en bytes que se quiere reservar
	@;	R2: el tipo de segmento reservado (0 -> código, 1 -> datos)
	@;Resultado:
	@;	R0: dirección inicial de memoria reservada (0 si no es posible)
_gm_reservarMem:
	push {r1-r8,lr}
	mov r3,#0
	mov r4,r1		
.LFor:				@;Buscamos cuantos bloques del vector se necesitan
	sub r4,#32
	add r3,#1
	cmp r4,#0
	bgt .LFor

	ldr r4,=_gm_zocMem
	mov r5,#0		@;contador de franjas (r5<768)
	mov r6,#0		@;contador de franjas libres 
.LPerFranja:
	ldrb r7,[r4,r5]
	cmp r7,#0
	addeq r6,#1
	movne r6,#0
	cmp r6,#1		@;Si trobem primera posicio lliure guardem POSICIO
	moveq r8,r5	
	cmp r6,r3		@;Si trobem espai suficientment gran
	beq .LHayEspacio
	add r5,#1
	cmp r5,#NUM_FRANJAS
	blt .LPerFranja
	b .LNoEspacio
.LHayEspacio:
	mov r5,#0
	add r4,r8		@;Nos situamos en la primera franja
.LIntroduceFranja:
	strb r0,[r4,r5]
	add r5,#1
	cmp r5,r3
	blt .LIntroduceFranja
	mov r1,r8
	mov r3,r2
	mov r2,r6
	bl _gm_pintarFranjas
	ldr r6,=INI_MEM_PROC
	add r5,r6,r8,lsl#5
	mov r0,r5
	b .LFin
.LNoEspacio:
	mov r0,#0
.LFin:
	
	pop {r1-r8,pc}


	.global _gm_liberarMem
	@; Rutina para liberar todas las franjas de memoria asignadas al proceso
	@; del zócalo indicado por parámetro; también se encargará de invocar a la
	@; rutina _gm_pintarFranjas(), para actualizar la representación gráfica
	@; de la ocupación de la memoria de procesos.
	@;Parámetros:
	@;	R0: el número de zócalo que libera la memoria
_gm_liberarMem:
	push {r1-r9,lr}
	ldr r1,=_gm_zocMem
	mov r2,#0			@;Contador de franjas
	ldr r3,=NUM_FRANJAS
	mov r4,#0			@;Contiene el valor 0
	mov r6,#0			@;Comprueba cuando empieza un bloque
	mov r8,#0			@;Numero de franjas a pintar
	mov r9,#0			@;Booleano (codigo o datos)
.Lperfranja:
	ldrb r5,[r1,r2]
	cmp r5,r0
	bne .Lnofranja		@;Si no es franja del zocalo
	cmp r6,#0
	bne .Lnoprimera     @;Si no es la primera franja del bloque
	add r6,#1
	mov r7,r2
.Lnoprimera:
	add r8,#1
	strb r4,[r1,r2]
	b .Lnoencontrado
.Lnofranja:
	cmp r6,#0
	beq .Lnoencontrado	@;Si todavia no hemos encontrado la primera franja del bloque
	mov r6,#0
	push {r0-r3}
	mov r0,#0
	mov r1,r7
	mov r2,r8
	cmp r9,#0
	mov r3,#1
	bne .Ldatos		@;Si r9 no es 0, es un segmento de datos, ya que no es el primero
	mov r3,#0
	add r9,#1
.Ldatos:
	bl _gm_pintarFranjas
	mov r8,#0
	pop {r0-r3}
.Lnoencontrado:
	add r2,#1
	cmp r2,r3
	blt .Lperfranja
	pop {r1-r9,pc}


	.global _gm_pintarFranjas
	@; Rutina para para pintar las franjas verticales correspondientes a un
	@; conjunto de franjas consecutivas de memoria asignadas a un segmento
	@; (de código o datos) del zócalo indicado por parámetro.
	@;Parámetros:
	@;	R0: el número de zócalo que reserva la memoria (0 para borrar)
	@;	R1: el índice inicial de las franjas
	@;	R2: el número de franjas a pintar
	@;	R3: el tipo de segmento reservado (0 -> código, 1 -> datos)
_gm_pintarFranjas:
	push {r0-r11,lr}
	

	mov r4,#0x6200000    	@;R4=Base mapa caracteres    
	add r4,#0xc000			@;tile num: 768 * 64 bytes baldosa
	
	ldr r5,=_gs_colZoc
	ldrb r9,[r5,r0]			@;R9= Cogemos color (bits bajos)
	mov r10,r9,lsl#8		@;R10= Color bits altos
	
	mov r6, r1				@;R6= bit (1 para marcar bits altos 0 para marcar bits bajos)
	mov r5,#0				@;R5= Num baldosas a saltar
	mov r7,#0				@;R7= resto que saltaremos
.LnBaldJump:
	cmp r6,#8
	blt .LnFranjJump
	sub r6,#8
	add r5,#1
	b .LnBaldJump	
	
.LnFranjJump:
	cmp r6,#2
	blt .LCalcOff
	sub r6,#2
	add r7,#2
	b .LnFranjJump
	
.LCalcOff:
	mov r5,r5,lsl#6			@;Calculamos numero de bytes a desplazar
	add r4,r5				@;R4= Primer byte de la baldosa a pintar
	add r4,r7				@;R4= Primer byte a pintar
	mov r8,#0				@;R8= Contador de franjas

	cmp r3,#0
	beq .LCodigo
.LDatos:
	
	cmp r6,#1
	beq .LBitsAltosD
							@;Se pintan los bits 1 y 3 de la franja izquierda del conjunto
	ldrh r11,[r4,#16]
	and r11,#0xFF00
	orr r11,r9
	strh r11,[r4,#16]
	ldrh r11,[r4,#32]
	and r11,#0xFF00
	orr r11,r9
	strh r11,[r4,#32]
	add r6,#1
	add r8,#1
	cmp r8,r2
	blt .LDatos
	b .Lfin
	
.LBitsAltosD:				@;Se pintan los bits 2 y 4 de la franja derecha del conjunto
	ldrh r11,[r4,#24]
	and r11,#0xFF
	orr r11,r10
	strh r11,[r4,#24]
	ldrh r11,[r4,#40]
	and r11,#0xFF
	orr r11,r10
	strh r11,[r4,#40]
	cmp r7,#6
	bne .LnofinalD
	add r4,#56
	mov r7,#-2
.LnofinalD:
	add r4,#2
	sub r6,#1
	add r8,#1
	add r7,#2
	cmp r8,r2
	blt .LDatos
	
	
	
.LCodigo:
	cmp r6,#1
	beq .LBitsAltosC
						@;Se pinta la franja izquierda del conjunto
	ldrh r11,[r4,#16]
	and r11,#0xFF00
	orr r11,r9
	strh r11,[r4,#16]
	ldrh r11,[r4,#24]
	and r11,#0xFF00
	orr r11,r9
	strh r11,[r4,#24]
	ldrh r11,[r4,#32]
	and r11,#0xFF00
	orr r11,r9
	strh r11,[r4,#32]
	ldrh r11,[r4,#40]
	and r11,#0xFF00
	orr r11,r9
	strh r11,[r4,#40]
	add r6,#1
	add r8,#1
	cmp r8,r2
	blt .LCodigo
	b .Lfin
	
.LBitsAltosC:				@;Se pinta la franja derecha del conjunto
	ldrh r11,[r4,#16]
	and r11,#0xFF
	orr r11,r10
	strh r11,[r4,#16]
	ldrh r11,[r4,#24]
	and r11,#0xFF
	orr r11,r10
	strh r11,[r4,#24]
	ldrh r11,[r4,#32]
	and r11,#0xFF
	orr r11,r10
	strh r11,[r4,#32]
	ldrh r11,[r4,#40]
	and r11,#0xFF
	orr r11,r10
	strh r11,[r4,#40]
	cmp r7,#6
	bne .LnofinalC
	add r4,#56
	mov r7,#-2
.LnofinalC:
	add r4,#2
	sub r6,#1
	add r8,#1
	add r7,#2
	cmp r8,r2
	blt .LCodigo
	
.Lfin:	
	pop {r0-r11,pc}



	.global _gm_rsiTIMER1
	@; Rutina de Servicio de Interrupción (RSI) para actualizar la representa-
	@; ción de la pila y el estado de los procesos activos.
_gm_rsiTIMER1:
	push {r0-r12,lr}
	mov r0,#0x6200000
	ldr r1,=0x12e
	add r0,r1
	ldr r1,=_gd_pcbs
	ldr r2,=_gd_stacks
	ldr r3,=0xB003D00
	mov r4,#0
	mov r12,#119
	
.LporProceso:
	mov r11,#0
	cmp r4,#0
	beq .LSO
	mov r5,#24
	mul r5,r4
	ldr r6,[r1,r5]				@;Miramos si PID activo
	cmp r6,#0
	mov r7,r12
	mov r8,r12
	beq .LCambiarBald
	add r5,#8
	ldr r6,[r1,r5]				@;R6= SP
	add r5,r2,r4,lsl#9
	sub r5,r6
.LnConfig:
	cmp r5,#32
	blt .LPonerBald
	sub r5,#32
	add r11,#1
	b .LnConfig


.LSO:
	mov r5,#24
	mul r5,r4
	add r5,#8
	ldr r6,[r1,r5]				@;R6= SP
	cmp r6,#0
	mov r7,r12
	mov r8,r12
	beq .LCambiarBald
	sub r5,r3,r6
.LnConfigSO:
	cmp r5,#61
	blt .LPonerBald
	sub r5,#61
	add r11,#1
	b .LnConfigSO
	
.LPonerBald:	
	cmp r11,#8
	bge .LCompleta
	add r7,r12,r11
	mov r8,r12
	b .LCambiarBald
.LCompleta:
	sub r11,#8
	add r7,r12,#8
	add r8,r12,r11
.LCambiarBald:
	strh r7,[r0]
	add r0,#2
	strh r8,[r0]
	add r0,#4
	mov r11,#0
	strh r11,[r0]
	add r0,#58
	add r4,#1
	cmp r4,#16
	blt .LporProceso
	
	@;AQUI EMPIEZA REPRESENTACION DE ESTADO
	mov r0,#0x6200000
	ldr r1,=0x134
	add r0,r1 
	mov r1,#178			@; R azul
	ldr r2,=_gd_pidz
	and r2,#0xF			@;Nos quedamos con zocalo de proceso RUN
	mov r2,r2,lsl#6
	strh r1,[r0,r2]
	@;Miramos cola de ready
	mov r1,#57			@; Y blanca
	ldr r2,=_gd_qReady
	ldr r3,=_gd_nReady
	ldr r3,[r3]
	mov r4,#0
.LPerProcRdy:
	cmp r3,#0
	beq .LfinRdy
	ldrb r5,[r2,r4]
	mov r5,r5,lsl#6
	strh r1,[r0,r5]
	add r4,#1
	sub r3,#1
	b .LPerProcRdy
.LfinRdy:
	mov r1,#34			@; B blanca
	ldr r2,=_gd_qDelay
	ldr r3,=_gd_nDelay
	ldr r3,[r3]
	mov r4,#0
.LPerProcDly:
	cmp r3,#0
	beq .LfinDly
	ldrb r5,[r2,r4]
	and r5,#0xFF0000
	mov r5,r5,lsr#7
	strh r1,[r0,r5]
	add r4,#1
	sub r3,#1
	b .LPerProcDly
.LfinDly:
	
	pop {r0-r12,pc}


.end

