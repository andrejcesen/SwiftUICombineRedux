//
//  AsyncAction.swift
//  
//
//  Created by Andrej Česen on 17/09/2019.
//

import Foundation

public protocol AsyncAction: Action {
    func execute(state: FluxState?, dispatch: @escaping DispatchFunction)
}
