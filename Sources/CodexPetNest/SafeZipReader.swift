import Foundation
import Compression
import CryptoKit

/// A minimal, safe ZIP reader that parses Central Directory Headers
/// and extracts entries using the Compression framework.
/// It strictly enforces path traversal and symlink protections.
final class SafeZipReader {
    enum Error: LocalizedError {
        case invalidZip(String)
        case unsupportedCompression(String)
        case pathTraversal(String)
        case unsafeContent(String)
        case extractionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidZip(let msg): return "Invalid ZIP: \(msg)"
            case .unsupportedCompression(let msg): return "Unsupported compression: \(msg)"
            case .pathTraversal(let p): return "Unsafe path: \(p)"
            case .unsafeContent(let msg): return "Unsafe content: \(msg)"
            case .extractionFailed(let msg): return "Extraction failed: \(msg)"
            }
        }
    }

    struct Entry {
        let path: String
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let offset: UInt32
        let method: UInt16
        let externalAttributes: UInt32
        let isDirectory: Bool
        
        var isSymlink: Bool {
            // External attributes bit 5 (Unix symlink)
            return (externalAttributes >> 16) & 0xA000 == 0xA000
        }
    }

    private let data: Data
    private(set) var entries: [Entry] = []

    init(data: Data) throws {
        self.data = data
        try parseCentralDirectory()
    }

    private func parseCentralDirectory() throws {
        // Find EOCD (PK\x05\x06) - 22 bytes minimum
        guard data.count >= 22 else { throw Error.invalidZip("File too small") }
        
        var eocdOffset = -1
        // Search from end for PK\x05\x06 (0x06054b50 in little endian)
        for i in (0...(data.count - 22)).reversed() {
            if data[i] == 0x50 && data[i+1] == 0x4b && data[i+2] == 0x05 && data[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        
        guard eocdOffset != -1 else { throw Error.invalidZip("EOCD not found") }
        
        let cdCount = Int(readUInt16(at: eocdOffset + 10))
        let cdSize = Int(readUInt32(at: eocdOffset + 12))
        let cdOffset = Int(readUInt32(at: eocdOffset + 16))
        
        guard cdOffset + cdSize <= data.count else { throw Error.invalidZip("CD offset out of bounds") }
        
        var offset = cdOffset
        var entriesCount = 0
        
        while offset + 46 <= cdOffset + cdSize {
            // PK\x01\x02 (0x02014b50)
            guard data[offset] == 0x50 && data[offset+1] == 0x4b && data[offset+2] == 0x01 && data[offset+3] == 0x02 else {
                break
            }
            
            let method = readUInt16(at: offset + 10)
            let compSize = readUInt32(at: offset + 20)
            let uncompSize = readUInt32(at: offset + 24)
            let nameLen = Int(readUInt16(at: offset + 28))
            let extraLen = Int(readUInt16(at: offset + 30))
            let commentLen = Int(readUInt16(at: offset + 32))
            let externalAttrs = readUInt32(at: offset + 38)
            let localHeaderOffset = readUInt32(at: offset + 42)
            
            let nextOffset = offset + 46 + nameLen + extraLen + commentLen
            guard nextOffset <= cdOffset + cdSize else {
                throw Error.invalidZip("Central directory entry out of bounds")
            }
            
            let pathData = data.subdata(in: (offset + 46)..<(offset + 46 + nameLen))
            guard let path = String(data: pathData, encoding: .utf8) else {
                throw Error.invalidZip("Invalid filename encoding")
            }
            
            let isDir = path.hasSuffix("/")
            
            entries.append(Entry(
                path: path,
                compressedSize: compSize,
                uncompressedSize: uncompSize,
                offset: localHeaderOffset,
                method: method,
                externalAttributes: externalAttrs,
                isDirectory: isDir
            ))
            
            offset = nextOffset
            entriesCount += 1
        }
        
        guard entriesCount == cdCount else {
            throw Error.invalidZip("Entry count mismatch: expected \(cdCount), got \(entriesCount)")
        }
    }

    func extract(entry: Entry, to destURL: URL) throws {
        // 1. Safety checks
        if entry.path.contains("..") || entry.path.hasPrefix("/") {
            throw Error.pathTraversal(entry.path)
        }
        
        let targetURL = destURL.appendingPathComponent(entry.path).standardizedFileURL
        if !targetURL.path.hasPrefix(destURL.standardizedFileURL.path) {
            throw Error.pathTraversal(entry.path)
        }
        
        if entry.isSymlink {
            throw Error.unsafeContent("Symlinks are forbidden: \(entry.path)")
        }
        
        if entry.isDirectory {
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
            return
        }
        
        try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // 2. Read Local File Header to skip to data
        let lfhOffset = Int(entry.offset)
        guard data.count >= lfhOffset + 30 else { throw Error.invalidZip("LFH out of bounds") }
        guard data[lfhOffset] == 0x50 && data[lfhOffset+1] == 0x4b && data[lfhOffset+2] == 0x03 && data[lfhOffset+3] == 0x04 else {
            throw Error.invalidZip("Invalid LFH signature")
        }
        
        let nameLen = Int(readUInt16(at: lfhOffset + 26))
        let extraLen = Int(readUInt16(at: lfhOffset + 28))
        let dataStart = lfhOffset + 30 + nameLen + extraLen
        let dataEnd = dataStart + Int(entry.compressedSize)
        
        guard dataEnd <= data.count else { throw Error.invalidZip("Data out of bounds") }
        let compressedData = data.subdata(in: dataStart..<dataEnd)
        
        // 3. Decompress
        let uncompressedData: Data
        if entry.method == 0 { // STORE
            uncompressedData = compressedData
        } else if entry.method == 8 { // DEFLATE
            uncompressedData = try decompressDeflate(compressedData, uncompressedSize: Int(entry.uncompressedSize))
        } else {
            throw Error.unsupportedCompression("Method \(entry.method) not supported")
        }
        
        guard uncompressedData.count == Int(entry.uncompressedSize) else {
            throw Error.extractionFailed("Size mismatch: expected \(entry.uncompressedSize), got \(uncompressedData.count)")
        }
        
        try uncompressedData.write(to: targetURL, options: .atomic)
        
        // Ensure no executable bit
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: targetURL.path)
    }

    private func decompressDeflate(_ compressedData: Data, uncompressedSize: Int) throws -> Data {
        if uncompressedSize == 0 { return Data() }
        
        let bufferSize = uncompressedSize
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let result = compressedData.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Int in
            guard let sourceAddress = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_decode_buffer(
                destinationBuffer, bufferSize,
                sourceAddress, compressedData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        if result == 0 {
            throw Error.extractionFailed("Deflate decompression failed")
        }
        
        return Data(bytes: destinationBuffer, count: result)
    }

    private func readUInt16(at offset: Int) -> UInt16 {
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readUInt32(at offset: Int) -> UInt32 {
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }
}
