//===- SIMemoryLegalizer.cpp ----------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
/// \file
/// Memory legalizer - implements memory model. More information can be
/// found here:
///   http://llvm.org/docs/AMDGPUUsage.html#memory-model
//
//===----------------------------------------------------------------------===//

#include "AMDGPU.h"
#include "AMDGPUMachineModuleInfo.h"
#include "AMDGPUSubtarget.h"
#include "SIDefines.h"
#include "SIInstrInfo.h"
#include "MCTargetDesc/AMDGPUMCTargetDesc.h"
#include "Utils/AMDGPUBaseInfo.h"
#include "llvm/ADT/BitmaskEnum.h"
#include "llvm/ADT/None.h"
#include "llvm/ADT/Optional.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineMemOperand.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/IR/DebugLoc.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/MC/MCInstrDesc.h"
#include "llvm/Pass.h"
#include "llvm/Support/AtomicOrdering.h"
#include "llvm/Support/MathExtras.h"
#include <cassert>
#include <list>

using namespace llvm;
using namespace llvm::AMDGPU;

#define DEBUG_TYPE "si-memory-legalizer"
#define PASS_NAME "SI Memory Legalizer"

static cl::opt<bool> AmdgcnSkipCacheInvalidations(
    "amdgcn-skip-cache-invalidations", cl::init(false), cl::Hidden,
    cl::desc("Use this to skip inserting cache invalidating instructions."));

namespace {

LLVM_ENABLE_BITMASK_ENUMS_IN_NAMESPACE();

/// Memory operation flags. Can be ORed together.
enum class SIMemOp {
  NONE = 0u,
  LOAD = 1u << 0,
  STORE = 1u << 1,
  LLVM_MARK_AS_BITMASK_ENUM(/* LargestFlag = */ STORE)
};

/// Position to insert a new instruction relative to an existing
/// instruction.
enum class Position {
  BEFORE,
  AFTER
};

/// The atomic synchronization scopes supported by the AMDGPU target.
enum class SIAtomicScope {
  NONE,
  SINGLETHREAD,
  WAVEFRONT,
  WORKGROUP,
  AGENT,
  SYSTEM
};

/// The distinct address spaces supported by the AMDGPU target for
/// atomic memory operation. Can be ORed toether.
enum class SIAtomicAddrSpace {
  NONE = 0u,
  GLOBAL = 1u << 0,
  LDS = 1u << 1,
  SCRATCH = 1u << 2,
  GDS = 1u << 3,
  OTHER = 1u << 4,

  /// The address spaces that can be accessed by a FLAT instruction.
  FLAT = GLOBAL | LDS | SCRATCH,

  /// The address spaces that support atomic instructions.
  ATOMIC = GLOBAL | LDS | SCRATCH | GDS,

  /// All address spaces.
  ALL = GLOBAL | LDS | SCRATCH | GDS | OTHER,

  LLVM_MARK_AS_BITMASK_ENUM(/* LargestFlag = */ ALL)
};

/// Sets named bit \p BitName to "true" if present in instruction \p MI.
/// \returns Returns true if \p MI is modified, false otherwise.
template <uint16_t BitName>
bool enableNamedBit(const MachineBasicBlock::iterator &MI) {
  int BitIdx = AMDGPU::getNamedOperandIdx(MI->getOpcode(), BitName);
  if (BitIdx == -1)
    return false;

  MachineOperand &Bit = MI->getOperand(BitIdx);
  if (Bit.getImm() != 0)
    return false;

  Bit.setImm(1);
  return true;
}

class SIMemOpInfo final {
private:

  friend class SIMemOpAccess;

  AtomicOrdering Ordering = AtomicOrdering::NotAtomic;
  AtomicOrdering FailureOrdering = AtomicOrdering::NotAtomic;
  SIAtomicScope Scope = SIAtomicScope::SYSTEM;
  SIAtomicAddrSpace OrderingAddrSpace = SIAtomicAddrSpace::NONE;
  SIAtomicAddrSpace InstrAddrSpace = SIAtomicAddrSpace::NONE;
  bool IsCrossAddressSpaceOrdering = false;
  bool IsNonTemporal = false;

  SIMemOpInfo(AtomicOrdering Ordering = AtomicOrdering::SequentiallyConsistent,
              SIAtomicScope Scope = SIAtomicScope::SYSTEM,
              SIAtomicAddrSpace OrderingAddrSpace = SIAtomicAddrSpace::ATOMIC,
              SIAtomicAddrSpace InstrAddrSpace = SIAtomicAddrSpace::ALL,
              bool IsCrossAddressSpaceOrdering = true,
              AtomicOrdering FailureOrdering =
                AtomicOrdering::SequentiallyConsistent,
              bool IsNonTemporal = false)
    : Ordering(Ordering), FailureOrdering(FailureOrdering),
      Scope(Scope), OrderingAddrSpace(OrderingAddrSpace),
      InstrAddrSpace(InstrAddrSpace),
      IsCrossAddressSpaceOrdering(IsCrossAddressSpaceOrdering),
      IsNonTemporal(IsNonTemporal) {
    // There is also no cross address space ordering if the ordering
    // address space is the same as the instruction address space and
    // only contains a single address space.
    if ((OrderingAddrSpace == InstrAddrSpace) &&
        isPowerOf2_32(uint32_t(InstrAddrSpace)))
      this->IsCrossAddressSpaceOrdering = false;
  }

public:
  /// \returns Atomic synchronization scope of the machine instruction used to
  /// create this SIMemOpInfo.
  SIAtomicScope getScope() const {
    return Scope;
  }

  /// \returns Ordering constraint of the machine instruction used to
  /// create this SIMemOpInfo.
  AtomicOrdering getOrdering() const {
    return Ordering;
  }

  /// \returns Failure ordering constraint of the machine instruction used to
  /// create this SIMemOpInfo.
  AtomicOrdering getFailureOrdering() const {
    return FailureOrdering;
  }

  /// \returns The address spaces be accessed by the machine
  /// instruction used to create this SiMemOpInfo.
  SIAtomicAddrSpace getInstrAddrSpace() const {
    return InstrAddrSpace;
  }

  /// \returns The address spaces that must be ordered by the machine
  /// instruction used to create this SiMemOpInfo.
  SIAtomicAddrSpace getOrderingAddrSpace() const {
    return OrderingAddrSpace;
  }

  /// \returns Return true iff memory ordering of operations on
  /// different address spaces is required.
  bool getIsCrossAddressSpaceOrdering() const {
    return IsCrossAddressSpaceOrdering;
  }

  /// \returns True if memory access of the machine instruction used to
  /// create this SIMemOpInfo is non-temporal, false otherwise.
  bool isNonTemporal() const {
    return IsNonTemporal;
  }

  /// \returns True if ordering constraint of the machine instruction used to
  /// create this SIMemOpInfo is unordered or higher, false otherwise.
  bool isAtomic() const {
    return Ordering != AtomicOrdering::NotAtomic;
  }

};

class SIMemOpAccess final {
private:
  AMDGPUMachineModuleInfo *MMI = nullptr;

  /// Reports unsupported message \p Msg for \p MI to LLVM context.
  void reportUnsupported(const MachineBasicBlock::iterator &MI,
                         const char *Msg) const;

  /// Inspects the target synchonization scope \p SSID and determines
  /// the SI atomic scope it corresponds to, the address spaces it
  /// covers, and whether the memory ordering applies between address
  /// spaces.
  Optional<std::tuple<SIAtomicScope, SIAtomicAddrSpace, bool>>
  toSIAtomicScope(SyncScope::ID SSID, SIAtomicAddrSpace InstrScope) const;

  /// \return Return a bit set of the address spaces accessed by \p AS.
  SIAtomicAddrSpace toSIAtomicAddrSpace(unsigned AS) const;

  /// \returns Info constructed from \p MI, which has at least machine memory
  /// operand.
  Optional<SIMemOpInfo> constructFromMIWithMMO(
      const MachineBasicBlock::iterator &MI) const;

public:
  /// Construct class to support accessing the machine memory operands
  /// of instructions in the machine function \p MF.
  SIMemOpAccess(MachineFunction &MF);

  /// \returns Load info if \p MI is a load operation, "None" otherwise.
  Optional<SIMemOpInfo> getLoadInfo(
      const MachineBasicBlock::iterator &MI) const;

  /// \returns Store info if \p MI is a store operation, "None" otherwise.
  Optional<SIMemOpInfo> getStoreInfo(
      const MachineBasicBlock::iterator &MI) const;

  /// \returns Atomic fence info if \p MI is an atomic fence operation,
  /// "None" otherwise.
  Optional<SIMemOpInfo> getAtomicFenceInfo(
      const MachineBasicBlock::iterator &MI) const;

  /// \returns Atomic cmpxchg/rmw info if \p MI is an atomic cmpxchg or
  /// rmw operation, "None" otherwise.
  Optional<SIMemOpInfo> getAtomicCmpxchgOrRmwInfo(
      const MachineBasicBlock::iterator &MI) const;
};

class SICacheControl {
protected:

  //// AMDGPU subtarget info.
  const GCNSubtarget &ST;

  /// Instruction info.
  const SIInstrInfo *TII = nullptr;

  IsaVersion IV;

  /// Whether to insert cache invalidating instructions.
  bool InsertCacheInv;

  SICacheControl(const GCNSubtarget &ST);

public:

  /// Create a cache control for the subtarget \p ST.
  static std::unique_ptr<SICacheControl> create(const GCNSubtarget &ST);

  /// Update \p MI memory load instruction to bypass any caches up to
  /// the \p Scope memory scope for address spaces \p
  /// AddrSpace. Return true iff the instruction was modified.
  virtual bool enableLoadCacheBypass(const MachineBasicBlock::iterator &MI,
                                     SIAtomicScope Scope,
                                     SIAtomicAddrSpace AddrSpace) const = 0;

  /// Update \p MI memory instruction to indicate it is
  /// nontemporal. Return true iff the instruction was modified.
  virtual bool enableNonTemporal(const MachineBasicBlock::iterator &MI)
    const = 0;

  /// Inserts any necessary instructions at position \p Pos relative to
  /// instruction \p MI to ensure any subsequent memory instructions of this
  /// thread with address spaces \p AddrSpace will observe the previous memory
  /// operations by any thread for memory scopes up to memory scope \p Scope .
  /// Returns true iff any instructions inserted.
  virtual bool insertAcquire(MachineBasicBlock::iterator &MI,
                             SIAtomicScope Scope,
                             SIAtomicAddrSpace AddrSpace,
                             Position Pos) const = 0;

  /// Inserts any necessary instructions at position \p Pos relative
  /// to instruction \p MI to ensure memory instructions before \p Pos of kind
  /// \p Op associated with address spaces \p AddrSpace have completed. Used
  /// between memory instructions to enforce the order they become visible as
  /// observed by other memory instructions executing in memory scope \p Scope.
  /// \p IsCrossAddrSpaceOrdering indicates if the memory ordering is between
  /// address spaces. Returns true iff any instructions inserted.
  virtual bool insertWait(MachineBasicBlock::iterator &MI,
                          SIAtomicScope Scope,
                          SIAtomicAddrSpace AddrSpace,
                          SIMemOp Op,
                          bool IsCrossAddrSpaceOrdering,
                          Position Pos) const = 0;

  /// Inserts any necessary instructions at position \p Pos relative to
  /// instruction \p MI to ensure previous memory instructions by this thread
  /// with address spaces \p AddrSpace have completed and can be observed by
  /// subsequent memory instructions by any thread executing in memory scope \p
  /// Scope. \p IsCrossAddrSpaceOrdering indicates if the memory ordering is
  /// between address spaces. Returns true iff any instructions inserted.
  virtual bool insertRelease(MachineBasicBlock::iterator &MI,
                             SIAtomicScope Scope,
                             SIAtomicAddrSpace AddrSpace,
                             bool IsCrossAddrSpaceOrdering,
                             Position Pos) const = 0;

  /// Virtual destructor to allow derivations to be deleted.
  virtual ~SICacheControl() = default;

};

class SIGfx6CacheControl : public SICacheControl {
protected:

  /// Sets GLC bit to "true" if present in \p MI. Returns true if \p MI
  /// is modified, false otherwise.
  bool enableGLCBit(const MachineBasicBlock::iterator &MI) const {
    return enableNamedBit<AMDGPU::OpName::glc>(MI);
  }

  /// Sets SLC bit to "true" if present in \p MI. Returns true if \p MI
  /// is modified, false otherwise.
  bool enableSLCBit(const MachineBasicBlock::iterator &MI) const {
    return enableNamedBit<AMDGPU::OpName::slc>(MI);
  }

public:

  SIGfx6CacheControl(const GCNSubtarget &ST) : SICacheControl(ST) {};

  bool enableLoadCacheBypass(const MachineBasicBlock::iterator &MI,
                             SIAtomicScope Scope,
                             SIAtomicAddrSpace AddrSpace) const override;

  bool enableNonTemporal(const MachineBasicBlock::iterator &MI) const override;

  bool insertAcquire(MachineBasicBlock::iterator &MI,
                     SIAtomicScope Scope,
                     SIAtomicAddrSpace AddrSpace,
                     Position Pos) const override;

  bool insertRelease(MachineBasicBlock::iterator &MI,
                     SIAtomicScope Scope,
                     SIAtomicAddrSpace AddrSpace,
                     bool IsCrossAddrSpaceOrdering,
                     Position Pos) const override;

  bool insertWait(MachineBasicBlock::iterator &MI,
                  SIAtomicScope Scope,
                  SIAtomicAddrSpace AddrSpace,
                  SIMemOp Op,
                  bool IsCrossAddrSpaceOrdering,
                  Position Pos) const override;
};

class SIGfx7CacheControl : public SIGfx6CacheControl {
public:

  SIGfx7CacheControl(const GCNSubtarget &ST) : SIGfx6CacheControl(ST) {};

  bool insertAcquire(MachineBasicBlock::iterator &MI,
                     SIAtomicScope Scope,
                     SIAtomicAddrSpace AddrSpace,
                     Position Pos) const override;

};

class SIGfx10CacheControl : public SIGfx7CacheControl {
protected:

  /// Sets DLC bit to "true" if present in \p MI. Returns true if \p MI
  /// is modified, false otherwise.
  bool enableDLCBit(const MachineBasicBlock::iterator &MI) const {
    return enableNamedBit<AMDGPU::OpName::dlc>(MI);
  }

public:

  SIGfx10CacheControl(const GCNSubtarget &ST) : SIGfx7CacheControl(ST) {};

  bool enableLoadCacheBypass(const MachineBasicBlock::iterator &MI,
                             SIAtomicScope Scope,
                             SIAtomicAddrSpace AddrSpace) const override;

  bool enableNonTemporal(const MachineBasicBlock::iterator &MI) const override;

  bool insertAcquire(MachineBasicBlock::iterator &MI,
                     SIAtomicScope Scope,
                     SIAtomicAddrSpace AddrSpace,
                     Position Pos) const override;

  bool insertWait(MachineBasicBlock::iterator &MI,
                  SIAtomicScope Scope,
                  SIAtomicAddrSpace AddrSpace,
                  SIMemOp Op,
                  bool IsCrossAddrSpaceOrdering,
                  Position Pos) const override;
};

class SIMemoryLegalizer final : public MachineFunctionPass {
private:

  /// Cache Control.
  std::unique_ptr<SICacheControl> CC = nullptr;

  /// List of atomic pseudo instructions.
  std::list<MachineBasicBlock::iterator> AtomicPseudoMIs;

  /// Return true iff instruction \p MI is a atomic instruction that
  /// returns a result.
  bool isAtomicRet(const MachineInstr &MI) const {
    return AMDGPU::getAtomicNoRetOp(MI.getOpcode()) != -1;
  }

  /// Removes all processed atomic pseudo instructions from the current
  /// function. Returns true if current function is modified, false otherwise.
  bool removeAtomicPseudoMIs();

  /// Expands load operation \p MI. Returns true if instructions are
  /// added/deleted or \p MI is modified, false otherwise.
  bool expandLoad(const SIMemOpInfo &MOI,
                  MachineBasicBlock::iterator &MI);
  /// Expands store operation \p MI. Returns true if instructions are
  /// added/deleted or \p MI is modified, false otherwise.
  bool expandStore(const SIMemOpInfo &MOI,
                   MachineBasicBlock::iterator &MI);
  /// Expands atomic fence operation \p MI. Returns true if
  /// instructions are added/deleted or \p MI is modified, false otherwise.
  bool expandAtomicFence(const SIMemOpInfo &MOI,
                         MachineBasicBlock::iterator &MI);
  /// Expands atomic cmpxchg or rmw operation \p MI. Returns true if
  /// instructions are added/deleted or \p MI is modified, false otherwise.
  bool expandAtomicCmpxchgOrRmw(const SIMemOpInfo &MOI,
                                MachineBasicBlock::iterator &MI);

public:
  static char ID;

  SIMemoryLegalizer() : MachineFunctionPass(ID) {}

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  StringRef getPassName() const override {
    return PASS_NAME;
  }

  bool runOnMachineFunction(MachineFunction &MF) override;
};

} // end namespace anonymous

void SIMemOpAccess::reportUnsupported(const MachineBasicBlock::iterator &MI,
                                      const char *Msg) const {
  const Function &Func = MI->getParent()->getParent()->getFunction();
  DiagnosticInfoUnsupported Diag(Func, Msg, MI->getDebugLoc());
  Func.getContext().diagnose(Diag);
}

Optional<std::tuple<SIAtomicScope, SIAtomicAddrSpace, bool>>
SIMemOpAccess::toSIAtomicScope(SyncScope::ID SSID,
                               SIAtomicAddrSpace InstrScope) const {
  if (SSID == SyncScope::System)
    return std::make_tuple(SIAtomicScope::SYSTEM,
                           SIAtomicAddrSpace::ATOMIC,
                           true);
  if (SSID == MMI->getAgentSSID())
    return std::make_tuple(SIAtomicScope::AGENT,
                           SIAtomicAddrSpace::ATOMIC,
                           true);
  if (SSID == MMI->getWorkgroupSSID())
    return std::make_tuple(SIAtomicScope::WORKGROUP,
                           SIAtomicAddrSpace::ATOMIC,
                           true);
  if (SSID == MMI->getWavefrontSSID())
    return std::make_tuple(SIAtomicScope::WAVEFRONT,
                           SIAtomicAddrSpace::ATOMIC,
                           true);
  if (SSID == SyncScope::SingleThread)
    return std::make_tuple(SIAtomicScope::SINGLETHREAD,
                           SIAtomicAddrSpace::ATOMIC,
                           true);
  if (SSID == MMI->getSystemOneAddressSpaceSSID())
    return std::make_tuple(SIAtomicScope::SYSTEM,
                           SIAtomicAddrSpace::ATOMIC & InstrScope,
                           false);
  if (SSID == MMI->getAgentOneAddressSpaceSSID())
    return std::make_tuple(SIAtomicScope::AGENT,
                           SIAtomicAddrSpace::ATOMIC & InstrScope,
                           false);
  if (SSID == MMI->getWorkgroupOneAddressSpaceSSID())
    return std::make_tuple(SIAtomicScope::WORKGROUP,
                           SIAtomicAddrSpace::ATOMIC & InstrScope,
                           false);
  if (SSID == MMI->getWavefrontOneAddressSpaceSSID())
    return std::make_tuple(SIAtomicScope::WAVEFRONT,
                           SIAtomicAddrSpace::ATOMIC & InstrScope,
                           false);
  if (SSID == MMI->getSingleThreadOneAddressSpaceSSID())
    return std::make_tuple(SIAtomicScope::SINGLETHREAD,
                           SIAtomicAddrSpace::ATOMIC & InstrScope,
                           false);
  return None;
}

SIAtomicAddrSpace SIMemOpAccess::toSIAtomicAddrSpace(unsigned AS) const {
  if (AS == AMDGPUAS::FLAT_ADDRESS)
    return SIAtomicAddrSpace::FLAT;
  if (AS == AMDGPUAS::GLOBAL_ADDRESS)
    return SIAtomicAddrSpace::GLOBAL;
  if (AS == AMDGPUAS::LOCAL_ADDRESS)
    return SIAtomicAddrSpace::LDS;
  if (AS == AMDGPUAS::PRIVATE_ADDRESS)
    return SIAtomicAddrSpace::SCRATCH;
  if (AS == AMDGPUAS::REGION_ADDRESS)
    return SIAtomicAddrSpace::GDS;

  return SIAtomicAddrSpace::OTHER;
}

SIMemOpAccess::SIMemOpAccess(MachineFunction &MF) {
  MMI = &MF.getMMI().getObjFileInfo<AMDGPUMachineModuleInfo>();
}

Optional<SIMemOpInfo> SIMemOpAccess::constructFromMIWithMMO(
    const MachineBasicBlock::iterator &MI) const {
  assert(MI->getNumMemOperands() > 0);

  SyncScope::ID SSID = SyncScope::SingleThread;
  AtomicOrdering Ordering = AtomicOrdering::NotAtomic;
  AtomicOrdering FailureOrdering = AtomicOrdering::NotAtomic;
  SIAtomicAddrSpace InstrAddrSpace = SIAtomicAddrSpace::NONE;
  bool IsNonTemporal = true;

  // Validator should check whether or not MMOs cover the entire set of
  // locations accessed by the memory instruction.
  for (const auto &MMO : MI->memoperands()) {
    IsNonTemporal &= MMO->isNonTemporal();
    InstrAddrSpace |=
      toSIAtomicAddrSpace(MMO->getPointerInfo().getAddrSpace());
    AtomicOrdering OpOrdering = MMO->getOrdering();
    if (OpOrdering != AtomicOrdering::NotAtomic) {
      const auto &IsSyncScopeInclusion =
          MMI->isSyncScopeInclusion(SSID, MMO->getSyncScopeID());
      if (!IsSyncScopeInclusion) {
        reportUnsupported(MI,
          "Unsupported non-inclusive atomic synchronization scope");
        return None;
      }

      SSID = IsSyncScopeInclusion.getValue() ? SSID : MMO->getSyncScopeID();
      Ordering =
          isStrongerThan(Ordering, OpOrdering) ?
              Ordering : MMO->getOrdering();
      assert(MMO->getFailureOrdering() != AtomicOrdering::Release &&
             MMO->getFailureOrdering() != AtomicOrdering::AcquireRelease);
      FailureOrdering =
          isStrongerThan(FailureOrdering, MMO->getFailureOrdering()) ?
              FailureOrdering : MMO->getFailureOrdering();
    }
  }

  SIAtomicScope Scope = SIAtomicScope::NONE;
  SIAtomicAddrSpace OrderingAddrSpace = SIAtomicAddrSpace::NONE;
  bool IsCrossAddressSpaceOrdering = false;
  if (Ordering != AtomicOrdering::NotAtomic) {
    auto ScopeOrNone = toSIAtomicScope(SSID, InstrAddrSpace);
    if (!ScopeOrNone) {
      reportUnsupported(MI, "Unsupported atomic synchronization scope");
      return None;
    }
    std::tie(Scope, OrderingAddrSpace, IsCrossAddressSpaceOrdering) =
      ScopeOrNone.getValue();
    if ((OrderingAddrSpace == SIAtomicAddrSpace::NONE) ||
        ((OrderingAddrSpace & SIAtomicAddrSpace::ATOMIC) != OrderingAddrSpace)) {
      reportUnsupported(MI, "Unsupported atomic address space");
      return None;
    }
  }
  return SIMemOpInfo(Ordering, Scope, OrderingAddrSpace, InstrAddrSpace,
                     IsCrossAddressSpaceOrdering, FailureOrdering, IsNonTemporal);
}

Optional<SIMemOpInfo> SIMemOpAccess::getLoadInfo(
    const MachineBasicBlock::iterator &MI) const {
  assert(MI->getDesc().TSFlags & SIInstrFlags::maybeAtomic);

  if (!(MI->mayLoad() && !MI->mayStore()))
    return None;

  // Be conservative if there are no memory operands.
  if (MI->getNumMemOperands() == 0)
    return SIMemOpInfo();

  return constructFromMIWithMMO(MI);
}

Optional<SIMemOpInfo> SIMemOpAccess::getStoreInfo(
    const MachineBasicBlock::iterator &MI) const {
  assert(MI->getDesc().TSFlags & SIInstrFlags::maybeAtomic);

  if (!(!MI->mayLoad() && MI->mayStore()))
    return None;

  // Be conservative if there are no memory operands.
  if (MI->getNumMemOperands() == 0)
    return SIMemOpInfo();

  return constructFromMIWithMMO(MI);
}

Optional<SIMemOpInfo> SIMemOpAccess::getAtomicFenceInfo(
    const MachineBasicBlock::iterator &MI) const {
  assert(MI->getDesc().TSFlags & SIInstrFlags::maybeAtomic);

  if (MI->getOpcode() != AMDGPU::ATOMIC_FENCE)
    return None;

  AtomicOrdering Ordering =
    static_cast<AtomicOrdering>(MI->getOperand(0).getImm());

  SyncScope::ID SSID = static_cast<SyncScope::ID>(MI->getOperand(1).getImm());
  auto ScopeOrNone = toSIAtomicScope(SSID, SIAtomicAddrSpace::ATOMIC);
  if (!ScopeOrNone) {
    reportUnsupported(MI, "Unsupported atomic synchronization scope");
    return None;
  }

  SIAtomicScope Scope = SIAtomicScope::NONE;
  SIAtomicAddrSpace OrderingAddrSpace = SIAtomicAddrSpace::NONE;
  bool IsCrossAddressSpaceOrdering = false;
  std::tie(Scope, OrderingAddrSpace, IsCrossAddressSpaceOrdering) =
    ScopeOrNone.getValue();

  if ((OrderingAddrSpace == SIAtomicAddrSpace::NONE) ||
      ((OrderingAddrSpace & SIAtomicAddrSpace::ATOMIC) != OrderingAddrSpace)) {
    reportUnsupported(MI, "Unsupported atomic address space");
    return None;
  }

  return SIMemOpInfo(Ordering, Scope, OrderingAddrSpace, SIAtomicAddrSpace::ATOMIC,
                     IsCrossAddressSpaceOrdering);
}

Optional<SIMemOpInfo> SIMemOpAccess::getAtomicCmpxchgOrRmwInfo(
    const MachineBasicBlock::iterator &MI) const {
  assert(MI->getDesc().TSFlags & SIInstrFlags::maybeAtomic);

  if (!(MI->mayLoad() && MI->mayStore()))
    return None;

  // Be conservative if there are no memory operands.
  if (MI->getNumMemOperands() == 0)
    return SIMemOpInfo();

  return constructFromMIWithMMO(MI);
}

SICacheControl::SICacheControl(const GCNSubtarget &ST) : ST(ST) {
  TII = ST.getInstrInfo();
  IV = getIsaVersion(ST.getCPU());
  InsertCacheInv = !AmdgcnSkipCacheInvalidations;
}

/* static */
std::unique_ptr<SICacheControl> SICacheControl::create(const GCNSubtarget &ST) {
  GCNSubtarget::Generation Generation = ST.getGeneration();
  if (Generation <= AMDGPUSubtarget::SOUTHERN_ISLANDS)
    return std::make_unique<SIGfx6CacheControl>(ST);
  if (Generation < AMDGPUSubtarget::GFX10)
    return std::make_unique<SIGfx7CacheControl>(ST);
  return std::make_unique<SIGfx10CacheControl>(ST);
}

bool SIGfx6CacheControl::enableLoadCacheBypass(
    const MachineBasicBlock::iterator &MI,
    SIAtomicScope Scope,
    SIAtomicAddrSpace AddrSpace) const {
  assert(MI->mayLoad() && !MI->mayStore());
  bool Changed = false;

  if ((AddrSpace & SIAtomicAddrSpace::GLOBAL) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      Changed |= enableGLCBit(MI);
      break;
    case SIAtomicScope::WORKGROUP:
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // No cache to bypass.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  /// The scratch address space does not need the global memory caches
  /// to be bypassed as all memory operations by the same thread are
  /// sequentially consistent, and no other thread can access scratch
  /// memory.

  /// Other address spaces do not have a cache.

  return Changed;
}

bool SIGfx6CacheControl::enableNonTemporal(
    const MachineBasicBlock::iterator &MI) const {
  assert(MI->mayLoad() ^ MI->mayStore());
  bool Changed = false;

  /// TODO: Do not enableGLCBit if rmw atomic.
  Changed |= enableGLCBit(MI);
  Changed |= enableSLCBit(MI);

  return Changed;
}

bool SIGfx6CacheControl::insertAcquire(MachineBasicBlock::iterator &MI,
                                       SIAtomicScope Scope,
                                       SIAtomicAddrSpace AddrSpace,
                                       Position Pos) const {
  if (!InsertCacheInv)
    return false;

  bool Changed = false;

  MachineBasicBlock &MBB = *MI->getParent();
  DebugLoc DL = MI->getDebugLoc();

  if (Pos == Position::AFTER)
    ++MI;

  if ((AddrSpace & SIAtomicAddrSpace::GLOBAL) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      BuildMI(MBB, MI, DL, TII->get(AMDGPU::BUFFER_WBINVL1));
      Changed = true;
      break;
    case SIAtomicScope::WORKGROUP:
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // No cache to invalidate.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  /// The scratch address space does not need the global memory cache
  /// to be flushed as all memory operations by the same thread are
  /// sequentially consistent, and no other thread can access scratch
  /// memory.

  /// Other address spaces do not have a cache.

  if (Pos == Position::AFTER)
    --MI;

  return Changed;
}

bool SIGfx6CacheControl::insertWait(MachineBasicBlock::iterator &MI,
                                    SIAtomicScope Scope,
                                    SIAtomicAddrSpace AddrSpace,
                                    SIMemOp Op,
                                    bool IsCrossAddrSpaceOrdering,
                                    Position Pos) const {
  bool Changed = false;

  MachineBasicBlock &MBB = *MI->getParent();
  DebugLoc DL = MI->getDebugLoc();

  if (Pos == Position::AFTER)
    ++MI;

  bool VMCnt = false;
  bool LGKMCnt = false;

  if ((AddrSpace & SIAtomicAddrSpace::GLOBAL) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      VMCnt |= true;
      break;
    case SIAtomicScope::WORKGROUP:
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // The L1 cache keeps all memory operations in order for
      // wavefronts in the same work-group.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  if ((AddrSpace & SIAtomicAddrSpace::LDS) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
    case SIAtomicScope::WORKGROUP:
      // If no cross address space ordering then an "S_WAITCNT lgkmcnt(0)" is
      // not needed as LDS operations for all waves are executed in a total
      // global ordering as observed by all waves. Required if also
      // synchronizing with global/GDS memory as LDS operations could be
      // reordered with respect to later global/GDS memory operations of the
      // same wave.
      LGKMCnt |= IsCrossAddrSpaceOrdering;
      break;
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // The LDS keeps all memory operations in order for
      // the same wavesfront.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  if ((AddrSpace & SIAtomicAddrSpace::GDS) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      // If no cross address space ordering then an GDS "S_WAITCNT lgkmcnt(0)"
      // is not needed as GDS operations for all waves are executed in a total
      // global ordering as observed by all waves. Required if also
      // synchronizing with global/LDS memory as GDS operations could be
      // reordered with respect to later global/LDS memory operations of the
      // same wave.
      LGKMCnt |= IsCrossAddrSpaceOrdering;
      break;
    case SIAtomicScope::WORKGROUP:
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // The GDS keeps all memory operations in order for
      // the same work-group.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  if (VMCnt || LGKMCnt) {
    unsigned WaitCntImmediate =
      AMDGPU::encodeWaitcnt(IV,
                            VMCnt ? 0 : getVmcntBitMask(IV),
                            getExpcntBitMask(IV),
                            LGKMCnt ? 0 : getLgkmcntBitMask(IV));
    BuildMI(MBB, MI, DL, TII->get(AMDGPU::S_WAITCNT)).addImm(WaitCntImmediate);
    Changed = true;
  }

  if (Pos == Position::AFTER)
    --MI;

  return Changed;
}

bool SIGfx6CacheControl::insertRelease(MachineBasicBlock::iterator &MI,
                                       SIAtomicScope Scope,
                                       SIAtomicAddrSpace AddrSpace,
                                       bool IsCrossAddrSpaceOrdering,
                                       Position Pos) const {
    return insertWait(MI, Scope, AddrSpace, SIMemOp::LOAD | SIMemOp::STORE,
                      IsCrossAddrSpaceOrdering, Pos);
}

bool SIGfx7CacheControl::insertAcquire(MachineBasicBlock::iterator &MI,
                                       SIAtomicScope Scope,
                                       SIAtomicAddrSpace AddrSpace,
                                       Position Pos) const {
  if (!InsertCacheInv)
    return false;

  bool Changed = false;

  MachineBasicBlock &MBB = *MI->getParent();
  DebugLoc DL = MI->getDebugLoc();

  const GCNSubtarget &STM = MBB.getParent()->getSubtarget<GCNSubtarget>();

  const unsigned InvalidateL1 = STM.isAmdPalOS() || STM.isMesa3DOS()
                                    ? AMDGPU::BUFFER_WBINVL1
                                    : AMDGPU::BUFFER_WBINVL1_VOL;

  if (Pos == Position::AFTER)
    ++MI;

  if ((AddrSpace & SIAtomicAddrSpace::GLOBAL) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      BuildMI(MBB, MI, DL, TII->get(InvalidateL1));
      Changed = true;
      break;
    case SIAtomicScope::WORKGROUP:
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // No cache to invalidate.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  /// The scratch address space does not need the global memory cache
  /// to be flushed as all memory operations by the same thread are
  /// sequentially consistent, and no other thread can access scratch
  /// memory.

  /// Other address spaces do not have a cache.

  if (Pos == Position::AFTER)
    --MI;

  return Changed;
}

bool SIGfx10CacheControl::enableLoadCacheBypass(
    const MachineBasicBlock::iterator &MI,
    SIAtomicScope Scope,
    SIAtomicAddrSpace AddrSpace) const {
  assert(MI->mayLoad() && !MI->mayStore());
  bool Changed = false;

  if ((AddrSpace & SIAtomicAddrSpace::GLOBAL) != SIAtomicAddrSpace::NONE) {
    /// TODO Do not set glc for rmw atomic operations as they
    /// implicitly bypass the L0/L1 caches.

    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      Changed |= enableGLCBit(MI);
      Changed |= enableDLCBit(MI);
      break;
    case SIAtomicScope::WORKGROUP:
      // In WGP mode the waves of a work-group can be executing on either CU of
      // the WGP. Therefore need to bypass the L0 which is per CU. Otherwise in
      // CU mode all waves of a work-group are on the same CU, and so the L0
      // does not need to be bypassed.
      if (!ST.isCuModeEnabled()) Changed |= enableGLCBit(MI);
      break;
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // No cache to bypass.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  /// The scratch address space does not need the global memory caches
  /// to be bypassed as all memory operations by the same thread are
  /// sequentially consistent, and no other thread can access scratch
  /// memory.

  /// Other address spaces do not have a cache.

  return Changed;
}

bool SIGfx10CacheControl::enableNonTemporal(
    const MachineBasicBlock::iterator &MI) const {
  assert(MI->mayLoad() ^ MI->mayStore());
  bool Changed = false;

  Changed |= enableSLCBit(MI);
  /// TODO for store (non-rmw atomic) instructions also enableGLCBit(MI)

  return Changed;
}

bool SIGfx10CacheControl::insertAcquire(MachineBasicBlock::iterator &MI,
                                        SIAtomicScope Scope,
                                        SIAtomicAddrSpace AddrSpace,
                                        Position Pos) const {
  if (!InsertCacheInv)
    return false;

  bool Changed = false;

  MachineBasicBlock &MBB = *MI->getParent();
  DebugLoc DL = MI->getDebugLoc();

  if (Pos == Position::AFTER)
    ++MI;

  if ((AddrSpace & SIAtomicAddrSpace::GLOBAL) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      BuildMI(MBB, MI, DL, TII->get(AMDGPU::BUFFER_GL0_INV));
      BuildMI(MBB, MI, DL, TII->get(AMDGPU::BUFFER_GL1_INV));
      Changed = true;
      break;
    case SIAtomicScope::WORKGROUP:
      // In WGP mode the waves of a work-group can be executing on either CU of
      // the WGP. Therefore need to invalidate the L0 which is per CU. Otherwise
      // in CU mode and all waves of a work-group are on the same CU, and so the
      // L0 does not need to be invalidated.
      if (!ST.isCuModeEnabled()) {
        BuildMI(MBB, MI, DL, TII->get(AMDGPU::BUFFER_GL0_INV));
        Changed = true;
      }
      break;
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // No cache to invalidate.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  /// The scratch address space does not need the global memory cache
  /// to be flushed as all memory operations by the same thread are
  /// sequentially consistent, and no other thread can access scratch
  /// memory.

  /// Other address spaces do not have a cache.

  if (Pos == Position::AFTER)
    --MI;

  return Changed;
}

bool SIGfx10CacheControl::insertWait(MachineBasicBlock::iterator &MI,
                                     SIAtomicScope Scope,
                                     SIAtomicAddrSpace AddrSpace,
                                     SIMemOp Op,
                                     bool IsCrossAddrSpaceOrdering,
                                     Position Pos) const {
  bool Changed = false;

  MachineBasicBlock &MBB = *MI->getParent();
  DebugLoc DL = MI->getDebugLoc();

  if (Pos == Position::AFTER)
    ++MI;

  bool VMCnt = false;
  bool VSCnt = false;
  bool LGKMCnt = false;

  if ((AddrSpace & SIAtomicAddrSpace::GLOBAL) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      if ((Op & SIMemOp::LOAD) != SIMemOp::NONE)
        VMCnt |= true;
      if ((Op & SIMemOp::STORE) != SIMemOp::NONE)
        VSCnt |= true;
      break;
    case SIAtomicScope::WORKGROUP:
      // In WGP mode the waves of a work-group can be executing on either CU of
      // the WGP. Therefore need to wait for operations to complete to ensure
      // they are visible to waves in the other CU as the L0 is per CU.
      // Otherwise in CU mode and all waves of a work-group are on the same CU
      // which shares the same L0.
      if (!ST.isCuModeEnabled()) {
        if ((Op & SIMemOp::LOAD) != SIMemOp::NONE)
          VMCnt |= true;
        if ((Op & SIMemOp::STORE) != SIMemOp::NONE)
          VSCnt |= true;
      }
      break;
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // The L0 cache keeps all memory operations in order for
      // work-items in the same wavefront.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  if ((AddrSpace & SIAtomicAddrSpace::LDS) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
    case SIAtomicScope::WORKGROUP:
      // If no cross address space ordering then an "S_WAITCNT lgkmcnt(0)" is
      // not needed as LDS operations for all waves are executed in a total
      // global ordering as observed by all waves. Required if also
      // synchronizing with global/GDS memory as LDS operations could be
      // reordered with respect to later global/GDS memory operations of the
      // same wave.
      LGKMCnt |= IsCrossAddrSpaceOrdering;
      break;
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // The LDS keeps all memory operations in order for
      // the same wavesfront.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  if ((AddrSpace & SIAtomicAddrSpace::GDS) != SIAtomicAddrSpace::NONE) {
    switch (Scope) {
    case SIAtomicScope::SYSTEM:
    case SIAtomicScope::AGENT:
      // If no cross address space ordering then an GDS "S_WAITCNT lgkmcnt(0)"
      // is not needed as GDS operations for all waves are executed in a total
      // global ordering as observed by all waves. Required if also
      // synchronizing with global/LDS memory as GDS operations could be
      // reordered with respect to later global/LDS memory operations of the
      // same wave.
      LGKMCnt |= IsCrossAddrSpaceOrdering;
      break;
    case SIAtomicScope::WORKGROUP:
    case SIAtomicScope::WAVEFRONT:
    case SIAtomicScope::SINGLETHREAD:
      // The GDS keeps all memory operations in order for
      // the same work-group.
      break;
    default:
      llvm_unreachable("Unsupported synchronization scope");
    }
  }

  if (VMCnt || LGKMCnt) {
    unsigned WaitCntImmediate =
      AMDGPU::encodeWaitcnt(IV,
                            VMCnt ? 0 : getVmcntBitMask(IV),
                            getExpcntBitMask(IV),
                            LGKMCnt ? 0 : getLgkmcntBitMask(IV));
    BuildMI(MBB, MI, DL, TII->get(AMDGPU::S_WAITCNT)).addImm(WaitCntImmediate);
    Changed = true;
  }

  if (VSCnt) {
    BuildMI(MBB, MI, DL, TII->get(AMDGPU::S_WAITCNT_VSCNT))
      .addReg(AMDGPU::SGPR_NULL, RegState::Undef)
      .addImm(0);
    Changed = true;
  }

  if (Pos == Position::AFTER)
    --MI;

  return Changed;
}

bool SIMemoryLegalizer::removeAtomicPseudoMIs() {
  if (AtomicPseudoMIs.empty())
    return false;

  for (auto &MI : AtomicPseudoMIs)
    MI->eraseFromParent();

  AtomicPseudoMIs.clear();
  return true;
}

bool SIMemoryLegalizer::expandLoad(const SIMemOpInfo &MOI,
                                   MachineBasicBlock::iterator &MI) {
  assert(MI->mayLoad() && !MI->mayStore());

  bool Changed = false;

  if (MOI.isAtomic()) {
    if (MOI.getOrdering() == AtomicOrdering::Monotonic ||
        MOI.getOrdering() == AtomicOrdering::Acquire ||
        MOI.getOrdering() == AtomicOrdering::SequentiallyConsistent) {
      Changed |= CC->enableLoadCacheBypass(MI, MOI.getScope(),
                                           MOI.getOrderingAddrSpace());
    }

    if (MOI.getOrdering() == AtomicOrdering::SequentiallyConsistent)
      Changed |= CC->insertWait(MI, MOI.getScope(),
                                MOI.getOrderingAddrSpace(),
                                SIMemOp::LOAD | SIMemOp::STORE,
                                MOI.getIsCrossAddressSpaceOrdering(),
                                Position::BEFORE);

    if (MOI.getOrdering() == AtomicOrdering::Acquire ||
        MOI.getOrdering() == AtomicOrdering::SequentiallyConsistent) {
      Changed |= CC->insertWait(MI, MOI.getScope(),
                                MOI.getInstrAddrSpace(),
                                SIMemOp::LOAD,
                                MOI.getIsCrossAddressSpaceOrdering(),
                                Position::AFTER);
      Changed |= CC->insertAcquire(MI, MOI.getScope(),
                                   MOI.getOrderingAddrSpace(),
                                   Position::AFTER);
    }

    return Changed;
  }

  // Atomic instructions do not have the nontemporal attribute.
  if (MOI.isNonTemporal()) {
    Changed |= CC->enableNonTemporal(MI);
    return Changed;
  }

  return Changed;
}

bool SIMemoryLegalizer::expandStore(const SIMemOpInfo &MOI,
                                    MachineBasicBlock::iterator &MI) {
  assert(!MI->mayLoad() && MI->mayStore());

  bool Changed = false;

  if (MOI.isAtomic()) {
    if (MOI.getOrdering() == AtomicOrdering::Release ||
        MOI.getOrdering() == AtomicOrdering::SequentiallyConsistent)
      Changed |= CC->insertRelease(MI, MOI.getScope(),
                                   MOI.getOrderingAddrSpace(),
                                   MOI.getIsCrossAddressSpaceOrdering(),
                                   Position::BEFORE);

    return Changed;
  }

  // Atomic instructions do not have the nontemporal attribute.
  if (MOI.isNonTemporal()) {
    Changed |= CC->enableNonTemporal(MI);
    return Changed;
  }

  return Changed;
}

bool SIMemoryLegalizer::expandAtomicFence(const SIMemOpInfo &MOI,
                                          MachineBasicBlock::iterator &MI) {
  assert(MI->getOpcode() == AMDGPU::ATOMIC_FENCE);

  AtomicPseudoMIs.push_back(MI);
  bool Changed = false;

  if (MOI.isAtomic()) {
    if (MOI.getOrdering() == AtomicOrdering::Acquire ||
        MOI.getOrdering() == AtomicOrdering::Release ||
        MOI.getOrdering() == AtomicOrdering::AcquireRelease ||
        MOI.getOrdering() == AtomicOrdering::SequentiallyConsistent)
      /// TODO: This relies on a barrier always generating a waitcnt
      /// for LDS to ensure it is not reordered with the completion of
      /// the proceeding LDS operations. If barrier had a memory
      /// ordering and memory scope, then library does not need to
      /// generate a fence. Could add support in this file for
      /// barrier. SIInsertWaitcnt.cpp could then stop unconditionally
      /// adding S_WAITCNT before a S_BARRIER.
      Changed |= CC->insertRelease(MI, MOI.getScope(),
                                   MOI.getOrderingAddrSpace(),
                                   MOI.getIsCrossAddressSpaceOrdering(),
                                   Position::BEFORE);

    // TODO: If both release and invalidate are happening they could be combined
    // to use the single "BUFFER_WBL2" instruction. This could be done by
    // reorganizing this code or as part of optimizing SIInsertWaitcnt pass to
    // track cache invalidate and write back instructions.

    if (MOI.getOrdering() == AtomicOrdering::Acquire ||
        MOI.getOrdering() == AtomicOrdering::AcquireRelease ||
        MOI.getOrdering() == AtomicOrdering::SequentiallyConsistent)
      Changed |= CC->insertAcquire(MI, MOI.getScope(),
                                   MOI.getOrderingAddrSpace(),
                                   Position::BEFORE);

    return Changed;
  }

  return Changed;
}

bool SIMemoryLegalizer::expandAtomicCmpxchgOrRmw(const SIMemOpInfo &MOI,
  MachineBasicBlock::iterator &MI) {
  assert(MI->mayLoad() && MI->mayStore());

  bool Changed = false;

  if (MOI.isAtomic()) {
    if (MOI.getOrdering() == AtomicOrdering::Release ||
        MOI.getOrdering() == AtomicOrdering::AcquireRelease ||
        MOI.getOrdering() == AtomicOrdering::SequentiallyConsistent ||
        MOI.getFailureOrdering() == AtomicOrdering::SequentiallyConsistent)
      Changed |= CC->insertRelease(MI, MOI.getScope(),
                                   MOI.getOrderingAddrSpace(),
                                   MOI.getIsCrossAddressSpaceOrdering(),
                                   Position::BEFORE);

    if (MOI.getOrdering() == AtomicOrdering::Acquire ||
        MOI.getOrdering() == AtomicOrdering::AcquireRelease ||
        MOI.getOrdering() == AtomicOrdering::SequentiallyConsistent ||
        MOI.getFailureOrdering() == AtomicOrdering::Acquire ||
        MOI.getFailureOrdering() == AtomicOrdering::SequentiallyConsistent) {
      Changed |= CC->insertWait(MI, MOI.getScope(),
                                MOI.getOrderingAddrSpace(),
                                isAtomicRet(*MI) ? SIMemOp::LOAD :
                                                   SIMemOp::STORE,
                                MOI.getIsCrossAddressSpaceOrdering(),
                                Position::AFTER);
      Changed |= CC->insertAcquire(MI, MOI.getScope(),
                                   MOI.getOrderingAddrSpace(),
                                   Position::AFTER);
    }

    return Changed;
  }

  return Changed;
}

bool SIMemoryLegalizer::runOnMachineFunction(MachineFunction &MF) {
  bool Changed = false;

  SIMemOpAccess MOA(MF);
  CC = SICacheControl::create(MF.getSubtarget<GCNSubtarget>());

  for (auto &MBB : MF) {
    for (auto MI = MBB.begin(); MI != MBB.end(); ++MI) {

      if (MI->getOpcode() == TargetOpcode::BUNDLE && MI->mayLoadOrStore()) {
        MachineBasicBlock::instr_iterator II(MI->getIterator());
        for (MachineBasicBlock::instr_iterator I = ++II, E = MBB.instr_end();
             I != E && I->isBundledWithPred(); ++I) {
          I->unbundleFromPred();
          for (MachineOperand &MO : I->operands())
            if (MO.isReg())
              MO.setIsInternalRead(false);
        }

        MI->eraseFromParent();
        MI = II->getIterator();
      }

      if (!(MI->getDesc().TSFlags & SIInstrFlags::maybeAtomic))
        continue;

      if (const auto &MOI = MOA.getLoadInfo(MI))
        Changed |= expandLoad(MOI.getValue(), MI);
      else if (const auto &MOI = MOA.getStoreInfo(MI))
        Changed |= expandStore(MOI.getValue(), MI);
      else if (const auto &MOI = MOA.getAtomicFenceInfo(MI))
        Changed |= expandAtomicFence(MOI.getValue(), MI);
      else if (const auto &MOI = MOA.getAtomicCmpxchgOrRmwInfo(MI))
        Changed |= expandAtomicCmpxchgOrRmw(MOI.getValue(), MI);
    }
  }

  Changed |= removeAtomicPseudoMIs();
  return Changed;
}

INITIALIZE_PASS(SIMemoryLegalizer, DEBUG_TYPE, PASS_NAME, false, false)

char SIMemoryLegalizer::ID = 0;
char &llvm::SIMemoryLegalizerID = SIMemoryLegalizer::ID;

FunctionPass *llvm::createSIMemoryLegalizerPass() {
  return new SIMemoryLegalizer();
}
