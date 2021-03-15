

import Foundation

extension Result {
    public init(failure: Failure) {
        self = .failure(failure)
    }

    public init(success: Success) {
        self = .success(success)
    }

    public var successValue: Success? {
        switch self {
        case let .success(success): return success
        case .failure: return nil
        }
    }

    public var failureValue: Failure? {
        switch self {
        case .success: return nil
        case let .failure(error): return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    public var isFailure: Bool {
        switch self {
        case .success: return false
        case .failure: return true
        }
    }
}
