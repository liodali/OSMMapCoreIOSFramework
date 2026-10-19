#if os(macOS)
import AppKit

public typealias OSMPlatformView = NSView
public typealias OSMPlatformImage = NSImage
public typealias OSMPlatformColor = NSColor
#else
import UIKit

public typealias OSMPlatformView = UIView
public typealias OSMPlatformImage = UIImage
public typealias OSMPlatformColor = UIColor
#endif
