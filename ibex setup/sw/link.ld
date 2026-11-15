OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K }
__stack_top = ORIGIN(RAM) + LENGTH(RAM);
__stack_bottom = __stack_top - 4K;
SECTIONS {
  .vectors : { KEEP(*(.vectors)) } > RAM
  .text : { *(.text .text.*) } > RAM
  .rodata : { *(.srodata .srodata.* .rodata .rodata.*) } > RAM
  .data : {
    . = ALIGN(4);
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.* .data .data.*)
  } > RAM
  .bss (NOLOAD) : {
    . = ALIGN(4);
    __bss_start = .;
    *(.sbss .sbss.* .bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM
  ASSERT(_start == 0x80, "Reset entry must be at 0x80")
  ASSERT(__bss_end <= __stack_bottom, "Firmware overlaps reserved 4 KiB stack")
}
