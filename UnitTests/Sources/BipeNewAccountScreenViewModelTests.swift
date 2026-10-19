//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
@testable import ElementX
import Testing

@MainActor
struct BipeNewAccountScreenViewModelTests {
    @Test
    func rowsFollowTheCapAndTheInvite() {
        var state = BipeNewAccountScreenViewState(accountName: "Ana", canAddPersonal: true, maxPersonalAccounts: 2, showsCompany: true)
        #expect(state.isPersonalEnabled)
        #expect(state.isCompanyEnabled)
        #expect(state.inviteFooter == nil)
        
        state.invite = .available
        #expect(state.inviteFooter == BipeStrings.accountNewInviteNote("Ana"))
        
        state.creatingInviteFor = .personal
        #expect(!state.isPersonalEnabled)
        #expect(!state.isCompanyEnabled)
        
        state.creatingInviteFor = nil
        state.invite = .noneLeft(nextAvailableAt: nil)
        #expect(!state.isPersonalEnabled)
        #expect(!state.isCompanyEnabled)
        #expect(state.inviteFooter == BipeInviteQuota.noneLeft(nextAvailableAt: nil))
    }
    
    @Test
    func personalRowStopsAtTheCap() {
        let state = BipeNewAccountScreenViewState(accountName: "Ana", canAddPersonal: false, maxPersonalAccounts: 2, showsCompany: true)
        #expect(!state.isPersonalEnabled)
        #expect(state.isCompanyEnabled)
        #expect(state.personalBody == BipeStrings.accountCapReached("2"))
    }
    
    @Test
    func withoutAnInviteCreatorTheSignupAsksForTheCode() async throws {
        let viewModel = BipeNewAccountScreenViewModel(accountName: "Ana", canAddPersonal: true, maxPersonalAccounts: 2,
                                                      showsCompany: true, inviteCreator: nil)
        let deferred = deferFulfillment(viewModel.actionsPublisher) { $0 == .choose(.signUp(.company, inviteCode: nil)) }
        viewModel.context.send(viewAction: .signUp(.company))
        try await deferred.fulfill()
    }
}
