//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// The "O que você perdeu" block above the read marker (bipe#98). Each line opens its message.
struct BipeMissedSummaryView: View {
    let summary: BipeMissedSummary
    let onTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(BipeStrings.groupMissedTitle)
                .font(.compound.bodySMSemibold)
                .foregroundStyle(.compound.textActionAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            ForEach(summary.lines) { line in
                Divider()
                Button { onTap(line.eventID) } label: {
                    lineLabel(line)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            Text(BipeStrings.groupMissedMore("\(summary.otherCount)"))
                .font(.compound.bodySM)
                .foregroundStyle(.compound.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.compound.borderInteractiveSecondary, lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func lineLabel(_ line: BipeMissedSummary.Line) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title(for: line))
                .font(.compound.bodySMSemibold)
                .foregroundStyle(.compound.textPrimary)
            if line.kind != .poll {
                Text(line.text)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func title(for line: BipeMissedSummary.Line) -> String {
        switch line.kind {
        case .mention: BipeStrings.groupMissedMention(line.senderName)
        case .reply: BipeStrings.groupMissedReply(line.senderName)
        case .poll: BipeStrings.groupMissedPoll(line.text)
        }
    }
}

struct BipeMissedSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        BipeMissedSummaryView(summary: .init(lines: [.init(kind: .mention, eventID: "$1", senderName: "Bia", text: "@gabi você leva o carvão?"),
                                                     .init(kind: .reply, eventID: "$2", senderName: "Léo", text: "Fechado, 13h lá em casa"),
                                                     .init(kind: .poll, eventID: "$3", senderName: "Léo", text: "Sábado ou domingo?")],
                                             otherCount: 142)) { _ in }
    }
}
