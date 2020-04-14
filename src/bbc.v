`timescale 1ns / 1ps

module bbc(

   input             CLK32M_I,
   input             CLK24M_I,

   input             RESET_I,

   output            HSYNC,
   output            VSYNC,

   output            VIDEO_CLKEN,
   output            VIDEO_R,
   output            VIDEO_G,
   output            VIDEO_B,

    // RAM Interface (CPU)

   output reg [17:0] ext_A,
   output reg        ext_nOE,
   output reg        ext_nWE,
   output reg [7:0]  ext_Din,
   input [7:0]       ext_Dout,

   output            MEM_SYNC, // signal to synchronite sdram state machine

   // Keyboard interface
   input             PS2_CLK,
   input             PS2_DAT,

   // audio signal.
   output [15:0]     AUDIO_L,
   output [15:0]     AUDIO_R,

   // externally pressed "shift" key for autoboot
   input             SHIFT,

   // SD Card
   output            ss,
   output            sclk,
   output            mosi,
   input             miso,
           
   // analog joystick input
   input [1:0]       joy_but,
   input [7:0]       joy0_axis0,
   input [7:0]       joy0_axis1,
   input [7:0]       joy1_axis0,
   input [7:0]       joy1_axis1,

   // boot settings
   input [7:0]       DIP_SWITCH,

   // LEDs
   output            caps_lock_led_n,
   output            shift_lock_led_n,
   output            break_led_n
);

// let sdram state machine synchronize to cpu
assign MEM_SYNC = cpu_clken;

wire       ram_we;

//  ROM select latch
reg  [3:0] romsel;

// clock enable signals

wire mhz4_clken;
wire mhz2_clken;
wire mhz1_clken;

wire ttxt_clken;
wire ttxt_clkenx2;
wire tube_clken;

wire cpu_clken;
wire cpu_cycle;

// decode signals
wire    ddr_enable;

wire    ram_enable;
wire    rom_enable;
wire    mos_enable;

wire    io_fred;
wire    io_jim;
wire    io_sheila;

// SHEILA
wire     crtc_enable;
wire     acia_enable;
wire     serproc_enable;
wire     vidproc_enable;
wire     romsel_enable;
wire     sys_via_enable;
wire     user_via_enable;
wire     fddc_enable;
wire     adlc_enable;
wire     adc_enable;
wire     tube_enable;
wire     mhz1_enable;

//  CPU signals
//  6502
localparam CPU_MODE = 2'd0;
wire    cpu_ready = 1'b 1;
wire    cpu_abort_n = 1'b 1;
wire    cpu_nmi_n  = 1'b 1;
wire    cpu_so_n = 1'b 1;
wire    cpu_irq_n;
reg     cpu_r_nw;
wire    cpu_we_next;

reg    [15:0] cpu_a;
wire    [15:0] cpu_a_next;
wire    [7:0] cpu_di;
//reg     [7:0] cpu_di_r;
reg    [7:0] cpu_do;
wire    [7:0] cpu_do_next;

//  CRTC signals
wire    crtc_clken;
wire    crtc_clken_adr;
wire    [7:0] crtc_do;
wire    crtc_de;
wire    crtc_cursor;
reg     crtc_lpstb;
wire    [13:0] crtc_ma;
wire    [4:0] crtc_ra;

//  Decoded display address after address translation for hardware
//  scrolling
reg     [14:0] display_a;

//  "VIDPROC" signals
wire    vidproc_invert_n;
wire    vidproc_disen;

// ADC signals
wire    [7:0] adc_do;

//  SAA5050 signals
wire    ttxt_glr;
wire    ttxt_dew;
wire    ttxt_crs;
wire    ttxt_lose;
wire    ttxt_r;
wire    ttxt_g;
wire    ttxt_b;

//  Must loop back output pins or keyboard won't work
wire [3:0] keyb_column = sys_via_pa_out[3:0];
wire [2:0] keyb_row = sys_via_pa_out[6:4];
wire    keyb_out;
wire    keyb_int;
wire    keyb_break;

// internal reset signals
wire hard_reset_n = ~RESET_I;  
wire reset_n = ~RESET_I & ~keyb_break;

//  IC32 latch on System VIA
reg     [7:0] ic32;
wire    sound_enable_n;
wire    speech_read_n;
wire    speech_write_n;
wire    keyb_enable_n;
wire    [1:0] disp_addr_offs;

//  Sound generator
wire    sound_ready;
wire    [7:0] sound_di;
wire    [7:0] sound_ao;

//  System VIA signals
wire    [7:0] sys_via_do;
reg    [7:0] sys_via_do_r;
wire    sys_via_do_oe_n;
wire    sys_via_irq_n;
wire     sys_via_ca1_in;
wire     sys_via_ca2_in;
wire    sys_via_ca2_out;
wire    sys_via_ca2_oe_n;
wire    [7:0] sys_via_pa_in;
wire    [7:0] sys_via_pa_out;
wire    [7:0] sys_via_pa_oe_n;
wire     sys_via_cb1_in;
wire    sys_via_cb1_out;
wire    sys_via_cb1_oe_n;
wire     sys_via_cb2_in;
wire    sys_via_cb2_out;
wire    sys_via_cb2_oe_n;
wire    [7:0] sys_via_pb_in;
wire    [7:0] sys_via_pb_out;
wire    [7:0] sys_via_pb_oe_n;

//  User VIA signals
wire    [7:0] user_via_do;
reg    [7:0] user_via_do_r;
wire    user_via_do_oe_n;
wire    user_via_irq_n;
wire    user_via_ca1_in;
wire    user_via_ca2_in;
wire    user_via_ca2_out;
wire    user_via_ca2_oe_n;
wire    [7:0] user_via_pa_in;
wire    [7:0] user_via_pa_out;
wire    [7:0] user_via_pa_oe_n;
wire    user_via_cb1_in;
wire    user_via_cb1_out;
wire    user_via_cb1_oe_n;
wire    user_via_cb2_in;
wire    user_via_cb2_out;
wire    user_via_cb2_oe_n;
wire    [7:0] user_via_pb_in;
wire    [7:0] user_via_pb_out;
wire    [7:0] user_via_pb_oe_n;

// calulation for display address

reg     [3:0]  process_3_aa;

// Basic Clock Generation

clocks CLOCKS(

   .clk_32m       ( CLK32M_I  ), // master clock
   .clk_24m       ( CLK24M_I  ),
   .reset_n       ( hard_reset_n   ),

   .vid_clken     ( VIDEO_CLKEN     ),

   .mhz4_clken    ( mhz4_clken   ),
   .mhz2_clken    ( mhz2_clken   ),
   .mhz1_clken    ( mhz1_clken   ),

   .mhz1_enable   ( mhz1_enable  ),

   .cpu_cycle     ( cpu_cycle    ),
   .cpu_clken     ( cpu_clken    ),

   .ttxt_clken    ( ttxt_clken   ),
   .ttxt_clkenx2  ( ttxt_clkenx2 ),

   .tube_clken    ( tube_clken   )
);


address_decode ADDRDECODE(
   .cpu_a(cpu_a),
   .romsel(romsel),
   .ddr_enable(ddr_enable),
   .ram_enable(ram_enable),
   .rom_enable(rom_enable),
   .mos_enable(mos_enable),
    .io_fred(io_fred),
    .io_jim(io_jim),
    .io_sheila(io_sheila),
   .crtc_enable(crtc_enable),
   .acia_enable(acia_enable),
   .serproc_enable(serproc_enable),
   .vidproc_enable(vidproc_enable),
   .romsel_enable(romsel_enable),
   .sys_via_enable(sys_via_enable),
   .user_via_enable(user_via_enable),
   .fddc_enable(fddc_enable),
   .adlc_enable(adlc_enable),
   .adc_enable(adc_enable),
   .tube_enable(tube_enable),
   .mhz1_enable(mhz1_enable)
);

cpu CPU
  (
   .clk    ( CLK32M_I     ),
   .reset  ( ~reset_n     ),
   .IRQ    ( ~cpu_irq_n   ),
   .NMI    ( ~cpu_nmi_n   ),
   .WE     ( cpu_we_next  ),
   .AB     ( cpu_a_next   ),
   .DI     ( cpu_di       ),
   .DO     ( cpu_do_next  ),
   .RDY    ( cpu_clken )
);

   // The outputs of Arlets's 6502 core need registing
   always @(posedge CLK32M_I)
     begin
        if (cpu_clken)
          begin
             cpu_a    <= cpu_a_next;
             cpu_do   <= cpu_do_next;
             cpu_r_nw <= ~cpu_we_next;
          end
     end


   // This is needed as in v003 of the 6522 data out is only valid while I_P2_H is asserted
   // I_P2_H is driven from mhz1_clken
   always @(posedge CLK32M_I)
     begin
        if (mhz1_clken)
          begin
             user_via_do_r <= user_via_do;
             sys_via_do_r  <= sys_via_do;
          end
     end

m6522 SYS_VIA (
     //  System VIA is reset by power on reset only
    .ENA_4(mhz4_clken),
    .CLK(CLK32M_I),
    .I_RS(cpu_a[3:0]),
    .I_DATA(cpu_do),
    .O_DATA(sys_via_do),
    .O_DATA_OE_L(sys_via_do_oe_n),
    .I_RW_L(cpu_r_nw),
    .I_CS1(sys_via_enable),
    .I_CS2_L(1'b 0), // nCS2(1'b 0),
    .O_IRQ_L(sys_via_irq_n),
    .I_P2_H(mhz1_clken),
    .RESET_L(hard_reset_n),

    .I_CA1(sys_via_ca1_in),
    .I_CA2(sys_via_ca2_in),
    .O_CA2(sys_via_ca2_out),
    .O_CA2_OE_L(sys_via_ca2_oe_n),
    .I_PA(sys_via_pa_in),
    .O_PA(sys_via_pa_out),
    .O_PA_OE_L(sys_via_pa_oe_n),
    .I_CB1(sys_via_cb1_in),
    .O_CB1(sys_via_cb1_out),
    .O_CB1_OE_L(sys_via_cb1_oe_n),
    .I_CB2(sys_via_cb2_in),
    .O_CB2(sys_via_cb2_out),
    .O_CB2_OE_L(sys_via_cb2_oe_n),
    .I_PB(sys_via_pb_in),
    .O_PB(sys_via_pb_out),
    .O_PB_OE_L(sys_via_pb_oe_n)
);

m6522 USER_VIA (
    .ENA_4(mhz4_clken),
    .CLK(CLK32M_I),
    .I_RS(cpu_a[3:0]),
    .I_DATA(cpu_do),
    .O_DATA(user_via_do),
    .O_DATA_OE_L(user_via_do_oe_n),
    .I_RW_L(cpu_r_nw),
    .I_CS1(user_via_enable), // using the econet port
    .I_CS2_L(1'b 0), // nCS2(1'b 0),
    .O_IRQ_L(user_via_irq_n),
    .I_P2_H(mhz1_clken),
    .RESET_L(hard_reset_n),

    .I_CA1(user_via_ca1_in),
    .I_CA2(user_via_ca2_in),
    .O_CA2(user_via_ca2_out),
    .O_CA2_OE_L(user_via_ca2_oe_n),
    .I_PA(user_via_pa_in),
    .O_PA(user_via_pa_out),
    .O_PA_OE_L(user_via_pa_oe_n),
    .I_CB1(user_via_cb1_in),
    .O_CB1(user_via_cb1_out),
    .O_CB1_OE_L(user_via_cb1_oe_n),
    .I_CB2(user_via_cb2_in),
    .O_CB2(user_via_cb2_out),
    .O_CB2_OE_L(user_via_cb2_oe_n),
    .I_PB(user_via_pb_in),
    .O_PB(user_via_pb_out),
    .O_PB_OE_L(user_via_pb_oe_n)
);

   // User port connections for MMFS
   
   assign user_via_ca1_in = 1'b0;
   assign user_via_ca2_in = 1'b0;

   // SCLK is driven from either PB1 or CB1 depending on the SR Mode
   wire sdclk_int   = !user_via_pb_oe_n[1] ? user_via_pb_out[1] :
                      !user_via_cb1_oe_n   ? user_via_cb1_out : 1'b1;
   
   assign sclk = sdclk_int;
   assign user_via_cb1_in = sdclk_int;

   // MOSI is always driven from PB0
   assign mosi = !user_via_pb_oe_n[0] ? user_via_pb_out[0] : 1'b1;

   // MISO is always read from CB2
   assign user_via_cb2_in = miso; // SDI

   // SS is hardwired to 0 (always selected) as there is only one slave attached
   assign ss = 1'b0;

//  Keyboard
keyboard KEYB (

    .CLOCK        ( CLK32M_I     ),
    .nRESET       ( hard_reset_n      ),
    .CLKEN_1MHZ   ( mhz1_clken   ),
    .PS2_CLK      ( PS2_CLK      ),
    .PS2_DATA     ( PS2_DAT      ),
    .AUTOSCAN     ( keyb_enable_n),
    .COLUMN       ( keyb_column  ),
    .ROW          ( keyb_row     ),
    .KEYPRESS     ( keyb_out     ),
    .INT          ( keyb_int     ),
    .SHIFT        ( SHIFT        ),
    .BREAK_OUT    ( keyb_break   ),
    .DIP_SWITCH   ( DIP_SWITCH   )
);

adc ADC (
    .CLOCK(CLK32M_I),
    .CLKEN(crtc_clken),
    .nRESET(reset_n),
    .ENABLE(adc_enable),
    .R_nW(cpu_r_nw),
    .A(cpu_a[1:0]),
    .DI(cpu_do),
    .DO(adc_do),

    // adc is used for analog joystick input
    .ch0 ( joy0_axis0 ),
    .ch1 ( joy0_axis1 ),
    .ch2 ( joy1_axis0 ),
    .ch3 ( joy1_axis1 )
);

mc6845 CRTC (
    .CLOCK(CLK32M_I),
    .CLKEN(crtc_clken),
    .CLKEN_ADR(crtc_clken),
    .nRESET(hard_reset_n),
    .ENABLE(crtc_enable),
    .R_nW(cpu_r_nw),
    .RS(cpu_a[0]),
    .DI(cpu_do),
    .DO(crtc_do),
    .VSYNC  (VSYNC),
    .HSYNC  (HSYNC),
    .DE(crtc_de),
    .CURSOR(crtc_cursor),
    .LPSTB(crtc_lpstb),
    .MA(crtc_ma),
    .RA(crtc_ra)
);

sn76489 #(8) SOUND
  (
   .clk       ( CLK32M_I       ),
   .clk_en    ( mhz4_clken     ),
   .reset     ( !reset_n       ),
   .ce_n      ( 1'b 0          ),
   .we_n      ( sound_enable_n ),
   .ready     ( sound_ready    ),
   .d         ( sound_di       ),
   .audio_out ( sound_ao       )
);


vidproc VIDEO_ULA (
      .CLOCK(CLK32M_I),
      .CLKEN(VIDEO_CLKEN),
      .nRESET(hard_reset_n),
      .CLKEN_CRTC(crtc_clken),
      .CLKEN_CRTC_ADR(crtc_clken_adr),
      .ENABLE(vidproc_enable),
      .A0(cpu_a[0]),
      .DI_CPU(cpu_do),
      .DI_RAM(ext_Dout),
      .nINVERT(vidproc_invert_n),
      .DISEN(vidproc_disen),
      .CURSOR(crtc_cursor),

      .R_IN    ( ttxt_r    ),
      .G_IN    ( ttxt_g    ),
      .B_IN    ( ttxt_b    ),

      .R       ( VIDEO_R   ),
      .G       ( VIDEO_G   ),
      .B       ( VIDEO_B   )
);

saa5050 TELETEXT (

        //  This runs at 6 MHz, which we can't derive from the 32 MHz clock
       .CLOCK     ( CLK24M_I     ),
       .CLKEN     ( ttxt_clkenx2   ),
//       .PIXCLKEN  ( ttxt_clkenx2 ),
       .nRESET    ( hard_reset_n      ),

        //  Data input is synchronised to the main cpu bus clock.
       .DI_CLOCK  ( CLK32M_I     ),
       .DI_CLKEN  ( VIDEO_CLKEN  ),
       .DI        ( ext_Dout[6:0]),

       .GLR       ( ttxt_glr     ),
       .DEW       ( ttxt_dew     ),
       .CRS       ( ttxt_crs     ),
       .LOSE      ( ttxt_lose    ),

       .R         ( ttxt_r       ),
       .G         ( ttxt_g       ),
       .B         ( ttxt_b       )

);

initial begin : via_init

   crtc_lpstb = 1'b 0;

end

// rom select latch
always @(posedge CLK32M_I) begin

   if (reset_n === 1'b 0) begin

      romsel <= {4{1'b 0}};
      ic32 <= {8{1'b 0}};

   end else begin

      case (sys_via_pb_out[2:0])

            0: ic32[0] <= sys_via_pb_out[3];
            1: ic32[1] <= sys_via_pb_out[3];
            2: ic32[2] <= sys_via_pb_out[3];
            3: ic32[3] <= sys_via_pb_out[3];
            4: ic32[4] <= sys_via_pb_out[3];
            5: ic32[5] <= sys_via_pb_out[3];
            6: ic32[6] <= sys_via_pb_out[3];
            7: ic32[7] <= sys_via_pb_out[3];

      endcase

      if (romsel_enable === 1'b 1 & cpu_r_nw === 1'b 0) begin

            romsel <= cpu_do[3:0];

      end

      //  // retard DI by one cpu clock cycle
      //  if (cpu_clken === 1'b1) begin
      //      cpu_di_r <= cpu_di;
      //  end

   end
end


//  Address translation logic for calculation of display address
always @(crtc_ma or crtc_ra or disp_addr_offs)
   begin : process_3
   if (crtc_ma[12] === 1'b 0)
      begin

//  No adjustment
      process_3_aa = crtc_ma[11:8];

//  Address adjusted according to screen mode to compensate for
//  wrap at 0x8000.
      end
   else
      begin
      case (disp_addr_offs)
      2'b 00:
         begin

//  Mode 3 - restart at 0x4000
         process_3_aa = crtc_ma[11:8] + 8;
         end
      2'b 01:
         begin

//  Mode 6 - restart at 0x6000
         process_3_aa = crtc_ma[11:8] + 12;
         end
      2'b 10:
         begin

//  Mode 0,1,2 - restart at 0x3000
         process_3_aa = crtc_ma[11:8] + 6;
         end
      2'b 11:
         begin

//  Mode 4,5 - restart at 0x5800
         process_3_aa = crtc_ma[11:8] + 11;
         end
      default:
         ;
      endcase
      end
   if (crtc_ma[13] === 1'b 0)
      begin

//  HI RES
      display_a <= {process_3_aa[3:0], crtc_ma[7:0], crtc_ra[2:0]};

//  TTX VDU
      end
   else
      begin
      display_a <= {process_3_aa[3], 4'b 1111, crtc_ma[9:0]};
      end
   end

// SOUND
assign AUDIO_L = {sound_ao[7:0], 8'b00000000};
assign AUDIO_R = {sound_ao[7:0], 8'b00000000};

//  VIDPROC
assign vidproc_invert_n = 1'b 1;
assign vidproc_disen = crtc_de & ~crtc_ra[3];

//  SAA5050
assign ttxt_glr = ~HSYNC;
assign ttxt_dew = VSYNC;
assign ttxt_crs = ~crtc_ra[0];
assign ttxt_lose = crtc_de;

//  IC32 latch
assign sound_enable_n = ic32[0];
assign speech_write_n = ic32[1];
assign speech_read_n = ic32[2];
assign keyb_enable_n = ic32[3];
assign disp_addr_offs = ic32[5:4];
assign caps_lock_led_n = ic32[6];
assign shift_lock_led_n = ic32[7];
assign break_led_n = ~keyb_break;

//  CPU data bus mux and interrupts
//wire himem_enable = rom_enable && (romsel[3] === 1'b0);

//  All regions normally de-selected
assign cpu_di = ram_enable === 1'b 1 ? ext_Dout :
//   himem_enable === 1'b 1 ? ext_Dout :
   rom_enable === 1'b 1 ? ext_Dout :
   mos_enable === 1'b 1 ? ext_Dout :
   crtc_enable === 1'b 1 ? crtc_do :
   acia_enable === 1'b 1 ? 8'b 00000010 :
   sys_via_enable === 1'b 1 ? sys_via_do_r :
   user_via_enable === 1'b 1 ? user_via_do_r :
   adc_enable === 1'b 1 ? adc_do :
   //tube_enable === 1'b 1 ? tube_do :
   //adlc_enable === 1'b 1 ? bbcddr_out :
   8'd0;

//  un-decoded locations are pulled down by RP1
assign cpu_irq_n = sys_via_irq_n & user_via_irq_n; // & tube_irq_n;

// can we write to ram? Further decodig happens on top-level to deal with sideways ram etc
assign ram_we = ~RESET_I & ~cpu_r_nw;

// system via interrupt lines.
assign sys_via_ca1_in = VSYNC;
assign sys_via_ca2_in = keyb_int;
assign sys_via_cb1_in = 1'b1;
assign sys_via_cb2_in = crtc_lpstb;

assign sys_via_pa_in[7] = keyb_out;
assign sys_via_pa_in[6:0] = sys_via_pa_out[6:0];

//  Sound
assign sound_di = sys_via_pa_out;

//  Others (idle until missing bits implemented)
assign sys_via_pb_in[7:4] = { 2'b11, !joy_but[1], !joy_but[0] };
assign sys_via_pb_in[3:0] = sys_via_pb_out[3:0];

// Fixes Planetoid, Snapper etc
assign user_via_pa_in = user_via_pa_out;
assign user_via_pb_in = user_via_pb_out;


// Pipeline RAM accesses
   always @(posedge CLK32M_I or negedge hard_reset_n)
     begin
        if (!hard_reset_n)
          begin
             ext_nOE <= 1'b1;
             ext_nWE <= 1'b1;
             ext_Din <= 0;
             ext_A   <= 0;
          end
        else
          begin
             ext_Din  <= cpu_do;
             ext_nWE  <= 1'b1;
             ext_nOE  <= 1'b0;
             if (VIDEO_CLKEN == 1'b0)
               begin
                  ext_A <= { 3'b000, display_a };
               end
             else if (rom_enable)
               begin
                  ext_A <= { romsel[3:0], cpu_a[13:0] };
               end
             else if (mos_enable)
               begin
                  ext_A <= { 2'b00, cpu_a };
               end
             else if (ram_enable)
               begin
                  ext_A <= { 2'b00, cpu_a };
                  ext_nWE <= cpu_r_nw;
                  ext_nOE <= ~cpu_r_nw;
               end
          end
     end

endmodule
