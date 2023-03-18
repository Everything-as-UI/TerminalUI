//
//  File.swift
//  
//
//  Created by Denis Koryttsev on 08.07.2022.
//
import Darwin
import Foundation

extension Range where Bound == Int {
    var middle: Int? {
        guard count > 0 else { return nil }
        return lowerBound + count / 2
    }
}

extension Collection where Index == Int {
    /// The index where `newElement` should be inserted to preserve the array's sort order.
    public func sortedInsertionIndex(for newElement: Element, comparator: (Element, Element) -> ComparisonResult) -> Index {
        search(for: newElement, comparator: comparator).index
    }
    public func sortedInsertionIndex(for element: Element, comparator: (Element, Element) -> Bool) -> Index {
        sortedInsertionIndex(for: element) { lhs, rhs -> ComparisonResult in
            if comparator(lhs, rhs) { return .orderedAscending }
            else if comparator(rhs, lhs) { return .orderedDescending }
            else { return .orderedSame }
        }
    }

    /// Searches the array for `element` using binary search.
    ///
    /// - Returns: If `element` is in the array, returns `.found(at: index)`
    ///   where `index` is the index of the element in the array.
    ///   If `element` is not in the array, returns `.notFound(insertAt: index)`
    ///   where `index` is the index where the element should be inserted to
    ///   preserve the sort order.
    ///   If the array contains multiple elements that are equal to `element`,
    ///   there is no guarantee which of these is found.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    fileprivate func search(for element: Element, comparator: (Element, Element) -> ComparisonResult) -> SortedIndex {
        return searchIndex(in: startIndex ..< endIndex, comparator: { el in
            comparator(element, el)
        })
    }

    typealias SortedIndex = (index: Index, found: Bool)
    func searchIndex(in range: Range<Index>, comparator: (Element) -> ComparisonResult) -> SortedIndex {
        guard let middle = range.middle else { return (range.upperBound, false) }
        switch comparator(self[middle]) {
        case .orderedDescending:
            return searchIndex(in: index(after: middle)..<range.upperBound, comparator: comparator)
        case .orderedAscending:
            return searchIndex(in: range.lowerBound..<middle, comparator: comparator)
        case .orderedSame:
            return (middle, true)
        }
    }
}
extension Array {
    @discardableResult
    public mutating func insertSorted(_ newElement: Element, comparator: (Element, Element) -> ComparisonResult) -> Index {
        let index = sortedInsertionIndex(for: newElement, comparator: comparator)
        // This should be O(1) if the element is to be inserted at the end,
        // O(_n) in the worst case (inserted at the front).
        insert(newElement, at: index)
        return index
    }
    @discardableResult
    public mutating func insertSorted(_ newElement: Element, comparator: (Element, Element) -> Bool) -> Index {
        insertSorted(newElement, comparator: { lhs, rhs -> ComparisonResult in
            if comparator(lhs, rhs) { return .orderedAscending }
            else if comparator(rhs, lhs) { return .orderedDescending }
            else { return .orderedSame }
        })
    }
}

extension String {
    subscript(range: Range<Int>) -> Substring {
        self[index(startIndex, offsetBy: range.lowerBound) ..< index(startIndex, offsetBy: range.upperBound)]
    }
}

///

public struct Point: Equatable {
    public var x: Int
    public var y: Int

    static public let zero = Point(x: 0, y: 0)
}
extension Point {
    func offset(x: Int = 0, y: Int = 0) -> Point {
        Point(x: self.x + x, y: self.y + y)
    }
}
public struct Size: Equatable {
    public var width: Int
    public var height: Int

    public static let zero = Size(width: 0, height: 0)
    public static let one = Size(width: 1, height: 1)
    public static let unspecified = Size(width: -1, height: -1)
}
extension Size {
    var length: Int { width * height }
}
public struct Rect: Equatable {
    public var origin: Point
    public var size: Size

    static public let zero = Rect(origin: .zero, size: .zero)
    static public let null = Rect(origin: Point(x: .max, y: .max), size: .zero)
    static public let unspecified = Rect(origin: .zero, size: .unspecified)
    var isNull: Bool { origin.x == .max || origin.y == .max }
}
extension Rect {
    var maxX: Int { origin.x + size.width }
    var maxY: Int { origin.y + size.height }
    func offset(x: Int, y: Int) -> Rect { Rect(origin: origin.offset(x: x, y: y), size: size) }
    func contains(_ point: Point) -> Bool {
        guard point.x >= origin.x, point.y >= origin.y else { return false }
        guard origin.x + size.width > point.x, origin.y + size.height > point.y else { return false }
        return true
    }
    func union(_ other: Rect) -> Rect {
        guard !isNull else { return other }
        guard !other.isNull else { return self }
        let point = Point(x: min(origin.x, other.origin.x), y: min(origin.y, other.origin.y))
        return Rect(
            origin: point,
            size: Size(width: max(maxX, other.maxX) - point.x, height: max(maxY, other.maxY) - point.y)
        )
    }
}
public struct EdgeInsets: Equatable {
    public init(leading: Int, trailing: Int, top: Int, bottom: Int) {
        self.leading = leading
        self.trailing = trailing
        self.top = top
        self.bottom = bottom
    }

    public init(value: Int) {
        self.leading = value
        self.trailing = value
        self.top = value
        self.bottom = value
    }

    public var leading: Int
    public var trailing: Int
    public var top: Int
    public var bottom: Int
}
extension EdgeInsets {
    var horizontal: Int { leading + trailing }
    var vertical: Int { top + bottom }
    func inverted() -> EdgeInsets {
        EdgeInsets(leading: -leading, trailing: -trailing, top: -top, bottom: -bottom)
    }
}
extension Rect {
    func inset(by insets: EdgeInsets) -> Rect {
        Rect(
            origin: Point(x: origin.x + insets.leading, y: origin.y + insets.top),
            size: Size(width: size.width - insets.horizontal, height: size.height - insets.vertical)
        )
    }
}

// Commands: https://www2.ccs.neu.edu/research/gpc/VonaUtils/vona/terminal/vtansi.htm
// Unicode-chart: https://www.ssec.wisc.edu/~tomw/java/unicode.html#x0000

public enum Color: Int, RawRepresentable, CaseIterable {
    case black = 30
    case red = 31
    case green = 32
    case yellow = 33
    case blue = 34
    case magenta = 35
    case cyan = 36
    case white = 37
    case brightBlack = 90
    case brightRed = 91
    case brightGreen = 92
    case brightYellow = 93
    case brightBlue = 94
    case brightMagenta = 95
    case brightCyan = 96
    case brightWhite = 97
}
extension Color {
    var foreground: Int { rawValue }
    var background: Int { rawValue + 10 }
}
enum TextStyle: Int, Hashable {
    case bold = 1
    case dimmed = 2
    case italic = 3
    case underline = 4
    case blink = 5
    case invertedColors = 7
    case hidden = 8
    case strikethrough = 9
}
extension TextStyle {
    var resetValue: Int { rawValue + 20 }
}
/// For 256-colors terminals
struct ColorPalette: RawRepresentable {
    let rawValue: UInt8
}
extension ColorPalette {
    var foregroundValue: String { "\u{1b}[38;5;\(rawValue + 1)m" }
    var backgroundValue: String { "\u{1b}[48;5;\(rawValue + 1)m" }
}

///

// Taken from https://stackoverflow.com/questions/49748507/listening-to-stdin-in-swift
func enableRawMode(file: Int32) -> termios {
    var raw: termios = .init()
    tcgetattr(file, &raw)
    let original = raw
    raw.c_lflag &= ~(UInt(ECHO | ICANON))
    tcsetattr(file, TCSAFLUSH, &raw);
    return original
}

// see https://stackoverflow.com/a/24335355/669586
func initStruct<S>() -> S {
    let struct_pointer = UnsafeMutablePointer<S>.allocate(capacity: 1)
    let struct_memory = struct_pointer.pointee
    struct_pointer.deallocate()
    return struct_memory
}

func enableRawMode(fileHandle: FileHandle) -> termios {
    var raw: termios = initStruct()
    tcgetattr(fileHandle.fileDescriptor, &raw)
    let original = raw
    raw.c_lflag &= ~(UInt(ECHO | ICANON))
    tcsetattr(fileHandle.fileDescriptor, TCSAFLUSH, &raw);
    return original
}

func restoreRawMode(fileHandle: FileHandle, originalTerm: termios) {
    var term = originalTerm
    tcsetattr(fileHandle.fileDescriptor, TCSAFLUSH, &term);
}

func _move(toX x: Int, y: Int) {
    _write("\u{1b}[\(y+1);\(x+1)H")
}
func clearScreen() {
    _write("\u{1b}[2J")
}
func _setColor(foregroundColor: Color?, backgroundColor: Color?) {
    foregroundColor.map(_setForeground(_:))
    backgroundColor.map(_setBackground(_:))
}
func _setForeground(_ color: Color) {
    _write("\u{1b}[\(color.foreground)m")
}
func _setBackground(_ color: Color) {
    _write("\u{1b}[\(color.background)m")
}
func _clearColors() {
    _write("\u{1b}[0m")
}

func _write(_ str: String, fd: Int32 = STDOUT_FILENO) {
    _ = str.withCString { str in
        write(fd, str, strlen(str))
    }
}

func winsz_handler(sig: Int32) {
}

func readCursorPosition() -> Int {
    "\u{1b}[6n".withCString { ptr in
        return write(STDIN_FILENO, ptr, strlen(ptr))
    }
}
func readScreenSize() -> Size {
    var w: winsize = .init()
    _ = ioctl(STDOUT_FILENO, TIOCGWINSZ, &w)
    return Size(width: Int(w.ws_col), height: Int(w.ws_row))
}

/*public func run() {
    _ = enableRawMode(file: STDOUT_FILENO)
    //render()
    signal(SIGWINCH, winsz_handler)
    _ = enableRawMode(file: STDIN_FILENO)
    var c = getchar()
    while true {
        //render()
        c = getchar()
    }
}*/

///

public struct Renderer {
    var origin: Point = .zero
    var size: Size = .zero
    var foregroundColor: Color? = nil
    var backgroundColor: Color? = nil

    mutating func resetColors() {
        foregroundColor = nil
        backgroundColor = nil
    }

    ///

    func setCursor() {
        _move(toX: origin.x, y: origin.y)
    }
    func setColors() {
        _setColor(foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }
    func clearColors() {
        _clearColors()
    }
    func write<S: StringProtocol>(_ s: S) {
        _write(String(s))
    }
}

///

extension Renderer {
    func writeText(_ text: String) {
        var startIndex = 0
        let endRow = size.height == .max ? size.height : origin.y + size.height
        for row in origin.y ..< endRow {
            let endIndex = min(text.count, startIndex + size.width)
            let line = text[startIndex ..< endIndex]
            _move(toX: origin.x, y: row)
            write(line)
            if endIndex == text.count { return }
            startIndex = endIndex
        }
    }
}
extension Renderer {
    func fillColor(_ color: Color) {
        _clearColors()
        _setColor(foregroundColor: nil, backgroundColor: color)
        writeText(String(repeating: " ", count: size.width * size.height))
        _clearColors()
    }
}
protocol BorderStyleProtocol {
    func topBorder(in row: Int, of borderWidth: Int, length: Int) -> String
    func bottomBorder(in row: Int, of borderWidth: Int, length: Int) -> String
    func leadingBorder(of borderWidth: Int) -> String
    func trailingBorder(of borderWidth: Int) -> String
}
struct BorderStyle {
    public var topLeft = "┌"
    public var topRight = "┐"
    public var horizontal = "─"
    public var vertical = "│"
    public var bottomLeft = "└"
    public var bottomRight = "┘"
    public static let `default` = Self()

    public static let ascii = Self(topLeft: "+", topRight: "+", horizontal: "-", vertical: "|", bottomLeft: "+", bottomRight: "+")
    public static let double = Self(topLeft: "╔", topRight: "╗", horizontal: "═", vertical: "║", bottomLeft: "╚", bottomRight: "╝")
}
extension Renderer {
    func drawBorders(_ style: BorderStyle) {
        let right = origin.x + size.width
        let left = origin.x - 1
        let bottom = origin.y + size.height
        for row in origin.y ..< bottom {
            _move(toX: left, y: row)
            write(style.vertical)
            _move(toX: right, y: row)
            write(style.vertical)
        }
        _move(toX: left, y: origin.y - 1)
        write(style.topLeft)
        write(String(repeating: style.horizontal, count: size.width))
        write(style.topRight)
        _move(toX: left, y: bottom)
        write(style.bottomLeft)
        write(String(repeating: style.horizontal, count: size.width))
        write(style.bottomRight)
    }
}

///

struct OutputString {
    var screenSize: Size
    var characters: String
    var runs: [Run] = []

    static var main: OutputString = OutputString(size: .zero)

    init(size: Size) {
        self.screenSize = size
        self.characters = String(repeating: " ", count: size.length)
    }

    struct Run {
        var range: Range<Int>
        var attributes: Attributes
    }
    struct Attributes {
        var styles: Set<TextStyle> = []
        var foreground: Color?
        var background: Color?
    }
}
extension OutputString.Run: Comparable {
    static func < (lhs: OutputString.Run, rhs: OutputString.Run) -> Bool {  
        lhs.range.lowerBound < rhs.range.lowerBound
    }
    static func == (lhs: OutputString.Run, rhs: OutputString.Run) -> Bool {
        lhs.range == rhs.range
    }
}
extension OutputString {
    mutating func clear(_ newSize: Size? = nil) {
        if let size = newSize, size != screenSize {
            screenSize = size
        }
        characters.removeAll(keepingCapacity: true)
        characters.append(String(repeating: " ", count: screenSize.length))
        runs.removeAll(keepingCapacity: true)
    }
    mutating func setChars<C>(_ chars: C, attributes: Attributes? = nil, in origin: Point, size: Size) where C: Collection, C.Element == Character {
        guard chars.count > 0 else { return }
        guard origin.x < screenSize.width else { return }
        let maxX = size.width + origin.x
        guard maxX > 0 else { return }
        let leftCrop = origin.x < 0 ? abs(origin.x) : 0
        let rightCrop = min(0, screenSize.width - maxX)
        var offsetIndex = chars.startIndex
        let endRow = min(screenSize.height, size.height == -1 ? size.height : origin.y + size.height)
        for row in origin.y ..< endRow {
            guard row > -1 else { continue }
            var endIndex = chars.index(offsetIndex, offsetBy: size.width, limitedBy: chars.endIndex) ?? chars.endIndex
            endIndex = min(chars.endIndex, chars.index(endIndex, offsetBy: rightCrop))
            offsetIndex = chars.index(offsetIndex, offsetBy: leftCrop, limitedBy: endIndex) ?? endIndex
            let line = chars[offsetIndex ..< endIndex]
            let lower = (row * screenSize.width) + origin.x + leftCrop
            let upper = lower + chars.distance(from: offsetIndex, to: endIndex)
            setChars(line, attributes: attributes, in: lower ..< upper)
            if endIndex == chars.endIndex { return }
            offsetIndex = endIndex
        }
    }
    mutating func setChars<C>(_ chars: C, attributes: Attributes? = nil, in range: Range<Int>) where C: Collection, C.Element == Character {
        let charsRange = characters.index(characters.startIndex, offsetBy: range.lowerBound) ..< characters.index(characters.startIndex, offsetBy: range.upperBound)
        characters.replaceSubrange(charsRange, with: chars)
        // if it replaces attributed text without attributes, then attributes will  still be active
        if let attr = attributes {
            setAttributes(attr, in: range)
        }
    }
    mutating func setAttributes(_ attributes: Attributes, in range: Range<Int>) {
        let run = Run(range: range, attributes: attributes)
        let index = runs.sortedInsertionIndex(for: run, comparator: <)
        // TODO: Remove other attributes in this place
        runs.insert(run, at: index)
    }
}


protocol Output {
    mutating func write<T>(_ substring: T) where T: StringProtocol
}
extension Output {
    mutating func writeClearAttributes() {
        write("\u{1b}[0m")
    }
}
extension OutputString.Attributes {
    func write<O>(to output: inout O) where O: Output {
        if let color = foreground {
            output.write("\u{1b}[\(color.foreground)m")
        }
        if let color = background {
            output.write("\u{1b}[\(color.background)m")
        }
        for style in styles {
            output.write("\u{1b}[\(style.rawValue)m")
        }
    }
}
extension OutputString {
    func write<O>(to output: inout O) where O: Output {
        guard runs.count > 0 else { return output.write(characters) }
        var intersectionRuns: [Run] = []
        var lowerBound = 0
        for each in runs {
            if intersectionRuns.count > 0 {
                var i = 0
                while i < intersectionRuns.count {
                    let next = intersectionRuns[i]
                    let distance = next.range.upperBound - each.range.lowerBound
                    if distance > 0 {
                        if i == intersectionRuns.count - 1 {
                            output.write(characters[lowerBound ..< each.range.lowerBound])
                            lowerBound = each.range.lowerBound
                        }
                        i += 1
                    } else {
                        output.write(characters[lowerBound ..< next.range.upperBound])
                        lowerBound = next.range.upperBound
                        output.writeClearAttributes()
                        intersectionRuns.remove(at: i)
                        intersectionRuns.forEach({ $0.attributes.write(to: &output) })
                    }
                }
            }
            if each.range.lowerBound > lowerBound {
                output.write(characters[lowerBound ..< each.range.lowerBound])
                lowerBound = each.range.lowerBound
            }
            each.attributes.write(to: &output)
            intersectionRuns.append(each)
        }
        while intersectionRuns.count > 0 {
            let next = intersectionRuns[0]
            output.write(characters[lowerBound ..< next.range.upperBound])
            lowerBound = next.range.upperBound
            output.writeClearAttributes()
            intersectionRuns.remove(at: 0)
            intersectionRuns.forEach({ $0.attributes.write(to: &output) })
        }
        output.write(characters[lowerBound ..< characters.count])
        assert(intersectionRuns.isEmpty)
    }
}

struct SnapshotOutput: Output {
    private(set) var value: String = ""
    mutating func write<T>(_ substring: T) where T : StringProtocol {
        value.append(String(substring))
    }
}
struct StandartOutput: Output {
    func write<T>(_ substring: T) where T : StringProtocol {
        _ = substring.withCString { ptr in
            Darwin.write(STDOUT_FILENO, ptr, strlen(ptr))
        }
    }
}

///

// https://tldp.org/HOWTO/NCURSES-Programming-HOWTO/index.html
import Curses
import Darwin.ncurses

typealias get_wch_def = @convention(c) (UnsafeMutablePointer<Int32>) -> Int
final class Application {
    var isRunning: Bool = true
    var rootNode: ViewNode? {
        willSet { unbindRootNode() }
        didSet { rootNode.map(bindRootNode(_:)) }
    }
    var currentFirstResponser: ViewNode? {
        willSet { currentFirstResponser?.resignFirstResponder() }
    }
    var stateChangeHandler: () -> Void = {}

    init() {
        let rtld_default = UnsafeMutableRawPointer(bitPattern: -2)
        // Fetch the pointers to get_wch and add_wch as the NCurses binding in Swift is missing them
        let get_wch_ptr = dlsym (rtld_default, "get_wch")
        let get_wch_fn = unsafeBitCast(get_wch_ptr, to: get_wch_def.self)
        initscr()
        //raw()
        noecho()
        keypad(stdscr, true)
        curs_set(0)
        /*var mouseEvents: mmask_t = */mousemask(0x7ffffff | 0x8000000, nil)
        clear()
    }

    func unbindRootNode() {
        FileHandle.standardInput.readabilityHandler = nil
    }
    func bindRootNode(_ root: ViewNode) {
        FileHandle.standardInput.readabilityHandler = { _ in
            let code = getch()
            switch code {
            case KEY_MOUSE:
                var event = MEVENT()
                guard getmouse(&event) == OK else { return }
                DispatchQueue.main.async {
                    root.mouseEvent(event)
                }
            default:
                guard code < 256, code > 0 else { return }
                DispatchQueue.main.async {
                    guard code != 9 || !Application.shared._searchNextFirstResponderAndActivate() else { return }
                    root.keyDown(UInt8(code))
                }
            }
        }
    }
}
extension Application {
    static var shared: Application = Application()
}
