; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-unknown-unknown | FileCheck %s

; This tests codegen time inlining/optimization of memcmp
; rdar://6480398

@.str = private constant [65 x i8] c"0123456789012345678901234567890123456789012345678901234567890123\00", align 1

declare i32 @memcmp(i8*, i8*, i64)

define i1 @length2(i8* %X, i8* %Y, i32* nocapture %P) nounwind {
; CHECK-LABEL: length2:
; CHECK:       # BB#0:
; CHECK-NEXT:    movzwl (%rdi), %eax
; CHECK-NEXT:    cmpw (%rsi), %ax
; CHECK-NEXT:    sete %al
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* %Y, i64 2) nounwind
  %c = icmp eq i32 %m, 0
  ret i1 %c
}

define i1 @length2_const(i8* %X, i32* nocapture %P) nounwind {
; CHECK-LABEL: length2_const:
; CHECK:       # BB#0:
; CHECK-NEXT:    movzwl (%rdi), %eax
; CHECK-NEXT:    cmpl $12849, %eax # imm = 0x3231
; CHECK-NEXT:    setne %al
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* getelementptr inbounds ([65 x i8], [65 x i8]* @.str, i32 0, i32 1), i64 2) nounwind
  %c = icmp ne i32 %m, 0
  ret i1 %c
}

define i1 @length2_nobuiltin_attr(i8* %X, i8* %Y, i32* nocapture %P) nounwind {
; CHECK-LABEL: length2_nobuiltin_attr:
; CHECK:       # BB#0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    movl $2, %edx
; CHECK-NEXT:    callq memcmp
; CHECK-NEXT:    testl %eax, %eax
; CHECK-NEXT:    sete %al
; CHECK-NEXT:    popq %rcx
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* %Y, i64 2) nounwind nobuiltin
  %c = icmp eq i32 %m, 0
  ret i1 %c
}

define i1 @length4(i8* %X, i8* %Y, i32* nocapture %P) nounwind {
; CHECK-LABEL: length4:
; CHECK:       # BB#0:
; CHECK-NEXT:    movl (%rdi), %eax
; CHECK-NEXT:    cmpl (%rsi), %eax
; CHECK-NEXT:    setne %al
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* %Y, i64 4) nounwind
  %c = icmp ne i32 %m, 0
  ret i1 %c
}

define i1 @length4_const(i8* %X, i32* nocapture %P) nounwind {
; CHECK-LABEL: length4_const:
; CHECK:       # BB#0:
; CHECK-NEXT:    cmpl $875770417, (%rdi) # imm = 0x34333231
; CHECK-NEXT:    sete %al
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* getelementptr inbounds ([65 x i8], [65 x i8]* @.str, i32 0, i32 1), i64 4) nounwind
  %c = icmp eq i32 %m, 0
  ret i1 %c
}

define i1 @length8(i8* %X, i8* %Y, i32* nocapture %P) nounwind {
; CHECK-LABEL: length8:
; CHECK:       # BB#0:
; CHECK-NEXT:    movq (%rdi), %rax
; CHECK-NEXT:    cmpq (%rsi), %rax
; CHECK-NEXT:    sete %al
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* %Y, i64 8) nounwind
  %c = icmp eq i32 %m, 0
  ret i1 %c
}

define i1 @length8_const(i8* %X, i32* nocapture %P) nounwind {
; CHECK-LABEL: length8_const:
; CHECK:       # BB#0:
; CHECK-NEXT:    movabsq $3978425819141910832, %rax # imm = 0x3736353433323130
; CHECK-NEXT:    cmpq %rax, (%rdi)
; CHECK-NEXT:    setne %al
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* getelementptr inbounds ([65 x i8], [65 x i8]* @.str, i32 0, i32 0), i64 8) nounwind
  %c = icmp ne i32 %m, 0
  ret i1 %c
}

define i1 @length16(i8* %x, i8* %y) nounwind {
; CHECK-LABEL: length16:
; CHECK:       # BB#0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    movl $16, %edx
; CHECK-NEXT:    callq memcmp
; CHECK-NEXT:    testl %eax, %eax
; CHECK-NEXT:    setne %al
; CHECK-NEXT:    popq %rcx
; CHECK-NEXT:    retq
  %call = tail call i32 @memcmp(i8* %x, i8* %y, i64 16) nounwind
  %cmp = icmp ne i32 %call, 0
  ret i1 %cmp
}

define i1 @length16_const(i8* %X, i32* nocapture %P) nounwind {
; CHECK-LABEL: length16_const:
; CHECK:       # BB#0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    movl $.L.str, %esi
; CHECK-NEXT:    movl $16, %edx
; CHECK-NEXT:    callq memcmp
; CHECK-NEXT:    testl %eax, %eax
; CHECK-NEXT:    sete %al
; CHECK-NEXT:    popq %rcx
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* getelementptr inbounds ([65 x i8], [65 x i8]* @.str, i32 0, i32 0), i64 16) nounwind
  %c = icmp eq i32 %m, 0
  ret i1 %c
}

define i1 @length32(i8* %x, i8* %y) nounwind {
; CHECK-LABEL: length32:
; CHECK:       # BB#0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    movl $32, %edx
; CHECK-NEXT:    callq memcmp
; CHECK-NEXT:    testl %eax, %eax
; CHECK-NEXT:    sete %al
; CHECK-NEXT:    popq %rcx
; CHECK-NEXT:    retq
  %call = tail call i32 @memcmp(i8* %x, i8* %y, i64 32) nounwind
  %cmp = icmp eq i32 %call, 0
  ret i1 %cmp
}

define i1 @length32_const(i8* %X, i32* nocapture %P) nounwind {
; CHECK-LABEL: length32_const:
; CHECK:       # BB#0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    movl $.L.str, %esi
; CHECK-NEXT:    movl $32, %edx
; CHECK-NEXT:    callq memcmp
; CHECK-NEXT:    testl %eax, %eax
; CHECK-NEXT:    setne %al
; CHECK-NEXT:    popq %rcx
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* getelementptr inbounds ([65 x i8], [65 x i8]* @.str, i32 0, i32 0), i64 32) nounwind
  %c = icmp ne i32 %m, 0
  ret i1 %c
}

define i1 @length64(i8* %x, i8* %y) nounwind {
; CHECK-LABEL: length64:
; CHECK:       # BB#0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    movl $64, %edx
; CHECK-NEXT:    callq memcmp
; CHECK-NEXT:    testl %eax, %eax
; CHECK-NEXT:    setne %al
; CHECK-NEXT:    popq %rcx
; CHECK-NEXT:    retq
  %call = tail call i32 @memcmp(i8* %x, i8* %y, i64 64) nounwind
  %cmp = icmp ne i32 %call, 0
  ret i1 %cmp
}

define i1 @length64_const(i8* %X, i32* nocapture %P) nounwind {
; CHECK-LABEL: length64_const:
; CHECK:       # BB#0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    movl $.L.str, %esi
; CHECK-NEXT:    movl $64, %edx
; CHECK-NEXT:    callq memcmp
; CHECK-NEXT:    testl %eax, %eax
; CHECK-NEXT:    sete %al
; CHECK-NEXT:    popq %rcx
; CHECK-NEXT:    retq
  %m = tail call i32 @memcmp(i8* %X, i8* getelementptr inbounds ([65 x i8], [65 x i8]* @.str, i32 0, i32 0), i64 64) nounwind
  %c = icmp eq i32 %m, 0
  ret i1 %c
}

