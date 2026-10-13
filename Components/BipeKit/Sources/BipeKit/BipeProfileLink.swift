//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import CoreImage.CIFilterBuiltins
import SwiftUI

/// Profile links: `https://bipe.chat/@handle`. The web page there falls back to the App Store;
/// the app opens it as a universal link (`applinks:bipe.chat`).
/// Links on the old host `proseio.com.br` still parse: that host redirects to `bipe.chat`.
public nonisolated enum BipeProfileLink {
    public static let host = "bipe.chat"
    /// Hosts whose links the app accepts. The old host stays for links already shared.
    static let acceptedHosts: Set<String> = [host, "www.\(host)", "proseio.com.br", "www.proseio.com.br"]

    static func isBipeLinkHost(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return acceptedHosts.contains(host)
    }

    public static func url(handle: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/@\(handle)"
        return components.url
    }

    /// The handle in a profile link, lowercased, or `nil` when the URL is not one.
    public static func handle(from url: URL) -> String? {
        guard url.scheme == "https", isBipeLinkHost(url) else {
            return nil
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 1, let first = components.first, first.hasPrefix("@") else { return nil }
        let handle = BipeHandle.sanitize(first).lowercased()
        return BipeHandle.localProblem(for: handle) == nil ? handle : nil
    }

    /// The Matrix user ID in a `https://matrix.to/#/@user:server` permalink.
    public static func matrixUserID(fromPermalink url: URL) -> String? {
        guard url.host() == "matrix.to", let fragment = url.fragment(percentEncoded: false) else { return nil }
        let path = fragment.split(separator: "?", maxSplits: 1).first.map(String.init) ?? fragment
        let userID = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return userID.hasPrefix("@") && !userID.contains("/") ? userID : nil
    }
}

public extension BipeHandleResolver {
    /// The profile link for a user with a known handle.
    func profileLink(for userID: String) -> URL? {
        handle(for: userID).flatMap(BipeProfileLink.url(handle:))
    }

    /// Swaps a matrix.to user permalink for the Bipe profile link when the handle is known.
    func shareURL(for permalink: URL) -> URL {
        BipeProfileLink.matrixUserID(fromPermalink: permalink).flatMap(profileLink(for:)) ?? permalink
    }
}

// MARK: - QR code

#if canImport(UIKit)

/// A QR code for a profile link, drawn with Core Image.
public struct BipeQRCodeView: View {
    private let image: UIImage?

    public init(url: URL) {
        image = Self.makeImage(for: url.absoluteString)
    }

    public var body: some View {
        if let image {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
        }
    }

    private static func makeImage(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Sheet content: the QR code of the user's own profile link, the handle and a share button.
public struct BipeProfileQRCodeSheet: View {
    private let handle: String
    private let url: URL

    public init?(handle: String) {
        guard let url = BipeProfileLink.url(handle: handle) else { return nil }
        self.handle = handle
        self.url = url
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text(BipeStrings.profileQrTitle)
                .font(.title3.bold())
            BipeQRCodeView(url: url)
                .frame(maxWidth: 280)
            Text("@\(handle)")
                .font(.headline)
            Text(BipeStrings.profileQrFooter)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ShareLink(item: url) {
                Label(BipeStrings.profileShare, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
#endif
