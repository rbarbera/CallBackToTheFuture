import Foundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

/*
 * Did you attend to the talk? so, this should be easy ;)
 * - All the types are right (Result<T>, FutureResult<T>) :)
 * - All function signatures are right, you only must provide the implementation
 * - Good luck and don't cheat, please ;)
 */

//---------------------------------------------------

func compose<A,B,C>(_ f: @escaping (A) -> B, _ g: @escaping (B) -> C) -> (A) -> C {
    fatalError()
}

precedencegroup CompositionPrecedence {
    associativity: left
}

infix operator >>>: CompositionPrecedence
infix operator >=>: CompositionPrecedence

func >>><A,B,C>(_ f: @escaping (A) -> B, _ g: @escaping (B) -> C) -> (A) -> C {
    fatalError()
}

//---------------------------------------------------

extension String: Error {}

enum Result<T> {
    case success(T)
    case failure(Error)
}

extension Result {
    func map<U>(_ f: @escaping (T) -> U) -> Result<U> {
        fatalError()
    }
    
    func flatMap<U>(_ f: @escaping (T) -> Result<U>) -> Result<U> {
        fatalError()
    }
}

func zip<A, B>(_ ra: Result<A>, _ rb: Result<B>) -> Result<(A,B)> {
    fatalError()
}

//---------------------------------------------------

func compose<A,B,C>(_ f: @escaping (A) -> Result<B>, _ g: @escaping (B) -> Result<C>) -> (A) -> Result<C> {
    fatalError()
}

func >=><A,B,C>(_ f: @escaping (A) -> Result<B>, _ g: @escaping (B) -> Result<C>) -> (A) -> Result<C> {
    fatalError()
}

//---------------------------------------------------

struct FutureResult<T> {
    let run: (@escaping Callback<T>) -> Void
}

extension FutureResult {
    func map<U>(_ f: @escaping (T) -> U) -> FutureResult<U> {
        fatalError()
    }
    
    func map<U>(_ f: @escaping (T) -> Result<U>) -> FutureResult<U> {
        fatalError()
    }
    
    func flatMap<U>(_ f: @escaping (T) -> FutureResult<U>) -> FutureResult<U> {
        fatalError()
    }
    
    func retry(upTo: Int) -> FutureResult<T> {
        fatalError()
    }
}

func zip<A,B>(_ fa: FutureResult<A>, _ fb: FutureResult<B>) -> FutureResult<(A,B)> {
    fatalError()
}

extension URLSession {
    func get(_ url: URL) -> FutureResult<Data> {
        fatalError()
    }
}

//---------------------------------------------------

typealias Callback<T> = (Result<T>) -> Void

extension URLSession {
    func dataTask(with url: URL, completion: @escaping Callback<Data>) {
        fatalError()
    }
}

//---------------------------------------------------

func toUTF8(_ data: Data) -> Result<String> {
    guard let string = String(data: data, encoding: .utf8) else {
        return .failure("No UTF-8 content")
    }
    return .success(string)
}

func wc(_ string: String) -> Result<Int> {
    return .success(string.split(separator: " ").count)
}

func trace<T>(_ value: T) -> T {
    return value
}

func firstLink(_ input: String) -> Result<URL> {
    guard let regex = try? NSRegularExpression(pattern: "href=\\\"(http[^\\\"]+)\\\"", options: []) else {
        return .failure("Invalid pattern")
    }
    guard
        let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..<input.endIndex, in: input)),
        let range = Range(match.range(at: 1), in: input) else {
            return .failure("Link not found")
    }
    
    let urlString = String(input[range])
    guard let url = URL(string: urlString) else {
        return .failure("Invalid URL")
    }
    return .success(url)
}

func upTo(_ x: Int) -> Result<Int> {
    return .success(Int.random(in: 0..<x))
}

func multiplier(_ n: Int) -> (Int) -> Result<Int> {
    return { x in
        x % n == 0
            ? .success(x)
            : .failure("Invalid \(x) % \(n) == \(x % n)")
    }
}

//---------------------------------------------------

let u1 = URL(string: "http://example.com")!
let u2 = URL(string: "http://apple.com")!

let wcFirstLink = { url in
    URLSession.shared.get(url)
        .map(toUTF8 >=> firstLink)
        .flatMap(URLSession.shared.get)
        .map(toUTF8 >=> wc >=> upTo)
}

let f1 = wcFirstLink(u1)
let f2 = wcFirstLink(u2)

let wow = zip(f1,f2)
    .map(+)
    .map(multiplier(13))
    .retry(upTo: 1000)


wow.run { result in
    switch result {
    case let .failure(e): print(e)
    case let .success(v): print(v)
    }
}
