@;==============================================================================
@;
@;	"garlic_itcm_mem.s":	código de rutinas de soporte a la carga de
@;							programas en memoria (version 1.0)
@;
@;==============================================================================

.section .itcm,"ax",%progbits

	.arm
	.align 2


	.global _gm_reubicar
	@; rutina para interpretar los 'relocs' de un fichero ELF y ajustar las
	@; direcciones de memoria correspondientes a las referencias de tipo
	@; R_ARM_ABS32, restando la dirección de inicio de segmento y sumando
	@; la dirección de destino en la memoria;
	@;Parámetros:
	@; R0: dirección inicial del buffer de fichero (char *fileBuf)
	@; R1: dirección de inicio de segmento (unsigned int pAddr)
	@; R2: dirección de destino en la memoria (unsigned int *dest)
	@;Resultado:
	@; cambio de las direcciones de memoria que se tienen que ajustar
_gm_reubicar:
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


.end

