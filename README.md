# SwiftUICombineRedux

Redux implementation with Combine-based middleware for unidirectional handling of side effects. Inspired by [redux-observable](https://redux-observable.js.org).

## Introduction

The main idea behind SwiftUICombineRedux is in leveraging Apple's Combine Framework to handle complex asynchronous events in a way that lets you push side effects to the edges of the system, which helps you write more predictable and maintainable code. As a bonus, this also makes testing substantially simpler by enabling you to reduce the amount of mocks to a minimum.

The core building block is an *Epic*, which is a function that takes an action Publisher (along with an optional state Publisher) and returns an action Publisher.

Actions delivered from Epics are immediately dispatched through Redux's Store instance, which in turn triggers its reducers. Epics are delivered actions *after* reducers have already processed them.

## Example

```swift
let pingEpic: Epic<TestState> = { actionPublisher, statePublisher in
    actionPublisher
        .filter { $0 is AppAction.ping }
        .map { _ in AppAction.pong() }
        .eraseToAnyPublisher()
}
```

`pingEpic` simply maps each `ping` action to a `pong` action.


> This should give you a basic idea on how to define epics. You can check [tests](Tests/SwiftUICombineReduxTests/SwiftUICombineReduxTests.swift) for additional examples.

## Setup

First, add SwiftUICombineRedux as a Swift Package Dependency in Xcode by going to `File > Swift Packages > Add Package Dependency...` and point it to this repo's URL.

Next, we need to setup Redux:

```swift
import SwiftUICombineRedux

// MARK: State
struct AppState: FluxState {
    var symbolsState = SymbolsState()
}

struct SymbolsState {
    var symbols: [String: Symbol] = [:]
}

struct Symbol {
    let id: String
    var price: Decimal?
}

// MARK: Reducers
func appStateReducer(state: AppState, action: Action) -> AppState {
    var state = state
    state.symbolsState = symbolsStateReducer(state: state.symbolsState, action: action)
    return state
}

func symbolsStateReducer(state: SymbolsState, action: Action) -> SymbolsState {
    var state = state

    switch action {
    case let action as SymbolsActions.fetchSymbolPriceRequestSuccess:
        state.symbols[action.id, default: Symbol(id: action.id)].price = action.price

    default:
        break
    }

    return state
}

// MARK: Actions
struct SymbolsActions {
    struct fetchSymbolPriceRequest: Action {
        let id: String
    }
    struct fetchSymbolPriceRequestSuccess: Action {
        let id: String
        let price: Decimal
    }
    struct fetchSymbolPriceRequestFailure: Action {
        let error: Error
    }
}
```

Then we define Epics:

```swift
import Combine
import SwiftUICombineRedux

// MARK: Epics
struct PricePayload: Codable {
    let price: Decimal
}

let fetchSymbolPriceEpic: Epic<AppState> = { actionPublisher, statePublisher in
    actionPublisher
        .filter { $0 is SymbolsActions.fetchSymbolPriceRequest }
        .map { $0 as! SymbolsActions.fetchSymbolPriceRequest }
        .map { request -> AnyPublisher<Action, Never> in
            URLSession.shared.dataTaskPublisher(for: APIRequest.symbolPrice(symbolId: request.id).urlRequest())
                .tryMap { element -> Data in
                    guard let httpResponse = element.response as? HTTPURLResponse,
                          200..<300 ~= httpResponse.statusCode else {
                        throw URLError(.badServerResponse)
                    }
                    return element.data
                }
                // decode can fail with Error
                .decode(type: PricePayload.self, decoder: JSONDecoder())
                .map { SymbolsActions.fetchSymbolPriceRequestSuccess(id: request.id, price: $0.price) }
                .catch { Just(SymbolsActions.fetchSymbolPriceRequestFailure(error: $0)) }
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
}

let rootEpic: Epic<AppState> = combineEpics(
    fetchSymbolPriceEpic
    // ...
)
```
> `combineEpics` is a helper function that effectively merges passed Epics into a single Epic.


And finally, let's add all of the pieces together:

```swift
import Combine
import SwiftUI
import SwiftUICombineRedux

// MARK: Views
struct ContentView: View {
    @StateObject var store: Store<AppState> = {
        let epicMiddleware: EpicMiddleware<AppState> = createEpicMiddleware(with: rootEpic)
        return Store(reducer: appStateReducer,
                     state: AppState(),
                     middleware: [epicMiddleware])
    }()

    var body: some View {
        SymbolList()
            .environmentObject(store)
    }
}

struct SymbolDetail {
    @EnvironmentObject var store: Store<AppState>
    let symbolId: String

    var symbol: Symbol? { store.state.symbolsState.symbols[symbolId] }
    var symbolName: String { symbol?.id ?? "" }

    var body: some View {
        List {
            Text(symbolName)
            // ...
        }
    }
}
```
> `@StateObject` has perfect semantics to store Redux Store, as it keeps its instance around for the duration of a (root) component.

🎉 And that's it! 🎉

Enjoy using *SwiftUICombineRedux* to conjure up something awesome in your next app. 😊

