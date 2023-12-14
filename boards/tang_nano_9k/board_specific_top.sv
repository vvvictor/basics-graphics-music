`include "config.svh"
`include "lab_specific_config.svh"

`undef ENABLE_TM1638
`define ENABLE_HDMI

module board_specific_top
# (
    parameter   clk_mhz = 27,
                w_key   = 2,  // The last key is used for a reset
                w_sw    = 0,
                w_led   = 6,
                w_digit = 0,
                w_gpio  = 9
)
(
    input                       CLK,

    input  [w_key       - 1:0]  KEY,
    input  [w_sw        - 1:0]  SW,

    input                       UART_RX,
    output                      UART_TX,

    output [w_led       - 1:0]  LED,

    output                      VGA_HS,
    output                      VGA_VS,
    output [              3:0]  VGA_R,
    output [              3:0]  VGA_G,
    output [              3:0]  VGA_B,

    output       tmds_clk_n,
    output       tmds_clk_p,
    output [2:0] tmds_d_n,
    output [2:0] tmds_d_p,
    
    inout  [w_gpio      - 1:0]  GPIO
);

    wire clk = CLK;

    //------------------------------------------------------------------------

    localparam w_tm_key    = 8,
               w_tm_led    = 8,
               w_tm_digit  = 8;


    //------------------------------------------------------------------------

    `ifdef ENABLE_TM1638    // TM1638 module is connected

        localparam w_top_key   = w_tm_key,
                   w_top_sw    = w_sw,
                   w_top_led   = w_tm_led,
                   w_top_digit = w_tm_digit;

    `else                   // TM1638 module is not connected

        localparam w_top_key   = w_key,
                   w_top_sw    = w_sw,
                   w_top_led   = w_led,
                   w_top_digit = w_digit;

    `endif

    `ifdef ENABLE_HDMI
        localparam w_top_vgar  = 8 
                 , w_top_vgag  = 8
                 , w_top_vgab  = 8; 
    `else
        localparam w_top_vgar  = 4
                 , w_top_vgag  = 4
                 , w_top_vgab  = 4; 
    `endif

    //------------------------------------------------------------------------

    wire  [w_tm_key    - 1:0] tm_key;
    wire  [w_tm_led    - 1:0] tm_led;
    wire  [w_tm_digit  - 1:0] tm_digit;

    logic [w_top_key   - 1:0] top_key;
    wire  [w_top_led   - 1:0] top_led;
    wire  [w_top_digit - 1:0] top_digit;

    wire                      rst;
    wire  [              7:0] abcdefgh;
    wire  [             23:0] mic;

    wire                      vga_hs;
    wire                      vga_vs;
    wire  [ w_top_vgar - 1:0] vga_r;
    wire  [ w_top_vgag - 1:0] vga_g;
    wire  [ w_top_vgab - 1:0] vga_b;

   //------------------------------------------------------------------------

    `ifdef ENABLE_TM1638    // TM1638 module is connected

        assign rst      = tm_key [w_tm_key - 1];
        assign top_key  = tm_key [w_tm_key - 1:0];

        assign tm_led   = top_led;
        assign tm_digit = top_digit;

    `else                   // TM1638 module is not connected

        assign rst      = ~ KEY [w_key - 1];
        assign top_key  = ~ KEY [w_key - 1:0];

        assign LED      = ~ top_led;

    `endif



    //------------------------------------------------------------------------

    wire slow_clk;

    slow_clk_gen # (.fast_clk_mhz (clk_mhz), .slow_clk_hz (1))
    i_slow_clk_gen (.slow_clk (slow_clk), .*);

    //------------------------------------------------------------------------

    top
    # (
        .clk_mhz ( clk_mhz   ),
        .w_key   ( w_top_key ),  // The last key is used for a reset
        .w_sw    ( w_top_sw      ),
        .w_led   ( w_top_led     ),
        .w_digit ( w_top_digit   ),
        .w_gpio  ( w_gpio    )
     
      , .w_vgar  ( w_top_vgar )
      , .w_vgag  ( w_top_vgag )
      , .w_vgab  ( w_top_vgab )

    )
    i_top
    (
        .clk      ( clk       ),
        .slow_clk ( slow_clk  ),
        .rst      ( rst       ),

        .key      ( top_key   ),
        .sw       (           ),

        .led      ( top_led   ),

        .abcdefgh ( abcdefgh  ),
        .digit    ( top_digit ),

        .vsync    ( vga_hs    ),
        .hsync    ( vga_vs    ),

        .red      ( vga_r     ),
        .green    ( vga_g     ),
        .blue     ( vga_b     ),

        .mic      ( mic       ),
        .gpio     (           )
    );

    //------------------------------------------------------------------------

    wire [$left (abcdefgh):0] hgfedcba;

    generate
        genvar i;

        for (i = 0; i < $bits (abcdefgh); i ++)
        begin : abc
            assign hgfedcba [i] = abcdefgh [$left (abcdefgh) - i];
        end
    endgenerate

    //------------------------------------------------------------------------

    tm1638_board_controller
    # (
        .w_digit ( w_tm_digit )
    )
    i_tm1638
    (
        .clk      ( clk       ),
        .rst      ( rst       ),
        .hgfedcba ( hgfedcba  ),
        .digit    ( tm_digit  ),
        .ledr     ( tm_led    ),
        .keys     ( tm_key    ),
        .sio_clk  ( GPIO [0]  ),
        .sio_stb  ( GPIO [1]  ),
        .sio_data ( GPIO [2]  )
    );

    //------------------------------------------------------------------------

    inmp441_mic_i2s_receiver i_microphone
    (
        .clk   ( clk      ),
        .rst   ( rst      ),
        .lr    ( GPIO [5] ),
        .ws    ( GPIO [4] ),
        .sck   ( GPIO [3] ),
        .sd    ( GPIO [6] ),
        .value ( mic      )
    );


    `ifdef ENABLE_HDMI
      wire clk_hd;
      wire clk_px;

      Gowin_rPLL hdPLL(
        .clkout( clk_hd ), //output clkout
        .clkin ( clk    ) //input clkin
      );   

      Gowin_CLKDIV pxCLK(
        .clkout(clk_px), //output clkout
        .hclkin(clk_hd), //input hclkin
        .resetn( ~ rst) //input resetn
      );


//		.I_rgb_de(I_rgb_de_i), //input I_rgb_de
	  DVI_TX_Top DVImod(
		.I_rst_n( ~ rst), //input I_rst_n
		.I_serial_clk( clk_hd ), //input I_serial_clk
		.I_rgb_clk( clk_px ), //input I_rgb_clk
		.I_rgb_vs(vga_vs), //input I_rgb_vs
		.I_rgb_hs(vga_hs), //input I_rgb_hs

		.I_rgb_de( 1'b1 ), //input I_rgb_de

		.I_rgb_r(vga_r), //input [7:0] I_rgb_r
		.I_rgb_g(vga_g), //input [7:0] I_rgb_g
		.I_rgb_b(vga_b), //input [7:0] I_rgb_b
		.O_tmds_clk_p(tmds_clk_p), //output O_tmds_clk_p
		.O_tmds_clk_n(tmds_clk_n), //output O_tmds_clk_n
		.O_tmds_data_p(tmds_d_p), //output [2:0] O_tmds_data_p
		.O_tmds_data_n(tmds_d_n) //output [2:0] O_tmds_data_n
	);
    `else
       assign VGA_HS = vga_hs;
       assign VGA_VS = vga_vs;
       assign VGA_R  = vga_r;
       assign VGA_G  = vga_g;
       assign VGA_B  = vga_b;
    `endif

    assign GPIO [8] = 1'b0;  // GND
    assign GPIO [7] = 1'b1;  // VCC

endmodule
