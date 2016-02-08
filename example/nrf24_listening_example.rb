require 'msgpack'
require 'nrf24-ruby'

def with_block

  NRF24.begin(channel: 85) {
    puts "setting channel to #{ch = rand 125}"
    # ch=85
    # set_channel ch
    print_regs

    rf_setup :rate_250kbps, :max_power
    open_reading_pipe 1, 'AAAAA'.unpack('c*')
    start_listening

    loop do
      if data_available?
        p read
        puts "bytes received: #{read.count}"
      end
    end

  }
end

def classic
  nrf = NRF24.new channel: 85

  nrf.rf_setup :rate_250kbps, :max_power

  address = 'AAAAA'.unpack('c*')
  nrf.open_reading_pipe 1, address

  nrf.start_listening

  nrf.print_regs
  nrf.flush_rx

  loop do
    if pipe = nrf.data_available?
      puts "Got data on pipe #{pipe}, FIFO flags: #{nrf.fifo_flags}"
      data  = nrf.read
      p data
    end

    sleep 0.1
  end

end

classic
