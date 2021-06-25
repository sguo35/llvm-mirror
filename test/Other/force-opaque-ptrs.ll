; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: llvm-as --force-opaque-pointers < %s | llvm-dis | FileCheck %s
; RUN: llvm-as < %s | llvm-dis --force-opaque-pointers | FileCheck %s
; RUN: opt --force-opaque-pointers < %s -S | FileCheck %s

; CHECK: @g = external global i16
@g = external global i16

define void @f(i32* %p) {
; CHECK-LABEL: @f(
; CHECK-NEXT:    ret void
;
  ret void
}
