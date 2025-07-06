//
//  AuthorizationInterceptor.swift
//  Journiary
//
//  Created by Gemini on 08.06.25.
//

import Foundation
import Apollo
import ApolloAPI

class AuthorizationInterceptor: ApolloInterceptor {
    
    public var id: String = UUID().uuidString

    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            if let token = AuthService.shared.getToken() {
                request.addHeader(name: "Authorization", value: "Bearer \(token)")
            }
            
            chain.proceedAsync(
                request: request,
                response: response,
                interceptor: self,
                completion: completion
            )
        }
    }
} 