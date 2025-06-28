//
//  CustomTextFieldStyle.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import SwiftUI

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    let isValid: Bool
    
    init(isValid: Bool = true) {
        self.isValid = isValid
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .stroke(isValid ? Color(.systemGray4) : Color.red, lineWidth: 1)
            )
            .font(.body)
    }
} 