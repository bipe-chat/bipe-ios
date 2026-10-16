//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Compound
import SwiftUI

struct LocationSharingSettingsScreen: View {
    static let measurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter
    }()
    
    @Bindable var context: LocationSharingSettingsScreenViewModel.Context
    
    var body: some View {
        Form {
            liveLocationSection
        }
        .compoundList()
        .navigationTitle(BipeStrings.chatsLiveLocation) // Bipe: Element has no pt-BR here (ADR 0112)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var liveLocationSection: some View {
        let binding = Binding(get: {
            Double(context.liveLocationMinimumDistanceUpdate)
        }, set: { newValue in
            context.liveLocationMinimumDistanceUpdate = Int(newValue)
        })
        
        Section {
            ListRow(kind: .custom {
                VStack(alignment: .leading, spacing: 0) {
                    // Bipe: needs string bipe_chats_live_location_distance ("A cada %1$@"); Element's plural is English only.
                    Text(Self.measurementFormatter.string(from: .init(value: Double(context.liveLocationMinimumDistanceUpdate), unit: UnitLength.meters)))
                        .font(.compound.bodyLG)
                        .foregroundStyle(.compound.textPrimary)
                        // The internal hidden label of the slider will read voice over
                        .accessibilityHidden(true)
                    Slider(value: binding, in: 1...100) {
                        Text(BipeStrings.chatsLiveLocation)
                    } minimumValueLabel: {
                        Text(Self.measurementFormatter.string(from: .init(value: 1,
                                                                          unit: UnitLength.meters)))
                            .font(.compound.bodyLG)
                            .foregroundStyle(.compound.textSecondary)
                            .padding(.trailing, 15)
                    } maximumValueLabel: {
                        Text(Self.measurementFormatter.string(from: .init(value: 100,
                                                                          unit: UnitLength.meters)))
                            .font(.compound.bodyLG)
                            .foregroundStyle(.compound.textSecondary)
                            .padding(.leading, 15)
                    }
                    .tint(.compound.iconAccentPrimary)
                }
                .padding(.horizontal, ListRowPadding.horizontal)
                .padding(.vertical, ListRowPadding.vertical)
            })
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                Text(BipeStrings.chatsLiveLocation)
                    .compoundListSectionHeader()
                Text(BipeStrings.chatsLiveLocationFooter)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
            }
        } footer: {
            // Bipe: needs string bipe_chats_live_location_precise ("Precise Location" hint); Element's is English only.
            Text(context.viewState.liveLocationUpdateFooterAttributedString)
                .compoundListSectionFooter()
        }
    }
}

// MARK: - Previews

struct LocationSharingSettingsScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = LocationSharingSettingsScreenViewModel(userSettings: .mock())
    
    static var previews: some View {
        ElementNavigationStack {
            LocationSharingSettingsScreen(context: viewModel.context)
        }
    }
}

private extension TimelineMediaVisibility {
    static var items: [(title: String, tag: TimelineMediaVisibility)] {
        [(title: L10n.screenAdvancedSettingsShowMediaTimelineAlwaysHide, tag: .never),
         (title: L10n.screenAdvancedSettingsShowMediaTimelinePrivateRooms, tag: .privateOnly),
         (title: L10n.screenAdvancedSettingsShowMediaTimelineAlwaysShow, tag: .always)]
    }
}
