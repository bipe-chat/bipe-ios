//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import BipeKit
import Combine
import SwiftUI

typealias BipeNewAccountScreenViewModelType = StateStoreViewModelV2<BipeNewAccountScreenViewState, BipeNewAccountScreenViewAction>

/// Bipe: the "Nova conta" window (bipe#445, #446). It reads the invite quota on open and creates the invite only on the
/// first tap of a sign-up row, so a closed window spends no invite.
class BipeNewAccountScreenViewModel: BipeNewAccountScreenViewModelType, BipeNewAccountScreenViewModelProtocol {
    /// `nil` when the account on screen cannot make invites: the sign-up then shows its invite step.
    private let inviteCreator: BipeInviteCreator?
    
    private let actionsSubject: PassthroughSubject<BipeNewAccountScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<BipeNewAccountScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(accountName: String,
         canAddPersonal: Bool,
         maxPersonalAccounts: Int,
         showsCompany: Bool,
         inviteCreator: BipeInviteCreator?) {
        self.inviteCreator = inviteCreator
        super.init(initialViewState: BipeNewAccountScreenViewState(accountName: accountName,
                                                                   canAddPersonal: canAddPersonal,
                                                                   maxPersonalAccounts: maxPersonalAccounts,
                                                                   showsCompany: showsCompany))
        
        if inviteCreator != nil {
            Task { await loadQuota() }
        }
    }
    
    override func process(viewAction: BipeNewAccountScreenViewAction) {
        switch viewAction {
        case .signUp(let accountType):
            Task { await signUp(accountType) }
        case .signIn:
            actionsSubject.send(.choose(.signIn))
        case .cancel:
            actionsSubject.send(.dismiss)
        }
    }
    
    // MARK: - Private
    
    private func loadQuota() async {
        guard let inviteCreator else { return }
        do {
            let myInvites = try await inviteCreator.quota()
            guard state.invite == .unknown else { return } // A tap already made the invite.
            state.invite = myInvites.available > 0 ? .available : .noneLeft(nextAvailableAt: myInvites.nextAvailableAt)
        } catch {
            MXLog.error("Bipe invite quota failed: \(error)")
        }
    }
    
    private func signUp(_ accountType: BipeAccountType) async {
        guard accountType == .company ? state.isCompanyEnabled : state.isPersonalEnabled else { return }
        
        if case .created(let code) = state.invite {
            actionsSubject.send(.choose(.signUp(accountType, inviteCode: code)))
            return
        }
        guard let inviteCreator else {
            actionsSubject.send(.choose(.signUp(accountType, inviteCode: nil)))
            return
        }
        
        state.creatingInviteFor = accountType
        defer { state.creatingInviteFor = nil }
        
        do {
            switch try await inviteCreator.createIfAvailable() {
            case .created(let created):
                MXLog.info("Bipe invite created for a new account \(created)")
                guard let code = BipeInviteCode(created.code) else {
                    MXLog.error("Bipe created an invite with an invalid code")
                    actionsSubject.send(.choose(.signUp(accountType, inviteCode: nil)))
                    return
                }
                state.invite = .created(code)
                actionsSubject.send(.choose(.signUp(accountType, inviteCode: code)))
            case .noneLeft(let nextAvailableAt):
                state.invite = .noneLeft(nextAvailableAt: nextAvailableAt)
            }
        } catch {
            // The fallback: the sign-up asks for an invite code.
            MXLog.error("Bipe invite for a new account failed: \(error)")
            actionsSubject.send(.choose(.signUp(accountType, inviteCode: nil)))
        }
    }
}
