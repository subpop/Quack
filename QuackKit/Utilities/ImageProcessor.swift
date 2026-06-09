// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import AppKit
import UniformTypeIdentifiers
import QuackInterface

/// Processes images for LLM consumption: resizing, compression, and MIME
/// type detection.
public enum ImageProcessor {

    /// Maximum dimension (width or height) for images sent to LLM providers.
    private static let maxDimension: CGFloat = 2048

    /// JPEG compression quality (0.0–1.0).
    private static let jpegQuality: CGFloat = 0.85

    /// Create an `Attachment` from a file URL, resizing images as needed.
    ///
    /// Images are resized to fit within ``maxDimension`` and compressed to
    /// JPEG. PDFs are stored as-is.
    public static func attachment(from url: URL) throws -> Attachment {
        let data = try Data(contentsOf: url)
        let mimeType = Self.mimeType(for: url)
        let fileName = url.lastPathComponent

        if mimeType == "application/pdf" {
            return Attachment(type: .pdf, mimeType: mimeType, data: data, fileName: fileName)
        }

        let processed = try processImageData(data)
        return Attachment(type: .image, mimeType: "image/jpeg", data: processed, fileName: fileName)
    }

    /// Create an `Attachment` from raw image data (e.g. from the pasteboard).
    public static func attachment(from imageData: Data, fileName: String? = nil) throws -> Attachment {
        let processed = try processImageData(imageData)
        return Attachment(type: .image, mimeType: "image/jpeg", data: processed, fileName: fileName)
    }

    /// Create an `Attachment` from an `NSImage` (e.g. from the pasteboard).
    public static func attachment(from image: NSImage, fileName: String? = nil) throws -> Attachment {
        let resized = resizeIfNeeded(image)
        guard let data = jpegData(from: resized) else {
            throw ImageProcessorError.conversionFailed
        }
        return Attachment(type: .image, mimeType: "image/jpeg", data: data, fileName: fileName)
    }

    // MARK: - Private

    private static func processImageData(_ data: Data) throws -> Data {
        guard let image = NSImage(data: data) else {
            throw ImageProcessorError.invalidImageData
        }
        let resized = resizeIfNeeded(image)
        guard let jpeg = jpegData(from: resized) else {
            throw ImageProcessorError.conversionFailed
        }
        return jpeg
    }

    private static func resizeIfNeeded(_ image: NSImage) -> NSImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        guard scale < 1 else { return image }

        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        resized.unlockFocus()
        return resized
    }

    private static func jpegData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
    }

    private static func mimeType(for url: URL) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension) {
            if utType.conforms(to: .pdf) { return "application/pdf" }
            if utType.conforms(to: .png) { return "image/png" }
            if utType.conforms(to: .jpeg) { return "image/jpeg" }
            if utType.conforms(to: .gif) { return "image/gif" }
            if utType.conforms(to: .webP) { return "image/webp" }
            if utType.conforms(to: .heic) { return "image/heic" }
            if utType.conforms(to: .tiff) { return "image/tiff" }
            if utType.conforms(to: .image) { return "image/jpeg" }
        }
        return "application/octet-stream"
    }
}

public enum ImageProcessorError: LocalizedError {
    case invalidImageData
    case conversionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImageData: "The file does not contain valid image data."
        case .conversionFailed: "Failed to convert the image to JPEG format."
        }
    }
}
