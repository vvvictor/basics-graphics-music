`include "config.svh"
`include "lab_specific_config.svh"

// `define ENABLE_VGA16

module board_specific_top
# (
    parameter   clk_mhz = 27,
                w_key   = 5,  // The last key is used for a reset
                w_sw    = 5,
                w_led   = 6,
                w_digit = 0,
                w_gpio  = 32
)
(
    input                       CLK,

    input  [w_key       - 1:0]  KEY,
    input  [w_sw        - 1:0]  SW,

    input                       UART_RX,
    output                      UART_TX,

    output [w_led       - 1:0]  LED,

    inout  [w_gpio / 4  - 1:0]  GPIO_0,
    inout  [w_gpio / 4  - 1:0]  GPIO_1,
    inout  [w_gpio / 4  - 1:0]  GPIO_2,
    inout  [w_gpio / 4  - 1:0]  GPIO_3
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

    `ifdef ENABLE_VGA16
        localparam w_top_red   = 5,
                   w_top_green = 6,
                   w_top_blue  = 5;
    `else
        localparam w_top_red   = 4,
                   w_top_green = 4,
                   w_top_blue  = 4;
    `endif


    //------------------------------------------------------------------------

    wire  [w_tm_key    - 1:0] tm_key;
    wire  [w_tm_led    - 1:0] tm_led;
    wire  [w_tm_digit  - 1:0] tm_digit;

    logic [w_top_key   - 1:0] top_key;
    logic [w_top_sw    - 1:0] top_sw;
    wire  [w_top_led   - 1:0] top_led;
    wire  [w_top_digit - 1:0] top_digit;

    wire                      rst;
    wire  [              7:0] abcdefgh;
    wire  [             23:0] mic;

    wire                      VGA_HS;
    wire                      VGA_VS;

    wire  [ w_top_red   - 1:0] VGA_R;
    wire  [ w_top_green - 1:0] VGA_G;
    wire  [ w_top_blue  - 1:0] VGA_B;

    //------------------------------------------------------------------------

    `ifdef ENABLE_TM1638    // TM1638 module is connected

        assign rst      = tm_key [w_tm_key - 1];
        assign top_key  = tm_key [w_tm_key - 1:0];
        assign top_sw   = ~ SW;

        assign tm_led   = top_led;
        assign tm_digit = top_digit;

    `else                   // TM1638 module is not connected

        assign rst      = ~ KEY [w_key - 1];
        assign top_key  = ~ KEY [w_key - 1:0];
        assign top_sw   = ~ SW;

        assign LED      = ~ top_led;

    `endif

    //------------------------------------------------------------------------

    wire slow_clk;

    slow_clk_gen # (.fast_clk_mhz (clk_mhz), .slow_clk_hz (1))
    i_slow_clk_gen (.slow_clk (slow_clk), .*);

    //------------------------------------------------------------------------

    top
    # (
        .clk_mhz ( clk_mhz      ),
        .w_key   ( w_top_key    ),  // The last key is used for a reset
        .w_sw    ( w_top_sw     ),
        .w_led   ( w_top_led    ),
        .w_digit ( w_top_digit  ),
        .w_gpio  ( w_gpio       )
    `ifdef ENABLE_VGA16
      , .w_vgar  ( w_top_red    )     
      , .w_vgag  ( w_top_green  )     
      , .w_vgab  ( w_top_blue   )     
    `endif
    )
    i_top
    (
        .clk      ( clk       ),
        .slow_clk ( slow_clk  ),
        .rst      ( rst       ),

        .key      ( top_key   ),
        .sw       ( top_sw    ),

        .led      ( top_led   ),

        .abcdefgh ( abcdefgh  ),
        .digit    ( top_digit ),

        .vsync    ( VGA_VS    ),
        .hsync    ( VGA_HS    ),

        .red      ( VGA_R     ),
        .green    ( VGA_G     ),
        .blue     ( VGA_B     ),

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
        .clk        ( clk           ),
        .rst        ( rst           ),
        .hgfedcba   ( hgfedcba      ),
        .digit      ( tm_digit      ),
        .ledr       ( tm_led        ),
        .keys       ( tm_key        ),
        .sio_clk    ( GPIO_0[2]     ),
        .sio_stb    ( GPIO_0[3]     ),
        .sio_data   ( GPIO_0[1]     )
    );

    //------------------------------------------------------------------------

    inmp441_mic_i2s_receiver i_microphone
    (
        .clk   ( clk        ),
        .rst   ( rst        ),
        .lr    ( GPIO_0 [5] ),
        .ws    ( GPIO_0 [6] ),
        .sck   ( GPIO_0 [7] ),
        .sd    ( GPIO_0 [4] ),
        .value ( mic        )
    );

    //------------------------------------------------------------------------

   `ifdef ENABLE_VGA16

      assign GPIO_3 = {2'bz, VGA_R[3], VGA_R[1], 2'bz, VGA_R[4], VGA_R[2]}; 
      assign GPIO_2 = {VGA_G[5], VGA_G[3], VGA_G[1], VGA_B[4], VGA_R[0], VGA_G[4], VGA_G[2], VGA_G[0]}; 
      assign GPIO_1 = {VGA_B[2], VGA_B[0], VGA_HS, 1'bz, VGA_B[3], VGA_B[1], VGA_VS, 1'bz};

   `else

      assign GPIO_2 = { VGA_B, VGA_R };
      assign GPIO_3 = { 2'bz, VGA_VS, VGA_HS, VGA_G };

   `endif 
endmodule
