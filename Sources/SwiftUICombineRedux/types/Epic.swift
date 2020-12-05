//
//  File.swift
//  
//
//  Created by Andrej Česen on 22/09/2019.
//

import Combine
import Foundation

public typealias Epic<State> =
    (AnyPublisher<Action, Never>, CurrentValueSubject<State, Never>) -> AnyPublisher<Action, Never>

public typealias EpicMiddleware<State> = Middleware<State>
