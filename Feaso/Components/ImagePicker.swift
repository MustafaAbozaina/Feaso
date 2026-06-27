import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Attachment Button Component

struct AttachmentButton: View {
    let attachedImage: UIImage?
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(String(localized: "ATTACHMENT (OPTIONAL)"))
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(Color.Theme.ink2)
            
            if let image = attachedImage {
                // Show attached image
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(Spacing.sm)
                }
                .onTapGesture {
                    onTap()
                }
            } else {
                // Show add attachment button
                Button {
                    onTap()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "camera.fill")
                            .font(.body)
                        Text(String(localized: "Add Receipt or Photo"))
                            .font(.body)
                    }
                    .foregroundStyle(Color.Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundStyle(Color.Theme.border2)
                    )
                }
            }
        }
    }
}

// MARK: - Attachment Source Picker

struct AttachmentSourceSheet: View {
    @Binding var isPresented: Bool
    let onSelectCamera: () -> Void
    let onSelectLibrary: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "Add Attachment"))
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            .padding(Spacing.lg)
            
            Divider()
            
            // Options
            VStack(spacing: 0) {
                Button {
                    isPresented = false
                    onSelectCamera()
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Take Photo"))
                                .font(.body)
                                .fontWeight(.medium)
                            Text(String(localized: "Capture receipt or document"))
                                .font(.caption)
                                .foregroundStyle(Color.Theme.ink3)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                    .foregroundStyle(Color.Theme.ink)
                    .padding(Spacing.lg)
                }
                
                Divider()
                    .padding(.leading, 60)
                
                Button {
                    isPresented = false
                    onSelectLibrary()
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Choose from Library"))
                                .font(.body)
                                .fontWeight(.medium)
                            Text(String(localized: "Select existing photo"))
                                .font(.caption)
                                .foregroundStyle(Color.Theme.ink3)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                    .foregroundStyle(Color.Theme.ink)
                    .padding(Spacing.lg)
                }
            }
            
            Spacer()
        }
        .background(Color.Theme.surface)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Attachment Button - Empty") {
    AttachmentButton(
        attachedImage: nil,
        onTap: {},
        onRemove: {}
    )
    .padding()
    .background(Color.Theme.background)
}
