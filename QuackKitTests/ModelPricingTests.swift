import Testing
import Foundation
@testable import QuackKit

struct ModelPricingTests {
    @Test func initAndProperties() {
        let pricing = ModelPricing(inputPerMTok: 3.0, outputPerMTok: 15.0)
        #expect(pricing.inputPerMTok == 3.0)
        #expect(pricing.outputPerMTok == 15.0)
    }

    @Test func costCalculationBasic() {
        let pricing = ModelPricing(inputPerMTok: 3.0, outputPerMTok: 15.0)
        let cost = pricing.cost(inputTokens: 1_000_000, outputTokens: 1_000_000)
        #expect(abs(cost - 18.0) < 0.001)
    }

    @Test func costCalculationWithReasoning() {
        let pricing = ModelPricing(inputPerMTok: 3.0, outputPerMTok: 15.0)
        let cost = pricing.cost(inputTokens: 1000, outputTokens: 500, reasoningTokens: 2000)
        let expected = (1000 * 3.0 / 1_000_000) + (500 * 15.0 / 1_000_000) + (2000 * 15.0 / 1_000_000)
        #expect(abs(cost - expected) < 0.0001)
    }

    @Test func costCalculationZeroTokens() {
        let pricing = ModelPricing(inputPerMTok: 3.0, outputPerMTok: 15.0)
        let cost = pricing.cost(inputTokens: 0, outputTokens: 0)
        #expect(cost == 0.0)
    }

    @Test func costCalculationDefaultReasoning() {
        let pricing = ModelPricing(inputPerMTok: 10.0, outputPerMTok: 30.0)
        let cost = pricing.cost(inputTokens: 100, outputTokens: 200)
        let expected = (100 * 10.0 / 1_000_000) + (200 * 30.0 / 1_000_000)
        #expect(abs(cost - expected) < 0.0001)
    }

    @Test func costCalculationSmallUsage() {
        let pricing = ModelPricing(inputPerMTok: 0.15, outputPerMTok: 0.60)
        let cost = pricing.cost(inputTokens: 500, outputTokens: 100, reasoningTokens: 50)
        let expected = (500 * 0.15 / 1_000_000) + (100 * 0.60 / 1_000_000) + (50 * 0.60 / 1_000_000)
        #expect(abs(cost - expected) < 0.000001)
    }

    @Test func zeroPricing() {
        let pricing = ModelPricing(inputPerMTok: 0, outputPerMTok: 0)
        let cost = pricing.cost(inputTokens: 1_000_000, outputTokens: 1_000_000, reasoningTokens: 500_000)
        #expect(cost == 0.0)
    }
}
