; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -instcombine -instsimplify -S | FileCheck %s

; NOTE: we run instcombine first,
; to make sure that it does *NOT* drop uitofp+bitcast here.

; target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

; This is related to https://bugs.llvm.org/show_bug.cgi?id=36682

; FIXME: All of these can be simplified to a constant true or false value.
;   * slt i32 %b, 0  -> false
;   * sgt i32 %b, -1 -> true

define i1 @i32_cast_cmp_slt_int_0_uitofp_float(i32 %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_float(
; CHECK-NEXT:    [[F:%.*]] = uitofp i32 [[I:%.*]] to float
; CHECK-NEXT:    [[B:%.*]] = bitcast float [[F]] to i32
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i32 [[B]], 0
; CHECK-NEXT:    ret i1 [[CMP]]
;
  %f = uitofp i32 %i to float
  %b = bitcast float %f to i32
  %cmp = icmp slt i32 %b, 0
  ret i1 %cmp
}

define <2 x i1> @i32_cast_cmp_slt_int_0_uitofp_float_vec(<2 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_float_vec(
; CHECK-NEXT:    [[F:%.*]] = uitofp <2 x i32> [[I:%.*]] to <2 x float>
; CHECK-NEXT:    [[B:%.*]] = bitcast <2 x float> [[F]] to <2 x i32>
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt <2 x i32> [[B]], zeroinitializer
; CHECK-NEXT:    ret <2 x i1> [[CMP]]
;
  %f = uitofp <2 x i32> %i to <2 x float>
  %b = bitcast <2 x float> %f to <2 x i32>
  %cmp = icmp slt <2 x i32> %b, <i32 0, i32 0>
  ret <2 x i1> %cmp
}

define <3 x i1> @i32_cast_cmp_slt_int_0_uitofp_float_vec_undef(<3 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_float_vec_undef(
; CHECK-NEXT:    [[F:%.*]] = uitofp <3 x i32> [[I:%.*]] to <3 x float>
; CHECK-NEXT:    [[B:%.*]] = bitcast <3 x float> [[F]] to <3 x i32>
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt <3 x i32> [[B]], <i32 0, i32 undef, i32 0>
; CHECK-NEXT:    ret <3 x i1> [[CMP]]
;
  %f = uitofp <3 x i32> %i to <3 x float>
  %b = bitcast <3 x float> %f to <3 x i32>
  %cmp = icmp slt <3 x i32> %b, <i32 0, i32 undef, i32 0>
  ret <3 x i1> %cmp
}

define i1 @i32_cast_cmp_sgt_int_m1_uitofp_float(i32 %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_float(
; CHECK-NEXT:    [[F:%.*]] = uitofp i32 [[I:%.*]] to float
; CHECK-NEXT:    [[B:%.*]] = bitcast float [[F]] to i32
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt i32 [[B]], -1
; CHECK-NEXT:    ret i1 [[CMP]]
;
  %f = uitofp i32 %i to float
  %b = bitcast float %f to i32
  %cmp = icmp sgt i32 %b, -1
  ret i1 %cmp
}

define <2 x i1> @i32_cast_cmp_sgt_int_m1_uitofp_float_vec(<2 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_float_vec(
; CHECK-NEXT:    [[F:%.*]] = uitofp <2 x i32> [[I:%.*]] to <2 x float>
; CHECK-NEXT:    [[B:%.*]] = bitcast <2 x float> [[F]] to <2 x i32>
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt <2 x i32> [[B]], <i32 -1, i32 -1>
; CHECK-NEXT:    ret <2 x i1> [[CMP]]
;
  %f = uitofp <2 x i32> %i to <2 x float>
  %b = bitcast <2 x float> %f to <2 x i32>
  %cmp = icmp sgt <2 x i32> %b, <i32 -1, i32 -1>
  ret <2 x i1> %cmp
}

define <3 x i1> @i32_cast_cmp_sgt_int_m1_uitofp_float_vec_undef(<3 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_float_vec_undef(
; CHECK-NEXT:    [[F:%.*]] = uitofp <3 x i32> [[I:%.*]] to <3 x float>
; CHECK-NEXT:    [[B:%.*]] = bitcast <3 x float> [[F]] to <3 x i32>
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt <3 x i32> [[B]], <i32 -1, i32 undef, i32 -1>
; CHECK-NEXT:    ret <3 x i1> [[CMP]]
;
  %f = uitofp <3 x i32> %i to <3 x float>
  %b = bitcast <3 x float> %f to <3 x i32>
  %cmp = icmp sgt <3 x i32> %b, <i32 -1, i32 undef, i32 -1>
  ret <3 x i1> %cmp
}

define i1 @i32_cast_cmp_slt_int_0_uitofp_double(i32 %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_double(
; CHECK-NEXT:    [[F:%.*]] = uitofp i32 [[I:%.*]] to double
; CHECK-NEXT:    [[B:%.*]] = bitcast double [[F]] to i64
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i64 [[B]], 0
; CHECK-NEXT:    ret i1 [[CMP]]
;
  %f = uitofp i32 %i to double
  %b = bitcast double %f to i64
  %cmp = icmp slt i64 %b, 0
  ret i1 %cmp
}

define <2 x i1> @i32_cast_cmp_slt_int_0_uitofp_double_vec(<2 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_double_vec(
; CHECK-NEXT:    [[F:%.*]] = uitofp <2 x i32> [[I:%.*]] to <2 x double>
; CHECK-NEXT:    [[B:%.*]] = bitcast <2 x double> [[F]] to <2 x i64>
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt <2 x i64> [[B]], zeroinitializer
; CHECK-NEXT:    ret <2 x i1> [[CMP]]
;
  %f = uitofp <2 x i32> %i to <2 x double>
  %b = bitcast <2 x double> %f to <2 x i64>
  %cmp = icmp slt <2 x i64> %b, <i64 0, i64 0>
  ret <2 x i1> %cmp
}

define <3 x i1> @i32_cast_cmp_slt_int_0_uitofp_double_vec_undef(<3 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_double_vec_undef(
; CHECK-NEXT:    [[F:%.*]] = uitofp <3 x i32> [[I:%.*]] to <3 x double>
; CHECK-NEXT:    [[B:%.*]] = bitcast <3 x double> [[F]] to <3 x i64>
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt <3 x i64> [[B]], <i64 0, i64 undef, i64 0>
; CHECK-NEXT:    ret <3 x i1> [[CMP]]
;
  %f = uitofp <3 x i32> %i to <3 x double>
  %b = bitcast <3 x double> %f to <3 x i64>
  %cmp = icmp slt <3 x i64> %b, <i64 0, i64 undef, i64 0>
  ret <3 x i1> %cmp
}

define i1 @i32_cast_cmp_sgt_int_m1_uitofp_double(i32 %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_double(
; CHECK-NEXT:    [[F:%.*]] = uitofp i32 [[I:%.*]] to double
; CHECK-NEXT:    [[B:%.*]] = bitcast double [[F]] to i64
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt i64 [[B]], -1
; CHECK-NEXT:    ret i1 [[CMP]]
;
  %f = uitofp i32 %i to double
  %b = bitcast double %f to i64
  %cmp = icmp sgt i64 %b, -1
  ret i1 %cmp
}

define <2 x i1> @i32_cast_cmp_sgt_int_m1_uitofp_double_vec(<2 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_double_vec(
; CHECK-NEXT:    [[F:%.*]] = uitofp <2 x i32> [[I:%.*]] to <2 x double>
; CHECK-NEXT:    [[B:%.*]] = bitcast <2 x double> [[F]] to <2 x i64>
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt <2 x i64> [[B]], <i64 -1, i64 -1>
; CHECK-NEXT:    ret <2 x i1> [[CMP]]
;
  %f = uitofp <2 x i32> %i to <2 x double>
  %b = bitcast <2 x double> %f to <2 x i64>
  %cmp = icmp sgt <2 x i64> %b, <i64 -1, i64 -1>
  ret <2 x i1> %cmp
}

define <3 x i1> @i32_cast_cmp_sgt_int_m1_uitofp_double_vec_undef(<3 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_double_vec_undef(
; CHECK-NEXT:    [[F:%.*]] = uitofp <3 x i32> [[I:%.*]] to <3 x double>
; CHECK-NEXT:    [[B:%.*]] = bitcast <3 x double> [[F]] to <3 x i64>
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt <3 x i64> [[B]], <i64 -1, i64 undef, i64 -1>
; CHECK-NEXT:    ret <3 x i1> [[CMP]]
;
  %f = uitofp <3 x i32> %i to <3 x double>
  %b = bitcast <3 x double> %f to <3 x i64>
  %cmp = icmp sgt <3 x i64> %b, <i64 -1, i64 undef, i64 -1>
  ret <3 x i1> %cmp
}

define i1 @i32_cast_cmp_slt_int_0_uitofp_half(i32 %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_half(
; CHECK-NEXT:    [[F:%.*]] = uitofp i32 [[I:%.*]] to half
; CHECK-NEXT:    [[B:%.*]] = bitcast half [[F]] to i16
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i16 [[B]], 0
; CHECK-NEXT:    ret i1 [[CMP]]
;
  %f = uitofp i32 %i to half
  %b = bitcast half %f to i16
  %cmp = icmp slt i16 %b, 0
  ret i1 %cmp
}

define <2 x i1> @i32_cast_cmp_slt_int_0_uitofp_half_vec(<2 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_half_vec(
; CHECK-NEXT:    [[F:%.*]] = uitofp <2 x i32> [[I:%.*]] to <2 x half>
; CHECK-NEXT:    [[B:%.*]] = bitcast <2 x half> [[F]] to <2 x i16>
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt <2 x i16> [[B]], zeroinitializer
; CHECK-NEXT:    ret <2 x i1> [[CMP]]
;
  %f = uitofp <2 x i32> %i to <2 x half>
  %b = bitcast <2 x half> %f to <2 x i16>
  %cmp = icmp slt <2 x i16> %b, <i16 0, i16 0>
  ret <2 x i1> %cmp
}

define <3 x i1> @i32_cast_cmp_slt_int_0_uitofp_half_vec_undef(<3 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_slt_int_0_uitofp_half_vec_undef(
; CHECK-NEXT:    [[F:%.*]] = uitofp <3 x i32> [[I:%.*]] to <3 x half>
; CHECK-NEXT:    [[B:%.*]] = bitcast <3 x half> [[F]] to <3 x i16>
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt <3 x i16> [[B]], <i16 0, i16 undef, i16 0>
; CHECK-NEXT:    ret <3 x i1> [[CMP]]
;
  %f = uitofp <3 x i32> %i to <3 x half>
  %b = bitcast <3 x half> %f to <3 x i16>
  %cmp = icmp slt <3 x i16> %b, <i16 0, i16 undef, i16 0>
  ret <3 x i1> %cmp
}

define i1 @i32_cast_cmp_sgt_int_m1_uitofp_half(i32 %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_half(
; CHECK-NEXT:    [[F:%.*]] = uitofp i32 [[I:%.*]] to half
; CHECK-NEXT:    [[B:%.*]] = bitcast half [[F]] to i16
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt i16 [[B]], -1
; CHECK-NEXT:    ret i1 [[CMP]]
;
  %f = uitofp i32 %i to half
  %b = bitcast half %f to i16
  %cmp = icmp sgt i16 %b, -1
  ret i1 %cmp
}

define <2 x i1> @i32_cast_cmp_sgt_int_m1_uitofp_half_vec(<2 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_half_vec(
; CHECK-NEXT:    [[F:%.*]] = uitofp <2 x i32> [[I:%.*]] to <2 x half>
; CHECK-NEXT:    [[B:%.*]] = bitcast <2 x half> [[F]] to <2 x i16>
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt <2 x i16> [[B]], <i16 -1, i16 -1>
; CHECK-NEXT:    ret <2 x i1> [[CMP]]
;
  %f = uitofp <2 x i32> %i to <2 x half>
  %b = bitcast <2 x half> %f to <2 x i16>
  %cmp = icmp sgt <2 x i16> %b, <i16 -1, i16 -1>
  ret <2 x i1> %cmp
}

define <3 x i1> @i32_cast_cmp_sgt_int_m1_uitofp_half_vec_undef(<3 x i32> %i) {
; CHECK-LABEL: @i32_cast_cmp_sgt_int_m1_uitofp_half_vec_undef(
; CHECK-NEXT:    [[F:%.*]] = uitofp <3 x i32> [[I:%.*]] to <3 x half>
; CHECK-NEXT:    [[B:%.*]] = bitcast <3 x half> [[F]] to <3 x i16>
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt <3 x i16> [[B]], <i16 -1, i16 undef, i16 -1>
; CHECK-NEXT:    ret <3 x i1> [[CMP]]
;
  %f = uitofp <3 x i32> %i to <3 x half>
  %b = bitcast <3 x half> %f to <3 x i16>
  %cmp = icmp sgt <3 x i16> %b, <i16 -1, i16 undef, i16 -1>
  ret <3 x i1> %cmp
}
