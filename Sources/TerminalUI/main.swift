//
//  Created by Denis Koryttsev on 08.07.2022.
//

import Foundation
import CoreUI

class ViewNode {
    let id: String
    var childIds: Set<String> = [] // avoid separated collections
    var children: [ViewNode] = [] // move to ConcreteViewNode? // should be ordered, because ZStack rendering will fail
    var next: ViewNode?
    var rect: Rect = .zero
    init(id: String) {
        self.id = id
    }

    func child(with id: String) -> ViewNode? {
        guard childIds.contains(id) else { return nil }
        return children.first(where: { $0.id == id })
    }
    func addChildren(_ nodes: [ViewNode]) {
        for child in nodes {
            child.next = self
            childIds.insert(child.id)
            children.append(child)
        }
    }

    func render(to buffer: inout OutputString, in rect: Rect) {
        for child in children {
            child.render(to: &buffer, in: rect)
        }
    }

    func keyDown(_ keyCode: UInt8) {
        for child in children {
            child.keyDown(keyCode)
        }
    }
    func mouseEvent(_ event: MEVENT) {
        for child in children {
            child.mouseEvent(event)
        }
    }
    var canBecomeFirstResponder: Bool { false }
    @discardableResult
    func becomeFirstResponder() -> Bool { false }
    @discardableResult
    func resignFirstResponder() -> Bool { true }
}
final class ConcreteViewNode<V>: ViewNode where V: View {
    var view: V
    var _needsUpdate: Bool = false
    init(id: String, view: V) {
        self.view = view
        super.init(id: id)
    }
    override func render(to buffer: inout OutputString, in rect: Rect) {
        var interpolation = V.Body.ViewInterpolation(view.body)
        let result = interpolation.build(with: BuildInputs(id: id, parent: self, rect: rect), buffer: &buffer)
        self.rect = result.rect
        children.removeAll(keepingCapacity: true)
        childIds.removeAll(keepingCapacity: true)
        addChildren(result.nodes)
    }
}

protocol View {
    associatedtype ViewInterpolation: ViewInterpolationProtocol = DefaultViewInterpolation<Self> where ViewInterpolation.View == Self
    associatedtype Body: View = Never
    @ViewBuilder var body: Body { get }
}

protocol ViewModifier {
    func modify<Container>(content: inout Container) where Container: ViewModifications
}
struct InterpolationResult {
    var rect: Rect
    var nodes: [ViewNode] = []
}
struct BuildInputs {
    let id: String
    let parent: ViewNode
    let rect: Rect
}
protocol ViewInterpolationProtocol {
    associatedtype View
    init(_ view: View)
    mutating func modify<M>(_ modifier: M) where M: ViewModifier
    typealias Result = InterpolationResult
    mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> Result
    var subviewsCount: Int { get }
    mutating func build(with inputs: BuildInputs, buffer: inout OutputString, at position: Int) -> Result
}
extension ViewInterpolationProtocol {
    func modify<M>(_ modifier: M) where M: ViewModifier {}
    var subviewsCount: Int { 1 }
    mutating func build(with inputs: BuildInputs, buffer: inout OutputString, at position: Int) -> Result {
        build(with: inputs, buffer: &buffer)
    }
}

struct DefaultViewInterpolation<V>: ViewInterpolationProtocol where V: View {
    typealias View = V
    let view: View
    var base: View.Body.ViewInterpolation
    init(_ view: View) {
        self.view = view
        self.base = View.Body.ViewInterpolation(view.body)
    }
    mutating func modify<M>(_ modifier: M) where M : ViewModifier {
        base.modify(modifier)
    }
    mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
        guard let node = inputs.parent.child(with: inputs.id) else {
            let node = ConcreteViewNode<V>(id: inputs.id, view: view)
            let baseResult = base.build(with: BuildInputs(id: inputs.id, parent: node, rect: inputs.rect), buffer: &buffer)
            node.rect = baseResult.rect
            node.addChildren(baseResult.nodes)
            return Result(rect: baseResult.rect, nodes: [node])
        }
        node.render(to: &buffer, in: inputs.rect)
        return Result(rect: node.rect, nodes: [node])
    }
}

extension Never: View {}
extension View where Body == Never {
    var body: Never { fatalError() }
}
extension NullView: View {
    struct ViewInterpolation: ViewInterpolationProtocol {
        init(_ _: NullView) {}
        func build(with _: BuildInputs, buffer _: inout OutputString) -> InterpolationResult {
            InterpolationResult(rect: .zero)
        }
    }
}
@_spi(Terminal)
extension Optional: View where Wrapped: View {
    struct ViewInterpolation: ViewInterpolationProtocol {
        typealias View = Optional<Wrapped>
        var base: Wrapped.ViewInterpolation?
        init(_ view: Optional<Wrapped>) {
            self.base = view.map(Wrapped.ViewInterpolation.init)
        }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            base?.modify(modifier)
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            base?.build(with: inputs, buffer: &buffer) ?? Result(rect: .zero)
        }
        var subviewsCount: Int { base?.subviewsCount ?? 0 }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString, at position: Int) -> InterpolationResult {
            base?.build(with: inputs, buffer: &buffer, at: position) ?? InterpolationResult(rect: .zero)
        }
    }
}
extension _ConditionalContent: View where TrueContent: View, FalseContent: View {
    struct ViewInterpolation: ViewInterpolationProtocol {
        public typealias View = _ConditionalContent<TrueContent, FalseContent>
        enum Condition {
        case first(TrueContent.ViewInterpolation)
        case second(FalseContent.ViewInterpolation)
        }
        var base: Condition
        public init(_ view: _ConditionalContent<TrueContent, FalseContent>) {
            switch view.condition {
            case .first(let first): self.base = .first(TrueContent.ViewInterpolation(first))
            case .second(let second): self.base = .second(FalseContent.ViewInterpolation(second))
            }
        }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            switch base {
            case .first(var trueContent):
                trueContent.modify(modifier)
                self.base = .first(trueContent)
            case .second(var falseContent):
                falseContent.modify(modifier)
                self.base = .second(falseContent)
            }
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            switch base {
            case .first(var trueContent):
                return trueContent.build(with: BuildInputs(id: inputs.id + "A", parent: inputs.parent, rect: inputs.rect), buffer: &buffer)
            case .second(var falseContent):
                return falseContent.build(with: BuildInputs(id: inputs.id + "B", parent: inputs.parent, rect: inputs.rect), buffer: &buffer)
            }
        }
        var subviewsCount: Int {
            switch base {
            case .first(let trueContent): return trueContent.subviewsCount
            case .second(let falseContent): return falseContent.subviewsCount
            }
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString, at position: Int) -> InterpolationResult {
            switch base {
            case .first(var trueContent): return trueContent.build(with: inputs, buffer: &buffer, at: position)
            case .second(var falseContent): return falseContent.build(with: inputs, buffer: &buffer, at: position)
            }
        }
    }
}
extension _ModifiedContent: View where Content: View, Modifier: ViewModifier {
    struct ViewInterpolation: ViewInterpolationProtocol {
        public typealias View = _ModifiedContent<Content, Modifier>
        var base: Content.ViewInterpolation
        init(_ view: _ModifiedContent<Content, Modifier>) {
            self.base = Content.ViewInterpolation(view.content)
            self.base.modify(view.modifier)
        }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            base.modify(modifier)
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            base.build(with: inputs, buffer: &buffer)
        }
        var subviewsCount: Int { base.subviewsCount }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString, at position: Int) -> InterpolationResult {
            base.build(with: inputs, buffer: &buffer, at: position)
        }
    }
}
extension View {
    public func modifier<T>(_ modifier: T) -> _ModifiedContent<Self, T> {
        _ModifiedContent(self, modifier: modifier)
    }
}

///

protocol ViewModifications {
    var attributes: OutputString.Attributes { set get }
    var rect: Rect { set get }
}
extension ViewModifications {
    var attributes: OutputString.Attributes { set {} get { .init() } }
    var rect: Rect { set {} get { .zero } }
}
struct EmptyViewModifications: ViewModifications {}
struct DefaultViewModifications: ViewModifications {
    var attributes: OutputString.Attributes = OutputString.Attributes()
    var rect: Rect = .unspecified
}
struct PositioningViewModifications: ViewModifications {
    var rect: Rect = .unspecified
}

struct TupleView<T>: View {
    let count: Int
    let build: (BuildInputs, inout OutputString, Int) -> InterpolationResult
    init(count: Int, _ build: @escaping (BuildInputs, inout OutputString, Int) -> InterpolationResult) {
        self.count = count
        self.build = build
    }
    struct ViewInterpolation: ViewInterpolationProtocol {
        typealias View = TupleView<T>
        let view: TupleView<T>
        init(_ view: TupleView<T>) { self.view = view }
        func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult { // TODO: Default layout should VStack
            var result = InterpolationResult(rect: .null, nodes: [])
            for i in 0 ..< view.count {
                let r = view.build(inputs, &buffer, i)
                result.rect = result.rect.union(r.rect)
                result.nodes.append(contentsOf: r.nodes)
            }
            return result
        }
        var subviewsCount: Int { view.count }
        func build(with inputs: BuildInputs, buffer: inout OutputString, at position: Int) -> InterpolationResult {
            view.build(inputs, &buffer, position)
        }
    }
}
extension ViewBuilder {
    static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)> where C0: View, C1: View {
        TupleView(count: 2) { inputs, buf, index in
            switch index {
            case 0:
                var c0i = C0.ViewInterpolation(c0)
                return c0i.build(with: BuildInputs(id: inputs.id + "0", parent: inputs.parent, rect: inputs.rect), buffer: &buf)
            case 1:
                var c1i = C1.ViewInterpolation(c1)
                return c1i.build(with: BuildInputs(id: inputs.id + "1", parent: inputs.parent, rect: inputs.rect), buffer: &buf)
            default: fatalError("Index out of range")
            }
        }
    }
}

extension Color: View {
    struct ViewInterpolation: ViewInterpolationProtocol {
        let view: Color
        var values = PositioningViewModifications()
        init(_ view: Color) { self.view = view }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            modifier.modify(content: &values)
        }
        func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            let origin = inputs.rect.origin.offset(x: values.rect.origin.x, y: values.rect.origin.y)
            let size: Size
            if values.rect.size == .unspecified {
                size = inputs.rect.size
            } else {
                size = values.rect.size
            }
            buffer.setChars(
                String(repeating: " ", count: size.length),
                attributes: OutputString.Attributes(background: view),
                in: origin, size: size
            )
            return InterpolationResult(rect: Rect(origin: origin, size: size))
        }
    }
}
struct Text: View {
    let value: String
    init(_ value: String) { self.value = value }
    struct ViewInterpolation: ViewInterpolationProtocol {
        let view: Text
        var values = DefaultViewModifications()
        init(_ view: Text) { self.view = view }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            modifier.modify(content: &values)
        }
        func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            let origin = inputs.rect.origin.offset(x: values.rect.origin.x, y: values.rect.origin.y)
            let size: Size
            if values.rect.size == .unspecified {
                let calcHeight = view.value.count.quotientAndRemainder(dividingBy: inputs.rect.size.width)
                size = Size(width: min(view.value.count, inputs.rect.size.width), height: min(inputs.rect.size.height, calcHeight.quotient + (calcHeight.remainder > 0 ? 1 : 0)))
            } else {
                size = values.rect.size
            }
            buffer.setChars(view.value, attributes: values.attributes, in: origin, size: size)
            return InterpolationResult(rect: Rect(origin: origin, size: size)) // TODO: Size should be calculated
        }
    }
}
struct Border<Content>: View where Content: View {
    let style: BorderStyle
    let content: Content
    struct ViewInterpolation: ViewInterpolationProtocol {
        let style: BorderStyle
        var contentInterpolation: Content.ViewInterpolation
        init(_ view: Border<Content>) {
            self.style = view.style
            self.contentInterpolation = Content.ViewInterpolation(view.content)
        }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            contentInterpolation.modify(modifier)
            // we can modify also border params (foreground for example), or set foreground in style
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            let result = contentInterpolation.build(with: BuildInputs(id: inputs.id, parent: inputs.parent, rect: inputs.rect.inset(by: EdgeInsets(value: 1))) /*inputs*/, buffer: &buffer) // should draw borders inside?
            let rect = result.rect
            let right = rect.origin.x + rect.size.width
            let left = rect.origin.x - 1
            let top = rect.origin.y - 1
            let bottom = rect.origin.y + rect.size.height
            for row in rect.origin.y ..< bottom {
                buffer.setChars(style.vertical, in: Point(x: left, y: row), size: .one)
                buffer.setChars(style.vertical, in: Point(x: right, y: row), size: .one)
            }
            let horizontal = String(repeating: style.horizontal, count: rect.size.width)
            let topLine = style.topLeft + horizontal + style.topRight
            buffer.setChars(topLine, in: Point(x: left, y: top), size: Size(width: rect.size.width + 2, height: 1))
            let bottomLine = style.bottomLeft + horizontal + style.bottomLeft
            buffer.setChars(bottomLine, in: Point(x: left, y: bottom), size: Size(width: rect.size.width + 2, height: 1))
            return InterpolationResult(rect: Rect(origin: Point(x: left, y: top), size: Size(width: rect.size.width + 2, height: rect.size.height + 2)), nodes: result.nodes)
        }
    }
}
extension View {
    func bordered(_ style: BorderStyle) -> Border<Self> {
        Border(style: style, content: self)
    }
}
struct Padding<Content>: View where Content: View {
    let insets: EdgeInsets
    let content: Content
    struct ViewInterpolation: ViewInterpolationProtocol {
        let insets: EdgeInsets
        var contentInterpolation: Content.ViewInterpolation
        init(_ view: Padding<Content>) {
            self.insets = view.insets
            self.contentInterpolation = Content.ViewInterpolation(view.content)
        }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            contentInterpolation.modify(modifier)
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            let result = contentInterpolation.build(with: BuildInputs(id: inputs.id, parent: inputs.parent, rect: inputs.rect.inset(by: insets)), buffer: &buffer)
            let rect = result.rect
            let left = rect.origin.x - insets.leading
            let bottom = rect.origin.y + rect.size.height
            let fill = " "
            if insets.leading > 0 || insets.trailing > 0, bottom > 0 {
                let right = rect.origin.x + rect.size.width + insets.trailing - 1
                let leadingColumn = String(repeating: fill, count: insets.leading)
                let trailingColumn = String(repeating: fill, count: insets.leading)
                for row in rect.origin.y ..< bottom {
                    buffer.setChars(leadingColumn, in: Point(x: left, y: row), size: Size(width: insets.leading, height: 1))
                    buffer.setChars(trailingColumn, in: Point(x: right, y: row), size: Size(width: insets.trailing, height: 1))
                }
            }
            if insets.top > 0 || insets.bottom > 0 {
                let width = rect.size.width + insets.horizontal
                let horizontal = String(repeating: fill, count: width)
                for row in rect.origin.y - insets.top ..< rect.origin.y {
                    buffer.setChars(horizontal, in: Point(x: left, y: row), size: Size(width: width, height: 1))
                }
                for row in bottom ..< bottom + insets.bottom {
                    buffer.setChars(horizontal, in: Point(x: left, y: row), size: Size(width: width, height: 1))
                }
            }
            return InterpolationResult(rect: rect.inset(by: insets.inverted()), nodes: result.nodes)
        }
    }
}
extension View {
    func padding(_ insets: EdgeInsets) -> Padding<Self> {
        Padding(insets: insets, content: self)
    }
    func padding(_ value: Int = 1) -> Padding<Self> {
        Padding(insets: EdgeInsets(value: value), content: self)
    }
}
struct VStack<Content>: View where Content: View {
    @ViewBuilder let content: () -> Content
    struct ViewInterpolation: ViewInterpolationProtocol {
        let view: VStack<Content>
        var modifications = PositioningViewModifications()
        init(_ view: VStack<Content>) {
            self.view = view
        }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            modifier.modify(content: &modifications)
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            var interpolation = Content.ViewInterpolation(view.content())
            let rect = Rect(
                origin: inputs.rect.origin.offset(x: modifications.rect.origin.x, y: modifications.rect.origin.y),
                size: modifications.rect.size == .unspecified ? inputs.rect.size : modifications.rect.size
            )
            var result = InterpolationResult(rect: .null)
            let subviewSize = Size(width: rect.size.width, height: rect.size.height / interpolation.subviewsCount)
            for p in (0 ..< interpolation.subviewsCount) { // TODO: use visitor to build it without position (see DocumentUI)
                let subviewRect = Rect(origin: Point(x: rect.origin.x, y: p * subviewSize.height + rect.origin.y), size: subviewSize)
                let res = interpolation.build(with: BuildInputs(id: inputs.id, parent: inputs.parent, rect: subviewRect), buffer: &buffer, at: p)
                result.rect = result.rect.union(res.rect)
                result.nodes.append(contentsOf: res.nodes)
            }
            return result
        }
    }
}

@propertyWrapper
struct Binding<Value> { // TODO: should be observed by updater also
    let set: (Value) -> Void
    let get: () -> Value

    var wrappedValue: Value {
        set { set(newValue) }
        get { get() }
    }
}
@propertyWrapper
struct State<Value> {
    private let storage: _Storage
    public init(wrappedValue value: Value) {
        self.storage = _Storage(_value: value)
    }
    public var wrappedValue: Value {
        get { storage._value }
        nonmutating set { storage._set(newValue) }
    }

    public var projectedValue: Binding<Value> {
        Binding(set: storage._set(_:), get: storage._get)
    }

    final class _Storage {
        var _value: Value
        init(_value: Value) { self._value = _value }
        func _set(_ newValue: Value) {
            _value = newValue
            Application.shared.stateChangeHandler()
        }
        func _get() -> Value { _value }
    }
}

struct TextField: View { // TODO: Cursor position
    let isActive: Binding<Bool>
    let text: Binding<String>
    var body: Text {
        Text(text.get())
    }
    struct ViewInterpolation: ViewInterpolationProtocol {
        let view: TextField
        var contentInterpolation: TextField.Body.ViewInterpolation
        init(_ view: TextField) {
            self.view = view
            self.contentInterpolation = TextField.Body.ViewInterpolation(view.body)
        }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            contentInterpolation.modify(modifier)
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            if view.isActive.wrappedValue {
                contentInterpolation.modify(TextStyleModifier(style: .underline))
            }
            let result = contentInterpolation.build(with: inputs, buffer: &buffer)
            guard let node = inputs.parent.child(with: inputs.id) else {
                let node = Node(id: inputs.id, view: view)
                node.rect = result.rect
                return InterpolationResult(rect: result.rect, nodes: [node])
            }
            node.rect = result.rect
            return InterpolationResult(rect: node.rect, nodes: [node])
        }
        final class Node: ViewNode {
            let view: TextField
            init(id: String, view: TextField) {
                self.view = view
                super.init(id: id)
            }
            override var canBecomeFirstResponder: Bool { true }
            override func becomeFirstResponder() -> Bool {
                Application.shared.currentFirstResponser = self
                view.isActive.set(true)
                return true
            }
            override func resignFirstResponder() -> Bool {
                view.isActive.set(false)
                return true
            }
            override func keyDown(_ keyCode: UInt8) {
                guard view.isActive.wrappedValue else { return }
                switch keyCode {
                case 0x04, 0x0A, 0x1B: // detect EOF (Ctrl+D) or LINE FEED
                    view.isActive.set(false)
                case 127:
                    var current = view.text.get()
                    guard current.count > 0 else { return }
                    current.removeLast()
                    view.text.set(current)
                default:
                    let char = Character(Unicode.Scalar(UInt8(keyCode)))
                    view.text.set(view.text.get().appending(String(char)))
                }
            }
            override func mouseEvent(_ event: MEVENT) {
                /// guard event.bstate & _ else { return }
                let point = Point(x: Int(event.x), y: Int(event.y))
                guard rect.contains(point) else { return }
                guard !view.isActive.wrappedValue else {
                    // change cursor position
                    return
                }
                Application.shared.currentFirstResponser = self
                view.isActive.set(true)
            }
        }
    }
}
struct Button<Title>: View where Title: View {
    let title: Title
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) where Title == Text {
        self.title = Text(title)
        self.action = action
    }
    init(action: @escaping () -> Void, @ViewBuilder title: () -> Title) {
        self.title = title()
        self.action = action
    }
    var body: some View {
        title
    }
    struct ViewInterpolation: ViewInterpolationProtocol {
        let view: Button<Title>
        var bodyInterpolation: Title.ViewInterpolation
        init(_ view: Button<Title>) {
            self.view = view
            self.bodyInterpolation = Title.ViewInterpolation(view.title)
        }
        mutating func modify<M>(_ modifier: M) where M : ViewModifier {
            bodyInterpolation.modify(modifier)
        }
        mutating func build(with inputs: BuildInputs, buffer: inout OutputString) -> InterpolationResult {
            let node: Node
            if let n = inputs.parent.child(with: inputs.id) {
                node = n as! Node
            } else {
                node = Node(id: inputs.id, view: view)
            }
            if node._isActive {
                bodyInterpolation.modify(TextStyleModifier(style: .bold))
            }
            let result = bodyInterpolation.build(with: inputs, buffer: &buffer)
            node.rect = result.rect
            return InterpolationResult(rect: result.rect, nodes: [node])
        }
        final class Node: ViewNode {
            let view: Button<Title>
            var _isActive: Bool = false
            init(id: String, view: Button<Title>) {
                self.view = view
                super.init(id: id)
            }
            override var canBecomeFirstResponder: Bool { true }
            override func becomeFirstResponder() -> Bool {
                guard !_isActive else { return true }
                _isActive = true
                Application.shared.currentFirstResponser = self
                Application.shared.stateChangeHandler()
                return true
            }
            override func resignFirstResponder() -> Bool {
                _isActive = false
                return true
            }
            override func keyDown(_ keyCode: UInt8) {
                guard _isActive else { return }
                switch keyCode {
                case 0x1B: _isActive = false
                case 0x0A, 0x20:
                    view.action()
                default: break
                }
            }
            override func mouseEvent(_ event: MEVENT) {
                /// guard event.bstate & _ else { return }
                let point = Point(x: Int(event.x), y: Int(event.y))
                guard rect.contains(point) else { return }
                view.action()
            }
        }
    }
}

///

struct BackgroundModifier: ViewModifier {
    let color: Color
    func modify<Container>(content: inout Container) where Container: ViewModifications { content.attributes.background = color }
}
struct ForegroundModifier: ViewModifier {
    let color: Color
    func modify<Container>(content: inout Container) where Container: ViewModifications { content.attributes.foreground = color }
}
struct TextStyleModifier: ViewModifier {
    let style: TextStyle
    func modify<Container>(content: inout Container) where Container: ViewModifications { content.attributes.styles.insert(style) }
}
struct PositionModifier: ViewModifier {
    let origin: Point
    func modify<Container>(content: inout Container) where Container: ViewModifications { content.rect.origin = origin }
}
struct SizeModifier: ViewModifier {
    let size: Size
    func modify<Container>(content: inout Container) where Container: ViewModifications { content.rect.size = size }
}

extension View {
    func background(_ color: Color) -> _ModifiedContent<Self, BackgroundModifier> {
        modifier(BackgroundModifier(color: color))
    }
    func foreground(_ color: Color) -> _ModifiedContent<Self, ForegroundModifier> {
        modifier(ForegroundModifier(color: color))
    }
    func offset(_ origin: Point) -> _ModifiedContent<Self, PositionModifier> {
        modifier(PositionModifier(origin: origin))
    }
    func size(_ size: Size) -> _ModifiedContent<Self, SizeModifier> {
        modifier(SizeModifier(size: size))
    }
    func textStyle(_ style: TextStyle) -> _ModifiedContent<Self, TextStyleModifier> {
        modifier(TextStyleModifier(style: style))
    }
}

///

var showTestView: Bool = true

struct App: View {
    var body: some View {
        ContentView()
        if showTestView {
            TestView()
        } else {
            NullView()
        }
    }
}

struct ContentView: View {
    @State var tfActive: Bool = false
    @State var text: String = "Hello"
    @State var counter: Int = 0
    var body: some View {
        VStack {
            Button("Counter: \(counter)") {
                counter += 1
            }
            .background(.blue)
            Button("Exit") {
                Application.shared.isRunning = false
            }
        }
        .offset(Point(x: 0, y: _size.height - 2))
        .size(Size(width: _size.width, height: 2))
        VStack {
            Text("Text field is \(tfActive ? "active" : "not active")")
                .foreground(.red)
                .padding()
                .bordered(.ascii)
                .background(.yellow)
            TextField(isActive: $tfActive, text: $text)
                .textStyle(.bold)
                .foreground(.blue)
        }
    }
}

struct TestView: View {
    var body: some View {
        NullView()
    }
}

extension ViewNode {
    func _searchNextFirstResponderAndActivate(after otherChild: ViewNode? = nil) -> Bool {
        guard !canBecomeFirstResponder || !becomeFirstResponder() else { return true }
        let startIndex = children.firstIndex(where: { $0 === otherChild }).map({ $0 + 1 }) ?? 0
        for child in children[startIndex...] {
            guard child._searchNextFirstResponderAndActivate() else {
                continue
            }
            return true
        }
        return false
    }
}
extension Application {
    func _searchNextFirstResponderAndActivate() -> Bool {
        guard let current = currentFirstResponser else {
            return rootNode?._searchNextFirstResponderAndActivate() ?? false
        }
        var next: ViewNode = current
        while let nxt = next.next {
            if nxt._searchNextFirstResponderAndActivate(after: next) {
                return true
            }
            next = nxt
        }
        return next._searchNextFirstResponderAndActivate()
    }
}

let isDebug = ProcessInfo.processInfo.arguments.last?.hasPrefix("--debug") == true
var _size = isDebug ? Size(width: 70, height: 30) : readScreenSize()

var buffer = OutputString(size: _size)
let root = ConcreteViewNode(id: "root", view: App())
Application.shared.rootNode = root
if isDebug {
    root.render(to: &buffer, in: Rect(origin: .zero, size: _size))
    var output = SnapshotOutput()
    buffer.write(to: &output)
    print(buffer.characters.count, output.value.count, output.value)
} else {
    let runloop = RunLoop.main
    signal(SIGINT) { _ in
        Application.shared.isRunning = false
    }
    signal(SIGWINCH) { _ in
        _size = readScreenSize()
        render()
    }
    Application.shared.stateChangeHandler = {
        render()
    }
    while Application.shared.isRunning, runloop.run(mode: .default, before: Date().addingTimeInterval(1)) {
        render()
    }
    _move(toX: 0, y: 0)
    func render() {
        buffer.clear(_size)
        root.render(to: &buffer, in: Rect(origin: .zero, size: _size))
        var output = StandartOutput()
        _move(toX: 0, y: 0)
        buffer.write(to: &output)
    }
}
endwin()
