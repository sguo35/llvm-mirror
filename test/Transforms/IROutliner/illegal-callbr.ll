; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -S -verify -iroutliner < %s | FileCheck %s

; This test checks that we do not outline callbr instruction since as we do not
; outline any control flow change instructions.


define i32 @function1(i32 %a, i32 %b) {
; CHECK-LABEL: @function1(
; CHECK-NEXT:  bb0:
; CHECK-NEXT:    [[TMP0:%.*]] = add i32 [[A:%.*]], 4
; CHECK-NEXT:    call void @function1.outlined(i32 [[B:%.*]])
; CHECK-NEXT:    callbr void asm "xorl $0, $0
; CHECK-NEXT:    to label [[NORMAL:%.*]] [label %fail1]
; CHECK:       normal:
; CHECK-NEXT:    call void @function1.outlined.1(i32 [[B]])
; CHECK-NEXT:    ret i32 0
; CHECK:       fail1:
; CHECK-NEXT:    [[TMP1:%.*]] = add i32 [[B]], 1
; CHECK-NEXT:    [[TMP2:%.*]] = add i32 [[B]], 1
; CHECK-NEXT:    ret i32 0
;
bb0:
  %0 = add i32 %a, 4
  %1 = add i32 %b, 1
  %2 = add i32 %b, 1
  callbr void asm "xorl $0, $0; jmp ${1:l}", "r,X,~{dirflag},~{fpsr},~{flags}"(i32 %0, i8* blockaddress(@function1, %fail1)) to label %normal [label %fail1]
normal:
  %3 = add i32 %b, 1
  %4 = add i32 %b, 1
  ret i32 0
fail1:
  %5 = add i32 %b, 1
  %6 = add i32 %b, 1
  ret i32 0
}

define i32 @function2(i32 %a, i32 %b) {
; CHECK-LABEL: @function2(
; CHECK-NEXT:  bb0:
; CHECK-NEXT:    [[TMP0:%.*]] = add i32 [[A:%.*]], 4
; CHECK-NEXT:    call void @function2.outlined(i32 [[B:%.*]])
; CHECK-NEXT:    callbr void asm "xorl $0, $0
; CHECK-NEXT:    to label [[NORMAL:%.*]] [label %fail1]
; CHECK:       normal:
; CHECK-NEXT:    call void @function2.outlined.2(i32 [[B]])
; CHECK-NEXT:    ret i32 0
; CHECK:       fail1:
; CHECK-NEXT:    [[TMP1:%.*]] = add i32 [[B]], 1
; CHECK-NEXT:    [[TMP2:%.*]] = add i32 [[B]], 1
; CHECK-NEXT:    ret i32 0
;
bb0:
  %0 = add i32 %a, 4
  %1 = add i32 %b, 1
  %2 = add i32 %b, 1
  callbr void asm "xorl $0, $0; jmp ${1:l}", "r,X,~{dirflag},~{fpsr},~{flags}"(i32 %0, i8* blockaddress(@function2, %fail1)) to label %normal [label %fail1]
normal:
  %3 = add i32 %b, 1
  %4 = add i32 %b, 1
  ret i32 0
fail1:
  %5 = add i32 %b, 1
  %6 = add i32 %b, 1
  ret i32 0
}
