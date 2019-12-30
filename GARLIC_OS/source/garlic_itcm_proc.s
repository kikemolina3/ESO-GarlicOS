@;==============================================================================
@;
@;	"garlic_itcm_proc.s":	c�digo de las rutinas de control de procesos (2.0)
@;						(ver "garlic_system.h" para descripci�n de funciones)
@;
@;==============================================================================

.section .itcm,"ax",%progbits

	.arm
	.align 2
	
	.global _gp_WaitForVBlank
	@; rutina para pausar el procesador mientras no se produzca una interrupci�n
	@; de retrazado vertical (VBL); es un sustituto de la "swi #5", que evita
	@; la necesidad de cambiar a modo supervisor en los procesos GARLIC
_gp_WaitForVBlank:
	push {r0-r1, lr}
	ldr r0, =__irq_flags
.Lwait_espera:
	mcr p15, 0, lr, c7, c0, 4	@; HALT (suspender hasta nueva interrupci�n)
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
	ldr	r2, [r12, #0x08]	@; R2 = REG_IE (m�scara de bits con int. permitidas)
	ldr	r1, [r12, #0x0C]	@; R1 = REG_IF (m�scara de bits con int. activas)
	and r1, r1, r2			@; filtrar int. activas con int. permitidas
	ldr	r2, =irqTable
.Lintr_find:				@; buscar manejadores de interrupciones espec�ficos
	ldr r0, [r2, #4]		@; R0 = m�scara de int. del manejador indexado
	cmp	r0, #0				@; si m�scara = cero, fin de vector de manejadores
	beq	.Lintr_setflags		@; (abandonar bucle de b�squeda de manejador)
	ands r0, r0, r1			@; determinar si el manejador indexado atiende a una
	beq	.Lintr_cont1		@; de las interrupciones activas
	ldr	r3, [r2]			@; R3 = direcci�n de salto del manejador indexado
	cmp	r3, #0
	beq	.Lintr_ret			@; abandonar si direcci�n = 0
	mov r2, lr				@; guardar direcci�n de retorno
	blx	r3					@; invocar el manejador indexado
	mov lr, r2				@; recuperar direcci�n de retorno
	b .Lintr_ret			@; salir del bucle de b�squeda
.Lintr_cont1:	
	add	r2, r2, #8			@; pasar al siguiente �ndice del vector de
	b	.Lintr_find			@; manejadores de interrupciones espec�ficas
.Lintr_ret:
	mov r1, r0				@; indica qu� interrupci�n se ha servido
.Lintr_setflags:
	str	r1, [r12, #0x0C]	@; REG_IF = R1 (comunica interrupci�n servida)
	ldr	r0, =__irq_flags	@; R0 = direcci�n flags IRQ para gesti�n IntrWait
	ldr	r3, [r0]
	orr	r3, r3, r1			@; activar el flag correspondiente a la interrupci�n
	str	r3, [r0]			@; servida (todas si no se ha encontrado el maneja-
							@; dor correspondiente)
	mov	pc,lr				@; retornar al gestor de la excepci�n IRQ de la BIOS


	.global _gp_rsiVBL
	@; Manejador de interrupciones VBL (Vertical BLank) de Garlic:
	@; se encarga de actualizar los tics, intercambiar procesos, etc.
_gp_rsiVBL:
	push {r4-r7, lr}
	ldr r4, =_gd_tickCount			@; Se carga la direcci�n de memoria del contador de ticks.
	ldr r5, [r4]					@; Se obtiene el valor del contador de ticks.
	add r5, #1						@; Se incrementa una unidad el contador de tics.
	str r5, [r4]					@; Se guarda de nuevo en memoria el nuevo valor del contador de tics.
	ldr r4, =_gd_nReady				@; Se carga la direcci�n de memoria del n�mero de procesos en la cola de Ready.
	ldr r5, [r4]					@; Se obtiene el n�mero de procesos de la cola de Ready.
	cmp r5, #0						@; Si comprueba si el n�mero de procesos de la cola de Ready es 0.
	beq .L_fi_rsiVBL				@; En caso afirmativo, se salta al final del programa.
	ldr r6, =_gd_pidz				@; Se carga la direcci�n de memoria del identificador de proceso + z�calo.
	ldr r7, [r6]					@; Se obtiene el identificador de proceso + z�calo.
	cmp r7, #0						@; Se comprueba si el PID + z�calo es 0 (si corresponde al proceso del sistema operativo).
	beq .L_salvar_contexto			@; En caso afirmativo, se salta a la instrucci�n para salvar contexto.
	movs r7, r7, lsr #4				@; Se eliminan los 4 bits correspondientes al z�calo y se actualizan los flags para poder comprobar si el PID es 0 (si el proceso ha terminado su ejecuci�n).
	beq .L_restaurar_contexto		@; En caso afirmativo, se salta al paso de restaurar contexto.
.L_salvar_contexto:	
	bl _gp_salvarProc				@; Se llama a la rutina para salvar el contexto del proceso actual.
.L_restaurar_contexto:
	bl _gp_restaurarProc			@; Se llama a la rutina para restaurar el contexto del primer proceso de la cola de Ready. 
.L_fi_rsiVBL:
	pop {r4-r7, pc}


	@; Rutina para salvar el estado del proceso interrumpido en la entrada
	@; correspondiente del vector _gd_pcbs
	@;Par�metros
	@; R4: direcci�n _gd_nReady
	@; R5: n�mero de procesos en READY
	@; R6: direcci�n _gd_pidz
	@;Resultado
	@; R5: nuevo n�mero de procesos en READY (+1)
_gp_salvarProc:
	push {r8-r11, lr}
	mov r8, sp						@; Se almacena el valor del SP (direcci�n base de la pila) del modo IRQ en un registro de trabajo libre.
	mrs r9, CPSR					@; Se traslada el contenido del registro CPSR a uno de los registros de trabajo.
	orr r9, #0x1F					@; Se aplica una m�scara para modificar los bits de modo, que pasar�n de indicar el modo IRQ al modo System.
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
	mov r10, #24					@; Cada PCB contien 6 campos de 4 bytes cada uno. En consecuencia, el z�calo se deber� multimplicar por 24 para acceder al PCB correspondiente al proceso desbancado.							 					
	ldr r11, =_gd_pcbs				@; Se carga la direcci�n de memoria base del vector de PCBs.
	mla r10, r9, r10, r11			@; Se obtiene la posici�n de la variable para almacenar el PC del PCB del proceso a desbancar en el vector de PCBs. Se multiplica el z�calo por 24 y se le suma 4.
	str sp, [r10, #8]				@; Se almacena el valor del SP en la posici�n correspondiente del PCB correspondiente.
	mrs r11, CPSR					@; Se traslada el contenido del registro CPSR a uno de los registros de trabajo.
	bic r11, #0x0D					@; Se aplica una m�scara para modificar los bits de modo, que pasar�n de indicar el modo System al modo IRQ.			
	msr CPSR, r11					@; Se restaura el contenido del registro CPSR. Se vuelve al modo IRQ.
	ldr r11, [sp, #60]				@; Se carga el valor del PC del proceso antes de ser desbancado. Se encuentra en la posici�n 60 de la pila del modo IRQ.
	str r11, [r10, #4]				@; Se almacena el valor del PC del proceso antes de ser desbancado en la posici�n correspondiente del PCB correspondiente.
	mrs r11, SPSR					@; Se traslada el contenido del registro SPSR (el CPSR del proceso que se quiere desbancar) a uno de los registros de trabajo.					
	str r11, [r10, #12]				@; Se almacena el contenido del registro CPSR del proceso antes de ser desbancado en es el quarto campo del PCB correspondiente.
	tst r8, #0x80000000				@; Si el bit de m�s peso de la variable _gd_pidz est� activo, no se almacena el z�calo en la cola de Ready.
	bne .L_fin_salvarProc				
	ldr r10, =_gd_qReady			@; Se carga la direcci�n de memoria de la cola de Ready.
	strb r9, [r10, r5]				@; Se almacena el z�calo del proceso a desbancar en la �ltima posici�n de la cola de Ready.
	add r5, #1						@; Se incrementa el n�mero de procesos en la cola de Ready.
	str r5, [r4]					@; Se almacena el nuevo valor del n�mero de procesos de la cola de Ready en la posici�n de memoria correspondiente.
.L_fin_salvarProc:	
	pop {r8-r11, pc}


	@; Rutina para restaurar el estado del siguiente proceso en la cola de READY
	@;Par�metros
	@; R4: direcci�n _gd_nReady
	@; R5: n�mero de procesos en READY
	@; R6: direcci�n _gd_pidz
_gp_restaurarProc:
	push {r8-r11, lr}
	sub r5, #1						@; Se decrementa el n�mero de procesos en Ready.
	str r5, [r4]					@; Se almacena el nuevo valor del n�mero de procesos de la cola de Ready en la posici�n de memoria correspondiente.
	ldr r9, =_gd_qReady				@; Se carga la direcci�n de memoria de la cola de Ready.
	ldrb r8, [r9]					@; Se carga el z�calo del proceso cuyo contexto se ha de restaurar (primer proceso de la cola de Ready). 	
.L_bucle_desplazarCola:
	ldrb r10, [r9, #1]				@; Se carga un z�calo de una posici�n de la cola de Ready. 
	strb r10, [r9]					@; Se almacena dicho z�calo en la posici�n anterior de la cola de Ready.
	add r9, #1						@; Se incrementa el �ndice de la cola de Ready.
	subs r5, #1						@; Se decrementa la variable de control del bucle y se actualizan los flags.
	bhi .L_bucle_desplazarCola		@; A trav�s de los flags, se comprueba si la variable de control del bucle es 0 (Ya se han desplazado todos los z�calos a las posiciones anteriores de la cola de Ready).
	mov r9, #24						@; Cada PCB contien 6 campos de 4 bytes cada uno. En consecuencia, el z�calo se deber� multimplicar por 24 para acceder al PCB correspondiente al proceso desbancado.
	ldr r10, =_gd_pcbs				@; Se carga la direcci�n de memoria del vector de PCBs.
	mla r9, r8, r9, r10				@; Se calcula el �ndice para acceder al PID del proceso correspondiente al z�calo. El PID es el primer campo del PCB. 
	ldr r10, [r9]					@; Se carga el PID del proceso.
	orr r8, r10, lsl #4				@; Se concatenan el PID y el z�calo para construir el valor PIDz.
	str r8, [r6]					@; Se almacena el valor PIDz en la posici�n de memoria correspondiente a la etiqueta _gd_pidz.
	ldr r10, [r9, #4]				@; Se carga el valor del PC del proceso que se quiere restaurar.			
	str r10, [sp, #60]				@; Se almacena el valor del PC en la posici�n 60 de la pila del modo IRQ.
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
	@; R0: n�mero de procesos total
_gp_numProc:
	push {r1-r2, lr}
	mov r0, #1				@; contar siempre 1 proceso en RUN
	ldr r1, =_gd_nReady
	ldr r2, [r1]			@; R2 = n�mero de procesos en cola de READY
	add r0, r2				@; a�adir procesos en READY
	ldr r1, =_gd_nDelay
	ldr r2, [r1]			@; R2 = n�mero de procesos en cola de DELAY
	add r0, r2				@; a�adir procesos retardados
	pop {r1-r2, pc}


	.global _gp_crearProc
	@; prepara un proceso para ser ejecutado, creando su entorno de ejecuci�n y
	@; coloc�ndolo en la cola de READY
	@;Par�metros
	@; R0: intFunc funcion,
	@; R1: int zocalo,
	@; R2: char *nombre
	@; R3: int arg
	@;Resultado
	@; R0: 0 si no hay problema, >0 si no se puede crear el proceso
_gp_crearProc:
	push {r4-r7, lr}
	cmp r1, #0						@; Se comprueba si el z�calo es 0, es decir, si corresponde al proceso del sistema operativo.  
	beq .L_fin_crearProc			@; En caso afirmativo, se termina la ejecuci�n de la rutina de creaci�n de proceso.
	ldr r5, =_gd_pcbs				@; Se carga la direcci�n de memoria del vector de PCBs.
	mov r4, #24						@; El z�calo se deber� multiplicar por 24 para acceder al PCB que se asignar� al proceso que se quiere crear.
	mla r4, r1, r4, r5				@; Se c�lcula el �ndice para acceder al PID del proceso correspondiente al z�calo. El PID es el primer campo del PCB.
	ldr r5, [r4]					@; Se carga el PID del proceso corresponidente al z�calo.
	cmp r5, #0						@; Se comprueba si el PID es 0, es decir, si el z�calo ya est� ocupado por otro proceso.
	bne .L_fin_crearProc			@; En caso afirmativo, se termina la ejecuci�n de la rutina de creaci�n de proceso.
	ldr r5, =_gd_pidCount			@; Se carga la direcci�n de memoria en donde se almacena el contador de PIDs.
	ldr r6, [r5]					@; Se carga el valor del contador de PIDs.
	add r6, #1						@; Se incrementa el valor del contador de PIDs.
	str r6, [r5]					@; Se almacena el nuevo valor del contador de PIDs.
	str r6, [r4]					@; Se almacena el nuevo valor del PID del proceso a crear en el campo correspondiente del PCB correspondiente.
	add r0, #4						@; Se incrementa una instrucci�n la direcci�n base de la primera rutina del proceso (valor inicial del PC). Esto se hace para compensar el decremento autom�tico que se producir� debido al funcionamiento del c�digo de la BIOS IRQ Exception Handler cuando se restaure el proceso por primera vez.
	str r0, [r4, #4]				@; Se almacena la direcci�n base de la primera rutina del proceso en el campo del PCB correspondiente al PC.
	ldr r5, [r2]					@; Se cargan los 4 primeros car�cteres del nombre en clave del programa.
	str r5, [r4, #16]				@; Se almacenan los 4 primeros car�cteres del nombre en clave en el campo correspondiente del vector de PCBs.
	mov r7, sp						@; Se salva el valor actual de la pila.
	ldr r5, =_gd_stacks				@; Se carga la direcci�n base del vector de pilas.
	add sp, r5, r1, lsl #9			@; Se multiplica el z�calo por el tama�o de una pila y se le suma la direcci�n base del vector de pilas para obtener la direcci�n base de la pila correspondiente al proceso que se quiere crear.		
	ldr r5, =_gp_terminarProc		@; Se carga la direcci�n de inicio de la rutina _gp_terminarProc.
	push {r5}						@; Se apila dicha direcci�n de memoria, de manera que al ser desapilada corresponda al registro de enlace del proceso. 
	mov r5, #0						@; R5 contendr� un 0, que es el valor que debera apilarse en la pila en las posiciones correspondientes a los registros R1-R12.				
	mov r6, #0						@; Se inicializa el �ndice para controlar del bucle de apilado de los registros. 
.L_bucle_apilarRegistros:
	push {r5}						@; Se apila un 0 en cada una de las posiciones de la pila.
	add r6, #1						@; Se incrementa el �ndice de control del bucle.
	cmp r6, #12						@; Se comprueba si se han realizado 12 iteraciones, es decir, si se han apilado todos los registros que al restaurarse deber�n contener un 0.
	blo .L_bucle_apilarRegistros	@; En caso contrario, se contin�an realizando iteraciones.
	push {r3}						@; Se apila el valor del argumento en la posici�n que al desapilarse corresponder� a R0.
	str sp, [r4, #8]				@; Se almacena el valor del top de la pila en el campo correspondiente del vector de PCBs.
	mov sp, r7						@; Se recupera el valor de la pila.
	mov r5, #0x1F					@; R6 contendr� el valor de la palabra de estado del procesador. Los flags estar�n todos a 0, las interrupciones IRQ estar�n habilitadas, el juego de instrucciones ser� ARM y los 4 bits de modo estar�n a 1 para que la ejecuci�n se realice en modo sistema. 
	str r5, [r4, #12]				@; Se almacena el valor inicial de la palabra de estado del proceso en el campo correspondiente.
	mov r5, #0						@; El contador de tics de trabajo se inicializar� al valor 0.
	str r5, [r4, #20]				@; Se almacenar� el valor incial del contador de tics de trabajo en el campo correspondiente del vector de PCBs.
	ldr r4, =_gd_qReady				@; Se carga la direcci�n base de la cola de Ready.
	ldr r5, =_gd_nReady				@; Se carga la direcci�n de memoria que contiene el n�mero de proceso en la cola de Ready.
	ldr r6, [r5]					@; Se carga el valor del n�mero de procesos en la cola de Ready.
	strb r1, [r4, r6]				@; Se almacena el z�calo del proceso creado en la �ltima posici�n de la cola de Ready.
	add r6, #1						@; Se incrementa el n�mero de procesos en la cola de Ready.
	str r6, [r5]					@; Se almacena el nuevo valor del n�mero de procesos en la direcci�n de memoria correspondiente.
.L_fin_crearProc:
	pop {r4-r7, pc}
	

	@; Rutina para terminar un proceso de usuario:
	@; pone a 0 el campo PID del PCB del z�calo actual, para indicar que esa
	@; entrada del vector _gd_pcbs est� libre; tambi�n pone a 0 el PID de la
	@; variable _gd_pidz (sin modificar el n�mero de z�calo), para que el c�digo
	@; de multiplexaci�n de procesos no salve el estado del proceso terminado.
_gp_terminarProc:
	ldr r0, =_gd_pidz
	ldr r1, [r0]			@; R1 = valor actual de PID + z�calo
	and r1, r1, #0xf		@; R1 = z�calo del proceso desbancado
	str r1, [r0]			@; guardar z�calo con PID = 0, para no salvar estado			
	ldr r2, =_gd_pcbs
	mov r10, #24
	mul r11, r1, r10
	add r2, r11				@; R2 = direcci�n base _gd_pcbs[zocalo]
	mov r3, #0
	str r3, [r2]			@; pone a 0 el campo PID del PCB del proceso
	str r3, [r2, #20]		@; borrar porcentaje de USO de la CPU
	ldr r0, =_gd_sincMain
	ldr r2, [r0]			@; R2 = valor actual de la variable de sincronismo
	mov r3, #1
	mov r3, r3, lsl r1		@; R3 = m�scara con bit correspondiente al z�calo
	orr r2, r3
	str r2, [r0]			@; actualizar variable de sincronismo
.LterminarProc_inf:
	bl _gp_WaitForVBlank	@; pausar procesador
	b .LterminarProc_inf	@; hasta asegurar el cambio de contexto
	
	
	@; Rutina para actualizar la cola de procesos retardados, poniendo en
	@; cola de READY aquellos cuyo n�mero de tics de retardo sea 0
_gp_actualizarDelay:
	push {r0-r7, lr}
	ldr r0, =_gp_qDelay			
	ldr r1, =_gd_nDelay
	ldr r2, [r1]				
	mov r3, r2				@; El n�mero de procesos de la cola de Delay estar� replicado en dos registros. En uno de ellos actuar� como contador del n�mero de procesos que quedan por tratar. En el otro actuar� como el n�mero total de procesos bloqueados al final de la ejecuci�n de la rutina.
.L_actualizar_qDelay:
	ldr r4, [r0]
	sub r4, #1				@; Se decrementa una unidad el n�mero de tics a retardar.
	movs r5, r4, lsl #8			@; Se elimina el z�calo y se actualizan los flags.
	beq .L_desblocProc			@; Si el n�mero de tics es 0, se deber� desplazar el proceso a la cola de Ready.
	str r4, [r0] 
	add r0, #4				@; Sino, se almacena de nuevo el proceso en la posici�n correspondiente y se avanza a la siguiente posici�n de la cola de Delay.	
	b .L_fin_desblocProc
.L_desblocProc: 
	ldr r5, =_gd_qReady
	ldr r7, =_gd_nReady
	ldr r6, [r7]
	mov r4, r4, lsr #24
	strb r4, [r5, r6]			@; Se almacena el z�calo del proceso en la �ltima posici�n de la cola de Ready.
	add r6, #1
	str r6, [r7]				@; Se incrementa el n�mero de procesos de la cola de Ready.								
	push {r0, r2}
	sub r2, #1
.L_desplazar_qDelay:
	ldr r4, [r0, #4]
	str r4, [r0]				@; Se mueven todos los procesos bloquedaos (situados a partir del proceso que se ha movido a la cola de Ready) a la posici�n anterior de la cola de Delay.
	add r0, #4
	subs r1, #1	
	bhi .L_desplazar_qDelay
	pop {r0, r2}
	sub r3, #1				@; Se decrementa una unidad el n�mero de procesos totales de la cola de Delay por cada proceso que se mueve a la cola de run. 
.L_fin_desblocProc:
	subs r2, #1				@; Se decrementa el n�mero de procesos de la cola de Delay que quedan por tratar.
	bhi .L_actualizar_qDelay
	str r3, [r1]
	pop {r0-r7, pc}
	
	.global _gp_matarProc
	@; Rutina para destruir un proceso de usuario:
	@; borra el PID del PCB del z�calo referenciado por par�metro, para indicar
	@; que esa entrada del vector _gd_pcbs est� libre; elimina el �ndice de
	@; z�calo de la cola de READY o de la cola de DELAY, est� donde est�;
	@; Par�metros:
	@;	R0:	z�calo del proceso a matar (entre 1 y 15).
_gp_matarProc:
	push {lr} 


	pop {pc}
	
	.global _gp_retardarProc
	@; retarda la ejecuci�n de un proceso durante cierto n�mero de segundos,
	@; coloc�ndolo en la cola de DELAY
	@;Par�metros
	@; R0: int nsec
_gp_retardarProc:
	push {r0-r3, lr}
	ldr r1, [r3]
	orr r1, #0x80000000		@; Se pone a 1 el bit de m�s peso del campo PID+z.
	str r1, [r3]
	mov r1, #60			@; En un segundo se producen 60 retrocesos verticales (60 tics).
	mul r0, r1, r0			@; Por tanto, se multiplica el n�mero de segundos por 60 para obtener el n�mero de tics.
	orr r2, r0, r2, lsl #24		@; Se construye el valor del z�calo + el n�mero de tics.	
	ldr r0, =_gd_qDelay
	ldr r3, =_gd_nDelay
	ldr r1, [r3]
	str r2, [r0, r1]		@; Se almacena el valor del z�calo + el n�mero de tics en la �ltima posici�n de la cola de Delay.
	add r1, #1
	str r1, [r3]			@; Se incrementa el n�mero de procesos en la cola de Delay.
	bl _gp_WaitForVBlank		@; Se fuerza la cesi�n de la CPU a la espera de que se produzca un nuevo retroceso vertical.
	pop {r0-r3, pc}


	.global _gp_inihibirIRQs
	@; pone el bit IME (Interrupt Master Enable) a 0, para inhibir todas
	@; las IRQs y evitar as� posibles problemas debidos al cambio de contexto
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
	@; Rutina de Servicio de Interrupci�n (RSI) para contabilizar los tics
	@; de trabajo de cada proceso: suma los tics de todos los procesos y calcula
	@; el porcentaje de uso de la CPU, que se guarda en los 8 bits altos de la
	@; entrada _gd_pcbs[z].workTicks de cada proceso (z) y, si el procesador
	@; gr�fico secundario est� correctamente configurado, se imprime en la
	@; columna correspondiente de la tabla de procesos.
_gp_rsiTIMER0:
	push {lr}

	
	pop {pc}


	
.end

