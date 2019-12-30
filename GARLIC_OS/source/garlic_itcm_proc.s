@;==============================================================================
@;
@;	"garlic_itcm_proc.s":	código de las rutinas de control de procesos (2.0)
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
	cmp r5, #0						@; Si comprueba si el número de procesos de la cola de Ready es 0.
	beq .L_fi_rsiVBL				@; En caso afirmativo, se salta al final del programa.
	ldr r6, =_gd_pidz				@; Se carga la dirección de memoria del identificador de proceso + zócalo.
	ldr r7, [r6]					@; Se obtiene el identificador de proceso + zócalo.
	cmp r7, #0						@; Se comprueba si el PID + zócalo es 0 (si corresponde al proceso del sistema operativo).
	beq .L_salvar_contexto			@; En caso afirmativo, se salta a la instrucción para salvar contexto.
	movs r7, r7, lsr #4				@; Se eliminan los 4 bits correspondientes al zócalo y se actualizan los flags para poder comprobar si el PID es 0 (si el proceso ha terminado su ejecución).
	beq .L_restaurar_contexto		@; En caso afirmativo, se salta al paso de restaurar contexto.
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
	mov r8, sp						@; Se almacena el valor del SP (dirección base de la pila) del modo IRQ en un registro de trabajo libre.
	mrs r9, CPSR					@; Se traslada el contenido del registro CPSR a uno de los registros de trabajo.
	orr r9, #0x1F					@; Se aplica una máscara para modificar los bits de modo, que pasarán de indicar el modo IRQ al modo System.
	msr CPSR, r9					@; Se restaura el contenido del registro CPSR. Se entra en modo sistema. Se recupera la pila y el registro de enlace de dicho modo.
	ldr r11, [r8, #56]				@; Se carga el valor del registro 12 del proceso antes de que este fuese desbancado.
	ldr r10, [r8, #12]				@; Se carga el valor del registro 11 del proceso antes de que este fuese desbancado.
	ldr r9, [r8, #8]				@; Se carga el valor del registro 10 del proceso antes de que este fuese desbancado.
	push {r9-r11, lr}				@; Se apila el contenido de los registros 10, 11, 12 y lr en la pila del proceso.
	ldr r11, [r8, #4]				@; Se carga el valor del registro 9 del proceso antes de que este fuese desbancado.
	ldr r10, [r8]					@; Se carga el valor del registro 8 del proceso antes de que este fuese desbancado.
	ldr r9, [r8, #32]				@; Se carga el valor del registro 7 del proceso antes de que este fuese desbancado.
	push {r9-r11}					@; Se apila el contenido de los registros 7, 8 y 9 en la pila del proceso.
	ldr r11, [r8, #28]				@; Se carga el valor del registro 6 del proceso antes de que este fuese desbancado.
	ldr r10, [r8, #24]				@; Se carga el valor del registro 5 del proceso antes de que este fuese desbancado.
	ldr r9, [r8, #20]				@; Se carga el valor del registro 4 del proceso antes de que este fuese desbancado.
	push {r9-r11}					@; Se apila el contenido de los registros 4, 5 y 6 en la pila del proceso.
	ldr r11, [r8, #52]				@; Se carga el valor del registro 3 del proceso antes de que este fuese desbancado.
	ldr r10, [r8, #48]				@; Se carga el valor del registro 2 del proceso antes de que este fuese desbancado.
	ldr r9, [r8, #44]				@; Se carga el valor del registro 1 del proceso antes de que este fuese desbancado.
	ldr r8, [r8, #40]				@; Se carga el valor del registro 0 del proceso antes de que este fuese desbancado.
	push {r8-r11}					@; Se apila los contenido de los registros 0, 1, 2 y 3 en la pila del proceso.
	ldrb r8, [r6]					@; Se carga el contenido de la variable _gd_pidz.
	and r9, #0xF					@; Se filtran los 28 bits correspondientes al identificador de proceso.
	mov r10, #24					@; Cada PCB contien 6 campos de 4 bytes cada uno. En consecuencia, el zócalo se deberá multimplicar por 24 para acceder al PCB correspondiente al proceso desbancado.							 					
	ldr r11, =_gd_pcbs				@; Se carga la dirección de memoria base del vector de PCBs.
	mla r10, r9, r10, r11			@; Se obtiene la posición de la variable para almacenar el PC del PCB del proceso a desbancar en el vector de PCBs. Se multiplica el zócalo por 24 y se le suma 4.
	str sp, [r10, #8]				@; Se almacena el valor del SP en la posición correspondiente del PCB correspondiente.
	mrs r11, CPSR					@; Se traslada el contenido del registro CPSR a uno de los registros de trabajo.
	bic r11, #0x0D					@; Se aplica una máscara para modificar los bits de modo, que pasarán de indicar el modo System al modo IRQ.			
	msr CPSR, r11					@; Se restaura el contenido del registro CPSR. Se vuelve al modo IRQ.
	ldr r11, [sp, #60]				@; Se carga el valor del PC del proceso antes de ser desbancado. Se encuentra en la posición 60 de la pila del modo IRQ.
	str r11, [r10, #4]				@; Se almacena el valor del PC del proceso antes de ser desbancado en la posición correspondiente del PCB correspondiente.
	mrs r11, SPSR					@; Se traslada el contenido del registro SPSR (el CPSR del proceso que se quiere desbancar) a uno de los registros de trabajo.					
	str r11, [r10, #12]				@; Se almacena el contenido del registro CPSR del proceso antes de ser desbancado en es el quarto campo del PCB correspondiente.
	tst r8, #0x80000000				@; Si el bit de más peso de la variable _gd_pidz está activo, no se almacena el zócalo en la cola de Ready.
	bne .L_fin_salvarProc				
	ldr r10, =_gd_qReady			@; Se carga la dirección de memoria de la cola de Ready.
	strb r9, [r10, r5]				@; Se almacena el zócalo del proceso a desbancar en la última posición de la cola de Ready.
	add r5, #1						@; Se incrementa el número de procesos en la cola de Ready.
	str r5, [r4]					@; Se almacena el nuevo valor del número de procesos de la cola de Ready en la posición de memoria correspondiente.
.L_fin_salvarProc:	
	pop {r8-r11, pc}


	@; Rutina para restaurar el estado del siguiente proceso en la cola de READY
	@;Parámetros
	@; R4: dirección _gd_nReady
	@; R5: número de procesos en READY
	@; R6: dirección _gd_pidz
_gp_restaurarProc:
	push {r8-r11, lr}
	sub r5, #1						@; Se decrementa el número de procesos en Ready.
	str r5, [r4]					@; Se almacena el nuevo valor del número de procesos de la cola de Ready en la posición de memoria correspondiente.
	ldr r9, =_gd_qReady				@; Se carga la dirección de memoria de la cola de Ready.
	ldrb r8, [r9]					@; Se carga el zócalo del proceso cuyo contexto se ha de restaurar (primer proceso de la cola de Ready). 	
.L_bucle_desplazarCola:
	ldrb r10, [r9, #1]				@; Se carga un zócalo de una posición de la cola de Ready. 
	strb r10, [r9]					@; Se almacena dicho zócalo en la posición anterior de la cola de Ready.
	add r9, #1						@; Se incrementa el índice de la cola de Ready.
	subs r5, #1						@; Se decrementa la variable de control del bucle y se actualizan los flags.
	bhi .L_bucle_desplazarCola		@; A través de los flags, se comprueba si la variable de control del bucle es 0 (Ya se han desplazado todos los zócalos a las posiciones anteriores de la cola de Ready).
	mov r9, #24						@; Cada PCB contien 6 campos de 4 bytes cada uno. En consecuencia, el zócalo se deberá multimplicar por 24 para acceder al PCB correspondiente al proceso desbancado.
	ldr r10, =_gd_pcbs				@; Se carga la dirección de memoria del vector de PCBs.
	mla r9, r8, r9, r10				@; Se calcula el índice para acceder al PID del proceso correspondiente al zócalo. El PID es el primer campo del PCB. 
	ldr r10, [r9]					@; Se carga el PID del proceso.
	orr r8, r10, lsl #4				@; Se concatenan el PID y el zócalo para construir el valor PIDz.
	str r8, [r6]					@; Se almacena el valor PIDz en la posición de memoria correspondiente a la etiqueta _gd_pidz.
	ldr r10, [r9, #4]				@; Se carga el valor del PC del proceso que se quiere restaurar.			
	str r10, [sp, #60]				@; Se almacena el valor del PC en la posición 60 de la pila del modo IRQ.
	ldr r10, [r9, #12]				@; Se carga la palabra de estado del proceso que se quiere restaurar.
	msr SPSR, r10					@; Se almacena la palabra de estado del proceso que se quiere restaurar en el registro SPSR del modo irq. 
	mov r8, sp						@; Se almacena el valor del SP del modo IRQ en R8.
	mrs r10, CPSR					@; Se mueve el contenido del registro CPSR a R11 para poder manipular su contenido.
	orr r10, #0x1F					@; Se modifican los bits de modo para pasar del modo IRQ al modo System.
	msr CPSR, r10					@; Se actualiza el contenido del registro CPSR con el valor modificado.
	ldr sp, [r9, #8]				@; Se carga el valor del SP del proceso que se quiere restaurar.
	pop {r9-r11}					@; Se desapila el contenido de los registros R0, R1 y R2 de la pila del proceso.
	str r9, [r8, #40]				@; Se almacena el contenido del registro R0 en la pila del modo IRQ.
	str r10, [r8, #44]				@; Se almacena el contenido del registro R1 en la pila del modo IRQ.
	str r11, [r8, #48]				@; Se almacena el contenido del registro R2 la pila del modo IRQ.
	pop {r9-r11}					@; Se desapila el contenido de los registros R3, R4 y R5 de la pila del proceso.
	str r9, [r8, #52]				@; Se almacena el contenido del registro R3 en la pila del modo IRQ.
	str r10, [r8, #20]				@; Se almacena el contenido del registro R4 en la pila del modo IRQ.
	str r11, [r8, #24]				@; Se almacena el contenido del registro R5 la pila del modo IRQ.
	pop {r9-r11}					@; Se desapila el contenido de los registros R6, R7 y R8 de la pila del proceso.
	str r9, [r8, #28]				@; Se almacena el contenido del registro R6 en la pila del modo IRQ.
	str r10, [r8, #32]				@; Se almacena el contenido del registro R7 en la pila del modo IRQ.
	str r11, [r8]					@; Se almacena el contenido del registro R8 la pila del modo IRQ.
	pop {r9-r11}					@; Se desapila el contenido de los registros R9, R10 y R11 de la pila del proceso.
	str r9, [r8, #4]				@; Se almacena el contenido del registro R0 en la pila del modo IRQ.
	str r10, [r8, #8]				@; Se almacena el contenido del registro R1 en la pila del modo IRQ.
	str r11, [r8, #12]				@; Se almacena el contenido del registro R2 la pila del modo IRQ.
	pop {r9, lr}					@; Se desapila el contenido de los registros R12 y LR de la pila del proceso.
	str r9, [r8, #56]				@; Se almacena el contenido del registro R12 en la pila del modo IRQ.
	mrs r10, CPSR					@; Se mueve el contenido del registro CPSR a R11 para poder manipular su contenido.
	bic r10, #0x0D					@; Se modifican los bits de modo para pasar del modo System al modo IRQ.
	msr CPSR, r10					@; Se actualiza el contenido del registro CPSR con el valor modificado.
	pop {r8-r11, pc}


	.global _gp_numProc
	@;Resultado
	@; R0: número de procesos total
_gp_numProc:
	push {r1-r2, lr}
	mov r0, #1				@; contar siempre 1 proceso en RUN
	ldr r1, =_gd_nReady
	ldr r2, [r1]			@; R2 = número de procesos en cola de READY
	add r0, r2				@; añadir procesos en READY
	ldr r1, =_gd_nDelay
	ldr r2, [r1]			@; R2 = número de procesos en cola de DELAY
	add r0, r2				@; añadir procesos retardados
	pop {r1-r2, pc}


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
	push {r4-r7, lr}
	cmp r1, #0						@; Se comprueba si el zócalo es 0, es decir, si corresponde al proceso del sistema operativo.  
	beq .L_fin_crearProc			@; En caso afirmativo, se termina la ejecución de la rutina de creación de proceso.
	ldr r5, =_gd_pcbs				@; Se carga la dirección de memoria del vector de PCBs.
	mov r4, #24						@; El zócalo se deberá multiplicar por 24 para acceder al PCB que se asignará al proceso que se quiere crear.
	mla r4, r1, r4, r5				@; Se cálcula el índice para acceder al PID del proceso correspondiente al zócalo. El PID es el primer campo del PCB.
	ldr r5, [r4]					@; Se carga el PID del proceso corresponidente al zócalo.
	cmp r5, #0						@; Se comprueba si el PID es 0, es decir, si el zócalo ya está ocupado por otro proceso.
	bne .L_fin_crearProc			@; En caso afirmativo, se termina la ejecución de la rutina de creación de proceso.
	ldr r5, =_gd_pidCount			@; Se carga la dirección de memoria en donde se almacena el contador de PIDs.
	ldr r6, [r5]					@; Se carga el valor del contador de PIDs.
	add r6, #1						@; Se incrementa el valor del contador de PIDs.
	str r6, [r5]					@; Se almacena el nuevo valor del contador de PIDs.
	str r6, [r4]					@; Se almacena el nuevo valor del PID del proceso a crear en el campo correspondiente del PCB correspondiente.
	add r0, #4						@; Se incrementa una instrucción la dirección base de la primera rutina del proceso (valor inicial del PC). Esto se hace para compensar el decremento automático que se producirá debido al funcionamiento del código de la BIOS IRQ Exception Handler cuando se restaure el proceso por primera vez.
	str r0, [r4, #4]				@; Se almacena la dirección base de la primera rutina del proceso en el campo del PCB correspondiente al PC.
	ldr r5, [r2]					@; Se cargan los 4 primeros carácteres del nombre en clave del programa.
	str r5, [r4, #16]				@; Se almacenan los 4 primeros carácteres del nombre en clave en el campo correspondiente del vector de PCBs.
	mov r7, sp						@; Se salva el valor actual de la pila.
	ldr r5, =_gd_stacks				@; Se carga la dirección base del vector de pilas.
	add sp, r5, r1, lsl #9			@; Se multiplica el zócalo por el tamaño de una pila y se le suma la dirección base del vector de pilas para obtener la dirección base de la pila correspondiente al proceso que se quiere crear.		
	ldr r5, =_gp_terminarProc		@; Se carga la dirección de inicio de la rutina _gp_terminarProc.
	push {r5}						@; Se apila dicha dirección de memoria, de manera que al ser desapilada corresponda al registro de enlace del proceso. 
	mov r5, #0						@; R5 contendrá un 0, que es el valor que debera apilarse en la pila en las posiciones correspondientes a los registros R1-R12.				
	mov r6, #0						@; Se inicializa el índice para controlar del bucle de apilado de los registros. 
.L_bucle_apilarRegistros:
	push {r5}						@; Se apila un 0 en cada una de las posiciones de la pila.
	add r6, #1						@; Se incrementa el índice de control del bucle.
	cmp r6, #12						@; Se comprueba si se han realizado 12 iteraciones, es decir, si se han apilado todos los registros que al restaurarse deberán contener un 0.
	blo .L_bucle_apilarRegistros	@; En caso contrario, se continúan realizando iteraciones.
	push {r3}						@; Se apila el valor del argumento en la posición que al desapilarse corresponderá a R0.
	str sp, [r4, #8]				@; Se almacena el valor del top de la pila en el campo correspondiente del vector de PCBs.
	mov sp, r7						@; Se recupera el valor de la pila.
	mov r5, #0x1F					@; R6 contendrá el valor de la palabra de estado del procesador. Los flags estarán todos a 0, las interrupciones IRQ estarán habilitadas, el juego de instrucciones será ARM y los 4 bits de modo estarán a 1 para que la ejecución se realice en modo sistema. 
	str r5, [r4, #12]				@; Se almacena el valor inicial de la palabra de estado del proceso en el campo correspondiente.
	mov r5, #0						@; El contador de tics de trabajo se inicializará al valor 0.
	str r5, [r4, #20]				@; Se almacenará el valor incial del contador de tics de trabajo en el campo correspondiente del vector de PCBs.
	ldr r4, =_gd_qReady				@; Se carga la dirección base de la cola de Ready.
	ldr r5, =_gd_nReady				@; Se carga la dirección de memoria que contiene el número de proceso en la cola de Ready.
	ldr r6, [r5]					@; Se carga el valor del número de procesos en la cola de Ready.
	strb r1, [r4, r6]				@; Se almacena el zócalo del proceso creado en la última posición de la cola de Ready.
	add r6, #1						@; Se incrementa el número de procesos en la cola de Ready.
	str r6, [r5]					@; Se almacena el nuevo valor del número de procesos en la dirección de memoria correspondiente.
.L_fin_crearProc:
	pop {r4-r7, pc}
	

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
	str r3, [r2, #20]		@; borrar porcentaje de USO de la CPU
	ldr r0, =_gd_sincMain
	ldr r2, [r0]			@; R2 = valor actual de la variable de sincronismo
	mov r3, #1
	mov r3, r3, lsl r1		@; R3 = máscara con bit correspondiente al zócalo
	orr r2, r3
	str r2, [r0]			@; actualizar variable de sincronismo
.LterminarProc_inf:
	bl _gp_WaitForVBlank	@; pausar procesador
	b .LterminarProc_inf	@; hasta asegurar el cambio de contexto
	
	
	@; Rutina para actualizar la cola de procesos retardados, poniendo en
	@; cola de READY aquellos cuyo número de tics de retardo sea 0
_gp_actualizarDelay:
	push {r0-r7, lr}
	ldr r0, =_gp_qDelay			
	ldr r1, =_gd_nDelay
	ldr r2, [r1]				
	mov r3, r2				@; El número de procesos de la cola de Delay estará replicado en dos registros. En uno de ellos actuará como contador del número de procesos que quedan por tratar. En el otro actuará como el número total de procesos bloqueados al final de la ejecución de la rutina.
.L_actualizar_qDelay:
	ldr r4, [r0]
	sub r4, #1				@; Se decrementa una unidad el número de tics a retardar.
	movs r5, r4, lsl #8			@; Se elimina el zócalo y se actualizan los flags.
	beq .L_desblocProc			@; Si el número de tics es 0, se deberá desplazar el proceso a la cola de Ready.
	str r4, [r0] 
	add r0, #4				@; Sino, se almacena de nuevo el proceso en la posición correspondiente y se avanza a la siguiente posición de la cola de Delay.	
	b .L_fin_desblocProc
.L_desblocProc: 
	ldr r5, =_gd_qReady
	ldr r7, =_gd_nReady
	ldr r6, [r7]
	mov r4, r4, lsr #24
	strb r4, [r5, r6]			@; Se almacena el zócalo del proceso en la última posición de la cola de Ready.
	add r6, #1
	str r6, [r7]				@; Se incrementa el número de procesos de la cola de Ready.								
	push {r0, r2}
	sub r2, #1
.L_desplazar_qDelay:
	ldr r4, [r0, #4]
	str r4, [r0]				@; Se mueven todos los procesos bloquedaos (situados a partir del proceso que se ha movido a la cola de Ready) a la posición anterior de la cola de Delay.
	add r0, #4
	subs r1, #1	
	bhi .L_desplazar_qDelay
	pop {r0, r2}
	sub r3, #1				@; Se decrementa una unidad el número de procesos totales de la cola de Delay por cada proceso que se mueve a la cola de run. 
.L_fin_desblocProc:
	subs r2, #1				@; Se decrementa el número de procesos de la cola de Delay que quedan por tratar.
	bhi .L_actualizar_qDelay
	str r3, [r1]
	pop {r0-r7, pc}
	
	.global _gp_matarProc
	@; Rutina para destruir un proceso de usuario:
	@; borra el PID del PCB del zócalo referenciado por parámetro, para indicar
	@; que esa entrada del vector _gd_pcbs está libre; elimina el índice de
	@; zócalo de la cola de READY o de la cola de DELAY, esté donde esté;
	@; Parámetros:
	@;	R0:	zócalo del proceso a matar (entre 1 y 15).
_gp_matarProc:
	push {lr} 


	pop {pc}
	
	.global _gp_retardarProc
	@; retarda la ejecución de un proceso durante cierto número de segundos,
	@; colocándolo en la cola de DELAY
	@;Parámetros
	@; R0: int nsec
_gp_retardarProc:
	push {r0-r3, lr}
	ldr r1, [r3]
	orr r1, #0x80000000		@; Se pone a 1 el bit de más peso del campo PID+z.
	str r1, [r3]
	mov r1, #60			@; En un segundo se producen 60 retrocesos verticales (60 tics).
	mul r0, r1, r0			@; Por tanto, se multiplica el número de segundos por 60 para obtener el número de tics.
	orr r2, r0, r2, lsl #24		@; Se construye el valor del zócalo + el número de tics.	
	ldr r0, =_gd_qDelay
	ldr r3, =_gd_nDelay
	ldr r1, [r3]
	str r2, [r0, r1]		@; Se almacena el valor del zócalo + el número de tics en la última posición de la cola de Delay.
	add r1, #1
	str r1, [r3]			@; Se incrementa el número de procesos en la cola de Delay.
	bl _gp_WaitForVBlank		@; Se fuerza la cesión de la CPU a la espera de que se produzca un nuevo retroceso vertical.
	pop {r0-r3, pc}


	.global _gp_inihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 0, para inhibir todas
	@; las IRQs y evitar así posibles problemas debidos al cambio de contexto
_gp_inhibirIRQs:
	push {lr}


	pop {pc}


	.global _gp_desinihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 1, para desinhibir todas
	@; las IRQs
_gp_desinhibirIRQs:
	push {lr}


	pop {pc}


	.global _gp_rsiTIMER0
	@; Rutina de Servicio de Interrupción (RSI) para contabilizar los tics
	@; de trabajo de cada proceso: suma los tics de todos los procesos y calcula
	@; el porcentaje de uso de la CPU, que se guarda en los 8 bits altos de la
	@; entrada _gd_pcbs[z].workTicks de cada proceso (z) y, si el procesador
	@; gráfico secundario está correctamente configurado, se imprime en la
	@; columna correspondiente de la tabla de procesos.
_gp_rsiTIMER0:
	push {lr}

	
	pop {pc}


	
.end

