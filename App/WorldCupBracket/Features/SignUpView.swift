import AuthenticationServices
import SwiftUI

struct SignUpView: View {
    @Environment(AppModel.self) private var appModel
    @State private var currentNonce: String?
    @State private var authErrorMessage: String?
    private let configuration = AppConfiguration.main

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 14) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(AppBrand.name)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("Make your picks, create a group, and compare brackets with friends.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            VStack(spacing: 16) {
                SignInWithAppleButton(.signUp) { request in
                    do {
                        let nonce = try AppleSignInNonce.random()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleSignInNonce.sha256(nonce)
                    } catch {
                        authErrorMessage = "Could not prepare Apple sign in. Please try again."
                    }
                } onCompletion: { result in
                    Task {
                        await completeAppleSignIn(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let authErrorMessage {
                    Text(authErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

            }
            .padding(.horizontal, 24)

            Spacer()

            Text("\(AppBrand.shortPurpose) No cash rewards, prizes, betting, or gambling.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .background(AppBackground())
    }

    @MainActor
    private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            let (idToken, firstName) = try appleCredentialDetails(from: result)

            guard let currentNonce else {
                throw BackendServiceError.transportFailed("Apple sign-in nonce was missing.")
            }

            let services = try AppServices.live(configuration: configuration)
            let user = try await services.auth.signInWithApple(
                idToken: idToken,
                nonce: currentNonce,
                displayName: preferredDisplayName(appleFirstName: firstName)
            )
            appModel.displayName = user.displayName

            authErrorMessage = nil
            appModel.completeSignUp()
        } catch {
            authErrorMessage = "Apple sign in did not complete: \(error.authDiagnosticMessage)"
        }
    }

    private func appleCredentialDetails(from result: Result<ASAuthorization, Error>) throws -> (idToken: String, firstName: String?) {
        let authorization = try result.get()

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw BackendServiceError.notAuthenticated
        }

        let firstName = credential.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines)

        return (idToken, firstName?.isEmpty == false ? firstName : nil)
    }

    private func preferredDisplayName(appleFirstName: String?) -> String {
        appleFirstName ?? "Player"
    }
}

private extension Error {
    var authDiagnosticMessage: String {
        let nsError = self as NSError
        let localizedDescription = nsError.localizedDescription

        if localizedDescription != "The operation couldn’t be completed. (\(nsError.domain) error \(nsError.code).)" {
            return localizedDescription
        }

        return String(describing: self)
    }
}
