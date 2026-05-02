import SwiftUI
import UIKit

// SwiftUI wrapper around UIImagePickerController. Returns a JPEG-compressed
// UIImage via the onCapture callback. Ships in source as the V0 path because
// it works on simulator (photo library) and device (camera) without extra
// permission dance — the camera permission already lives in Info.plist.
//
// We deliberately do NOT use AVCaptureSession custom UI yet — that's a
// V0.5 polish item once we want INE-shape overlays and selfie circle masks.
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.delegate = context.coordinator
        // If camera unavailable (simulator), fall back to library.
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        p.allowsEditing = false
        return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onCapture(img)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Triple-doc capture screen. Drives ApplyWizardModel.documents via
// PesitoAPI.uploadDocument. Replaces the placeholder docs step in
// ApplyView when the model.applicationId is set.
struct DocsCaptureView: View {
    @ObservedObject var model: ApplyWizardModel
    @State private var captureKind: DocKind?
    @State private var pickerSource: UIImagePickerController.SourceType = .camera

    enum DocKind: String, CaseIterable, Identifiable {
        case ineFront = "ine_front", ineBack = "ine_back", selfie = "selfie"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .ineFront: return "INE — frente"
            case .ineBack:  return "INE — reverso"
            case .selfie:   return "Selfie"
            }
        }
        var hint: String {
            switch self {
            case .ineFront: return "Foto clara del frente con tu CURP visible"
            case .ineBack:  return "Reverso con código de barras y firma"
            case .selfie:   return "Tu cara, buena luz, sin gorras ni gafas"
            }
        }
        var icon: String {
            switch self {
            case .ineFront: return "rectangle.split.2x1"
            case .ineBack:  return "rectangle.split.2x1.fill"
            case .selfie:   return "person.fill.viewfinder"
            }
        }
        var preferredSource: UIImagePickerController.SourceType {
            self == .selfie ? .camera : .camera
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PesitoSpace.md) {
            Text("Para tu seguridad necesitamos foto del INE (frente y reverso) y una selfie.")
                .font(.pesitoBodyM)
                .foregroundColor(PesitoColor.inkSoft)

            ForEach(DocKind.allCases) { kind in
                DocRow(
                    kind: kind,
                    state: model.documents[kind.rawValue],
                    onTap: {
                        pickerSource = kind.preferredSource
                        captureKind = kind
                    }
                )
            }

            if let e = model.error {
                Text(e).font(.pesitoBodyS).foregroundColor(PesitoColor.danger)
            }
        }
        .sheet(item: $captureKind) { kind in
            ImagePicker(sourceType: pickerSource) { image in
                Task { await model.uploadDocument(kind: kind.rawValue, image: image) }
            }
            .ignoresSafeArea()
        }
    }
}

private struct DocRow: View {
    let kind: DocsCaptureView.DocKind
    let state: ApplyWizardModel.DocumentState?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PesitoSpace.md) {
                ZStack {
                    if let img = state?.thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: kind.icon)
                            .font(.system(size: 24))
                            .foregroundColor(PesitoColor.inkSoft)
                            .frame(width: 56, height: 56)
                            .background(PesitoColor.brandSoft.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.pesitoBody(15, weight: .bold))
                        .foregroundColor(PesitoColor.ink)
                    Text(state?.statusText ?? kind.hint)
                        .font(.pesitoBodyS)
                        .foregroundColor(state?.uploaded == true ? PesitoColor.success : PesitoColor.inkSoft)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: state?.uploaded == true ? "checkmark.circle.fill" : "camera")
                    .font(.system(size: 22))
                    .foregroundColor(state?.uploaded == true ? PesitoColor.success : PesitoColor.brand)
            }
            .padding(PesitoSpace.md)
            .background(PesitoColor.bgRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(state?.uploaded == true ? PesitoColor.success : PesitoColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
