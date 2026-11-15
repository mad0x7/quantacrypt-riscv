.section .vectors, "ax", @progbits
.option norvc
.globl _vectors
_vectors:
  .rept 32
    j trap_entry
  .endr

// boot_addr_i = 0: Ibex begins execution at byte address 0x80.
.globl _start
_start:
.option rvc
.option push
.option norelax
  la sp, __stack_top
  la gp, __global_pointer$
.option pop
  la t0, _vectors
  csrw mtvec, t0
  csrwi mie, 0
  csrwi mcountinhibit, 0
  la t0, __bss_start
  la t1, __bss_end
1:
  bgeu t0, t1, 2f
  sw zero, 0(t0)
  addi t0, t0, 4
  j 1b
2:
  call main
3:
  j 3b

.section .text.trap, "ax", @progbits
trap_entry:
  li t0, 0x80000000
  li t1, 15
  sw t1, 0(t0)
4:
  j 4b

.section .note.GNU-stack, "", @progbits
