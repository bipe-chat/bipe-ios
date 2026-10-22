//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI
import UniformTypeIdentifiers

/// Bipe: "Verificar com gov.br", trust step 5 (bipe#544). Two taps in Bipe: one out to the gov.br app, one back.
/// Tap 1 gets the challenge and opens the system save dialog; after the save the gov.br page opens.
/// The way back by the share sheet comes in a later change; "Já assinei" opens a PDF picker.
struct BipeGovbrScreen: View {
    let flow: BipeGovbrFlow
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isPickingFile = false
    @State private var isSavingFile = false
    
    private var challengeDocument: BipeChallengePDF? {
        guard case .waitingForSignature(let pdf, let fileName) = flow.phase else { return nil }
        return BipeChallengePDF(data: pdf, fileName: fileName)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ListRow(label: .description(BipeStrings.govbrIntro), kind: .label)
                    ListRow(label: .description(BipeStrings.govbrNeedsLevel), kind: .label)
                }
                
                Section {
                    ListRow(label: .default(title: BipeStrings.govbrStepSave, icon: \.download), kind: .label)
                    ListRow(label: .default(title: BipeStrings.govbrStepSign, icon: \.verified), kind: .label)
                    ListRow(label: .default(title: BipeStrings.govbrStepShare, icon: \.attachment), kind: .label)
                }
                
                Section {
                    phaseRows
                } footer: {
                    Text(BipeStrings.govbrSafety)
                        .compoundListSectionFooter()
                }
            }
            .compoundList()
            .navigationTitle(BipeStrings.govbrTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionClose) { dismiss() }
                }
            }
            .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf]) { result in
                guard case .success(let fileURL) = result else { return }
                Task { await flow.submit(fileURL: fileURL) }
            }
            .fileExporter(isPresented: $isSavingFile,
                          document: challengeDocument,
                          contentType: .pdf,
                          defaultFilename: challengeDocument?.fileName) { result in
                if case .success = result {
                    openURL(BipeGovbrFlow.govbrAppURL)
                }
            }
        }
    }
    
    @ViewBuilder
    private var phaseRows: some View {
        switch flow.phase {
        case .ready:
            startRow(title: BipeStrings.govbrStart)
        case .preparing:
            ListRow(label: .plain(title: BipeStrings.govbrStart), details: .isWaiting(true), kind: .label)
        case .waitingForSignature:
            ListRow(label: .action(title: BipeStrings.govbrAlreadySigned, icon: \.attachment),
                    kind: .button { isPickingFile = true })
            ListRow(label: .action(title: BipeStrings.govbrStepSave, icon: \.download),
                    kind: .button { isSavingFile = true })
            ListRow(label: .action(title: BipeStrings.govbrGetApp, icon: \.popOut),
                    kind: .button { openURL(BipeGovbrFlow.govbrAppURL) })
        case .checking:
            ListRow(label: .plain(title: BipeStrings.govbrChecking), details: .isWaiting(true), kind: .label)
        case .verified(let name):
            ListRow(label: .default(title: name.map(BipeStrings.govbrVerified) ?? BipeStrings.trustStepGovbr,
                                    icon: \.checkCircleSolid),
                    kind: .label)
        case .rejected(let reason):
            ListRow(label: .description(reason.message), kind: .label)
            startRow(title: BipeStrings.govbrRetry)
        case .failed:
            ListRow(label: .description(L10n.errorUnknown), kind: .label)
            startRow(title: BipeStrings.govbrRetry)
        }
    }
    
    private func startRow(title: String) -> some View {
        ListRow(label: .action(title: title, icon: \.verified),
                kind: .button {
                    Task {
                        await flow.start()
                        if case .waitingForSignature = flow.phase {
                            isSavingFile = true
                        }
                    }
                })
    }
}

/// The challenge PDF for the system save dialog.
private struct BipeChallengePDF: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]
    
    let data: Data
    let fileName: String
    
    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        fileName = configuration.file.filename ?? ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private extension BipeGovbrReason {
    var message: String {
        switch self {
        case .notSigned: BipeStrings.govbrReasonNotSigned
        case .notGovbr: BipeStrings.govbrReasonNotGovbr
        case .wrongDocument: BipeStrings.govbrReasonWrongDocument
        case .expired: BipeStrings.govbrReasonExpired
        case .cpfInUse: BipeStrings.govbrReasonCpfInUse
        case .changedAfterSigning: BipeStrings.govbrReasonChangedAfterSigning
        }
    }
}

struct BipeGovbrScreen_Previews: PreviewProvider {
    static var previews: some View {
        BipeGovbrScreen(flow: BipeGovbrFlow(apiClient: BipeAPIClient(baseURL: URL(string: "https://api.example.com")!),
                                            accessToken: { nil }))
    }
}
