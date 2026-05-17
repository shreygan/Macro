//
//  MealPhotoGalleryCard.swift
//  Macro
//
//  Created by Shrey Gangwar on 5/15/26.
//

import PhotosUI
import SwiftUI

struct LoggedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let pickerItem: PhotosPickerItem?
}

struct MealPhotoGalleryCard: View {
    @State private var images: [LoggedPhoto] = []

    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var currentTabIndex: Int = 0
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []

    let maxPhotos = 5

    var body: some View {
        Card {
            if images.isEmpty {
                addMenu
                    .aspectRatio(1, contentMode: .fit)
            } else {
                TabView(selection: $currentTabIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        InteractivePhotoView(image: images[index].image) {
                            deleteImage(at: index)
                        }
                        .tag(index)
                    }

                    if images.count < maxPhotos {
                        addMenu
                            .tag(images.count)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedPhotosPickerItems,
            maxSelectionCount: maxPhotos
                - images.filter({ $0.pickerItem == nil }).count,
            selectionBehavior: .ordered,
            matching: .images
        )
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
                                LoggedPhoto(image: uiImage, pickerItem: item)
                            )
                        }
                    }
                }

                await MainActor.run {
                    let previouslyEmpty = images.isEmpty

                    images = cameraPhotos + updatedLibraryPhotos

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
                images.append(LoggedPhoto(image: image, pickerItem: nil))

                withAnimation(.easeInOut) {
                    currentTabIndex = images.count - 1
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var addMenu: some View {
        Menu {
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
        } label: {
            Image(systemName: "photo")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.primary.opacity(0.6))
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func deleteImage(at index: Int) {
        let photoToRemove = images[index]

        if let item = photoToRemove.pickerItem {
            selectedPhotosPickerItems.removeAll { $0 == item }
        }

        images.remove(at: index)

        if currentTabIndex >= images.count {
            withAnimation(.easeInOut) {
                currentTabIndex = max(0, images.count - 1)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.background.ignoresSafeArea()

        Spacer()

        MealPhotoGalleryCard()
            .padding()

        Spacer()
    }
}
