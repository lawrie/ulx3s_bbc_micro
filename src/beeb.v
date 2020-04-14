// =======================================================================
// Ice40Beeb
//
// A BBC Micro Model B implementation for the Ulx3s ECP5 board
//
// Copyright (C) 2017 David Banks for Ice40 version
// Copyright (C) 2020 Lawrie Griffiths for Ulx3s version
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see http://www.gnu.org/licenses/.
// =======================================================================

`default_nettype none
module beeb
   (
    // Main clock, 25MHz
    input         clk25_mhz,
    // Flash memory
    output        flash_csn,
    output        flash_mosi,
    input         flash_miso,
    // SD Card SPI master
    output        ss,
    output        sclk,
    output        mosi,
    input         miso,
    // Cassette
    input         cas_in,
    output        cas_out,
    // Audio
    output  [3:0] audio_l,
    output  [3:0] audio_r,
    // Leds
    output [7:0] leds,
    // Buttons
    input   [6:0] btn,
    // Keyboard
    output        usb_fpga_pu_dp,
    output        usb_fpga_pu_dn,
    input         ps2_clk,
    input         ps2_data,
    // Video
    output [3:0]  red,
    output [3:0]  green,
    output [3:0]  blue,
    output        hsync,
    output        vsync,
    output [15:0] diag
    );

   assign diag = beeb_RAMA;

   // pull-ups for us2 connector
   assign usb_fpga_pu_dp = 1;
   assign usb_fpga_pu_dn = 1;

   // Get access to flash_sck
   wire flash_sck;
   wire tristate = 1'b0;

   USRMCLK u1 (.USRMCLKI(flash_sck), .USRMCLKTS(tristate));

   // ===============================================================
   // System Clock generation (25MHz)
   // ===============================================================
   wire clk100, locked;

   pll pll_i (
     .clkin(clk25_mhz),
     .clkout0(clk100),
     .locked(locked)
   );

   reg            clock32;
   reg            clock24;
   reg [4:0]      clkdiv = 5'b0;

   always @(posedge clk100)
     begin
        // clkdiv counts 0..24, i.e. 250ns / 4MHz
        if (clkdiv == 24)
          clkdiv <= 0;
        else
          clkdiv <= clkdiv + 1;
        // 32MHz == 8 ticks in 250ns, so ~every 3 cycles
        if (clkdiv == 0 | clkdiv == 3 | clkdiv == 6 | clkdiv == 9 | clkdiv == 12 | clkdiv == 15 | clkdiv == 18 | clkdiv == 21)
          clock32 <= 1'b1;
        else
          clock32 <= 1'b0;
        // 24MHz == 6 ticks in 250ns, so ~every 4 cycles
        if (clkdiv == 0 | clkdiv == 4 | clkdiv == 8 | clkdiv == 12 | clkdiv == 16 | clkdiv == 20)
          clock24 <= 1'b1;
        else
          clock24 <= 1'b0;
     end

   // ===============================================================
   // Reset generation
   // ===============================================================

   reg [15:0] pwr_up_reset_counter = 0; // hold reset low for ~1ms
   wire      pwr_up_reset_n = &pwr_up_reset_counter;
   reg       hard_reset_n;

   always @(posedge clock32)
     begin
        if (!pwr_up_reset_n)
          pwr_up_reset_counter <= pwr_up_reset_counter + 1;
        hard_reset_n <= btn[0] & pwr_up_reset_n;
     end

   wire reset = !hard_reset_n | !load_done;

   // ===============================================================
   // LEDs
   // ===============================================================

   wire caps_lock_led_n;
   wire shift_lock_led_n;
   wire break_led_n;
   reg  rgb_mode = 0;

   reg        led1;
   reg        led2;
   reg        led3;
   reg        led4;
   reg        led5;
   reg        led6;
   reg        led7;
   reg        led8;

   always @(posedge clock32)
     begin
	led8 <= load_done;
	led7 <= reset;
	led6 <= hard_reset_n;
	led5 <= beeb_RAMWE_b;
        led4 <= !caps_lock_led_n;  // blue
        led3 <= !shift_lock_led_n; // green
        led2 <= !break_led_n;      // yellow
        led1 <= rgb_mode;          // red
     end

   assign leds = {led8, led7, led6, led5, led4, led3, led2, led1};

   // ==============================================================
   // Flash memory
   // ==============================================================
   reg         load_done;
   reg  [16:0] load_addr;
   wire [7:0]  load_write_data;

   wire        flashmem_valid = !load_done;
   wire        flashmem_ready;
   wire        load_wren = flashmem_ready;
   wire [23:0] flashmem_addr = 24'h80000 + load_addr;
   reg         load_done_pre;
   reg [7:0]   wait_ctr;

  // Flash memory load interface
   always @(posedge clock32)
   begin
     if (!hard_reset_n) begin
       load_done_pre <= 1'b0;
       load_done <= 1'b0;
       load_addr <= 17'h0000;
       wait_ctr <= 8'h00;
     end else begin
       if (!load_done_pre) begin
         if (flashmem_ready == 1'b1) begin
           if (load_addr == 17'hbfff) begin
             load_done_pre <= 1;
           end else begin
             load_addr <= load_addr + 1;
           end
         end
       end else begin
         if (wait_ctr < 8'hFF)
           wait_ctr <= wait_ctr + 1;
         else
           load_done <= 1'b1;
       end
     end
   end

   icosoc_flashmem flash_i (
     .clk(clock32),
     .reset(!hard_reset_n),
     .valid(flashmem_valid),
     .ready(flashmem_ready),
     .addr(flashmem_addr),
     .rdata(load_write_data),

     .spi_cs(flash_csn),
     .spi_sclk(flash_sck),
     .spi_mosi(flash_mosi),
     .spi_miso(flash_miso)
   );

   // ===============================================================
   // Keyboard
   // ===============================================================

   wire       ps2_clk_int;
   wire       ps2_data_int;

   assign ps2_clk_int = ps2_clk;
   assign ps2_data_int = ps2_data;

   // ===============================================================
   // Audio DAC
   // ===============================================================

   wire [15:0] audio;
   wire sound;

   pwm_sddac dac
     (
     .clk_i             (clk100),
     .reset             (reset),
     .dac_i             (audio[15:6]),
     .dac_o             (sound)
      );

   assign cas_out  = 1'b0;
   assign audio_l = sound ? 4'b1111 : 4'b0;
   assign audio_r = sound ? 4'b1111 : 4'b0;

   // ===============================================================
   // Video
   // ===============================================================

   wire       r;
   wire       g;
   wire       b;
   wire       hs;
   wire       vs;
   wire       vid_clken;
   wire       vga_hs;
   wire       vga_vs;
   wire [5:0] vga_r;
   wire [5:0] vga_g;
   wire [5:0] vga_b;

   assign red   = rgb_mode ? {4{r}}     : vga_r[5:2];
   assign green = rgb_mode ? {4{g}}     : vga_g[5:2];
   assign blue  = rgb_mode ? {4{b}}     : vga_b[5:2];
   assign hsync = rgb_mode ? !(vs | hs) : vga_hs;
   assign vsync = rgb_mode ? 1'b0       : vga_vs;

   mist_scandoubler SD (
     // system interface
     .clk_x2(clock32),
     .clk_pix(clock32),
     .clken_pix(vid_clken),
     // scanlines (00-none 01-25% 10-50% 11-75%)
     .scanlines(2'b00),
     // shifter video interface
     .hs_in(hs),
     .vs_in(vs),
     .r_in({6{r}}),
     .g_in({6{g}}),
     .b_in({6{b}}),

     // output interface
     .hs_out(vga_hs),
     .vs_out(vga_vs),
     .r_out(vga_r),
     .g_out(vga_g),
     .b_out(vga_b)
   );

   // ===============================================================
   // Mist BBC Core
   // ===============================================================

   wire [17:0] beeb_RAMA;
   wire        beeb_RAMOE_b;
   wire        beeb_RAMWE_b;
   wire [7:0]  beeb_RAMDin;
   wire [7:0]  beeb_RAMDout;

   ram ram96 (
     .clk(clk100),
     .we(load_done ? !beeb_RAMWE_b : load_wren),
     //.we(load_done ? 1'b0 : load_wren),
     .addr(load_done ? beeb_RAMA[16:0] : (17'hc000 + load_addr)),
     //.addr(load_done ? 17'hfffc : (17'hc000 + load_addr)),
     .din(load_done ? beeb_RAMDin : load_write_data),
     .dout(beeb_RAMDout)
   );

   bbc BBC
     (

      .CLK32M_I(clock32),
      .CLK24M_I(clock24),
      .RESET_I(reset),

      .HSYNC(hs),
      .VSYNC(vs),

      .VIDEO_CLKEN(vid_clken),
      .VIDEO_R(r),
      .VIDEO_G(g),
      .VIDEO_B(b),

      // RAM Interface (CPU)
      .ext_A(beeb_RAMA),
      .ext_nOE(beeb_RAMOE_b),
      .ext_nWE(beeb_RAMWE_b),
      .ext_Din(beeb_RAMDin),
      .ext_Dout(beeb_RAMDout),

      .MEM_SYNC(),   // signal to synchronite sdram state machine

      // Keyboard interface
      .PS2_CLK(ps2_clk_int),
      .PS2_DAT(ps2_data_int),

      // audio signal.
      .AUDIO_L(audio),
      .AUDIO_R(),

      // externally pressed "shift" key for autoboot
      .SHIFT(1'b0),

      // SD Card
      .ss(ss),
      .sclk(sclk),
      .mosi(mosi),
      .miso(miso),

      // analog joystick input
      .joy_but(2'b0),
      .joy0_axis0(8'h00),
      .joy0_axis1(8'h00),
      .joy1_axis0(8'h00),
      .joy1_axis1(8'h00),

      // boot settings
      .DIP_SWITCH(8'b00000000),

      // LEDs
      .caps_lock_led_n(caps_lock_led_n),
      .shift_lock_led_n(shift_lock_led_n),
      .break_led_n(break_led_n)
      );

endmodule
