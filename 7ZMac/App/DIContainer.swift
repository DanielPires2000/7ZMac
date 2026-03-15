import Foundation

/// Lightweight Dependency Injection Container.
/// Register dependencies once at app launch, resolve them anywhere.
///
/// Usage:
/// ```swift
/// // Register
/// DIContainer.shared.register(ArchiveServiceProtocol.self) { SevenZipService() }
///
/// // Resolve
/// let service: ArchiveServiceProtocol = DIContainer.shared.resolve()
/// ```
@MainActor
final class DIContainer {
    
    static let shared = DIContainer()
    
    private var factories: [String: () -> Any] = [:]
    private var singletonKeys: Set<String> = []
    private var cache: [String: Any] = [:]
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register a factory that creates a new instance each time.
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    /// Register a singleton — the factory runs once, then the instance is cached.
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
        singletonKeys.insert(key)
    }
    
    // MARK: - Resolution
    
    /// Resolve a dependency. Crashes if the type was never registered (programming error).
    func resolve<T>(_ type: T.Type = T.self) -> T {
        let key = String(describing: type)
        
        // Return cached singleton if available
        if let cached = cache[key] {
            guard let instance = cached as? T else {
                fatalError("DIContainer: Type mismatch for \(key)")
            }
            return instance
        }
        
        // Create from factory
        guard let factory = factories[key] else {
            fatalError("DIContainer: No registration found for \(key). Did you forget to call register()?")
        }
        
        guard let instance = factory() as? T else {
            fatalError("DIContainer: Factory for \(key) returned wrong type")
        }
        
        // Cache if singleton
        if singletonKeys.contains(key) {
            cache[key] = instance
        }
        
        return instance
    }
    
    // MARK: - Testing Support
    
    /// Reset all registrations. Use in test setUp/tearDown.
    func reset() {
        factories.removeAll()
        singletonKeys.removeAll()
        cache.removeAll()
    }
}
