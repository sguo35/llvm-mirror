//===- lib/MC/MCAssembler.cpp - Assembler Backend Implementation ----------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "assembler"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCAsmLayout.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSectionMachO.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MachO.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/Debug.h"
#include "llvm/Target/TargetRegistry.h"
#include "llvm/Target/TargetAsmBackend.h"

// FIXME: Gross.
#include "../Target/X86/X86FixupKinds.h"

#include <vector>
using namespace llvm;

class MachObjectWriter;

STATISTIC(EmittedFragments, "Number of emitted assembler fragments");

// FIXME FIXME FIXME: There are number of places in this file where we convert
// what is a 64-bit assembler value used for computation into a value in the
// object file, which may truncate it. We should detect that truncation where
// invalid and report errors back.

static unsigned getFixupKindLog2Size(unsigned Kind) {
  switch (Kind) {
  default: llvm_unreachable("invalid fixup kind!");
  case X86::reloc_pcrel_1byte:
  case FK_Data_1: return 0;
  case FK_Data_2: return 1;
  case X86::reloc_pcrel_4byte:
  case X86::reloc_riprel_4byte:
  case FK_Data_4: return 2;
  case FK_Data_8: return 3;
  }
}

static bool isFixupKindPCRel(unsigned Kind) {
  switch (Kind) {
  default:
    return false;
  case X86::reloc_pcrel_1byte:
  case X86::reloc_pcrel_4byte:
  case X86::reloc_riprel_4byte:
    return true;
  }
}

class MachObjectWriter : public MCObjectWriter {
  // See <mach-o/loader.h>.
  enum {
    Header_Magic32 = 0xFEEDFACE,
    Header_Magic64 = 0xFEEDFACF
  };

  enum {
    Header32Size = 28,
    Header64Size = 32,
    SegmentLoadCommand32Size = 56,
    SegmentLoadCommand64Size = 72,
    Section32Size = 68,
    Section64Size = 80,
    SymtabLoadCommandSize = 24,
    DysymtabLoadCommandSize = 80,
    Nlist32Size = 12,
    Nlist64Size = 16,
    RelocationInfoSize = 8
  };

  enum HeaderFileType {
    HFT_Object = 0x1
  };

  enum HeaderFlags {
    HF_SubsectionsViaSymbols = 0x2000
  };

  enum LoadCommandType {
    LCT_Segment = 0x1,
    LCT_Symtab = 0x2,
    LCT_Dysymtab = 0xb,
    LCT_Segment64 = 0x19
  };

  // See <mach-o/nlist.h>.
  enum SymbolTypeType {
    STT_Undefined = 0x00,
    STT_Absolute  = 0x02,
    STT_Section   = 0x0e
  };

  enum SymbolTypeFlags {
    // If any of these bits are set, then the entry is a stab entry number (see
    // <mach-o/stab.h>. Otherwise the other masks apply.
    STF_StabsEntryMask = 0xe0,

    STF_TypeMask       = 0x0e,
    STF_External       = 0x01,
    STF_PrivateExtern  = 0x10
  };

  /// IndirectSymbolFlags - Flags for encoding special values in the indirect
  /// symbol entry.
  enum IndirectSymbolFlags {
    ISF_Local    = 0x80000000,
    ISF_Absolute = 0x40000000
  };

  /// RelocationFlags - Special flags for addresses.
  enum RelocationFlags {
    RF_Scattered = 0x80000000
  };

  enum RelocationInfoType {
    RIT_Vanilla             = 0,
    RIT_Pair                = 1,
    RIT_Difference          = 2,
    RIT_PreboundLazyPointer = 3,
    RIT_LocalDifference     = 4
  };

  /// MachSymbolData - Helper struct for containing some precomputed information
  /// on symbols.
  struct MachSymbolData {
    MCSymbolData *SymbolData;
    uint64_t StringIndex;
    uint8_t SectionIndex;

    // Support lexicographic sorting.
    bool operator<(const MachSymbolData &RHS) const {
      const std::string &Name = SymbolData->getSymbol().getName();
      return Name < RHS.SymbolData->getSymbol().getName();
    }
  };

  unsigned Is64Bit : 1;

  /// @name Relocation Data
  /// @{

  struct MachRelocationEntry {
    uint32_t Word0;
    uint32_t Word1;
  };

  llvm::DenseMap<const MCSectionData*,
                 std::vector<MachRelocationEntry> > Relocations;

  /// @}
  /// @name Symbol Table Data

  SmallString<256> StringTable;
  std::vector<MachSymbolData> LocalSymbolData;
  std::vector<MachSymbolData> ExternalSymbolData;
  std::vector<MachSymbolData> UndefinedSymbolData;

  /// @}

public:
  MachObjectWriter(raw_ostream &_OS, bool _Is64Bit, bool _IsLittleEndian = true)
    : MCObjectWriter(_OS, _IsLittleEndian), Is64Bit(_Is64Bit) {
  }

  void WriteHeader(unsigned NumLoadCommands, unsigned LoadCommandsSize,
                   bool SubsectionsViaSymbols) {
    uint32_t Flags = 0;

    if (SubsectionsViaSymbols)
      Flags |= HF_SubsectionsViaSymbols;

    // struct mach_header (28 bytes) or
    // struct mach_header_64 (32 bytes)

    uint64_t Start = OS.tell();
    (void) Start;

    Write32(Is64Bit ? Header_Magic64 : Header_Magic32);

    // FIXME: Support cputype.
    Write32(Is64Bit ? MachO::CPUTypeX86_64 : MachO::CPUTypeI386);
    // FIXME: Support cpusubtype.
    Write32(MachO::CPUSubType_I386_ALL);
    Write32(HFT_Object);
    Write32(NumLoadCommands);    // Object files have a single load command, the
                                 // segment.
    Write32(LoadCommandsSize);
    Write32(Flags);
    if (Is64Bit)
      Write32(0); // reserved

    assert(OS.tell() - Start == Is64Bit ? Header64Size : Header32Size);
  }

  /// WriteSegmentLoadCommand - Write a segment load command.
  ///
  /// \arg NumSections - The number of sections in this segment.
  /// \arg SectionDataSize - The total size of the sections.
  void WriteSegmentLoadCommand(unsigned NumSections,
                               uint64_t VMSize,
                               uint64_t SectionDataStartOffset,
                               uint64_t SectionDataSize) {
    // struct segment_command (56 bytes) or
    // struct segment_command_64 (72 bytes)

    uint64_t Start = OS.tell();
    (void) Start;

    unsigned SegmentLoadCommandSize = Is64Bit ? SegmentLoadCommand64Size :
      SegmentLoadCommand32Size;
    Write32(Is64Bit ? LCT_Segment64 : LCT_Segment);
    Write32(SegmentLoadCommandSize +
            NumSections * (Is64Bit ? Section64Size : Section32Size));

    WriteBytes("", 16);
    if (Is64Bit) {
      Write64(0); // vmaddr
      Write64(VMSize); // vmsize
      Write64(SectionDataStartOffset); // file offset
      Write64(SectionDataSize); // file size
    } else {
      Write32(0); // vmaddr
      Write32(VMSize); // vmsize
      Write32(SectionDataStartOffset); // file offset
      Write32(SectionDataSize); // file size
    }
    Write32(0x7); // maxprot
    Write32(0x7); // initprot
    Write32(NumSections);
    Write32(0); // flags

    assert(OS.tell() - Start == SegmentLoadCommandSize);
  }

  void WriteSection(const MCAssembler &Asm, const MCSectionData &SD,
                    uint64_t FileOffset, uint64_t RelocationsStart,
                    unsigned NumRelocations) {
    // The offset is unused for virtual sections.
    if (Asm.getBackend().isVirtualSection(SD.getSection())) {
      assert(SD.getFileSize() == 0 && "Invalid file size!");
      FileOffset = 0;
    }

    // struct section (68 bytes) or
    // struct section_64 (80 bytes)

    uint64_t Start = OS.tell();
    (void) Start;

    // FIXME: cast<> support!
    const MCSectionMachO &Section =
      static_cast<const MCSectionMachO&>(SD.getSection());
    WriteBytes(Section.getSectionName(), 16);
    WriteBytes(Section.getSegmentName(), 16);
    if (Is64Bit) {
      Write64(SD.getAddress()); // address
      Write64(SD.getSize()); // size
    } else {
      Write32(SD.getAddress()); // address
      Write32(SD.getSize()); // size
    }
    Write32(FileOffset);

    unsigned Flags = Section.getTypeAndAttributes();
    if (SD.hasInstructions())
      Flags |= MCSectionMachO::S_ATTR_SOME_INSTRUCTIONS;

    assert(isPowerOf2_32(SD.getAlignment()) && "Invalid alignment!");
    Write32(Log2_32(SD.getAlignment()));
    Write32(NumRelocations ? RelocationsStart : 0);
    Write32(NumRelocations);
    Write32(Flags);
    Write32(0); // reserved1
    Write32(Section.getStubSize()); // reserved2
    if (Is64Bit)
      Write32(0); // reserved3

    assert(OS.tell() - Start == Is64Bit ? Section64Size : Section32Size);
  }

  void WriteSymtabLoadCommand(uint32_t SymbolOffset, uint32_t NumSymbols,
                              uint32_t StringTableOffset,
                              uint32_t StringTableSize) {
    // struct symtab_command (24 bytes)

    uint64_t Start = OS.tell();
    (void) Start;

    Write32(LCT_Symtab);
    Write32(SymtabLoadCommandSize);
    Write32(SymbolOffset);
    Write32(NumSymbols);
    Write32(StringTableOffset);
    Write32(StringTableSize);

    assert(OS.tell() - Start == SymtabLoadCommandSize);
  }

  void WriteDysymtabLoadCommand(uint32_t FirstLocalSymbol,
                                uint32_t NumLocalSymbols,
                                uint32_t FirstExternalSymbol,
                                uint32_t NumExternalSymbols,
                                uint32_t FirstUndefinedSymbol,
                                uint32_t NumUndefinedSymbols,
                                uint32_t IndirectSymbolOffset,
                                uint32_t NumIndirectSymbols) {
    // struct dysymtab_command (80 bytes)

    uint64_t Start = OS.tell();
    (void) Start;

    Write32(LCT_Dysymtab);
    Write32(DysymtabLoadCommandSize);
    Write32(FirstLocalSymbol);
    Write32(NumLocalSymbols);
    Write32(FirstExternalSymbol);
    Write32(NumExternalSymbols);
    Write32(FirstUndefinedSymbol);
    Write32(NumUndefinedSymbols);
    Write32(0); // tocoff
    Write32(0); // ntoc
    Write32(0); // modtaboff
    Write32(0); // nmodtab
    Write32(0); // extrefsymoff
    Write32(0); // nextrefsyms
    Write32(IndirectSymbolOffset);
    Write32(NumIndirectSymbols);
    Write32(0); // extreloff
    Write32(0); // nextrel
    Write32(0); // locreloff
    Write32(0); // nlocrel

    assert(OS.tell() - Start == DysymtabLoadCommandSize);
  }

  void WriteNlist(MachSymbolData &MSD) {
    MCSymbolData &Data = *MSD.SymbolData;
    const MCSymbol &Symbol = Data.getSymbol();
    uint8_t Type = 0;
    uint16_t Flags = Data.getFlags();
    uint32_t Address = 0;

    // Set the N_TYPE bits. See <mach-o/nlist.h>.
    //
    // FIXME: Are the prebound or indirect fields possible here?
    if (Symbol.isUndefined())
      Type = STT_Undefined;
    else if (Symbol.isAbsolute())
      Type = STT_Absolute;
    else
      Type = STT_Section;

    // FIXME: Set STAB bits.

    if (Data.isPrivateExtern())
      Type |= STF_PrivateExtern;

    // Set external bit.
    if (Data.isExternal() || Symbol.isUndefined())
      Type |= STF_External;

    // Compute the symbol address.
    if (Symbol.isDefined()) {
      if (Symbol.isAbsolute()) {
        llvm_unreachable("FIXME: Not yet implemented!");
      } else {
        Address = Data.getAddress();
      }
    } else if (Data.isCommon()) {
      // Common symbols are encoded with the size in the address
      // field, and their alignment in the flags.
      Address = Data.getCommonSize();

      // Common alignment is packed into the 'desc' bits.
      if (unsigned Align = Data.getCommonAlignment()) {
        unsigned Log2Size = Log2_32(Align);
        assert((1U << Log2Size) == Align && "Invalid 'common' alignment!");
        if (Log2Size > 15)
          llvm_report_error("invalid 'common' alignment '" +
                            Twine(Align) + "'");
        // FIXME: Keep this mask with the SymbolFlags enumeration.
        Flags = (Flags & 0xF0FF) | (Log2Size << 8);
      }
    }

    // struct nlist (12 bytes)

    Write32(MSD.StringIndex);
    Write8(Type);
    Write8(MSD.SectionIndex);

    // The Mach-O streamer uses the lowest 16-bits of the flags for the 'desc'
    // value.
    Write16(Flags);
    if (Is64Bit)
      Write64(Address);
    else
      Write32(Address);
  }

  void RecordScatteredRelocation(const MCAssembler &Asm,
                                 const MCFragment &Fragment,
                                 const MCAsmFixup &Fixup, MCValue Target,
                                 uint64_t &FixedValue) {
    uint32_t Address = Fragment.getOffset() + Fixup.Offset;
    unsigned IsPCRel = isFixupKindPCRel(Fixup.Kind);
    unsigned Log2Size = getFixupKindLog2Size(Fixup.Kind);
    unsigned Type = RIT_Vanilla;

    // See <reloc.h>.
    const MCSymbol *A = &Target.getSymA()->getSymbol();
    MCSymbolData *A_SD = &Asm.getSymbolData(*A);

    if (!A_SD->getFragment())
      llvm_report_error("symbol '" + A->getName() +
                        "' can not be undefined in a subtraction expression");

    uint32_t Value = A_SD->getAddress();
    uint32_t Value2 = 0;

    if (const MCSymbolRefExpr *B = Target.getSymB()) {
      MCSymbolData *B_SD = &Asm.getSymbolData(B->getSymbol());

      if (!B_SD->getFragment())
        llvm_report_error("symbol '" + B->getSymbol().getName() +
                          "' can not be undefined in a subtraction expression");

      // Select the appropriate difference relocation type.
      //
      // Note that there is no longer any semantic difference between these two
      // relocation types from the linkers point of view, this is done solely
      // for pedantic compatibility with 'as'.
      Type = A_SD->isExternal() ? RIT_Difference : RIT_LocalDifference;
      Value2 = B_SD->getAddress();
    }

    // Relocations are written out in reverse order, so the PAIR comes first.
    if (Type == RIT_Difference || Type == RIT_LocalDifference) {
      MachRelocationEntry MRE;
      MRE.Word0 = ((0         <<  0) |
                   (RIT_Pair  << 24) |
                   (Log2Size  << 28) |
                   (IsPCRel   << 30) |
                   RF_Scattered);
      MRE.Word1 = Value2;
      Relocations[Fragment.getParent()].push_back(MRE);
    }

    MachRelocationEntry MRE;
    MRE.Word0 = ((Address   <<  0) |
                 (Type      << 24) |
                 (Log2Size  << 28) |
                 (IsPCRel   << 30) |
                 RF_Scattered);
    MRE.Word1 = Value;
    Relocations[Fragment.getParent()].push_back(MRE);
  }

  virtual void RecordRelocation(const MCAssembler &Asm,
                                const MCDataFragment &Fragment,
                                const MCAsmFixup &Fixup, MCValue Target,
                                uint64_t &FixedValue) {
    unsigned IsPCRel = isFixupKindPCRel(Fixup.Kind);
    unsigned Log2Size = getFixupKindLog2Size(Fixup.Kind);

    // If this is a difference or a defined symbol plus an offset, then we need
    // a scattered relocation entry.
    uint32_t Offset = Target.getConstant();
    if (IsPCRel)
      Offset += 1 << Log2Size;
    if (Target.getSymB() ||
        (Target.getSymA() && !Target.getSymA()->getSymbol().isUndefined() &&
         Offset)) {
      RecordScatteredRelocation(Asm, Fragment, Fixup, Target, FixedValue);
      return;
    }

    // See <reloc.h>.
    uint32_t Address = Fragment.getOffset() + Fixup.Offset;
    uint32_t Value = 0;
    unsigned Index = 0;
    unsigned IsExtern = 0;
    unsigned Type = 0;

    if (Target.isAbsolute()) { // constant
      // SymbolNum of 0 indicates the absolute section.
      //
      // FIXME: Currently, these are never generated (see code below). I cannot
      // find a case where they are actually emitted.
      Type = RIT_Vanilla;
      Value = 0;
    } else {
      const MCSymbol *Symbol = &Target.getSymA()->getSymbol();
      MCSymbolData *SD = &Asm.getSymbolData(*Symbol);

      if (Symbol->isUndefined()) {
        IsExtern = 1;
        Index = SD->getIndex();
        Value = 0;
      } else {
        // The index is the section ordinal.
        //
        // FIXME: O(N)
        Index = 1;
        MCAssembler::const_iterator it = Asm.begin(), ie = Asm.end();
        for (; it != ie; ++it, ++Index)
          if (&*it == SD->getFragment()->getParent())
            break;
        assert(it != ie && "Unable to find section index!");
        Value = SD->getAddress();
      }

      Type = RIT_Vanilla;
    }

    // struct relocation_info (8 bytes)
    MachRelocationEntry MRE;
    MRE.Word0 = Address;
    MRE.Word1 = ((Index     <<  0) |
                 (IsPCRel   << 24) |
                 (Log2Size  << 25) |
                 (IsExtern  << 27) |
                 (Type      << 28));
    Relocations[Fragment.getParent()].push_back(MRE);
  }

  void BindIndirectSymbols(MCAssembler &Asm) {
    // This is the point where 'as' creates actual symbols for indirect symbols
    // (in the following two passes). It would be easier for us to do this
    // sooner when we see the attribute, but that makes getting the order in the
    // symbol table much more complicated than it is worth.
    //
    // FIXME: Revisit this when the dust settles.

    // Bind non lazy symbol pointers first.
    for (MCAssembler::indirect_symbol_iterator it = Asm.indirect_symbol_begin(),
           ie = Asm.indirect_symbol_end(); it != ie; ++it) {
      // FIXME: cast<> support!
      const MCSectionMachO &Section =
        static_cast<const MCSectionMachO&>(it->SectionData->getSection());

      if (Section.getType() != MCSectionMachO::S_NON_LAZY_SYMBOL_POINTERS)
        continue;

      Asm.getOrCreateSymbolData(*it->Symbol);
    }

    // Then lazy symbol pointers and symbol stubs.
    for (MCAssembler::indirect_symbol_iterator it = Asm.indirect_symbol_begin(),
           ie = Asm.indirect_symbol_end(); it != ie; ++it) {
      // FIXME: cast<> support!
      const MCSectionMachO &Section =
        static_cast<const MCSectionMachO&>(it->SectionData->getSection());

      if (Section.getType() != MCSectionMachO::S_LAZY_SYMBOL_POINTERS &&
          Section.getType() != MCSectionMachO::S_SYMBOL_STUBS)
        continue;

      // Set the symbol type to undefined lazy, but only on construction.
      //
      // FIXME: Do not hardcode.
      bool Created;
      MCSymbolData &Entry = Asm.getOrCreateSymbolData(*it->Symbol, &Created);
      if (Created)
        Entry.setFlags(Entry.getFlags() | 0x0001);
    }
  }

  /// ComputeSymbolTable - Compute the symbol table data
  ///
  /// \param StringTable [out] - The string table data.
  /// \param StringIndexMap [out] - Map from symbol names to offsets in the
  /// string table.
  void ComputeSymbolTable(MCAssembler &Asm, SmallString<256> &StringTable,
                          std::vector<MachSymbolData> &LocalSymbolData,
                          std::vector<MachSymbolData> &ExternalSymbolData,
                          std::vector<MachSymbolData> &UndefinedSymbolData) {
    // Build section lookup table.
    DenseMap<const MCSection*, uint8_t> SectionIndexMap;
    unsigned Index = 1;
    for (MCAssembler::iterator it = Asm.begin(),
           ie = Asm.end(); it != ie; ++it, ++Index)
      SectionIndexMap[&it->getSection()] = Index;
    assert(Index <= 256 && "Too many sections!");

    // Index 0 is always the empty string.
    StringMap<uint64_t> StringIndexMap;
    StringTable += '\x00';

    // Build the symbol arrays and the string table, but only for non-local
    // symbols.
    //
    // The particular order that we collect the symbols and create the string
    // table, then sort the symbols is chosen to match 'as'. Even though it
    // doesn't matter for correctness, this is important for letting us diff .o
    // files.
    for (MCAssembler::symbol_iterator it = Asm.symbol_begin(),
           ie = Asm.symbol_end(); it != ie; ++it) {
      const MCSymbol &Symbol = it->getSymbol();

      // Ignore non-linker visible symbols.
      if (!Asm.isSymbolLinkerVisible(it))
        continue;

      if (!it->isExternal() && !Symbol.isUndefined())
        continue;

      uint64_t &Entry = StringIndexMap[Symbol.getName()];
      if (!Entry) {
        Entry = StringTable.size();
        StringTable += Symbol.getName();
        StringTable += '\x00';
      }

      MachSymbolData MSD;
      MSD.SymbolData = it;
      MSD.StringIndex = Entry;

      if (Symbol.isUndefined()) {
        MSD.SectionIndex = 0;
        UndefinedSymbolData.push_back(MSD);
      } else if (Symbol.isAbsolute()) {
        MSD.SectionIndex = 0;
        ExternalSymbolData.push_back(MSD);
      } else {
        MSD.SectionIndex = SectionIndexMap.lookup(&Symbol.getSection());
        assert(MSD.SectionIndex && "Invalid section index!");
        ExternalSymbolData.push_back(MSD);
      }
    }

    // Now add the data for local symbols.
    for (MCAssembler::symbol_iterator it = Asm.symbol_begin(),
           ie = Asm.symbol_end(); it != ie; ++it) {
      const MCSymbol &Symbol = it->getSymbol();

      // Ignore non-linker visible symbols.
      if (!Asm.isSymbolLinkerVisible(it))
        continue;

      if (it->isExternal() || Symbol.isUndefined())
        continue;

      uint64_t &Entry = StringIndexMap[Symbol.getName()];
      if (!Entry) {
        Entry = StringTable.size();
        StringTable += Symbol.getName();
        StringTable += '\x00';
      }

      MachSymbolData MSD;
      MSD.SymbolData = it;
      MSD.StringIndex = Entry;

      if (Symbol.isAbsolute()) {
        MSD.SectionIndex = 0;
        LocalSymbolData.push_back(MSD);
      } else {
        MSD.SectionIndex = SectionIndexMap.lookup(&Symbol.getSection());
        assert(MSD.SectionIndex && "Invalid section index!");
        LocalSymbolData.push_back(MSD);
      }
    }

    // External and undefined symbols are required to be in lexicographic order.
    std::sort(ExternalSymbolData.begin(), ExternalSymbolData.end());
    std::sort(UndefinedSymbolData.begin(), UndefinedSymbolData.end());

    // Set the symbol indices.
    Index = 0;
    for (unsigned i = 0, e = LocalSymbolData.size(); i != e; ++i)
      LocalSymbolData[i].SymbolData->setIndex(Index++);
    for (unsigned i = 0, e = ExternalSymbolData.size(); i != e; ++i)
      ExternalSymbolData[i].SymbolData->setIndex(Index++);
    for (unsigned i = 0, e = UndefinedSymbolData.size(); i != e; ++i)
      UndefinedSymbolData[i].SymbolData->setIndex(Index++);

    // The string table is padded to a multiple of 4.
    while (StringTable.size() % 4)
      StringTable += '\x00';
  }

  virtual void ExecutePostLayoutBinding(MCAssembler &Asm) {
    // Create symbol data for any indirect symbols.
    BindIndirectSymbols(Asm);

    // Compute symbol table information and bind symbol indices.
    ComputeSymbolTable(Asm, StringTable, LocalSymbolData, ExternalSymbolData,
                       UndefinedSymbolData);
  }

  virtual void WriteObject(const MCAssembler &Asm) {
    unsigned NumSections = Asm.size();

    // The section data starts after the header, the segment load command (and
    // section headers) and the symbol table.
    unsigned NumLoadCommands = 1;
    uint64_t LoadCommandsSize = Is64Bit ?
      SegmentLoadCommand64Size + NumSections * Section64Size :
      SegmentLoadCommand32Size + NumSections * Section32Size;

    // Add the symbol table load command sizes, if used.
    unsigned NumSymbols = LocalSymbolData.size() + ExternalSymbolData.size() +
      UndefinedSymbolData.size();
    if (NumSymbols) {
      NumLoadCommands += 2;
      LoadCommandsSize += SymtabLoadCommandSize + DysymtabLoadCommandSize;
    }

    // Compute the total size of the section data, as well as its file size and
    // vm size.
    uint64_t SectionDataStart = (Is64Bit ? Header64Size : Header32Size)
      + LoadCommandsSize;
    uint64_t SectionDataSize = 0;
    uint64_t SectionDataFileSize = 0;
    uint64_t VMSize = 0;
    for (MCAssembler::const_iterator it = Asm.begin(),
           ie = Asm.end(); it != ie; ++it) {
      const MCSectionData &SD = *it;

      VMSize = std::max(VMSize, SD.getAddress() + SD.getSize());

      if (Asm.getBackend().isVirtualSection(SD.getSection()))
        continue;

      SectionDataSize = std::max(SectionDataSize,
                                 SD.getAddress() + SD.getSize());
      SectionDataFileSize = std::max(SectionDataFileSize,
                                     SD.getAddress() + SD.getFileSize());
    }

    // The section data is padded to 4 bytes.
    //
    // FIXME: Is this machine dependent?
    unsigned SectionDataPadding = OffsetToAlignment(SectionDataFileSize, 4);
    SectionDataFileSize += SectionDataPadding;

    // Write the prolog, starting with the header and load command...
    WriteHeader(NumLoadCommands, LoadCommandsSize,
                Asm.getSubsectionsViaSymbols());
    WriteSegmentLoadCommand(NumSections, VMSize,
                            SectionDataStart, SectionDataSize);

    // ... and then the section headers.
    uint64_t RelocTableEnd = SectionDataStart + SectionDataFileSize;
    for (MCAssembler::const_iterator it = Asm.begin(),
           ie = Asm.end(); it != ie; ++it) {
      std::vector<MachRelocationEntry> &Relocs = Relocations[it];
      unsigned NumRelocs = Relocs.size();
      uint64_t SectionStart = SectionDataStart + it->getAddress();
      WriteSection(Asm, *it, SectionStart, RelocTableEnd, NumRelocs);
      RelocTableEnd += NumRelocs * RelocationInfoSize;
    }

    // Write the symbol table load command, if used.
    if (NumSymbols) {
      unsigned FirstLocalSymbol = 0;
      unsigned NumLocalSymbols = LocalSymbolData.size();
      unsigned FirstExternalSymbol = FirstLocalSymbol + NumLocalSymbols;
      unsigned NumExternalSymbols = ExternalSymbolData.size();
      unsigned FirstUndefinedSymbol = FirstExternalSymbol + NumExternalSymbols;
      unsigned NumUndefinedSymbols = UndefinedSymbolData.size();
      unsigned NumIndirectSymbols = Asm.indirect_symbol_size();
      unsigned NumSymTabSymbols =
        NumLocalSymbols + NumExternalSymbols + NumUndefinedSymbols;
      uint64_t IndirectSymbolSize = NumIndirectSymbols * 4;
      uint64_t IndirectSymbolOffset = 0;

      // If used, the indirect symbols are written after the section data.
      if (NumIndirectSymbols)
        IndirectSymbolOffset = RelocTableEnd;

      // The symbol table is written after the indirect symbol data.
      uint64_t SymbolTableOffset = RelocTableEnd + IndirectSymbolSize;

      // The string table is written after symbol table.
      uint64_t StringTableOffset =
        SymbolTableOffset + NumSymTabSymbols * (Is64Bit ? Nlist64Size :
                                                Nlist32Size);
      WriteSymtabLoadCommand(SymbolTableOffset, NumSymTabSymbols,
                             StringTableOffset, StringTable.size());

      WriteDysymtabLoadCommand(FirstLocalSymbol, NumLocalSymbols,
                               FirstExternalSymbol, NumExternalSymbols,
                               FirstUndefinedSymbol, NumUndefinedSymbols,
                               IndirectSymbolOffset, NumIndirectSymbols);
    }

    // Write the actual section data.
    for (MCAssembler::const_iterator it = Asm.begin(),
           ie = Asm.end(); it != ie; ++it)
      Asm.WriteSectionData(it, this);

    // Write the extra padding.
    WriteZeros(SectionDataPadding);

    // Write the relocation entries.
    for (MCAssembler::const_iterator it = Asm.begin(),
           ie = Asm.end(); it != ie; ++it) {
      // Write the section relocation entries, in reverse order to match 'as'
      // (approximately, the exact algorithm is more complicated than this).
      std::vector<MachRelocationEntry> &Relocs = Relocations[it];
      for (unsigned i = 0, e = Relocs.size(); i != e; ++i) {
        Write32(Relocs[e - i - 1].Word0);
        Write32(Relocs[e - i - 1].Word1);
      }
    }

    // Write the symbol table data, if used.
    if (NumSymbols) {
      // Write the indirect symbol entries.
      for (MCAssembler::const_indirect_symbol_iterator
             it = Asm.indirect_symbol_begin(),
             ie = Asm.indirect_symbol_end(); it != ie; ++it) {
        // Indirect symbols in the non lazy symbol pointer section have some
        // special handling.
        const MCSectionMachO &Section =
          static_cast<const MCSectionMachO&>(it->SectionData->getSection());
        if (Section.getType() == MCSectionMachO::S_NON_LAZY_SYMBOL_POINTERS) {
          // If this symbol is defined and internal, mark it as such.
          if (it->Symbol->isDefined() &&
              !Asm.getSymbolData(*it->Symbol).isExternal()) {
            uint32_t Flags = ISF_Local;
            if (it->Symbol->isAbsolute())
              Flags |= ISF_Absolute;
            Write32(Flags);
            continue;
          }
        }

        Write32(Asm.getSymbolData(*it->Symbol).getIndex());
      }

      // FIXME: Check that offsets match computed ones.

      // Write the symbol table entries.
      for (unsigned i = 0, e = LocalSymbolData.size(); i != e; ++i)
        WriteNlist(LocalSymbolData[i]);
      for (unsigned i = 0, e = ExternalSymbolData.size(); i != e; ++i)
        WriteNlist(ExternalSymbolData[i]);
      for (unsigned i = 0, e = UndefinedSymbolData.size(); i != e; ++i)
        WriteNlist(UndefinedSymbolData[i]);

      // Write the string table.
      OS << StringTable.str();
    }
  }
};

/* *** */

MCFragment::MCFragment() : Kind(FragmentType(~0)) {
}

MCFragment::MCFragment(FragmentType _Kind, MCSectionData *_Parent)
  : Kind(_Kind),
    Parent(_Parent),
    FileSize(~UINT64_C(0))
{
  if (Parent)
    Parent->getFragmentList().push_back(this);
}

MCFragment::~MCFragment() {
}

uint64_t MCFragment::getAddress() const {
  assert(getParent() && "Missing Section!");
  return getParent()->getAddress() + Offset;
}

/* *** */

MCSectionData::MCSectionData() : Section(0) {}

MCSectionData::MCSectionData(const MCSection &_Section, MCAssembler *A)
  : Section(&_Section),
    Alignment(1),
    Address(~UINT64_C(0)),
    Size(~UINT64_C(0)),
    FileSize(~UINT64_C(0)),
    HasInstructions(false)
{
  if (A)
    A->getSectionList().push_back(this);
}

/* *** */

MCSymbolData::MCSymbolData() : Symbol(0) {}

MCSymbolData::MCSymbolData(const MCSymbol &_Symbol, MCFragment *_Fragment,
                           uint64_t _Offset, MCAssembler *A)
  : Symbol(&_Symbol), Fragment(_Fragment), Offset(_Offset),
    IsExternal(false), IsPrivateExtern(false),
    CommonSize(0), CommonAlign(0), Flags(0), Index(0)
{
  if (A)
    A->getSymbolList().push_back(this);
}

/* *** */

MCAssembler::MCAssembler(MCContext &_Context, TargetAsmBackend &_Backend,
                         raw_ostream &_OS)
  : Context(_Context), Backend(_Backend), OS(_OS), SubsectionsViaSymbols(false)
{
}

MCAssembler::~MCAssembler() {
}

static bool isScatteredFixupFullyResolvedSimple(const MCAssembler &Asm,
                                                const MCAsmFixup &Fixup,
                                                const MCDataFragment *DF,
                                                const MCValue Target,
                                                const MCSection *BaseSection) {
  // The effective fixup address is
  //     addr(atom(A)) + offset(A)
  //   - addr(atom(B)) - offset(B)
  //   - addr(<base symbol>) + <fixup offset from base symbol>
  // and the offsets are not relocatable, so the fixup is fully resolved when
  //  addr(atom(A)) - addr(atom(B)) - addr(<base symbol>)) == 0.
  //
  // The simple (Darwin, except on x86_64) way of dealing with this was to
  // assume that any reference to a temporary symbol *must* be a temporary
  // symbol in the same atom, unless the sections differ. Therefore, any PCrel
  // relocation to a temporary symbol (in the same section) is fully
  // resolved. This also works in conjunction with absolutized .set, which
  // requires the compiler to use .set to absolutize the differences between
  // symbols which the compiler knows to be assembly time constants, so we don't
  // need to worry about consider symbol differences fully resolved.

  // Non-relative fixups are only resolved if constant.
  if (!BaseSection)
    return Target.isAbsolute();

  // Otherwise, relative fixups are only resolved if not a difference and the
  // target is a temporary in the same section.
  if (Target.isAbsolute() || Target.getSymB())
    return false;

  const MCSymbol *A = &Target.getSymA()->getSymbol();
  if (!A->isTemporary() || !A->isInSection() ||
      &A->getSection() != BaseSection)
    return false;

  return true;
}

static bool isScatteredFixupFullyResolved(const MCAssembler &Asm,
                                          const MCAsmFixup &Fixup,
                                          const MCDataFragment *DF,
                                          const MCValue Target,
                                          const MCSymbolData *BaseSymbol) {
  // The effective fixup address is
  //     addr(atom(A)) + offset(A)
  //   - addr(atom(B)) - offset(B)
  //   - addr(BaseSymbol) + <fixup offset from base symbol>
  // and the offsets are not relocatable, so the fixup is fully resolved when
  //  addr(atom(A)) - addr(atom(B)) - addr(BaseSymbol) == 0.
  //
  // Note that "false" is almost always conservatively correct (it means we emit
  // a relocation which is unnecessary), except when it would force us to emit a
  // relocation which the target cannot encode.

  const MCSymbolData *A_Base = 0, *B_Base = 0;
  if (const MCSymbolRefExpr *A = Target.getSymA()) {
    // Modified symbol references cannot be resolved.
    if (A->getKind() != MCSymbolRefExpr::VK_None)
      return false;

    A_Base = Asm.getAtom(&Asm.getSymbolData(A->getSymbol()));
    if (!A_Base)
      return false;
  }

  if (const MCSymbolRefExpr *B = Target.getSymB()) {
    // Modified symbol references cannot be resolved.
    if (B->getKind() != MCSymbolRefExpr::VK_None)
      return false;

    B_Base = Asm.getAtom(&Asm.getSymbolData(B->getSymbol()));
    if (!B_Base)
      return false;
  }

  // If there is no base, A and B have to be the same atom for this fixup to be
  // fully resolved.
  if (!BaseSymbol)
    return A_Base == B_Base;

  // Otherwise, B must be missing and A must be the base.
  return !B_Base && BaseSymbol == A_Base;
}

bool MCAssembler::isSymbolLinkerVisible(const MCSymbolData *SD) const {
  // Non-temporary labels should always be visible to the linker.
  if (!SD->getSymbol().isTemporary())
    return true;

  // Absolute temporary labels are never visible.
  if (!SD->getFragment())
    return false;

  // Otherwise, check if the section requires symbols even for temporary labels.
  return getBackend().doesSectionRequireSymbols(
    SD->getFragment()->getParent()->getSection());
}

const MCSymbolData *MCAssembler::getAtomForAddress(const MCSectionData *Section,
                                                   uint64_t Address) const {
  const MCSymbolData *Best = 0;
  for (MCAssembler::const_symbol_iterator it = symbol_begin(),
         ie = symbol_end(); it != ie; ++it) {
    // Ignore non-linker visible symbols.
    if (!isSymbolLinkerVisible(it))
      continue;

    // Ignore symbols not in the same section.
    if (!it->getFragment() || it->getFragment()->getParent() != Section)
      continue;

    // Otherwise, find the closest symbol preceding this address (ties are
    // resolved in favor of the last defined symbol).
    if (it->getAddress() <= Address &&
        (!Best || it->getAddress() >= Best->getAddress()))
      Best = it;
  }

  return Best;
}

const MCSymbolData *MCAssembler::getAtom(const MCSymbolData *SD) const {
  // Linker visible symbols define atoms.
  if (isSymbolLinkerVisible(SD))
    return SD;

  // Absolute and undefined symbols have no defining atom.
  if (!SD->getFragment())
    return 0;

  // Otherwise, search by address.
  return getAtomForAddress(SD->getFragment()->getParent(), SD->getAddress());
}

bool MCAssembler::EvaluateFixup(const MCAsmLayout &Layout, MCAsmFixup &Fixup,
                                MCDataFragment *DF,
                                MCValue &Target, uint64_t &Value) const {
  if (!Fixup.Value->EvaluateAsRelocatable(Target, &Layout))
    llvm_report_error("expected relocatable expression");

  // FIXME: How do non-scattered symbols work in ELF? I presume the linker
  // doesn't support small relocations, but then under what criteria does the
  // assembler allow symbol differences?

  Value = Target.getConstant();

  bool IsResolved = true, IsPCRel = isFixupKindPCRel(Fixup.Kind);
  if (const MCSymbolRefExpr *A = Target.getSymA()) {
    if (A->getSymbol().isDefined())
      Value += getSymbolData(A->getSymbol()).getAddress();
    else
      IsResolved = false;
  }
  if (const MCSymbolRefExpr *B = Target.getSymB()) {
    if (B->getSymbol().isDefined())
      Value -= getSymbolData(B->getSymbol()).getAddress();
    else
      IsResolved = false;
  }

  // If we are using scattered symbols, determine whether this value is actually
  // resolved; scattering may cause atoms to move.
  if (IsResolved && getBackend().hasScatteredSymbols()) {
    if (getBackend().hasReliableSymbolDifference()) {
      // If this is a PCrel relocation, find the base atom (identified by its
      // symbol) that the fixup value is relative to.
      const MCSymbolData *BaseSymbol = 0;
      if (IsPCRel) {
        BaseSymbol = getAtomForAddress(
          DF->getParent(), DF->getAddress() + Fixup.Offset);
        if (!BaseSymbol)
          IsResolved = false;
      }

      if (IsResolved)
        IsResolved = isScatteredFixupFullyResolved(*this, Fixup, DF, Target,
                                                   BaseSymbol);
    } else {
      const MCSection *BaseSection = 0;
      if (IsPCRel)
        BaseSection = &DF->getParent()->getSection();

      IsResolved = isScatteredFixupFullyResolvedSimple(*this, Fixup, DF, Target,
                                                       BaseSection);
    }
  }

  if (IsPCRel)
    Value -= DF->getAddress() + Fixup.Offset;

  return IsResolved;
}

void MCAssembler::LayoutSection(MCSectionData &SD) {
  MCAsmLayout Layout(*this);
  uint64_t Address = SD.getAddress();

  for (MCSectionData::iterator it = SD.begin(), ie = SD.end(); it != ie; ++it) {
    MCFragment &F = *it;

    F.setOffset(Address - SD.getAddress());

    // Evaluate fragment size.
    switch (F.getKind()) {
    case MCFragment::FT_Align: {
      MCAlignFragment &AF = cast<MCAlignFragment>(F);

      uint64_t Size = OffsetToAlignment(Address, AF.getAlignment());
      if (Size > AF.getMaxBytesToEmit())
        AF.setFileSize(0);
      else
        AF.setFileSize(Size);
      break;
    }

    case MCFragment::FT_Data:
    case MCFragment::FT_Fill:
      F.setFileSize(F.getMaxFileSize());
      break;

    case MCFragment::FT_Org: {
      MCOrgFragment &OF = cast<MCOrgFragment>(F);

      int64_t TargetLocation;
      if (!OF.getOffset().EvaluateAsAbsolute(TargetLocation, &Layout))
        llvm_report_error("expected assembly-time absolute expression");

      // FIXME: We need a way to communicate this error.
      int64_t Offset = TargetLocation - F.getOffset();
      if (Offset < 0)
        llvm_report_error("invalid .org offset '" + Twine(TargetLocation) +
                          "' (at offset '" + Twine(F.getOffset()) + "'");

      F.setFileSize(Offset);
      break;
    }

    case MCFragment::FT_ZeroFill: {
      MCZeroFillFragment &ZFF = cast<MCZeroFillFragment>(F);

      // Align the fragment offset; it is safe to adjust the offset freely since
      // this is only in virtual sections.
      Address = RoundUpToAlignment(Address, ZFF.getAlignment());
      F.setOffset(Address - SD.getAddress());

      // FIXME: This is misnamed.
      F.setFileSize(ZFF.getSize());
      break;
    }
    }

    Address += F.getFileSize();
  }

  // Set the section sizes.
  SD.setSize(Address - SD.getAddress());
  if (getBackend().isVirtualSection(SD.getSection()))
    SD.setFileSize(0);
  else
    SD.setFileSize(Address - SD.getAddress());
}

/// WriteNopData - Write optimal nops to the output file for the \arg Count
/// bytes.  This returns the number of bytes written.  It may return 0 if
/// the \arg Count is more than the maximum optimal nops.
///
/// FIXME this is X86 32-bit specific and should move to a better place.
static uint64_t WriteNopData(uint64_t Count, MCObjectWriter *OW) {
  static const uint8_t Nops[16][16] = {
    // nop
    {0x90},
    // xchg %ax,%ax
    {0x66, 0x90},
    // nopl (%[re]ax)
    {0x0f, 0x1f, 0x00},
    // nopl 0(%[re]ax)
    {0x0f, 0x1f, 0x40, 0x00},
    // nopl 0(%[re]ax,%[re]ax,1)
    {0x0f, 0x1f, 0x44, 0x00, 0x00},
    // nopw 0(%[re]ax,%[re]ax,1)
    {0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00},
    // nopl 0L(%[re]ax)
    {0x0f, 0x1f, 0x80, 0x00, 0x00, 0x00, 0x00},
    // nopl 0L(%[re]ax,%[re]ax,1)
    {0x0f, 0x1f, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00},
    // nopw 0L(%[re]ax,%[re]ax,1)
    {0x66, 0x0f, 0x1f, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00},
    // nopw %cs:0L(%[re]ax,%[re]ax,1)
    {0x66, 0x2e, 0x0f, 0x1f, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00},
    // nopl 0(%[re]ax,%[re]ax,1)
    // nopw 0(%[re]ax,%[re]ax,1)
    {0x0f, 0x1f, 0x44, 0x00, 0x00,
     0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00},
    // nopw 0(%[re]ax,%[re]ax,1)
    // nopw 0(%[re]ax,%[re]ax,1)
    {0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00,
     0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00},
    // nopw 0(%[re]ax,%[re]ax,1)
    // nopl 0L(%[re]ax) */
    {0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00,
     0x0f, 0x1f, 0x80, 0x00, 0x00, 0x00, 0x00},
    // nopl 0L(%[re]ax)
    // nopl 0L(%[re]ax)
    {0x0f, 0x1f, 0x80, 0x00, 0x00, 0x00, 0x00,
     0x0f, 0x1f, 0x80, 0x00, 0x00, 0x00, 0x00},
    // nopl 0L(%[re]ax)
    // nopl 0L(%[re]ax,%[re]ax,1)
    {0x0f, 0x1f, 0x80, 0x00, 0x00, 0x00, 0x00,
     0x0f, 0x1f, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00}
  };

  if (Count > 15)
    return 0;

  for (uint64_t i = 0; i < Count; i++)
    OW->Write8(uint8_t(Nops[Count - 1][i]));

  return Count;
}

/// WriteFragmentData - Write the \arg F data to the output file.
static void WriteFragmentData(const MCFragment &F, MCObjectWriter *OW) {
  uint64_t Start = OW->getStream().tell();
  (void) Start;

  ++EmittedFragments;

  // FIXME: Embed in fragments instead?
  switch (F.getKind()) {
  case MCFragment::FT_Align: {
    MCAlignFragment &AF = cast<MCAlignFragment>(F);
    uint64_t Count = AF.getFileSize() / AF.getValueSize();

    // FIXME: This error shouldn't actually occur (the front end should emit
    // multiple .align directives to enforce the semantics it wants), but is
    // severe enough that we want to report it. How to handle this?
    if (Count * AF.getValueSize() != AF.getFileSize())
      llvm_report_error("undefined .align directive, value size '" +
                        Twine(AF.getValueSize()) +
                        "' is not a divisor of padding size '" +
                        Twine(AF.getFileSize()) + "'");

    // See if we are aligning with nops, and if so do that first to try to fill
    // the Count bytes.  Then if that did not fill any bytes or there are any
    // bytes left to fill use the the Value and ValueSize to fill the rest.
    if (AF.getEmitNops()) {
      uint64_t NopByteCount = WriteNopData(Count, OW);
      Count -= NopByteCount;
    }

    for (uint64_t i = 0; i != Count; ++i) {
      switch (AF.getValueSize()) {
      default:
        assert(0 && "Invalid size!");
      case 1: OW->Write8 (uint8_t (AF.getValue())); break;
      case 2: OW->Write16(uint16_t(AF.getValue())); break;
      case 4: OW->Write32(uint32_t(AF.getValue())); break;
      case 8: OW->Write64(uint64_t(AF.getValue())); break;
      }
    }
    break;
  }

  case MCFragment::FT_Data: {
    OW->WriteBytes(cast<MCDataFragment>(F).getContents().str());
    break;
  }

  case MCFragment::FT_Fill: {
    MCFillFragment &FF = cast<MCFillFragment>(F);
    for (uint64_t i = 0, e = FF.getCount(); i != e; ++i) {
      switch (FF.getValueSize()) {
      default:
        assert(0 && "Invalid size!");
      case 1: OW->Write8 (uint8_t (FF.getValue())); break;
      case 2: OW->Write16(uint16_t(FF.getValue())); break;
      case 4: OW->Write32(uint32_t(FF.getValue())); break;
      case 8: OW->Write64(uint64_t(FF.getValue())); break;
      }
    }
    break;
  }

  case MCFragment::FT_Org: {
    MCOrgFragment &OF = cast<MCOrgFragment>(F);

    for (uint64_t i = 0, e = OF.getFileSize(); i != e; ++i)
      OW->Write8(uint8_t(OF.getValue()));

    break;
  }

  case MCFragment::FT_ZeroFill: {
    assert(0 && "Invalid zero fill fragment in concrete section!");
    break;
  }
  }

  assert(OW->getStream().tell() - Start == F.getFileSize());
}

void MCAssembler::WriteSectionData(const MCSectionData *SD,
                                   MCObjectWriter *OW) const {
  // Ignore virtual sections.
  if (getBackend().isVirtualSection(SD->getSection())) {
    assert(SD->getFileSize() == 0);
    return;
  }

  uint64_t Start = OW->getStream().tell();
  (void) Start;

  for (MCSectionData::const_iterator it = SD->begin(),
         ie = SD->end(); it != ie; ++it)
    WriteFragmentData(*it, OW);

  // Add section padding.
  assert(SD->getFileSize() >= SD->getSize() && "Invalid section sizes!");
  OW->WriteZeros(SD->getFileSize() - SD->getSize());

  assert(OW->getStream().tell() - Start == SD->getFileSize());
}

void MCAssembler::Finish() {
  DEBUG_WITH_TYPE("mc-dump", {
      llvm::errs() << "assembler backend - pre-layout\n--\n";
      dump(); });

  // Layout until everything fits.
  while (LayoutOnce())
    continue;

  DEBUG_WITH_TYPE("mc-dump", {
      llvm::errs() << "assembler backend - post-layout\n--\n";
      dump(); });

  // FIXME: Factor out MCObjectWriter.
  bool Is64Bit = StringRef(getBackend().getTarget().getName()) == "x86-64";
  MachObjectWriter MOW(OS, Is64Bit);

  // Allow the object writer a chance to perform post-layout binding (for
  // example, to set the index fields in the symbol data).
  MOW.ExecutePostLayoutBinding(*this);

  // Evaluate and apply the fixups, generating relocation entries as necessary.
  //
  // FIXME: Share layout object.
  MCAsmLayout Layout(*this);
  for (MCAssembler::iterator it = begin(), ie = end(); it != ie; ++it) {
    for (MCSectionData::iterator it2 = it->begin(),
           ie2 = it->end(); it2 != ie2; ++it2) {
      MCDataFragment *DF = dyn_cast<MCDataFragment>(it2);
      if (!DF)
        continue;

      for (MCDataFragment::fixup_iterator it3 = DF->fixup_begin(),
             ie3 = DF->fixup_end(); it3 != ie3; ++it3) {
        MCAsmFixup &Fixup = *it3;

        // Evaluate the fixup.
        MCValue Target;
        uint64_t FixedValue;
        if (!EvaluateFixup(Layout, Fixup, DF, Target, FixedValue)) {
          // The fixup was unresolved, we need a relocation. Inform the object
          // writer of the relocation, and give it an opportunity to adjust the
          // fixup value if need be.
          MOW.RecordRelocation(*this, *DF, Fixup, Target, FixedValue);
        }

        getBackend().ApplyFixup(Fixup, *DF, FixedValue);
      }
    }
  }

  // Write the object file.
  MOW.WriteObject(*this);

  OS.flush();
}

bool MCAssembler::FixupNeedsRelaxation(MCAsmFixup &Fixup, MCDataFragment *DF) {
  // FIXME: Share layout object.
  MCAsmLayout Layout(*this);

  // Currently we only need to relax X86::reloc_pcrel_1byte.
  if (unsigned(Fixup.Kind) != X86::reloc_pcrel_1byte)
    return false;

  // If we cannot resolve the fixup value, it requires relaxation.
  MCValue Target;
  uint64_t Value;
  if (!EvaluateFixup(Layout, Fixup, DF, Target, Value))
    return true;

  // Otherwise, relax if the value is too big for a (signed) i8.
  return int64_t(Value) != int64_t(int8_t(Value));
}

bool MCAssembler::LayoutOnce() {
  // Layout the concrete sections and fragments.
  uint64_t Address = 0;
  MCSectionData *Prev = 0;
  for (iterator it = begin(), ie = end(); it != ie; ++it) {
    MCSectionData &SD = *it;

    // Skip virtual sections.
    if (getBackend().isVirtualSection(SD.getSection()))
      continue;

    // Align this section if necessary by adding padding bytes to the previous
    // section.
    if (uint64_t Pad = OffsetToAlignment(Address, it->getAlignment())) {
      assert(Prev && "Missing prev section!");
      Prev->setFileSize(Prev->getFileSize() + Pad);
      Address += Pad;
    }

    // Layout the section fragments and its size.
    SD.setAddress(Address);
    LayoutSection(SD);
    Address += SD.getFileSize();

    Prev = &SD;
  }

  // Layout the virtual sections.
  for (iterator it = begin(), ie = end(); it != ie; ++it) {
    MCSectionData &SD = *it;

    if (!getBackend().isVirtualSection(SD.getSection()))
      continue;

    // Align this section if necessary by adding padding bytes to the previous
    // section.
    if (uint64_t Pad = OffsetToAlignment(Address, it->getAlignment()))
      Address += Pad;

    SD.setAddress(Address);
    LayoutSection(SD);
    Address += SD.getSize();
  }

  // Scan the fixups in order and relax any that don't fit.
  for (iterator it = begin(), ie = end(); it != ie; ++it) {
    MCSectionData &SD = *it;

    for (MCSectionData::iterator it2 = SD.begin(),
           ie2 = SD.end(); it2 != ie2; ++it2) {
      MCDataFragment *DF = dyn_cast<MCDataFragment>(it2);
      if (!DF)
        continue;

      for (MCDataFragment::fixup_iterator it3 = DF->fixup_begin(),
             ie3 = DF->fixup_end(); it3 != ie3; ++it3) {
        MCAsmFixup &Fixup = *it3;

        // Check whether we need to relax this fixup.
        if (!FixupNeedsRelaxation(Fixup, DF))
          continue;

        // Relax the instruction.
        //
        // FIXME: This is a huge temporary hack which just looks for x86
        // branches; the only thing we need to relax on x86 is
        // 'X86::reloc_pcrel_1byte'. Once we have MCInst fragments, this will be
        // replaced by a TargetAsmBackend hook (most likely tblgen'd) to relax
        // an individual MCInst.
        SmallVectorImpl<char> &C = DF->getContents();
        uint64_t PrevOffset = Fixup.Offset;
        unsigned Amt = 0;

          // jcc instructions
        if (unsigned(C[Fixup.Offset-1]) >= 0x70 &&
            unsigned(C[Fixup.Offset-1]) <= 0x7f) {
          C[Fixup.Offset] = C[Fixup.Offset-1] + 0x10;
          C[Fixup.Offset-1] = char(0x0f);
          ++Fixup.Offset;
          Amt = 4;

          // jmp rel8
        } else if (C[Fixup.Offset-1] == char(0xeb)) {
          C[Fixup.Offset-1] = char(0xe9);
          Amt = 3;

        } else
          llvm_unreachable("unknown 1 byte pcrel instruction!");

        Fixup.Value = MCBinaryExpr::Create(
          MCBinaryExpr::Sub, Fixup.Value,
          MCConstantExpr::Create(3, getContext()),
          getContext());
        C.insert(C.begin() + Fixup.Offset, Amt, char(0));
        Fixup.Kind = MCFixupKind(X86::reloc_pcrel_4byte);

        // Update the remaining fixups, which have slid.
        //
        // FIXME: This is bad for performance, but will be eliminated by the
        // move to MCInst specific fragments.
        ++it3;
        for (; it3 != ie3; ++it3)
          it3->Offset += Amt;

        // Update all the symbols for this fragment, which may have slid.
        //
        // FIXME: This is really really bad for performance, but will be
        // eliminated by the move to MCInst specific fragments.
        for (MCAssembler::symbol_iterator it = symbol_begin(),
               ie = symbol_end(); it != ie; ++it) {
          MCSymbolData &SD = *it;

          if (it->getFragment() != DF)
            continue;

          if (SD.getOffset() > PrevOffset)
            SD.setOffset(SD.getOffset() + Amt);
        }

        // Restart layout.
        //
        // FIXME: This is O(N^2), but will be eliminated once we have a smart
        // MCAsmLayout object.
        return true;
      }
    }
  }

  return false;
}

// Debugging methods

namespace llvm {

raw_ostream &operator<<(raw_ostream &OS, const MCAsmFixup &AF) {
  OS << "<MCAsmFixup" << " Offset:" << AF.Offset << " Value:" << *AF.Value
     << " Kind:" << AF.Kind << ">";
  return OS;
}

}

void MCFragment::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCFragment " << (void*) this << " Offset:" << Offset
     << " FileSize:" << FileSize;

  OS << ">";
}

void MCAlignFragment::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCAlignFragment ";
  this->MCFragment::dump();
  OS << "\n       ";
  OS << " Alignment:" << getAlignment()
     << " Value:" << getValue() << " ValueSize:" << getValueSize()
     << " MaxBytesToEmit:" << getMaxBytesToEmit() << ">";
}

void MCDataFragment::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCDataFragment ";
  this->MCFragment::dump();
  OS << "\n       ";
  OS << " Contents:[";
  for (unsigned i = 0, e = getContents().size(); i != e; ++i) {
    if (i) OS << ",";
    OS << hexdigit((Contents[i] >> 4) & 0xF) << hexdigit(Contents[i] & 0xF);
  }
  OS << "] (" << getContents().size() << " bytes)";

  if (!getFixups().empty()) {
    OS << ",\n       ";
    OS << " Fixups:[";
    for (fixup_iterator it = fixup_begin(), ie = fixup_end(); it != ie; ++it) {
      if (it != fixup_begin()) OS << ",\n                ";
      OS << *it;
    }
    OS << "]";
  }

  OS << ">";
}

void MCFillFragment::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCFillFragment ";
  this->MCFragment::dump();
  OS << "\n       ";
  OS << " Value:" << getValue() << " ValueSize:" << getValueSize()
     << " Count:" << getCount() << ">";
}

void MCOrgFragment::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCOrgFragment ";
  this->MCFragment::dump();
  OS << "\n       ";
  OS << " Offset:" << getOffset() << " Value:" << getValue() << ">";
}

void MCZeroFillFragment::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCZeroFillFragment ";
  this->MCFragment::dump();
  OS << "\n       ";
  OS << " Size:" << getSize() << " Alignment:" << getAlignment() << ">";
}

void MCSectionData::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCSectionData";
  OS << " Alignment:" << getAlignment() << " Address:" << Address
     << " Size:" << Size << " FileSize:" << FileSize
     << " Fragments:[\n      ";
  for (iterator it = begin(), ie = end(); it != ie; ++it) {
    if (it != begin()) OS << ",\n      ";
    it->dump();
  }
  OS << "]>";
}

void MCSymbolData::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCSymbolData Symbol:" << getSymbol()
     << " Fragment:" << getFragment() << " Offset:" << getOffset()
     << " Flags:" << getFlags() << " Index:" << getIndex();
  if (isCommon())
    OS << " (common, size:" << getCommonSize()
       << " align: " << getCommonAlignment() << ")";
  if (isExternal())
    OS << " (external)";
  if (isPrivateExtern())
    OS << " (private extern)";
  OS << ">";
}

void MCAssembler::dump() {
  raw_ostream &OS = llvm::errs();

  OS << "<MCAssembler\n";
  OS << "  Sections:[\n    ";
  for (iterator it = begin(), ie = end(); it != ie; ++it) {
    if (it != begin()) OS << ",\n    ";
    it->dump();
  }
  OS << "],\n";
  OS << "  Symbols:[";

  for (symbol_iterator it = symbol_begin(), ie = symbol_end(); it != ie; ++it) {
    if (it != symbol_begin()) OS << ",\n           ";
    it->dump();
  }
  OS << "]>\n";
}
