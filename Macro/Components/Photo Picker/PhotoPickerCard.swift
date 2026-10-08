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

    var isEditing: Bool = true

    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var currentTabIndex: Int = 0
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []

    @State private var showAddSlide: Bool = false

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
        .onChange(of: selectedPhotosPickerItems) { oldItems, newItems in
            Task {
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
                }

                await MainActor.run {
                    let previouslyEmpty = images.isEmpty
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
                    {
                        images = cameraPhotos + updatedLibraryPhotos
                    }
                    if images.isEmpty { return }

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
                Label("Add Photos", systemImage: "camera")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var carouselAddSlide: some View {
        Menu {
            photoMenuOptions
        } label: {
            Image(systemName: "photo")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.primary.opacity(0.6))
                .padding(20)
        }
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

    ZStack {
        Color.background.ignoresSafeArea()

        VStack {
            Spacer()

            PhotoPickerCard(images: $previewImages, isEditing: false)

            Spacer()
        }
    }
}
