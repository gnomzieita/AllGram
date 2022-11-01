//
//  TermsViewModel.swift
//  AllGram
//
//  Created by Admin on 31.08.2021.
//

import Foundation
import MatrixSDK
import Combine


class TermsViewModel: ObservableObject {
    static let shared = TermsViewModel()
    
    /// The list of policies to be accepted by the end user
    @Published var policies: [MXLoginPolicyData] = []
    
    /// Policies already accepted by the end user
    @Published var policiesStates: [Bool] = [false]
    
    /// The index of the policy being displayed fullscreen within `TermsView`
    @Published var displayedPolicyIndex: Int?
    
    @Published var allPoliciesAccepted: Bool = false
    
    @Published private(set) var displayTerms: Bool = false
    
    //MARK:- Private proporties
    private var cancels = Set<AnyCancellable>()
    private var acceptedCallback: (() -> Void)?
    
    private var policiesCount: AnyPublisher<Int, Never> {
        $policies
            .map {$0.count}
            .eraseToAnyPublisher()
    }
    

    
    //MARK: - Init()
    private init() {
        $policiesStates
            .receive(on: RunLoop.main)
            .dropFirst()
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .map { !$0.contains(false) } // Do I have `false` in states
            .assign(to: \.allPoliciesAccepted, on: self)
            .store(in: &cancels)
        
        $allPoliciesAccepted
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [unowned self] accepted in
                if accepted {
                    guard let acceptedCallback = acceptedCallback else {
                        fatalError("All policies has been accepted, but acceptedCallback() function is NIL")
                    }
                    acceptedCallback()
                }
            }
            .store(in: &cancels)
    }
    
    //MARK: - Methods
    func getTerms(terms: MXLoginTerms, onAccepted: @escaping () -> Void) {
        acceptedCallback = onAccepted
        let language = Locale.current.languageCode
        
        policies = terms.policiesData(forLanguage: language, defaultLanguage: "en")
        policiesStates.removeAll()
    }
    
    func removePolicies() {
        displayedPolicyIndex = nil
    }
    
    func swapPolicyState(at index: Int) {
        policiesStates[index].toggle()
    }
    
}
