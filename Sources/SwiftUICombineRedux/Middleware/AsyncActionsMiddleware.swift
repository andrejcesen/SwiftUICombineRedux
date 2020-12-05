//
//  AsyncActionsMiddleware.swift
//  
//
//  Created by Andrej Česen on 17/09/2019.
//

import Foundation

public let asyncActionsMiddleware: Middleware<FluxState> = { dispatch, getState, _ in
    return { next in
        return { action in
            if let action = action as? AsyncAction {
                action.execute(state: getState(), dispatch: dispatch)
            }
            return next(action)
        }
    }
}
