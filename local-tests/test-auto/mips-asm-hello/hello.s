		.rdata					# begin read-only data segment
		.align		2			# because of the way memory is built
hello:		.asciz		"Hello, world!\n"	# a null terminated string
		.align		4			# because of the way memory is built
length:		.word		. - hello		# length = IC - (hello-addr)
		.text					# begin code segment
		.globl		main			# for gcc/ld linking
		.ent		main			# for gdb debugging info.
main:		# We must specify -non_shared to gcc or we`ll need these 3 lines that fallow.
#		.set		noreorder		# disable instruction reordering
#		.cpload		t9			# PIC ABI crap (function prologue)
#		.set		reorder			# re-enable instruction reordering
		move		a0,$0			# load stdout fd
		la		a1,hello		# load string address
		lw		a2,length		# load string length
		li		v0,__NR_write		# specify system write service
		syscall					# call the kernel (write string)
		li		v0,0			# load return code
		j		ra			# return to caller
		.end		main			# for dgb debugging info.
