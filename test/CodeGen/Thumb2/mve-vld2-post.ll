; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=thumbv8.1m.main-none-none-eabi -mattr=+mve.fp,+fp64 -verify-machineinstrs %s -o - | FileCheck %s

; i32

define <8 x i32> *@vld2_v4i32(<8 x i32> *%src, <4 x i32> *%dst) {
; CHECK-LABEL: vld2_v4i32:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vld20.32 {q0, q1}, [r0]
; CHECK-NEXT:    vld21.32 {q0, q1}, [r0]!
; CHECK-NEXT:    vadd.i32 q0, q0, q1
; CHECK-NEXT:    vstrw.32 q0, [r1]
; CHECK-NEXT:    bx lr
entry:
  %l1 = load <8 x i32>, <8 x i32>* %src, align 4
  %s1 = shufflevector <8 x i32> %l1, <8 x i32> undef, <4 x i32> <i32 0, i32 2, i32 4, i32 6>
  %s2 = shufflevector <8 x i32> %l1, <8 x i32> undef, <4 x i32> <i32 1, i32 3, i32 5, i32 7>
  %a = add <4 x i32> %s1, %s2
  store <4 x i32> %a, <4 x i32> *%dst
  %ret = getelementptr inbounds <8 x i32>, <8 x i32>* %src, i32 1
  ret <8 x i32> *%ret
}

; i16

define <16 x i16> *@vld2_v8i16(<16 x i16> *%src, <8 x i16> *%dst) {
; CHECK-LABEL: vld2_v8i16:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vld20.16 {q0, q1}, [r0]
; CHECK-NEXT:    vld21.16 {q0, q1}, [r0]!
; CHECK-NEXT:    vadd.i16 q0, q0, q1
; CHECK-NEXT:    vstrw.32 q0, [r1]
; CHECK-NEXT:    bx lr
entry:
  %l1 = load <16 x i16>, <16 x i16>* %src, align 4
  %s1 = shufflevector <16 x i16> %l1, <16 x i16> undef, <8 x i32> <i32 0, i32 2, i32 4, i32 6, i32 8, i32 10, i32 12, i32 14>
  %s2 = shufflevector <16 x i16> %l1, <16 x i16> undef, <8 x i32> <i32 1, i32 3, i32 5, i32 7, i32 9, i32 11, i32 13, i32 15>
  %a = add <8 x i16> %s1, %s2
  store <8 x i16> %a, <8 x i16> *%dst
  %ret = getelementptr inbounds <16 x i16>, <16 x i16>* %src, i32 1
  ret <16 x i16> *%ret
}

; i8

define <32 x i8> *@vld2_v16i8(<32 x i8> *%src, <16 x i8> *%dst) {
; CHECK-LABEL: vld2_v16i8:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vld20.8 {q0, q1}, [r0]
; CHECK-NEXT:    vld21.8 {q0, q1}, [r0]!
; CHECK-NEXT:    vadd.i8 q0, q0, q1
; CHECK-NEXT:    vstrw.32 q0, [r1]
; CHECK-NEXT:    bx lr
entry:
  %l1 = load <32 x i8>, <32 x i8>* %src, align 4
  %s1 = shufflevector <32 x i8> %l1, <32 x i8> undef, <16 x i32> <i32 0, i32 2, i32 4, i32 6, i32 8, i32 10, i32 12, i32 14, i32 16, i32 18, i32 20, i32 22, i32 24, i32 26, i32 28, i32 30>
  %s2 = shufflevector <32 x i8> %l1, <32 x i8> undef, <16 x i32> <i32 1, i32 3, i32 5, i32 7, i32 9, i32 11, i32 13, i32 15, i32 17, i32 19, i32 21, i32 23, i32 25, i32 27, i32 29, i32 31>
  %a = add <16 x i8> %s1, %s2
  store <16 x i8> %a, <16 x i8> *%dst
  %ret = getelementptr inbounds <32 x i8>, <32 x i8>* %src, i32 1
  ret <32 x i8> *%ret
}

; i64

define <4 x i64> *@vld2_v2i64(<4 x i64> *%src, <2 x i64> *%dst) {
; CHECK-LABEL: vld2_v2i64:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    .save {r4, r5, r6, lr}
; CHECK-NEXT:    push {r4, r5, r6, lr}
; CHECK-NEXT:    vldrw.u32 q2, [r0, #16]
; CHECK-NEXT:    vldrw.u32 q0, [r0], #32
; CHECK-NEXT:    vmov.f64 d2, d1
; CHECK-NEXT:    vmov.f32 s5, s3
; CHECK-NEXT:    vmov.f32 s6, s10
; CHECK-NEXT:    vmov.f32 s2, s8
; CHECK-NEXT:    vmov.f32 s7, s11
; CHECK-NEXT:    vmov.f32 s3, s9
; CHECK-NEXT:    vmov r2, s4
; CHECK-NEXT:    vmov r3, s0
; CHECK-NEXT:    vmov r12, s5
; CHECK-NEXT:    vmov lr, s1
; CHECK-NEXT:    vmov r4, s6
; CHECK-NEXT:    vmov r5, s2
; CHECK-NEXT:    adds r6, r3, r2
; CHECK-NEXT:    vmov r3, s7
; CHECK-NEXT:    vmov r2, s3
; CHECK-NEXT:    adc.w r12, r12, lr
; CHECK-NEXT:    adds r5, r5, r4
; CHECK-NEXT:    vmov q0[2], q0[0], r5, r6
; CHECK-NEXT:    adcs r2, r3
; CHECK-NEXT:    vmov q0[3], q0[1], r2, r12
; CHECK-NEXT:    vstrw.32 q0, [r1]
; CHECK-NEXT:    pop {r4, r5, r6, pc}
entry:
  %l1 = load <4 x i64>, <4 x i64>* %src, align 4
  %s1 = shufflevector <4 x i64> %l1, <4 x i64> undef, <2 x i32> <i32 0, i32 2>
  %s2 = shufflevector <4 x i64> %l1, <4 x i64> undef, <2 x i32> <i32 1, i32 3>
  %a = add <2 x i64> %s1, %s2
  store <2 x i64> %a, <2 x i64> *%dst
  %ret = getelementptr inbounds <4 x i64>, <4 x i64>* %src, i32 1
  ret <4 x i64> *%ret
}

; f32

define <8 x float> *@vld2_v4f32(<8 x float> *%src, <4 x float> *%dst) {
; CHECK-LABEL: vld2_v4f32:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vld20.32 {q0, q1}, [r0]
; CHECK-NEXT:    vld21.32 {q0, q1}, [r0]!
; CHECK-NEXT:    vadd.f32 q0, q0, q1
; CHECK-NEXT:    vstrw.32 q0, [r1]
; CHECK-NEXT:    bx lr
entry:
  %l1 = load <8 x float>, <8 x float>* %src, align 4
  %s1 = shufflevector <8 x float> %l1, <8 x float> undef, <4 x i32> <i32 0, i32 2, i32 4, i32 6>
  %s2 = shufflevector <8 x float> %l1, <8 x float> undef, <4 x i32> <i32 1, i32 3, i32 5, i32 7>
  %a = fadd <4 x float> %s1, %s2
  store <4 x float> %a, <4 x float> *%dst
  %ret = getelementptr inbounds <8 x float>, <8 x float>* %src, i32 1
  ret <8 x float> *%ret
}

; f16

define <16 x half> *@vld2_v8f16(<16 x half> *%src, <8 x half> *%dst) {
; CHECK-LABEL: vld2_v8f16:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vld20.16 {q0, q1}, [r0]
; CHECK-NEXT:    vld21.16 {q0, q1}, [r0]!
; CHECK-NEXT:    vadd.f16 q0, q0, q1
; CHECK-NEXT:    vstrw.32 q0, [r1]
; CHECK-NEXT:    bx lr
entry:
  %l1 = load <16 x half>, <16 x half>* %src, align 4
  %s1 = shufflevector <16 x half> %l1, <16 x half> undef, <8 x i32> <i32 0, i32 2, i32 4, i32 6, i32 8, i32 10, i32 12, i32 14>
  %s2 = shufflevector <16 x half> %l1, <16 x half> undef, <8 x i32> <i32 1, i32 3, i32 5, i32 7, i32 9, i32 11, i32 13, i32 15>
  %a = fadd <8 x half> %s1, %s2
  store <8 x half> %a, <8 x half> *%dst
  %ret = getelementptr inbounds <16 x half>, <16 x half>* %src, i32 1
  ret <16 x half> *%ret
}

; f64

define <4 x double> *@vld2_v2f64(<4 x double> *%src, <2 x double> *%dst) {
; CHECK-LABEL: vld2_v2f64:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    vldrw.u32 q0, [r0, #16]
; CHECK-NEXT:    vldrw.u32 q1, [r0], #32
; CHECK-NEXT:    vadd.f64 d1, d0, d1
; CHECK-NEXT:    vadd.f64 d0, d2, d3
; CHECK-NEXT:    vstrw.32 q0, [r1]
; CHECK-NEXT:    bx lr
entry:
  %l1 = load <4 x double>, <4 x double>* %src, align 4
  %s1 = shufflevector <4 x double> %l1, <4 x double> undef, <2 x i32> <i32 0, i32 2>
  %s2 = shufflevector <4 x double> %l1, <4 x double> undef, <2 x i32> <i32 1, i32 3>
  %a = fadd <2 x double> %s1, %s2
  store <2 x double> %a, <2 x double> *%dst
  %ret = getelementptr inbounds <4 x double>, <4 x double>* %src, i32 1
  ret <4 x double> *%ret
}
