import Foundation
import Testing

extension Tag {
    @Tag static var integration: Self
}

extension Trait where Self == ConditionTrait {
    static var requiresLLM: Self {
        .enabled(
            if: ProcessInfo.processInfo.environment["ACORN_LLM_TESTS"] == "1",
            "set ACORN_LLM_TESTS=1 (and ANTHROPIC_API_KEY) to run paid LLM tests"
        )
    }
}
