; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=riscv32 -target-abi=ilp32d -mattr=+experimental-v,+experimental-zfh,+f,+d -verify-machineinstrs -riscv-v-vector-bits-min=128 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=RV32
; RUN: llc -mtriple=riscv64 -target-abi=lp64d -mattr=+experimental-v,+experimental-zfh,+f,+d -verify-machineinstrs -riscv-v-vector-bits-min=128 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=RV64

define i8 @extractelt_v16i8(<16 x i8>* %x) nounwind {
; RV32-LABEL: extractelt_v16i8:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 16, e8,m1,ta,mu
; RV32-NEXT:    vle8.v v25, (a0)
; RV32-NEXT:    vsetivli a0, 1, e8,m1,ta,mu
; RV32-NEXT:    vslidedown.vi v25, v25, 7
; RV32-NEXT:    vmv.x.s a0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v16i8:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 16, e8,m1,ta,mu
; RV64-NEXT:    vle8.v v25, (a0)
; RV64-NEXT:    vsetivli a0, 1, e8,m1,ta,mu
; RV64-NEXT:    vslidedown.vi v25, v25, 7
; RV64-NEXT:    vmv.x.s a0, v25
; RV64-NEXT:    ret
  %a = load <16 x i8>, <16 x i8>* %x
  %b = extractelement <16 x i8> %a, i32 7
  ret i8 %b
}

define i16 @extractelt_v8i16(<8 x i16>* %x) nounwind {
; RV32-LABEL: extractelt_v8i16:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 8, e16,m1,ta,mu
; RV32-NEXT:    vle16.v v25, (a0)
; RV32-NEXT:    vsetivli a0, 1, e16,m1,ta,mu
; RV32-NEXT:    vslidedown.vi v25, v25, 7
; RV32-NEXT:    vmv.x.s a0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v8i16:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 8, e16,m1,ta,mu
; RV64-NEXT:    vle16.v v25, (a0)
; RV64-NEXT:    vsetivli a0, 1, e16,m1,ta,mu
; RV64-NEXT:    vslidedown.vi v25, v25, 7
; RV64-NEXT:    vmv.x.s a0, v25
; RV64-NEXT:    ret
  %a = load <8 x i16>, <8 x i16>* %x
  %b = extractelement <8 x i16> %a, i32 7
  ret i16 %b
}

define i32 @extractelt_v4i32(<4 x i32>* %x) nounwind {
; RV32-LABEL: extractelt_v4i32:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 4, e32,m1,ta,mu
; RV32-NEXT:    vle32.v v25, (a0)
; RV32-NEXT:    vsetivli a0, 1, e32,m1,ta,mu
; RV32-NEXT:    vslidedown.vi v25, v25, 2
; RV32-NEXT:    vmv.x.s a0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v4i32:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 4, e32,m1,ta,mu
; RV64-NEXT:    vle32.v v25, (a0)
; RV64-NEXT:    vsetivli a0, 1, e32,m1,ta,mu
; RV64-NEXT:    vslidedown.vi v25, v25, 2
; RV64-NEXT:    vmv.x.s a0, v25
; RV64-NEXT:    ret
  %a = load <4 x i32>, <4 x i32>* %x
  %b = extractelement <4 x i32> %a, i32 2
  ret i32 %b
}

define i64 @extractelt_v2i64(<2 x i64>* %x) nounwind {
; RV32-LABEL: extractelt_v2i64:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 2, e64,m1,ta,mu
; RV32-NEXT:    vle64.v v25, (a0)
; RV32-NEXT:    addi a0, zero, 32
; RV32-NEXT:    vsetivli a1, 1, e64,m1,ta,mu
; RV32-NEXT:    vsrl.vx v26, v25, a0
; RV32-NEXT:    vmv.x.s a1, v26
; RV32-NEXT:    vmv.x.s a0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v2i64:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 2, e64,m1,ta,mu
; RV64-NEXT:    vle64.v v25, (a0)
; RV64-NEXT:    vmv.x.s a0, v25
; RV64-NEXT:    ret
  %a = load <2 x i64>, <2 x i64>* %x
  %b = extractelement <2 x i64> %a, i32 0
  ret i64 %b
}

define half @extractelt_v8f16(<8 x half>* %x) nounwind {
; RV32-LABEL: extractelt_v8f16:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 8, e16,m1,ta,mu
; RV32-NEXT:    vle16.v v25, (a0)
; RV32-NEXT:    vsetivli a0, 1, e16,m1,ta,mu
; RV32-NEXT:    vslidedown.vi v25, v25, 7
; RV32-NEXT:    vfmv.f.s fa0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v8f16:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 8, e16,m1,ta,mu
; RV64-NEXT:    vle16.v v25, (a0)
; RV64-NEXT:    vsetivli a0, 1, e16,m1,ta,mu
; RV64-NEXT:    vslidedown.vi v25, v25, 7
; RV64-NEXT:    vfmv.f.s fa0, v25
; RV64-NEXT:    ret
  %a = load <8 x half>, <8 x half>* %x
  %b = extractelement <8 x half> %a, i32 7
  ret half %b
}

define float @extractelt_v4f32(<4 x float>* %x) nounwind {
; RV32-LABEL: extractelt_v4f32:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 4, e32,m1,ta,mu
; RV32-NEXT:    vle32.v v25, (a0)
; RV32-NEXT:    vsetivli a0, 1, e32,m1,ta,mu
; RV32-NEXT:    vslidedown.vi v25, v25, 2
; RV32-NEXT:    vfmv.f.s fa0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v4f32:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 4, e32,m1,ta,mu
; RV64-NEXT:    vle32.v v25, (a0)
; RV64-NEXT:    vsetivli a0, 1, e32,m1,ta,mu
; RV64-NEXT:    vslidedown.vi v25, v25, 2
; RV64-NEXT:    vfmv.f.s fa0, v25
; RV64-NEXT:    ret
  %a = load <4 x float>, <4 x float>* %x
  %b = extractelement <4 x float> %a, i32 2
  ret float %b
}

define double @extractelt_v2f64(<2 x double>* %x) nounwind {
; RV32-LABEL: extractelt_v2f64:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 2, e64,m1,ta,mu
; RV32-NEXT:    vle64.v v25, (a0)
; RV32-NEXT:    vfmv.f.s fa0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v2f64:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 2, e64,m1,ta,mu
; RV64-NEXT:    vle64.v v25, (a0)
; RV64-NEXT:    vfmv.f.s fa0, v25
; RV64-NEXT:    ret
  %a = load <2 x double>, <2 x double>* %x
  %b = extractelement <2 x double> %a, i32 0
  ret double %b
}

define i8 @extractelt_v32i8(<32 x i8>* %x) nounwind {
; RV32-LABEL: extractelt_v32i8:
; RV32:       # %bb.0:
; RV32-NEXT:    addi a1, zero, 32
; RV32-NEXT:    vsetvli a1, a1, e8,m2,ta,mu
; RV32-NEXT:    vle8.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e8,m2,ta,mu
; RV32-NEXT:    vslidedown.vi v26, v26, 7
; RV32-NEXT:    vmv.x.s a0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v32i8:
; RV64:       # %bb.0:
; RV64-NEXT:    addi a1, zero, 32
; RV64-NEXT:    vsetvli a1, a1, e8,m2,ta,mu
; RV64-NEXT:    vle8.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e8,m2,ta,mu
; RV64-NEXT:    vslidedown.vi v26, v26, 7
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <32 x i8>, <32 x i8>* %x
  %b = extractelement <32 x i8> %a, i32 7
  ret i8 %b
}

define i16 @extractelt_v16i16(<16 x i16>* %x) nounwind {
; RV32-LABEL: extractelt_v16i16:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 16, e16,m2,ta,mu
; RV32-NEXT:    vle16.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e16,m2,ta,mu
; RV32-NEXT:    vslidedown.vi v26, v26, 7
; RV32-NEXT:    vmv.x.s a0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v16i16:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 16, e16,m2,ta,mu
; RV64-NEXT:    vle16.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e16,m2,ta,mu
; RV64-NEXT:    vslidedown.vi v26, v26, 7
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <16 x i16>, <16 x i16>* %x
  %b = extractelement <16 x i16> %a, i32 7
  ret i16 %b
}

define i32 @extractelt_v8i32(<8 x i32>* %x) nounwind {
; RV32-LABEL: extractelt_v8i32:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 8, e32,m2,ta,mu
; RV32-NEXT:    vle32.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV32-NEXT:    vslidedown.vi v26, v26, 6
; RV32-NEXT:    vmv.x.s a0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v8i32:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 8, e32,m2,ta,mu
; RV64-NEXT:    vle32.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV64-NEXT:    vslidedown.vi v26, v26, 6
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <8 x i32>, <8 x i32>* %x
  %b = extractelement <8 x i32> %a, i32 6
  ret i32 %b
}

define i64 @extractelt_v4i64(<4 x i64>* %x) nounwind {
; RV32-LABEL: extractelt_v4i64:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 4, e64,m2,ta,mu
; RV32-NEXT:    vle64.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e64,m2,ta,mu
; RV32-NEXT:    vslidedown.vi v26, v26, 3
; RV32-NEXT:    vmv.x.s a0, v26
; RV32-NEXT:    addi a1, zero, 32
; RV32-NEXT:    vsrl.vx v26, v26, a1
; RV32-NEXT:    vmv.x.s a1, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v4i64:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 4, e64,m2,ta,mu
; RV64-NEXT:    vle64.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e64,m2,ta,mu
; RV64-NEXT:    vslidedown.vi v26, v26, 3
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <4 x i64>, <4 x i64>* %x
  %b = extractelement <4 x i64> %a, i32 3
  ret i64 %b
}

define half @extractelt_v16f16(<16 x half>* %x) nounwind {
; RV32-LABEL: extractelt_v16f16:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 16, e16,m2,ta,mu
; RV32-NEXT:    vle16.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e16,m2,ta,mu
; RV32-NEXT:    vslidedown.vi v26, v26, 7
; RV32-NEXT:    vfmv.f.s fa0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v16f16:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 16, e16,m2,ta,mu
; RV64-NEXT:    vle16.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e16,m2,ta,mu
; RV64-NEXT:    vslidedown.vi v26, v26, 7
; RV64-NEXT:    vfmv.f.s fa0, v26
; RV64-NEXT:    ret
  %a = load <16 x half>, <16 x half>* %x
  %b = extractelement <16 x half> %a, i32 7
  ret half %b
}

define float @extractelt_v8f32(<8 x float>* %x) nounwind {
; RV32-LABEL: extractelt_v8f32:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 8, e32,m2,ta,mu
; RV32-NEXT:    vle32.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV32-NEXT:    vslidedown.vi v26, v26, 2
; RV32-NEXT:    vfmv.f.s fa0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v8f32:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 8, e32,m2,ta,mu
; RV64-NEXT:    vle32.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV64-NEXT:    vslidedown.vi v26, v26, 2
; RV64-NEXT:    vfmv.f.s fa0, v26
; RV64-NEXT:    ret
  %a = load <8 x float>, <8 x float>* %x
  %b = extractelement <8 x float> %a, i32 2
  ret float %b
}

define double @extractelt_v4f64(<4 x double>* %x) nounwind {
; RV32-LABEL: extractelt_v4f64:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 4, e64,m2,ta,mu
; RV32-NEXT:    vle64.v v26, (a0)
; RV32-NEXT:    vfmv.f.s fa0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v4f64:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 4, e64,m2,ta,mu
; RV64-NEXT:    vle64.v v26, (a0)
; RV64-NEXT:    vfmv.f.s fa0, v26
; RV64-NEXT:    ret
  %a = load <4 x double>, <4 x double>* %x
  %b = extractelement <4 x double> %a, i32 0
  ret double %b
}

; This uses a non-power of 2 type so that it isn't an MVT to catch an
; incorrect use of getSimpleValueType().
; NOTE: Type legalization is bitcasting to vXi32 and doing 2 independent
; slidedowns and extracts.
define i64 @extractelt_v3i64(<3 x i64>* %x) nounwind {
; RV32-LABEL: extractelt_v3i64:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a1, 8, e32,m2,ta,mu
; RV32-NEXT:    vle32.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV32-NEXT:    vslidedown.vi v28, v26, 4
; RV32-NEXT:    vmv.x.s a0, v28
; RV32-NEXT:    vslidedown.vi v26, v26, 5
; RV32-NEXT:    vmv.x.s a1, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v3i64:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a1, 4, e64,m2,ta,mu
; RV64-NEXT:    vle64.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e64,m2,ta,mu
; RV64-NEXT:    vslidedown.vi v26, v26, 2
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <3 x i64>, <3 x i64>* %x
  %b = extractelement <3 x i64> %a, i32 2
  ret i64 %b
}

define i8 @extractelt_v16i8_idx(<16 x i8>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v16i8_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 16, e8,m1,ta,mu
; RV32-NEXT:    vle8.v v25, (a0)
; RV32-NEXT:    vsetivli a0, 1, e8,m1,ta,mu
; RV32-NEXT:    vslidedown.vx v25, v25, a1
; RV32-NEXT:    vmv.x.s a0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v16i8_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 16, e8,m1,ta,mu
; RV64-NEXT:    vle8.v v25, (a0)
; RV64-NEXT:    vsetivli a0, 1, e8,m1,ta,mu
; RV64-NEXT:    vslidedown.vx v25, v25, a1
; RV64-NEXT:    vmv.x.s a0, v25
; RV64-NEXT:    ret
  %a = load <16 x i8>, <16 x i8>* %x
  %b = extractelement <16 x i8> %a, i32 %idx
  ret i8 %b
}

define i16 @extractelt_v8i16_idx(<8 x i16>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v8i16_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 8, e16,m1,ta,mu
; RV32-NEXT:    vle16.v v25, (a0)
; RV32-NEXT:    vsetivli a0, 1, e16,m1,ta,mu
; RV32-NEXT:    vslidedown.vx v25, v25, a1
; RV32-NEXT:    vmv.x.s a0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v8i16_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 8, e16,m1,ta,mu
; RV64-NEXT:    vle16.v v25, (a0)
; RV64-NEXT:    vsetivli a0, 1, e16,m1,ta,mu
; RV64-NEXT:    vslidedown.vx v25, v25, a1
; RV64-NEXT:    vmv.x.s a0, v25
; RV64-NEXT:    ret
  %a = load <8 x i16>, <8 x i16>* %x
  %b = extractelement <8 x i16> %a, i32 %idx
  ret i16 %b
}

define i32 @extractelt_v4i32_idx(<4 x i32>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v4i32_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 4, e32,m1,ta,mu
; RV32-NEXT:    vle32.v v25, (a0)
; RV32-NEXT:    vadd.vv v25, v25, v25
; RV32-NEXT:    vsetivli a0, 1, e32,m1,ta,mu
; RV32-NEXT:    vslidedown.vx v25, v25, a1
; RV32-NEXT:    vmv.x.s a0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v4i32_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 4, e32,m1,ta,mu
; RV64-NEXT:    vle32.v v25, (a0)
; RV64-NEXT:    vadd.vv v25, v25, v25
; RV64-NEXT:    vsetivli a0, 1, e32,m1,ta,mu
; RV64-NEXT:    vslidedown.vx v25, v25, a1
; RV64-NEXT:    vmv.x.s a0, v25
; RV64-NEXT:    ret
  %a = load <4 x i32>, <4 x i32>* %x
  %b = add <4 x i32> %a, %a
  %c = extractelement <4 x i32> %b, i32 %idx
  ret i32 %c
}

define i64 @extractelt_v2i64_idx(<2 x i64>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v2i64_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 2, e64,m1,ta,mu
; RV32-NEXT:    vle64.v v25, (a0)
; RV32-NEXT:    vadd.vv v25, v25, v25
; RV32-NEXT:    vsetivli a0, 1, e64,m1,ta,mu
; RV32-NEXT:    vslidedown.vx v25, v25, a1
; RV32-NEXT:    vmv.x.s a0, v25
; RV32-NEXT:    addi a1, zero, 32
; RV32-NEXT:    vsrl.vx v25, v25, a1
; RV32-NEXT:    vmv.x.s a1, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v2i64_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 2, e64,m1,ta,mu
; RV64-NEXT:    vle64.v v25, (a0)
; RV64-NEXT:    vadd.vv v25, v25, v25
; RV64-NEXT:    vsetivli a0, 1, e64,m1,ta,mu
; RV64-NEXT:    vslidedown.vx v25, v25, a1
; RV64-NEXT:    vmv.x.s a0, v25
; RV64-NEXT:    ret
  %a = load <2 x i64>, <2 x i64>* %x
  %b = add <2 x i64> %a, %a
  %c = extractelement <2 x i64> %b, i32 %idx
  ret i64 %c
}

define half @extractelt_v8f16_idx(<8 x half>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v8f16_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 8, e16,m1,ta,mu
; RV32-NEXT:    vle16.v v25, (a0)
; RV32-NEXT:    vfadd.vv v25, v25, v25
; RV32-NEXT:    vsetivli a0, 1, e16,m1,ta,mu
; RV32-NEXT:    vslidedown.vx v25, v25, a1
; RV32-NEXT:    vfmv.f.s fa0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v8f16_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 8, e16,m1,ta,mu
; RV64-NEXT:    vle16.v v25, (a0)
; RV64-NEXT:    vfadd.vv v25, v25, v25
; RV64-NEXT:    vsetivli a0, 1, e16,m1,ta,mu
; RV64-NEXT:    vslidedown.vx v25, v25, a1
; RV64-NEXT:    vfmv.f.s fa0, v25
; RV64-NEXT:    ret
  %a = load <8 x half>, <8 x half>* %x
  %b = fadd <8 x half> %a, %a
  %c = extractelement <8 x half> %b, i32 %idx
  ret half %c
}

define float @extractelt_v4f32_idx(<4 x float>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v4f32_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 4, e32,m1,ta,mu
; RV32-NEXT:    vle32.v v25, (a0)
; RV32-NEXT:    vfadd.vv v25, v25, v25
; RV32-NEXT:    vsetivli a0, 1, e32,m1,ta,mu
; RV32-NEXT:    vslidedown.vx v25, v25, a1
; RV32-NEXT:    vfmv.f.s fa0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v4f32_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 4, e32,m1,ta,mu
; RV64-NEXT:    vle32.v v25, (a0)
; RV64-NEXT:    vfadd.vv v25, v25, v25
; RV64-NEXT:    vsetivli a0, 1, e32,m1,ta,mu
; RV64-NEXT:    vslidedown.vx v25, v25, a1
; RV64-NEXT:    vfmv.f.s fa0, v25
; RV64-NEXT:    ret
  %a = load <4 x float>, <4 x float>* %x
  %b = fadd <4 x float> %a, %a
  %c = extractelement <4 x float> %b, i32 %idx
  ret float %c
}

define double @extractelt_v2f64_idx(<2 x double>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v2f64_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 2, e64,m1,ta,mu
; RV32-NEXT:    vle64.v v25, (a0)
; RV32-NEXT:    vfadd.vv v25, v25, v25
; RV32-NEXT:    vsetivli a0, 1, e64,m1,ta,mu
; RV32-NEXT:    vslidedown.vx v25, v25, a1
; RV32-NEXT:    vfmv.f.s fa0, v25
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v2f64_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 2, e64,m1,ta,mu
; RV64-NEXT:    vle64.v v25, (a0)
; RV64-NEXT:    vfadd.vv v25, v25, v25
; RV64-NEXT:    vsetivli a0, 1, e64,m1,ta,mu
; RV64-NEXT:    vslidedown.vx v25, v25, a1
; RV64-NEXT:    vfmv.f.s fa0, v25
; RV64-NEXT:    ret
  %a = load <2 x double>, <2 x double>* %x
  %b = fadd <2 x double> %a, %a
  %c = extractelement <2 x double> %b, i32 %idx
  ret double %c
}

define i8 @extractelt_v32i8_idx(<32 x i8>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v32i8_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    addi a2, zero, 32
; RV32-NEXT:    vsetvli a2, a2, e8,m2,ta,mu
; RV32-NEXT:    vle8.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e8,m2,ta,mu
; RV32-NEXT:    vslidedown.vx v26, v26, a1
; RV32-NEXT:    vmv.x.s a0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v32i8_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    addi a2, zero, 32
; RV64-NEXT:    vsetvli a2, a2, e8,m2,ta,mu
; RV64-NEXT:    vle8.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e8,m2,ta,mu
; RV64-NEXT:    vslidedown.vx v26, v26, a1
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <32 x i8>, <32 x i8>* %x
  %b = extractelement <32 x i8> %a, i32 %idx
  ret i8 %b
}

define i16 @extractelt_v16i16_idx(<16 x i16>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v16i16_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 16, e16,m2,ta,mu
; RV32-NEXT:    vle16.v v26, (a0)
; RV32-NEXT:    vsetivli a0, 1, e16,m2,ta,mu
; RV32-NEXT:    vslidedown.vx v26, v26, a1
; RV32-NEXT:    vmv.x.s a0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v16i16_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 16, e16,m2,ta,mu
; RV64-NEXT:    vle16.v v26, (a0)
; RV64-NEXT:    vsetivli a0, 1, e16,m2,ta,mu
; RV64-NEXT:    vslidedown.vx v26, v26, a1
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <16 x i16>, <16 x i16>* %x
  %b = extractelement <16 x i16> %a, i32 %idx
  ret i16 %b
}

define i32 @extractelt_v8i32_idx(<8 x i32>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v8i32_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 8, e32,m2,ta,mu
; RV32-NEXT:    vle32.v v26, (a0)
; RV32-NEXT:    vadd.vv v26, v26, v26
; RV32-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV32-NEXT:    vslidedown.vx v26, v26, a1
; RV32-NEXT:    vmv.x.s a0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v8i32_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 8, e32,m2,ta,mu
; RV64-NEXT:    vle32.v v26, (a0)
; RV64-NEXT:    vadd.vv v26, v26, v26
; RV64-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV64-NEXT:    vslidedown.vx v26, v26, a1
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <8 x i32>, <8 x i32>* %x
  %b = add <8 x i32> %a, %a
  %c = extractelement <8 x i32> %b, i32 %idx
  ret i32 %c
}

define i64 @extractelt_v4i64_idx(<4 x i64>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v4i64_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 4, e64,m2,ta,mu
; RV32-NEXT:    vle64.v v26, (a0)
; RV32-NEXT:    vadd.vv v26, v26, v26
; RV32-NEXT:    vsetivli a0, 1, e64,m2,ta,mu
; RV32-NEXT:    vslidedown.vx v26, v26, a1
; RV32-NEXT:    vmv.x.s a0, v26
; RV32-NEXT:    addi a1, zero, 32
; RV32-NEXT:    vsrl.vx v26, v26, a1
; RV32-NEXT:    vmv.x.s a1, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v4i64_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 4, e64,m2,ta,mu
; RV64-NEXT:    vle64.v v26, (a0)
; RV64-NEXT:    vadd.vv v26, v26, v26
; RV64-NEXT:    vsetivli a0, 1, e64,m2,ta,mu
; RV64-NEXT:    vslidedown.vx v26, v26, a1
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <4 x i64>, <4 x i64>* %x
  %b = add <4 x i64> %a, %a
  %c = extractelement <4 x i64> %b, i32 %idx
  ret i64 %c
}

define half @extractelt_v16f16_idx(<16 x half>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v16f16_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 16, e16,m2,ta,mu
; RV32-NEXT:    vle16.v v26, (a0)
; RV32-NEXT:    vfadd.vv v26, v26, v26
; RV32-NEXT:    vsetivli a0, 1, e16,m2,ta,mu
; RV32-NEXT:    vslidedown.vx v26, v26, a1
; RV32-NEXT:    vfmv.f.s fa0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v16f16_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 16, e16,m2,ta,mu
; RV64-NEXT:    vle16.v v26, (a0)
; RV64-NEXT:    vfadd.vv v26, v26, v26
; RV64-NEXT:    vsetivli a0, 1, e16,m2,ta,mu
; RV64-NEXT:    vslidedown.vx v26, v26, a1
; RV64-NEXT:    vfmv.f.s fa0, v26
; RV64-NEXT:    ret
  %a = load <16 x half>, <16 x half>* %x
  %b = fadd <16 x half> %a, %a
  %c = extractelement <16 x half> %b, i32 %idx
  ret half %c
}

define float @extractelt_v8f32_idx(<8 x float>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v8f32_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 8, e32,m2,ta,mu
; RV32-NEXT:    vle32.v v26, (a0)
; RV32-NEXT:    vfadd.vv v26, v26, v26
; RV32-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV32-NEXT:    vslidedown.vx v26, v26, a1
; RV32-NEXT:    vfmv.f.s fa0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v8f32_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 8, e32,m2,ta,mu
; RV64-NEXT:    vle32.v v26, (a0)
; RV64-NEXT:    vfadd.vv v26, v26, v26
; RV64-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV64-NEXT:    vslidedown.vx v26, v26, a1
; RV64-NEXT:    vfmv.f.s fa0, v26
; RV64-NEXT:    ret
  %a = load <8 x float>, <8 x float>* %x
  %b = fadd <8 x float> %a, %a
  %c = extractelement <8 x float> %b, i32 %idx
  ret float %c
}

define double @extractelt_v4f64_idx(<4 x double>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v4f64_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 4, e64,m2,ta,mu
; RV32-NEXT:    vle64.v v26, (a0)
; RV32-NEXT:    vfadd.vv v26, v26, v26
; RV32-NEXT:    vsetivli a0, 1, e64,m2,ta,mu
; RV32-NEXT:    vslidedown.vx v26, v26, a1
; RV32-NEXT:    vfmv.f.s fa0, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v4f64_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 4, e64,m2,ta,mu
; RV64-NEXT:    vle64.v v26, (a0)
; RV64-NEXT:    vfadd.vv v26, v26, v26
; RV64-NEXT:    vsetivli a0, 1, e64,m2,ta,mu
; RV64-NEXT:    vslidedown.vx v26, v26, a1
; RV64-NEXT:    vfmv.f.s fa0, v26
; RV64-NEXT:    ret
  %a = load <4 x double>, <4 x double>* %x
  %b = fadd <4 x double> %a, %a
  %c = extractelement <4 x double> %b, i32 %idx
  ret double %c
}

; This uses a non-power of 2 type so that it isn't an MVT to catch an
; incorrect use of getSimpleValueType_idx(, i32 signext %idx).
; NOTE: Type legalization is bitcasting to vXi32 and doing 2 independent
; slidedowns and extracts.
define i64 @extractelt_v3i64_idx(<3 x i64>* %x, i32 signext %idx) nounwind {
; RV32-LABEL: extractelt_v3i64_idx:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli a2, 4, e64,m2,ta,mu
; RV32-NEXT:    vle64.v v26, (a0)
; RV32-NEXT:    vadd.vv v26, v26, v26
; RV32-NEXT:    add a1, a1, a1
; RV32-NEXT:    vsetivli a0, 1, e32,m2,ta,mu
; RV32-NEXT:    vslidedown.vx v28, v26, a1
; RV32-NEXT:    vmv.x.s a0, v28
; RV32-NEXT:    addi a1, a1, 1
; RV32-NEXT:    vslidedown.vx v26, v26, a1
; RV32-NEXT:    vmv.x.s a1, v26
; RV32-NEXT:    ret
;
; RV64-LABEL: extractelt_v3i64_idx:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli a2, 4, e64,m2,ta,mu
; RV64-NEXT:    vle64.v v26, (a0)
; RV64-NEXT:    vadd.vv v26, v26, v26
; RV64-NEXT:    vsetivli a0, 1, e64,m2,ta,mu
; RV64-NEXT:    vslidedown.vx v26, v26, a1
; RV64-NEXT:    vmv.x.s a0, v26
; RV64-NEXT:    ret
  %a = load <3 x i64>, <3 x i64>* %x
  %b = add <3 x i64> %a, %a
  %c = extractelement <3 x i64> %b, i32 %idx
  ret i64 %c
}
