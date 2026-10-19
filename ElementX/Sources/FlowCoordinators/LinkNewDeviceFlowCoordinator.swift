//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import BipeKit
import Combine
import Foundation

enum LinkNewDeviceFlowCoordinatorAction {
    case requestOAuthAuthorisation(URL, OAuthAccountSettingsPresenter.Continuation)
    /// The user failed to remember their App Lock PIN.
    case forceLogout
    case dismiss
}

class LinkNewDeviceFlowCoordinator: FlowCoordinatorProtocol {
    private let navigationStackCoordinator: NavigationStackCoordinator
    private let appLockService: AppLockServiceProtocol
    private let flowParameters: CommonFlowParameters
    
    private var cancellables = Set<AnyCancellable>()
    
    private let actionsSubject: PassthroughSubject<LinkNewDeviceFlowCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<LinkNewDeviceFlowCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(navigationStackCoordinator: NavigationStackCoordinator,
         appLockService: AppLockServiceProtocol,
         flowParameters: CommonFlowParameters) {
        self.navigationStackCoordinator = navigationStackCoordinator
        self.appLockService = appLockService
        self.flowParameters = flowParameters
    }
    
    func start(animated: Bool) {
        presentLinkedDevicesScreen()
    }
    
    func handleAppRoute(_ appRoute: AppRoute, animated: Bool) {
        fatalError()
    }
    
    func clearRoute(animated: Bool) {
        fatalError()
    }
    
    // MARK: - Bipe (ADR 0116, ADR 0118)
    
    private var linkedDevicesCoordinator: BipeLinkedDevicesScreenCoordinator?
    
    private var bipeWebApprovalDependencies: BipeWebApprovalDependencies {
        let userSession = flowParameters.userSession
        return BipeWebApprovalDependencies(clientProxy: userSession.clientProxy,
                                           apiClient: BipeAPIClient(baseURL: userSession.userSettings.app.bipeAPIBaseURL),
                                           credentialStore: BipeCredentialStore(accessGroup: InfoPlistReader.main.keychainAccessGroupIdentifier))
    }
    
    /// Settings > Linked devices is the root. Only the desktop direction exists: the phone scans the browser's code.
    private func presentLinkedDevicesScreen() {
        let userSession = flowParameters.userSession
        let coordinator = BipeLinkedDevicesScreenCoordinator(parameters: .init(clientProxy: userSession.clientProxy,
                                                                               showsLinkComputer: userSession.userSettings.app.linkNewDeviceEnabled))
        coordinator.actionsPublisher
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .linkComputer:
                    presentQRCodeScreen(mode: .linkDesktop(flowParameters.userSession.clientProxy.linkNewDeviceService()))
                case .createPIN:
                    presentPINScreen()
                case .signOut(let deviceID):
                    presentSignOutScreen(deviceID: deviceID)
                case .dismiss:
                    actionsSubject.send(.dismiss)
                }
            }
            .store(in: &cancellables)
        
        linkedDevicesCoordinator = coordinator
        navigationStackCoordinator.setRootCoordinator(coordinator)
    }
    
    /// A beta account creates its PIN here. That gives this phone the hidden password, then the list checks again.
    private func presentPINScreen() {
        let userSession = flowParameters.userSession
        let coordinator = BipeAccountScreenCoordinator(parameters: .init(mode: .pin,
                                                                         apiClient: BipeAPIClient(baseURL: userSession.userSettings.app.bipeAPIBaseURL),
                                                                         clientProxy: userSession.clientProxy,
                                                                         appLockService: appLockService,
                                                                         userIndicatorController: flowParameters.userIndicatorController))
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .done:
                    self?.navigationStackCoordinator.pop()
                    self?.linkedDevicesCoordinator?.reload()
                }
            }
            .store(in: &cancellables)
        navigationStackCoordinator.push(coordinator)
    }
    
    /// Ends the session of a linked device on the MAS account page, in the private web view.
    private func presentSignOutScreen(deviceID: String) {
        let model = BipeWebApprovalModel(purpose: .signOut(deviceID: deviceID), dependencies: bipeWebApprovalDependencies)
        model.onFinished = { [weak self] in
            self?.navigationStackCoordinator.setSheetCoordinator(nil)
        }
        let stackCoordinator = NavigationStackCoordinator()
        stackCoordinator.setRootCoordinator(BipeWebApprovalScreenCoordinator(model: model))
        navigationStackCoordinator.setSheetCoordinator(stackCoordinator) { [weak self] in
            model.end()
            self?.linkedDevicesCoordinator?.reload()
        }
    }
    
    private func presentAppLockScreen(continuation: CheckedContinuation<Bool, Never>) {
        // We can use the AppLockScreen as a fallback here. It might seem weird but in the end it only calls
        // AppLockService.unlock which is a no-op when the app is already unlocked.
        let stackCoordinator = NavigationStackCoordinator()
        let coordinator = AppLockScreenCoordinator(parameters: .init(appLockService: appLockService, mode: .verifyDeviceOwner))
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .appUnlocked:
                    continuation.resume(returning: true)
                    navigationStackCoordinator.setFullScreenCoverCoordinator(nil)
                case .cancelVerifyDeviceOwner:
                    continuation.resume(returning: false)
                    navigationStackCoordinator.setFullScreenCoverCoordinator(nil)
                case .forceLogout:
                    continuation.resume(returning: false)
                    actionsSubject.send(.forceLogout)
                }
            }
            .store(in: &cancellables)
        
        stackCoordinator.setRootCoordinator(coordinator)
        navigationStackCoordinator.setFullScreenCoverCoordinator(stackCoordinator)
    }
    
    private func presentQRCodeScreen(mode: QRCodeLoginScreenMode) {
        let coordinator = QRCodeLoginScreenCoordinator(parameters: .init(mode: mode,
                                                                         canSignInManually: false, // No need to worry about this when linking a device.
                                                                         orientationManager: flowParameters.appMediator.windowManager,
                                                                         appMediator: flowParameters.appMediator,
                                                                         bipeWebApproval: bipeWebApprovalDependencies))
        coordinator.actionsPublisher
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .signInManually, .signedIn:
                    fatalError("QR linking shouldn't send sign-in actions.")
                case .startOver, .cancel:
                    navigationStackCoordinator.popToRoot() // Back to Linked devices.
                case .requestOAuthAuthorisation(let url, let continuation):
                    actionsSubject.send(.requestOAuthAuthorisation(url, continuation))
                case .linkedDevice:
                    navigationStackCoordinator.popToRoot()
                    linkedDevicesCoordinator?.reload()
                    flowParameters.userIndicatorController.submitIndicator(UserIndicator(title: BipeStrings.linkComputerDone, icon: \.checkCircle))
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
}
