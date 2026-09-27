`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Project      : Arizona Float<->Fixed Hardware Library (AFFHL)
//
// Authors      : Lysecky, R., Saldanha, L., Kamath Nileshwar, V.
//
// Module Name  : Overflow
//
// Description  : Computes the number of bits needed to represent the floating
//                point input in fixed point representation
//
// Date modified: 11.14.2008 - Initial Version
//                07.18.2010 - Bug Fix - Overflow computation would yield wrong
//                             results when FIXEDSIZE is less than or equal to
//                             MANTISSABITS+1. Modified Overflow Computation to
//                             fix  the  same. Also  added 2  new  ports
//                             InRadixPoint and InExponent needed for overflow
//                             computation.
//-----------------------------------------------------------------------------

module Overflow (
    InShiftAmount,
    InShiftDirection,
    InNormal,
    InExponent,
    InRadixPoint,
    OutOverflow
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
    
    // Number of bits used to represent the overflow
    parameter OVERFLOWBITS      = 6;

    // Maximum shift possible without causing overflow
    parameter MAXSHIFTNOOV = FIXEDSIZE - MANTISSABITS - 2;

    // Fixed shift value needed to compute exponent
    parameter BIAS              = 2**(EXPONENTBITS-1)-1;

    //-------------------------------------------------------------------------
    //                     Port Definitions
    //-------------------------------------------------------------------------
    // Amount by which the input is to be shifted
    input [RADIXPOINTSIZE-1:0] InShiftAmount;
    
    // Direction in which the input is to be shifted
    // 0 - Left shift
    // 1 - Right shift
    input InShiftDirection; 
    
    // Flag to indicate whether the input is normalized or denormalized
    // 0 - Denormalized
    // 1 - Normalized
    input InNormal;

    // Exponent
    input [EXPONENTBITS-1:0] InExponent;

    // RadixPoint position from right
    input [RADIXPOINTSIZE-1:0] InRadixPoint;

    // Number of bits needed to prevent overflow
    output reg [OVERFLOWBITS-1:0] OutOverflow;

    //-------------------------------------------------------------------------
    //                     Internal Signals (wire & reg) declaration
    //-------------------------------------------------------------------------
    reg [OVERFLOWBITS:0] FullOverflow;
        
    //-------------------------------------------------------------------------
    //                     Assignments and Statement Blocks
    //-------------------------------------------------------------------------
    
    
    // The number of extra bits needed to represent the floating point number
    // using the given fixed point precision is computed as the difference
    // of the computed shift amount and the maximum shift possible without 
    // causing an overflow. This is true only in case of the shift direction
    // indicating a left shift and also only for normalized numbers.
    always @ (InShiftAmount, InShiftDirection, InNormal, InExponent, InRadixPoint)
    begin
        if (FIXEDSIZE > (MANTISSABITS+1))
        begin
            if(InShiftAmount > MAXSHIFTNOOV && InShiftDirection == 0 && InNormal)
            begin
                FullOverflow <= InShiftAmount - MAXSHIFTNOOV;
            end
            else
            begin
                FullOverflow <= 0;
            end
        end
        else
        begin
            if (InExponent > BIAS && InNormal)
            begin
                if ((InExponent - BIAS) >= (FIXEDSIZE - InRadixPoint - 1))
                begin
                    FullOverflow <= (InExponent - BIAS) - (FIXEDSIZE - InRadixPoint - 1) + 1;
                end
                else
                begin
                    FullOverflow <= 0;
                end
            end
            else
            begin
                FullOverflow <= 0;
            end
        end
    end
        
    // In case the above computed overflow is greater than the maximum
    // allowed overflow output overflow is set to one less than the maximum 
    always @ (FullOverflow)
    begin
        if(FullOverflow > (2**OVERFLOWBITS))
        begin
            OutOverflow <= (2**OVERFLOWBITS)-1;
        end
        else 
        begin
            OutOverflow <= FullOverflow;
        end
    end

endmodule
