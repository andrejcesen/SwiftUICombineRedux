//
//  Store.swift
//  SwiftUICombineRedux
//
//  Created by Andrej Česen on 11/09/2019.
//  Copyright © 2019 Andrej Česen. All rights reserved.
//

import Foundation
import Combine

final public class Store<State: FluxState>: ObservableObject {
    @Published public private(set) var state: State
    
    private var dispatchFunction: DispatchFunction!
    private let reducer: Reducer<State>
    private var cancellables: Set<AnyCancellable> = []
    
    public init(reducer: @escaping Reducer<State>,
                state: State,
                middleware: [Middleware<State>] = []) {
        self.reducer = reducer
        self.state = state
        
        self.dispatchFunction = middleware
            .reversed()
            .reduce(
                { [unowned self] action in
                    self.defaultDispatch(action: action) },
                { dispatchFunction, middleware in
                    let dispatch: (Action) -> Void = { [weak self] in self?.dispatch(action: $0) }
                    let getState = { [weak self] in self!.state }
                    let storeCancellable = { [weak self] in self!.storeCancellable(cancellable: $0) }
                    return middleware(dispatch, getState, storeCancellable)(dispatchFunction)
            })
    }
    
    public func storeCancellable(cancellable: AnyCancellable) {
        self.cancellables.insert(cancellable)
    }
    
    public func dispatch(action: Action) {
        // publishing changes from background threads to SwiftUI views is not allowed
        DispatchQueue.main.async {
            self.dispatchFunction(action)
        }
    }
    
    private func defaultDispatch(action: Action) {
        state = reducer(state, action)
    }
}
