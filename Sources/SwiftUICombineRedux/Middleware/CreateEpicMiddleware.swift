//
//  CreateEpicMiddleware.swift
//  SwiftUICombineRedux
//
//  Created by Andrej Česen on 12/09/2019.
//  Copyright © 2019 Andrej Česen. All rights reserved.
//

import Combine
import Foundation

public func createEpicMiddleware<State>() -> EpicMiddleware<State> {
    let epicSubject = PassthroughSubject<Epic<State>, Never>()
    let run = { (rootEpic: @escaping Epic<State>) -> Void in epicSubject.send(rootEpic) }
    let epicMiddleware: Middleware<State> = { dispatch, getState in
        let actionSubject = PassthroughSubject<Action, Never>()
        let stateSubject = CurrentValueSubject<State, Never>(getState())
        
        let actionPublisher = actionSubject.eraseToAnyPublisher()
        // no statePublisher, as Combine does not yet support withLatestFrom operator,
        // which is used for getting latest state in epic
        
        let resultSubject = epicSubject.flatMap { epic in
            return epic(actionPublisher, stateSubject)
        }
        let _ = resultSubject.sink { action in
            dispatch(action)
        }
        
        return { next in
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
    
    return (run, epicMiddleware)
}
