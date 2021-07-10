; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --check-attributes --check-globals
; RUN: opt -attributor -enable-new-pm=0 -attributor-manifest-internal  -attributor-max-iterations-verify -attributor-annotate-decl-cs -attributor-max-iterations=1 -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_CGSCC_NPM,NOT_CGSCC_OPM,NOT_TUNIT_NPM,IS__TUNIT____,IS________OPM,IS__TUNIT_OPM
; RUN: opt -aa-pipeline=basic-aa -passes=attributor -attributor-manifest-internal  -attributor-max-iterations-verify -attributor-annotate-decl-cs -attributor-max-iterations=1 -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_CGSCC_OPM,NOT_CGSCC_NPM,NOT_TUNIT_OPM,IS__TUNIT____,IS________NPM,IS__TUNIT_NPM
; RUN: opt -attributor-cgscc -enable-new-pm=0 -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_TUNIT_NPM,NOT_TUNIT_OPM,NOT_CGSCC_NPM,IS__CGSCC____,IS________OPM,IS__CGSCC_OPM
; RUN: opt -aa-pipeline=basic-aa -passes=attributor-cgscc -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,NOT_TUNIT_NPM,NOT_TUNIT_OPM,NOT_CGSCC_OPM,IS__CGSCC____,IS________NPM,IS__CGSCC_NPM

declare void @unknown()

declare void @bar(i32*)

define void @foo() {
; CHECK-LABEL: define {{[^@]+}}@foo() {
; CHECK-NEXT:    [[X:%.*]] = alloca i32, align 4
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    call void @bar(i32* noundef nonnull align 4 dereferenceable(4) [[X]])
; CHECK-NEXT:    ret void
;
  %x = alloca i32
  call void @unknown()
  call void @bar(i32* %x)
  ret void
}

define internal i8* @returned_dead() {
; CHECK-LABEL: define {{[^@]+}}@returned_dead() {
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    ret i8* undef
;
  call void @unknown()
  ret i8* null
}

define void @caller1() {
; CHECK-LABEL: define {{[^@]+}}@caller1() {
; CHECK-NEXT:    [[TMP1:%.*]] = call i8* @returned_dead()
; CHECK-NEXT:    ret void
;
  call i8* @returned_dead()
  ret void
}

define internal void @argument_dead_callback_callee(i8* %c) {
; CHECK-LABEL: define {{[^@]+}}@argument_dead_callback_callee
; CHECK-SAME: (i8* noalias nocapture nofree readnone align 536870912 [[C:%.*]]) {
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    ret void
;
  call void @unknown()
  ret void
}

define void @callback_caller() {
; IS__TUNIT____-LABEL: define {{[^@]+}}@callback_caller() {
; IS__TUNIT____-NEXT:    call void @callback_broker(void (i8*)* noundef @argument_dead_callback_callee, i8* noalias nocapture nofree readnone align 536870912 undef)
; IS__TUNIT____-NEXT:    ret void
;
; IS__CGSCC____-LABEL: define {{[^@]+}}@callback_caller() {
; IS__CGSCC____-NEXT:    call void @callback_broker(void (i8*)* noundef @argument_dead_callback_callee, i8* noalias nocapture nofree noundef readnone align 536870912 null)
; IS__CGSCC____-NEXT:    ret void
;
  call void @callback_broker(void (i8*)* @argument_dead_callback_callee, i8* null)
  ret void
}

; Drop the noundef if when we replace the call argument with `undef`. We use a
; varargs function as we cannot (yet) rewrite their signature. If we ever can,
; try to come up with a different scheme to verify the `noundef` is dropped if
; signature rewriting is not happening.
define internal void @callee_with_dead_noundef_arg(i1 noundef %create, ...) {
; CHECK-LABEL: define {{[^@]+}}@callee_with_dead_noundef_arg
; CHECK-SAME: (i1 [[CREATE:%.*]], ...) {
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    ret void
;
  call void @unknown()
  ret void
}

define void @caller_with_unused_arg(i1 %c) {
; CHECK-LABEL: define {{[^@]+}}@caller_with_unused_arg
; CHECK-SAME: (i1 [[C:%.*]]) {
; CHECK-NEXT:    call void (i1, ...) @callee_with_dead_noundef_arg(i1 undef)
; CHECK-NEXT:    ret void
;
  call void (i1, ...) @callee_with_dead_noundef_arg(i1 %c)
  ret void
}

define internal void @callee_with_dead_arg(i1 %create, ...) {
; CHECK-LABEL: define {{[^@]+}}@callee_with_dead_arg
; CHECK-SAME: (i1 [[CREATE:%.*]], ...) {
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[IF_THEN3:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    unreachable
; CHECK:       if.then3:
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    ret void
;
entry:
  br i1 %create, label %if.then3, label %if.then

if.then:                                          ; preds = %entry
  ret void

if.then3:                                         ; preds = %entry
  call void @unknown()
  ret void
}

; Drop the noundef if when we replace the call argument with `undef`. We use a
; varargs function as we cannot (yet) rewrite their signature. If we ever can,
; try to come up with a different scheme to verify the `noundef` is dropped if
; signature rewriting is not happening.
define void @caller_with_noundef_arg() {
; CHECK-LABEL: define {{[^@]+}}@caller_with_noundef_arg() {
; CHECK-NEXT:    call void (i1, ...) @callee_with_dead_arg(i1 undef)
; CHECK-NEXT:    ret void
;
  call void (i1, ...) @callee_with_dead_arg(i1 noundef true)
  ret void
}

declare !callback !0 void @callback_broker(void (i8*)*, i8*)
!1 = !{i64 0, i64 1, i1 false}
!0 = !{!1}
;.
; CHECK: [[META0:![0-9]+]] = !{!1}
; CHECK: [[META1:![0-9]+]] = !{i64 0, i64 1, i1 false}
;.
