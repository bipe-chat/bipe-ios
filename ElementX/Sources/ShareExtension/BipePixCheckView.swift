//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Compound
import SwiftUI

/// "Conferir no Bipe" phase 1 (bipe ADR 0091): what a shared Pix code or key says, checked on the device.
/// Android: `BipePixCheckView` in libraries/bipe.
struct BipePixCheckView: View {
    let check: PixCheck
    let close: () -> Void
    let sendToChat: () -> Void
    
    var body: some View {
        ElementNavigationStack {
            Form {
                if let code = check.code {
                    codeSection(code)
                }
                if !check.keys.isEmpty {
                    keysSection
                }
                if let warning = check.warning {
                    Section {
                        ListRow(label: .default(title: BipeStrings.warningMoneyRequestTitle, description: warning.message, icon: \.warning, role: .error),
                                kind: .label)
                    }
                }
                Section {
                    ListRow(label: .default(title: BipeStrings.pixCheckBankName, icon: \.checkCircle), kind: .label)
                } footer: {
                    Text(BipeStrings.pixCheckPrivate)
                        .compoundListSectionFooter()
                }
                Section {
                    ListRow(label: .action(title: BipeStrings.pixCheckSendToChat, icon: \.forward), kind: .button(action: sendToChat))
                }
            }
            .compoundList()
            .navigationTitle(BipeStrings.pixCheckTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BipeStrings.pixCheckClose, action: close)
                }
            }
        }
        .onAppear {
            if check.warning != nil {
                BipeHaptics.play(.warning)
            }
        }
    }
    
    private func codeSection(_ code: PixCheck.Code) -> some View {
        Section {
            switch code.status {
            case .malformed:
                ListRow(label: .default(title: BipeStrings.pixCheckCodeMalformed, icon: \.error, role: .error), kind: .label)
            case .badCrc, .valid:
                if code.status == .badCrc {
                    ListRow(label: .default(title: BipeStrings.pixCheckCodeBadCrc, icon: \.error, role: .error), kind: .label)
                }
                if let name = code.name {
                    field(BipeStrings.pixCheckFieldName, name, footnote: BipeStrings.pixCheckNameHint)
                }
                field(BipeStrings.pixCheckFieldAmount, code.amount.map(Self.formattedAmount) ?? BipeStrings.pixCheckAmountOpen)
                if let key = code.key {
                    field(Self.keyLabel([code.keyType ?? .unknown]), key)
                }
                if let host = code.urlHost {
                    field(BipeStrings.pixCheckFieldChargeHost, host, footnote: BipeStrings.pixCheckCodeDynamic)
                }
                if let city = code.city {
                    field(BipeStrings.pixCheckFieldCity, city)
                }
                if let info = code.info {
                    field(BipeStrings.pixCheckFieldInfo, info)
                }
                if let txid = code.txid {
                    field(BipeStrings.pixCheckFieldTxid, txid)
                }
            }
        } header: {
            Text(BipeStrings.pixCheckCodeTitle)
                .compoundListSectionHeader()
        }
    }
    
    private var keysSection: some View {
        Section {
            ForEach(check.keys, id: \.value) { key in
                field(Self.keyLabel(key.types), key.value)
            }
        } header: {
            Text(BipeStrings.pixCheckKeysTitle)
                .compoundListSectionHeader()
        }
    }
    
    private func field(_ label: String, _ value: String, footnote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.compound.bodySM)
                .foregroundStyle(.compound.textSecondary)
            Text(value)
                .font(.compound.bodyLGSemibold)
                .foregroundStyle(.compound.textPrimary)
                .textSelection(.enabled)
            if let footnote {
                Text(footnote)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private static func keyLabel(_ types: [PixCheck.KeyType]) -> String {
        let names = types.map { type in
            switch type {
            case .cpf: BipeStrings.pixCheckKeyTypeCpf
            case .cnpj: BipeStrings.pixCheckKeyTypeCnpj
            case .phone: BipeStrings.pixCheckKeyTypePhone
            case .email: BipeStrings.pixCheckKeyTypeEmail
            case .random: BipeStrings.pixCheckKeyTypeRandom
            case .unknown: BipeStrings.pixCheckKeyTypeUnknown
            }
        }
        return names.dropFirst().reduce(names.first ?? BipeStrings.pixCheckKeyTypeUnknown) { BipeStrings.pixCheckKeyTypesOr($0, $1) }
    }
    
    /// "50.00" → "R$ 50,00". The code holds a plain decimal with a dot.
    private static func formattedAmount(_ amount: String) -> String {
        guard let value = Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX")) else { return amount }
        return value.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }
}

struct BipePixCheckView_Previews: PreviewProvider {
    static var previews: some View {
        BipePixCheckView(check: .check("URGENTE, paga agora: 00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D"),
                         close: { },
                         sendToChat: { })
    }
}
