//
//  CallHistoryViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 25.07.2022.
//

import SwiftUI
import Combine
import MatrixSDK

class CallHistoryViewModel: ObservableObject {
    @Published private(set) var history = [CallHistoryItem]()
    @Published private(set) var isLoading = false
    @Published private(set) var isClearing = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() { }
    
    deinit {
        cancellables.removeAll()
    }
    
    func reload() {
        guard let accessToken = AuthViewModel.shared.session?.credentials.accessToken else { return }
        guard !isLoading && !isClearing else { return }
        isLoading = true
        NewApiManager.shared.getCallHistory(accessToken: accessToken)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    break
                case .failure(_):
                    self?.isLoading = false
                }
            } receiveValue: { [weak self] history in
                self?.history = history
                self?.isLoading = false
                // Update counter on tab bar (should reset to zero after getting history)
                AuthViewModel.shared.sessionVM?.updateMissed()
            }
            .store(in: &cancellables)
    }
    
    func clearHistory() {
        guard let accessToken = AuthViewModel.shared.session?.credentials.accessToken else { return }
        guard !isClearing else { return }
        isClearing = true
        NewApiManager.shared.clearCallHistory(accessToken: accessToken)
            .sink(receiveValue: { [weak self] success in
                self?.isClearing = false
                self?.reload()
            })
            .store(in: &cancellables)
    }
}
