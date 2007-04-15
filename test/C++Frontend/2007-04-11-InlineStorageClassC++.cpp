// RUN: %llvmgxx %s -S -emit-llvm -O0 -o - | grep define | \
// RUN:   grep xglobWeak | grep linkonce | wc -l | grep 1
// RUN: %llvmgxx %s -S -emit-llvm -O0 -o - | grep define | \
// RUN:   grep xextWeak | grep linkonce | wc -l | grep 1
// RUN: %llvmgxx %s -S -emit-llvm -O0 -o - | grep define | \
// RUN:   grep xWeaknoinline | grep weak | wc -l | grep 1
// RUN: %llvmgxx %s -S -emit-llvm -O0 -o - | grep define | \
// RUN:   grep xWeakextnoinline | grep weak | wc -l | grep 1
// RUN: %llvmgxx %s -S -emit-llvm -O0 -o - | grep declare | \
// RUN:   grep xglobnoWeak | grep linkonce | wc -l | grep 1
// RUN: %llvmgxx %s -S -emit-llvm -O0 -o - | grep define | \
// RUN:   grep xstatnoWeak | grep internal | wc -l | grep 1
// RUN: %llvmgxx %s -S -emit-llvm -O0 -o - | grep define | \
// RUN:   grep xextnoWeak | grep linkonce | wc -l | grep 1
// XFAIL: *
inline int xglobWeak(int) __attribute__((weak));
inline int xglobWeak (int i) {
  return i*2;
}
inline int xextWeak(int) __attribute__((weak));
extern  inline int xextWeak (int i) {
  return i*4;
}
int xWeaknoinline(int) __attribute__((weak));
int xWeaknoinline(int i) {
  return i*8;
}
int xWeakextnoinline(int) __attribute__((weak));
extern int xWeakextnoinline(int i) {
  return i*16;
}
inline int xglobnoWeak (int i) {
  return i*32;
}
static inline int xstatnoWeak (int i) {
  return i*64;
}
extern  inline int xextnoWeak (int i) {
  return i*128;
}
int j(int y) {
  return xglobnoWeak(y)+xstatnoWeak(y)+xextnoWeak(y)+
        xglobWeak(y)+xextWeak(y)+
        xWeakextnoinline(y)+xWeaknoinline(y);
}
