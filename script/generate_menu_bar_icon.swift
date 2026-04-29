import AppKit
import Foundation
import ImageIO

struct IconExport {
    let filename: String
    let pixels: Int
}

let rootDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = rootDirectory.appendingPathComponent("Assets", isDirectory: true)
let sourceURL = outputDirectory.appendingPathComponent("CatRestIconSource.png")

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    throw NSError(domain: "CatRestIcon", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Missing icon source at \(sourceURL.path)"
    ])
}

let menuBarExports = [
    IconExport(filename: "MenuBarCatClock.png", pixels: 18),
    IconExport(filename: "MenuBarCatClock@2x.png", pixels: 36),
    IconExport(filename: "MenuBarCatClock@3x.png", pixels: 54),
    IconExport(filename: "MenuBarCatClock.preview.png", pixels: 256)
]

let appIconDirectory = outputDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let appIconExports = [
    IconExport(filename: "icon_16x16.png", pixels: 16),
    IconExport(filename: "icon_16x16@2x.png", pixels: 32),
    IconExport(filename: "icon_32x32.png", pixels: 32),
    IconExport(filename: "icon_32x32@2x.png", pixels: 64),
    IconExport(filename: "icon_128x128.png", pixels: 128),
    IconExport(filename: "icon_128x128@2x.png", pixels: 256),
    IconExport(filename: "icon_256x256.png", pixels: 256),
    IconExport(filename: "icon_256x256@2x.png", pixels: 512),
    IconExport(filename: "icon_512x512.png", pixels: 512),
    IconExport(filename: "icon_512x512@2x.png", pixels: 1024)
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: appIconDirectory, withIntermediateDirectories: true)

for export in menuBarExports {
    let outputURL = outputDirectory.appendingPathComponent(export.filename)
    try resizedPNG(from: sourceImage, pixels: export.pixels).write(to: outputURL, options: .atomic)
    print(outputURL.path)
}

for export in appIconExports {
    let outputURL = appIconDirectory.appendingPathComponent(export.filename)
    try resizedPNG(from: sourceImage, pixels: export.pixels).write(to: outputURL, options: .atomic)
    print(outputURL.path)
}

let appIconURL = outputDirectory.appendingPathComponent("AppIcon.icns")
try writeICNS(iconsetDirectory: appIconDirectory, outputURL: appIconURL)
print(appIconURL.path)

func resizedPNG(from source: NSImage, pixels: Int) throws -> Data {
    var sourceRect = CGRect(origin: .zero, size: source.size)
    guard let sourceImage = source.cgImage(forProposedRect: &sourceRect, context: nil, hints: nil) else {
        throw NSError(domain: "CatRestIcon", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Could not read source image"
        ])
    }

    let bytesPerRow = pixels * 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        .union(.byteOrder32Big)

    var rawData = Data(count: bytesPerRow * pixels)
    try rawData.withUnsafeMutableBytes { buffer in
        guard
            let baseAddress = buffer.baseAddress,
            let context = CGContext(
                data: baseAddress,
                width: pixels,
                height: pixels,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            throw NSError(domain: "CatRestIcon", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Could not create \(pixels)x\(pixels) bitmap context"
            ])
        }

        context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        context.interpolationQuality = .high
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    }

    guard
        let provider = CGDataProvider(data: rawData as CFData),
        let resizedImage = CGImage(
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    else {
        throw NSError(domain: "CatRestIcon", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Could not create \(pixels)x\(pixels) image"
        ])
    }

    let outputData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(outputData, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "CatRestIcon", code: 5, userInfo: [
            NSLocalizedDescriptionKey: "Could not create PNG destination"
        ])
    }

    CGImageDestinationAddImage(destination, resizedImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "CatRestIcon", code: 6, userInfo: [
            NSLocalizedDescriptionKey: "Could not encode \(pixels)x\(pixels) PNG"
        ])
    }

    return outputData as Data
}

func writeICNS(iconsetDirectory: URL, outputURL: URL) throws {
    let chunks: [(type: String, filename: String)] = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png")
    ]

    var body = Data()
    for chunk in chunks {
        let data = try Data(contentsOf: iconsetDirectory.appendingPathComponent(chunk.filename))
        body.append(Data(chunk.type.utf8))
        body.append(bigEndianUInt32(UInt32(data.count + 8)))
        body.append(data)
    }

    var iconData = Data("icns".utf8)
    iconData.append(bigEndianUInt32(UInt32(body.count + 8)))
    iconData.append(body)
    try iconData.write(to: outputURL, options: .atomic)
}

func bigEndianUInt32(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}
