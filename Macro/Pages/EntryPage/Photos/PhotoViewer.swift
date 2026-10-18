//
//  PhotoViewer.swift
//  Macro
//
//  Created by Shrey Gangwar on 10/10/26.
//

import SwiftData
import SwiftUI
import UIKit

struct PhotoViewerItem: Identifiable {
    let photo: EntryPhoto
    let entry: LoggedEntry

    var id: PersistentIdentifier { photo.persistentModelID }
}

struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss

    let items: [PhotoViewerItem]
    @Binding var selection: PersistentIdentifier?
    var currentEntryID: UUID? = nil

    @State private var isChromeHidden = false
    @State private var logToShow: LoggedEntry?
    @State private var closesAfterLog = false
    @State private var metadata: [PersistentIdentifier: PhotoMetadata] = [:]

    private let chromeAnimation = Animation.easeInOut(duration: 0.2)

    private var selectedItem: PhotoViewerItem? {
        items.first { $0.id == selection } ?? items.first
    }

    private var subtitle: String? {
        selectedItem.flatMap { PhotoLog.detail(for: $0.entry) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isChromeHidden ? Color.black : Color.background)
                    .ignoresSafeArea()

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(items) { item in
                            ZoomablePhotoPage(
                                photo: item.photo,
                                isActive: item.id == selection,
                                onTap: {
                                    withAnimation(chromeAnimation) {
                                        isChromeHidden.toggle()
                                    }
                                },
                                onZoomIn: {
                                    withAnimation(chromeAnimation) {
                                        isChromeHidden = true
                                    }
                                }
                            )
                            .containerRelativeFrame([.horizontal, .vertical])
                            .accessibilityLabel(
                                "Photo from \(EntryHelper.logDateText(item.entry.timestamp))"
                            )
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $selection)
                .scrollIndicators(.hidden)
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottom) {
                if !isChromeHidden, let selectedItem {
                    let photoMetadata = metadata[selectedItem.id]
                    let showsViewLog = selectedItem.entry.id != currentEntryID
                    PhotoCaption(
                        coordinate: photoMetadata?.coordinate,
                        capturedAt: photoMetadata?.capturedAt,
                        logDate: selectedItem.entry.timestamp,
                        logLocation: selectedItem.entry.location,
                        nearbyCoordinates: neighbors(of: selectedItem.id).compactMap {
                            metadata[$0.id]?.coordinate
                        }
                    ) {
                        if showsViewLog {
                            ViewLogButton {
                                logToShow = selectedItem.entry
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.snappy(duration: 0.3), value: showsViewLog)
                    .padding([.horizontal, .bottom])
                    .transition(.opacity)
                }
            }
            .task(id: selectedItem?.id) {
                guard let selectedItem else { return }
                for item in [selectedItem] + neighbors(of: selectedItem.id) where metadata[item.id] == nil {
                    guard let loaded = await EntryPhotoCache.shared.metadata(for: item.photo),
                        !Task.isCancelled
                    else { continue }
                    metadata[item.id] = loaded
                }
            }
            .background {
                if let subtitle {
                    Color.clear.navigationSubtitle(subtitle)
                }
            }
            .navigationTitle(
                selectedItem.map { EntryHelper.logDateText($0.entry.timestamp) }
                    ?? ""
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(
                isChromeHidden ? .hidden : .visible,
                for: .navigationBar
            )
            .statusBarHidden(isChromeHidden)
            .persistentSystemOverlays(isChromeHidden ? .hidden : .automatic)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(item: $logToShow) { entry in
                NavigationStack {
                    LoggedEntryDetailView(
                        entry: entry,
                        isPushedView: false,
                        showsActionsAndLinks: false,
                        onRemovePhotos: { closesAfterLog = true }
                    )
                }
                .onLeave {
                    if closesAfterLog { dismiss() }
                }
            }
        }
        .environment(\.tabBarHeight, 0)
    }

    private func neighbors(of id: PersistentIdentifier) -> [PhotoViewerItem] {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return [] }
        return [index + 1, index - 1]
            .filter { items.indices.contains($0) }
            .map { items[$0] }
    }
}

private struct ViewLogButton: View {
    var action: () -> Void

    @State private var availableWidth = CGFloat.infinity
    @State private var iconLabelWidth: CGFloat = 0

    private var showsIcon: Bool {
        availableWidth >= iconLabelWidth
    }

    var body: some View {
        label(showsIcon: false)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                availableWidth = $0
            }
            .background {
                label(showsIcon: true)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                        iconLabelWidth = $0
                    }
            }
            .overlay(alignment: .trailing) {
                Button(action: action) {
                    label(showsIcon: showsIcon)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(.capsule)
                .accessibilityLabel("View Log")
                .animation(.snappy(duration: 0.3), value: showsIcon)
            }
    }

    private func label(showsIcon: Bool) -> some View {
        HStack(spacing: 6) {
            if showsIcon {
                Image(systemName: "list.bullet.rectangle")
                    .transition(.opacity)
            }

            Text("View Log")
        }
        .font(.compactTitle)
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .fixedSize()
    }
}

private struct ZoomablePhotoPage: View {
    @Environment(\.displayScale) private var displayScale

    let photo: EntryPhoto
    let isActive: Bool
    var onTap: () -> Void
    var onZoomIn: () -> Void

    @State private var image: UIImage?
    @State private var loadedPixelSize = 0
    @State private var isZoomed = false
    @State private var nativePixelSize: CGSize?

    private let zoomedPixelSize = 4096

    private var zoomablePixelSize: CGSize? {
        guard let nativePixelSize else { return nil }
        let longSide = max(nativePixelSize.width, nativePixelSize.height)
        let limit = CGFloat(zoomedPixelSize)
        guard longSide > limit else { return nativePixelSize }
        let scale = limit / longSide
        return CGSize(
            width: nativePixelSize.width * scale,
            height: nativePixelSize.height * scale
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let side = max(geometry.size.width, geometry.size.height) * displayScale
            let pixelSize = Int((side / 256).rounded(.up)) * 256

            ZoomableImage(
                image: image,
                nativePixelSize: zoomablePixelSize,
                isActive: isActive,
                onTap: onTap,
                onZoomChange: { zoomed in
                    isZoomed = zoomed
                    if zoomed { onZoomIn() }
                }
            )
            .overlay {
                if image == nil {
                    ProgressView()
                }
            }
            .task(id: pixelSize) {
                await load(pixelSize)
            }
            .task {
                nativePixelSize = await EntryPhotoCache.shared.pixelDimensions(
                    for: photo
                )
            }
            .task(id: isZoomed) {
                if isZoomed {
                    await load(zoomedPixelSize)
                }
            }
        }
    }

    private func load(_ pixelSize: Int) async {
        guard pixelSize > loadedPixelSize,
            let loaded = await EntryPhotoCache.shared.image(
                for: photo,
                pixelSize: pixelSize
            ),
            pixelSize > loadedPixelSize
        else { return }
        loadedPixelSize = pixelSize
        image = loaded
    }
}

struct LoggedPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss

    let photos: [LoggedPhoto]
    @Binding var selection: UUID?
    var logDate: Date? = nil
    var logLocation: EntryLocation? = nil
    var onUseTime: ((Date) -> Void)? = nil
    var onUseLocation: ((EntryLocation) -> Void)? = nil

    @State private var isChromeHidden = false

    private let chromeAnimation = Animation.easeInOut(duration: 0.2)

    private var title: String {
        guard photos.count > 1,
            let index = photos.firstIndex(where: { $0.id == selection })
        else { return "" }
        return String(localized: "\(index + 1) of \(photos.count)")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isChromeHidden ? Color.black : Color.background)
                    .ignoresSafeArea()

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(photos) { photo in
                            ZoomableImage(
                                image: photo.image,
                                nativePixelSize: CGSize(
                                    width: photo.image.size.width * photo.image.scale,
                                    height: photo.image.size.height * photo.image.scale
                                ),
                                isActive: photo.id == selection,
                                onTap: {
                                    withAnimation(chromeAnimation) {
                                        isChromeHidden.toggle()
                                    }
                                },
                                onZoomChange: { zoomed in
                                    guard zoomed else { return }
                                    withAnimation(chromeAnimation) {
                                        isChromeHidden = true
                                    }
                                }
                            )
                            .containerRelativeFrame([.horizontal, .vertical])
                            .accessibilityLabel("Photo")
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $selection)
                .scrollIndicators(.hidden)
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottom) {
                if !isChromeHidden, let index = photos.firstIndex(where: { $0.id == selection }) {
                    let photo = photos[index]
                    PhotoCaption(
                        coordinate: photo.coordinate,
                        capturedAt: photo.capturedAt,
                        logDate: logDate,
                        logLocation: logLocation,
                        nearbyCoordinates: [index + 1, index - 1]
                            .filter { photos.indices.contains($0) }
                            .compactMap { photos[$0].coordinate },
                        onUseTime: onUseTime,
                        onUseLocation: onUseLocation
                    )
                        .padding([.horizontal, .bottom])
                        .transition(.opacity)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(
                isChromeHidden ? .hidden : .visible,
                for: .navigationBar
            )
            .statusBarHidden(isChromeHidden)
            .persistentSystemOverlays(isChromeHidden ? .hidden : .automatic)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage?
    let nativePixelSize: CGSize?
    let isActive: Bool
    var onTap: () -> Void
    var onZoomChange: (Bool) -> Void

    func makeUIView(context: Context) -> ZoomingScrollView {
        ZoomingScrollView()
    }

    func updateUIView(_ view: ZoomingScrollView, context: Context) {
        view.onTap = onTap
        view.onZoomChange = onZoomChange
        view.image = image
        view.nativePixelSize = nativePixelSize
        if !isActive && view.zoomScale != 1 {
            view.setZoomScale(1, animated: false)
        }
    }
}

private final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var lastBoundsSize: CGSize = .zero
    private var isZoomedIn = false

    var onTap: (() -> Void)?
    var onZoomChange: ((Bool) -> Void)?

    var nativePixelSize: CGSize? {
        didSet {
            guard nativePixelSize != oldValue else { return }
            updateMaximumZoom()
        }
    }

    var image: UIImage? {
        didSet {
            guard image !== oldValue else { return }
            imageView.image = image
            if aspectRatio(of: image) != aspectRatio(of: oldValue) {
                resetZoom()
            }
        }
    }

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleSingleTap)
        )
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastBoundsSize {
            lastBoundsSize = bounds.size
            resetZoom()
        }
    }

    private func aspectRatio(of image: UIImage?) -> CGFloat? {
        guard let image, image.size.height > 0 else { return nil }
        return (image.size.width / image.size.height * 1000).rounded()
    }

    private func resetZoom() {
        zoomScale = 1

        guard let image, image.size.width > 0, image.size.height > 0,
            bounds.width > 0, bounds.height > 0
        else { return }

        let scale = min(
            bounds.width / image.size.width,
            bounds.height / image.size.height
        )
        let size = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        imageView.frame = CGRect(origin: .zero, size: size)
        contentSize = size
        centerImage()
        updateMaximumZoom()
    }

    private func updateMaximumZoom() {
        let fitWidth = imageView.bounds.width
        guard let nativePixelSize, fitWidth > 0 else {
            maximumZoomScale = 4
            return
        }

        let actualSize =
            nativePixelSize.width / (fitWidth * traitCollection.displayScale)
        maximumZoomScale = min(max(actualSize * 2, 2), 12)
    }

    private func centerImage() {
        let x = max(0, (bounds.width - contentSize.width) / 2)
        let y = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
        let zoomed = zoomScale > minimumZoomScale + 0.01
        if zoomed != isZoomedIn {
            isZoomedIn = zoomed
            onZoomChange?(zoomed)
        }
    }

    @objc private func handleSingleTap() {
        onTap?()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }

        let point = gesture.location(in: imageView)
        let scale: CGFloat = 2.5
        let size = CGSize(
            width: bounds.width / scale,
            height: bounds.height / scale
        )
        zoom(
            to: CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            ),
            animated: true
        )
    }
}
