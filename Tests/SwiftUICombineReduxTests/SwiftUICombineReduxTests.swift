import XCTest
import SwiftUI
import Combine
@testable import SwiftUICombineRedux

struct TestState: FluxState {
    var count = 0
    var isPinging = false
}

enum AppAction: Action {
    case increment
    case incrementIfOdd
    case ping
    case pong
}

func testReducer(state: TestState, action: Action) -> TestState {
    var state = state
    switch action {
    case AppAction.increment:
        state.count += 1
    case AppAction.ping:
        state.isPinging = true
    case AppAction.pong:
        state.isPinging = false
    default:
        break
    }
    return state
}

struct TestView : View {
    @EnvironmentObject var store: Store<TestState>
    
    var count: Int {
        store.state.count
    }
    
    var body: some View {
        VStack {
            Text("\(count)")
            Button(action: {
                self.store.dispatch(action: AppAction.increment)
            }) {
                Text("Increment")
            }
        }
    }
}

final class SwiftUICombineReduxTests: XCTestCase {
    let store: Store<TestState> = {
        let pingEpic: Epic<TestState> = { actionPublisher, statePublisher in
            actionPublisher
                .filter { action in
                    if case AppAction.ping = action {
                        return true
                    }
                    return false
            }
            .map { action in
                AppAction.pong
            }
            .eraseToAnyPublisher()
        }
        
        let incrementIfOddEpic: Epic<TestState> = { actionPublisher, statePublisher in
            actionPublisher
                .filter { action in
                    if case AppAction.incrementIfOdd = action {
                        return true
                    }
                    return false
            }
            .filter { action in
                guard let count = statePublisher.value?.count else { return false }
                return count % 2 == 1
            }
            .map { action in
                return AppAction.increment
            }
            .eraseToAnyPublisher()
        }
        
        let rootEpic: Epic<TestState> = { actionPublisher, statePublisher in
            Publishers.Merge(pingEpic(actionPublisher, statePublisher),
                             incrementIfOddEpic(actionPublisher, statePublisher))
                .eraseToAnyPublisher()
        }
        
        let epicMiddleware: EpicMiddleware<TestState> = createEpicMiddleware()
        let store = Store(reducer: testReducer, state: TestState(), middleware: [epicMiddleware.epicMiddleware])
        epicMiddleware.run(rootEpic)
        return store
    }()
    
    func testStore() {
        XCTAssert(store.state.count == 0, "Initial state is not valid")
        
        store.dispatch(action: AppAction.incrementIfOdd)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.store.state.count, 0, "Reduced state increment is not valid")
            
            // synchronous action
            self.store.dispatch(action: AppAction.increment)
            DispatchQueue.main.async {
                XCTAssertEqual(self.store.state.count, 1, "Reduced state increment is not valid")
            }
            
            self.store.dispatch(action: AppAction.incrementIfOdd)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(self.store.state.count, 2, "Reduced state increment is not valid")
                
                self.store.dispatch(action: AppAction.ping)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    XCTAssertEqual(self.store.state.isPinging, true, "Reduced state increment is not valid")
                    
                    self.store.dispatch(action: AppAction.pong)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        XCTAssertEqual(self.store.state.isPinging, false, "Reduced state increment is not valid")
                    }
                }
            }
        }
    }
    
    static var allTests = [
        ("testExample", testStore),
    ]
}
