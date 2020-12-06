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
    @ObservedObject var store: Store<TestState>
    
    var count: Int {
        store.state.count
    }
    
    func onIncrementIfOdd() {
        store.dispatch(action: AppAction.incrementIfOdd)
    }
    
    var body: some View {
        VStack {
            Text("\(count)")
            Button(action: {
                self.onIncrementIfOdd()
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
                return statePublisher.value.count % 2 == 1
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
        
        let epicMiddleware: EpicMiddleware<TestState> = createEpicMiddleware(with: rootEpic)
        let store = Store(reducer: testReducer, state: TestState(), middleware: [epicMiddleware])
        return store
    }()
    
    func testStore() {
        let expectations = [
            XCTestExpectation(description: "dispatch increment action"),
            XCTestExpectation(description: "dispatch incrementIfOdd action"),
            XCTestExpectation(description: "dispatch incrementIfOdd noop action"),
        ]
        
        XCTAssert(store.state.count == 0, "Initial state is not valid")
        
        store.dispatch(action: AppAction.increment)
        DispatchQueue.main.async {
            XCTAssert(self.store.state.count == 1, "Reduced state increment is not valid")
            expectations[0].fulfill()
            
            self.store.dispatch(action: AppAction.incrementIfOdd)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssert(self.store.state.count == 2, "Reduced state incrementIfOdd is not valid")
                expectations[1].fulfill()
                
                self.store.dispatch(action: AppAction.incrementIfOdd)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    XCTAssert(self.store.state.count == 2, "Reduced state incrementIfOdd noop is not valid")
                    expectations[2].fulfill()
                }
            }
        }
        wait(for: expectations, timeout: 1)
    }
    
    func testViewIntegration() {
        let expectations = [
            XCTestExpectation(description: "dispatch increment action"),
            XCTestExpectation(description: "dispatch incrementIfOdd action")
        ]
        
        XCTAssert(store.state.count == 0, "Initial state is not valid")
        
        let view: TestView = TestView(store: store)
        store.dispatch(action: AppAction.increment)
        DispatchQueue.main.async {
            XCTAssert(view.count == 1, "Reduced state increment is not valid")
            expectations[0].fulfill()
            
            self.store.dispatch(action: AppAction.incrementIfOdd)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssert(view.count == 2, "Reduced state incrementIfOdd is not valid")
                expectations[1].fulfill()
            }
        }
        
        wait(for: expectations, timeout: 1)
    }
    
    static var allTests = [
        ("testStore", testStore),
        ("testViewIntegration", testViewIntegration),
    ]
}
