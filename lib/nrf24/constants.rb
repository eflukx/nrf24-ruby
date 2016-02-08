class NRF24

  COMMANDS = {
      :r_register => 0x00,
      :w_register => 0x20,
      :activate => 0x50, # non-plus register only
      :r_rx_pl_wid => 0x60,
      :r_rx_payload => 0x61,
      :w_tx_payload => 0xa0,
      :w_ack_payload => 0xa8,
      :w_tx_payload_noack => 0xb0,
      :flush_tx => 0xe1,
      :flush_rx => 0xe2,
      :reuse_tx_pl => 0xe3,
      :nop => 0xff
  }

  REGS = {
      :config => 0x00, # Configuration Register
      :en_aa => 0x01, # Enable ‘Auto Acknowledgment’ Function Disable this functionality to be compatible with nRF2401,
      :en_rxaddr => 0x02, # Enabled RX Addresses
      :setup_aw => 0x03, # Setup of Address Widths (common for all data pipes)
      :setup_retr => 0x04, # Setup of Automatic Retransmission
      :rf_ch => 0x05, # RF Channel
      :rf_setup => 0x06, # RF Setup Register (power, rate)
      :nrf_status => 0x07, # a.k.a. nrf24l01.rbStatus
      :status => 0x07,
      :observe_tx => 0x08, # Transmit observe register (packets lost, retransmits)
      :cd => 0x09, # Legacy (nRF24l01 non+) name
      :rpd => 0x09, # Received power detection (1 == > -64dBm)

      :rx_addr_p0 => 0x0a, # Receive address data pipe 0. 5 Bytes maximum length. (LSByte is written first. Write the number of bytes defined by SETUP_AW)
      :rx_addr_p1 => 0x0b, # Receive address data pipe 1. 5 Bytes maximum length. (LSByte is written first. Write the number of bytes defined by SETUP_AW)
      :rx_addr_p2 => 0x0c, # Receive address data pipe 2. Only LSB. MSBytes are equal to RX_ADDR_P1[39:8]
      :rx_addr_p3 => 0x0d, # Receive address data pipe 3. Only LSB. MSBytes are equal to RX_ADDR_P1[39:8]
      :rx_addr_p4 => 0x0e, # Receive address data pipe 4. Only LSB. MSBytes are equal to RX_ADDR_P1[39:8]
      :rx_addr_p5 => 0x0f, # Receive address data pipe 5. Only LSB. MSBytes are equal to RX_ADDR_P1[39:8]

      :tx_addr => 0x10, # Transmit address. Used for a PTX device only. (LSByte is written first) Set RX_ADDR_P0 equal to this address to handle automatic acknowledge if this is a PTX device with Enhanced ShockBurst™ enabled.

      :rx_pw_p0 => 0x11, # Number of bytes in RX payload in data pipe 0-5 (1 to 32 bytes).
      :rx_pw_p1 => 0x12, #
      :rx_pw_p2 => 0x13, # 0 Pipe not used
      :rx_pw_p3 => 0x14, # 1 = 1 byte
      :rx_pw_p4 => 0x15, # …
      :rx_pw_p5 => 0x16, # 32 = 32 bytes

      :fifo_status => 0x17, # FIFO Status Register
      :dynpd => 0x1c,
      :feature => 0x1d
  }

  # CONFIG
  MASK_RX_DR = 6
  MASK_TX_DS = 5
  MASK_MAX_RT = 4
  EN_CRC = 3
  CRCO = 2
  PWR_UP = 1
  PRIM_RX = 0

  # SETUP_RETR
  ARD = 4
  ARC = 0

  # STATUS
  RX_DR = 6 # Data Ready RX FIFO interrupt
  TX_DS = 5 # Data Sent TX FIFO interrupt
  MAX_RT = 4 # Maximum number of TX retransmits interrupt Write 1 to clear bit. If MAX_RT is asserted it must be cleared to enable further communication.
  RX_P_NO = 1 # bit 3:1 Data pipe number for the payload available for reading from RX_FIFO 000-101: Data Pipe Number 110: Not Used 111: RX FIFO Empty
  TX_FULL = 0 # TX FIFO full flag. 1: TX FIFO full. 0: Available locations in TX FIFO.

  # observe_tx
  PLOS_CNT = 4 # 7:4 Count lost packets. The counter is overflow protected to 15, and discontinues at max until reset. The counter is reset by writing to RF_CH.
  ARC_CNT = 0 # 3:0 Count retransmitted packets.

  # FIFO_STATUS
  TX_REUSE = 6
  FIFO_TX_FULL = 5
  FIFO_TX_EMPTY = 4
  FIFO_RX_FULL = 1
  FIFO_RX_EMPTY = 0

  # FEATURE
  EN_DPL = 2
  EN_ACK_PAY = 1
  EN_DYN_ACK = 0

  # RF_SETUP
  RF_DR_LOW = 5
  PLL_LOCK = 4
  RF_DR_HIGH = 3
  RF_PWR_LOW = 1
  RF_PWR_HIGH = 2
  LNA_HCURR = 0

   REGISTER_MASK = 0x1F

end
