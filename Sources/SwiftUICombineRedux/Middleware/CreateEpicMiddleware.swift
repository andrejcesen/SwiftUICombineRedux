//
//  CreateEpicMiddleware.swift
//  SwiftUICombineRedux
//
//  Created by Andrej Česen on 12/09/2019.
//  Copyright © 2019 Andrej Česen. All rights reserved.
//

import Combine
import Foundation

public func createEpicMiddleware<State>(with rootEpic: @escaping Epic<State>) -> EpicMiddleware<State> {
    let epicSubject = PassthroughSubject<Epic<State>, Never>()
    
    let epicMiddleware: Middleware<State> = { dispatch, getState, storeCancellable in
        let actionSubject = PassthroughSubject<Action, Never>()
        let stateSubject = CurrentValueSubject<State, Never>(getState())
        
        let actionPublisher = actionSubject.eraseToAnyPublisher()
        // no statePublisher, as Combine does not yet support withLatestFrom operator,
        // which is used for getting latest state in epic
        
        return { next in
            let epicCancellable = epicSubject
                .flatMap { epic in epic(actionPublisher, stateSubject) }
                .sink { action in dispatch(action) }
            
            // store cancellable reference in Store object (RAII fashion)
            // as capturing in closure releases it immediately
            storeCancellable(epicCancellable)
            
            // start me up :)
            epicSubject.send(rootEpic)
            
            return { action in
                // run actions through downstream middleware first (which includes reducers)
                // before publishers receive them
                let result: Void = next(action)
                
                // state subject needs to be updated before we send the action
                // because otherwise it would be stale
                stateSubject.send(getState())
                actionSubject.send(action)
                
                return result
            }
        }
    }
    
    return epicMiddleware
}
