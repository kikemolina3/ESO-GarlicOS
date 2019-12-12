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
	push {lr}
	push {r0-r9,lr}
	ldr r3,[r0,#32]		@;Cargamos en r3 header.e_shoff
	add r4, r0, r3		@;Cargamos en r4 la direccion de memoria del primer byte de la tabla de secciones
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
	mov r10,#0
.LRecorrerSeccion:
	add r8,#8
	ldr r9,[r8,#4]		@;Cargamos en r9 r_info
	and r9,#0xF			@;Nos quedamos con el tipo de reubicacion
	cmp r9,#2	
	bne .LNoReubicadorAdecuado
	ldr r9,[r8]   		@;Cargamos en r9 el offset de la direccion a reubicar
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
	pop {r0-r9,pc}

	pop {pc}


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
	push {lr}
	

	pop {pc}


	.global _gm_liberarMem
	@; Rutina para liberar todas las franjas de memoria asignadas al proceso
	@; del zócalo indicado por parámetro; también se encargará de invocar a la
	@; rutina _gm_pintarFranjas(), para actualizar la representación gráfica
	@; de la ocupación de la memoria de procesos.
	@;Parámetros:
	@;	R0: el número de zócalo que libera la memoria
_gm_liberarMem:
	push {lr}


	pop {pc}


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
	push {lr}


	pop {pc}



	.global _gm_rsiTIMER1
	@; Rutina de Servicio de Interrupción (RSI) para actualizar la representa-
	@; ción de la pila y el estado de los procesos activos.
_gm_rsiTIMER1:
	push {lr}


	pop {pc}


.end

