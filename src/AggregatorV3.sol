// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// Deployed address on ETH-Sepolia - 0x93a4C2C19C733D53724A990676a2f62C359BF7aa
contract AggregatorV3 {
  AggregatorV3Interface internal priceFeed;
  AggregatorV3Interface internal volatilityFeed;

  constructor(address _priceDataFeed, address _volatilityDataFeed) {
    // ETH-Sepolia (eth/usd) price data feed address - 0x694AA1769357215DE4FAC081bf1f309aDC325306
    priceFeed = AggregatorV3Interface(_priceDataFeed); 
    // ETH-Sepolia (eth/usd) volatility data feed address (24H)- 0x31D04174D0e1643963b38d87f26b0675Bb7dC96e
    volatilityFeed = AggregatorV3Interface(_volatilityDataFeed); 
  }

  function getETHUSDPrice() public view returns (int256) {
    (,int256 answer,,,) = priceFeed.latestRoundData();
    return answer;
  }

  function getETHUSDVolatility() public view returns (int256) {
    (,int256 answer,,,) = volatilityFeed.latestRoundData();
    return answer;
  }
}
