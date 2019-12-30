	.arch armv5te
	.eabi_attribute 23, 1
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 1
	.eabi_attribute 30, 6
	.eabi_attribute 34, 0
	.eabi_attribute 18, 4
	.file	"XIFA.c"
	.section	.rodata
	.align	2
.LC19:
	.ascii	"PID (%d)%s\011\000"
	.align	2
.LC0:
	.ascii	"el 20 de diciembre montar\351 el \341rbol de navida"
	.ascii	"d.\000"
	.align	2
.LC1:
	.ascii	"el 9 de enero del 2018 se entrega la pr\341ctica de"
	.ascii	" la asignatura.\000"
	.align	2
.LC2:
	.ascii	"quiero ir al cine a ver la pel\355cula 1917\000"
	.align	2
.LC3:
	.ascii	"eL 21 de junio es el cumplea\361os de mi hermana\000"
	.align	2
.LC4:
	.ascii	"no entiendo porque hay gente a la que no le gusta b"
	.ascii	"lade runner 2049\000"
	.align	2
.LC5:
	.ascii	"este verano he le\355do 3 libros\000"
	.align	2
.LC6:
	.ascii	"querr\355a sacar un 10 en alguna pr\341ctica de pro"
	.ascii	"gramaci\363n\000"
	.align	2
.LC7:
	.ascii	"este viernes tengo cena de navidad a las 22 horas\000"
	.align	2
.LC8:
	.ascii	"joker estar\341 nominada a 8 oscars\000"
	.align	2
.LC9:
	.ascii	"el mes de agosto tiene 31 d\355as\000"
	.align	2
.LC16:
	.word	.LC0
	.word	.LC1
	.word	.LC2
	.word	.LC3
	.word	.LC4
	.word	.LC5
	.word	.LC6
	.word	.LC7
	.word	.LC8
	.word	.LC9
	.align	2
.LC11:
	.ascii	"0fqbizw1xm8ern2gtskpu3jdo7hi4v9cl6a5\000"
	.align	2
.LC12:
	.ascii	"til6b2ugdm4rqvkfy5nspc8z37ohj9wa1ex0\000"
	.align	2
.LC13:
	.ascii	"o1segf20haydrbzp4nq98ctk3xi75wju6mvl\000"
	.align	2
.LC14:
	.ascii	"1gr4hde2av9m8pinkzbyuf6t5gxs3owlq7c0\000"
	.align	2
.LC17:
	.word	.LC11
	.word	.LC12
	.word	.LC13
	.word	.LC14
	.align	2
.LC18:
	.ascii	"ADFGVX\000"
	.text
	.align	2
	.global	_start
	.syntax unified
	.arm
	.fpu softvfp
	.type	_start, %function
_start:
	@ args = 0, pretend = 0, frame = 208
	@ frame_needed = 0, uses_anonymous_args = 0
	str	lr, [sp, #-4]!
	sub	sp, sp, #212
	str	r0, [sp, #4]
	ldr	r3, .L12
	add	ip, sp, #152
	mov	lr, r3
	ldmia	lr!, {r0, r1, r2, r3}
	stmia	ip!, {r0, r1, r2, r3}
	ldmia	lr!, {r0, r1, r2, r3}
	stmia	ip!, {r0, r1, r2, r3}
	ldm	lr, {r0, r1}
	stm	ip, {r0, r1}
	ldr	r3, .L12+4
	add	ip, sp, #136
	ldm	r3, {r0, r1, r2, r3}
	stm	ip, {r0, r1, r2, r3}
	ldr	r2, .L12+8
	add	r3, sp, #128
	ldm	r2, {r0, r1}
	str	r0, [r3]
	add	r3, r3, #4
	strh	r1, [r3]	@ movhi
	mov	r3, #0
	str	r3, [sp, #192]
	ldr	r3, [sp, #4]
	cmp	r3, #0
	bge	.L2
	mov	r3, #0
	str	r3, [sp, #4]
	b	.L3
.L2:
	ldr	r3, [sp, #4]
	cmp	r3, #3
	ble	.L3
	mov	r3, #3
	str	r3, [sp, #4]
.L3:
	bl	GARLIC_random
	mov	r3, r0
	mov	r0, r3
	add	r3, sp, #8
	add	r2, sp, #16
	mov	r1, #10
	bl	GARLIC_divmod
	b	.L4
.L11:
	mov	r3, #0
	str	r3, [sp, #196]
	mov	r3, #0
	str	r3, [sp, #204]
	b	.L5
.L10:
	mov	r3, #0
	str	r3, [sp, #200]
	b	.L6
.L9:
	ldr	r3, [sp, #8]
	lsl	r3, r3, #2
	add	r2, sp, #208
	add	r3, r2, r3
	ldr	r2, [r3, #-56]
	ldr	r3, [sp, #204]
	add	r3, r2, r3
	ldrb	r2, [r3]	@ zero_extendqisi2
	ldr	r3, [sp, #4]
	lsl	r3, r3, #2
	add	r1, sp, #208
	add	r3, r1, r3
	ldr	r1, [r3, #-72]
	ldr	r3, [sp, #200]
	add	r3, r1, r3
	ldrb	r3, [r3]	@ zero_extendqisi2
	cmp	r2, r3
	bne	.L7
	mov	r3, #1
	str	r3, [sp, #192]
	b	.L6
.L7:
	ldr	r3, [sp, #200]
	add	r3, r3, #1
	str	r3, [sp, #200]
.L6:
	ldr	r3, [sp, #192]
	cmp	r3, #0
	bne	.L8
	ldr	r3, [sp, #4]
	lsl	r3, r3, #2
	add	r2, sp, #208
	add	r3, r2, r3
	ldr	r2, [r3, #-72]
	ldr	r3, [sp, #200]
	add	r3, r2, r3
	ldrb	r3, [r3]	@ zero_extendqisi2
	cmp	r3, #0
	bne	.L9
.L8:
	add	r3, sp, #12
	add	r2, sp, #16
	mov	r1, #10
	ldr	r0, [sp, #200]
	bl	GARLIC_divmod
	ldr	r3, [sp, #196]
	add	r2, r3, #1
	str	r2, [sp, #196]
	ldr	r2, [sp, #12]
	add	r1, sp, #208
	add	r2, r1, r2
	ldrb	r2, [r2, #-80]	@ zero_extendqisi2
	add	r1, sp, #208
	add	r3, r1, r3
	strb	r2, [r3, #-188]
	ldr	r3, [sp, #196]
	add	r2, r3, #1
	str	r2, [sp, #196]
	ldr	r2, [sp, #16]
	add	r1, sp, #208
	add	r2, r1, r2
	ldrb	r2, [r2, #-80]	@ zero_extendqisi2
	add	r1, sp, #208
	add	r3, r1, r3
	strb	r2, [r3, #-188]
	ldr	r3, [sp, #204]
	add	r3, r3, #1
	str	r3, [sp, #204]
.L5:
	ldr	r3, [sp, #8]
	lsl	r3, r3, #2
	add	r2, sp, #208
	add	r3, r2, r3
	ldr	r2, [r3, #-56]
	ldr	r3, [sp, #204]
	add	r3, r2, r3
	ldrb	r3, [r3]	@ zero_extendqisi2
	cmp	r3, #0
	bne	.L10
	add	r2, sp, #20
	ldr	r3, [sp, #196]
	add	r3, r2, r3
	mov	r2, #0
	strb	r2, [r3]
	add	r3, sp, #20
	mov	r2, r3
	ldr	r1, .L12+12
	ldr	r0, .L12+16
	bl	GARLIC_printf
	ldr	r3, [sp, #8]
	add	r3, r3, #1
	str	r3, [sp, #8]
.L4:
	ldr	r3, [sp, #8]
	cmp	r3, #9
	bls	.L11
	nop
	add	sp, sp, #212
	@ sp needed
	ldr	pc, [sp], #4
.L13:
	.align	2
.L12:
	.word	.LC16
	.word	.LC17
	.word	.LC18
	.word	GARLIC_pid
	.word	.LC19
	.size	_start, .-_start
	.ident	"GCC: (devkitARM release 46) 6.3.0"
