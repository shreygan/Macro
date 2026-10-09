//
//  PhotoPickerCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/15/26.
//

import PhotosUI
import SwiftUI

struct LoggedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let originalData: Data
    let pickerItem: PhotosPickerItem?

    var scale: CGFloat = 1.0
    var offset: CGSize = .zero
}

struct PhotoPickerCard: View {
    @Binding var images: [LoggedPhoto]
    @Binding var isLoading: Bool

    var isEditing: Bool = true

    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var currentTabIndex: Int = 0
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []

    @State private var showAddSlide: Bool = false
    @State private var isEmptyStateLoading: Bool = false
    @State private var loadTask: Task<Void, Never>?

    let maxPhotos = 5

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
                            TabView(selection: $currentTabIndex) {
                                ForEach(images.indices, id: \.self) { index in
                                    InteractivePhotoView(photo: $images[index])
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
                                                    .frame(
                                                        width: 30,
                                                        height: 30
                                                    )
                                                    .background(
                                                        Circle()
                                                            .fill(
                                                                .regularMaterial
                                                            )
                                                    )
                                                    .overlay(
                                                        Circle()
                                                            .strokeBorder(
                                                                Color.white
                                                                    .opacity(
                                                                        0.4
                                                                    ),
                                                                lineWidth: 0.5
                                                            )
                                                    )
                                                    .shadow(
                                                        color: .black.opacity(
                                                            0.15
                                                        ),
                                                        radius: 4,
                                                        x: 0,
                                                        y: 2
                                                    )
                                            }
                                            .padding(12)
                                            .opacity(isEditing ? 1 : 0)
                                            .scaleEffect(isEditing ? 1 : 0.5)
                                            .disabled(!isEditing)
                                        }
                                        .padding(.horizontal, 5)
                                        .tag(index)
                                }

                                if images.count < maxPhotos && showAddSlide {
                                    carouselAddSlide
                                        .padding(.horizontal, 5)
                                        .tag(images.count)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .padding(.horizontal, -5)
                        )
                        .clipped()
                }
                .padding()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
        .onChange(of: isLoading) { _, newValue in
            guard !newValue, let loadTask else { return }
            loadTask.cancel()
            self.loadTask = nil
            isEmptyStateLoading = false
            syncPickerSelection()
        }
        .onChange(of: selectedPhotosPickerItems) { oldItems, newItems in
            let hasUnloadedItems = newItems.contains { item in
                !images.contains { $0.pickerItem == item }
            }
            if hasUnloadedItems {
                isLoading = true
                if images.isEmpty { isEmptyStateLoading = true }
            }

            loadTask?.cancel()
            loadTask = Task {
                let cameraPhotos = images.filter { $0.pickerItem == nil }
                var updatedLibraryPhotos: [LoggedPhoto] = []

                for item in newItems {
                    if let existingPhoto = images.first(where: {
                        $0.pickerItem == item
                    }) {
                        updatedLibraryPhotos.append(existingPhoto)
                    } else {
                        if let data = try? await item.loadTransferable(
                            type: Data.self
                        ),
                            let uiImage = UIImage(data: data)
                        {
                            updatedLibraryPhotos.append(
                                LoggedPhoto(
                                    image: uiImage,
                                    originalData: data,
                                    pickerItem: item
                                )
                            )
                        }
                    }
                    if Task.isCancelled { return }
                }

                await MainActor.run {
                    guard !Task.isCancelled, !hasUnloadedItems || isLoading
                    else { return }
                    loadTask = nil

                    let previouslyEmpty = images.isEmpty
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
                    {
                        images = cameraPhotos + updatedLibraryPhotos
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
    }

    @ViewBuilder
    private var emptyStateMenu: some View {
        GlassEffectContainer(spacing: 10) {
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
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .animation(.snappy, value: isEmptyStateLoading)
            }
            .buttonStyle(.glass)
            .allowsHitTesting(!isEmptyStateLoading)
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
                .foregroundColor(.primary.opacity(0.6))
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
