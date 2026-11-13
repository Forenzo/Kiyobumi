import SwiftUI

// Select the property-wrapper type explicitly. SDK 27 also exports a State
// macro, whose compiler plugin may be absent from standalone Command Line Tools.
// This alias retains SwiftUI storage, bindings and DynamicProperty behaviour.
typealias KiyobumiState<Value> = SwiftUI.State<Value>
