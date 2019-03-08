import Foundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

/*
 * This is the end result for all the refactor steps
 */

//---------------------------------------------------

func compose<A,B,C>(_ f: @escaping (A) -> B, _ g: @escaping (B) -> C) -> (A) -> C {
    return {a in g(f(a)) }
}

precedencegroup CompositionPrecedence {
    associativity: left
}

infix operator >>>: CompositionPrecedence
infix operator >=>: CompositionPrecedence

func >>><A,B,C>(_ f: @escaping (A) -> B, _ g: @escaping (B) -> C) -> (A) -> C {
    return compose(f, g)
}

//---------------------------------------------------

extension String: Error {}

enum Result<T> {
    case success(T)
    case failure(Error)
}

extension Result {
    func map<U>(_ f: @escaping (T) -> U) -> Result<U> {
        switch self {
        case let .failure(e): return .failure(e)
        case let .success(t): return .success(f(t))
        }
    }
    
    func flatMap<U>(_ f: @escaping (T) -> Result<U>) -> Result<U> {
        switch self {
        case let .failure(e): return .failure(e)
        case let .success(t): return f(t)
        }
    }
}

func zip<A, B>(_ ra: Result<A>, _ rb: Result<B>) -> Result<(A,B)> {
    switch (ra, rb) {
    case let (.failure(e), _): return .failure(e)
    case let (_, .failure(e)): return .failure(e)
    case let (.success(a), .success(b)): return .success((a,b))
    }
}

//---------------------------------------------------

func compose<A,B,C>(_ f: @escaping (A) -> Result<B>, _ g: @escaping (B) -> Result<C>) -> (A) -> Result<C> {
    return {a in f(a).flatMap(g) }
}

func >=><A,B,C>(_ f: @escaping (A) -> Result<B>, _ g: @escaping (B) -> Result<C>) -> (A) -> Result<C> {
    return compose(f, g)
}

//---------------------------------------------------

struct FutureResult<T> {
    let run: (@escaping Callback<T>) -> Void
}

extension FutureResult {
    func map<U>(_ f: @escaping (T) -> U) -> FutureResult<U> {
        return FutureResult<U> { callback in
            self.run { result in callback(result.map(f)) }
        }
    }
    func map<U>(_ f: @escaping (T) -> Result<U>) -> FutureResult<U> {
        return FutureResult<U> { callback in
            self.run { result in callback(result.flatMap(f)) }
        }
    }
    
    func flatMap<U>(_ f: @escaping (T) -> FutureResult<U>) -> FutureResult<U> {
        return FutureResult<U> { callback in
            self.run { result in
                switch result {
                case let .failure(e): callback(.failure(e))
                case let .success(t): f(t).run(callback)
                }
            }
        }
    }
    
    func retry(upTo: Int) -> FutureResult<T> {
        return FutureResult<T> { callback in
            func tryFuture(_ f: FutureResult<T>, upTo remaining: Int) {
                f.run { result in
                    switch result {
                    case let .failure(e):
                        print(e)
                        guard remaining > 0 else { callback(.failure(e)); return }
                        tryFuture(f, upTo: remaining - 1)
                    case let .success(t):
                        callback(.success(t))
                    }
                }
            }
            tryFuture(self, upTo: upTo)
        }
    }
}

func zip<A,B>(_ fa: FutureResult<A>, _ fb: FutureResult<B>) -> FutureResult<(A,B)> {
    return FutureResult<(A,B)> { callback in
        var ra: Result<A>?
        var rb: Result<B>?
        let group = DispatchGroup()
        
        group.enter(); fa.run { ra = $0; group.leave() }
        group.enter(); fb.run { rb = $0; group.leave() }
        group.notify(queue: DispatchQueue.main, execute: { callback(zip(ra!, rb!)) })
    }
}

extension URLSession {
    func get(_ url: URL) -> FutureResult<Data> {
        return FutureResult<Data> { callback in
            self.dataTask(with: url, completion: callback)
        }
    }
}

//---------------------------------------------------

typealias Callback<T> = (Result<T>) -> Void

extension URLSession {    
    func dataTask(with url: URL, completion: @escaping Callback<Data>) {
        self.dataTask(with: url) { (data, response, error) in
            if let systemError = error {
                completion(.failure(systemError))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure("Malformed response"))
                return
            }
            guard 200..<400 ~= httpResponse.statusCode else {
                completion(.failure("Invalid response"))
                return
            }
            completion(.success(data ?? Data()))
        }.resume()
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
