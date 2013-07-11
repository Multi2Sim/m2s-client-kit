		.rdata					# begin read-only data segment
		.align		2			# because of the way memory is built
hello:		.asciz		"Hello, world!\n"	# a null terminated string
		.align		4			# because of the way memory is built
length:		.word		. - hello		# length = IC - (hello-addr)
		.text					# begin code segment
		.global		__start
__start:	# We must specify -non_shared to gcc or we`ll need these 3 lines that fallow.
		move		$a0, $0			# load stdout fd
		la		$a1, hello		# load string address
		lw		$a2, length		# load string length
		li		$v0, 4004		# specify system write service
		syscall					# call the kernel (write string)
		li		$v0, 4246		# Syscall 'exit_group'
		syscall
