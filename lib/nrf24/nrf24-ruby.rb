require_relative 'constants'
class NRF24

  class OverSizedPayload < RuntimeError
  end

  class TX_Timeout < RuntimeError
  end

  attr_reader :static_payload_size

  def self.begin *opts, &block
    nrf = NRF24.new *opts
    nrf.instance_eval &block if block_given?
  ensure
    nrf.send :radio_deinit
  end

  def start_listening
    set_register :config, get_register(:config) | bv(PRIM_RX)
    clear_interrupt_flags
    ce_high

    set_register :rx_addr_p0, @pipe0_reading_address if @pipe0_reading_address # Restore address, as this could be overwritten during a PTX cycle (Pipe 0 is used for receiving auto-acks)

    flush_tx if dynamic_ack_payload_enabled?
  end

  def stop_listening
    ce_low
    flush_tx if dynamic_ack_payload_enabled?
    set_register :config, get_register(:config) & inv_bv(PRIM_RX)
    set_register :en_rxaddr, get_register(:en_rxaddr) | 1
  end

  def write_no_ack payload, *args
    write(payload, :no_ack, *args)
  end

  def write payload, type = :ack, timeout = 2
    start = Time.now

    while fifo_tx_full?
      if status[MAX_RT] > 0
        set_register :nrf_status, bv(MAX_RT)
        return :max_rt
      end
      raise TX_Timeout, "TX FIFO full" if Time.now - start > timeout
    end

    write_payload payload, type

    pulse_ce
  end

  def write_payload payload, type = :ack
    if dynamic_payload_enabled?
      raise OverSizedPayload if payload.size > 32
      padding = 0
    else
      raise OverSizedPayload if payload.size > static_payload_size
      padding = static_payload_size - payload.size
    end

    with_csn {
      spi.write COMMANDS[type == :no_ack ? :w_tx_payload_noack : :w_tx_payload]
      spi.write payload
      spi.write ([0] * padding)
    }
  end

  def open_writing_pipe address
    set_register :rx_addr_p0, address
    set_register :tx_addr, address
    set_register :rx_pw_p0, static_payload_size
  end

  def set_ack_payload pipe, payload
    raise OverSizedPayload, "ack payload can be 32 bytes max!" if payload.size > 32
    with_csn {
      spi.write COMMANDS[:w_ack_payload] | (pipe & 7)
      spi.write payload
    }
  end

  def enable_auto_ack pipes = :all
    if pipes == :all
      set_register :en_aa, 0b111111
    elsif pipes.is_a? Enumerable
      pipes.map { |p| enable_auto_ack p }
    else
      return if pipes > 5
      set_register :en_aa, get_register(:en_aa) | bv(pipes)
    end
  end

  def disable_auto_ack pipes = :all
    if pipes == :all
      set_register :en_aa, 0
    elsif pipes.is_a? Enumerable
      pipes.map { |p| disable_auto_ack p }
    else
      return if pipes > 5
      set_register :en_aa, get_register(:en_aa) & inv_bv(pipes)
    end
  end

  def read
    payload = read_payload
    clear_interrupt_flags
    payload
  end

  def read_payload
    send_command :r_rx_payload, payload_size
  end

  def open_reading_pipe pipe, address
    @pipe0_reading_address = address if pipe == 0

    if pipe <= 5
      if pipe < 2
        set_register REGS[:rx_addr_p0] + pipe, address
      else
        set_register REGS[:rx_addr_p0] + pipe, address.first # Only LSB TODO Handle Numeric (byte) address
      end
      set_register REGS[:rx_pw_p0] + pipe, static_payload_size

      set_register :en_rxaddr, get_register(:en_rxaddr) | bv(pipe)
    end
  end

  def close_reading_pipe pipe
    set_register :en_rxaddr, get_register(:en_rxaddr) & inv_bv(pipe)
  end

  def payload_size
    if dynamic_payload_enabled?
      get_dynamic_payload_size
    else
      static_payload_size
    end
  end

  def set_payload_size pipe, size
    if pipe.is_a? Enumerable
      pipe.map { |p| set_payload_size p, size }
    else
      return if pipe > 5 # Lets make sure not to screw up other regs
      set_register(REGS[:rx_pw_p0] + pipe, size)
    end
  end

  def get_dynamic_payload_size
    send_command :r_rx_pl_wid, 1
  end

  def enable_dynamic_payloads
    set_register :feature, get_register(:feature) | bv(EN_DPL)
    set_register :dynpd, 63 # Enable for all pipes
  end

  def disable_dynamic_payloads
    set_register :feature, get_register(:feature) & inv_bv(EN_DPL)
    set_register :dynpd, 0
  end

  def dynamic_payload_enabled?
    get_register(:feature)[EN_DPL] > 0
  end

  def enable_dynamic_ack
    set_register :feature, get_register(:feature) | bv(EN_DYN_ACK)
  end

  def disable_dynamic_ack
    set_register :feature, get_register(:feature) & inv_bv(EN_DYN_ACK)
  end

  def dynamic_ack_enabled?
    get_register(:feature)[EN_DYN_ACK] > 0
  end

  def enable_ack_payload
    set_register :feature, get_register(:feature) | bv(EN_ACK_PAY)
  end

  def disable_ack_payload
    set_register :feature, get_register(:feature) & inv_bv(EN_ACK_PAY)
  end

  def dynamic_ack_payload_enabled?
    get_register(:feature)[EN_ACK_PAY] > 0
  end

  def power_up
    config = get_register(:config)
    if config[PWR_UP] == 0
      set_register :config, config | bv(PWR_UP)
      sleep 0.01
    end
  end

  def power_down
    ce_low
    config = get_register(:config) & inv_bv(PWR_UP)
    set_register :config, config
  end

  def channel
    get_register :rf_ch
  end

  def set_channel ch
    set_register :rf_ch, ch
  end

  def rf_setup datarate = :rate_1mbps, power = :max_power
    available_rates = {
        :rate_250kbps => 32, 250 => 32,
        :rate_1mbps => 0, 1 => 0, 1000 => 0,
        :rate_2mbps => 8, 2 => 8, 2000 => 8
    }

    pa_settings = {
        :min_power => 0, -18 => 0, 18 => 0,
        :low_power => 2, -12 => 2, 12 => 2,
        :high_power => 4, -6 => 4, 6 => 4,
        :max_power => 6, 0 => 6
    }

    rate = available_rates[datarate]
    power = pa_settings[power]

    return nil unless rate && power

    set_register :rf_setup, (rate | power)
    get_register :rf_setup
  end

  def datarate
    rf_setup = get_register :rf_setup

    if rf_setup[RF_DR_LOW] == 1
      :rate_250kbps
    elsif rf_setup[RF_DR_HIGH] == 1
      :rate_2mbps
    else
      :rate_1mbps
    end
  end

  def crc_length
    config = get_register(:config)

    if config[EN_CRC] > 0 or get_register(:en_aa) > 0
      config[CRCO] == 1 ? :crc_16 : :crc_8
    else
      :crc_none
    end
  end

  def set_crc_length length
    config = get_register(:config) & (~(bv(CRCO) | bv(EN_CRC)) & 0xff)

    if [:crc_16, 16, 2].include? length
      config |= (bv(EN_CRC) | bv(CRCO))
    elsif [:crc_8, 8, 1].include? length
      config |= bv(EN_CRC)
    end
    set_register :config, config
  end

  def disable_crc
    set_register :config, get_register(:config) & inv_bv(EN_CRC)
  end

  def set_retries delay, count
    set_register :setup_retr, ((delay & 0xf) << ARD) | ((count & 0xf) << ARC)
  end

  def set_tx_address addr
    set_register :tx_addr, addr
  end

  def address_width
    @address_width || (get_register(:setup_aw) + 2)
  end

  def set_address_width aw = 5
    aw = (aw - 2) % 4;
    set_register :setup_aw, aw
    @address_width = aw + 2
  end

  def flush_tx
    send_command :flush_tx
  end

  def flush_rx
    send_command :flush_rx
  end

  def reuse_tx_payload
    set_register :nrf_status, bv(MAX_RT)
    send_commnad :reuse_tx_pl
    pulse_ce
  end

  def data_available?
    (status >> RX_P_NO) & 0b111 if not fifo_rx_empty?
  end

  def fifo_tx_full?
    get_register(:fifo_status)[FIFO_TX_FULL] > 0
  end

  def fifo_tx_empty?
    get_register(:fifo_status)[FIFO_TX_EMPTY] > 0
  end

  def fifo_rx_full?
    get_register(:fifo_status)[FIFO_RX_FULL] > 0
  end

  def fifo_rx_empty?
    get_register(:fifo_status)[FIFO_RX_EMPTY] > 0
  end

  def fifo_flags
    flags = []

    flags << :tx_full if fifo_tx_full?
    flags << :tx_empty if fifo_tx_empty?
    flags << :rx_full if fifo_rx_full?
    flags << :rx_empty if fifo_rx_empty?

    flags
  end

  def rx_dr?
    status[RX_DR] > 0
  end

  def tx_ds?
    status[TX_DS] > 0
  end

  def max_rt?
    status[MAX_RT] > 0
  end

  def interruptq_flags
    flags = []

    flags << :rx_dr if rx_dr?
    flags << :rx_dr if tx_ds?
    flags << :rx_dr if max_rt?

    flags
  end

  def clear_interrupt_flags
    set_register :nrf_status, (1 << RX_DR) | (1 << TX_DS) | (1 << MAX_RT)
  end

  def received_power
    get_register(:rpd)
  end

  def activate
    send_command :activate, 0x73
  end

  def status
    with_csn {
      spi.read
    }
  end

  def set_register reg, value
    reg = REGS[reg] unless reg.is_a? Numeric
    with_csn {
      spi.write(COMMANDS[:w_register] | (REGISTER_MASK & reg))
      spi.write value
    }
  end

  def get_register reg, len = 1
    reg = REGS[reg] unless reg.is_a? Numeric
    with_csn {
      spi.write(COMMANDS[:r_register] | (REGISTER_MASK & reg))
      len == 1 ? spi.read : spi.read(len) # do not return an array when len == 1
    } if reg
  end

  def send_command command, data_len = 0
    command = COMMANDS[command] unless command.is_a? Numeric
    with_csn {
      spi.write command
      if data_len == 1
        spi.read
      elsif data_len > 1
        spi.read(data_len)
      end
    }
  end

  def print_regs
    REGS.each do |i, v|
      len = [:rx_addr_p0, :rx_addr_p1, :tx_addr].include?(i) ? address_width : 1
      puts "register #{v.to_s(16).rjust(2, "0")} (#{i}): #{get_register i, len}"
    end
  end

  private

  alias_method :channel=, :set_channel
  alias_method :tx_address=, :set_tx_address
  alias_method :address_width=, :set_address_width
  alias_method :crc_length=, :set_crc_length

  attr_reader :spi, :cepin, :csnpin

  def initialize opts = {}
    opts = {cepin: 22, csnpin: 8, static_payload_size: 32, channel: 76, driver: Bcm2835Driver}.merge opts

    @cepin = opts[:cepin]
    @csnpin = opts[:csnpin]
    @static_payload_size = [opts[:static_payload_size], 32].min
    @channel = opts[:channel]

    extend opts[:driver]

    init_io
    radio_init

    @pipe0_reading_address = nil
  end

  def radio_init
    activate # nrf24l01 (non-plus) compatibility

    set_address_width

    set_channel @channel

    set_payload_size (0..5), static_payload_size
    disable_dynamic_payloads
    enable_auto_ack

    set_register :config, ((1 << EN_CRC) | (1 << CRCO) | (1 << PWR_UP) | (1 << PRIM_RX))

    clear_interrupt_flags

    flush_rx
    flush_tx
  end

  def radio_deinit
    ce_low
    radio_init
    rf_setup
    set_channel 0
  end

  def with_csn
    csn_low
    ret = yield
    csn_high
    ret
  end

  def with_ce
    ce_high
    ret = yield
    ce_low
    ret
  end

  def pulse_ce us = 10
    ce_high
    sleep(0.000001 * us)
    ce_low
  end

  # Low level bit vector stuff
  def bv d
    1 << d
  end

  def inv_bv d, mask = 0xff
    ~(1 << d) & mask
  end

end
