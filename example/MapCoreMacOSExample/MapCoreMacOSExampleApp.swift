import AppKit
import Combine
import MapCore
import MetalKit
import SwiftUI

@main
@MainActor
struct MapCoreMacOSExampleApp: App {
    var body: some Scene {
        WindowGroup("MapCore — Native macOS") {
            NativeMapContentView()
        }
    }
}

private enum NativeMapStyle: String, CaseIterable {
    case vector = "Vector"
    case raster = "Raster"
}

@MainActor
private struct NativeMapContentView: View {
    @StateObject private var model = NativeMapModel()
    private let refresh = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Map tiles:")
                ForEach(NativeMapStyle.allCases, id: \.self) { style in
                    Button {
                        model.style = style
                    } label: {
                        Label("\(style.rawValue) tiles", systemImage: model.style == style ? "checkmark.circle.fill" : "circle")
                    }
                    .disabled(model.style == style)
                }
                Spacer()
            }
            .buttonStyle(.bordered)
            .padding(10)
            Divider()
            NativeMapView(mapView: model.mapView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 8) {
                        if model.style == .vector {
                            Link("OpenFreeMap", destination: URL(string: "https://openfreemap.org")!)
                            Link("© OpenMapTiles", destination: URL(string: "https://openmaptiles.org")!)
                        }
                        Link("© OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    }
                    .font(.caption)
                    .padding(6)
                    .background(.regularMaterial)
                    .padding(8)
                }
                .overlay {
                    if let error = model.error {
                        Text(error)
                            .padding()
                            .background(.regularMaterial)
                    } else if model.isLoading {
                        ProgressView("Loading \(model.style.rawValue.lowercased()) map…")
                            .padding()
                            .background(.regularMaterial)
                    }
                }
            Divider()
            HStack {
                Text("Drag to pan · Scroll or pinch to zoom")
                Spacer()
                Text(model.position).monospacedDigit()
            }
            .font(.caption)
            .padding(10)
        }
        .frame(minWidth: 800, idealWidth: 1000, minHeight: 550, idealHeight: 700)
        .toolbar {
            Button { model.home() } label: { Label("Zurich", systemImage: "house") }
            Button { model.zoom(by: 0.5) } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }
            Button { model.zoom(by: 2) } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
        }
        .onChange(of: model.style) { model.selectStyle($0) }
        .onReceive(refresh) { _ in model.refreshPosition() }
    }
}

private struct NativeMapView: NSViewRepresentable {
    let mapView: MCMapView
    func makeNSView(context: Context) -> MCMapView { mapView }
    func updateNSView(_ nsView: MCMapView, context: Context) {}
}

@MainActor
private final class NativeMapModel: ObservableObject {
    private static let vectorStyleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    let mapView = MCMapView()
    @Published var style = NativeMapStyle.vector
    @Published private(set) var position = ""
    @Published private(set) var error: String?
    @Published private(set) var isLoading = true
    private var baseLayer: MCLayerInterface?
    private var styleTask: Task<Void, Never>?
    private var frameMonitor: NativeFrameMonitor?
    private let textureLoader = MCTextureLoader()
    private let fontLoader = NativeFontLoader()
    private let tileErrorManager = MCErrorManager.create()
    private lazy var tileErrorListener = NativeTileErrorListener { [weak self] message in
        self?.error = message
    }
    #if DEBUG
        private var diagnosticsRemaining = 20
    #endif

    init() {
        tileErrorManager?.addErrorListener(tileErrorListener)
        home()
        selectStyle(.vector)
        if ProcessInfo.processInfo.arguments.contains("--map-performance-check") {
            let monitor = NativeFrameMonitor(target: mapView)
            frameMonitor = monitor
            mapView.delegate = monitor
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                monitor.reset()
                for scale in [25_000.0, 100_000, 12_500, 50_000] {
                    mapView.camera.setZoom(scale, animated: true)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
                monitor.report()
            }
        }
    }

    func selectStyle(_ style: NativeMapStyle) {
        styleTask?.cancel()
        mapView.remove(layer: baseLayer)
        baseLayer = nil
        tileErrorManager?.clearAllErrors()
        error = nil
        isLoading = true
        #if DEBUG
            diagnosticsRemaining = 20
        #endif
        switch style {
        case .raster:
            do {
                let raster = try MCTiled2dMapRasterLayerInterface.webMercator(
                    "OpenStreetMap", urlFormat: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    loaders: [textureLoader]
                )
                install(raster.asLayerInterface())
            } catch {
                self.error = "Could not create the raster map."
                isLoading = false
            }
        case .vector:
            styleTask = Task {
                do {
                    var request = URLRequest(url: Self.vectorStyleURL)
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard !Task.isCancelled else { return }
                    guard (response as? HTTPURLResponse)?.statusCode == 200,
                          let json = String(data: data, encoding: .utf8) else {
                        throw URLError(.badServerResponse)
                    }
                    // Match the style compatibility transformation in the iOS example.
                    let compatibleJSON = json.replacingOccurrences(
                        of: #"\["in"\s*,"#, with: #"["==","#, options: .regularExpression
                    )
                    let vector = MCTiled2dMapVectorLayerInterface.createExplicitly(
                        "OpenFreeMap Liberty", styleJson: compatibleJSON,
                        localStyleJson: NSNumber(value: true), loaders: [textureLoader],
                        fontLoader: fontLoader, localDataProvider: nil, customZoomInfo: nil,
                        symbolDelegate: nil, sourceUrlParams: nil
                    )
                    install(vector?.asLayerInterface())
                } catch {
                    guard !Task.isCancelled else { return }
                    NSLog("Native vector style failed: %@", String(describing: error))
                    self.error = "Could not load the vector map style."
                    isLoading = false
                }
            }
        }
    }

    private func install(_ layer: MCLayerInterface?) {
        guard let layer else {
            error = "Could not create the map layer."
            isLoading = false
            return
        }
        baseLayer = layer
        layer.setErrorManager(tileErrorManager)
        mapView.insert(layer: layer, at: 0)
        mapView.invalidate()
    }

    func home() {
        let zurich = MCCoord(systemIdentifier: 4326, x: 8.5417, y: 47.3769, z: 0)
        mapView.camera.move(toCenterPositionZoom: zurich, zoom: 50_000, animated: false)
        refreshPosition()
    }

    func zoom(by factor: Double) {
        mapView.camera.setZoom(mapView.camera.getZoom() * factor, animated: true)
    }

    func refreshPosition() {
        // This check synchronizes with vector tile workers. Stop polling after
        // initial loading so camera updates do not wait on those workers.
        if isLoading, let baseLayer, mapView.window != nil {
            let state = baseLayer.isReadyToRenderOffscreen()
            isLoading = state == .NOT_READY
            if !isLoading {
                NSLog("Native %@ map initial readiness=%ld", style.rawValue, state.rawValue)
            }
            #if DEBUG
                if diagnosticsRemaining > 0 {
                    diagnosticsRemaining -= 1
                    NSLog("Native %@ map: drawable=%@ paused=%d readiness=%ld",
                          style.rawValue, NSStringFromSize(mapView.drawableSize),
                          mapView.isPaused ? 1 : 0, state.rawValue)
                }
            #endif
        }
        let center = mapView.camera.getCenterPosition()
        guard let coordinate = mapView.mapInterface.getCoordinateConverterHelper()?.convert(4326, coordinate: center) else { return }
        position = String(format: "Center: %.5f, %.5f · Scale: %.0f", coordinate.y, coordinate.x, mapView.camera.getZoom())
    }
}

/// Opt-in timing of the example's own renderer, without desktop inspection.
private final class NativeFrameMonitor: NSObject, MTKViewDelegate {
    private let target: MCMapView
    private var durations: [Double] = []
    private var isMeasuring = false

    init(target: MCMapView) { self.target = target }

    func reset() {
        durations.removeAll()
        isMeasuring = true
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        target.mtkView(view, drawableSizeWillChange: size)
    }

    func draw(in view: MTKView) {
        guard isMeasuring else {
            target.draw(in: view)
            return
        }
        let start = ProcessInfo.processInfo.systemUptime
        target.draw(in: view)
        durations.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
    }

    func report() {
        isMeasuring = false
        let sorted = durations.sorted()
        guard !sorted.isEmpty else { return }
        NSLog("Native frame timing: frames=%d drawMedian=%.1fms drawP95=%.1fms drawMax=%.1fms stallsOver50ms=%d",
              sorted.count, sorted[sorted.count / 2], sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))],
              sorted.last!, durations.filter { $0 > 50 }.count)
    }
}

private final class NativeTileErrorListener: NSObject, MCErrorManagerListener {
    private let onChange: @MainActor @Sendable (String?) -> Void
    init(onChange: @escaping @MainActor @Sendable (String?) -> Void) { self.onChange = onChange }

    func onTiledLayerErrorStateChanged(_ errors: [MCTiledLayerError]) {
        for error in errors.prefix(3) {
            NSLog("Native tile error: status=%ld code=%@ url=%@",
                  error.status.rawValue, error.errorCode ?? "none", error.url)
        }
        let message: String? = errors.isEmpty ? nil : "Map tiles could not be loaded."
        let callback = onChange
        Task { @MainActor in callback(message) }
    }
}
