//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// The company seal next to a name (bipe#252, ADR 0020). Shows only for a verified company. A tap opens the details.
struct BipeCompanySeal: View {
    @Environment(\.bipeCompanySeals) private var seals
    @State private var isShowingDetails = false
    
    let userID: String
    var size: CGFloat = 16
    
    var body: some View {
        if let payload = seals?.badge(for: userID) {
            Button {
                isShowingDetails = true
            } label: {
                BipeSealMark(size: size)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(BipeStrings.badgeCompany)
            .sheet(isPresented: $isShowingDetails) {
                BipeCompanySealSheet(payload: payload)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

/// The seal shape with a building glyph (trust-ui.md). It must not look like Element's verification shield.
struct BipeSealMark: View {
    let size: CGFloat
    
    var body: some View {
        BipeSealShape()
            .fill(Color.compound.iconTrustVerified)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "building.2.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.compound.iconOnSolidPrimary)
                    .padding(size * 0.24)
            }
            .accessibilityHidden(true)
    }
}

/// The Bipe mark: a rounded square with a tight top-left corner (bipe-web/public/brand/mark.svg, viewBox 64).
nonisolated struct BipeSealShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 48
        let origin = CGPoint(x: rect.midX - 24 * scale, y: rect.midY - 24 * scale)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + (x - 8) * scale, y: origin.y + (y - 8) * scale)
        }
        var path = Path()
        path.move(to: point(8, 10))
        path.addQuadCurve(to: point(10, 8), control: point(8, 8))
        path.addLine(to: point(38, 8))
        path.addCurve(to: point(56, 26), control1: point(47.9, 8), control2: point(56, 16.1))
        path.addLine(to: point(56, 38))
        path.addCurve(to: point(38, 56), control1: point(56, 47.9), control2: point(47.9, 56))
        path.addLine(to: point(26, 56))
        path.addCurve(to: point(8, 38), control1: point(16.1, 56), control2: point(8, 47.9))
        path.closeSubpath()
        return path
    }
}

/// Legal name, CNPJ and dates of a verified company.
struct BipeCompanySealSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let payload: BadgePayload
    
    var body: some View {
        ElementNavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        BipeSealMark(size: 32)
                        Text(payload.name)
                            .font(.compound.headingSMSemibold)
                            .foregroundStyle(.compound.textPrimary)
                    }
                }
                Section {
                    if let company = payload.company {
                        row(BipeStrings.badgeCompanyLegalName, company.legalName)
                        if let tradeName = company.tradeName {
                            row(BipeStrings.badgeCompanyTradeName, tradeName)
                        }
                        if let cnpj = payload.cnpj {
                            row(BipeStrings.badgeCompanyCnpj, BipeCNPJ.formatted(cnpj))
                        }
                        if let month = BipeCNPJ.checkedDate(company.checkedMonth) {
                            row(BipeStrings.badgeCompanyChecked, month.formatted(.dateTime.month(.wide).year()))
                        }
                    }
                    row(BipeStrings.badgeCompanyValidUntil,
                        Date(timeIntervalSince1970: TimeInterval(payload.exp)).formatted(date: .long, time: .omitted))
                } footer: {
                    Text(BipeStrings.badgeCompanyBody)
                        .compoundListSectionFooter()
                }
            }
            .compoundList()
            .navigationTitle(BipeStrings.badgeCompany)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.actionDone) { dismiss() }
                }
            }
        }
    }
    
    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
            .textSelection(.enabled)
    }
}

/// The notice in a chat with an account whose seal ended or no longer verifies.
struct BipeCompanySealNotice: View {
    @Environment(\.bipeCompanySeals) private var seals
    
    let userID: String
    
    var body: some View {
        if let text {
            HStack(alignment: .top, spacing: 8) {
                CompoundIcon(\.warning, size: .small, relativeTo: .compound.bodyMD)
                    .foregroundStyle(Color.compound.iconTrustCaution)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.compound.bgTrustCautionSubtle, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private var text: String? {
        guard let state = seals?.state(for: userID) else { return nil }
        return switch state {
        case .revoked(.notActive), .revoked(.notFound):
            BipeStrings.badgeCompanyRevokedNotActive
        case .revoked:
            BipeStrings.badgeCompanyRevoked
        case .suspended:
            BipeStrings.badgeCompanySuspended
        case .verified, .none:
            nil
        }
    }
}

struct BipeCompanySeal_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            Text("2 zero 1")
            BipeSealMark(size: 16)
        }
        .padding()
    }
}
