@;==============================================================================
@;
@;	"garlic_itcm_proc.s":	código de las funciones de control de procesos (1.0)
@;						(ver "garlic_system.h" para descripción de funciones)
@;
@;==============================================================================

.section .itcm,"ax",%progbits

	.arm
	.align 2
	
	.global _gp_WaitForVBlank
	@; rutina para pausar el procesador mientras no se produzca una interrupción
	@; de retrazado vertical (VBL); es un sustituto de la "swi #5", que evita
	@; la necesidad de cambiar a modo supervisor en los procesos GARLIC
_gp_WaitForVBlank:
	push {r0-r1, lr}
	ldr r0, =__irq_flags
.Lwait_espera:
	mcr p15, 0, lr, c7, c0, 4	@; HALT (suspender hasta nueva interrupción)
	ldr r1, [r0]			@; R1 = [__irq_flags]
	tst r1, #1				@; comprobar flag IRQ_VBL
	beq .Lwait_espera		@; repetir bucle mientras no exista IRQ_VBL
	bic r1, #1
	str r1, [r0]			@; poner a cero el flag IRQ_VBL
	pop {r0-r1, pc}


	.global _gp_IntrMain
	@; Manejador principal de interrupciones del sistema Garlic
_gp_IntrMain:
	mov	r12, #0x4000000
	add	r12, r12, #0x208	@; R12 = base registros de control de interrupciones	
	ldr	r2, [r12, #0x08]	@; R2 = REG_IE (máscara de bits con int. permitidas)
	ldr	r1, [r12, #0x0C]	@; R1 = REG_IF (máscara de bits con int. activas)
	and r1, r1, r2			@; filtrar int. activas con int. permitidas
	ldr	r2, =irqTable
.Lintr_find:				@; buscar manejadores de interrupciones específicos
	ldr r0, [r2, #4]		@; R0 = máscara de int. del manejador indexado
	cmp	r0, #0				@; si máscara = cero, fin de vector de manejadores
	beq	.Lintr_setflags		@; (abandonar bucle de búsqueda de manejador)
	ands r0, r0, r1			@; determinar si el manejador indexado atiende a una
	beq	.Lintr_cont1		@; de las interrupciones activas
	ldr	r3, [r2]			@; R3 = dirección de salto del manejador indexado
	cmp	r3, #0
	beq	.Lintr_ret			@; abandonar si dirección = 0
	mov r2, lr				@; guardar dirección de retorno
	blx	r3					@; invocar el manejador indexado
	mov lr, r2				@; recuperar dirección de retorno
	b .Lintr_ret			@; salir del bucle de búsqueda
.Lintr_cont1:	
	add	r2, r2, #8			@; pasar al siguiente índice del vector de
	b	.Lintr_find			@; manejadores de interrupciones específicas
.Lintr_ret:
	mov r1, r0				@; indica qué interrupción se ha servido
.Lintr_setflags:
	str	r1, [r12, #0x0C]	@; REG_IF = R1 (comunica interrupción servida)
	ldr	r0, =__irq_flags	@; R0 = dirección flags IRQ para gestión IntrWait
	ldr	r3, [r0]
	orr	r3, r3, r1			@; activar el flag correspondiente a la interrupción
	str	r3, [r0]			@; servida (todas si no se ha encontrado el maneja-
							@; dor correspondiente)
	mov	pc,lr				@; retornar al gestor de la excepción IRQ de la BIOS


	.global _gp_rsiVBL
	@; Manejador de interrupciones VBL (Vertical BLank) de Garlic:
	@; se encarga de actualizar los tics, intercambiar procesos, etc.
_gp_rsiVBL:
	push {r4-r7, lr}
	ldr r4, =_gd_tickCount			@; Se carga la dirección de memoria del contador de ticks.
	ldr r5, [r4]					@; Se obtiene el valor del contador de ticks.
	add r5, #1						@; Se incrementa una unidad el contador de tics.
	str r5, [r4]					@; Se guarda de nuevo en memoria el nuevo valor del contador de tics.
	ldr r4, =_gd_nReady				@; Se carga la dirección de memoria del número de procesos en la cola de Ready.
	ldr r5, [r4]					@; Se obtiene el número de procesos de la cola de Ready.
	cmp r5, #0						@; Si el número de procesos de la cola de Ready es 0...
	beq .L_fi_rsiVBL				@; ...Se salta al final del programa.
	ldr r6, =_gd_pidz				@; Se carga la dirección de memoria del identificador de proceso + zócalo.
	ldr r7, [r6]					@; Se obtiene el identificador de proceso + zócalo.
	cmp r7, #0						@; Si el identificador del proceso + zócalo corresponde al proceso del sistema operativo...
	beq .L_salvar_contexto			@; ...Se salta al paso de salvar contexto.
	mov r7, r7, lsr #4				@; Se eliminan los 4 bits correspondientes al zócalo.
	cmp r7, #0						@; Si el identificador de proceso es 0 (el proceso ha terminado su ejecución)...
	@; tst r7, #0xFFFFFFF0			@; Si el identificador de proceso es 0 (el proceso ha terminado su ejecución)...
	beq .L_restaurar_contexto		@; ...Se salta al paso de restaurar contexto.
.L_salvar_contexto:	
	bl _gp_salvarProc				@; Se llama a la rutina para salvar el contexto del proceso actual.
.L_restaurar_contexto:
	bl _gp_restaurarProc			@; Se llama a la rutina para restaurar el contexto del primer proceso de la cola de Ready. 
.L_fi_rsiVBL:
	pop {r4-r7, pc}


	@; Rutina para salvar el estado del proceso interrumpido en la entrada
	@; correspondiente del vector _gd_pcbs
	@;Parámetros
	@; R4: dirección _gd_nReady
	@; R5: número de procesos en READY
	@; R6: dirección _gd_pidz
	@;Resultado
	@; R5: nuevo número de procesos en READY (+1)
_gp_salvarProc:
	push {r8-r11, lr}
	add r5, #1					@; Se incrementa el número de procesos en la cola de Ready.
	str r5, [r4]				@; Se almacena el nuevo valor del número de procesos de la cola de Ready en la posición de memoria correspondiente.
	ldr r8, =_gd_qReady			@; Se carga la dirección de memoria de la cola de Ready.
	ldrb r9, [r6]				@; Se carga el contenido de la variable _gd_pidz.
	and r9, #0xF				@; Se filtran los 28 bits correspondientes al identificador de proceso.
	strb r9, [r8, #15]			@; Se almacena el zócalo del proceso a desbancar en la última posición de la cola de Ready
	ldr r8, [r13, #60]			@; Se carga el valor del PC del proceso antes de ser desbancado. Se encuentra en la posición 60 de la pila del modo IRQ.
	mov r10, #24				@; Cada PCB contien 6 campos de 4 bytes cada uno. En consecuencia, el zócalo se deberá multimplicar por 24 para acceder al PCB correspondiente al proceso desbancado.							 					
	mov r11, #4					@; El campo en donde se almacena el PC es el segundo campo. Se tendrá que sumar 4 para acceder a dicho campo.
	mla r10, r9, r10, r11		@; Se obtiene la posición de la variable para almacenar el PC del PCB del proceso a desbancar en el vector de PCBs. Se multiplica el zócalo por 24 y se le suma 4.
	ldr r9, =_gd_pcbs			@; Se carga la dirección de memoria base del vector de PCBs.
	str r8, [r9, r10]			@; Se almacena el valor del PC del proceso antes de ser desbancado en la posición correspondiente del PCB correspondiente.
	mrs r8, SPSR				@; Se traslada el contenido del registro SPSR (el CPSR del proceso que se quiere desbancar) a uno de los registros de trabajo.					
	add r10, #8					@; El campo en donde se almacena la palabra de estado es el quarto campo del PCB. Por tanto, el índice se deberá incrementar 8 unidades.
	str r8, [r9, r10]			@; Se almacena el contenido del registro CPSR del proceso antes de ser desbancado en la posición correspondiente del PCB correspondiente.
	mov r8, sp					@; Se almacena el valor del SP (dirección base de la pila) del modo IRQ en un registro de trabajo libre.
	mrs r9, CPSR				@; Se traslada el contenido del registro CPSR a uno de los registros de trabajo.
	orr r9, #0x1F				@; Se aplica una máscara para modificar los bits de modo, que pasarán de indicar el modo IRQ al modo System.
	msr CPSR, r9				@; Se restaura el contenido del registro CPSR. Se entra en modo sistema. Se recupera la pila y el registro de enlace de dicho modo.
	ldr r10, [r8, #56]			@; Se carga el valor del registro 12 del proceso antes de que este fuese desbancado
	push {r10, lr}				@; Se apila el contenido del registro 12 y del registro de enlace den la pila del proceso.
	mov r9, #12					@; R9 será el índice para acceder a la pila del proceso. 
	mov r11, #0					@; R11 será el contador que permitirá controlar el bucle de apilado de los registros de trabajo.
.Lbucle_salvarRegistros
	ldr r10, [r8, r9]			@; Se obtiene el contenido de un registro de trabajo de la pila del modo IRQ...
	push {r10}					@; ...y se apila en la pila del proceso (pila del modo sistema).
	sub r9, #4					@; Se incrementa el índice de la pila.
	add r11, #1					@; Se incrementa el contador de control del bucle.
							@; Los 12 registros del procesador están agrupados en la pila en 3 grupos de 4 registros por como se han ido almacenando en la ejecución de las distintas rutinas.
	and r10, r11, #0x3			@; Se filtran los bits altos (se mantienen los 2 bits bajos) del contador de control del bucle.
	cmp r10, #3					@; Se comprueba si el bucle ha realizado 4 iteraciones, es decir, si se ha almacenado un grupo de 4 regsitros. 
	blo .Lbucle_salvarRegistros	@; Sino, se continúa ejecutando el bucle.
	add r9, #32					@; Se incrementa el índice de la pila del proceso para apuntar a otro grupo de 4 registros.
	cmp r11, #12				@; Se comprueba si se han hecho 12 iteraciones del bucle, es decir, si se han apilado los 12 registros más bajos.
	blo .Lbucle_salvarRegistros	@; Sino, se continúa ejecutando el bucle.
	ldr r9, [r6]				@; Se carga el contenido de la variable _gd_pidz.
	and r9, #0xF				@; Se filtran los 28 bits correspondientes al identificador de proceso.
	mov r10, #24				@; Cada PCB contien 6 campos de 4 bytes cada uno. En consecuencia, el zócalo se deberá multimplicar por 24 para acceder al PCB correspondiente al proceso desbancado.						 					
	mov r11, #8					@; El campo en donde se almacena el SP es el tercer campo. Se tendrá que sumar 8 para acceder a dicho campo.
	mla r10, r9, r10, r11		@; Se obtiene la posición de la variable para almacenar el SP del PCB del proceso a desbancar en el vector de PCBs. Se multiplica el zócalo por 24 y se le suma 8.
	ldr r9, =_gd_pcbs			@; Se carga la dirección de memoria base del vector de PCBs.
	str sp, [r9, r10]			@; Se almacena el valor del SP en la posición correspondiente del PCB correspondiente.
	mrs r11, CPSR				@; Se traslada el contenido del registro CPSR a uno de los registros de trabajo.
	bic r11, #0x0D				@; Se aplica una máscara para modificar los bits de modo, que pasarán de indicar el modo System al modo IRQ.			
	msr CPSR, r11				@; Se restaura el contenido del registro CPSR. Se vuelve al modo IRQ.
	pop {r8-r11, pc}


	@; Rutina para restaurar el estado del siguiente proceso en la cola de READY
	@;Parámetros
	@; R4: dirección _gd_nReady
	@; R5: número de procesos en READY
	@; R6: dirección _gd_pidz
_gp_restaurarProc:
	push {r8-r11, lr}
	
	
	pop {r8-r11, pc}


	.global _gp_numProc
	@;Resultado
	@; R0: número de procesos total
_gp_numProc:
	push {lr}


	pop {pc}


	.global _gp_crearProc
	@; prepara un proceso para ser ejecutado, creando su entorno de ejecución y
	@; colocándolo en la cola de READY
	@;Parámetros
	@; R0: intFunc funcion,
	@; R1: int zocalo,
	@; R2: char *nombre
	@; R3: int arg
	@;Resultado
	@; R0: 0 si no hay problema, >0 si no se puede crear el proceso
_gp_crearProc:
	push {lr}


	pop {pc}


	@; Rutina para terminar un proceso de usuario:
	@; pone a 0 el campo PID del PCB del zócalo actual, para indicar que esa
	@; entrada del vector _gd_pcbs está libre; también pone a 0 el PID de la
	@; variable _gd_pidz (sin modificar el número de zócalo), para que el código
	@; de multiplexación de procesos no salve el estado del proceso terminado.
_gp_terminarProc:
	ldr r0, =_gd_pidz
	ldr r1, [r0]			@; R1 = valor actual de PID + zócalo
	and r1, r1, #0xf		@; R1 = zócalo del proceso desbancado
	str r1, [r0]			@; guardar zócalo con PID = 0, para no salvar estado			
	ldr r2, =_gd_pcbs
	mov r10, #24
	mul r11, r1, r10
	add r2, r11				@; R2 = dirección base _gd_pcbs[zocalo]
	mov r3, #0
	str r3, [r2]			@; pone a 0 el campo PID del PCB del proceso
.LterminarProc_inf:
	bl _gp_WaitForVBlank	@; pausar procesador
	b .LterminarProc_inf	@; hasta asegurar el cambio de contexto
	
.end

