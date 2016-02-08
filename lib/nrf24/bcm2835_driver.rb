require 'bcm2835'

class NRF24
  module Bcm2835Driver

    def init_io
      @spi = Bcm2835::SPI.begin
      spi.clock Bcm2835::SPI::CLOCK_DIVIDER_128
      spi.bit_order(Bcm2835::SPI::MSBFIRST)
      Bcm2835::GPIO.output cepin
      Bcm2835::GPIO.output csnpin
    end

    def ce_high
      Bcm2835::GPIO.set cepin
    end

    def ce_low
      Bcm2835::GPIO.clear cepin
    end

    def csn_high
      Bcm2835::GPIO.set csnpin
    end

    def csn_low
      Bcm2835::GPIO.clear csnpin
    end

  end
end