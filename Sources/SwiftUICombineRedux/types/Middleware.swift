//
//  Middleware.swift
//  SwiftUICombineRedux
//
//  Created by Andrej Česen on 12/09/2019.
//  Copyright © 2019 Andrej Česen. All rights reserved.
//

public typealias DispatchFunction = (Action) -> Void
public typealias Middleware<State> = (@escaping DispatchFunction, @escaping () -> State)
    -> (@escaping DispatchFunction) -> DispatchFunction
