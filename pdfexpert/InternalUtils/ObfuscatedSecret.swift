//
//  ObfuscatedSecret.swift
//  PdfExpert
//
//  Runtime holder for a build-time XOR-obfuscated secret.
//
//  SECURITY NOTE: obfuscation only raises the bar. Because the XOR pad is
//  regenerated on every build, the cleartext secret never appears in the IPA and
//  `strings` on the binary reveals nothing recognizable. A runtime attacker on a
//  jailbroken device (hooking, memory dumping) can still recover the value once
//  `value` is evaluated. The definitive fix remains a server-side proxy that holds
//  the real key and enforces quotas.
//

import Foundation

/// A secret stored as `bytes` XOR-ed against a per-build random `pad`.
///
/// `pad` and `bytes` must have the same length; the deobfuscated value is their
/// element-wise XOR decoded as UTF-8. An empty secret is represented by empty
/// arrays and deobfuscates to `""`.
struct ObfuscatedSecret {

    let pad: [UInt8]
    let bytes: [UInt8]

    var value: String {
        guard !bytes.isEmpty, pad.count == bytes.count else { return "" }
        let deobfuscated = zip(bytes, pad).map { $0 ^ $1 }
        return String(decoding: deobfuscated, as: UTF8.self)
    }
}
