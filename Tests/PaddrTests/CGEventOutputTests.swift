#if canImport(CoreGraphics)
import CoreGraphics
import Synchronization
import XCTest
@testable import PaddrCore

final class CGEventOutputTests: XCTestCase {
    func testMouseButtonReleaseThrowsWhenCurrentLocationIsUnavailable() {
        let output = CGEventOutput(currentMouseLocation: { nil })

        XCTAssertThrowsError(
            try output.dispatch([.mouseButton(.left, isPressed: false)])
        ) { error in
            XCTAssertTrue(String(describing: error).contains("mouse location"))
        }
    }

    func testLeftButtonChangesMovementFromDragBackToMove() throws {
        let recorder = CGEventRequestRecorder()
        let output = makeOutput(recorder: recorder)

        try output.dispatch([
            .mouseButton(.left, isPressed: true),
            .mouseMove(dx: 4, dy: -3),
            .mouseButton(.left, isPressed: false),
            .mouseMove(dx: -2, dy: 5)
        ])

        XCTAssertEqual(recorder.requests, [
            .mouse(kind: .leftDown, button: .left, x: 100, y: 200),
            .mouse(kind: .leftDragged, button: .left, x: 104, y: 197, deltaX: 4, deltaY: -3),
            .mouse(kind: .leftUp, button: .left, x: 100, y: 200),
            .mouse(kind: .moved, button: .left, x: 98, y: 205, deltaX: -2, deltaY: 5)
        ])
    }

    func testRightButtonProducesRightDrag() throws {
        let recorder = CGEventRequestRecorder()
        let output = makeOutput(recorder: recorder)

        try output.dispatch([
            .mouseButton(.right, isPressed: true),
            .mouseMove(dx: 1.5, dy: 2.5)
        ])

        XCTAssertEqual(recorder.requests.last, .mouse(
            kind: .rightDragged,
            button: .right,
            x: 101.5,
            y: 202.5, deltaX: 1, deltaY: 2
        ))
    }

    func testLeftButtonTakesDragPrecedenceUntilReleased() throws {
        let recorder = CGEventRequestRecorder()
        let output = makeOutput(recorder: recorder)

        try output.dispatch([
            .mouseButton(.right, isPressed: true),
            .mouseButton(.left, isPressed: true),
            .mouseMove(dx: 2, dy: 3),
            .mouseButton(.left, isPressed: false),
            .mouseMove(dx: 6, dy: 7)
        ])

        XCTAssertEqual(recorder.requests[2], .mouse(
            kind: .leftDragged,
            button: .left,
            x: 102,
            y: 203, deltaX: 2, deltaY: 3
        ))
        XCTAssertEqual(recorder.requests[4], .mouse(
            kind: .rightDragged,
            button: .right,
            x: 106,
            y: 207, deltaX: 6, deltaY: 7
        ))
    }

    func testFailedButtonPostDoesNotChangeHeldButtonState() throws {
        let attempts = Mutex(0)
        let recorder = CGEventRequestRecorder()
        let output = CGEventOutput(
            currentMouseLocation: { CGPoint(x: 100, y: 200) },
            postEvent: { request in
                let shouldFail = attempts.withLock { count in
                    count += 1
                    return count == 1
                }
                if shouldFail { throw PaddrError.output("Injected post failure.") }
                recorder.record(request)
            }
        )

        XCTAssertThrowsError(try output.dispatch([.mouseButton(.left, isPressed: true)]))
        try output.dispatch([.mouseMove(dx: 1, dy: 1)])

        XCTAssertEqual(recorder.requests, [
            .mouse(kind: .moved, button: .left, x: 101, y: 201, deltaX: 1, deltaY: 1)
        ])
    }

    func testScrollAndKeyboardUseTheSameRequestSink() throws {
        let recorder = CGEventRequestRecorder()
        let output = makeOutput(recorder: recorder)
        let key = try KeyCatalog.resolve("a")

        try output.dispatch([
            .scroll(dx: 2.4, dy: -3.6),
            .key(key, isPressed: true)
        ])

        XCTAssertEqual(recorder.requests, [
            .scroll(horizontal: 2, vertical: -4),
            .key(code: key.keyCode, isPressed: true)
        ])
    }

    func testFractionalMapperStepsReachRequestSinkAsConservedIntegralScroll() throws {
        for sign in [1, -1] {
            let recorder = CGEventRequestRecorder()
            let output = makeOutput(recorder: recorder)
            var mapper = PadMapper(side: .left, configuration: .init(mode: .scroll, scrollSensitivity: 0.5))
            for step in 0...10 {
                let sample = TrackpadSample(isTouched: true, isClicked: false,
                    x: Int16(sign * step * 120), y: Int16(sign * step * 120), pressure: 0,
                    timestampNanoseconds: UInt64(step))
                try output.dispatch(try mapper.process(sample))
            }
            XCTAssertEqual(recorder.requests, [
                .scroll(horizontal: Int32(sign), vertical: Int32(-sign)),
                .scroll(horizontal: Int32(sign), vertical: Int32(-sign))
            ])
        }
    }

    func testRelativeDeltaFieldsSurviveCursorRecenteringAndPreserveFractionalSteps() throws {
        let recorder = CGEventRequestRecorder()
        let cursor = Mutex(CGPoint(x: 100, y: 200))
        let output = CGEventOutput(currentMouseLocation: { cursor.withLock { $0 } }, postEvent: recorder.record)
        for _ in 0..<5 { try output.dispatch([.mouseMove(dx: 0.25, dy: -0.25)]) }
        cursor.withLock { $0 = .zero }
        try output.dispatch([.mouseMove(dx: 2, dy: -3)])
        var xTotal: Int64 = 0
        var yTotal: Int64 = 0
        for request in recorder.requests {
            guard case let .mouse(_, _, _, _, dx, dy) = request else { return XCTFail("Expected mouse request") }
            xTotal += dx
            yTotal += dy
            let event = try CGEventOutput.makeLiveEvent(request)
            XCTAssertEqual(event.getIntegerValueField(.mouseEventDeltaX), dx)
            XCTAssertEqual(event.getIntegerValueField(.mouseEventDeltaY), dy)
        }
        XCTAssertEqual(xTotal, 3)
        XCTAssertEqual(yTotal, -4)
        XCTAssertEqual(recorder.requests.last,
            .mouse(kind: .moved, button: .left, x: 2, y: -3, deltaX: 2, deltaY: -3))
    }

    func testMotionResetDropsPriorEpochSubpointRemainder() throws {
        let recorder = CGEventRequestRecorder()
        let output = makeOutput(recorder: recorder)
        try output.dispatch([.mouseMove(dx: 0.75, dy: -0.75)])
        output.resetMouseMotion()
        try output.dispatch([.mouseMove(dx: 0.25, dy: -0.25)])
        XCTAssertEqual(recorder.requests.last,
            .mouse(kind: .moved, button: .left, x: 100.25, y: 199.75, deltaX: 0, deltaY: 0))
    }

    func testFractionalRelativeRemainderIsCommittedOnlyAfterSuccessfulPost() throws {
        let recorder = CGEventRequestRecorder()
        let attempts = Mutex(0)
        let output = CGEventOutput(currentMouseLocation: { .zero }, postEvent: { request in
            let count = attempts.withLock { $0 += 1; return $0 }
            if count == 2 { throw PaddrError.output("Injected move failure") }
            recorder.record(request)
        })
        try output.dispatch([.mouseMove(dx: 0.75, dy: -0.75)])
        XCTAssertThrowsError(try output.dispatch([.mouseMove(dx: 0.75, dy: -0.75)]))
        try output.dispatch([.mouseMove(dx: 0.25, dy: -0.25)])
        XCTAssertEqual(recorder.requests.last,
            .mouse(kind: .moved, button: .left, x: 0.25, y: -0.25, deltaX: 1, deltaY: -1))
        for bad in [Double.nan, .infinity, Double.greatestFiniteMagnitude] {
            XCTAssertThrowsError(try output.dispatch([.mouseMove(dx: bad, dy: 0)]))
        }
    }

    private func makeOutput(recorder: CGEventRequestRecorder) -> CGEventOutput {
        CGEventOutput(
            currentMouseLocation: { CGPoint(x: 100, y: 200) },
            postEvent: recorder.record
        )
    }
}

private final class CGEventRequestRecorder: Sendable {
    private let storage = Mutex<[CGEventRequest]>([])

    var requests: [CGEventRequest] { storage.withLock { $0 } }

    func record(_ request: CGEventRequest) {
        storage.withLock { $0.append(request) }
    }
}
#endif
