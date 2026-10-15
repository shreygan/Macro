//
//  PhotoPickerCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/15/26.
//

import CoreLocation
import PhotosUI
import SwiftUI

struct LoggedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let originalData: Data
    let pickerItem: PhotosPickerItem?
    let coordinate: CLLocationCoordinate2D?
    let capturedAt: Date?

    var scale: CGFloat = 1.0
    var offset: CGSize = .zero

    init(
        image: UIImage,
        originalData: Data,
        pickerItem: PhotosPickerItem?,
        scale: CGFloat = 1.0,
        offset: CGSize = .zero
    ) {
        self.image = image
        self.originalData = originalData
        self.pickerItem = pickerItem
        let metadata = PhotoMetadata(data: originalData)
        self.coordinate = metadata.coordinate
        self.capturedAt = metadata.capturedAt
        self.scale = scale
        self.offset = offset
    }
}

struct PhotoPickerCard: View {
    @Binding var images: [LoggedPhoto]
    @Binding var isLoading: Bool

    var isEditing: Bool = true
    var onViewAll: (() -> Void)? = nil
    var onUseTime: ((Date) -> Void)? = nil
    var onUseLocation: ((EntryLocation) -> Void)? = nil
    var entryDate: Date? = nil
    var entryTime: Date? = nil
    var entryLocation: EntryLocation? = nil
    var onPickerItemsChange: (([PhotosPickerItem]) -> Void)? = nil
    var onCoverChange: ((Bool) -> Void)? = nil

    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var currentTabIndex: Int = 0
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []

    @State private var showAddSlide: Bool = false
    @State private var isEmptyStateLoading: Bool = false
    @State private var loadTask: Task<Void, Never>?
    @State private var showViewer = false

    @Namespace private var photoNamespace

    let maxPhotos = 5

    private var pageCount: Int {
        images.count + (images.count < maxPhotos && showAddSlide ? 1 : 0)
    }

    private var pageSelection: Binding<Int?> {
        Binding(
            get: { currentTabIndex },
            set: { currentTabIndex = $0 ?? 0 }
        )
    }

    private var currentPhotoID: UUID? {
        images.indices.contains(currentTabIndex) ? images[currentTabIndex].id : nil
    }

    private var viewerSelection: Binding<UUID?> {
        Binding(
            get: { currentPhotoID },
            set: { id in
                if let index = images.firstIndex(where: { $0.id == id }) {
                    currentTabIndex = index
                }
            }
        )
    }

    private var availableSelectionCount: Int {
        maxPhotos - images.filter({ $0.pickerItem == nil }).count
    }

    var body: some View {
        Group {
            if images.isEmpty {
                emptyStateMenu
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Card {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            ScrollView(.horizontal) {
                                HStack(spacing: 0) {
                                    ForEach(images.indices, id: \.self) { index in
                                        InteractivePhotoView(
                                            photo: $images[index],
                                            isAdjustable: isEditing,
                                            onTap: { showViewer = true }
                                        )
                                            .matchedTransitionSource(
                                                id: images[index].id,
                                                in: photoNamespace
                                            )
                                            .overlay(alignment: .topTrailing) {
                                                Button(action: {
                                                    deleteImage(at: index)
                                                }) {
                                                    Image(systemName: "trash")
                                                        .font(
                                                            .system(
                                                                size: 12,
                                                                weight: .bold
                                                            )
                                                        )
                                                        .foregroundColor(
                                                            .red.opacity(0.85)
                                                        )
                                                }
                                                .buttonStyle(PhotoOverlayButtonStyle())
                                                .padding(5)
                                                .opacity(isEditing ? 1 : 0)
                                                .scaleEffect(isEditing ? 1 : 0.5)
                                                .disabled(!isEditing)
                                            }
                                            .overlay(alignment: .bottomLeading) {
                                                PhotoDetailsChip(
                                                    photo: images[index],
                                                    onUseTime: onUseTime,
                                                    onUseLocation: onUseLocation,
                                                    entryDate: entryDate,
                                                    entryTime: entryTime,
                                                    entryLocation: entryLocation,
                                                    isInteractive: isEditing
                                                )
                                                .padding(5)
                                            }
                                            .padding(.horizontal, 5)
                                            .containerRelativeFrame([.horizontal, .vertical])
                                            .id(index)
                                    }

                                    if images.count < maxPhotos && showAddSlide {
                                        carouselAddSlide
                                            .padding(.horizontal, 5)
                                            .containerRelativeFrame([.horizontal, .vertical])
                                            .id(images.count)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.paging)
                            .scrollIndicators(.hidden)
                            .scrollPosition(id: pageSelection)
                            .padding(.horizontal, -5)
                        )
                        .overlay(alignment: .top) {
                            PageControl(
                                numberOfPages: pageCount,
                                currentPage: pageSelection
                            )
                            .frame(height: 30)
                            .padding(.top, 12)
                        }
                        .overlay(alignment: .topLeading) {
                            if let onViewAll {
                                Button(action: onViewAll) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.buttonIcon)
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(PhotoOverlayButtonStyle())
                                .padding(5)
                                .accessibilityLabel("View All Photos")
                            }
                        }
                        .clipped()
                }
                .padding()
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.95),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    )
                )
            }
        }
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8),
            value: images.isEmpty
        )
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedPhotosPickerItems,
            maxSelectionCount: availableSelectionCount,
            selectionBehavior: .ordered,
            matching: .images
        )
        .onAppear {
            showAddSlide = isEditing
        }
        .onChange(of: isEditing) { oldVal, newVal in
            if !newVal && currentTabIndex == images.count {
                currentTabIndex = max(0, images.count - 1)
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showAddSlide = newVal
            }
        }
        .onChange(of: images.isEmpty) { _, isEmpty in
            if isEmpty { isEmptyStateLoading = false }
        }
        .onChange(of: images.map(\.id)) {
            guard loadTask == nil else { return }
            syncPickerSelection()
        }
        .onChange(of: showCamera || showViewer) { _, isCovered in
            onCoverChange?(isCovered)
        }
        .onChange(of: isLoading) { _, newValue in
            guard !newValue, let loadTask else { return }
            loadTask.cancel()
            self.loadTask = nil
            isEmptyStateLoading = false
            syncPickerSelection()
        }
        .onChange(of: selectedPhotosPickerItems) { oldItems, newItems in
            onPickerItemsChange?(newItems)

            let hasUnloadedItems = newItems.contains { item in
                !images.contains { $0.pickerItem == item }
            }
            if hasUnloadedItems {
                isLoading = true
                if images.isEmpty { isEmptyStateLoading = true }
            }

            loadTask?.cancel()
            loadTask = Task {
                guard
                    let loadedPhotos = await Self.loadPhotos(
                        for: newItems,
                        keeping: images
                    )
                else { return }

                await MainActor.run {
                    guard !Task.isCancelled, !hasUnloadedItems || isLoading
                    else { return }
                    loadTask = nil

                    let previouslyEmpty = images.isEmpty
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
                    {
                        images = loadedPhotos
                    }
                    if hasUnloadedItems { isLoading = false }
                    if images.isEmpty {
                        isEmptyStateLoading = false
                        return
                    }

                    let addedItems = newItems.filter { !oldItems.contains($0) }
                    let isStrictDeletion =
                        newItems.count < oldItems.count && addedItems.isEmpty

                    if !addedItems.isEmpty {
                        if previouslyEmpty {
                            currentTabIndex = 0
                        } else {
                            if let lastNewItem = addedItems.last,
                                let targetIndex = images.firstIndex(where: {
                                    $0.pickerItem == lastNewItem
                                })
                            {
                                currentTabIndex = targetIndex
                            }
                        }
                    } else if !isStrictDeletion && newItems != oldItems {
                        currentTabIndex = 0
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
                    {
                        images.append(
                            LoggedPhoto(
                                image: image,
                                originalData: data,
                                pickerItem: nil
                            )
                        )
                        currentTabIndex = images.count - 1
                    }
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showViewer) {
            LoggedPhotoViewer(
                photos: images,
                selection: viewerSelection,
                logDate: entryTimestamp,
                logLocation: entryLocation,
                onUseTime: isEditing ? onUseTime : nil,
                onUseLocation: isEditing ? onUseLocation : nil
            )
                .navigationTransition(
                    .zoom(sourceID: currentPhotoID, in: photoNamespace)
                )
        }
    }

    static func loadPhotos(
        for items: [PhotosPickerItem],
        keeping images: [LoggedPhoto]
    ) async -> [LoggedPhoto]? {
        let cameraPhotos = images.filter { $0.pickerItem == nil }
        var libraryPhotos: [LoggedPhoto] = []

        for item in items {
            if let existingPhoto = images.first(where: { $0.pickerItem == item }) {
                libraryPhotos.append(existingPhoto)
            } else if let data = try? await item.loadTransferable(type: Data.self),
                let uiImage = UIImage(data: data)
            {
                libraryPhotos.append(
                    LoggedPhoto(image: uiImage, originalData: data, pickerItem: item)
                )
            }
            if Task.isCancelled { return nil }
        }

        return cameraPhotos + libraryPhotos
    }

    private var entryTimestamp: Date? {
        guard let entryDate, let entryTime else { return nil }
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: entryTime)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: entryDate
        )
    }

    @ViewBuilder
    private var emptyStateMenu: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    photoMenuOptions
                } label: {
                    ZStack {
                        if isEmptyStateLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Loading Photos...")
                                    .foregroundStyle(.secondary)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            Label("Add Photos", systemImage: "camera")
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .font(.prominentButton)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .animation(.snappy, value: isEmptyStateLoading)
                }
                .buttonStyle(.glass)
                .allowsHitTesting(!isEmptyStateLoading)

                if let onViewAll {
                    Button(action: onViewAll) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.prominentButton)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("View All Photos")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var carouselAddSlide: some View {
        Menu {
            photoMenuOptions
        } label: {
            Image(systemName: "photo")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(isLoading ? 0 : 1)
                .scaleEffect(isLoading ? 0.95 : 1)
                .overlay {
                    ProgressView()
                        .controlSize(.large)
                        .opacity(isLoading ? 1 : 0)
                        .scaleEffect(isLoading ? 1 : 0.95)
                }
                .padding(20)
                .animation(.snappy, value: isLoading)
        }
        .allowsHitTesting(!isLoading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var photoMenuOptions: some View {
        Button {
            showCamera = true
        } label: {
            Label("Take Picture", systemImage: "camera")
        }

        Button {
            showPhotoLibrary = true
        } label: {
            Label("Choose from Library", systemImage: "photo.on.rectangle")
        }
    }

    private func syncPickerSelection() {
        let remainingItems = images.compactMap(\.pickerItem)
        if selectedPhotosPickerItems != remainingItems {
            selectedPhotosPickerItems = remainingItems
        }
    }

    private func deleteImage(at index: Int) {
        let photoToRemove = images[index]

        if let item = photoToRemove.pickerItem {
            selectedPhotosPickerItems.removeAll { $0 == item }
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            images.remove(at: index)

            if currentTabIndex >= images.count {
                currentTabIndex = max(0, images.count - 1)
            }
        }
    }
}

private struct PhotoOverlayButtonStyle: ButtonStyle {
    private let size: CGFloat = 30
    private let tapInset: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .glassEffect(.regular.interactive(), in: .circle)
            .padding(tapInset)
            .contentShape(.circle)
    }
}

private struct PageControl: UIViewRepresentable {
    let numberOfPages: Int
    @Binding var currentPage: Int?

    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.currentPageIndicatorTintColor = .white
        control.pageIndicatorTintColor = .white.withAlphaComponent(0.4)
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.pageChanged(_:)),
            for: .valueChanged
        )
        return control
    }

    func updateUIView(_ control: UIPageControl, context: Context) {
        context.coordinator.parent = self
        control.numberOfPages = numberOfPages
        control.currentPage = currentPage ?? 0
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UIPageControl,
        context: Context
    ) -> CGSize? {
        uiView.numberOfPages = numberOfPages
        return uiView.intrinsicContentSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: PageControl

        init(parent: PageControl) {
            self.parent = parent
        }

        @objc func pageChanged(_ control: UIPageControl) {
            withAnimation {
                parent.currentPage = control.currentPage
            }
        }
    }
}

#Preview {
    @Previewable @State var previewImages: [LoggedPhoto] = []
    @Previewable @State var isLoading = false

    ZStack {
        Color.background.ignoresSafeArea()

        VStack {
            Spacer()

            PhotoPickerCard(
                images: $previewImages,
                isLoading: $isLoading,
                isEditing: false
            )

            Spacer()
        }
    }
}
