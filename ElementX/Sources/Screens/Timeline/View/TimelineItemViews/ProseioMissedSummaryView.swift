//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import ProseioKit
import SwiftUI

/// The "O que você perdeu" block above the read marker (proseio#98). Each line opens its message.
struct ProseioMissedSummaryView: View {
    let summary: ProseioMissedSummary
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ProseioStrings.groupMissedTitle)
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
            Text(ProseioStrings.groupMissedMore("\(summary.otherCount)"))
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

    private func lineLabel(_ line: ProseioMissedSummary.Line) -> some View {
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

    private func title(for line: ProseioMissedSummary.Line) -> String {
        switch line.kind {
        case .mention: ProseioStrings.groupMissedMention(line.senderName)
        case .reply: ProseioStrings.groupMissedReply(line.senderName)
        case .poll: ProseioStrings.groupMissedPoll(line.text)
        }
    }
}

struct ProseioMissedSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        ProseioMissedSummaryView(summary: .init(lines: [.init(kind: .mention, eventID: "$1", senderName: "Bia", text: "@gabi você leva o carvão?"),
                                                        .init(kind: .reply, eventID: "$2", senderName: "Léo", text: "Fechado, 13h lá em casa"),
                                                        .init(kind: .poll, eventID: "$3", senderName: "Léo", text: "Sábado ou domingo?")],
                                                otherCount: 142)) { _ in }
    }
}
