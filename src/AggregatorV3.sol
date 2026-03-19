// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// @title AggregatorV3: A simple helper contract to fetch price and volatility data from Chainlink feeds
// @dev This contract is designed to interact with Chainlink's AggregatorV3Interface to retrieve the latest price and volatility data for ETH/USD. It can be used in conjunction with the other contracts to make informed decisions based on real-time market data.
// @notice Deployed address on ETH-Sepolia - 0x93a4C2C19C733D53724A990676a2f62C359BF7aa
contract AggregatorV3 {
    AggregatorV3Interface internal priceFeed;
    AggregatorV3Interface internal volatilityFeed;

    constructor(address _priceDataFeed, address _volatilityDataFeed) {
        // ETH-Sepolia (eth/usd) price data feed address - 0x694AA1769357215DE4FAC081bf1f309aDC325306
        priceFeed = AggregatorV3Interface(_priceDataFeed);
        // ETH-Sepolia (eth/usd) volatility data feed address (24H)- 0x31D04174D0e1643963b38d87f26b0675Bb7dC96e
        volatilityFeed = AggregatorV3Interface(_volatilityDataFeed);
    }

    // @dev This function retrieves the latest price data for ETH/USD from the Chainlink feed.
    function getETHUSDPrice() public view returns (int256) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        return answer;
    }

    // @dev This function retrieves the latest volatility data for ETH/USD from the Chainlink feed.
    function getETHUSDVolatility() public view returns (int256) {
        (, int256 answer,,,) = volatilityFeed.latestRoundData();
        return answer;
    }
}
