//
//  Reducer.swift
//  SwiftUICombineRedux
//
//  Created by Andrej Česen on 11/09/2019.
//  Copyright © 2019 Andrej Česen. All rights reserved.
//

import Foundation

public typealias Reducer<State> =
    (_ state: State, _ action: Action) -> State
