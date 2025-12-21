//
//  main.swift
//  Services
//
//  Created by Thomas Rademaker on 12/6/25.
//

import Compute

let router = Router()
BTCPriceRoutes.register(router)
try await router.listen()
