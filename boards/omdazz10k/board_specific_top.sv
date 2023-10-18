// Asynchronous reset here is needed for some FPGA boards we use

`include "config.svh"
`include "lab_specific_config.svh"

// `define USE_DIGILENT_PMOD_MIC3
// `define USE_INMP_441_MIC_ON_OLD_POSITION

`ifdef USE_DIGILENT_PMOD_MIC3
    `define USE_SDRAM_PINS_AS_GPIO
`elsif USE_INMP_441_MIC_ON_OLD_POSITION
    `define USE_SDRAM_PINS_AS_GPIO
`else
    `define USE_LCD_AS_GPIO
`endif

 `define ENABLE_VGA16

//----------------------------------------------------------------------------

module board_specific_top
# (
    parameter clk_mhz = 50,
              w_key   = 4,
              w_sw    = 4,
              w_led   = 4,
              w_digit = 4,

              `ifdef USE_SDRAM_PINS_AS_GPIO
              w_gpio  = 14
              `elif USE_LCD_AS_GPIO
              w_gpio  = 11
              `else
              w_gpio  = 1
              `endif
)
(
    input                  CLK,
    input                  RESET,

    input  [w_key   - 1:0] KEY,
    output [w_led   - 1:0] LED,

	 `ifdef ENABLE_VGA16
    output                 VGA16_HSYNC,
    output                 VGA16_VSYNC,
    output [          4:0] VGAR,
    output [          5:0] VGAG,
    output [          4:0] VGAB,
	 `else
    output [          7:0] SEG,
    output [w_digit - 1:0] DIG,
    output                 VGA_HSYNC,
    output                 VGA_VSYNC,
    output                 VGA_R,
    output                 VGA_G,
    output                 VGA_B,
	 `endif

    input                  UART_RXD,

    inout  [w_gpio  - 1:0] PSEUDO_GPIO_USING_SDRAM_PINS

	 
	 `ifndef ENABLE_VGA16
    , inout                  LCD_RS
    , inout                  LCD_RW
    , inout                  LCD_E
    , inout  [          7:0] LCD_D
	 `endif
);

    //------------------------------------------------------------------------

    wire               clk     =   CLK;
    wire               rst     = ~ RESET;
    wire [w_sw  - 1:0] top_sw  = ~ KEY [w_sw - 1:0];
    wire [w_key - 1:0] top_key = ~ KEY;

    //------------------------------------------------------------------------

    wire  [w_led   - 1:0] top_led;

    wire  [          7:0] abcdefgh;
    wire  [w_digit - 1:0] digit;

    wire                  vga_vs, vga_hs;
	 
	 `ifdef ENABLE_VGA16
    reg  [          4:0] red;
    reg  [          5:0] green;
    reg  [          4:0] blue;
	 `else
    reg  [          3:0] red, green, blue;
	 `endif

    wire  [         23:0] mic;

    //------------------------------------------------------------------------

    wire slow_clk;

    slow_clk_gen # (.fast_clk_mhz (clk_mhz), .slow_clk_hz (1))
    i_slow_clk_gen (.slow_clk (slow_clk), .*);

    //------------------------------------------------------------------------

    top
    # (
        .clk_mhz ( clk_mhz ),
        .w_key   ( w_key   ),
        .w_sw    ( w_sw    ),
        .w_led   ( w_led   ),
        .w_digit ( w_digit ),
        .w_gpio  ( w_gpio  )
  	     `ifdef ENABLE_VGA16 
		  , .w_vgar ( 5 )
		  , .w_vgag ( 6 )
		  , .w_vgab ( 5 )
		  `endif
		  
    )
    i_top
    (
        .clk      (   clk          ),
        .slow_clk (   slow_clk     ),
        .rst      (   rst          ),

        .key      (   top_key      ),
        .sw       (   top_sw       ),

        .led      (   top_led      ),

        .abcdefgh (   abcdefgh     ),
        .digit    (   digit        ),

  	     `ifdef ENABLE_VGA16 
        .vsync    (   VGA16_VSYNC    ),
        .hsync    (   VGA16_HSYNC    ),
		  `else
        .vsync    (   VGA_VSYNC    ),
        .hsync    (   VGA_HSYNC    ),
		  `endif

        .red      (   red          ),
        .green    (   green        ),
        .blue     (   blue         ),

        .mic      (   mic          ),

        `ifdef USE_SDRAM_PINS_AS_GPIO
            .gpio ( PSEUDO_GPIO_USING_SDRAM_PINS )
        `elif USE_LCD_AS_GPIO
            .gpio ({ LCD_RS, LCD_RW, LCD_E, LCD_D })
        `endif
    );

    //------------------------------------------------------------------------

    assign LED       = ~ top_led;


	 `ifdef ENABLE_VGA16 
    assign VGAR     = red;
    assign VGAG     = green;
    assign VGAB     = blue;
	 `else
    assign SEG       = ~ abcdefgh;
    assign DIG       = ~ digit;
    assign VGA_R     = | red;
    assign VGA_G     = | green;
    assign VGA_B     = | blue;
	 `endif

    //------------------------------------------------------------------------

    `ifdef USE_DIGILENT_PMOD_MIC3

    wire [15:0] mic_16;

    digilent_pmod_mic3_spi_receiver i_microphone
    (
        .clk   ( clk                               ),
        .rst   ( rst                               ),
        .cs    ( PSEUDO_GPIO_USING_SDRAM_PINS  [0] ),
        .sck   ( PSEUDO_GPIO_USING_SDRAM_PINS  [6] ),
        .sdo   ( PSEUDO_GPIO_USING_SDRAM_PINS  [4] ),
        .value ( mic_16                            )
    );

    assign PSEUDO_GPIO_USING_SDRAM_PINS [ 8] = 1'b0;  // GND
    assign PSEUDO_GPIO_USING_SDRAM_PINS [10] = 1'b1;  // VCC

    assign mic = { mic_16, 8'b0 };

    //------------------------------------------------------------------------

    `elsif USE_INMP_441_MIC_ON_OLD_POSITION

    inmp441_mic_i2s_receiver i_microphone
    (
        .clk   ( clk                               ),
        .rst   ( rst                               ),
        .lr    ( PSEUDO_GPIO_USING_SDRAM_PINS  [5] ),
        .ws    ( PSEUDO_GPIO_USING_SDRAM_PINS  [3] ),
        .sck   ( PSEUDO_GPIO_USING_SDRAM_PINS  [1] ),
        .sd    ( PSEUDO_GPIO_USING_SDRAM_PINS  [0] ),
        .value ( mic                               )
    );

    assign PSEUDO_GPIO_USING_SDRAM_PINS [4] = 1'b0;  // GND
    assign PSEUDO_GPIO_USING_SDRAM_PINS [2] = 1'b1;  // VCC

    //------------------------------------------------------------------------

	 `else
    `ifndef ENABLE_VGA16   // USE_INMP_441_MIC

    inmp441_mic_i2s_receiver i_microphone
    (
        .clk   ( clk       ),
        .rst   ( rst       ),
        .lr    ( LCD_D [1] ),
        .ws    ( LCD_D [2] ),
        .sck   ( LCD_D [3] ),
        .sd    ( LCD_D [6] ),
        .value ( mic       )
    );

    assign LCD_D [4] = 1'b0;  // GND
    assign LCD_D [5] = 1'b1;  // VCC
	 
	 `endif

    `endif

endmodule
