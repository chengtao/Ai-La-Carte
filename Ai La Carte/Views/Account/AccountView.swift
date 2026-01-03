//
//  AccountView.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Guest User")
                                .font(.headline)

                            Text("Sign in for personalized recommendations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Account") {
                    Button {
                        // TODO: Implement Sign in with Apple
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Sign in with Apple")
                        }
                    }
                }

                Section("Preferences") {
                    NavigationLink {
                        Text("Taste Profile Settings")
                    } label: {
                        Label("Taste Profile", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        Text("Notification Settings")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        Text("Privacy Policy")
                    } label: {
                        Text("Privacy Policy")
                    }

                    NavigationLink {
                        Text("Terms of Service")
                    } label: {
                        Text("Terms of Service")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        // TODO: Implement delete account
                    } label: {
                        Text("Delete Account")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AccountView()
}
