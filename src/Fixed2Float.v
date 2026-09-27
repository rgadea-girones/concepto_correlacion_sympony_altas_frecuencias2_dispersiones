`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Project      : Arizona Float<->Fixed Hardware Library (AFFHL)
//
// Authors      : Roman Lysecky, Lance Saldanha, Varadaraj Kamath Nileshwar,
//                Jovan Vance, David Schwartz
//
// Module Name  : Fixed2Float
//
// Description  : Converts fixed point input into its IEEE floating point
//                representation
//
// Date modified: 11.14.2008 : Initial Version
//
//                07.18.2010 : Bug Fix - Mantissa would go to negative indices
//                             when FIXEDSIZE is less than MANTISSABITS
//
//                01.16.2014 : Bug Fix - Increased size of NormShiftAmount by 
//                             one bit to accomodate corner case
//										 
//-----------------------------------------------------------------------------

module Fixed2Float (
    InFixed, 
    InRadixPoint,
    OutFloat
    );

    //-------------------------------------------------------------------------
    //                     Parameter Definitions
    //-------------------------------------------------------------------------
    // Width of floating point output
    parameter FLOATSIZE         = 32;

    // Width of fixed point input
    parameter FIXEDSIZE         = 64;

    // Width needed to represent radix point
    parameter RADIXPOINTSIZE    = 6;

    // Number of bits used to represent the exponent
    parameter EXPONENTBITS      = 8;

    // Number of bits used to represent the mantissa
    parameter MANTISSABITS      = 23;

    parameter BIAS              = 2**(EXPONENTBITS-1)-1;

    //-------------------------------------------------------------------------
    //                     Port Definitions
    //-------------------------------------------------------------------------

    // Fixed point input
    input signed [FIXEDSIZE-1:0] InFixed;

    // RadixPoint position from right
    input [RADIXPOINTSIZE-1:0] InRadixPoint;

    // Floating point output
    output reg [FLOATSIZE-1:0] OutFloat;

    //-------------------------------------------------------------------------
    //                     Internal Signals (wire & reg) declaration
    //-------------------------------------------------------------------------
    // Sign bit
    reg  SignBit;

    reg  [EXPONENTBITS-1:0] Exponent;
    reg  [MANTISSABITS-1:0] Mantissa;

    // Indicates position of leading 1
    reg  [RADIXPOINTSIZE:0] NormShiftAmount;

    // Unsigned representation of fixed point input
    reg  [FIXEDSIZE-1:0] UFixed;

    // UFixed shifted by NormShiftAmount
    reg  [FIXEDSIZE-1:0] UShiftFixed;
	//needs one more bit probably
    
	 // Flag to indicate that input is zero
    wire Zero;

    // Loop variable
    integer i;

    //-------------------------------------------------------------------------
    //                     Assignments and Statement Blocks
    //-------------------------------------------------------------------------

    // Sign bit and Absolute value extraction
    always @ (InFixed) 
    begin
        // If number is negative
        if(InFixed[FIXEDSIZE-1] == 1'b1)
        begin
            UFixed  <= -InFixed;
            SignBit <= 1'b1;
        end
        else
        begin
            UFixed  <= InFixed;
            SignBit <= 1'b0;
        end
    end

    // Zero is detected if all input bits are zero
    assign Zero = ~(|InFixed);
    
    // Priority encoder to detect the position of leading 1
    always @ (UFixed) 
    begin
        NormShiftAmount <= 0;

        for(i = 0; i < FIXEDSIZE; i = i + 1) 
        begin
            if(UFixed[i] == 1'b1) 
            begin
                NormShiftAmount <= FIXEDSIZE - i;
            end
        end
    end

    // Compute values of exponent and mantissa
    always @ (Zero, UFixed, InRadixPoint, NormShiftAmount) 
    begin
        // In case of zero, the output is also set to zero
        if(Zero == 1'b1) 
        begin
            UShiftFixed <= 0;
            Exponent    <= 0;
        end
        else 
        begin
            // UFixed is left shifted by the computed value of NormShiftAmount
            // to get rid of redundant 0 bits and position the MSB at the first
            // bit of the mantissa
            UShiftFixed <= UFixed << NormShiftAmount;
            
            //Add 2**EXPONENTBITS-1 as an offset (floating point exponent)
            Exponent    <= BIAS + FIXEDSIZE - InRadixPoint - NormShiftAmount;
        end
    end
    
    // Mantissa bits are allotted
    always @ (UShiftFixed)
    begin
        if (FIXEDSIZE < MANTISSABITS)
        begin
            Mantissa <= {UShiftFixed,{(MANTISSABITS-FIXEDSIZE){1'b0}}};
        end
        else
        begin
            Mantissa <= UShiftFixed[FIXEDSIZE-1:FIXEDSIZE-MANTISSABITS];
        end
    end

    // Concatenate SignBit, Exponent, Mantissa to form OutFloat
    always @ (SignBit, Exponent, Mantissa)
    begin
        OutFloat <= {SignBit, Exponent, Mantissa};
    end

endmodule
