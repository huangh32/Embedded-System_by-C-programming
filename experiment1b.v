// Copyright by Adam Kinsman, Henry Ko and Nicola Nicolici
// Developed for the Embedded Systems course (COE4DS4)
// Department of Electrical and Computer Engineering
// McMaster University
// Ontario, Canada

`timescale 1ns/100ps
`default_nettype none

// This is the top module
// It interfaces to the LCD display and touch panel
module experiment1b (
	/////// board clocks                      ////////////
	input logic CLOCK_50_I,                   // 50 MHz clock
	
	/////// pushbuttons/switches              ////////////
	input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
	input logic[17:0] SWITCH_I,               // toggle switches
	
	/////// 7 segment displays/LEDs           ////////////
	output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
	output logic[8:0] LED_GREEN_O,            // 9 green LEDs
	output logic[17:0] LED_RED_O,             // 18 red LEDs
	
	/////// GPIO connections                  ////////////
	inout wire[35:0] GPIO_0,                   // GPIO Connection 0 (LTM)
	////// FSM
	input logic resetn
	
);

// Signals for LCD Touch Module (LTM)
// LCD display interface
logic 	[7:0]	LTM_R, LTM_G, LTM_B;
logic 			LTM_HD, LTM_VD;
logic 			LTM_NCLK, LTM_DEN, LTM_GRST;

// LCD configuration interface
wire 			LTM_SDA;
logic 			LTM_SCLK, LTM_SCEN;

// LCD touch panel interface
logic 			TP_DCLK, TP_CS, TP_DIN, TP_DOUT;
logic 			TP_PENIRQ_N, TP_BUSY;

// Internal signals
logic 			Clock, Resetn;
logic 	[2:0] 	Top_state;

// For LCD display / touch screen
logic 			LCD_TPn_sel, LCD_TPn_sclk;
logic 			LCD_config_start, LCD_config_done;
logic 			LCD_enable, TP_enable;
logic 			TP_touch_en, TP_coord_en;
logic 	[11:0]	TP_X_coord, TP_Y_coord;

logic 	[9:0] 	Colourbar_X, Colourbar_Y;
logic 	[7:0]	Colourbar_Red, Colourbar_Green, Colourbar_Blue;

logic 	[4:0] 	TP_position[7:0];
logic    [2:0] 	Diff1,Diff2,Diff3,Diff4,Diff5,Diff6,Diff7,Diff8;

//FSM variables
logic [26:0] color_counter0;
logic [26:0] color_counter1;
logic [26:0] color_counter2;
logic [26:0] color_counter3;
logic [26:0] color_counter4;
logic [26:0] color_counter5;
logic [26:0] color_counter6;
logic [26:0] color_counter7;
logic [4:0] position_counter;
logic [4:0] color_buffer0;
logic [4:0] color_buffer1;
logic [4:0] color_buffer2;
logic [4:0] color_buffer3;
logic [4:0] color_buffer4;
logic [4:0] color_buffer5;
logic [4:0] color_buffer6;
logic [4:0] color_buffer7;
//logic [7:0] color_red_buffer0,color_blue_buffer0,color_green_buffer0,color_red_buffer1,color_blue_buffer1,color_green_buffer1;
//logic [7:0] color_red_buffer2,color_blue_buffer2,color_green_buffer2,color_red_buffer3,color_blue_buffer3,color_green_buffer3;
//logic [7:0] color_red_buffer4,color_blue_buffer4,color_green_buffer4,color_red_buffer5,color_blue_buffer5,color_green_buffer5;
//logic [7:0] color_red_buffer6,color_blue_buffer6,color_green_buffer6,color_red_buffer7,color_blue_buffer7,color_green_buffer7;

//reg [2:0] present_state,next_state;
enum logic[2:0]{
	S_IDLE,
	S_1,
	S_2,
	S_3,
	S_4,
	S_5,
	S_6,
	S_7
}RGB_state;


assign Clock = CLOCK_50_I;
assign Resetn = SWITCH_I[17];

assign LCD_TPn_sclk = (LCD_TPn_sel) ? LTM_SCLK : TP_DCLK;
assign LTM_SCEN = (LCD_TPn_sel) ? 1'b0 : ~TP_CS;
assign LTM_GRST = Resetn;

// Connections to GPIO for LTM
assign TP_PENIRQ_N   = GPIO_0[0];
assign TP_DOUT       = GPIO_0[1];
assign TP_BUSY       = GPIO_0[2];
assign GPIO_0[3]	 = TP_DIN;

assign GPIO_0[4]	 = LCD_TPn_sclk;

assign GPIO_0[35]    = LTM_SDA;
assign GPIO_0[34]    = LTM_SCEN;
assign GPIO_0[33]    = LTM_GRST;

assign GPIO_0[9]	 = LTM_NCLK;
assign GPIO_0[10]    = LTM_DEN;
assign GPIO_0[11]    = LTM_HD;
assign GPIO_0[12]    = LTM_VD;

assign GPIO_0[5]     = LTM_B[3];
assign GPIO_0[6]     = LTM_B[2];
assign GPIO_0[7]     = LTM_B[1];
assign GPIO_0[8]     = LTM_B[0];
assign GPIO_0[16:13] = LTM_B[7:4];
assign GPIO_0[24:17] = LTM_G[7:0];
assign GPIO_0[32:25] = LTM_R[7:0];

// Top state machine for controlling resets
always_ff @(posedge Clock or negedge Resetn) begin
	if (~Resetn) begin
		Top_state <= 3'h0;
		TP_enable <= 1'b0;
		LCD_enable <= 1'b0;
		LCD_config_start <= 1'b0;
		LCD_TPn_sel <= 1'b1;
	end else begin
		case (Top_state)
			3'h0 : begin
				LCD_config_start <= 1'b1;
				LCD_TPn_sel <= 1'b1;
				Top_state <= 3'h1;
			end			
			3'h1 : begin
				LCD_config_start <= 1'b0;
				if (LCD_config_done & ~LCD_config_start) begin
					TP_enable <= 1'b1;
					LCD_enable <= 1'b1;
					LCD_TPn_sel <= 1'b0;
					Top_state <= 3'h2;
				end
			end			
			3'h2 : begin
				Top_state <= 3'h2;
			end
		endcase
	end
end				

// LCD Configuration
LCD_Config_Controller LCD_Config_unit(
	.Clock(Clock),
	.Resetn(Resetn),
	.Start(LCD_config_start),
	.Done(LCD_config_done),
	.LCD_I2C_sclk(LTM_SCLK),
 	.LCD_I2C_sdat(LTM_SDA),
	.LCD_I2C_scen()
);

// LCD Image
LCD_Data_Controller LCD_Data_unit (
	.Clock(Clock),
	.oClock_en(),
	.Resetn(Resetn),
	.Enable(LCD_enable),
	.iRed(Colourbar_Red),
	.iGreen(Colourbar_Green),
	.iBlue(Colourbar_Blue),
	.oCoord_X(Colourbar_X),
	.oCoord_Y(Colourbar_Y),
//	.oCoord_D1(Diff1),
//	.oCoord_D2(Diff2),
//	.oCoord_D3(Diff3),
//	.oCoord_D4(Diff4),
//	.oCoord_D5(Diff5),
//	.oCoord_D6(Diff6),
//	.oCoord_D7(Diff7),
//	.oCoord_D8(Diff8),
	.H_Count(), // not used in this experiment
	.V_Count(), // not used in this experiment
	.LTM_NCLK(LTM_NCLK),
	.LTM_HD(LTM_HD),
	.LTM_VD(LTM_VD),
	.LTM_DEN(LTM_DEN),
	.LTM_R(LTM_R),
	.LTM_G(LTM_G),
	.LTM_B(LTM_B)
);

//// State machine for generating the colour bars
//always_ff @(posedge Clock or negedge Resetn) begin
//	if (~Resetn) begin
//		Colourbar_Red <= 8'h00; 
//		Colourbar_Green <= 8'h00;
//		Colourbar_Blue <= 8'h00;
//	end else begin
////		Colourbar_Red <= {8{Colourbar_X[2]}};
////		Colourbar_Green = {8{Colourbar_X[1]}};
////		Colourbar_Blue = {8{Colourbar_X[0]}};
//	end
//end

// Controller for the TP on the LTM
Touch_Panel_Controller Touch_Panel_unit( 
	.Clock_50MHz(Clock),
	.Resetn(Resetn),
	.Enable(~LTM_VD),	
	.Touch_En(TP_touch_en),
	.Coord_En(TP_coord_en),
	.X_Coord(TP_X_coord),
	.Y_Coord(TP_Y_coord),
	.TP_PENIRQ_N_I(TP_PENIRQ_N),
	.TP_BUSY_I(TP_BUSY), 
	.TP_SCLK_O(TP_DCLK),
	.TP_MOSI_O(TP_DIN),
	.TP_MISO_I(TP_DOUT),
	.TP_SS_N_O(TP_CS)
);


// State machine for capturing the touch panel coordinates
// and displaying them on the seven segment displays
always_ff @(posedge Clock or negedge Resetn) begin
	if (~Resetn) begin
		TP_position[0] <= 5'h10;
		TP_position[1] <= 5'h10;
		TP_position[2] <= 5'h10;
		TP_position[3] <= 5'h10;
		TP_position[4] <= 5'h10;
		TP_position[5] <= 5'h10;
		TP_position[6] <= 5'h10;
		TP_position[7] <= 5'h10;
		Diff1<=3'b000;
		Diff2<=3'b001;
		Diff3<=3'b010;
		Diff4<=3'b011;
		Diff5<=3'b100;
		Diff6<=3'b101;
		Diff7<=3'b110;
		Diff8<=3'b111;
		color_counter0 <= 26'd00;
		color_counter1 <= 26'd00;
		color_counter2 <= 26'd00;
		color_counter3 <= 26'd00;
		color_counter4 <= 26'd00;
		color_counter5 <= 26'd00;
		color_counter6 <= 26'd00;
		color_counter7 <= 26'd00;
		position_counter <= 5'h10;
		color_buffer0 <= 5'h18;
		color_buffer1 <= 5'h18;
		color_buffer2 <= 5'h18;
		color_buffer3 <= 5'h18;
		color_buffer4 <= 5'h18;
		color_buffer5 <= 5'h18;
		color_buffer6 <= 5'h18;
		color_buffer7 <= 5'h18;
		end else begin
		if (color_counter0 == 26'd49999999) begin   //block 0
			Diff1 <= Diff1 + 1'd1;
			color_counter0 <= 26'd00;
		end
		else begin
//			if (Diff1 == 3'b000)
//				color_buffer0 <= color_buffer0 + 1'h1;
//			else
//				color_buffer0 <= color_buffer0 - 1'h1;
//			if (Diff1 == 3'b001)
//				color_buffer1 <= color_buffer1 + 1'h1;
//			else 
//				color_buffer1 <= color_buffer1 - 1'h1;
//			if (Diff1 == 3'b010)
//				color_buffer2 <= color_buffer2 + 1'h1;
//			else 
//				color_buffer2 <= color_buffer2 - 1'h1; 
//			if (Diff1 == 3'b011)
//				color_buffer3 <= color_buffer3 + 1'h1;	
//			else 
//				color_buffer3 <= color_buffer3 - 1'h1;
//			if (Diff1 == 3'b100)
//				color_buffer4 <= color_buffer4 + 1'h1;	
//			else 
//				color_buffer4 <= color_buffer4 - 1'h1;
//			if (Diff1 == 3'b101)
//				color_buffer5 <= color_buffer5 + 1'h1;
//			else 
//				color_buffer5 <= color_buffer5 - 1'h1;
//			if (Diff1 == 3'b110)
//				color_buffer6 <= color_buffer6 + 1'h1;
//			else 
//				color_buffer6 <= color_buffer6 - 1'h1;
//			if (Diff1 == 3'b111)
//				color_buffer7 <= color_buffer7 + 1'h1;
//			else 
//				color_buffer7 <= color_buffer7 - 1'h1;
		   if (TP_coord_en) begin
			   if (~(TP_X_coord[11] && TP_X_coord[10] && TP_Y_coord[11]))begin
				position_counter <= 5'h10;
				color_counter0 <= 26'd00;
		      end
			end
			else begin
			   color_counter0 <= color_counter0 + 1'd1;
		    end
		end

		if (color_counter1 == 26'd49999999) begin   //block 1
			Diff2 <= Diff2 + 1'd1;
			color_counter1 <= 26'd00;
		end
		else begin
//			if (Diff2 == 3'b000)
//				color_buffer0 <= color_buffer0 + 1'h1;
//			else
//				color_buffer0 <= color_buffer0 - 1'h1;
//			if (Diff2 == 3'b001)
//				color_buffer1 <= color_buffer1 + 1'h1;
//			else 
//				color_buffer1 <= color_buffer1 - 1'h1;
//			if (Diff2 == 3'b010)
//				color_buffer2 <= color_buffer2 + 1'h1;
//			else 
//				color_buffer2 <= color_buffer2 - 1'h1; 
//			if (Diff2 == 3'b011)
//				color_buffer3 <= color_buffer3 + 1'h1;	
//			else 
//				color_buffer3 <= color_buffer3 - 1'h1;
//			if (Diff2 == 3'b100)
//				color_buffer4 <= color_buffer4 + 1'h1;	
//			else 
//				color_buffer4 <= color_buffer4 - 1'h1;
//			if (Diff2 == 3'b101)
//				color_buffer5 <= color_buffer5 + 1'h1;
//			else 
//				color_buffer5 <= color_buffer5 - 1'h1;
//			if (Diff2 == 3'b110)
//				color_buffer6 <= color_buffer6 + 1'h1;
//			else 
//				color_buffer6 <= color_buffer6 - 1'h1;
//			if (Diff2 == 3'b111)
//				color_buffer7 <= color_buffer7 + 1'h1;
//			else 
//				color_buffer7 <= color_buffer7 - 1'h1;
			if (TP_coord_en) begin
			   if (~TP_X_coord[11] && TP_X_coord[10] && ~TP_Y_coord[11])begin
				position_counter <= 5'h11;
				color_counter1 <= 26'd00;
		      end
			end
			else begin
				color_counter1 <= color_counter1 + 1'd1;
			end
		end
		
		if (color_counter2 == 26'd49999999) begin //block 2
			Diff3 <= Diff3 + 1'd1;
			color_counter2 <= 26'd00;
		end
		else begin
//			if (Diff3 == 3'b000)
//				color_buffer0 <= color_buffer0 + 1'h1;
//			else
//				color_buffer0 <= color_buffer0 - 1'h1;
//			if (Diff3 == 3'b001)
//				color_buffer1 <= color_buffer1 + 1'h1;
//			else 
//				color_buffer1 <= color_buffer1 - 1'h1;
//			if (Diff3 == 3'b010)
//				color_buffer2 <= color_buffer2 + 1'h1;
//			else 
//				color_buffer2 <= color_buffer2 - 1'h1; 
//			if (Diff3 == 3'b011)
//				color_buffer3 <= color_buffer3 + 1'h1;	
//			else 
//				color_buffer3 <= color_buffer3 - 1'h1;
//			if (Diff3 == 3'b100)
//				color_buffer4 <= color_buffer4 + 1'h1;	
//			else 
//				color_buffer4 <= color_buffer4 - 1'h1;
//			if (Diff3 == 3'b101)
//				color_buffer5 <= color_buffer5 + 1'h1;
//			else 
//				color_buffer5 <= color_buffer5 - 1'h1;
//			if (Diff3 == 3'b110)
//				color_buffer6 <= color_buffer6 + 1'h1;
//			else 
//				color_buffer6 <= color_buffer6 - 1'h1;
//			if (Diff1 == 3'b111)
//				color_buffer7 <= color_buffer7 + 1'h1;
//			else 
//				color_buffer7 <= color_buffer7 - 1'h1;
			if (TP_coord_en) begin
			   if (TP_X_coord[11] && ~TP_X_coord[10] && ~TP_Y_coord[11])begin
				position_counter <= 5'h12;
				color_counter2 <= 26'd00;
		      end
			end
			else begin
				color_counter2 <= color_counter2 + 1'd1;
			end
		end
		
		if (color_counter3 == 26'd49999999) begin //block 3
			Diff4 <= Diff4 + 1'd1;
			color_counter3 <= 26'd00;
		end
		else begin
//			if (Diff4 == 3'b000)
//				color_buffer0 <= color_buffer0 + 1'h1;
//			else
//				color_buffer0 <= color_buffer0 - 1'h1;
//			if (Diff4 == 3'b001)
//				color_buffer1 <= color_buffer1 + 1'h1;
//			else 
//				color_buffer1 <= color_buffer1 - 1'h1;
//			if (Diff4 == 3'b010)
//				color_buffer2 <= color_buffer2 + 1'h1;
//			else 
//				color_buffer2 <= color_buffer2 - 1'h1; 
//			if (Diff4 == 3'b011)
//				color_buffer3 <= color_buffer3 + 1'h1;	
//			else 
//				color_buffer3 <= color_buffer3 - 1'h1;
//			if (Diff4 == 3'b100)
//				color_buffer4 <= color_buffer4 + 1'h1;	
//			else 
//				color_buffer4 <= color_buffer4 - 1'h1;
//			if (Diff4 == 3'b101)
//				color_buffer5 <= color_buffer5 + 1'h1;
//			else 
//				color_buffer5 <= color_buffer5 - 1'h1;
//			if (Diff4 == 3'b110)
//				color_buffer6 <= color_buffer6 + 1'h1;
//			else 
//				color_buffer6 <= color_buffer6 - 1'h1;
//			if (Diff4 == 3'b111)
//				color_buffer7 <= color_buffer7 + 1'h1;
//			else 
//				color_buffer7 <= color_buffer7 - 1'h1;
			if (TP_coord_en) begin
			   if (TP_X_coord[11] && TP_X_coord[10] && ~TP_Y_coord[11])begin
				position_counter <= 5'h13;
				color_counter3 <= 26'd00;
		      end
			end
			else begin
				color_counter3 <= color_counter3 + 1'd1;
			end
		end
		
		if (color_counter4 == 26'd49999999) begin //block 4
			Diff5 <= Diff5 + 1'd1;
			color_counter4 <= 26'd00;
		end
		else begin
//			if (Diff5 == 3'b000)
//				color_buffer0 <= color_buffer0 + 1'h1;
//			else
//				color_buffer0 <= color_buffer0 - 1'h1;
//			if (Diff5 == 3'b001)
//				color_buffer1 <= color_buffer1 + 1'h1;
//			else 
//				color_buffer1 <= color_buffer1 - 1'h1;
//			if (Diff5 == 3'b010)
//				color_buffer2 <= color_buffer2 + 1'h1;
//			else 
//				color_buffer2 <= color_buffer2 - 1'h1; 
//			if (Diff5 == 3'b011)
//				color_buffer3 <= color_buffer3 + 1'h1;	
//			else 
//				color_buffer3 <= color_buffer3 - 1'h1;
//			if (Diff5 == 3'b100)
//				color_buffer4 <= color_buffer4 + 1'h1;	
//			else 
//				color_buffer4 <= color_buffer4 - 1'h1;
//			if (Diff5 == 3'b101)
//				color_buffer5 <= color_buffer5 + 1'h1;
//			else 
//				color_buffer5 <= color_buffer5 - 1'h1;
//			if (Diff5 == 3'b110)
//				color_buffer6 <= color_buffer6 + 1'h1;
//			else 
//				color_buffer6 <= color_buffer6 - 1'h1;
//			if (Diff5 == 3'b111)
//				color_buffer7 <= color_buffer7 + 1'h1;
//			else 
//				color_buffer7 <= color_buffer7 - 1'h1;
			if (TP_coord_en) begin
			   if (~TP_X_coord[11] && ~TP_X_coord[10] && TP_Y_coord[11])begin
				position_counter <= 5'h14;
				color_counter4 <= 26'd00;
		      end
			end
			else begin
				color_counter4 <= color_counter4 + 1'd1;
			end
		end
		
		if (color_counter5 == 26'd49999999) begin  //block 5
			Diff6 <= Diff6 + 1'd1;
			color_counter5 <= 26'd00;
		end
		else begin
//			if (Diff6 == 3'b000)
//				color_buffer0 <= color_buffer0 + 1'h1;
//			else
//				color_buffer0 <= color_buffer0 - 1'h1;
//			if (Diff6 == 3'b001)
//				color_buffer1 <= color_buffer1 + 1'h1;
//			else 
//				color_buffer1 <= color_buffer1 - 1'h1;
//			if (Diff6 == 3'b010)
//				color_buffer2 <= color_buffer2 + 1'h1;
//			else 
//				color_buffer2 <= color_buffer2 - 1'h1; 
//			if (Diff6 == 3'b011)
//				color_buffer3 <= color_buffer3 + 1'h1;	
//			else 
//				color_buffer3 <= color_buffer3 - 1'h1;
//			if (Diff6 == 3'b100)
//				color_buffer4 <= color_buffer4 + 1'h1;	
//			else 
//				color_buffer4 <= color_buffer4 - 1'h1;
//			if (Diff6 == 3'b101)
//				color_buffer5 <= color_buffer5 + 1'h1;
//			else 
//				color_buffer5 <= color_buffer5 - 1'h1;
//			if (Diff6 == 3'b110)
//				color_buffer6 <= color_buffer6 + 1'h1;
//			else 
//				color_buffer6 <= color_buffer6 - 1'h1;
//			if (Diff6 == 3'b111)
//				color_buffer7 <= color_buffer7 + 1'h1;
//			else 
//				color_buffer7 <= color_buffer7 - 1'h1;
			if (TP_coord_en) begin
			   if (~TP_X_coord[11] && TP_X_coord[10] && TP_Y_coord[11])begin
				position_counter <= 5'h15;
				color_counter5 <= 26'd00;
		      end
			end
			else begin
				color_counter5 <= color_counter5 + 1'd1;
			end
		end
		
		if (color_counter6 == 26'd49999999) begin   //block 6
			Diff7 <= Diff7+ 1'd1;
			color_counter6 <= 26'd00;
		end
		else begin
//			if (Diff7 == 3'b000)
//				color_buffer0 <= color_buffer0 + 1'h1;
//			else
//				color_buffer0 <= color_buffer0 - 1'h1;
//			if (Diff7 == 3'b001)
//				color_buffer1 <= color_buffer1 + 1'h1;
//			else 
//				color_buffer1 <= color_buffer1 - 1'h1;
//			if (Diff7 == 3'b010)
//				color_buffer2 <= color_buffer2 + 1'h1;
//			else 
//				color_buffer2 <= color_buffer2 - 1'h1; 
//			if (Diff7 == 3'b011)
//				color_buffer3 <= color_buffer3 + 1'h1;	
//			else 
//				color_buffer3 <= color_buffer3 - 1'h1;
//			if (Diff7 == 3'b100)
//				color_buffer4 <= color_buffer4 + 1'h1;	
//			else 
//				color_buffer4 <= color_buffer4 - 1'h1;
//			if (Diff7 == 3'b101)
//				color_buffer5 <= color_buffer5 + 1'h1;
//			else 
//				color_buffer5 <= color_buffer5 - 1'h1;
//			if (Diff7 == 3'b110)
//				color_buffer6 <= color_buffer6 + 1'h1;
//			else 
//				color_buffer6 <= color_buffer6 - 1'h1;
//			if (Diff7 == 3'b111)
//				color_buffer7 <= color_buffer7 + 1'h1;
//			else 
//				color_buffer7 <= color_buffer7 - 1'h1;
			if (TP_coord_en) begin
			   if (TP_X_coord[11] && ~TP_X_coord[10] && TP_Y_coord[11])begin
				position_counter <= 5'h16;
				color_counter6 <= 26'd00;
		      end
			end
			else begin
				color_counter6 <= color_counter6 + 1'd1;
			end
		end
		
		if (color_counter7 == 26'd49999999) begin   //block 7
			Diff8 <= Diff8 + 1'd1;
			color_counter7 <= 26'd00;
		end
		else begin
//			if (Diff8 == 3'b000)
//				color_buffer0 <= color_buffer0 + 1'h1;
//			else
//				color_buffer0 <= color_buffer0 - 1'h1;
//			if (Diff8 == 3'b001)
//				color_buffer1 <= color_buffer1 + 1'h1;
//			else 
//				color_buffer1 <= color_buffer1 - 1'h1;
//			if (Diff8 == 3'b010)
//				color_buffer2 <= color_buffer2 + 1'h1;
//			else 
//				color_buffer2 <= color_buffer2 - 1'h1; 
//			if (Diff8 == 3'b011)
//				color_buffer3 <= color_buffer3 + 1'h1;	
//			else 
//				color_buffer3 <= color_buffer3 - 1'h1;
//			if (Diff8 == 3'b100)
//				color_buffer4 <= color_buffer4 + 1'h1;	
//			else 
//				color_buffer4 <= color_buffer4 - 1'h1;
//			if (Diff8 == 3'b101)
//				color_buffer5 <= color_buffer5 + 1'h1;
//			else 
//				color_buffer5 <= color_buffer5 - 1'h1;
//			if (Diff8 == 3'b110)
//				color_buffer6 <= color_buffer6 + 1'h1;
//			else 
//				color_buffer6 <= color_buffer6 - 1'h1;
//			if (Diff8== 3'b111)
//				color_buffer7 <= color_buffer7 + 1'h1;
//			else 
//				color_buffer7 <= color_buffer7 - 1'h1;
			if (TP_coord_en) begin
			   if (TP_X_coord[11] && TP_X_coord[10] && TP_Y_coord[11])begin
				position_counter <= 5'h17;
				color_counter7 <= 26'd00;
		      end
			end
			else begin
				color_counter7 <= color_counter7 + 1'd1;
			end
		end
		
		if (~SWITCH_I[0]) begin
			if (position_counter != TP_position[0]) begin
				TP_position[0] <= position_counter;
				TP_position[1] <= TP_position[0];
				TP_position[2] <= TP_position[1];
				TP_position[3] <= TP_position[2];
				TP_position[4] <= TP_position[3];
				TP_position[5] <= TP_position[4];
				TP_position[6] <= TP_position[5];
				TP_position[7] <= TP_position[6];
			end
		end
		else begin
			TP_position[0][2:0]<= (Diff1==3'b000)+(Diff2==3'b000)+(Diff3==3'b000)+(Diff4==3'b000)+(Diff5==3'b000)+(Diff6==3'b000)+(Diff7==3'b000)+(Diff8==3'b000);
			TP_position[1][2:0]<= (Diff1==3'b001)+(Diff2==3'b001)+(Diff3==3'b001)+(Diff4==3'b001)+(Diff5==3'b001)+(Diff6==3'b001)+(Diff7==3'b001)+(Diff8==3'b001);
			TP_position[2][2:0]<= (Diff1==3'b010)+(Diff2==3'b010)+(Diff3==3'b010)+(Diff4==3'b010)+(Diff5==3'b010)+(Diff6==3'b010)+(Diff7==3'b010)+(Diff8==3'b010);
			TP_position[3][2:0]<= (Diff1==3'b011)+(Diff2==3'b011)+(Diff3==3'b011)+(Diff4==3'b011)+(Diff5==3'b011)+(Diff6==3'b011)+(Diff7==3'b011)+(Diff8==3'b011);
			TP_position[4][2:0]<= (Diff1==3'b100)+(Diff2==3'b100)+(Diff3==3'b100)+(Diff4==3'b100)+(Diff5==3'b100)+(Diff6==3'b100)+(Diff7==3'b100)+(Diff8==3'b100);
			TP_position[5][2:0]<= (Diff1==3'b101)+(Diff2==3'b101)+(Diff3==3'b101)+(Diff4==3'b101)+(Diff5==3'b101)+(Diff6==3'b101)+(Diff7==3'b101)+(Diff8==3'b101);
			TP_position[6][2:0]<= (Diff1==3'b110)+(Diff2==3'b110)+(Diff3==3'b110)+(Diff4==3'b110)+(Diff5==3'b110)+(Diff6==3'b110)+(Diff7==3'b110)+(Diff8==3'b110);
			TP_position[7][2:0]<= (Diff1==3'b111)+(Diff2==3'b111)+(Diff3==3'b111)+(Diff4==3'b111)+(Diff5==3'b111)+(Diff6==3'b111)+(Diff7==3'b111)+(Diff8==3'b111);
//			TP_position[0] <= color_buffer0;
//			TP_position[1] <= color_buffer1;
//			TP_position[2] <= color_buffer2;
//			TP_position[3] <= color_buffer3;
//			TP_position[4] <= color_buffer4;
//			TP_position[5] <= color_buffer5;
//			TP_position[6] <= color_buffer6;
//			TP_position[7] <= color_buffer7;
		end
	end
end
always_ff @(posedge Clock or negedge Resetn) begin
if (~Resetn) begin
		Colourbar_Red <= 8'h00; 
		Colourbar_Green <= 8'h00;
		Colourbar_Blue <= 8'h00;
		end else begin
	if(Colourbar_X<=10'd199&& Colourbar_Y <=10'd239)begin//0
		Colourbar_Red <= {8{Diff1[2]}};
		Colourbar_Green <= {8{Diff1[1]}};
		Colourbar_Blue <= {8{Diff1[0]}};
	end else if (Colourbar_X<=10'd399&& Colourbar_Y <=10'd239)begin//1
		Colourbar_Red <= {8{Diff2[2]}};
		Colourbar_Green <= {8{Diff2[1]}};
		Colourbar_Blue <= {8{Diff2[0]}};
	end else if (Colourbar_X<=10'd599&& Colourbar_Y <=10'd239)begin//2
		Colourbar_Red <= {8{Diff3[2]}};
		Colourbar_Green <= {8{Diff3[1]}};
		Colourbar_Blue <= {8{Diff3[0]}};
	end else if (Colourbar_X<=10'd799&& Colourbar_Y <=10'd239)begin//3
		Colourbar_Red <= {8{Diff4[2]}};
		Colourbar_Green <= {8{Diff4[1]}};
		Colourbar_Blue <= {8{Diff4[0]}};
	end else if (Colourbar_X<=10'd199&& Colourbar_Y <=10'd479)begin//4
		Colourbar_Red <= {8{Diff5[2]}};
		Colourbar_Green <= {8{Diff5[1]}};
		Colourbar_Blue <= {8{Diff5[0]}};
	end else if (Colourbar_X<=10'd399&& Colourbar_Y <=10'd479)begin//5
		Colourbar_Red <= {8{Diff6[2]}};
		Colourbar_Green <= {8{Diff6[1]}};
		Colourbar_Blue <= {8{Diff6[0]}};
	end else if (Colourbar_X<=10'd599&& Colourbar_Y <=10'd479)begin//6
		Colourbar_Red <= {8{Diff7[2]}};
		Colourbar_Green <= {8{Diff7[1]}};
		Colourbar_Blue <= {8{Diff7[0]}};
	end else if (Colourbar_X<=10'd799&& Colourbar_Y <=10'd479)begin//7
		Colourbar_Red <= {8{Diff8[2]}};
		Colourbar_Green <= {8{Diff8[1]}};
		Colourbar_Blue <= {8{Diff8[0]}};
		end
end
end

//always @(posedge CLOCK_50_I or negedge resetn)begin//FSM
	//if(~resetn)begin
	//	RGB_state<=S_IDLE;
	//	counter<=3'd0;
	//end else begin
//		case(RGB_state)
//		S_IDLE:begin
//			Colourbar_Red <= 8'h000;
//			Colourbar_Green <= 8'h000;
//			Colourbar_Blue <= 8'h000;
//			counter<=counter+3'd1;
//			RGB_state<=S_1;
//		end
//	
//	end//end for else
//
//end//end for always

// Seven segment displays
seven_seg_displays display_unit (
	.hex_values(TP_position),
	.SEVEN_SEGMENT_N_O(SEVEN_SEGMENT_N_O)
);

endmodule
