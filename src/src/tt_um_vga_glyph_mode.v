/*
 * Copyright (c) 2024-2025 James Ross
 * SPDX-License-Identifier: Apache-2.0
 *
 * Kawaii symbol rain -> "KATSEYE RULES" revealed in the center.
 * Palette switch: ui_in[1:0] (4 pastel palettes). ui_in[7:6] = VGA mode.
 */

`default_nettype none

module tt_um_vga_glyph_mode(
	input  wire [7:0] ui_in, output wire [7:0] uo_out,
	input  wire [7:0] uio_in, output wire [7:0] uio_out, output wire [7:0] uio_oe,
	input  wire ena, input wire clk, input wire rst_n
);
	wire hsync, vsync, display_on;
	wire [10:0] hpos;
	wire [9:0]  vpos;
	wire [5:0]  RGB;

	assign uo_out  = {hsync, RGB[0], RGB[2], RGB[4], vsync, RGB[1], RGB[3], RGB[5]}; // TinyVGA PMOD
	assign uio_out = 0;
	assign uio_oe  = 0;
	wire _unused_ok = &{ena, ui_in[5:2], uio_in};

	hvsync_generator hvsync_gen(.clk(clk), .reset(~rst_n), .mode(ui_in[7:6]),
		.hsync(hsync), .vsync(vsync), .display_on(display_on), .hpos(hpos), .vpos(vpos));

	// ---------------- state ----------------
	reg [9:0] frame;   // free-running frame counter (rain motion)
	reg [8:0] rv;      // reveal counter (saturates)
	always @(posedge vsync, negedge rst_n)
		if (~rst_n) begin frame <= 0; rv <= 0; end
		else begin frame <= frame + 1; if (~&rv) rv <= rv + 1; end

	// ---------------- palettes ----------------
	// slot (32b) = {2'b0, bg, c3, c2, c1, c0}, colours {R[1:0],G[1:0],B[1:0]}
	localparam [127:0] PAL = {
		{2'b00, 6'b010000, 6'b101111, 6'b111011, 6'b111110, 6'b111010},  // 3 peach cream
		{2'b00, 6'b010010, 6'b111111, 6'b101111, 6'b111011, 6'b101011},  // 2 lavender dream
		{2'b00, 6'b000101, 6'b111011, 6'b111110, 6'b101111, 6'b101110},  // 1 mint soda
		{2'b00, 6'b010001, 6'b111111, 6'b101011, 6'b111010, 6'b111011}   // 0 sakura pink
	};
	wire [1:0] pal = ui_in[1:0];
	function [5:0] col(input [2:0] k);   // k = 0..3 accents, 4 = background
		col = PAL[{pal,5'b0} + {2'b0, {k,2'b00} + {1'b0,k,1'b0}} +: 6];
	endfunction
	wire [5:0] bg = col(3'd4);

	// ---------------- kawaii glyphs (8x8, top row = MSB byte, MSB = left) ----------------
	localparam [63:0] S_HEART = 64'h0066FFFFFF7E3C18;
	localparam [63:0] S_STAR  = 64'h1818FF7E3C3C6642;
	localparam [63:0] S_SPARK = 64'h08081C7F1C080800;
	localparam [63:0] S_FLOWR = 64'h00245A2418183C00;
	localparam [63:0] S_CAT   = 64'hC3E7FFDBFFFF7E3C;
	localparam [63:0] S_NOTE  = 64'h0C0E0A0A08387830;
	localparam [63:0] S_SMILE = 64'h3C42A581A599423C;
	localparam [63:0] S_MOON  = 64'h3C78F0E0E0F0783C;
	localparam [511:0] SYM = {S_MOON, S_SMILE, S_NOTE, S_CAT, S_FLOWR, S_SPARK, S_STAR, S_HEART};

	// ---------------- font for "KATSEYE RULES" ----------------
	localparam [63:0] F_K = 64'h00666C78786C6600;
	localparam [63:0] F_A = 64'h00183C66667E6666;
	localparam [63:0] F_T = 64'h007E181818181818;
	localparam [63:0] F_S = 64'h003C66603C06663C;
	localparam [63:0] F_E = 64'h007E60607C60607E;
	localparam [63:0] F_Y = 64'h0066663C18181818;
	localparam [63:0] F_R = 64'h007C66667C6C6666;
	localparam [63:0] F_U = 64'h006666666666663C;
	localparam [63:0] F_L = 64'h006060606060607E;
	localparam [63:0] F_SP = 64'd0;
	// slot 0 = K (least significant)
	localparam [831:0] TXT = {F_S, F_E, F_L, F_U, F_R, F_SP, F_E, F_Y, F_E, F_S, F_T, F_A, F_K};

	// ---------------- rain ----------------
	wire [6:0] xb = hpos[9:3];
	wire [6:0] yb = vpos[9:3];
	wire [2:0] gx = hpos[2:0];
	wire [2:0] gy = vpos[2:0];

	wire [6:0] x_mix = (xb << 5) + (xb << 3) + (xb << 2) + xb;   // xb*45 : scatter columns
	wire       s     = xb[0] ^ xb[2] ^ xb[5];                     // fast / slow column
	wire [6:0] hd    = s ? frame[8:2] : frame[9:3];
	wire [6:0] d     = hd - yb - x_mix;                           // 0 = drop head, grows up the trail
	wire       on    = ~|d[6:5] & ~&d[4:3];                       // trail length 24 rows
	wire       head  = ~|d[4:0];
	wire [1:0] stg   = d[4:3];

	wire [2:0]  sel    = x_mix[6:4] ^ yb[2:0];
	wire [63:0] sym    = SYM[{sel,6'b0} +: 64];
	wire [7:0]  symrow = sym[{~gy,3'b000} +: 8];
	wire        hl     = symrow[~gx];

	wire [5:0] ac = col({1'b0, x_mix[3:2]});
	wire [5:0] rc = head ? 6'd63 :
	                stg[1] ? (bg | (ac & 6'b010101)) :
	                stg[0] ? (bg | (ac & 6'b101010)) : ac;
	wire rain_px = hl & on;

	// ---------------- centered text ----------------
	wire [10:0] tx  = hpos - 11'd216;
	wire [9:0]  ty  = vpos - 10'd232;
	wire in_txt = (hpos >= 11'd216) & (hpos < 11'd424) & (vpos >= 10'd232) & (vpos < 10'd248);
	wire [3:0]  idx = tx[7:4];                                   // char 0..12 (2x scale)
	wire [63:0] gl  = TXT[{idx,6'b0} +: 64];
	wire [7:0]  trw = gl[{~ty[3:1],3'b000} +: 8];
	wire        tp  = trw[~tx[3:1]];

	wire [7:0] thr  = {idx,3'b000} + {idx,2'b00};                // 12*idx
	wire [8:0] beg  = {1'b0,thr} + 9'd60;                        // char idx appears here
	wire [8:0] age  = rv - beg;
	wire vis   = rv > beg;
	wire flash = vis & ~|age[8:3];
	wire [1:0] kt = idx[1:0] + frame[6:5];                       // pastel shimmer
	wire [5:0] tc = flash ? 6'd63 : col({1'b0, kt});

	wire plate_en = rv > 9'd40;
	wire inbox    = (hpos >= 11'd208) & (hpos < 11'd432) & (vpos >= 10'd224) & (vpos < 10'd256);
	wire inner    = (hpos >= 11'd210) & (hpos < 11'd430) & (vpos >= 10'd226) & (vpos < 10'd254);
	wire border   = inbox & ~inner & plate_en;
	wire plate    = inbox & plate_en;

	assign RGB = ~display_on ? 6'd0 :
	             border          ? col({1'b0, frame[7:6]}) :
	             (in_txt & vis & tp) ? tc :
	             plate           ? bg :
	             rain_px         ? rc : bg;
endmodule