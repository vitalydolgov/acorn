public enum DomainError: Error, Equatable {
    case invalidArgument(String)
    case invalidState(String)
    case deleted
}
