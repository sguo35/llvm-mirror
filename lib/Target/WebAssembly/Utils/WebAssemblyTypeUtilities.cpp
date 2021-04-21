//===-- WebAssemblyTypeUtilities.cpp - WebAssembly Type Utility Functions -===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// This file implements several utility functions for WebAssembly type parsing.
///
//===----------------------------------------------------------------------===//

#include "WebAssemblyTypeUtilities.h"
#include "llvm/ADT/StringSwitch.h"

using namespace llvm;

Optional<wasm::ValType> WebAssembly::parseType(StringRef Type) {
  // FIXME: can't use StringSwitch because wasm::ValType doesn't have a
  // "invalid" value.
  if (Type == "i32")
    return wasm::ValType::I32;
  if (Type == "i64")
    return wasm::ValType::I64;
  if (Type == "f32")
    return wasm::ValType::F32;
  if (Type == "f64")
    return wasm::ValType::F64;
  if (Type == "v128" || Type == "i8x16" || Type == "i16x8" || Type == "i32x4" ||
      Type == "i64x2" || Type == "f32x4" || Type == "f64x2")
    return wasm::ValType::V128;
  if (Type == "funcref")
    return wasm::ValType::FUNCREF;
  if (Type == "externref")
    return wasm::ValType::EXTERNREF;
  return Optional<wasm::ValType>();
}

WebAssembly::HeapType WebAssembly::parseHeapType(StringRef Type) {
  return StringSwitch<WebAssembly::HeapType>(Type)
      .Case("extern", WebAssembly::HeapType::Externref)
      .Case("func", WebAssembly::HeapType::Funcref)
      .Default(WebAssembly::HeapType::Invalid);
}

WebAssembly::BlockType WebAssembly::parseBlockType(StringRef Type) {
  // Multivalue block types are handled separately in parseSignature
  return StringSwitch<WebAssembly::BlockType>(Type)
      .Case("i32", WebAssembly::BlockType::I32)
      .Case("i64", WebAssembly::BlockType::I64)
      .Case("f32", WebAssembly::BlockType::F32)
      .Case("f64", WebAssembly::BlockType::F64)
      .Case("v128", WebAssembly::BlockType::V128)
      .Case("funcref", WebAssembly::BlockType::Funcref)
      .Case("externref", WebAssembly::BlockType::Externref)
      .Case("void", WebAssembly::BlockType::Void)
      .Default(WebAssembly::BlockType::Invalid);
}

// We have various enums representing a subset of these types, use this
// function to convert any of them to text.
const char *WebAssembly::anyTypeToString(unsigned Type) {
  switch (Type) {
  case wasm::WASM_TYPE_I32:
    return "i32";
  case wasm::WASM_TYPE_I64:
    return "i64";
  case wasm::WASM_TYPE_F32:
    return "f32";
  case wasm::WASM_TYPE_F64:
    return "f64";
  case wasm::WASM_TYPE_V128:
    return "v128";
  case wasm::WASM_TYPE_FUNCREF:
    return "funcref";
  case wasm::WASM_TYPE_EXTERNREF:
    return "externref";
  case wasm::WASM_TYPE_FUNC:
    return "func";
  case wasm::WASM_TYPE_NORESULT:
    return "void";
  default:
    return "invalid_type";
  }
}

const char *WebAssembly::typeToString(wasm::ValType Type) {
  return anyTypeToString(static_cast<unsigned>(Type));
}

std::string WebAssembly::typeListToString(ArrayRef<wasm::ValType> List) {
  std::string S;
  for (const auto &Type : List) {
    if (&Type != &List[0])
      S += ", ";
    S += WebAssembly::typeToString(Type);
  }
  return S;
}

std::string WebAssembly::signatureToString(const wasm::WasmSignature *Sig) {
  std::string S("(");
  S += typeListToString(Sig->Params);
  S += ") -> (";
  S += typeListToString(Sig->Returns);
  S += ")";
  return S;
}

wasm::ValType WebAssembly::toValType(MVT Type) {
  switch (Type.SimpleTy) {
  case MVT::i32:
    return wasm::ValType::I32;
  case MVT::i64:
    return wasm::ValType::I64;
  case MVT::f32:
    return wasm::ValType::F32;
  case MVT::f64:
    return wasm::ValType::F64;
  case MVT::v16i8:
  case MVT::v8i16:
  case MVT::v4i32:
  case MVT::v2i64:
  case MVT::v4f32:
  case MVT::v2f64:
    return wasm::ValType::V128;
  case MVT::funcref:
    return wasm::ValType::FUNCREF;
  case MVT::externref:
    return wasm::ValType::EXTERNREF;
  default:
    llvm_unreachable("unexpected type");
  }
}
