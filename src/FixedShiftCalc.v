`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Project      : Arizona Float<->Fixed Hardware Library (AFFHL)
//
// Authors      : Roman Lysecky, Lance Saldanha, Varadaraj Kamath Nileshwar,
//                Jovan Vance, David Schwartz
//
// Module Name  : FixedShiftCalc
//
// Description  : Computes the shift direction and value based on the exponent
//                and radix point values
//
// Date modified: 11.14.2008 : Initial Version
// 					 1.16.2014 : Bug Fix - Modified size for ShiftAmount 
//                             to ensure sufficient bits for exponent values   
//                             greaterthan RADIXPOINTSIZE. 
//                             NOTE: ShiftAmount must be equal
//                             to max(EXPONENTBITS, RADIXPOINTSIZE) + 1.
//
// 					 1.16.2014 : Modified calculation for OutShiftAmount in
//                             to correct output result for floating point 
//                             values smaller than the smallest representable 
//                             fixed point value. 
//                             Modified design will output a fixed point value of 0 
//                             in this situation.
//
//-----------------------------------------------------------------------------

module FixedShiftCalc (
    InExponent,
    InRadixPoint,
    InNormal,
    OutShiftAmount,
    OutShiftDirection
    );

    //-------------------------------------------------------------------------
    //                     Parameter Definitions
    //-------------------------------------------------------------------------
    // Width of floating point output
    parameter FLOATSIZE         = 32;
    
    // Width of OutFixed point input
    parameter FIXEDSIZE         = 32;
    
    // Width needed to represent radix point
    parameter RADIXPOINTSIZE    = 6;
    
    // Number of bits used to represent the exponent
    parameter EXPONENTBITS      = 8;
    	 
    // Number of bits used to represent the mantissa
    parameter MANTISSABITS      = 23;

    // Fixed shift value needed to compute exponent
    parameter BIAS              = 2**(EXPONENTBITS-1)-1;

    //-------------------------------------------------------------------------
    //                     Port Definitions
    //-------------------------------------------------------------------------

    // Exponent
    input [EXPONENTBITS-1:0] InExponent;
    
    // RadixPoint position from right
    input [RADIXPOINTSIZE-1:0] InRadixPoint;
    
    // Input flag indicating whether the input is normalized or denormalized
    input InNormal;

    // Shift needed
    output reg [RADIXPOINTSIZE-1:0] OutShiftAmount;
    
    // Shift direction
    // 0 - Left Shift
    // 1 - Right Shift
    output reg OutShiftDirection;

    //-------------------------------------------------------------------------
    //                     Internal Signals (wire & reg) declaration
    //-------------------------------------------------------------------------
    
    // Signed shift amount. Negative number indicates a right shift is needed
    // 
	 // NOTE: Bits for ShiftAmount must be equal to 
	 //       max(EXPONENTBITS, RADIXPOINTSIZE) + 1
	 reg signed [EXPONENTBITS:0] ShiftAmount;
    
    //-------------------------------------------------------------------------
    //                     Assignments and Statement Blocks
    //-------------------------------------------------------------------------

    always @ (InNormal, InRadixPoint, InExponent)
    begin
        // In case of normalized numbers we need to consider the difference
        // between the exponent and constant bias to compute the shift needed
        if (InNormal == 1'b1)
        begin
            ShiftAmount <= InRadixPoint - MANTISSABITS + InExponent - BIAS;
        end
        // Shift for denormalized numbers is directly the difference of the
        // radix point and the number of bits allocated for mantissa
        else
        begin
            ShiftAmount <= InRadixPoint - MANTISSABITS;
        end
    end

    // Set the shift direction and absolute shift value to output ports
    always @ (ShiftAmount)
    begin
        // If shift value is negative, it indicates right shift
        if(ShiftAmount < (0-MANTISSABITS))
        begin
            OutShiftAmount      <= MANTISSABITS+1;
            OutShiftDirection   <= 1;
        end
        // If shift value is negative, it indicates right shift
        else if(ShiftAmount < 0)
        begin
            OutShiftAmount      <= -ShiftAmount;
            OutShiftDirection   <= 1;
        end
        // If shift value is positive, it indicates left shift
        else 
        begin
            OutShiftAmount      <= ShiftAmount;
            OutShiftDirection   <= 0;
        end
    end
endmodule
