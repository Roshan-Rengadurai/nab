import Foundation
import AppKit
import NabCore

// Nab headless CLI (scripting / CI). The GUI menubar app launches when
// no recognised CLI argument is given (see main.swift).
//
// Usage:
//   Nab <file>     upload a file
//   Nab capture    interactive region screenshot, then upload
//
// Config via environment:
//   NAB_ENDPOINT NAB_BUCKET NAB_ACCESS_KEY NAB_SECRET_KEY  (required)
//   NAB_REGION (default "auto") NAB_PUBLIC_BASE NAB_PATH_STYLE ("0" for virtual-host)
//   NAB_BURNER ("1" to wait-for-verify before copying)

private func cliFail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(1)
}

private func cliEnv(_ key: String) -> String? {
    guard let v = ProcessInfo.processInfo.environment[key], !v.isEmpty else { return nil }
    return v
}

private func cliRequire(_ key: String) -> String {
    guard let v = cliEnv(key) else { cliFail("Missing required env: \(key)") }
    return v
}

private func cliRunCapture() -> URL {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("nab-\(UUID().uuidString).png")
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    proc.arguments = ["-i", "-o", tmp.path]
    do { try proc.run(); proc.waitUntilExit() } catch { cliFail("screencapture failed: \(error)") }
    guard FileManager.default.fileExists(atPath: tmp.path),
          (try? Data(contentsOf: tmp))?.isEmpty == false else {
        cliFail("Capture cancelled, no screenshot taken.")
    }
    return tmp
}

private func cliBuildProvider() -> S3CompatProvider {
    guard let endpoint = URL(string: cliRequire("NAB_ENDPOINT")) else {
        cliFail("NAB_ENDPOINT is not a valid URL")
    }
    let pathStyle = (cliEnv("NAB_PATH_STYLE") ?? "1") != "0"
    let publicBase = cliEnv("NAB_PUBLIC_BASE").flatMap(URL.init(string:))
    let config = ProviderConfig(
        id: "cli", kind: .s3compat, endpoint: endpoint,
        region: cliEnv("NAB_REGION") ?? "auto",
        bucket: cliRequire("NAB_BUCKET"),
        pathStyle: pathStyle, publicBase: publicBase
    )
    let creds = SigV4Credentials(
        accessKeyID: cliRequire("NAB_ACCESS_KEY"),
        secretAccessKey: cliRequire("NAB_SECRET_KEY")
    )
    return S3CompatProvider(config: config, credentials: creds)
}

/// Dev helper: `Nab render-snippet <in.txt> <out.png>`, renders the
/// snippet image from a text file, for headless verification of SnippetImage.
func runRenderSnippet(_ args: [String]) -> Never {
    guard args.count >= 3 else { cliFail("Usage: Nab render-snippet <in.txt> <out.png>") }
    guard let text = try? String(contentsOfFile: args[1], encoding: .utf8) else {
        cliFail("Could not read: \(args[1])")
    }
    guard let png = SnippetImage.renderPNG(text: text) else { cliFail("Render failed") }
    do { try png.write(to: URL(fileURLWithPath: args[2])) } catch { cliFail("Write failed: \(error)") }
    FileHandle.standardError.write(Data("✓ rendered \(png.count) bytes → \(args[2])\n".utf8))
    exit(0)
}

func runCLI(_ args: [String]) -> Never {
    guard let command = args.first else { cliFail("Usage: Nab <file|capture>") }

    let fileURL: URL
    let origin: UploadOrigin
    if command == "capture" {
        fileURL = cliRunCapture()
        origin = .capture
    } else {
        fileURL = URL(fileURLWithPath: command)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cliFail("File not found: \(fileURL.path)")
        }
        origin = .drop
    }

    guard let data = try? Data(contentsOf: fileURL) else { cliFail("Could not read: \(fileURL.path)") }

    let provider = cliBuildProvider()
    let pipeline = UploadPipeline(
        provider: provider,
        uploader: URLSessionUploader(),
        clipboard: ClipboardWriter(),
        namingScheme: NamingScheme(slugLength: 10)
    )
    let item = UploadItem(
        data: data, fileExtension: fileURL.pathExtension,
        origin: origin, isBurner: cliEnv("NAB_BURNER") == "1"
    )

    let sema = DispatchSemaphore(value: 0)
    Task {
        do {
            var rng = SystemRandomNumberGenerator()
            let outcome = try await pipeline.upload(item, using: &rng)
            print(outcome.url.absoluteString)
            FileHandle.standardError.write(Data("✓ uploaded (\(data.count) bytes), URL copied to clipboard\n".utf8))
            if origin == .capture { try? FileManager.default.removeItem(at: fileURL) }
        } catch let e as UploadError {
            cliFail("Upload failed: HTTP \(e.statusCode)")
        } catch {
            cliFail("Upload failed: \(error)")
        }
        sema.signal()
    }
    sema.wait()
    exit(0)
}
