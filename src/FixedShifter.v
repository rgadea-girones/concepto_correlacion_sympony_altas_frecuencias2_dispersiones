`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Project      : Arizona Float<->Fixed Hardware Library (AFFHL)
//
// Authors      : Lysecky, R., Saldanha, L., Kamath Nileshwar, V.
//
// Module Name  : FixedShifter
//
// Description  : Shift module which performs required amount of shifting 
//                needed to represented the input floating point number in its
//                fixed point representation
//
// Date modified: 11.14.2008
//-----------------------------------------------------------------------------

module FixedShifter (
    InNormFloat,
    InShiftAmount,
    InShiftDirection,
    OutUFixed
    );

    //-------------------------------------------------------------------------
    //                     Parameter Definitions
    //-------------------------------------------------------------------------
    // Width of floating point output
    parameter FLOATSIZE         = 32;
    
    // Width of OutFixed point input
    parameter FIXEDSIZE         = 16;
    
    // Width needed to represent radix point
    parameter RADIXPOINTSIZE    = 6;
    
    // Number of bits used to represent the exponent
    parameter EXPONENTBITS      = 8;
    
    // Number of bits used to represent the mantissa
    parameter MANTISSABITS      = 23;

    //-------------------------------------------------------------------------
    //                     Port Definitions
    //-------------------------------------------------------------------------

    // Mantissa part of floating point input with normal bit appended as MSB
    input [MANTISSABITS:0] InNormFloat;

    // Shift needed
    input [RADIXPOINTSIZE-1:0] InShiftAmount;

    // Shift direction
    // 0 - Left Shift
    // 1 - Right Shift
    input InShiftDirection;

    // Value after shifting
    output reg [FIXEDSIZE-1:0] OutUFixed;

    //-------------------------------------------------------------------------
    //                     Assignments and Statement Blocks
    //-------------------------------------------------------------------------

    always @ (InNormFloat, InShiftAmount, InShiftDirection)
    begin
        // If Shift direction indicates left shift
        if(InShiftDirection == 0)
        begin
            OutUFixed <= InNormFloat << InShiftAmount;
        end
        // Shift direction indicates right shift
        else
        begin
            OutUFixed <= InNormFloat >> InShiftAmount;
        end
    end

endmodule
