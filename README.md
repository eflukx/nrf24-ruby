# nRF24 lib for Ruby

nrf24-ruby is a pure Ruby library for controlling the ubiquitous nRF24l01(+) radio module. Currently primary target is
the Raspberry Pi, but it shouldn't be too hard to port to a different platform (supporting SPI).
 
No webserver, no message bus, no frills, yet a fully functional lib written in clear Ruby. (If you're in need of frills,
bells, whistles and the like. This library gem works merrily together with all kinds of whistle implementing gems :smile:)   

This gem was based on the [C++ RF24 library by tmrh20](https://github.com/TMRh20/RF24). I made the Ruby implementation
mostly because wrapping C++ from Ruby sucks donkey balls.  

## Installing
We rely on the bcm2835 gem which wraps the [bcm2835 C library](http://www.airspayce.com/mikem/bcm2835). Therefore we need
this C lib installed on our system.

Build the lib
 
    wget http://www.airspayce.com/mikem/bcm2835/bcm2835-1.49.tar.gz
    tar zxvf bcm2835-1.49.tar.gz
    cd bcm2835-1.49
    ./configure
    make
    sudo make check
    
Make the shared library (.so file) and copy into the correct location
    
    cd src
    gcc -shared -o libbcm2835.so bcm2835.o
    sudo cp libbcm2835.so /usr/local/lib
    

**caveat** Currently we're calling directly into the BCM2835 protected memory space, so we need to run as root.

Add this line to your application's Gemfile:

```ruby
gem 'nrf24-ruby'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nrf24-ruby

 

## Examples

```ruby
require 'nrf24-ruby'
```

The lib may be called using a block

```ruby
NRF24.begin {

  set_channel 23
  
  print_regs

  open_reading_pipe 1, [65, 65, 65, 65, 65]
  
  start_listening

  loop do
    p read if data_available?
    sleep 0.01
  end

}
``` 
Or use the plain old class based approach

```ruby
nrf = NRF24.new(channel: 0x4c)

nrf.rf_setup :rate_250kbps, :max_power

address = 'AAAAA'.unpack('c*')\
nrf.open_reading_pipe 1, address

nrf.start_listening

loop do
  if pipe = nrf.data_available?
    puts "data on pipe #{pipe}, fifo flags: #{nrf.fifo_flags}"
    data  = nrf.read
    p data
  end

  sleep 0.1 # Currently interrupt handling is not supported in Raspberry Pi, so we need to poll for new data
end
```