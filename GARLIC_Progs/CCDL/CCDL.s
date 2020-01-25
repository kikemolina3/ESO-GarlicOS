	.arch armv5te
	.eabi_attribute 23, 1
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 1
	.eabi_attribute 30, 6
	.eabi_attribute 34, 0
	.eabi_attribute 18, 4
	.file	"CCDL.c"
	.text
	.align	2
	.global	alea
	.syntax unified
	.arm
	.fpu softvfp
	.type	alea, %function
alea:
	@ args = 0, pretend = 0, frame = 16
	@ frame_needed = 0, uses_anonymous_args = 0
	str	lr, [sp, #-4]!
	sub	sp, sp, #20
	str	r0, [sp, #4]
	bl	GARLIC_random
	mov	r3, r0
	mov	r0, r3
	ldr	r3, [sp, #4]
	add	r3, r3, #1
	mov	r1, r3
	add	r3, sp, #8
	add	r2, sp, #12
	bl	GARLIC_divmod
	ldr	r3, [sp, #8]
	mov	r0, r3
	add	sp, sp, #20
	@ sp needed
	ldr	pc, [sp], #4
	.size	alea, .-alea
	.align	2
	.global	raiz
	.syntax unified
	.arm
	.fpu softvfp
	.type	raiz, %function
raiz:
	@ args = 0, pretend = 0, frame = 24
	@ frame_needed = 0, uses_anonymous_args = 0
	str	lr, [sp, #-4]!
	sub	sp, sp, #28
	str	r0, [sp, #4]
	ldr	r3, [sp, #4]
	str	r3, [sp, #16]
	mov	r3, #0
	str	r3, [sp, #20]
	b	.L4
.L5:
	ldr	r3, [sp, #16]
	ldr	r2, [sp, #16]
	mul	r2, r3, r2
	ldr	r3, [sp, #4]
	add	r0, r2, r3
	ldr	r3, [sp, #16]
	lsl	r1, r3, #1
	add	r3, sp, #12
	add	r2, sp, #16
	bl	GARLIC_divmod
	ldr	r3, [sp, #20]
	add	r3, r3, #1
	str	r3, [sp, #20]
.L4:
	ldr	r3, [sp, #20]
	cmp	r3, #9
	ble	.L5
	ldr	r3, [sp, #16]
	mov	r0, r3
	add	sp, sp, #28
	@ sp needed
	ldr	pc, [sp], #4
	.size	raiz, .-raiz
	.align	2
	.global	pot
	.syntax unified
	.arm
	.fpu softvfp
	.type	pot, %function
pot:
	@ args = 0, pretend = 0, frame = 16
	@ frame_needed = 0, uses_anonymous_args = 0
	@ link register save eliminated.
	sub	sp, sp, #16
	str	r0, [sp, #4]
	str	r1, [sp]
	mov	r3, #1
	str	r3, [sp, #8]
	mov	r3, #0
	str	r3, [sp, #12]
	b	.L8
.L9:
	ldr	r3, [sp, #8]
	ldr	r2, [sp, #4]
	mul	r3, r2, r3
	str	r3, [sp, #8]
	ldr	r3, [sp, #12]
	add	r3, r3, #1
	str	r3, [sp, #12]
.L8:
	ldr	r2, [sp, #12]
	ldr	r3, [sp]
	cmp	r2, r3
	blt	.L9
	ldr	r3, [sp, #8]
	mov	r0, r3
	add	sp, sp, #16
	@ sp needed
	bx	lr
	.size	pot, .-pot
	.section	.rodata
	.align	2
.LC0:
	.ascii	"-- Programa CCDL  -  PID (%d) --\012\000"
	.align	2
.LC1:
	.ascii	"El numero es: %d \012Comb. sumas de cuadrados:\012\000"
	.align	2
.LC2:
	.ascii	"%d\011 \011%d\011 \011\000"
	.align	2
.LC3:
	.ascii	"%d\011 \011%d\012\000"
	.align	2
.LC4:
	.ascii	"El numero era: %d \012\000"
	.text
	.align	2
	.global	_start
	.syntax unified
	.arm
	.fpu softvfp
	.type	_start, %function
_start:
	@ args = 0, pretend = 0, frame = 40
	@ frame_needed = 0, uses_anonymous_args = 0
	str	lr, [sp, #-4]!
	sub	sp, sp, #44
	str	r0, [sp, #4]
	ldr	r3, [sp, #4]
	cmp	r3, #0
	bge	.L12
	mov	r3, #0
	str	r3, [sp, #4]
	b	.L13
.L12:
	ldr	r3, [sp, #4]
	cmp	r3, #3
	ble	.L13
	mov	r3, #3
	str	r3, [sp, #4]
.L13:
	bl	GARLIC_pid
	mov	r3, r0
	mov	r1, r3
	ldr	r0, .L17
	bl	GARLIC_printf
	mov	r3, #0
	str	r3, [sp, #36]
	ldr	r3, [sp, #4]
	add	r3, r3, #2
	mov	r1, r3
	mov	r0, #25
	bl	pot
	str	r0, [sp, #32]
	ldr	r0, [sp, #32]
	bl	alea
	str	r0, [sp, #28]
	ldr	r1, [sp, #28]
	ldr	r0, .L17+4
	bl	GARLIC_printf
	ldr	r3, [sp, #4]
	rsb	r3, r3, #3
	lsl	r3, r3, #1
	mov	r1, r3
	mov	r0, #2
	bl	pot
	str	r0, [sp, #24]
	b	.L14
.L15:
	ldr	r0, [sp, #28]
	bl	raiz
	mov	r3, r0
	mov	r0, r3
	bl	alea
	str	r0, [sp, #20]
	ldr	r3, [sp, #20]
	ldr	r2, [sp, #20]
	mul	r3, r2, r3
	ldr	r2, [sp, #28]
	sub	r3, r2, r3
	mov	r0, r3
	bl	raiz
	mov	r3, r0
	mov	r0, r3
	bl	alea
	str	r0, [sp, #16]
	ldr	r3, [sp, #20]
	ldr	r2, [sp, #20]
	mul	r3, r2, r3
	ldr	r2, [sp, #28]
	sub	r2, r2, r3
	ldr	r3, [sp, #16]
	ldr	r1, [sp, #16]
	mul	r3, r1, r3
	sub	r3, r2, r3
	mov	r0, r3
	bl	raiz
	mov	r3, r0
	mov	r0, r3
	bl	alea
	str	r0, [sp, #12]
	ldr	r3, [sp, #20]
	ldr	r2, [sp, #20]
	mul	r3, r2, r3
	ldr	r2, [sp, #28]
	sub	r2, r2, r3
	ldr	r3, [sp, #16]
	ldr	r1, [sp, #16]
	mul	r3, r1, r3
	sub	r2, r2, r3
	ldr	r3, [sp, #12]
	ldr	r1, [sp, #12]
	mul	r3, r1, r3
	sub	r3, r2, r3
	mov	r0, r3
	bl	raiz
	mov	r3, r0
	mov	r0, r3
	bl	alea
	str	r0, [sp, #8]
	ldr	r3, [sp, #20]
	ldr	r2, [sp, #20]
	mul	r2, r3, r2
	ldr	r3, [sp, #16]
	ldr	r1, [sp, #16]
	mul	r3, r1, r3
	add	r2, r2, r3
	ldr	r3, [sp, #12]
	ldr	r1, [sp, #12]
	mul	r3, r1, r3
	add	r2, r2, r3
	ldr	r3, [sp, #8]
	ldr	r1, [sp, #8]
	mul	r3, r1, r3
	add	r2, r2, r3
	ldr	r3, [sp, #28]
	cmp	r2, r3
	bne	.L14
	ldr	r3, [sp, #36]
	add	r3, r3, #1
	str	r3, [sp, #36]
	ldr	r2, [sp, #16]
	ldr	r1, [sp, #20]
	ldr	r0, .L17+8
	bl	GARLIC_printf
	ldr	r2, [sp, #8]
	ldr	r1, [sp, #12]
	ldr	r0, .L17+12
	bl	GARLIC_printf
.L14:
	ldr	r2, [sp, #36]
	ldr	r3, [sp, #24]
	cmp	r2, r3
	blt	.L15
	ldr	r1, [sp, #28]
	ldr	r0, .L17+16
	bl	GARLIC_printf
	mov	r3, #0
	mov	r0, r3
	add	sp, sp, #44
	@ sp needed
	ldr	pc, [sp], #4
.L18:
	.align	2
.L17:
	.word	.LC0
	.word	.LC1
	.word	.LC2
	.word	.LC3
	.word	.LC4
	.size	_start, .-_start
	.ident	"GCC: (devkitARM release 46) 6.3.0"
