import SwiftUI

@MainActor
struct InviteUserView: View {
    @StateObject private var invitationManager = InvitationManager()
    @State private var email: String = ""
    @State private var selectedPermission: Permission = .read
    @State private var errorMessage: String?
    @State private var successMessage: String?

    let tripId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teilnehmer einladen")
                .font(.headline)

            TextField("E-Mail-Adresse des Teilnehmers", text: $email)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            Picker("Berechtigung", selection: $selectedPermission) {
                ForEach(Permission.allCases, id: \.self) { permission in
                    Text(permission.localizedDescription).tag(permission)
                }
            }
            .pickerStyle(.segmented)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if let successMessage = successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Button(action: inviteUser) {
                HStack {
                    Spacer()
                    Image(systemName: "paperplane.fill")
                    Text("Einladung senden")
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(email.isEmpty)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func inviteUser() {
        Task { @MainActor in
            do {
                try await invitationManager.sendInvitation(email: email, tripId: tripId, permission: selectedPermission)
                self.successMessage = "Einladung an \(email) wurde versendet."
                self.email = ""
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
                self.successMessage = nil
            }
        }
    }
} 